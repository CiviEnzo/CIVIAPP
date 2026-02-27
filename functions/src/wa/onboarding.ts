import axios, { AxiosError } from 'axios';
import { defineSecret } from 'firebase-functions/params';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';

import { FieldValue, db } from '../utils/firestore';

import { upsertSecret, clearSecretCache } from './secrets';
import { clearWaConfigCache } from './config';

const REGION = process.env.WA_REGION ?? 'europe-west1';
const GRAPH_API_VERSION = process.env.WA_GRAPH_API_VERSION ?? 'v25.0';
const DEFAULT_REDIRECT =
  process.env.WA_OAUTH_REDIRECT ??
  'https://europe-west1-civiapp-38b51.cloudfunctions.net/handleWhatsappOAuthCallback';
const TOKEN_SECRET_PREFIX =
  process.env.WA_TOKEN_SECRET_PREFIX ?? 'wa-salon';
const GRAPH_TIMEOUT_MS = Number(process.env.WA_GRAPH_TIMEOUT_MS ?? 10000);
const waAppId = defineSecret('WA_APP_ID');
const waAppSecret = defineSecret('WA_APP_SECRET');

type IntegrationDoc = {
  lastCode?: unknown;
  processedCode?: unknown;
  lastProcessedCode?: unknown;
  state?: unknown;
  rawQuery?: unknown;
  oauthSessionId?: unknown;
  requestedByUserId?: unknown;
  requestedByEmail?: unknown;
  tokenStrategy?: unknown;
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

type GraphApiErrorPayload = {
  error?: {
    code?: number;
    message?: string;
    type?: string;
  };
};

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
  appId: string;
  appSecret: string;
}): Promise<AccessTokenResponse> {
  const { code, redirectUri, appId, appSecret } = params;
  const response = await axios.get<AccessTokenResponse>(
    `https://graph.facebook.com/${GRAPH_API_VERSION}/oauth/access_token`,
    {
      params: {
        client_id: appId,
        client_secret: appSecret,
        redirect_uri: redirectUri,
        code,
      },
      timeout: GRAPH_TIMEOUT_MS,
    },
  );

  return response.data ?? {};
}

async function fetchWhatsappAccounts(accessToken: string): Promise<GraphWaba[]> {
  try {
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
  } catch (error) {
    const axiosError = error as AxiosError<GraphApiErrorPayload>;
    const graphError = axiosError.response?.data?.error;
    const message = String(graphError?.message ?? '');
    const isUserEdgeMissing =
      graphError?.code === 100 &&
      message.includes('owned_whatsapp_business_accounts');

    if (!isUserEdgeMissing) {
      throw error;
    }

    logger.warn(
      'Graph API /me/owned_whatsapp_business_accounts unavailable, falling back to /me/businesses',
      {
        graphApiVersion: GRAPH_API_VERSION,
        code: graphError?.code,
        type: graphError?.type,
        message,
      },
    );

    return fetchWhatsappAccountsViaBusinesses(accessToken);
  }
}

async function fetchWhatsappAccountsViaBusinesses(
  accessToken: string,
): Promise<GraphWaba[]> {
  const businessesResponse = await axios.get<{ data?: GraphBusiness[] }>(
    `https://graph.facebook.com/${GRAPH_API_VERSION}/me/businesses`,
    {
      params: {
        access_token: accessToken,
        fields: 'id,name',
      },
      timeout: GRAPH_TIMEOUT_MS,
    },
  );

  const businesses = Array.isArray(businessesResponse.data?.data)
    ? businessesResponse.data.data.filter((business) => typeof business.id === 'string' && business.id)
    : [];

  const results = await Promise.allSettled(
    businesses.map(async (business) => {
      const response = await axios.get<{ data?: GraphWaba[] }>(
        `https://graph.facebook.com/${GRAPH_API_VERSION}/${business.id}/owned_whatsapp_business_accounts`,
        {
          params: {
            access_token: accessToken,
            fields:
              'id,name,phone_numbers{id,display_phone_number,verified_name}',
          },
          timeout: GRAPH_TIMEOUT_MS,
        },
      );

      const accounts = Array.isArray(response.data?.data) ? response.data.data : [];
      return accounts.map((account) => ({
        ...account,
        business:
          account.business ??
          (business.id
            ? {
                id: business.id,
                name: business.name,
              }
            : undefined),
      }));
    }),
  );

  const accounts: GraphWaba[] = [];
  for (const result of results) {
    if (result.status === 'fulfilled') {
      accounts.push(...result.value);
      continue;
    }

    const axiosError = result.reason as AxiosError<GraphApiErrorPayload>;
    logger.warn('Failed to fetch WABAs for one business during fallback lookup', {
      response: axiosError.response?.data,
      message:
        axiosError instanceof Error ? axiosError.message : String(result.reason),
    });
  }

  return accounts;
}

async function fetchPhoneNumbersForWaba(params: {
  accessToken: string;
  wabaId: string;
}): Promise<GraphPhoneNumber[]> {
  const response = await axios.get<{ data?: GraphPhoneNumber[] }>(
    `https://graph.facebook.com/${GRAPH_API_VERSION}/${params.wabaId}/phone_numbers`,
    {
      params: {
        access_token: params.accessToken,
        fields: 'id,display_phone_number,verified_name',
      },
      timeout: GRAPH_TIMEOUT_MS,
    },
  );

  return Array.isArray(response.data?.data) ? response.data.data : [];
}

async function resolvePhoneNumbersForWabaCandidate(params: {
  accessToken: string;
  salonId: string;
  candidate: GraphWaba;
}): Promise<GraphPhoneNumber[]> {
  const embedded = Array.isArray(params.candidate.phone_numbers)
    ? params.candidate.phone_numbers
    : [];
  if (embedded.length > 0) {
    return embedded;
  }

  const wabaId = typeof params.candidate.id === 'string' ? params.candidate.id : '';
  if (!wabaId) {
    return [];
  }

  try {
    return await fetchPhoneNumbersForWaba({
      accessToken: params.accessToken,
      wabaId,
    });
  } catch (phoneError) {
    logger.warn('Unable to fetch phone numbers via WABA edge', {
      salonId: params.salonId,
      wabaId,
      error:
        phoneError instanceof Error ? phoneError.message : String(phoneError),
    });
    return [];
  }
}

export const syncWhatsappOAuth = onDocumentWritten(
  {
    region: REGION,
    document: 'salons/{salonId}/integrations/whatsapp_oauth',
    retry: false,
    secrets: [waAppId, waAppSecret],
  },
  async (event) => {
    const salonId = String(event.params.salonId);
    const after = event.data?.after;

    if (!after?.exists) {
      return;
    }

    const appId = waAppId.value();
    const appSecret = waAppSecret.value();

    if (!appId || !appSecret) {
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
    const oauthSessionId = firstString(data.oauthSessionId);
    const requestedByUserId = firstString(data.requestedByUserId);
    const requestedByEmail = firstString(data.requestedByEmail);
    const tokenStrategy =
      firstString(data.tokenStrategy) ?? 'optionA_meta_oauth_user_token';

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
        appId,
        appSecret,
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
        selectedWaba =
          accounts.find(
            (account) =>
              Array.isArray(account.phone_numbers) && account.phone_numbers.length > 0,
          ) ?? accounts[0];
      }

      let phoneNumbers = selectedWaba
        ? await resolvePhoneNumbersForWabaCandidate({
            accessToken,
            salonId,
            candidate: selectedWaba,
          })
        : [];

      // If Meta did not return a selected WABA/phone in the callback, prefer the first
      // accessible WABA that actually has at least one phone number.
      if (!wabaIdFromQuery && !phoneNumberIdFromQuery && phoneNumbers.length === 0) {
        for (const candidate of accounts) {
          if (candidate.id === selectedWaba?.id) {
            continue;
          }
          const candidatePhoneNumbers = await resolvePhoneNumbersForWabaCandidate({
            accessToken,
            salonId,
            candidate,
          });
          if (candidatePhoneNumbers.length > 0) {
            selectedWaba = {
              ...candidate,
              phone_numbers: candidatePhoneNumbers,
            };
            phoneNumbers = candidatePhoneNumbers;
            break;
          }
        }
      }
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
        logger.warn('No WhatsApp phone number could be resolved from accessible WABAs', {
          salonId,
          requestedWabaId: wabaIdFromQuery ?? null,
          requestedPhoneNumberId: phoneNumberIdFromQuery ?? null,
          accessibleWabaIds: accounts
            .map((account) => (typeof account.id === 'string' ? account.id : null))
            .filter((id): id is string => Boolean(id)),
          selectedWabaId: selectedWaba?.id ?? null,
        });
        throw new Error('Unable to resolve WhatsApp phone number identifier');
      }

      const secretId = secretNameForSalon(salonId);
      const secretName = await upsertSecret(secretId, accessToken);
      clearSecretCache();
      const tokenExpiresAt =
        typeof tokenInfo.expires_in === 'number' && tokenInfo.expires_in > 0
          ? new Date(Date.now() + tokenInfo.expires_in * 1000)
          : null;

      const whatsappUpdate: Record<string, unknown> = {
        mode: 'own',
        tokenSecretId: secretName,
        tokenStrategy,
        graphApiVersion: GRAPH_API_VERSION,
        tokenExpiresAt,
        connectedAt: FieldValue.serverTimestamp(),
        onboardingStatus: 'synced',
        lastOnboardingErrorMessage: FieldValue.delete(),
        lastOnboardingErrorAt: FieldValue.delete(),
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
          tokenStrategy,
          wabaId,
          phoneNumberId,
          businessId,
          displayPhoneNumber,
          graphApiVersion: GRAPH_API_VERSION,
          tokenType: tokenInfo.token_type,
          tokenExpiresIn: tokenInfo.expires_in,
          tokenExpiresAt,
          connectedAt: FieldValue.serverTimestamp(),
          connectedByUserId: requestedByUserId ?? null,
          connectedByEmail: requestedByEmail ?? null,
          status: 'synced',
          lastError: FieldValue.delete(),
        },
        { merge: true },
      );

      if (oauthSessionId) {
        await integrationRef
          .collection('sessions')
          .doc(oauthSessionId)
          .set(
            {
              status: 'processed',
              processedAt: FieldValue.serverTimestamp(),
              tokenExpiresAt,
              wabaId,
              phoneNumberId,
            },
            { merge: true },
          )
          .catch((error) => {
            logger.warn('Unable to update OAuth session status', {
              salonId,
              oauthSessionId,
              error: error instanceof Error ? error.message : String(error),
            });
          });
      }

      logger.info('Synchronized WhatsApp configuration', {
        salonId,
        wabaId,
        phoneNumberId,
      });
    } catch (error) {
      const axiosError = error as AxiosError;
      const responseData = axiosError.response?.data;
      const responsePayload = responseData ?? null;
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
            response: responsePayload,
          },
        },
        { merge: true },
      );

      await db
        .collection('salons')
        .doc(salonId)
        .set(
          {
            whatsapp: {
              onboardingStatus: 'error',
              lastOnboardingErrorMessage:
                error instanceof Error ? error.message : String(error),
              lastOnboardingErrorAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            },
          },
          { merge: true },
        )
        .catch((salonUpdateError) => {
          logger.warn('Unable to persist WhatsApp onboarding error on salon doc', {
            salonId,
            error:
              salonUpdateError instanceof Error
                ? salonUpdateError.message
                : String(salonUpdateError),
          });
        });

      if (oauthSessionId) {
        await integrationRef
          .collection('sessions')
          .doc(oauthSessionId)
          .set(
            {
              status: 'error',
              processedAt: FieldValue.serverTimestamp(),
              lastError: {
                message:
                  error instanceof Error ? error.message : String(error),
                response: responsePayload,
              },
            },
            { merge: true },
          )
          .catch(() => undefined);
      }
    }
  },
);
