import { getApps, initializeApp } from 'firebase-admin/app';

if (!getApps().length) {
  initializeApp();
}

export { createReminders, runCampaigns, birthdayGreetings } from './messaging/scheduler';
export { dispatchOutbox } from './messaging/dispatcher';
export { syncLoyaltyOnSaleWrite } from './loyalty/onSaleWrite';
export { adjustClientLoyalty } from './loyalty/adjustClientLoyalty';
export { scheduleLoyaltyReset } from './loyalty/reset_scheduler';
export { syncUserClaims } from './auth/syncUserClaims';
export {
  onClientQuestionnaireTemplateWrite,
  onClientQuestionnaireTemplateDelete,
} from './questionnaires/triggers';
export { bookLastMinuteSlot } from './appointments/bookLastMinuteSlot';
export { syncAppointmentWithLastMinuteSlot } from './appointments/onAppointmentWrite';
export { sendWhatsappTemplate } from './wa/sendTemplate';
export { onWhatsappWebhook } from './wa/webhook';
export { dispatchWhatsAppOutbox } from './scheduler/dispatchOutbox';
export {
  startWhatsappOAuth,
  handleWhatsappOAuthCallback,
} from './wa/oauth';
export { syncWhatsappOAuth } from './wa/onboarding';
export {
  createStripeConnectAccount,
  createStripeOnboardingLink,
  createStripePaymentIntent,
  createStripeEphemeralKey,
  handleStripeWebhook,
} from './stripe/routes';
