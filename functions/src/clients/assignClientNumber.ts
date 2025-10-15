import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

export const assignClientNumber = onCall({ region: 'europe-west3' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const rawSalonId = request.data?.salonId;
  if (typeof rawSalonId !== 'string' || rawSalonId.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Field "salonId" is required.');
  }
  const salonId = rawSalonId.trim();

  const db = getFirestore();
  const docRef = db.collection('salon_sequences').doc(salonId);

  const nextNumber = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(docRef);
    const data = snapshot.data();
    const current = data && typeof data.clientSequence === 'number'
      ? data.clientSequence
      : 0;
    const incremented = current + 1;
    const payload: Record<string, unknown> = {
      clientSequence: incremented,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (snapshot.exists) {
      transaction.update(docRef, payload);
    } else {
      payload.createdAt = FieldValue.serverTimestamp();
      transaction.set(docRef, payload);
    }
    return incremented;
  });

  return { clientNumber: nextNumber.toString() };
});
