import logger from 'firebase-functions/logger';

import { ChannelDispatchResult, OutboxMessage } from '../types';

export async function sendWhatsapp(
  message: OutboxMessage,
): Promise<ChannelDispatchResult> {
  logger.info('Simulating WhatsApp dispatch', {
    messageId: message.id,
    salonId: message.salonId,
  });

  return {
    success: true,
    providerMessageId: `whatsapp-${message.id}`,
    metadata: {
      simulated: true,
    },
  };
}
