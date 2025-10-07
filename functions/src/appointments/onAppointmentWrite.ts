import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

import { db, FieldValue } from '../utils/firestore';

const LAST_MINUTE_SLOTS_COLLECTION = 'last_minute_slots';
const APPOINTMENTS_COLLECTION = 'appointments';
const CLIENTS_COLLECTION = 'clients';
const ACTIVE_APPOINTMENT_STATUSES = new Set(['scheduled', 'confirmed']);

function extractSlotId(data: FirebaseFirestore.DocumentData | null): string | null {
  if (!data) {
    return null;
  }
  const fromField = data.lastMinuteSlotId;
  if (typeof fromField === 'string' && fromField.trim().length > 0) {
    return fromField.trim();
  }
  const notes = data.notes;
  if (typeof notes === 'string') {
    const match = notes.match(/Prenotazione last-minute ([a-zA-Z0-9-]+)/);
    if (match && match[1]) {
      return match[1];
    }
  }
  return null;
}

function parseTimestamp(value: unknown): Date | null {
  if (value instanceof Date) {
    return value;
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

export const syncAppointmentWithLastMinuteSlot = functions.region('europe-west1').firestore
  .document(`${APPOINTMENTS_COLLECTION}/{appointmentId}`)
  .onWrite(async (change) => {
    const beforeData = change.before.exists ? change.before.data() ?? null : null;
    const afterData = change.after.exists ? change.after.data() ?? null : null;

    const beforeSlotId = extractSlotId(beforeData);
    const afterSlotId = extractSlotId(afterData);
    const slotId = afterSlotId ?? beforeSlotId;
    if (!slotId) {
      return;
    }

    await db.runTransaction(async (tx) => {
      const slotRef = db.collection(LAST_MINUTE_SLOTS_COLLECTION).doc(slotId);
      const slotSnap = await tx.get(slotRef);
      if (!slotSnap.exists) {
        return;
      }

      const slotData = slotSnap.data() ?? {};
      const currentlyBookedClientId = typeof slotData.bookedClientId === 'string'
        ? slotData.bookedClientId
        : null;

      if (!afterData) {
        // Appointment deleted -> release slot
        tx.update(slotRef, {
          availableSeats: 1,
          bookedClientId: null,
          bookedClientName: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      const status = String(afterData.status ?? 'scheduled');
      const isActive = ACTIVE_APPOINTMENT_STATUSES.has(status);
      const clientId = String(afterData.clientId ?? '').trim();

      if (!isActive || !clientId) {
        if (currentlyBookedClientId === clientId || !currentlyBookedClientId) {
          tx.update(slotRef, {
            availableSeats: 1,
            bookedClientId: null,
            bookedClientName: null,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        return;
      }

      let clientName: string | null = null;
      if (currentlyBookedClientId === clientId) {
        clientName = typeof slotData.bookedClientName === 'string' ? slotData.bookedClientName : null;
      }
      if (!clientName) {
        const clientRef = db.collection(CLIENTS_COLLECTION).doc(clientId);
        const clientSnap = await tx.get(clientRef);
        if (clientSnap.exists) {
          clientName = String(clientSnap.data()?.fullName ?? '');
        }
      }

      const startDate = parseTimestamp(afterData.start) ?? new Date();
      const endDate = parseTimestamp(afterData.end) ?? new Date(startDate.getTime() + 30 * 60000);
      const durationMinutes = Math.max(5, Math.round((endDate.getTime() - startDate.getTime()) / 60000));

      tx.update(slotRef, {
        availableSeats: 0,
        bookedClientId: clientId,
        bookedClientName: clientName,
        startAt: admin.firestore.Timestamp.fromDate(startDate),
        durationMinutes,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  });
