import { Request, Response } from 'express';

export const parseJsonBody = <T = Record<string, unknown>>(body: unknown): T => {
  if (typeof body === 'string') {
    try {
      return JSON.parse(body) as T;
    } catch (error) {
      throw new Error('Invalid JSON body');
    }
  }
  if (!body) {
    return {} as T;
  }
  return body as T;
};

export const applyCors = (req: Request, res: Response, origin: string): boolean => {
  const allowedOrigin = origin || '*';
  res.set('Access-Control-Allow-Origin', allowedOrigin);
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Stripe-Version');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return true;
  }
  return false;
};

export const toStripeMetadata = (input: Record<string, unknown>, base: Record<string, string> = {}): Record<string, string> => {
  const metadata: Record<string, string> = { ...base };
  for (const [key, value] of Object.entries(input)) {
    if (value === undefined || value === null) {
      continue;
    }
    metadata[key] = String(value);
  }
  return metadata;
};
