import type { Request, Response } from 'express';
import { onRequest } from 'firebase-functions/v2/https';

import { getPrometheusMetrics } from './metrics';
import { ReportFilters, ReportsError, ReportsService, ReportScope } from './service';

const reportsService = new ReportsService();

const setCorsHeaders = (res: Response): void => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
};

const handleCors = (req: Request, res: Response): boolean => {
  setCorsHeaders(res);
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return true;
  }
  return false;
};

const parseFilters = (req: Request): { scope: ReportScope; filters: ReportFilters } => {
  const { query } = req;
  const scope = parseString(query.scope) ?? 'summary';
  const today = new Date();
  const defaultTo = formatDate(today);
  const defaultFrom = formatDate(new Date(today.getTime() - 29 * 24 * 60 * 60 * 1000));

  const dateFrom = parseDate(query.date_from, defaultFrom, 'date_from');
  const dateTo = parseDate(query.date_to, defaultTo, 'date_to');

  if (dateFrom > dateTo) {
    throw new ReportsError('REPORTS_INVALID_FILTER', 'date_from must be before date_to', 400);
  }

  const filters: ReportFilters = {
    dateFrom,
    dateTo,
    storeId: parseString(query.store_id) ?? null,
    operatorIds: parseList(query.operator_ids),
    serviceIds: parseList(query.service_ids),
    categoryIds: parseList(query.category_ids),
    channel: parseString(query.channel) ?? null,
  };

  return { scope, filters };
};

const parseDate = (value: unknown, fallback: string, field: string): string => {
  const raw = parseString(value);
  if (!raw) {
    return fallback;
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    throw new ReportsError('REPORTS_INVALID_FILTER', `Invalid date format for ${field}`, 400);
  }
  return raw;
};

const parseString = (value: unknown): string | undefined => {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (Array.isArray(value)) {
    return parseString(value[0]);
  }
  const stringified = String(value).trim();
  return stringified.length ? stringified : undefined;
};

const parseList = (value: unknown): string[] => {
  if (value === undefined || value === null) {
    return [];
  }
  const values = Array.isArray(value) ? value : [value];
  return values
    .flatMap(item => String(item).split(','))
    .map(item => item.trim())
    .filter(item => item.length > 0);
};

const formatDate = (input: Date): string => {
  const year = input.getUTCFullYear();
  const month = `${input.getUTCMonth() + 1}`.padStart(2, '0');
  const day = `${input.getUTCDate()}`.padStart(2, '0');
  return `${year}-${month}-${day}`;
};

const respondError = (res: Response, error: unknown): void => {
  if (error instanceof ReportsError) {
    res.status(error.status).json({
      error: { code: error.code, message: error.message },
    });
    return;
  }
  console.error('reports.unhandled_error', error);
  res.status(500).json({
    error: { code: 'REPORTS_INTERNAL_ERROR', message: 'Unexpected error occurred' },
  });
};

export const getReportsSummary = onRequest(
  { cors: false, region: 'europe-west3' },
  async (req: Request, res: Response): Promise<void> => {
    if (handleCors(req, res)) {
      return;
    }
    if (req.method !== 'GET') {
      res.set('Allow', 'GET, OPTIONS');
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    try {
      const { scope, filters } = parseFilters(req);
      const response = await reportsService.getReport(scope, filters);
      res.status(200).json(response);
    } catch (error) {
      respondError(res, error);
    }
  },
);

export const getReportsMetrics = onRequest(
  { cors: false, region: 'europe-west3' },
  async (req: Request, res: Response): Promise<void> => {
    if (req.method === 'OPTIONS') {
      res.set('Allow', 'GET, OPTIONS');
      res.status(204).send('');
      return;
    }
    if (req.method !== 'GET') {
      res.set('Allow', 'GET, OPTIONS');
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    const body = getPrometheusMetrics();
    res.set('Content-Type', 'text/plain; version=0.0.4');
    res.status(200).send(body);
  },
);
