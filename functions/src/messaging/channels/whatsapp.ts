import logger from 'firebase-functions/logger';

import { ChannelDispatchResult, OutboxMessage } from '../types';
import {
  sendTemplateMessage,
  WhatsAppTemplateComponent,
} from '../../wa/sendTemplate';

function extractComponents(
  payload: Record<string, unknown>,
): WhatsAppTemplateComponent[] | undefined {
  const components = payload['components'];
  return Array.isArray(components)
    ? (components as WhatsAppTemplateComponent[])
    : undefined;
}

export async function sendWhatsapp(
  message: OutboxMessage,
): Promise<ChannelDispatchResult> {
  const payload = message.payload ?? {};
  const to = payload['to'] ?? payload['recipient'];
  const templateName = payload['templateName'] ?? payload['template'];
  const lang =
    payload['lang'] ?? payload['language'] ?? payload['locale'];
  const components = extractComponents(payload);
  const allowPreviewRaw = payload['allowPreviewUrl'];

  if (!to || !templateName) {
    const error = 'Missing recipient or template in message payload';
    logger.error('Unable to send WhatsApp message', { messageId: message.id, error });
    return { success: false, errorMessage: error };
  }

  try {
    const result = await sendTemplateMessage({
      salonId: message.salonId,
      to: String(to),
      templateName: String(templateName),
      lang: typeof lang === 'string' ? lang : undefined,
      components,
      allowPreviewUrl:
        typeof allowPreviewRaw === 'boolean' ? allowPreviewRaw : undefined,
      outboxMessageId: message.id,
      metadata: message.metadata,
    });

    return {
      success: result.success,
      providerMessageId: result.messageId,
      metadata: {
        response: result.response,
      },
    };
  } catch (error) {
    const messageError =
      error instanceof Error ? error.message : String(error);
    logger.error('Failed to send WhatsApp message', error, {
      messageId: message.id,
      salonId: message.salonId,
    });
    return { success: false, errorMessage: messageError };
  }
}
