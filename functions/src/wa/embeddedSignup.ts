import axios from 'axios';
import { randomBytes } from 'crypto';
import { onRequest } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import type { Request, Response } from 'express';

import { FieldValue, Timestamp, db } from '../utils/firestore';

import { requireWaSalonAdmin } from './authz';
import { clearWaConfigCache } from './config';
import {
  GRAPH_API_VERSION,
  GRAPH_TIMEOUT_MS,
  REGION,
  WhatsAppHttpError,
  type ConnectionMethod,
  extractGraphError,
  getAppId,
  getAppSecret,
  getEmbeddedSignupConfigId,
  getSystemUserAccessToken,
  getSystemUserId,
  getTokenSecretPrefix,
  isAlreadySubscribedGraphError,
  isSystemUserAlreadyAssignedError,
  isVerificationRequiredGraphError,
  normalizeString,
  sanitizePin,
  toHttpError,
} from './runtime';
import { readSecret, upsertSecret } from './secrets';

type GraphBusiness = {
  id?: string;
  name?: string;
};

type GraphPhoneNumber = {
  id?: string;
  display_phone_number?: string;
  verified_name?: string;
};

type GraphWaba = {
  id?: string;
  name?: string;
  business?: GraphBusiness;
  phone_numbers?: GraphPhoneNumber[];
};

type EmbeddedSignupSessionState =
  | 'session_created'
  | 'signup_completed'
  | 'registering'
  | 'awaiting_verification'
  | 'ready'
  | 'error';

type EmbeddedSignupSessionDoc = {
  salonId?: unknown;
  sessionToken?: unknown;
  state?: unknown;
  createdAt?: unknown;
  expiresAt?: unknown;
  redirectUri?: unknown;
  createdByUserId?: unknown;
  createdByEmail?: unknown;
  code?: unknown;
  businessId?: unknown;
  wabaId?: unknown;
  phoneNumberId?: unknown;
  displayPhoneNumber?: unknown;
  verifiedName?: unknown;
  exchangeResponse?: unknown;
  lastCodeMethod?: unknown;
  lastCodeRequestedAt?: unknown;
};

type IntegrationDoc = {
  activeSessionId?: unknown;
};

type CreateSessionBody = {
  salonId?: unknown;
  redirectUri?: unknown;
};

type ManualSetupBody = {
  salonId?: unknown;
  accessToken?: unknown;
  businessId?: unknown;
  wabaId?: unknown;
  phoneNumberId?: unknown;
  displayPhoneNumber?: unknown;
  pin?: unknown;
};

type CompleteSignupBody = {
  salonId?: unknown;
  sessionId?: unknown;
  sessionToken?: unknown;
  code?: unknown;
  pin?: unknown;
  businessId?: unknown;
  wabaId?: unknown;
  phoneNumberId?: unknown;
  displayPhoneNumber?: unknown;
};

type RequestCodeBody = {
  salonId?: unknown;
  sessionId?: unknown;
  codeMethod?: unknown;
  locale?: unknown;
};

type ConfirmCodeBody = {
  salonId?: unknown;
  sessionId?: unknown;
  verificationCode?: unknown;
  pin?: unknown;
};

type CodeExchangeResponse = {
  access_token?: string;
  token_type?: string;
  expires_in?: number;
};

type ResolvedPhoneSelection = {
  businessId: string;
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber?: string;
  verifiedName?: string;
};

const SESSION_TTL_MS = Number(
  process.env.WA_EMBEDDED_SIGNUP_SESSION_TTL_MS ?? String(24 * 60 * 60 * 1000),
);

function jsonError(response: Response, error: unknown): void {
  const httpError = toHttpError(error);
  response.set('Access-Control-Allow-Origin', '*');
  response.status(httpError.statusCode).json({
    success: false,
    error: httpError.message,
    code: httpError.code,
    details: httpError.details ?? null,
  });
}

function ensureJsonBody<T>(body: unknown): T {
  if (typeof body !== 'object' || body === null) {
    throw new WhatsAppHttpError('Invalid request body', 400, 'invalid_body');
  }
  return body as T;
}

function embeddedSignupIntegrationRef(salonId: string) {
  return db
    .collection('salons')
    .doc(salonId)
    .collection('integrations')
    .doc('whatsapp_embedded_signup');
}

function embeddedSignupSessionRef(salonId: string, sessionId: string) {
  return embeddedSignupIntegrationRef(salonId)
    .collection('sessions')
    .doc(sessionId);
}

function generateOpaqueToken(bytes = 24): string {
  return randomBytes(bytes)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function parseSessionState(value: unknown): EmbeddedSignupSessionState {
  const normalized = normalizeString(value) ?? 'session_created';
  switch (normalized) {
    case 'session_created':
    case 'signup_completed':
    case 'registering':
    case 'awaiting_verification':
    case 'ready':
    case 'error':
      return normalized;
    default:
      return 'session_created';
  }
}

function parseTimestamp(value: unknown): Date | null {
  if (value instanceof Date) {
    return value;
  }
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.valueOf()) ? null : parsed;
  }
  if (typeof value === 'object' && value !== null && 'toDate' in value) {
    try {
      const parsed = (value as { toDate: () => Date }).toDate();
      return parsed instanceof Date ? parsed : null;
    } catch (_) {
      return null;
    }
  }
  return null;
}

function parseSessionDoc(
  salonId: string,
  sessionId: string,
  data: EmbeddedSignupSessionDoc,
) {
  return {
    salonId: normalizeString(data.salonId) ?? salonId,
    sessionId,
    sessionToken: normalizeString(data.sessionToken),
    state: parseSessionState(data.state),
    expiresAt: parseTimestamp(data.expiresAt),
    redirectUri: normalizeString(data.redirectUri) ?? undefined,
    createdByUserId: normalizeString(data.createdByUserId) ?? undefined,
    createdByEmail: normalizeString(data.createdByEmail) ?? undefined,
    code: normalizeString(data.code) ?? undefined,
    businessId: normalizeString(data.businessId) ?? undefined,
    wabaId: normalizeString(data.wabaId) ?? undefined,
    phoneNumberId: normalizeString(data.phoneNumberId) ?? undefined,
    displayPhoneNumber: normalizeString(data.displayPhoneNumber) ?? undefined,
    verifiedName: normalizeString(data.verifiedName) ?? undefined,
    lastCodeMethod: normalizeString(data.lastCodeMethod) ?? undefined,
  };
}

function parseSalonId(value: unknown): string {
  const salonId = normalizeString(value);
  if (!salonId) {
    throw new WhatsAppHttpError('Missing salonId', 400, 'missing_salon_id');
  }
  return salonId;
}

function parseSessionId(value: unknown): string {
  const sessionId = normalizeString(value);
  if (!sessionId) {
    throw new WhatsAppHttpError('Missing sessionId', 400, 'missing_session_id');
  }
  return sessionId;
}

function parseSessionToken(value: unknown): string {
  const sessionToken = normalizeString(value);
  if (!sessionToken) {
    throw new WhatsAppHttpError(
      'Missing sessionToken',
      400,
      'missing_session_token',
    );
  }
  return sessionToken;
}

function parseVerificationCode(value: unknown): string {
  const verificationCode = normalizeString(value);
  if (!verificationCode || !/^\d{4,8}$/.test(verificationCode)) {
    throw new WhatsAppHttpError(
      'Codice di verifica non valido.',
      400,
      'invalid_verification_code',
    );
  }
  return verificationCode;
}

function parseCodeMethod(value: unknown): 'SMS' | 'VOICE' {
  const normalized = (normalizeString(value) ?? 'SMS').toUpperCase();
  if (normalized === 'VOICE') {
    return 'VOICE';
  }
  return 'SMS';
}

function parseLocale(value: unknown): string {
  return normalizeString(value) ?? 'it_IT';
}

function resolveGraphAccessToken(accessToken?: string): string {
  return accessToken ?? getSystemUserAccessToken();
}

function buildSalonTokenSecretId(salonId: string): string {
  const prefix = getTokenSecretPrefix();
  const normalizedSalonId =
    salonId
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_-]+/g, '-')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '') || 'salon';
  return `${prefix}-${normalizedSalonId}-access-token`;
}

async function graphGet<T>(
  path: string,
  params: Record<string, unknown> = {},
  accessToken?: string,
): Promise<T> {
  const response = await axios.get<T>(
    `https://graph.facebook.com/${GRAPH_API_VERSION}/${path}`,
    {
      params,
      headers: {
        Authorization: `Bearer ${resolveGraphAccessToken(accessToken)}`,
      },
      timeout: GRAPH_TIMEOUT_MS,
    },
  );
  return response.data;
}

async function graphPost<T>(
  path: string,
  body: Record<string, unknown> = {},
  accessToken?: string,
): Promise<T> {
  const response = await axios.post<T>(
    `https://graph.facebook.com/${GRAPH_API_VERSION}/${path}`,
    body,
    {
      headers: {
        Authorization: `Bearer ${resolveGraphAccessToken(accessToken)}`,
        'Content-Type': 'application/json',
      },
      timeout: GRAPH_TIMEOUT_MS,
    },
  );
  return response.data;
}

async function exchangeCodeIfPossible(params: {
  code: string;
  redirectUri?: string;
}): Promise<CodeExchangeResponse | null> {
  const appId = getAppId();
  const appSecret = getAppSecret();

  try {
    const response = await axios.get<CodeExchangeResponse>(
      `https://graph.facebook.com/${GRAPH_API_VERSION}/oauth/access_token`,
      {
        params: {
          client_id: appId,
          client_secret: appSecret,
          code: params.code,
          ...(params.redirectUri ? { redirect_uri: params.redirectUri } : {}),
        },
        timeout: GRAPH_TIMEOUT_MS,
      },
    );
    return response.data ?? null;
  } catch (error) {
    logger.warn('Unable to exchange Embedded Signup code', {
      redirectUri: params.redirectUri ?? null,
      error: error instanceof Error ? error.message : String(error),
      response: extractGraphError(error)?.payload ?? null,
    });
    return null;
  }
}

async function fetchWabaById(
  wabaId: string,
  accessToken?: string,
): Promise<GraphWaba> {
  return graphGet<GraphWaba>(wabaId, {
    fields:
      'id,name,business{id,name},phone_numbers{id,display_phone_number,verified_name}',
  }, accessToken);
}

async function resolvePhoneSelection(params: {
  requestedBusinessId?: string;
  requestedWabaId?: string;
  requestedPhoneNumberId?: string;
  requestedDisplayPhoneNumber?: string;
}, accessToken?: string): Promise<ResolvedPhoneSelection> {
  const wabaId = normalizeString(params.requestedWabaId);
  if (!wabaId) {
    throw new WhatsAppHttpError(
      'Embedded Signup non ha restituito un WABA valido.',
      400,
      'missing_waba_id',
    );
  }

  const waba = await fetchWabaById(wabaId, accessToken);
  const resolvedWabaId = normalizeString(waba.id);
  if (!resolvedWabaId) {
    throw new WhatsAppHttpError(
      'Impossibile leggere il WABA selezionato da Meta.',
      400,
      'invalid_waba',
    );
  }

  const availablePhones = Array.isArray(waba.phone_numbers)
    ? waba.phone_numbers
    : [];
  const requestedPhoneNumberId = normalizeString(params.requestedPhoneNumberId);
  const selectedPhone =
    availablePhones.find((phone) => normalizeString(phone.id) === requestedPhoneNumberId) ??
    availablePhones[0];

  const phoneNumberId =
    normalizeString(selectedPhone?.id) ?? requestedPhoneNumberId;
  if (!phoneNumberId) {
    throw new WhatsAppHttpError(
      'Meta non ha restituito un numero WhatsApp valido per il WABA selezionato.',
      400,
      'missing_phone_number_id',
    );
  }

  const businessId =
    normalizeString(waba.business?.id) ??
    normalizeString(params.requestedBusinessId);
  if (!businessId) {
    throw new WhatsAppHttpError(
      'Impossibile determinare il Business Manager associato al numero selezionato.',
      400,
      'missing_business_id',
    );
  }

  return {
    businessId,
    wabaId: resolvedWabaId,
    phoneNumberId,
    displayPhoneNumber:
      normalizeString(selectedPhone?.display_phone_number) ??
      normalizeString(params.requestedDisplayPhoneNumber) ??
      undefined,
    verifiedName: normalizeString(selectedPhone?.verified_name) ?? undefined,
  };
}

async function assignSystemUserToWaba(wabaId: string): Promise<void> {
  try {
    await graphPost(`${wabaId}/assigned_users`, {
      user: getSystemUserId(),
      tasks: ['MANAGE'],
    });
  } catch (error) {
    if (isSystemUserAlreadyAssignedError(error)) {
      logger.info('System user already assigned to WABA', { wabaId });
      return;
    }
    throw error;
  }
}

async function subscribeAppToWaba(
  wabaId: string,
  accessToken?: string,
): Promise<void> {
  try {
    await graphPost(`${wabaId}/subscribed_apps`, {}, accessToken);
  } catch (error) {
    if (isAlreadySubscribedGraphError(error)) {
      logger.info('App already subscribed to WABA', { wabaId });
      return;
    }
    throw error;
  }
}

async function registerPhoneNumber(params: {
  phoneNumberId: string;
  pin: string;
  accessToken?: string;
}): Promise<void> {
  await graphPost(`${params.phoneNumberId}/register`, {
    messaging_product: 'whatsapp',
    pin: params.pin,
  }, params.accessToken);
}

async function requestPhoneVerificationCode(params: {
  phoneNumberId: string;
  codeMethod: 'SMS' | 'VOICE';
  locale: string;
  accessToken?: string;
}): Promise<void> {
  await graphPost(`${params.phoneNumberId}/request_code`, {
    code_method: params.codeMethod,
    locale: params.locale,
  }, params.accessToken);
}

async function verifyPhoneCode(params: {
  phoneNumberId: string;
  verificationCode: string;
  accessToken?: string;
}): Promise<void> {
  await graphPost(`${params.phoneNumberId}/verify_code`, {
    code: params.verificationCode,
  }, params.accessToken);
}

async function updateSalonWhatsappState(
  salonId: string,
  patch: Record<string, unknown>,
): Promise<void> {
  await db
    .collection('salons')
    .doc(salonId)
    .set(
      {
        whatsapp: {
          ...patch,
          updatedAt: FieldValue.serverTimestamp(),
        },
      },
      { merge: true },
    );
  clearWaConfigCache();
}

async function loadManualSetupState(salonId: string): Promise<{
  resolved: ResolvedPhoneSelection;
  accessToken: string;
  tokenSecretId: string;
}> {
  const snapshot = await db.collection('salons').doc(salonId).get();
  if (!snapshot.exists) {
    throw new WhatsAppHttpError('Salone non trovato.', 404, 'salon_not_found');
  }

  const data = snapshot.data() as { whatsapp?: Record<string, unknown> } | undefined;
  const whatsapp = data?.whatsapp;
  const connectionMethod = normalizeString(whatsapp?.connectionMethod);
  if (connectionMethod !== 'manual_setup') {
    throw new WhatsAppHttpError(
      'Il salone non e configurato con setup manuale WhatsApp.',
      409,
      'manual_setup_not_configured',
    );
  }

  const tokenSecretId = normalizeString(whatsapp?.tokenSecretId);
  const businessId = normalizeString(whatsapp?.businessId);
  const wabaId = normalizeString(whatsapp?.wabaId);
  const phoneNumberId = normalizeString(whatsapp?.phoneNumberId);
  const displayPhoneNumber = normalizeString(whatsapp?.displayPhoneNumber);

  if (!tokenSecretId || !businessId || !wabaId || !phoneNumberId) {
    throw new WhatsAppHttpError(
      'Configurazione manuale WhatsApp incompleta. Inserisci token, WABA e numero prima di continuare.',
      409,
      'manual_setup_incomplete',
    );
  }

  return {
    resolved: {
      businessId,
      wabaId,
      phoneNumberId,
      displayPhoneNumber: displayPhoneNumber ?? undefined,
    },
    accessToken: await readSecret(tokenSecretId),
    tokenSecretId,
  };
}

async function markSalonRegistering(params: {
  salonId: string;
  resolved: ResolvedPhoneSelection;
  connectionMethod?: ConnectionMethod;
  tokenSecretId?: string;
  verifyTokenSecretId?: string;
}): Promise<void> {
  await updateSalonWhatsappState(params.salonId, {
    mode: 'own',
    businessId: params.resolved.businessId,
    wabaId: params.resolved.wabaId,
    phoneNumberId: params.resolved.phoneNumberId,
    displayPhoneNumber: params.resolved.displayPhoneNumber ?? FieldValue.delete(),
    connectionMethod: params.connectionMethod ?? 'embedded_signup',
    requiresReconnect: false,
    onboardingStatus: 'registering',
    registrationStatus: 'pending',
    registeredAt: FieldValue.delete(),
    lastRegistrationErrorMessage: FieldValue.delete(),
    lastRegistrationErrorAt: FieldValue.delete(),
    lastOnboardingErrorMessage: FieldValue.delete(),
    lastOnboardingErrorAt: FieldValue.delete(),
    lastCodeMethod: FieldValue.delete(),
    lastCodeRequestedAt: FieldValue.delete(),
    tokenSecretId: params.tokenSecretId ?? FieldValue.delete(),
    verifyTokenSecretId: params.verifyTokenSecretId ?? FieldValue.delete(),
    graphApiVersion: GRAPH_API_VERSION,
  });
}

async function markSalonVerificationRequired(params: {
  salonId: string;
  resolved: ResolvedPhoneSelection;
  message?: string;
  connectionMethod?: ConnectionMethod;
  tokenSecretId?: string;
  verifyTokenSecretId?: string;
}): Promise<void> {
  await updateSalonWhatsappState(params.salonId, {
    mode: 'own',
    businessId: params.resolved.businessId,
    wabaId: params.resolved.wabaId,
    phoneNumberId: params.resolved.phoneNumberId,
    displayPhoneNumber: params.resolved.displayPhoneNumber ?? FieldValue.delete(),
    connectionMethod: params.connectionMethod ?? 'embedded_signup',
    requiresReconnect: false,
    onboardingStatus: 'awaiting_verification',
    registrationStatus: 'verification_required',
    lastRegistrationErrorMessage: params.message ?? FieldValue.delete(),
    lastRegistrationErrorAt:
      params.message != null
        ? FieldValue.serverTimestamp()
        : FieldValue.delete(),
    tokenSecretId: params.tokenSecretId ?? FieldValue.delete(),
    verifyTokenSecretId: params.verifyTokenSecretId ?? FieldValue.delete(),
    graphApiVersion: GRAPH_API_VERSION,
  });
}

async function markSalonReady(params: {
  salonId: string;
  resolved: ResolvedPhoneSelection;
  connectionMethod?: ConnectionMethod;
  tokenSecretId?: string;
  verifyTokenSecretId?: string;
}): Promise<void> {
  await updateSalonWhatsappState(params.salonId, {
    mode: 'own',
    businessId: params.resolved.businessId,
    wabaId: params.resolved.wabaId,
    phoneNumberId: params.resolved.phoneNumberId,
    displayPhoneNumber: params.resolved.displayPhoneNumber ?? FieldValue.delete(),
    connectionMethod: params.connectionMethod ?? 'embedded_signup',
    requiresReconnect: false,
    onboardingStatus: 'ready',
    registrationStatus: 'registered',
    connectedAt: FieldValue.serverTimestamp(),
    registeredAt: FieldValue.serverTimestamp(),
    lastRegistrationErrorMessage: FieldValue.delete(),
    lastRegistrationErrorAt: FieldValue.delete(),
    lastOnboardingErrorMessage: FieldValue.delete(),
    lastOnboardingErrorAt: FieldValue.delete(),
    lastCodeMethod: FieldValue.delete(),
    lastCodeRequestedAt: FieldValue.delete(),
    tokenSecretId: params.tokenSecretId ?? FieldValue.delete(),
    verifyTokenSecretId: params.verifyTokenSecretId ?? FieldValue.delete(),
    graphApiVersion: GRAPH_API_VERSION,
  });
}

async function markSalonError(params: {
  salonId: string;
  resolved?: Partial<ResolvedPhoneSelection>;
  message: string;
  connectionMethod?: ConnectionMethod;
  tokenSecretId?: string;
  verifyTokenSecretId?: string;
}): Promise<void> {
  const patch: Record<string, unknown> = {
    connectionMethod: params.connectionMethod ?? 'embedded_signup',
    requiresReconnect: false,
    onboardingStatus: 'error',
    registrationStatus: 'error',
    lastRegistrationErrorMessage: params.message,
    lastRegistrationErrorAt: FieldValue.serverTimestamp(),
    lastOnboardingErrorMessage: params.message,
    lastOnboardingErrorAt: FieldValue.serverTimestamp(),
    tokenSecretId: params.tokenSecretId ?? FieldValue.delete(),
    verifyTokenSecretId: params.verifyTokenSecretId ?? FieldValue.delete(),
    graphApiVersion: GRAPH_API_VERSION,
  };
  if (params.resolved?.businessId) {
    patch.businessId = params.resolved.businessId;
  }
  if (params.resolved?.wabaId) {
    patch.wabaId = params.resolved.wabaId;
  }
  if (params.resolved?.phoneNumberId) {
    patch.phoneNumberId = params.resolved.phoneNumberId;
  }
  if (params.resolved?.displayPhoneNumber) {
    patch.displayPhoneNumber = params.resolved.displayPhoneNumber;
  }
  await updateSalonWhatsappState(params.salonId, {
    ...patch,
  });
}

async function updateSessionState(params: {
  salonId: string;
  sessionId: string;
  state: EmbeddedSignupSessionState;
  data?: Record<string, unknown>;
}): Promise<void> {
  const integrationRef = embeddedSignupIntegrationRef(params.salonId);
  const sessionRef = embeddedSignupSessionRef(params.salonId, params.sessionId);

  await sessionRef.set(
    {
      state: params.state,
      ...(params.data ?? {}),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await integrationRef.set(
    {
      lastSessionId: params.sessionId,
      activeSessionId:
        params.state === 'ready' ? FieldValue.delete() : params.sessionId,
      currentStatus: params.state,
      updatedAt: FieldValue.serverTimestamp(),
      ...(params.data?.wabaId ? { wabaId: params.data.wabaId } : {}),
      ...(params.data?.phoneNumberId
        ? { phoneNumberId: params.data.phoneNumberId }
        : {}),
      ...(params.data?.businessId
        ? { businessId: params.data.businessId }
        : {}),
      ...(params.data?.displayPhoneNumber
        ? { displayPhoneNumber: params.data.displayPhoneNumber }
        : {}),
    },
    { merge: true },
  );
}

async function loadSession(params: {
  salonId: string;
  sessionId?: string;
  sessionToken?: string;
  requireToken?: boolean;
  allowedStates?: EmbeddedSignupSessionState[];
}): Promise<ReturnType<typeof parseSessionDoc>> {
  const integrationRef = embeddedSignupIntegrationRef(params.salonId);
  let sessionId = params.sessionId;
  if (!sessionId) {
    const integrationSnapshot = await integrationRef.get();
    const integrationData = (integrationSnapshot.data() ?? {}) as IntegrationDoc;
    sessionId = normalizeString(integrationData.activeSessionId) ?? undefined;
  }
  if (!sessionId) {
    throw new WhatsAppHttpError(
      'Nessuna sessione Embedded Signup attiva per questo salone.',
      409,
      'missing_active_session',
    );
  }

  const snapshot = await embeddedSignupSessionRef(params.salonId, sessionId).get();
  if (!snapshot.exists) {
    throw new WhatsAppHttpError(
      'Sessione Embedded Signup non trovata o scaduta.',
      404,
      'session_not_found',
    );
  }

  const session = parseSessionDoc(
    params.salonId,
    sessionId,
    snapshot.data() as EmbeddedSignupSessionDoc,
  );

  if (session.expiresAt && session.expiresAt.getTime() < Date.now()) {
    throw new WhatsAppHttpError(
      'La sessione Embedded Signup e scaduta. Avvia di nuovo il collegamento.',
      410,
      'session_expired',
    );
  }

  if (params.requireToken) {
    if (!session.sessionToken || session.sessionToken !== params.sessionToken) {
      throw new WhatsAppHttpError(
        'Session token non valido per Embedded Signup.',
        403,
        'invalid_session_token',
      );
    }
  }

  if (
    params.allowedStates != null &&
    params.allowedStates.length > 0 &&
    !params.allowedStates.includes(session.state)
  ) {
    throw new WhatsAppHttpError(
      `La sessione Embedded Signup non e nello stato corretto (${session.state}).`,
      409,
      'invalid_session_state',
      { state: session.state },
    );
  }

  return session;
}

export const configureWhatsappManualSetup = onRequest(
  { region: REGION, cors: true, maxInstances: 10 },
  async (request: Request, response: Response) => {
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Origin', '*');
      response.set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization',
      );
      response.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      response.status(204).send('');
      return;
    }

    if (request.method !== 'POST') {
      jsonError(response, new WhatsAppHttpError('Method Not Allowed', 405));
      return;
    }

    try {
      const body = ensureJsonBody<ManualSetupBody>(request.body);
      const salonId = parseSalonId(body.salonId);
      const user = await requireWaSalonAdmin(request, response, salonId);
      if (!user) {
        return;
      }

      const accessToken = normalizeString(body.accessToken);
      if (!accessToken) {
        throw new WhatsAppHttpError(
          'Inserisci un access token WhatsApp valido.',
          400,
          'missing_access_token',
        );
      }

      const pinRaw = normalizeString(body.pin);
      const pin = pinRaw != null ? sanitizePin(pinRaw) : null;
      const resolved = await resolvePhoneSelection(
        {
          requestedBusinessId: normalizeString(body.businessId) ?? undefined,
          requestedWabaId: normalizeString(body.wabaId) ?? undefined,
          requestedPhoneNumberId:
            normalizeString(body.phoneNumberId) ?? undefined,
          requestedDisplayPhoneNumber:
            normalizeString(body.displayPhoneNumber) ?? undefined,
        },
        accessToken,
      );
      const tokenSecretId = await upsertSecret(
        buildSalonTokenSecretId(salonId),
        accessToken,
      );

      await subscribeAppToWaba(resolved.wabaId, accessToken);

      if (pin != null) {
        await markSalonRegistering({
          salonId,
          resolved,
          connectionMethod: 'manual_setup',
          tokenSecretId,
        });

        try {
          await registerPhoneNumber({
            phoneNumberId: resolved.phoneNumberId,
            pin,
            accessToken,
          });
        } catch (error) {
          if (isVerificationRequiredGraphError(error)) {
            const message =
              extractGraphError(error)?.message ??
              'Meta richiede la verifica del numero prima della registrazione.';
            await markSalonVerificationRequired({
              salonId,
              resolved,
              message,
              connectionMethod: 'manual_setup',
              tokenSecretId,
            });
            response.set('Access-Control-Allow-Origin', '*');
            response.status(200).json({
              success: true,
              nextStep: 'verification_required',
              onboardingStatus: 'awaiting_verification',
              registrationStatus: 'verification_required',
              phoneNumberId: resolved.phoneNumberId,
              displayPhoneNumber: resolved.displayPhoneNumber ?? null,
            });
            return;
          }
          throw error;
        }
      }

      await markSalonReady({
        salonId,
        resolved,
        connectionMethod: 'manual_setup',
        tokenSecretId,
      });

      response.set('Access-Control-Allow-Origin', '*');
      response.status(200).json({
        success: true,
        nextStep: 'ready',
        onboardingStatus: 'ready',
        registrationStatus: 'registered',
        phoneNumberId: resolved.phoneNumberId,
        displayPhoneNumber: resolved.displayPhoneNumber ?? null,
      });
    } catch (error) {
      const body = request.body as ManualSetupBody | undefined;
      const salonId = normalizeString(body?.salonId);
      if (salonId) {
        const message = toHttpError(error).message;
        await markSalonError({
          salonId,
          message,
          connectionMethod: 'manual_setup',
          resolved: {
            businessId: normalizeString(body?.businessId) ?? undefined,
            wabaId: normalizeString(body?.wabaId) ?? undefined,
            phoneNumberId: normalizeString(body?.phoneNumberId) ?? undefined,
            displayPhoneNumber:
              normalizeString(body?.displayPhoneNumber) ?? undefined,
          },
        }).catch(() => undefined);
      }
      jsonError(response, error);
    }
  },
);

export const createWhatsappEmbeddedSignupSession = onRequest(
  { region: REGION, cors: true, maxInstances: 10 },
  async (request: Request, response: Response) => {
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Origin', '*');
      response.set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization',
      );
      response.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      response.status(204).send('');
      return;
    }

    if (request.method !== 'POST') {
      jsonError(response, new WhatsAppHttpError('Method Not Allowed', 405));
      return;
    }

    try {
      const body = ensureJsonBody<CreateSessionBody>(request.body);
      const salonId = parseSalonId(body.salonId);
      const user = await requireWaSalonAdmin(request, response, salonId);
      if (!user) {
        return;
      }

      const sessionId = generateOpaqueToken(18);
      const sessionToken = generateOpaqueToken(32);
      const redirectUri = normalizeString(body.redirectUri) ?? undefined;

      await embeddedSignupSessionRef(salonId, sessionId).set(
        {
          salonId,
          sessionToken,
          state: 'session_created',
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          expiresAt: new Date(Date.now() + SESSION_TTL_MS),
          redirectUri: redirectUri ?? null,
          createdByUserId: user.uid,
          createdByEmail: user.email ?? null,
        },
        { merge: true },
      );

      await embeddedSignupIntegrationRef(salonId).set(
        {
          activeSessionId: sessionId,
          lastSessionId: sessionId,
          currentStatus: 'session_created',
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      response.set('Access-Control-Allow-Origin', '*');
      response.status(200).json({
        success: true,
        sessionId,
        sessionToken,
        appId: getAppId(),
        configId: getEmbeddedSignupConfigId(),
        graphApiVersion: GRAPH_API_VERSION,
      });
    } catch (error) {
      jsonError(response, error);
    }
  },
);

export const completeWhatsappEmbeddedSignup = onRequest(
  { region: REGION, cors: true, maxInstances: 10 },
  async (request: Request, response: Response) => {
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Origin', '*');
      response.set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization',
      );
      response.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      response.status(204).send('');
      return;
    }

    if (request.method !== 'POST') {
      jsonError(response, new WhatsAppHttpError('Method Not Allowed', 405));
      return;
    }

    try {
      const body = ensureJsonBody<CompleteSignupBody>(request.body);
      const salonId = parseSalonId(body.salonId);
      const sessionId = parseSessionId(body.sessionId);
      const sessionToken = parseSessionToken(body.sessionToken);
      const code = normalizeString(body.code);
      if (!code) {
        throw new WhatsAppHttpError('Missing code', 400, 'missing_code');
      }
      const pin = sanitizePin(body.pin);
      const user = await requireWaSalonAdmin(request, response, salonId);
      if (!user) {
        return;
      }

      const session = await loadSession({
        salonId,
        sessionId,
        sessionToken,
        requireToken: true,
        allowedStates: ['session_created', 'error'],
      });

      const exchangeResponse = await exchangeCodeIfPossible({
        code,
        redirectUri: session.redirectUri,
      });

      const resolved = await resolvePhoneSelection({
        requestedBusinessId: normalizeString(body.businessId) ?? session.businessId,
        requestedWabaId: normalizeString(body.wabaId) ?? session.wabaId,
        requestedPhoneNumberId:
          normalizeString(body.phoneNumberId) ?? session.phoneNumberId,
        requestedDisplayPhoneNumber:
          normalizeString(body.displayPhoneNumber) ?? session.displayPhoneNumber,
      });

      await updateSessionState({
        salonId,
        sessionId,
        state: 'signup_completed',
        data: {
          code,
          exchangeResponse: exchangeResponse ?? null,
          businessId: resolved.businessId,
          wabaId: resolved.wabaId,
          phoneNumberId: resolved.phoneNumberId,
          displayPhoneNumber: resolved.displayPhoneNumber ?? null,
          verifiedName: resolved.verifiedName ?? null,
          completedByUserId: user.uid,
          completedByEmail: user.email ?? null,
          signupCompletedAt: FieldValue.serverTimestamp(),
        },
      });

      await markSalonRegistering({ salonId, resolved });
      await updateSessionState({
        salonId,
        sessionId,
        state: 'registering',
        data: {
          businessId: resolved.businessId,
          wabaId: resolved.wabaId,
          phoneNumberId: resolved.phoneNumberId,
          displayPhoneNumber: resolved.displayPhoneNumber ?? null,
        },
      });

      await assignSystemUserToWaba(resolved.wabaId);
      await subscribeAppToWaba(resolved.wabaId);

      try {
        await registerPhoneNumber({
          phoneNumberId: resolved.phoneNumberId,
          pin,
        });
      } catch (error) {
        if (isVerificationRequiredGraphError(error)) {
          const message =
            extractGraphError(error)?.message ??
            'Meta richiede la verifica del numero prima della registrazione.';
          await markSalonVerificationRequired({
            salonId,
            resolved,
            message,
          });
          await updateSessionState({
            salonId,
            sessionId,
            state: 'awaiting_verification',
            data: {
              businessId: resolved.businessId,
              wabaId: resolved.wabaId,
              phoneNumberId: resolved.phoneNumberId,
              displayPhoneNumber: resolved.displayPhoneNumber ?? null,
              lastError: {
                message,
                at: FieldValue.serverTimestamp(),
              },
            },
          });
          response.set('Access-Control-Allow-Origin', '*');
          response.status(200).json({
            success: true,
            nextStep: 'verification_required',
            onboardingStatus: 'awaiting_verification',
            registrationStatus: 'verification_required',
            phoneNumberId: resolved.phoneNumberId,
            displayPhoneNumber: resolved.displayPhoneNumber ?? null,
            sessionId,
          });
          return;
        }
        throw error;
      }

      await markSalonReady({ salonId, resolved });
      await updateSessionState({
        salonId,
        sessionId,
        state: 'ready',
        data: {
          businessId: resolved.businessId,
          wabaId: resolved.wabaId,
          phoneNumberId: resolved.phoneNumberId,
          displayPhoneNumber: resolved.displayPhoneNumber ?? null,
          registeredAt: FieldValue.serverTimestamp(),
        },
      });

      response.set('Access-Control-Allow-Origin', '*');
      response.status(200).json({
        success: true,
        nextStep: 'ready',
        onboardingStatus: 'ready',
        registrationStatus: 'registered',
        phoneNumberId: resolved.phoneNumberId,
        displayPhoneNumber: resolved.displayPhoneNumber ?? null,
        sessionId,
      });
    } catch (error) {
      const body = request.body as CompleteSignupBody | undefined;
      const salonId = normalizeString(body?.salonId);
      const sessionId = normalizeString(body?.sessionId);
      if (salonId && sessionId) {
        const message = toHttpError(error).message;
        await markSalonError({
          salonId,
          message,
          resolved: {
            businessId: normalizeString(body?.businessId) ?? undefined,
            wabaId: normalizeString(body?.wabaId) ?? undefined,
            phoneNumberId: normalizeString(body?.phoneNumberId) ?? undefined,
            displayPhoneNumber:
              normalizeString(body?.displayPhoneNumber) ?? undefined,
          },
        }).catch(() => undefined);
        await updateSessionState({
          salonId,
          sessionId,
          state: 'error',
          data: {
            lastError: {
              message,
              at: FieldValue.serverTimestamp(),
            },
          },
        }).catch(() => undefined);
      }
      jsonError(response, error);
    }
  },
);

export const requestWhatsappPhoneVerificationCode = onRequest(
  { region: REGION, cors: true, maxInstances: 10 },
  async (request: Request, response: Response) => {
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Origin', '*');
      response.set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization',
      );
      response.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      response.status(204).send('');
      return;
    }

    if (request.method !== 'POST') {
      jsonError(response, new WhatsAppHttpError('Method Not Allowed', 405));
      return;
    }

    try {
      const body = ensureJsonBody<RequestCodeBody>(request.body);
      const salonId = parseSalonId(body.salonId);
      const user = await requireWaSalonAdmin(request, response, salonId);
      if (!user) {
        return;
      }

      const requestedSessionId = normalizeString(body.sessionId) ?? undefined;
      const codeMethod = parseCodeMethod(body.codeMethod);
      const locale = parseLocale(body.locale);

      if (!requestedSessionId) {
        const manualSetup = await loadManualSetupState(salonId);
        await requestPhoneVerificationCode({
          phoneNumberId: manualSetup.resolved.phoneNumberId,
          codeMethod,
          locale,
          accessToken: manualSetup.accessToken,
        });

        await updateSalonWhatsappState(salonId, {
          connectionMethod: 'manual_setup',
          requiresReconnect: false,
          onboardingStatus: 'awaiting_verification',
          registrationStatus: 'verification_required',
          lastCodeMethod: codeMethod,
          lastCodeRequestedAt: FieldValue.serverTimestamp(),
          lastRegistrationErrorMessage: FieldValue.delete(),
          lastRegistrationErrorAt: FieldValue.delete(),
          tokenSecretId: manualSetup.tokenSecretId,
        });

        response.set('Access-Control-Allow-Origin', '*');
        response.status(200).json({
          success: true,
          codeMethod,
          onboardingStatus: 'awaiting_verification',
          registrationStatus: 'verification_required',
          phoneNumberId: manualSetup.resolved.phoneNumberId,
          displayPhoneNumber:
            manualSetup.resolved.displayPhoneNumber ?? null,
        });
        return;
      }

      const session = await loadSession({
        salonId,
        sessionId: requestedSessionId,
        allowedStates: ['awaiting_verification'],
      });

      if (!session.phoneNumberId) {
        throw new WhatsAppHttpError(
          'Sessione senza phoneNumberId attivo.',
          409,
          'missing_phone_number_id',
        );
      }

      await requestPhoneVerificationCode({
        phoneNumberId: session.phoneNumberId,
        codeMethod,
        locale,
      });

      await updateSessionState({
        salonId,
        sessionId: session.sessionId,
        state: 'awaiting_verification',
        data: {
          lastCodeMethod: codeMethod,
          lastCodeRequestedAt: FieldValue.serverTimestamp(),
          requestedByUserId: user.uid,
          requestedByEmail: user.email ?? null,
        },
      });

      await updateSalonWhatsappState(salonId, {
        onboardingStatus: 'awaiting_verification',
        registrationStatus: 'verification_required',
        lastCodeMethod: codeMethod,
        lastCodeRequestedAt: FieldValue.serverTimestamp(),
        lastRegistrationErrorMessage: FieldValue.delete(),
        lastRegistrationErrorAt: FieldValue.delete(),
      });

      response.set('Access-Control-Allow-Origin', '*');
      response.status(200).json({
        success: true,
        sessionId: session.sessionId,
        codeMethod,
        onboardingStatus: 'awaiting_verification',
        registrationStatus: 'verification_required',
      });
    } catch (error) {
      jsonError(response, error);
    }
  },
);

export const confirmWhatsappPhoneVerificationCode = onRequest(
  { region: REGION, cors: true, maxInstances: 10 },
  async (request: Request, response: Response) => {
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Origin', '*');
      response.set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization',
      );
      response.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      response.status(204).send('');
      return;
    }

    if (request.method !== 'POST') {
      jsonError(response, new WhatsAppHttpError('Method Not Allowed', 405));
      return;
    }

    try {
      const body = ensureJsonBody<ConfirmCodeBody>(request.body);
      const salonId = parseSalonId(body.salonId);
      const user = await requireWaSalonAdmin(request, response, salonId);
      if (!user) {
        return;
      }

      const requestedSessionId = normalizeString(body.sessionId) ?? undefined;
      const verificationCode = parseVerificationCode(body.verificationCode);
      const pin = sanitizePin(body.pin);

      if (!requestedSessionId) {
        const manualSetup = await loadManualSetupState(salonId);

        try {
          await verifyPhoneCode({
            phoneNumberId: manualSetup.resolved.phoneNumberId,
            verificationCode,
            accessToken: manualSetup.accessToken,
          });
          await registerPhoneNumber({
            phoneNumberId: manualSetup.resolved.phoneNumberId,
            pin,
            accessToken: manualSetup.accessToken,
          });
        } catch (error) {
          const message = toHttpError(error).message;
          await updateSalonWhatsappState(salonId, {
            connectionMethod: 'manual_setup',
            requiresReconnect: false,
            onboardingStatus: 'awaiting_verification',
            registrationStatus: 'verification_required',
            lastRegistrationErrorMessage: message,
            lastRegistrationErrorAt: FieldValue.serverTimestamp(),
            tokenSecretId: manualSetup.tokenSecretId,
          }).catch(() => undefined);
          throw error;
        }

        await markSalonReady({
          salonId,
          resolved: manualSetup.resolved,
          connectionMethod: 'manual_setup',
          tokenSecretId: manualSetup.tokenSecretId,
        });

        response.set('Access-Control-Allow-Origin', '*');
        response.status(200).json({
          success: true,
          nextStep: 'ready',
          onboardingStatus: 'ready',
          registrationStatus: 'registered',
          phoneNumberId: manualSetup.resolved.phoneNumberId,
          displayPhoneNumber:
            manualSetup.resolved.displayPhoneNumber ?? null,
        });
        return;
      }

      const session = await loadSession({
        salonId,
        sessionId: requestedSessionId,
        allowedStates: ['awaiting_verification'],
      });
      if (!session.phoneNumberId || !session.wabaId || !session.businessId) {
        throw new WhatsAppHttpError(
          'Sessione Embedded Signup incompleta. Riavvia il collegamento.',
          409,
          'incomplete_session',
        );
      }

      const resolved: ResolvedPhoneSelection = {
        businessId: session.businessId,
        wabaId: session.wabaId,
        phoneNumberId: session.phoneNumberId,
        displayPhoneNumber: session.displayPhoneNumber,
        verifiedName: session.verifiedName,
      };

      try {
        await verifyPhoneCode({
          phoneNumberId: session.phoneNumberId,
          verificationCode,
        });
        await registerPhoneNumber({
          phoneNumberId: session.phoneNumberId,
          pin,
        });
      } catch (error) {
        const message = toHttpError(error).message;
        await updateSessionState({
          salonId,
          sessionId: session.sessionId,
          state: 'awaiting_verification',
          data: {
            lastError: {
              message,
              at: FieldValue.serverTimestamp(),
            },
          },
        }).catch(() => undefined);
        await updateSalonWhatsappState(salonId, {
          onboardingStatus: 'awaiting_verification',
          registrationStatus: 'verification_required',
          lastRegistrationErrorMessage: message,
          lastRegistrationErrorAt: FieldValue.serverTimestamp(),
        }).catch(() => undefined);
        throw error;
      }

      await markSalonReady({ salonId, resolved });
      await updateSessionState({
        salonId,
        sessionId: session.sessionId,
        state: 'ready',
        data: {
          verificationCompletedByUserId: user.uid,
          verificationCompletedByEmail: user.email ?? null,
          registeredAt: FieldValue.serverTimestamp(),
        },
      });

      response.set('Access-Control-Allow-Origin', '*');
      response.status(200).json({
        success: true,
        nextStep: 'ready',
        onboardingStatus: 'ready',
        registrationStatus: 'registered',
        phoneNumberId: session.phoneNumberId,
        displayPhoneNumber: session.displayPhoneNumber ?? null,
        sessionId: session.sessionId,
      });
    } catch (error) {
      jsonError(response, error);
    }
  },
);

export const __test__ = {
  parseCodeMethod,
  parseSessionState,
};
