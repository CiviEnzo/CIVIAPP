import { defineSecret, defineInt, defineString } from 'firebase-functions/params';

export const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
export const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');
export const stripeApplicationFeeAmount = defineInt('STRIPE_APPLICATION_FEE_AMOUNT', { default: 0 });
export const stripePlatformName = defineString('STRIPE_PLATFORM_NAME', { default: 'CIVIAPP' });
export const stripeAllowedOrigin = defineString('STRIPE_ALLOWED_ORIGIN', { default: '*' });
