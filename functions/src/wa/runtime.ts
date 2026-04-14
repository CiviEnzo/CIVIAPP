import axios from 'axios';

export const REGION = process.env.WA_REGION ?? 'europe-west1';
export const GRAPH_API_VERSION = process.env.WA_GRAPH_API_VERSION ?? 'v25.0';
export const GRAPH_TIMEOUT_MS = Number(process.env.WA_GRAPH_TIMEOUT_MS ?? 10000);

export type ConnectionMethod =
  | 'embedded_signup'
  | 'legacy_oauth'
  | 'manual_setup';
export type WhatsAppOnboardingStatus =
  | 'disconnected'
  | 'reconnect_required'
  | 'registering'
  | 'awaiting_verification'
  | 'ready'
  | 'error';
export type WhatsAppRegistrationStatus =
  | 'pending'
  | 'verification_required'
  | 'registered'
  | 'error';

export type GraphApiErrorPayload = {
  error?: {
    code?: number;
    message?: string;
    type?: string;
    fbtrace_id?: string;
    error_subcode?: number;
  };
};

export class WhatsAppHttpError extends Error {
  constructor(
    message: string,
    readonly statusCode = 400,
    readonly code = 'whatsapp_error',
    readonly details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'WhatsAppHttpError';
  }
}

export function normalizeString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function parseBoolean(value: unknown): boolean {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    return normalized === 'true' || normalized === '1' || normalized === 'yes';
  }
  if (typeof value === 'number') {
    return value == 1;
  }
  return false;
}

export function inferConnectionMethod(
  whatsapp: Record<string, unknown> | undefined,
): ConnectionMethod {
  const configured = normalizeString(whatsapp?.connectionMethod);
  if (configured === 'embedded_signup') {
    return 'embedded_signup';
  }
  if (configured === 'manual_setup') {
    return 'manual_setup';
  }
  if (configured === 'legacy_oauth') {
    return 'legacy_oauth';
  }
  if (normalizeString(whatsapp?.tokenSecretId)) {
    return 'legacy_oauth';
  }
  return 'embedded_signup';
}

export function inferRequiresReconnect(
  whatsapp: Record<string, unknown> | undefined,
): boolean {
  if (parseBoolean(whatsapp?.requiresReconnect)) {
    return true;
  }
  return inferConnectionMethod(whatsapp) === 'legacy_oauth';
}

export function inferOnboardingStatus(
  whatsapp: Record<string, unknown> | undefined,
): WhatsAppOnboardingStatus {
  const configured = normalizeString(whatsapp?.onboardingStatus);
  switch (configured) {
    case 'disconnected':
    case 'reconnect_required':
    case 'registering':
    case 'awaiting_verification':
    case 'ready':
    case 'error':
      return configured;
    case 'synced':
    case 'connected':
      return 'ready';
    case 'pending':
    case 'in_progress':
      return 'registering';
    default:
      break;
  }

  if (inferRequiresReconnect(whatsapp)) {
    return 'reconnect_required';
  }
  if (normalizeString(whatsapp?.phoneNumberId)) {
    return 'ready';
  }
  return 'disconnected';
}

export function inferRegistrationStatus(
  whatsapp: Record<string, unknown> | undefined,
): WhatsAppRegistrationStatus {
  const configured = normalizeString(whatsapp?.registrationStatus);
  switch (configured) {
    case 'pending':
    case 'verification_required':
    case 'registered':
    case 'error':
      return configured;
    default:
      break;
  }

  if (inferRequiresReconnect(whatsapp)) {
    return 'error';
  }
  if (inferOnboardingStatus(whatsapp) === 'awaiting_verification') {
    return 'verification_required';
  }
  if (
    inferOnboardingStatus(whatsapp) === 'ready' &&
    normalizeString(whatsapp?.phoneNumberId)
  ) {
    return 'registered';
  }
  return 'pending';
}

export function requireEnv(name: string): string {
  const value = normalizeString(process.env[name]);
  if (!value) {
    throw new WhatsAppHttpError(
      `${name} is not configured on the backend`,
      500,
      'missing_env',
      { env: name },
    );
  }
  return value;
}

export function getSystemUserAccessToken(): string {
  return requireEnv('WA_SYSTEM_USER_TOKEN');
}

export function getSystemUserId(): string {
  return requireEnv('WA_SYSTEM_USER_ID');
}

export function getAppId(): string {
  return requireEnv('WA_APP_ID');
}

export function getAppSecret(): string {
  return requireEnv('WA_APP_SECRET');
}

export function getEmbeddedSignupConfigId(): string {
  return requireEnv('WA_EMBEDDED_SIGNUP_CONFIG_ID');
}

export function getTokenSecretPrefix(): string {
  return requireEnv('WA_TOKEN_SECRET_PREFIX');
}

export function sanitizePin(pin: unknown): string {
  const normalized = normalizeString(pin);
  if (!normalized || !/^\d{6}$/.test(normalized)) {
    throw new WhatsAppHttpError(
      'PIN WhatsApp non valido. Inserisci 6 cifre.',
      400,
      'invalid_pin',
    );
  }
  return normalized;
}

export function extractGraphError(
  error: unknown,
): {
  statusCode: number;
  message: string;
  code?: number;
  type?: string;
  payload?: GraphApiErrorPayload;
} | null {
  if (!axios.isAxiosError(error)) {
    return null;
  }

  const statusCode = error.response?.status ?? 400;
  const payload = error.response?.data as GraphApiErrorPayload | undefined;
  const graphError = payload?.error;
  return {
    statusCode,
    message:
      normalizeString(graphError?.message) ??
      normalizeString(error.message) ??
      'Unknown Graph API error',
    code: graphError?.code,
    type: graphError?.type,
    payload,
  };
}

export function isAlreadySubscribedGraphError(error: unknown): boolean {
  const details = extractGraphError(error);
  if (!details) {
    return false;
  }
  const message = details.message.toLowerCase();
  return message.includes('already subscribed');
}

export function isSystemUserAlreadyAssignedError(error: unknown): boolean {
  const details = extractGraphError(error);
  if (!details) {
    return false;
  }
  const message = details.message.toLowerCase();
  return (
    message.includes('already assigned') ||
    message.includes('already exists') ||
    message.includes('duplicate')
  );
}

export function isVerificationRequiredGraphError(error: unknown): boolean {
  const details = extractGraphError(error);
  if (!details) {
    return false;
  }
  const message = details.message.toLowerCase();
  return (
    message.includes('request_code') ||
    message.includes('verification code') ||
    message.includes('verify') ||
    message.includes('ownership') ||
    message.includes('registration') ||
    message.includes('pending')
  );
}

export function toHttpError(
  error: unknown,
  fallbackMessage = 'Operazione WhatsApp non riuscita',
): WhatsAppHttpError {
  if (error instanceof WhatsAppHttpError) {
    return error;
  }

  const details = extractGraphError(error);
  if (details) {
    return new WhatsAppHttpError(
      details.message,
      details.statusCode,
      'graph_error',
      {
        graphCode: details.code,
        graphType: details.type,
        payload: details.payload,
      },
    );
  }

  return new WhatsAppHttpError(
    error instanceof Error ? error.message : fallbackMessage,
    400,
    'whatsapp_error',
  );
}
