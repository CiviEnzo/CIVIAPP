import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

interface ActivateClientSalonPayload {
  salonId: string;
  clientId: string;
  displayName?: string;
  email?: string;
}

function assertStringField(
  value: unknown,
  fieldName: keyof ActivateClientSalonPayload,
): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpsError('invalid-argument', `Field "${fieldName}" is required.`);
  }
  return value.trim();
}

function optionalStringField(value: unknown): string | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed;
}

export const activateClientSalon = onCall({ region: 'europe-west3' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const rawData = request.data ?? {};
  const salonId = assertStringField(rawData.salonId, 'salonId');
  const clientId = assertStringField(rawData.clientId, 'clientId');
  const displayName = optionalStringField(rawData.displayName);
  const email = optionalStringField(rawData.email);

  const db = getFirestore();
  const userId = request.auth.uid;

  const [userSnapshot, clientSnapshot] = await Promise.all([
    db.collection('users').doc(userId).get(),
    db.collection('clients').doc(clientId).get(),
  ]);

  if (!userSnapshot.exists) {
    throw new HttpsError('permission-denied', 'User profile not found.');
  }
  if (!clientSnapshot.exists) {
    throw new HttpsError('not-found', 'Client profile not found.');
  }

  const clientData = clientSnapshot.data() ?? {};
  const clientSalonId = typeof clientData.salonId === 'string' ? clientData.salonId : '';
  if (clientSalonId !== salonId) {
    throw new HttpsError(
      'permission-denied',
      'Client profile belongs to a different salon.',
    );
  }

  const userData = userSnapshot.data() ?? {};
  const allowedSalons =
    Array.isArray(userData.salonIds)
      ? userData.salonIds
          .map((entry: unknown) => (typeof entry === 'string' ? entry.trim() : ''))
          .filter(Boolean)
      : [];
  const hasAccess = allowedSalons.includes(salonId);
  if (!hasAccess) {
    const requestsSnapshot = await db
      .collection('salon_access_requests')
      .where('userId', '==', userId)
      .where('salonId', '==', salonId)
      .where('status', '==', 'approved')
      .limit(1)
      .get();
    if (requestsSnapshot.empty) {
      throw new HttpsError(
        'permission-denied',
        'No approved access request found for this salon.',
      );
    }
  }

  const updateData: Record<string, unknown> = {
    role: 'client',
    clientId,
    salonId,
    salonIds: FieldValue.arrayUnion(salonId),
    roles: FieldValue.arrayUnion('client'),
    availableRoles: FieldValue.arrayUnion('client'),
    pendingSalonId: FieldValue.delete(),
    pendingFirstName: FieldValue.delete(),
    pendingLastName: FieldValue.delete(),
    pendingPhone: FieldValue.delete(),
    pendingDateOfBirth: FieldValue.delete(),
    pendingExtraData: FieldValue.delete(),
    pendingUpdatedAt: FieldValue.delete(),
  };

  if (displayName) {
    updateData.displayName = displayName;
  }
  if (email) {
    updateData.email = email.toLowerCase();
  }

  await userSnapshot.ref.set(updateData, { merge: true });

  return {
    success: true,
  };
});
