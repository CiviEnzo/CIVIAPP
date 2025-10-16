import { getMessaging } from 'firebase-admin/messaging';
import * as logger from 'firebase-functions/logger';

import { db, FieldValue } from '../../utils/firestore';
import { ChannelDispatchResult, OutboxMessage } from '../types';

export async function sendPush(
  message: OutboxMessage,
): Promise<ChannelDispatchResult> {
  const clientSnapshot = await db.collection('clients').doc(message.clientId).get();
  const tokensRaw = clientSnapshot.get('fcmTokens');
  const tokens = Array.isArray(tokensRaw)
    ? tokensRaw
        .map((token) => token?.toString())
        .filter((value): value is string => Boolean(value && value.length > 0))
    : [];

  if (!tokens.length) {
    logger.warn('No push tokens available for client', {
      messageId: message.id,
      clientId: message.clientId,
    });
    return {
      success: false,
      errorMessage: 'No push tokens registered for client',
    };
  }

  const title = (message.payload['title'] as string) ?? 'Notifica';
  const body = (message.payload['body'] as string) ?? '';
  const type = (message.payload['type'] as string) ?? 'generic';

  const dataPayload: Record<string, string> = {
    messageId: message.id,
    salonId: message.salonId,
    templateId: message.templateId,
    type,
  };

  if (message.payload['appointmentId']) {
    dataPayload.appointmentId = String(message.payload['appointmentId']);
  }
  if (message.payload['offsetMinutes'] != null) {
    dataPayload.offsetMinutes = String(message.payload['offsetMinutes']);
  }

  try {
    const response = await getMessaging().sendEachForMulticast({
      notification: body.trim().length === 0 ? undefined : { title, body },
      data: dataPayload,
      tokens,
    });

    const invalidTokenErrors = new Set([
      'messaging/registration-token-not-registered',
      'messaging/invalid-registration-token',
      'messaging/invalid-argument',
    ]);

    const invalidTokens: string[] = [];
    const otherFailures: string[] = [];

    response.responses.forEach((res, index) => {
      if (res.success) {
        return;
      }
      const failingToken = tokens[index];
      if (!failingToken) {
        return;
      }
      const code = res.error?.code;
      if (code && invalidTokenErrors.has(code)) {
        invalidTokens.push(failingToken);
      } else {
        otherFailures.push(code ?? 'unknown-error');
      }
    });

    if (invalidTokens.length) {
      await db.collection('clients').doc(message.clientId).update({
        fcmTokens: FieldValue.arrayRemove(...invalidTokens),
      });
      logger.debug('Removed invalid push tokens', {
        clientId: message.clientId,
        count: invalidTokens.length,
      });
    }

    if (response.successCount === 0) {
      const errorMessages = response.responses
        .map((res) => res.error?.message)
        .filter((err): err is string => Boolean(err));
      return {
        success: false,
        errorMessage: errorMessages.join('; ') || 'FCM send failed',
        metadata: {
          failureCount: response.failureCount,
          invalidTokenCount: invalidTokens.length,
          otherFailures,
        },
      };
    }

    return {
      success: true,
      providerMessageId: `fcm-${message.id}`,
      metadata: {
        successCount: response.successCount,
        failureCount: response.failureCount,
        invalidTokenCount: invalidTokens.length,
        otherFailures,
      },
    };
  } catch (error) {
    logger.error(
      'Error while sending push notification',
      error instanceof Error ? error : new Error(String(error)),
      {
        messageId: message.id,
      },
    );
    return {
      success: false,
      errorMessage: error instanceof Error ? error.message : String(error),
    };
  }
}
