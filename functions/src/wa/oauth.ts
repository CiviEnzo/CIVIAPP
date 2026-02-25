import { randomBytes } from 'crypto';
import { getAuth } from 'firebase-admin/auth';
import { defineSecret } from 'firebase-functions/params';
import { onRequest } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import type { Request, Response } from 'express';

import { FieldValue, db } from '../utils/firestore';

const REGION = process.env.WA_REGION ?? 'europe-west1';
const GRAPH_API_VERSION = process.env.WA_GRAPH_API_VERSION ?? 'v25.0';
const DEFAULT_REDIRECT =
  process.env.WA_OAUTH_REDIRECT ??
  'https://europe-west1-civiapp-38b51.cloudfunctions.net/handleWhatsappOAuthCallback';
const REQUIRED_SCOPES =
  process.env.WA_OAUTH_SCOPES ??
  'business_management,whatsapp_business_management,whatsapp_business_messaging';
const SUCCESS_REDIRECT =
  process.env.WA_SUCCESS_REDIRECT ?? 'https://civiapp-38b51.web.app/admin';
const OAUTH_STATE_TTL_MS = Number.parseInt(
  process.env.WA_OAUTH_STATE_TTL_MS ?? String(10 * 60 * 1000),
  10,
);
const DEFAULT_ALLOWED_SUCCESS_HOSTS = [
  'civiapp.app',
  'civiapp-38b51.web.app',
  'localhost',
];
const DEFAULT_ALLOWED_REDIRECT_HOSTS = [
  'civiapp.app',
  'civiapp-38b51.web.app',
  'localhost',
];
const ALLOWED_SUCCESS_REDIRECT_HOSTS = parseHostAllowlist(
  process.env.WA_ALLOWED_SUCCESS_REDIRECT_HOSTS,
  DEFAULT_ALLOWED_SUCCESS_HOSTS,
);
const ALLOWED_OAUTH_REDIRECT_HOSTS = parseHostAllowlist(
  process.env.WA_ALLOWED_OAUTH_REDIRECT_HOSTS,
  DEFAULT_ALLOWED_REDIRECT_HOSTS,
);
const waAppId = defineSecret('WA_APP_ID');

type OAuthStatePayload = {
  sid: string;
  n: string;
  s: string;
  ts: number;
};

type OAuthSessionDoc = {
  salonId?: unknown;
  nonce?: unknown;
  redirectUri?: unknown;
  returnTo?: unknown;
  requestedByUserId?: unknown;
  requestedByEmail?: unknown;
  expiresAt?: unknown;
  usedAt?: unknown;
  status?: unknown;
};

type UserContext = {
  uid: string;
  email?: string;
  role?: string;
  salonIds: string[];
};

function base64UrlEncode(input: string): string {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function base64UrlDecode(input: string): string {
  const normalized = input.replace(/-/g, '+').replace(/_/g, '/');
  const padding = normalized.length % 4;
  const padded =
    padding === 0
      ? normalized
      : normalized + '='.repeat(4 - (normalized.length % 4));
  return Buffer.from(padded, 'base64').toString('utf8');
}

function encodeState(payload: Record<string, unknown>): string {
  return base64UrlEncode(JSON.stringify(payload));
}

function decodeState(state?: string): Record<string, unknown> | null {
  if (!state) {
    return null;
  }
  try {
    const json = base64UrlDecode(state);
    return JSON.parse(json) as Record<string, unknown>;
  } catch (error) {
    logger.error(
      'Unable to decode OAuth state',
      error instanceof Error ? error : new Error(String(error)),
      { state },
    );
    return null;
  }
}

function base64UrlToken(bytes: number): string {
  return randomBytes(bytes)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function normalizeString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeRole(value: unknown): string | undefined {
  const normalized = normalizeString(value);
  return normalized ? normalized.toLowerCase() : undefined;
}

function normalizeSalonIds(...sources: unknown[]): string[] {
  const values = new Set<string>();
  for (const source of sources) {
    if (Array.isArray(source)) {
      for (const item of source) {
        const candidate = normalizeString(item);
        if (candidate) {
          values.add(candidate);
        }
      }
      continue;
    }
    const candidate = normalizeString(source);
    if (candidate) {
      values.add(candidate);
    }
  }
  return [...values];
}

function parseHostAllowlist(
  source: string | undefined,
  fallback: string[],
): Set<string> {
  const values = (source ?? '')
    .split(',')
    .map((value) => value.trim().toLowerCase())
    .filter((value) => value.length > 0);
  return new Set(values.length > 0 ? values : fallback);
}

function isAllowedHttpUrl(value: string, allowedHosts: Set<string>): boolean {
  try {
    const parsed = new URL(value);
    const protocol = parsed.protocol.toLowerCase();
    const host = parsed.hostname.toLowerCase();
    if (protocol !== 'https:' && !(protocol === 'http:' && host === 'localhost')) {
      return false;
    }
    return allowedHosts.has(host);
  } catch (_) {
    return false;
  }
}

function parseOAuthState(state?: string): OAuthStatePayload | null {
  const decoded = decodeState(state);
  if (!decoded) {
    return null;
  }

  const sid = normalizeString(decoded.sid);
  const nonce = normalizeString(decoded.n);
  const salonId = normalizeString(decoded.s);
  const tsRaw = decoded.ts;
  const ts =
    typeof tsRaw === 'number'
      ? tsRaw
      : typeof tsRaw === 'string'
        ? Number.parseInt(tsRaw, 10)
        : Number.NaN;

  if (!sid || !nonce || !salonId || !Number.isFinite(ts)) {
    return null;
  }

  return { sid, n: nonce, s: salonId, ts };
}

function getFirstParam(value: unknown): string | undefined {
  if (typeof value === 'string') {
    return value;
  }
  if (Array.isArray(value)) {
    for (const item of value) {
      if (typeof item === 'string') {
        return item;
      }
    }
  }
  return undefined;
}

function resolveRedirectUri(request: Request): string {
  const redirectParam =
    request.query.redirectUri ?? request.query.redirect_uri;
  if (typeof redirectParam === 'string' && redirectParam.length > 0) {
    if (isAllowedHttpUrl(redirectParam, ALLOWED_OAUTH_REDIRECT_HOSTS)) {
      return redirectParam;
    }
    logger.warn('Rejected OAuth redirectUri outside allowlist', {
      redirectParam,
    });
  }
  return DEFAULT_REDIRECT;
}

function resolveSuccessRedirect(request: Request): string {
  const custom =
    request.query.returnTo ??
    request.query.return_to ??
    request.query.successRedirect ??
    request.query.success_redirect;
  const value = getFirstParam(custom);
  if (value && isAllowedHttpUrl(value, ALLOWED_SUCCESS_REDIRECT_HOSTS)) {
    return value;
  }
  if (value) {
    logger.warn('Rejected success redirect outside allowlist', { value });
  }
  return SUCCESS_REDIRECT;
}

function buildAuthUrl(params: {
  salonId: string;
  redirectUri: string;
  state: string;
  appId: string;
}): string {
  const { salonId, redirectUri, state, appId } = params;
  const url = new URL(`https://www.facebook.com/${GRAPH_API_VERSION}/dialog/oauth`);
  url.searchParams.set('client_id', appId);
  url.searchParams.set('redirect_uri', redirectUri);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('scope', REQUIRED_SCOPES);
  url.searchParams.set('state', state);
  url.searchParams.set('display', 'page');
  url.searchParams.set('auth_type', 'rerequest');
  url.searchParams.set('app_id', appId);
  url.searchParams.set('salon_id', salonId);
  return url.toString();
}

function extractBearerToken(request: Request): string | null {
  const authorization = request.header('authorization') ?? request.header('Authorization');
  if (!authorization) {
    return null;
  }
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

async function loadUserContextFromRequest(request: Request): Promise<UserContext> {
  const token = extractBearerToken(request);
  if (!token) {
    throw new Error('Missing Authorization bearer token');
  }

  const decoded = await getAuth().verifyIdToken(token);
  const claimsRole = normalizeRole(decoded.role);
  const claimsSalonIds = normalizeSalonIds(decoded.salonIds);

  let profileRole: string | undefined;
  let profileSalonIds: string[] = [];

  try {
    const userDoc = await db.collection('users').doc(decoded.uid).get();
    if (userDoc.exists) {
      const data = userDoc.data() ?? {};
      profileRole = normalizeRole(data.role);
      profileSalonIds = normalizeSalonIds(
        data.salonIds,
        data.managedSalonIds,
        data.joinedSalonIds,
        data.primarySalonId,
        data.salonId,
      );
    }
  } catch (error) {
    logger.warn('Unable to load user profile for OAuth authorization', {
      uid: decoded.uid,
      error: error instanceof Error ? error.message : String(error),
    });
  }

  return {
    uid: decoded.uid,
    email: typeof decoded.email === 'string' ? decoded.email : undefined,
    role: profileRole ?? claimsRole,
    salonIds: profileSalonIds.length > 0 ? profileSalonIds : claimsSalonIds,
  };
}

function assertUserCanManageSalon(user: UserContext, salonId: string): void {
  const role = user.role?.toLowerCase() ?? '';
  if (role !== 'admin') {
    throw new Error('Only salon admins can start WhatsApp OAuth');
  }
  if (!user.salonIds.includes(salonId)) {
    throw new Error('User is not authorized for the requested salon');
  }
}

function oauthIntegrationRef(salonId: string) {
  return db
    .collection('salons')
    .doc(salonId)
    .collection('integrations')
    .doc('whatsapp_oauth');
}

function oauthSessionRef(salonId: string, sessionId: string) {
  return oauthIntegrationRef(salonId).collection('sessions').doc(sessionId);
}

async function createOAuthSession(params: {
  salonId: string;
  redirectUri: string;
  returnTo: string;
  user: UserContext;
}): Promise<{ sessionId: string; nonce: string }> {
  const sessionId = base64UrlToken(18);
  const nonce = base64UrlToken(24);
  const nowMs = Date.now();
  const expiresAt = new Date(nowMs + OAUTH_STATE_TTL_MS);

  await oauthSessionRef(params.salonId, sessionId).set(
    {
      salonId: params.salonId,
      nonce,
      redirectUri: params.redirectUri,
      returnTo: params.returnTo,
      requestedByUserId: params.user.uid,
      requestedByEmail: params.user.email ?? null,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt,
      status: 'started',
      tokenStrategy: 'optionA_meta_oauth_user_token',
    },
    { merge: true },
  );

  return { sessionId, nonce };
}

function toDate(value: unknown): Date | null {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value === 'object' && value !== null && 'toDate' in value) {
    try {
      const candidate = (value as { toDate: () => Date }).toDate();
      return candidate instanceof Date ? candidate : null;
    } catch (_) {
      return null;
    }
  }
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.valueOf()) ? null : parsed;
  }
  return null;
}

async function validateAndLockOAuthSession(params: {
  salonId: string;
  state: OAuthStatePayload;
  query: Record<string, unknown>;
}): Promise<{
  sessionId: string;
  redirectUri: string;
  returnTo: string;
  requestedByUserId?: string;
  requestedByEmail?: string;
}> {
  const sessionId = params.state.sid;
  const ref = oauthSessionRef(params.salonId, sessionId);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) {
      throw new Error('OAuth session not found or expired');
    }

    const data = (snapshot.data() ?? {}) as OAuthSessionDoc;
    const storedSalonId = normalizeString(data.salonId);
    const storedNonce = normalizeString(data.nonce);
    const redirectUri = normalizeString(data.redirectUri) ?? DEFAULT_REDIRECT;
    const returnTo = normalizeString(data.returnTo) ?? SUCCESS_REDIRECT;
    const requestedByUserId = normalizeString(data.requestedByUserId) ?? undefined;
    const requestedByEmail = normalizeString(data.requestedByEmail) ?? undefined;
    const status = normalizeString(data.status) ?? 'started';
    const usedAt = toDate(data.usedAt);
    const expiresAt = toDate(data.expiresAt);

    if (storedSalonId !== params.salonId) {
      throw new Error('OAuth session salon mismatch');
    }
    if (!storedNonce || storedNonce !== params.state.n) {
      throw new Error('Invalid OAuth session nonce');
    }
    if (usedAt) {
      throw new Error('OAuth session already used');
    }
    if (status === 'processed' || status === 'callback_stored') {
      throw new Error('OAuth session already completed');
    }
    if (expiresAt && expiresAt.getTime() < Date.now()) {
      throw new Error('OAuth session expired');
    }

    transaction.set(
      ref,
      {
        status: 'callback_received',
        callbackReceivedAt: FieldValue.serverTimestamp(),
        usedAt: FieldValue.serverTimestamp(),
        lastCallbackQuery: params.query,
      },
      { merge: true },
    );

    return {
      sessionId,
      redirectUri,
      returnTo,
      requestedByUserId,
      requestedByEmail,
    };
  });
}

export const startWhatsappOAuth = onRequest(
  { region: REGION, cors: true, secrets: [waAppId] },
  async (request: Request, response: Response) => {
    if (request.method !== 'GET') {
      response.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    const appId = waAppId.value();
    if (!appId) {
      response
        .status(500)
        .json({ error: 'WA_APP_ID not configured on the backend' });
      return;
    }

    const salonIdParam = request.query.salonId ?? request.query.salon_id;

    if (typeof salonIdParam !== 'string' || !salonIdParam.trim()) {
      response.status(400).json({ error: 'Missing salonId parameter' });
      return;
    }

    const salonId = salonIdParam.trim();
    let user: UserContext;
    try {
      user = await loadUserContextFromRequest(request);
      assertUserCanManageSalon(user, salonId);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Authentication required';
      logger.warn('Unauthorized WhatsApp OAuth start attempt', {
        salonId,
        error: message,
      });
      response.status(401).json({ error: message });
      return;
    }

    const redirectUri = resolveRedirectUri(request);
    const returnTo = resolveSuccessRedirect(request);
    const session = await createOAuthSession({
      salonId,
      redirectUri,
      returnTo,
      user,
    });
    const state = encodeState({
      sid: session.sessionId,
      n: session.nonce,
      s: salonId,
      ts: Date.now(),
    });
    const authUrl = buildAuthUrl({ salonId, redirectUri, state, appId });

    logger.info('Generated WhatsApp OAuth start URL', {
      salonId,
      redirectUri,
      userId: user.uid,
      sessionId: session.sessionId,
    });

    response.status(200).json({ authUrl, state });
  },
);

export const handleWhatsappOAuthCallback = onRequest(
  { region: REGION, cors: true },
  async (request: Request, response: Response) => {
    if (request.method !== 'GET') {
      response.status(405).send('Method Not Allowed');
      return;
    }

    const query = (request.query ?? {}) as Record<string, unknown>;
    const code = getFirstParam(query['code']);
    const error = getFirstParam(query['error']);
    const errorDescription =
      getFirstParam(query['error_description']) ??
      getFirstParam(query['errorDescription']);
    const stateParam = getFirstParam(query['state']);
    const state = parseOAuthState(stateParam);
    if (!state) {
      response.status(400).send('Missing or invalid OAuth state');
      return;
    }

    const salonId = state.s;

    let session: Awaited<ReturnType<typeof validateAndLockOAuthSession>>;
    try {
      session = await validateAndLockOAuthSession({ salonId, state, query });
    } catch (sessionError) {
      const message =
        sessionError instanceof Error
          ? sessionError.message
          : 'OAuth session validation failed';
      logger.warn('Invalid WhatsApp OAuth callback session', {
        salonId,
        error: message,
      });
      response.status(400).send(message);
      return;
    }

    const successRedirect = isAllowedHttpUrl(
      session.returnTo,
      ALLOWED_SUCCESS_REDIRECT_HOSTS,
    )
      ? session.returnTo
      : SUCCESS_REDIRECT;

    if (error) {
      await oauthSessionRef(salonId, session.sessionId).set(
        {
          status: 'error',
          error,
          errorDescription: errorDescription ?? null,
          callbackErrorAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      logger.error('WhatsApp OAuth callback returned error', {
        salonId,
        error,
        errorDescription,
      });
      response.status(400).send(String(error));
      return;
    }

    if (!code) {
      await oauthSessionRef(salonId, session.sessionId).set(
        {
          status: 'error',
          error: 'missing_code',
          callbackErrorAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      response.status(400).send('Missing authorization code');
      return;
    }

    try {
      const oauthRef = oauthIntegrationRef(salonId);

      await oauthRef.set(
        {
          salonId,
          lastCode: code,
          state,
          rawQuery: query,
          oauthSessionId: session.sessionId,
          tokenStrategy: 'optionA_meta_oauth_user_token',
          requestedByUserId: session.requestedByUserId ?? null,
          requestedByEmail: session.requestedByEmail ?? null,
          receivedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      await oauthSessionRef(salonId, session.sessionId).set(
        {
          status: 'callback_stored',
          callbackStoredAt: FieldValue.serverTimestamp(),
          lastCode: code,
        },
        { merge: true },
      );

      logger.info('Stored WhatsApp OAuth callback payload', { salonId });
    } catch (err) {
      await oauthSessionRef(salonId, session.sessionId).set(
        {
          status: 'error',
          error: 'callback_persist_failed',
          errorDescription:
            err instanceof Error ? err.message : String(err),
          callbackErrorAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      ).catch(() => undefined);
      logger.error(
        'Failed to persist OAuth payload',
        err instanceof Error ? err : new Error(String(err)),
        { salonId },
      );
    }

    response.status(200).send(
      `
<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <title>WhatsApp collegato</title>
    <style>
      body {
        font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        margin: 0;
        padding: 32px;
        background: #f3f4f6;
        color: #111827;
      }
      .card {
        max-width: 420px;
        margin: auto;
        background: white;
        padding: 24px;
        border-radius: 12px;
        box-shadow: 0 10px 30px rgba(15, 23, 42, 0.05);
      }
      h1 {
        font-size: 20px;
        margin-bottom: 16px;
      }
      p {
        margin-bottom: 12px;
        line-height: 1.5;
      }
      .button {
        display: inline-block;
        margin-top: 16px;
        padding: 10px 18px;
        background: #1f2937;
        color: white;
        text-decoration: none;
        border-radius: 8px;
      }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>WhatsApp collegato</h1>
      <p>Abbiamo ricevuto il codice di autorizzazione. Torna su CiviApp per completare la configurazione.</p>
      <a class="button" href="${successRedirect}">Torna al pannello</a>
    </div>
    <script>
      setTimeout(() => {
        try {
          window.location.href = ${JSON.stringify(successRedirect)};
        } catch (_) {
          window.close();
        }
      }, 1500);
    </script>
  </body>
</html>
      `.trim(),
    );
  },
);
