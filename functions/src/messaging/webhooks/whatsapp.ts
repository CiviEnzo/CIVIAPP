import { onRequest } from 'firebase-functions/v2/https';
import logger from 'firebase-functions/logger';
import type { Request, Response } from 'express';

const SUPPORTED_COMMANDS = new Set(['1', '2', 'STOP']);
const REGION = 'europe-west1';

function normalizeCommand(value?: unknown): string | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }
  return value.trim().toUpperCase();
}

export const onWhatsappWebhook = onRequest({ region: REGION }, async (request: Request, response: Response) => {
  const command = normalizeCommand(request.body?.message ?? request.body?.text);
  const from = request.body?.from ?? request.body?.sender;

  logger.info('Received WhatsApp webhook', { from, command, raw: request.body });

  if (command && SUPPORTED_COMMANDS.has(command)) {
    logger.info('Handling WhatsApp command', { command, from });
    // TODO: Update appointment or channel preferences accordingly.
  }

  response.status(200).json({ ok: true });
});
