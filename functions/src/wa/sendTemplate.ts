import axios from 'axios';
import { onRequest } from 'firebase-functions/v2/https';
import logger from 'firebase-functions/logger';
import type { Request, Response } from 'express';

import { FieldValue, db } from '../utils/firestore';

import { getSalonWaConfig } from './config';
import { readSecret } from './secrets';

const REGION = process.env.WA_REGION ?? 'europe-west1';
const GRAPH_API_VERSION = process.env.WA_GRAPH_API_VERSION ?? 'v19.0';
const DEFAULT_LANGUAGE = process.env.WA_DEFAULT_LANGUAGE ?? 'it';

export interface WhatsAppTemplateComponent {
  type: string;
  parameters?: Array<Record<string, unknown>>;
  [key: string]: unknown;
}

export interface SendTemplateInput {
  salonId: string;
  to: string;
  templateName: string;
  lang?: string;
  components?: WhatsAppTemplateComponent[];
  allowPreviewUrl?: boolean;
  campaignId?: string;
  outboxMessageId?: string;
  metadata?: Record<string, unknown>;
}

export interface SendTemplateResult {
  success: boolean;
  messageId?: string;
  response?: unknown;
}

async function createOutboxTrace(
  salonId: string,
  outboxMessageId: string,
  trace: Record<string, unknown>,
): Promise<void> {
  await db
    .collection('message_outbox')
    .doc(outboxMessageId)
    .update({
      traces: FieldValue.arrayUnion({
        ...trace,
        at: FieldValue.serverTimestamp(),
      }),
      lastAttemptAt: FieldValue.serverTimestamp(),
    })
    .catch((error) => {
      logger.warn('Failed to append outbox trace', error, {
        salonId,
        outboxMessageId,
      });
    });
}

export async function sendTemplateMessage(
  input: SendTemplateInput,
): Promise<SendTemplateResult> {
  const { salonId, to, templateName } = input;
  if (!salonId) {
    throw new Error('salonId is required');
  }
  if (!to) {
    throw new Error('Recipient phone number (to) is required');
  }
  if (!templateName) {
    throw new Error('templateName is required');
  }

  const config = await getSalonWaConfig(salonId);
  const accessToken = await readSecret(config.tokenSecretId);

  const languageCode =
    input.lang ?? config.defaultLanguage ?? DEFAULT_LANGUAGE;

  const url = `https://graph.facebook.com/${GRAPH_API_VERSION}/${config.phoneNumberId}/messages`;

  const payload: Record<string, unknown> = {
    messaging_product: 'whatsapp',
    to,
    type: 'template',
    template: {
      name: templateName,
      language: {
        code: languageCode,
      },
      ...(Array.isArray(input.components) && input.components.length
        ? { components: input.components }
        : {}),
    },
  };

  if (input.allowPreviewUrl === false) {
    (payload.template as Record<string, unknown>).disable_preview = true;
  }

  try {
    const response = await axios.post(url, payload, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      timeout: Number(process.env.WA_SEND_TIMEOUT_MS ?? 10000),
    });

    const messageId: string | undefined =
      response.data?.messages?.[0]?.id ??
      response.data?.messages?.[0]?.message_id;

    if (!messageId) {
      logger.warn('Graph API response missing message id', {
        salonId,
        to,
        templateName,
        response: response.data,
      });
    }

    if (input.outboxMessageId) {
      await createOutboxTrace(salonId, input.outboxMessageId, {
        event: 'graph_api_response',
        response: response.data,
      });
    }

    return {
      success: true,
      messageId,
      response: response.data,
    };
  } catch (error) {
    const axiosError = axios.isAxiosError(error) ? error : null;
    const status = axiosError?.response?.status;
    const data = axiosError?.response?.data;

    logger.error(
      'Failed to send WhatsApp template',
      error instanceof Error ? error : new Error(String(error)),
      { salonId, to, templateName, status, data },
    );

    if (input.outboxMessageId) {
      await createOutboxTrace(salonId, input.outboxMessageId, {
        event: 'graph_api_error',
        status,
        data,
      });
    }

    throw error instanceof Error ? error : new Error(String(error));
  }
}

function validateRequestBody(body: unknown): SendTemplateInput {
  if (typeof body !== 'object' || body === null) {
    throw new Error('Invalid request body');
  }
  const value = body as Record<string, unknown>;
  const salonId = String(value.salonId ?? '').trim();
  const to = String(value.to ?? '').trim();
  const templateName = String(value.templateName ?? '').trim();
  const langRaw = value.lang ?? value.language ?? value.locale;
  const lang =
    typeof langRaw === 'string' && langRaw.trim().length > 0
      ? langRaw.trim()
      : undefined;
  const components = Array.isArray(value.components)
    ? (value.components as WhatsAppTemplateComponent[])
    : undefined;
  const allowPreviewUrl =
    typeof value.allowPreviewUrl === 'boolean'
      ? value.allowPreviewUrl
      : undefined;
  const campaignId =
    typeof value.campaignId === 'string' ? value.campaignId : undefined;
  const outboxMessageId =
    typeof value.outboxMessageId === 'string'
      ? value.outboxMessageId
      : typeof value.messageId === 'string'
        ? value.messageId
        : undefined;

  if (!salonId) {
    throw new Error('Missing salonId');
  }
  if (!to) {
    throw new Error('Missing recipient (to)');
  }
  if (!templateName) {
    throw new Error('Missing templateName');
  }

  return {
    salonId,
    to,
    templateName,
    lang,
    components,
    allowPreviewUrl,
    campaignId,
    outboxMessageId,
    metadata:
      typeof value.metadata === 'object' && value.metadata !== null
        ? (value.metadata as Record<string, unknown>)
        : undefined,
  };
}

function sendError(response: Response, status: number, message: string): void {
  response.status(status).json({ success: false, error: message });
}

export const sendWhatsappTemplate = onRequest(
  { region: REGION, cors: true, maxInstances: 10 },
  async (request: Request, response: Response) => {
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Origin', '*');
      response.set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization',
      );
      response.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      response.status(204).send('');
      return;
    }

    if (request.method !== 'POST') {
      sendError(response, 405, 'Method Not Allowed');
      return;
    }

    try {
      const input = validateRequestBody(request.body);
      const result = await sendTemplateMessage(input);
      response.set('Access-Control-Allow-Origin', '*');
      response.status(200).json({
        success: true,
        messageId: result.messageId,
        response: result.response,
      });
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Unknown error occurred';
      sendError(response, 400, message);
    }
  },
);
