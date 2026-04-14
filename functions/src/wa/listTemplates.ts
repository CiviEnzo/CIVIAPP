import axios from 'axios'
import { onRequest } from 'firebase-functions/v2/https'
import * as logger from 'firebase-functions/logger'
import type { Request, Response } from 'express'

import { requireWaSalonAdmin } from './authz'
import { getSalonWaConfig } from './config'
import { readSecret } from './secrets'
import {
  GRAPH_API_VERSION,
  GRAPH_TIMEOUT_MS,
  REGION,
  getSystemUserAccessToken,
  toHttpError,
} from './runtime'

type GraphMessageTemplate = {
  id?: string
  name?: string
  language?: string
  status?: string
  category?: string
  components?: Array<Record<string, unknown>>
  quality_score?: Record<string, unknown>
  rejected_reason?: string
  previous_category?: string
}

type GraphTemplateResponse = {
  data?: GraphMessageTemplate[]
  paging?: {
    next?: string
    cursors?: {
      before?: string
      after?: string
    }
  }
}

function jsonError(
  response: Response,
  status: number,
  error: string,
  details?: Record<string, unknown>,
): void {
  response.set('Access-Control-Allow-Origin', '*')
  response.status(status).json({
    success: false,
    error,
    ...(details ?? {}),
  })
}

function parseSalonId(request: Request): string {
  const raw = request.query.salonId ?? request.query.salon_id
  if (typeof raw !== 'string' || raw.trim().length === 0) {
    throw new Error('Missing salonId')
  }
  return raw.trim()
}

function parseLimit(request: Request): number {
  const raw = request.query.limit
  if (typeof raw !== 'string') {
    return 100
  }
  const value = Number.parseInt(raw, 10)
  if (!Number.isFinite(value)) {
    return 100
  }
  return Math.max(1, Math.min(value, 200))
}

function extractBodyPreview(
  components: Array<Record<string, unknown>> | undefined,
): string | null {
  if (!Array.isArray(components)) {
    return null
  }
  for (const component of components) {
    if (String(component.type ?? '').toUpperCase() != 'BODY') {
      continue
    }
    const text = component.text
    if (typeof text === 'string' && text.trim().length > 0) {
      return text.trim()
    }
  }
  return null
}

async function fetchWhatsappTemplates(params: {
  accessToken: string
  wabaId: string
  limit: number
}): Promise<{
  templates: GraphMessageTemplate[]
  nextCursor?: string
}> {
  const url = `https://graph.facebook.com/${GRAPH_API_VERSION}/${params.wabaId}/message_templates`
  const response = await axios.get<GraphTemplateResponse>(url, {
    params: {
      access_token: params.accessToken,
      limit: params.limit,
      fields:
        'id,name,language,status,category,components,quality_score,rejected_reason,previous_category',
    },
    timeout: GRAPH_TIMEOUT_MS,
  })

  return {
    templates: Array.isArray(response.data?.data) ? response.data.data : [],
    nextCursor: response.data?.paging?.cursors?.after,
  }
}

async function resolveListAccessToken(
  tokenSecretId: string | undefined,
): Promise<string> {
  if (tokenSecretId) {
    return readSecret(tokenSecretId)
  }
  return getSystemUserAccessToken()
}

export const listWhatsappTemplates = onRequest(
  { region: REGION, cors: true, maxInstances: 10 },
  async (request: Request, response: Response) => {
    if (request.method == 'OPTIONS') {
      response.set('Access-Control-Allow-Origin', '*')
      response.set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization',
      )
      response.set('Access-Control-Allow-Methods', 'GET, OPTIONS')
      response.status(204).send('')
      return
    }

    if (request.method != 'GET') {
      jsonError(response, 405, 'Method Not Allowed')
      return
    }

    try {
      const salonId = parseSalonId(request)
      const user = await requireWaSalonAdmin(request, response, salonId)
      if (!user) {
        return
      }
      const limit = parseLimit(request)
      const config = await getSalonWaConfig(salonId)
      if (!config.wabaId) {
        jsonError(response, 400, 'WABA not configured for salon')
        return
      }

      const accessToken = await resolveListAccessToken(config.tokenSecretId)
      const result = await fetchWhatsappTemplates({
        accessToken,
        wabaId: config.wabaId,
        limit,
      })

      const templates = result.templates
        .map((template) => ({
          id:
            typeof template.id === 'string' && template.id.trim().length > 0
              ? template.id.trim()
              : null,
          name:
            typeof template.name === 'string' && template.name.trim().length > 0
              ? template.name.trim()
              : null,
          language:
            typeof template.language === 'string' &&
                template.language.trim().length > 0
              ? template.language.trim()
              : null,
          status:
            typeof template.status === 'string' && template.status.trim().length > 0
              ? template.status.trim()
              : null,
          category:
            typeof template.category === 'string' &&
                template.category.trim().length > 0
              ? template.category.trim()
              : null,
          bodyPreview: extractBodyPreview(template.components),
          components: Array.isArray(template.components) ? template.components : [],
          qualityScore: template.quality_score ?? null,
          rejectedReason:
            typeof template.rejected_reason == 'string'
              ? template.rejected_reason
              : null,
          previousCategory:
            typeof template.previous_category == 'string'
              ? template.previous_category
              : null,
        }))
        .filter((template) => template.name != null)
        .sort((a, b) => (a.name ?? '').localeCompare(b.name ?? ''))

      logger.info('Fetched WhatsApp templates', {
        salonId,
        userId: user.uid,
        wabaId: config.wabaId,
        count: templates.length,
      })

      response.set('Access-Control-Allow-Origin', '*')
      response.status(200).json({
        success: true,
        salonId,
        wabaId: config.wabaId,
        count: templates.length,
        paging: {
          nextCursor: result.nextCursor ?? null,
        },
        templates,
      })
    } catch (error) {
      const httpError = toHttpError(
        error,
        error instanceof Error ? error.message : 'Unable to list WhatsApp templates',
      )
      const axiosError = axios.isAxiosError(error) ? error : null
      const data = axiosError?.response?.data
      logger.error(
        'Failed to list WhatsApp templates',
        error instanceof Error ? error : new Error(String(error)),
        { status: httpError.statusCode, data },
      )
      jsonError(
        response,
        httpError.statusCode,
        httpError.message,
        data && typeof data == 'object' ? { response: data as Record<string, unknown> } : undefined,
      )
    }
  },
)
