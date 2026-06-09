import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

const termsVersion = 'terms-2026-06-05';
const privacyVersion = 'privacy-2026-06-01';

export const completeFirstPasswordChange = onCall(
  { region: 'europe-west3' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication is required.');
    }

    if (request.data?.acceptedLegalTerms !== true) {
      throw new HttpsError(
        'invalid-argument',
        'Terms and privacy acceptance is required.',
      );
    }

    const uid = request.auth.uid;
    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw new HttpsError('permission-denied', 'User profile not found.');
      }

      const data = snapshot.data() ?? {};
      const mustChangePassword = data.mustChangePassword === true ||
        data.forcePasswordChange === true ||
        data.requiresPasswordChange === true;

      if (!mustChangePassword) {
        return;
      }

      transaction.set(
        userRef,
        {
          mustChangePassword: false,
          forcePasswordChange: FieldValue.delete(),
          requiresPasswordChange: FieldValue.delete(),
          passwordChangedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          termsAcceptedAt: FieldValue.serverTimestamp(),
          privacyAcceptedAt: FieldValue.serverTimestamp(),
          termsVersion: request.data?.termsVersion ?? termsVersion,
          privacyVersion: request.data?.privacyVersion ?? privacyVersion,
          legalConsent: {
            accepted: true,
            acceptedAt: FieldValue.serverTimestamp(),
            termsVersion: request.data?.termsVersion ?? termsVersion,
            privacyVersion: request.data?.privacyVersion ?? privacyVersion,
            source: 'first_password_change',
          },
        },
        { merge: true },
      );
    });

    return { ok: true };
  },
);
