import logger from 'firebase-functions/logger';

import { ChannelDispatchResult, OutboxMessage } from '../types';

export async function sendEmail(
  message: OutboxMessage,
): Promise<ChannelDispatchResult> {
  logger.info('Simulating email dispatch', {
    messageId: message.id,
    salonId: message.salonId,
  });

  return {
    success: true,
    providerMessageId: `email-${message.id}`,
    metadata: {
      simulated: true,
    },
  };
}
