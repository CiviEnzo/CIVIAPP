import {
  FieldPath,
  FieldValue,
  Firestore,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';

const firestore: Firestore = getFirestore();

export { firestore as db, FieldValue, FieldPath, Timestamp };

export const serverTimestamp = () => FieldValue.serverTimestamp();
