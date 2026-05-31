import { getAuth } from 'firebase-admin/auth';
import {
  DocumentData,
  FieldValue,
  Query,
  getFirestore,
} from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

const REGION = 'europe-west3';
const MAX_BATCH_SIZE = 450;

interface DeleteAccountPayload {
  confirmation?: unknown;
}

interface DeleteSummary {
  userDeleted: boolean;
  authDeleted: boolean;
  clientId?: string;
  staffId?: string;
  deletedDocuments: number;
  deletedFiles: number;
}

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

async function deleteQueryResults(query: Query<DocumentData>): Promise<number> {
  const db = getFirestore();
  let deleted = 0;

  while (true) {
    const snapshot = await query.limit(MAX_BATCH_SIZE).get();
    if (snapshot.empty) {
      return deleted;
    }

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deleted += snapshot.size;

    if (snapshot.size < MAX_BATCH_SIZE) {
      return deleted;
    }
  }
}

async function deleteStoragePath(path: unknown): Promise<boolean> {
  const storagePath = normalizeString(path);
  if (!storagePath) {
    return false;
  }
  try {
    await getStorage().bucket().file(storagePath).delete({ ignoreNotFound: true });
    return true;
  } catch (error) {
    console.warn(`Unable to delete storage object ${storagePath}`, error);
    return false;
  }
}

async function deleteClientData(clientId: string): Promise<Pick<DeleteSummary, 'deletedDocuments' | 'deletedFiles'>> {
  const db = getFirestore();
  let deletedDocuments = 0;
  let deletedFiles = 0;

  const photoSnapshot = await db.collection('client_photos').where('clientId', '==', clientId).get();
  for (const doc of photoSnapshot.docs) {
    if (await deleteStoragePath(doc.data().storagePath)) {
      deletedFiles += 1;
    }
  }

  const collageSnapshot = await db.collection('client_photo_collages').where('clientId', '==', clientId).get();
  for (const doc of collageSnapshot.docs) {
    if (await deleteStoragePath(doc.data().storagePath)) {
      deletedFiles += 1;
    }
  }

  const collections = [
    'appointments',
    'sales',
    'payment_tickets',
    'client_photos',
    'client_photo_collages',
    'client_notes',
    'quotes',
    'client_questionnaires',
    'client_app_movements',
    'message_outbox',
  ];

  for (const collection of collections) {
    deletedDocuments += await deleteQueryResults(
      db.collection(collection).where('clientId', '==', clientId),
    );
  }

  await db.collection('clients').doc(clientId).delete();
  deletedDocuments += 1;

  return { deletedDocuments, deletedFiles };
}

async function deleteStaffData(staffId: string): Promise<Pick<DeleteSummary, 'deletedDocuments' | 'deletedFiles'>> {
  const db = getFirestore();
  let deletedDocuments = 0;
  let deletedFiles = 0;

  const staffSnapshot = await db.collection('staff').doc(staffId).get();
  if (staffSnapshot.exists) {
    const staffData = staffSnapshot.data() ?? {};
    if (await deleteStoragePath(staffData.avatarStoragePath)) {
      deletedFiles += 1;
    }
  }

  const appointmentSnapshot = await db.collection('appointments').where('staffId', '==', staffId).get();
  for (const doc of appointmentSnapshot.docs) {
    await doc.ref.update({ staffId: '' });
  }

  const publicAppointmentSnapshot = await db.collection('public_appointments').where('staffId', '==', staffId).get();
  for (const doc of publicAppointmentSnapshot.docs) {
    await doc.ref.update({ staffId: '' });
  }

  for (const collection of ['shifts', 'staff_absences', 'staff_absence_requests']) {
    deletedDocuments += await deleteQueryResults(
      db.collection(collection).where('staffId', '==', staffId),
    );
  }

  const cashFlowsSnapshot = await db.collection('cash_flows').where('staffId', '==', staffId).get();
  for (const doc of cashFlowsSnapshot.docs) {
    await doc.ref.update({ staffId: FieldValue.delete() });
  }

  await db.collection('staff').doc(staffId).delete();
  deletedDocuments += 1;

  return { deletedDocuments, deletedFiles };
}

export const deleteCurrentUserAccount = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const payload = (request.data ?? {}) as DeleteAccountPayload;
  if (normalizeString(payload.confirmation).toUpperCase() !== 'ELIMINA') {
    throw new HttpsError('invalid-argument', 'Confirmation is required.');
  }

  const db = getFirestore();
  const auth = getAuth();
  const uid = request.auth.uid;
  const userRef = db.collection('users').doc(uid);
  const userSnapshot = await userRef.get();
  const userData = userSnapshot.data() ?? {};
  const clientId = normalizeString(userData.clientId);
  const staffId = normalizeString(userData.staffId);

  const summary: DeleteSummary = {
    userDeleted: false,
    authDeleted: false,
    deletedDocuments: 0,
    deletedFiles: 0,
  };

  if (clientId) {
    const clientResult = await deleteClientData(clientId);
    summary.clientId = clientId;
    summary.deletedDocuments += clientResult.deletedDocuments;
    summary.deletedFiles += clientResult.deletedFiles;
  }

  if (staffId) {
    const staffResult = await deleteStaffData(staffId);
    summary.staffId = staffId;
    summary.deletedDocuments += staffResult.deletedDocuments;
    summary.deletedFiles += staffResult.deletedFiles;
  }

  await deleteQueryResults(db.collection('salon_access_requests').where('userId', '==', uid));
  await deleteQueryResults(db.collection('client_app_movements').where('userId', '==', uid));
  await deleteQueryResults(db.collection('staff_absence_requests').where('userId', '==', uid));

  await userRef.delete();
  summary.userDeleted = true;
  summary.deletedDocuments += 1;

  try {
    await auth.deleteUser(uid);
    summary.authDeleted = true;
  } catch (error) {
    console.warn(`Unable to delete auth user ${uid}`, error);
    throw new HttpsError('internal', 'Account data was deleted, but Auth user deletion failed.');
  }

  return summary;
});
