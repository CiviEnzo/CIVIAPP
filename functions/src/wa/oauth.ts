import { onRequest } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import type { Request, Response } from 'express';

import { FieldValue, db } from '../utils/firestore';

const REGION = process.env.WA_REGION ?? 'europe-west1';
const GRAPH_API_VERSION = process.env.WA_GRAPH_API_VERSION ?? 'v19.0';
const APP_ID = process.env.WA_APP_ID ?? '';
const DEFAULT_REDIRECT =
  process.env.WA_OAUTH_REDIRECT ??
  'https://civiapp.app/oauth/whatsapp/callback';
const REQUIRED_SCOPES =
  process.env.WA_OAUTH_SCOPES ??
  'whatsapp_business_management,whatsapp_business_messaging';
const SUCCESS_REDIRECT =
  process.env.WA_SUCCESS_REDIRECT ?? 'https://civiapp-38b51.web.app/admin';

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
    return redirectParam;
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
  if (value && value.startsWith('http')) {
    return value;
  }
  return SUCCESS_REDIRECT;
}

function buildAuthUrl(params: {
  salonId: string;
  redirectUri: string;
  state: string;
}): string {
  const { salonId, redirectUri, state } = params;
  const url = new URL(`https://www.facebook.com/${GRAPH_API_VERSION}/dialog/oauth`);
  url.searchParams.set('client_id', APP_ID);
  url.searchParams.set('redirect_uri', redirectUri);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('scope', REQUIRED_SCOPES);
  url.searchParams.set('state', state);
  url.searchParams.set('display', 'page');
  url.searchParams.set('auth_type', 'rerequest');
  url.searchParams.set('app_id', APP_ID);
  url.searchParams.set('salon_id', salonId);
  return url.toString();
}

export const startWhatsappOAuth = onRequest(
  { region: REGION, cors: true },
  async (request: Request, response: Response) => {
    if (request.method !== 'GET') {
      response.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    if (!APP_ID) {
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
    const redirectUri = resolveRedirectUri(request);
    const returnTo = resolveSuccessRedirect(request);
    const state = encodeState({
      salonId,
      redirectUri,
      returnTo,
      ts: Date.now(),
    });
    const authUrl = buildAuthUrl({ salonId, redirectUri, state });

    logger.info('Generated WhatsApp OAuth start URL', {
      salonId,
      redirectUri,
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
    const salonIdFromQuery =
      getFirstParam(query['salonId']) ?? getFirstParam(query['salon_id']);

    const decodedState = stateParam ? decodeState(stateParam) : null;
    const salonId =
      (decodedState?.salonId as string | undefined) ?? salonIdFromQuery;
    const returnToRaw = decodedState?.returnTo;
    const successRedirect =
      typeof returnToRaw === 'string' && returnToRaw.startsWith('http')
        ? returnToRaw
        : SUCCESS_REDIRECT;

    if (error) {
      logger.error('WhatsApp OAuth callback returned error', {
        salonId,
        error,
        errorDescription,
      });
      response.status(400).send(String(error));
      return;
    }

    if (!code) {
      response.status(400).send('Missing authorization code');
      return;
    }

    if (!salonId) {
      response.status(400).send('Missing salon reference in state');
      return;
    }

    try {
      const oauthRef = db
        .collection('salons')
        .doc(salonId)
        .collection('integrations')
        .doc('whatsapp_oauth');

      await oauthRef.set(
        {
          salonId,
          lastCode: code,
          state: decodedState,
          rawQuery: query,
          receivedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      logger.info('Stored WhatsApp OAuth callback payload', { salonId });
    } catch (err) {
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
