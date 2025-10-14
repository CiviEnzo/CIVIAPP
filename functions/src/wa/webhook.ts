import { onRequest } from 'firebase-functions/v2/https';
import logger from 'firebase-functions/logger';
import type { Request, Response } from 'express';

import { FieldValue, Timestamp, db } from '../utils/firestore';

import { getSalonWaConfigByPhoneNumberId } from './config';
import { readSecret } from './secrets';

const REGION = process.env.WA_REGION ?? 'europe-west1';
const QUIET_HOURS = { start: 21, end: 9 };
const verifyTokenFallback = process.env.WA_VERIFY_TOKEN;

type WebhookChange = Record<string, unknown> & {
  value?: Record<string, unknown>;
};

const phoneNumberCache = new Map<string, string>();
const verifyTokenCache = new Map<string, string>();
const verifyTokenIndex = new Map<string, string>();

type LoggerMethods = {
  debug?: (message: string, context?: Record<string, unknown>) => void;
  info?: (message: string, context?: Record<string, unknown>) => void;
  warn?: (message: string, context?: Record<string, unknown>) => void;
  error?: (
    message: string,
    error: Error,
    context?: Record<string, unknown>,
  ) => void;
};

const candidateLogger = (logger as unknown as LoggerMethods) ?? {};

function logDebug(message: string, context?: Record<string, unknown>): void {
  if (typeof candidateLogger.debug === 'function') {
    candidateLogger.debug(message, context);
  } else {
    console.debug(message, context);
  }
}

function logInfo(message: string, context?: Record<string, unknown>): void {
  if (typeof candidateLogger.info === 'function') {
    candidateLogger.info(message, context);
  } else {
    console.info(message, context);
  }
}

function logWarn(message: string, context?: Record<string, unknown>): void {
  if (typeof candidateLogger.warn === 'function') {
    candidateLogger.warn(message, context);
  } else {
    console.warn(message, context);
  }
}

function logError(
  message: string,
  error: unknown,
  context?: Record<string, unknown>,
): void {
  const err =
    error instanceof Error ? error : new Error(String(error ?? 'Unknown error'));
  if (typeof candidateLogger.error === 'function') {
    candidateLogger.error(message, err, context);
  } else {
    console.error(message, err, context);
  }
}

function toDateFromTimestamp(timestamp: unknown): Date | null {
  if (timestamp == null) {
    return null;
  }
  if (typeof timestamp === 'number') {
    return new Date(timestamp * 1000);
  }
  if (typeof timestamp === 'string') {
    const asNumber = Number.parseInt(timestamp, 10);
    if (!Number.isNaN(asNumber)) {
      return new Date(asNumber * 1000);
    }
    const parsed = new Date(timestamp);
    return Number.isNaN(parsed.valueOf()) ? null : parsed;
  }
  if (timestamp instanceof Date) {
    return timestamp;
  }
  if (timestamp instanceof Timestamp) {
    return timestamp.toDate();
  }
  return null;
}

async function resolveSalonIdByVerifyToken(
  verifyToken: string,
): Promise<string | null> {
  if (verifyTokenIndex.has(verifyToken)) {
    return verifyTokenIndex.get(verifyToken)!;
  }

  const snapshot = await db.collection('salons').get();
  for (const doc of snapshot.docs) {
    const salonId = doc.id;
    const data = doc.data() as Record<string, unknown>;
    const whatsapp = data.whatsapp as Record<string, unknown> | undefined;
    const secretId = whatsapp?.verifyTokenSecretId;
    if (typeof secretId !== 'string' || secretId.trim().length === 0) {
      continue;
    }

    let cachedToken = verifyTokenCache.get(salonId);
    if (!cachedToken) {
      try {
        cachedToken = await readSecret(secretId);
        verifyTokenCache.set(salonId, cachedToken);
        verifyTokenIndex.set(cachedToken, salonId);
      } catch (error) {
        logError('Failed to resolve verify token for salon', error, {
          salonId,
        });
        continue;
      }
    }

    if (cachedToken === verifyToken) {
      return salonId;
    }
  }

  if (verifyTokenFallback && verifyToken === verifyTokenFallback) {
    return '__global__';
  }

  return null;
}

async function handleVerification(
  request: Request,
  response: Response,
): Promise<void> {
  const mode = request.query['hub.mode'];
  const token = request.query['hub.verify_token'];
  const challenge = request.query['hub.challenge'];

  if (mode !== 'subscribe' || typeof token !== 'string') {
    response.status(403).send('Forbidden');
    return;
  }

  const salonId = await resolveSalonIdByVerifyToken(token);

  if (!salonId) {
    logWarn('Verify token mismatch', { token });
    response.status(403).send('Forbidden');
    return;
  }

  logInfo('WhatsApp webhook verified', { salonId });

  response.status(200).send(String(challenge ?? ''));
}

async function persistInboundMessage(
  salonId: string,
  message: Record<string, unknown>,
): Promise<void> {
  const messageId = String(message.id ?? '');
  if (!messageId) {
    return;
  }

  const receivedAt = toDateFromTimestamp(message.timestamp) ?? new Date();

  await db
    .collection('salons')
    .doc(salonId)
    .collection('message_inbox')
    .doc(messageId)
    .set(
      {
        salonId,
        messageId,
        from: message.from ?? message['wa_id'],
        type: message.type,
        payload: message,
        receivedAt,
        receivedAtMs: receivedAt.getTime(),
        createdAt: FieldValue.serverTimestamp(),
        quietHours: QUIET_HOURS,
      },
      { merge: true },
    );
}

async function persistDeliveryStatus(
  salonId: string,
  status: Record<string, unknown>,
): Promise<void> {
  const statusId = String(status.id ?? status.statusId ?? '');
  if (!statusId) {
    return;
  }

  const eventAt = toDateFromTimestamp(status.timestamp) ?? new Date();

  await db
    .collection('salons')
    .doc(salonId)
    .collection('delivery_receipts')
    .doc(statusId)
    .set(
      {
        salonId,
        messageId: status.id,
        status: status.status,
        recipient: status.recipient_id ?? status.recipientId,
        conversation: status.conversation,
        pricing: status.pricing,
        errors: status.errors,
        eventAt,
        eventAtMs: eventAt.getTime(),
        raw: status,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

async function processChange(
  change: WebhookChange,
): Promise<void> {
  const value = change.value as Record<string, unknown> | undefined;
  if (!value) {
    logDebug('Webhook change without value', { change });
    return;
  }

  const metadata = value.metadata as Record<string, unknown> | undefined;
  const phoneNumberId = String(metadata?.phone_number_id ?? '');

  if (!phoneNumberId) {
    logWarn('Webhook change missing phone_number_id', { change });
    return;
  }

  let salonId = phoneNumberCache.get(phoneNumberId);
  if (!salonId) {
    const config = await getSalonWaConfigByPhoneNumberId(phoneNumberId);
    if (!config) {
      logWarn('No salon mapped to phone_number_id', { phoneNumberId });
      return;
    }
    salonId = config.salonId;
    phoneNumberCache.set(phoneNumberId, salonId);
  }

  const messages = value.messages as Array<Record<string, unknown>> | undefined;
  const statuses = value.statuses as Array<Record<string, unknown>> | undefined;

  if (Array.isArray(messages)) {
    await Promise.all(messages.map((message) => persistInboundMessage(salonId!, message)));
  }

  if (Array.isArray(statuses)) {
    await Promise.all(statuses.map((status) => persistDeliveryStatus(salonId!, status)));
  }
}

async function handleNotification(
  request: Request,
  response: Response,
): Promise<void> {
  const body = request.body;

  if (!body || typeof body !== 'object') {
    response.status(200).json({ ok: true });
    return;
  }

  const entries = Array.isArray((body as Record<string, unknown>).entry)
    ? ((body as Record<string, unknown>).entry as Array<Record<string, unknown>>)
    : [];

  await Promise.all(
    entries.flatMap((entry) => {
      const changes = Array.isArray(entry.changes)
        ? (entry.changes as WebhookChange[])
        : [];
      return changes.map((change) => processChange(change));
    }),
  );

  response.status(200).json({ ok: true });
}

export const onWhatsappWebhook = onRequest(
  { region: REGION, cors: true, maxInstances: 10 },
  async (request: Request, response: Response) => {
    try {
      if (request.method === 'GET') {
        await handleVerification(request, response);
        return;
      }

      if (request.method !== 'POST') {
        response.status(405).json({ error: 'Method Not Allowed' });
        return;
      }

      await handleNotification(request, response);
    } catch (error) {
    logError('Unhandled error in WhatsApp webhook', error);
      response.status(500).json({ error: 'Internal Server Error' });
    }
  },
);
