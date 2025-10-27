import { randomBytes } from 'crypto';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

interface CreateClientAccountPayload {
  email: string;
  salonId: string;
  clientId: string;
  displayName: string;
}

function assertStringField(
  value: unknown,
  fieldName: keyof CreateClientAccountPayload,
): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new HttpsError('invalid-argument', `Field "${fieldName}" is required.`);
  }
  return value.trim();
}

export const createClientAccount = onCall({ region: 'europe-west3' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const rawData = request.data ?? {};
  const email = assertStringField(rawData.email, 'email').toLowerCase();
  const salonId = assertStringField(rawData.salonId, 'salonId');
  const clientId = assertStringField(rawData.clientId, 'clientId');
  const displayName = assertStringField(rawData.displayName, 'displayName');

  const db = getFirestore();
  const auth = getAuth();

  const requesterSnapshot = await db.collection('users').doc(request.auth.uid).get();
  if (!requesterSnapshot.exists) {
    throw new HttpsError('permission-denied', 'The requester profile was not found.');
  }
  const requesterData = requesterSnapshot.data() ?? {};
  const requesterRole = typeof requesterData.role === 'string'
    ? requesterData.role.toLowerCase()
    : '';
  const requesterSalonIds = Array.isArray(requesterData.salonIds)
    ? requesterData.salonIds.map((id: unknown) => (typeof id === 'string' ? id : '')).filter(Boolean)
    : [];

  const isAdminForSalon = requesterRole === 'admin' && requesterSalonIds.includes(salonId);
  if (!isAdminForSalon) {
    throw new HttpsError(
      'permission-denied',
      'You are not authorized to manage client accounts for this salon.',
    );
  }

  const usersCollection = db.collection('users');

  const cleanupPendingFields: Record<string, unknown> = {
    pendingSalonId: FieldValue.delete(),
    pendingFirstName: FieldValue.delete(),
    pendingLastName: FieldValue.delete(),
    pendingPhone: FieldValue.delete(),
    pendingDateOfBirth: FieldValue.delete(),
    pendingExtraData: FieldValue.delete(),
    pendingUpdatedAt: FieldValue.delete(),
  };

  let targetUid: string | undefined;

  const existingByClient = await usersCollection
    .where('clientId', '==', clientId)
    .limit(1)
    .get();
  if (!existingByClient.empty) {
    targetUid = existingByClient.docs[0].id;
  } else {
    const existingByEmail = await usersCollection
      .where('email', '==', email)
      .limit(1)
      .get();
    if (!existingByEmail.empty) {
      targetUid = existingByEmail.docs[0].id;
    }
  }

  let authUser = null;
  try {
    authUser = await auth.getUserByEmail(email);
  } catch (error: unknown) {
    if (error instanceof Error && 'code' in error && (error as { code: string }).code === 'auth/user-not-found') {
      authUser = null;
    } else {
      throw new HttpsError('internal', `Unable to lookup auth user: ${(error as Error).message}`);
    }
  }

  let createdAuthUser = false;

  if (!authUser) {
    const randomPasswordSeed = randomBytes(32).toString('base64').replace(/[^a-zA-Z0-9]/g, '');
    const randomPassword = (randomPasswordSeed.length >= 12 ? randomPasswordSeed : `${Date.now()}TempUser`).slice(0, 16);
    try {
      authUser = await auth.createUser({
        email,
        password: randomPassword,
        displayName,
        emailVerified: false,
      });
      createdAuthUser = true;
    } catch (error: unknown) {
      if (error instanceof Error && 'code' in error && (error as { code: string }).code === 'auth/email-already-exists') {
        authUser = await auth.getUserByEmail(email);
      } else {
        throw new HttpsError('internal', `Unable to create auth user: ${(error as Error).message}`);
      }
    }
  }

  if (!targetUid) {
    targetUid = authUser.uid;
  }

  await usersCollection.doc(targetUid).set(
    {
      clientId,
      email,
      displayName,
      role: 'client',
      roles: FieldValue.arrayUnion('client'),
      availableRoles: FieldValue.arrayUnion('client'),
      salonId,
      salonIds: FieldValue.arrayUnion(salonId),
      ...cleanupPendingFields,
    },
    { merge: true },
  );

  return {
    uid: authUser.uid,
    shouldSendPasswordReset: createdAuthUser,
  };
});
