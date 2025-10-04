import { getApps, initializeApp } from 'firebase-admin/app';

if (!getApps().length) {
  initializeApp();
}

export { createReminders, runCampaigns, birthdayGreetings } from './messaging/scheduler';
export { dispatchOutbox } from './messaging/dispatcher';
export { onWhatsappWebhook } from './messaging/webhooks/whatsapp';
