import { getApps, initializeApp } from 'firebase-admin/app';

if (!getApps().length) {
  initializeApp();
}

export { createReminders, runCampaigns, birthdayGreetings } from './messaging/scheduler';
export { dispatchOutbox } from './messaging/dispatcher';
export { onWhatsappWebhook } from './messaging/webhooks/whatsapp';
export { syncLoyaltyOnSaleWrite } from './loyalty/onSaleWrite';
export { adjustClientLoyalty } from './loyalty/adjustClientLoyalty';
export { scheduleLoyaltyReset } from './loyalty/reset_scheduler';
export { syncUserClaims } from './auth/syncUserClaims';
export {
  onClientQuestionnaireTemplateWrite,
  onClientQuestionnaireTemplateDelete,
} from './questionnaires/triggers';
