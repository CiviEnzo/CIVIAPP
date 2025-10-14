import Stripe from 'stripe';

import { stripeSecretKey } from './config';

let cachedClient: Stripe | undefined;
let cachedKey: string | undefined;

export const getStripeClient = (): Stripe => {
  const secret = stripeSecretKey.value();
  if (!secret) {
    throw new Error('Missing STRIPE_SECRET_KEY secret');
  }
  if (cachedClient && cachedKey === secret) {
    return cachedClient;
  }
  cachedClient = new Stripe(secret, { apiVersion: '2024-06-20' });
  cachedKey = secret;
  return cachedClient;
};
