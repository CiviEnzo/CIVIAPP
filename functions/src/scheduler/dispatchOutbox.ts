import { onSchedule } from 'firebase-functions/v2/scheduler';
import logger from 'firebase-functions/logger';
import type { QueryDocumentSnapshot } from 'firebase-admin/firestore';

import { FieldValue, db } from '../utils/firestore';
import { isWithinQuietHours, now } from '../utils/time';
import {
  sendTemplateMessage,
  WhatsAppTemplateComponent,
} from '../wa/sendTemplate';

const REGION = process.env.WA_REGION ?? 'europe-west1';
const TIMEZONE = process.env.WA_TIMEZONE ?? 'Europe/Rome';
const QUIET_HOURS = {
  start: Number.parseInt(process.env.WA_QUIET_START ?? '21', 10),
  end: Number.parseInt(process.env.WA_QUIET_END ?? '9', 10),
};
const BATCH_SIZE = Number.parseInt(process.env.WA_DISPATCH_BATCH ?? '25', 10);
const DEFAULT_RATE_LIMIT = Number.parseInt(
  process.env.WA_RATE_LIMIT_PER_RUN ?? '10',
  10,
);
const DISPATCH_ENABLED = process.env.WA_DISPATCH_ENABLED !== 'false';

interface OutboxDocument {
  salonId: string;
  channel: string;
  status: string;
  scheduledAt?: unknown;
  payload?: Record<string, unknown>;
  metadata?: Record<string, unknown>;
}

function extractComponents(
  value: unknown,
): WhatsAppTemplateComponent[] | undefined {
  return Array.isArray(value)
    ? (value as WhatsAppTemplateComponent[])
    : undefined;
}

function coerceString(value: unknown): string | undefined {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }
  if (typeof value === 'number') {
    return String(value);
  }
  return undefined;
}

function coerceBoolean(value: unknown): boolean | undefined {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'string') {
    if (value.toLowerCase() === 'true') {
      return true;
    }
    if (value.toLowerCase() === 'false') {
      return false;
    }
  }
  return undefined;
}

function coercePositiveInteger(
  value: unknown,
  fallback: number,
): number {
  if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
    return Math.floor(value);
  }
  if (typeof value === 'string') {
    const parsed = Number.parseInt(value, 10);
    if (Number.isFinite(parsed) && parsed > 0) {
      return parsed;
    }
  }
  return fallback;
}

async function markOutbox(
  doc: QueryDocumentSnapshot,
  status: string,
  info: Record<string, unknown>,
  extra: Record<string, unknown> = {},
): Promise<void> {
  await doc.ref.update({
    status,
    traces: FieldValue.arrayUnion({
      at: new Date(),
      event: status,
      info,
    }),
    updatedAt: FieldValue.serverTimestamp(),
    attempts: FieldValue.increment(1),
    ...extra,
  });
}

export const dispatchWhatsAppOutbox = onSchedule(
  {
    schedule: '*/5 * * * *',
    timeZone: TIMEZONE,
    region: REGION,
  },
  async () => {
    if (!DISPATCH_ENABLED) {
      logger.debug('WA dispatch disabled via WA_DISPATCH_ENABLED');
      return;
    }

    const zonedNow = now(TIMEZONE);
    if (isWithinQuietHours(zonedNow, QUIET_HOURS)) {
      logger.info('Within quiet hours window, skipping WA dispatch');
      return;
    }

    const snapshot = await db
      .collection('message_outbox')
      .where('channel', '==', 'whatsapp')
      .where('status', '==', 'pending')
      .orderBy('scheduledAt', 'asc')
      .limit(BATCH_SIZE)
      .get();

    if (snapshot.empty) {
      logger.debug('No pending WhatsApp messages to dispatch');
      return;
    }

    const processedPerSalon = new Map<string, number>();

    for (const doc of snapshot.docs) {
      const data = doc.data() as OutboxDocument;
      const salonId = data.salonId;
      const payload = (data.payload ?? {}) as Record<string, unknown>;
      const metadata = (data.metadata ?? {}) as Record<string, unknown>;
      if (!salonId || typeof salonId !== 'string') {
        logger.warn('Skipping outbox message without salonId', { id: doc.id });
        await markOutbox(doc, 'failed', {
          reason: 'missing-salon-id',
        });
        continue;
      }

      const rateLimit = coercePositiveInteger(
        metadata['waRateLimitPerRun'],
        DEFAULT_RATE_LIMIT,
      );
      const processed = processedPerSalon.get(salonId) ?? 0;
      if (processed >= rateLimit) {
        logger.info('Rate limit reached for salon, deferring message', {
          salonId,
          rateLimit,
          messageId: doc.id,
        });
        continue;
      }

      const recipientRaw =
        payload['to'] ?? payload['recipient'] ?? payload['phone'];
      const templateNameRaw =
        payload['templateName'] ??
        payload['template'] ??
        payload['template_id'] ??
        data.channel;
      const languageRaw =
        payload['lang'] ??
        payload['language'] ??
        payload['locale'] ??
        metadata['language'];
      const components = extractComponents(payload['components']);

      const to =
        coerceString(recipientRaw) ??
        (typeof recipientRaw === 'object' && recipientRaw !== null
          ? coerceString(
            (recipientRaw as Record<string, unknown>).default,
          )
          : undefined);
      const templateName = coerceString(templateNameRaw);
      const lang = coerceString(languageRaw);

      if (!to || !templateName) {
        logger.error('Outbox message missing recipient or template', {
          messageId: doc.id,
          salonId,
        });
        await markOutbox(doc, 'failed', {
          reason: 'missing-fields',
          to,
          templateName,
        });
        continue;
      }

      try {
        await doc.ref.update({
          status: 'queued',
          queuedAt: FieldValue.serverTimestamp(),
          traces: FieldValue.arrayUnion({
            at: new Date(),
            event: 'queued',
            info: {
              reason: 'wa-dispatch-start',
            },
          }),
        });

        const result = await sendTemplateMessage({
          salonId,
          to,
          templateName,
          lang,
          components,
          allowPreviewUrl:
            coerceBoolean(payload['allowPreviewUrl']),
          campaignId:
            coerceString(metadata['campaignId']),
          outboxMessageId: doc.id,
          metadata,
        });

        await doc.ref.update({
          status: 'sent',
          sentAt: FieldValue.serverTimestamp(),
          providerMessageId: result.messageId,
          traces: FieldValue.arrayUnion({
            at: new Date(),
            event: 'sent',
            info: {
              providerMessageId: result.messageId,
            },
          }),
        });

        processedPerSalon.set(salonId, processed + 1);
      } catch (error) {
        logger.error(
          'Failed to dispatch WhatsApp template',
          error instanceof Error ? error : new Error(String(error)),
          {
            salonId,
            messageId: doc.id,
          },
        );

        await markOutbox(doc, 'failed', {
          reason: 'wa-dispatch-error',
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
  },
);
