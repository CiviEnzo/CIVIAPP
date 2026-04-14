import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';

import { FieldValue, db } from '../utils/firestore';

import { REGION } from './runtime';

export function buildLegacyReconnectPayload(message?: string) {
  return {
    connectionMethod: 'legacy_oauth',
    requiresReconnect: true,
    onboardingStatus: 'reconnect_required',
    registrationStatus: 'error',
    lastOnboardingErrorMessage:
      message ??
      'Il flow OAuth legacy e stato disattivato. Riconfigura il numero con il setup manuale dal pannello admin web.',
    lastOnboardingErrorAt: FieldValue.serverTimestamp(),
    lastRegistrationErrorMessage:
      message ??
      'Il flow OAuth legacy e stato disattivato. Riconfigura il numero con il setup manuale dal pannello admin web.',
    lastRegistrationErrorAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

export const syncWhatsappOAuth = onDocumentWritten(
  {
    region: REGION,
    document: 'salons/{salonId}/integrations/whatsapp_oauth',
    retry: false,
  },
  async (event) => {
    const salonId = String(event.params.salonId);

    try {
      await db
        .collection('salons')
        .doc(salonId)
        .set(
          {
            whatsapp: buildLegacyReconnectPayload(),
          },
          { merge: true },
        );

      logger.warn('Marked legacy WhatsApp OAuth integration as reconnect required', {
        salonId,
      });
    } catch (error) {
      logger.error(
        'Unable to mark legacy WhatsApp OAuth integration as reconnect required',
        error instanceof Error ? error : new Error(String(error)),
        { salonId },
      );
    }
  },
);

export const __test__ = {
  buildLegacyReconnectPayload,
};
