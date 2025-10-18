import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as logger from 'firebase-functions/logger';

import { db, FieldValue } from '../utils/firestore';
import { canUseChannel } from '../utils/consent';
import { DEFAULT_QUIET_HOURS, DEFAULT_TIMEZONE, isWithinQuietHours, now } from '../utils/time';

import { ChannelDispatchResult, MessageChannel, OutboxMessage } from './types';
import { sendEmail } from './channels/email';
import { sendPush } from './channels/push';
import { sendWhatsapp } from './channels/whatsapp';

const messageOutboxCollection = db.collection('message_outbox');
const REGION = 'europe-west1';

const DISPATCH_ENABLED = process.env.MESSAGING_DISPATCH_ENABLED !== 'false';
const BATCH_SIZE = Number.parseInt(process.env.MESSAGING_DISPATCH_BATCH ?? '10', 10);
const DISPATCH_LEEWAY_MS = Number.parseInt(
  process.env.MESSAGING_DISPATCH_LEEWAY_MS ?? '60000',
  10,
);

function mapOutboxDocument(doc: FirebaseFirestore.QueryDocumentSnapshot): OutboxMessage {
  const data = doc.data();
  return {
    id: doc.id,
    salonId: String(data.salonId ?? ''),
    clientId: String(data.clientId ?? ''),
    templateId: String(data.templateId ?? ''),
    channel: (data.channel ?? 'push') as MessageChannel,
    status: (data.status ?? 'pending') as OutboxMessage['status'],
    scheduledAt:
      data.scheduledAt instanceof Date
        ? data.scheduledAt
        : data.scheduledAt?.toDate?.() ?? null,
    payload: data.payload ?? {},
    metadata: data.metadata ?? {},
  };
}

async function markMessage(
  doc: FirebaseFirestore.QueryDocumentSnapshot,
  status: OutboxMessage['status'],
  info: Record<string, unknown>,
  extra: Record<string, unknown> = {},
) {
  await doc.ref.update({
    status,
    updatedAt: FieldValue.serverTimestamp(),
    traces: FieldValue.arrayUnion({
      at: new Date(),
      event: status,
      info,
    }),
    ...extra,
  });
}

async function dispatchMessage(
  message: OutboxMessage,
): Promise<ChannelDispatchResult> {
  switch (message.channel) {
    case 'push':
      return sendPush(message);
    case 'email':
      return sendEmail(message);
    case 'whatsapp':
      return sendWhatsapp(message);
    default:
      logger.warn('Unsupported channel, skipping', { channel: message.channel });
      return {
        success: false,
        errorMessage: `Unsupported channel: ${message.channel}`,
      };
  }
}

export const dispatchOutbox = onSchedule(
  {
    schedule: '*/10 * * * *',
    timeZone: 'Europe/Rome',
    region: REGION,
  },
  async () => {
    if (!DISPATCH_ENABLED) {
      logger.debug('dispatchOutbox disabled via environment variable');
      return;
    }

    const zonedNow = now(DEFAULT_TIMEZONE);
    if (isWithinQuietHours(zonedNow, DEFAULT_QUIET_HOURS)) {
      logger.info('Quiet hours window, postponing dispatch cycle');
      return;
    }

    const snapshot = await messageOutboxCollection
      .where('status', '==', 'pending')
      .where('channel', 'in', ['push', 'email'])
      .orderBy('scheduledAt', 'asc')
      .limit(BATCH_SIZE)
      .get();

    if (snapshot.empty) {
      logger.debug('No pending messages to dispatch');
      return;
    }

    const nowInstant = new Date();

    for (const doc of snapshot.docs) {
      const message = mapOutboxDocument(doc);
      const channelAllowed = canUseChannel(
        message.channel,
        message.metadata?.channelPreferences,
      );

      if (
        message.scheduledAt &&
        message.scheduledAt.getTime() - DISPATCH_LEEWAY_MS > nowInstant.getTime()
      ) {
        logger.debug('Skipping message scheduled in the future', {
          id: message.id,
          scheduledAt: message.scheduledAt,
        });
        break;
      }

      if (!channelAllowed) {
        await markMessage(doc, 'skipped', {
          channel: message.channel,
          reason: 'channel-not-eligible',
        });
        continue;
      }

      await markMessage(doc, 'queued', { reason: 'dispatcher-start' });

      try {
        const result = await dispatchMessage(message);

        if (result.success) {
        await markMessage(
          doc,
          'sent',
          {
            channel: message.channel,
            simulated: true,
            providerMessageId: result.providerMessageId,
          },
          {
            sentAt: FieldValue.serverTimestamp(),
          },
        );
      } else {
          await markMessage(
            doc,
            'failed',
            {
              channel: message.channel,
              error: result.errorMessage ?? 'unknown',
            },
            {
              failedAt: FieldValue.serverTimestamp(),
            },
          );
        }
      } catch (error) {
        logger.error(
          'Failed to dispatch message',
          error instanceof Error ? error : new Error(String(error)),
          { id: message.id },
        );
        await markMessage(
          doc,
          'failed',
          {
            channel: message.channel,
            error: error instanceof Error ? error.message : String(error),
          },
          {
            failedAt: FieldValue.serverTimestamp(),
          },
        );
      }
    }
  },
);
