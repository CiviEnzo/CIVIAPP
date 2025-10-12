import axios, { AxiosError } from 'axios';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';

import { FieldValue, db } from '../utils/firestore';
import { upsertSecret, clearSecretCache } from './secrets';
import { clearWaConfigCache } from './config';

const REGION = process.env.WA_REGION ?? 'europe-west1';
const GRAPH_API_VERSION = process.env.WA_GRAPH_API_VERSION ?? 'v19.0';
const APP_ID = process.env.WA_APP_ID ?? '';
const APP_SECRET = process.env.WA_APP_SECRET ?? '';
const DEFAULT_REDIRECT =
  process.env.WA_OAUTH_REDIRECT ??
  'https://civiapp.app/oauth/whatsapp/callback';
const TOKEN_SECRET_PREFIX =
  process.env.WA_TOKEN_SECRET_PREFIX ?? 'wa-salon';
const GRAPH_TIMEOUT_MS = Number(process.env.WA_GRAPH_TIMEOUT_MS ?? 10000);

type IntegrationDoc = {
  lastCode?: unknown;
  processedCode?: unknown;
  lastProcessedCode?: unknown;
  state?: unknown;
  rawQuery?: unknown;
};

type IntegrationState = {
  redirectUri?: unknown;
};

type GraphPhoneNumber = {
  id?: string;
  display_phone_number?: string;
  verified_name?: string;
};

type GraphBusiness = {
  id?: string;
  name?: string;
};

type GraphWaba = {
  id?: string;
  name?: string;
  business?: GraphBusiness;
  phone_numbers?: GraphPhoneNumber[];
};

interface AccessTokenResponse {
  access_token?: string;
  token_type?: string;
  expires_in?: number;
}

function firstString(value: unknown): string | undefined {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }
  if (Array.isArray(value)) {
    for (const item of value) {
      const candidate = firstString(item);
      if (candidate) {
        return candidate;
      }
    }
  }
  return undefined;
}

function pickString(
  source: Record<string, unknown> | undefined,
  ...keys: string[]
): string | undefined {
  if (!source) {
    return undefined;
  }
  for (const key of keys) {
    const value = source[key];
    const extracted = firstString(value);
    if (extracted) {
      return extracted;
    }
  }
  return undefined;
}

function resolveRedirectUri(state: IntegrationState | undefined): string {
  const redirect = firstString(state?.redirectUri);
  if (redirect) {
    return redirect;
  }
  return DEFAULT_REDIRECT;
}

function secretNameForSalon(salonId: string): string {
  return `${TOKEN_SECRET_PREFIX}-${salonId}-access-token`.replace(/[^a-zA-Z0-9_-]/g, '-');
}

async function exchangeAuthorizationCode(params: {
  code: string;
  redirectUri: string;
}): Promise<AccessTokenResponse> {
  const { code, redirectUri } = params;
  const response = await axios.get<AccessTokenResponse>(
    `https://graph.facebook.com/${GRAPH_API_VERSION}/oauth/access_token`,
    {
      params: {
        client_id: APP_ID,
        client_secret: APP_SECRET,
        redirect_uri: redirectUri,
        code,
      },
      timeout: GRAPH_TIMEOUT_MS,
    },
  );

  return response.data ?? {};
}

async function fetchWhatsappAccounts(accessToken: string): Promise<GraphWaba[]> {
  const response = await axios.get<{ data?: GraphWaba[] }>(
    `https://graph.facebook.com/${GRAPH_API_VERSION}/me/owned_whatsapp_business_accounts`,
    {
      params: {
        access_token: accessToken,
        fields:
          'id,name,business{id,name},phone_numbers{id,display_phone_number,verified_name}',
      },
      timeout: GRAPH_TIMEOUT_MS,
    },
  );

  return Array.isArray(response.data?.data) ? response.data.data : [];
}

export const syncWhatsappOAuth = onDocumentWritten(
  {
    region: REGION,
    document: 'salons/{salonId}/integrations/whatsapp_oauth',
    retry: false,
  },
  async (event) => {
    const salonId = String(event.params.salonId);
    const after = event.data?.after;

    if (!after?.exists) {
      return;
    }

    if (!APP_ID || !APP_SECRET) {
      logger.error('WhatsApp app credentials missing, skipping sync', {
        salonId,
      });
      return;
    }

    const data = after.data() as IntegrationDoc;
    const lastCode = firstString(data.lastCode);

    if (!lastCode) {
      logger.warn('No authorization code to process', { salonId });
      return;
    }

    const processedCode =
      firstString(data.processedCode) ?? firstString(data.lastProcessedCode);

    if (processedCode === lastCode) {
      logger.debug('Authorization code already processed', {
        salonId,
        lastCode,
      });
      return;
    }

    const state = (data.state ?? {}) as IntegrationState | undefined;
    const redirectUri = resolveRedirectUri(state);
    const rawQuery =
      (data.rawQuery as Record<string, unknown> | undefined) ?? undefined;

    const wabaIdFromQuery = pickString(
      rawQuery,
      'wa_waba_id',
      'waba_id',
      'whatsapp_business_account_id',
    );
    const phoneNumberIdFromQuery = pickString(
      rawQuery,
      'wa_phone_number_id',
      'phone_number_id',
    );
    const displayPhoneFromQuery = pickString(
      rawQuery,
      'wa_phone_number',
      'phone_number',
      'display_phone_number',
    );
    const businessIdFromQuery = pickString(
      rawQuery,
      'wa_business_id',
      'business_id',
    );

    const integrationRef = after.ref;

    try {
      const tokenInfo = await exchangeAuthorizationCode({
        code: lastCode,
        redirectUri,
      });
      const accessToken = tokenInfo.access_token;

      if (!accessToken) {
        throw new Error('Token exchange returned no access_token');
      }

      const accounts = await fetchWhatsappAccounts(accessToken);

      let selectedWaba: GraphWaba | undefined;
      if (wabaIdFromQuery) {
        selectedWaba = accounts.find((account) => account.id === wabaIdFromQuery);
      }
      if (!selectedWaba) {
        selectedWaba = accounts[0];
      }

      const phoneNumbers = selectedWaba?.phone_numbers ?? [];
      let selectedPhone: GraphPhoneNumber | undefined;
      if (phoneNumberIdFromQuery) {
        selectedPhone = phoneNumbers.find(
          (phone) => phone.id === phoneNumberIdFromQuery,
        );
      }
      if (!selectedPhone) {
        selectedPhone = phoneNumbers[0];
      }

      const businessId = selectedWaba?.business?.id ?? businessIdFromQuery;
      const wabaId = selectedWaba?.id ?? wabaIdFromQuery;
      const phoneNumberId = selectedPhone?.id ?? phoneNumberIdFromQuery;
      const displayPhoneNumber =
        selectedPhone?.display_phone_number ?? displayPhoneFromQuery;

      if (!wabaId) {
        throw new Error('Unable to resolve WhatsApp Business Account identifier');
      }

      if (!phoneNumberId) {
        throw new Error('Unable to resolve WhatsApp phone number identifier');
      }

      const secretId = secretNameForSalon(salonId);
      const secretName = await upsertSecret(secretId, accessToken);
      clearSecretCache();

      const whatsappUpdate: Record<string, unknown> = {
        mode: 'own',
        tokenSecretId: secretName,
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (businessId) {
        whatsappUpdate.businessId = businessId;
      }
      whatsappUpdate.wabaId = wabaId;
      whatsappUpdate.phoneNumberId = phoneNumberId;
      if (displayPhoneNumber) {
        whatsappUpdate.displayPhoneNumber = displayPhoneNumber;
      }

      await db
        .collection('salons')
        .doc(salonId)
        .set({ whatsapp: whatsappUpdate }, { merge: true });

      clearWaConfigCache();

      await integrationRef.set(
        {
          processedCode: lastCode,
          processedAt: FieldValue.serverTimestamp(),
          tokenSecretId: secretName,
          wabaId,
          phoneNumberId,
          businessId,
          displayPhoneNumber,
          tokenType: tokenInfo.token_type,
          tokenExpiresIn: tokenInfo.expires_in,
          status: 'synced',
          lastError: FieldValue.delete(),
        },
        { merge: true },
      );

      logger.info('Synchronized WhatsApp configuration', {
        salonId,
        wabaId,
        phoneNumberId,
      });
    } catch (error) {
      const axiosError = error as AxiosError;
      const responseData = axiosError.response?.data;
      logger.error(
        'Failed to synchronize WhatsApp configuration',
        error instanceof Error ? error : new Error(String(error)),
        { salonId, response: responseData },
      );

      await integrationRef.set(
        {
          status: 'error',
          processedCode: lastCode,
          processedAt: FieldValue.serverTimestamp(),
          lastError: {
            message:
              error instanceof Error ? error.message : String(error),
            at: FieldValue.serverTimestamp(),
            response: responseData,
          },
        },
        { merge: true },
      );
    }
  },
);
