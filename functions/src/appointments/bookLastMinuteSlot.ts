import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

import { db, FieldValue } from '../utils/firestore';

const APPOINTMENTS_COLLECTION = 'appointments';
const LAST_MINUTE_SLOTS_COLLECTION = 'last_minute_slots';
const CLIENTS_COLLECTION = 'clients';

interface CallableAppointmentPayload {
  id: string;
  salonId: string;
  clientId: string;
  staffId: string;
  serviceId?: string | null;
  serviceIds?: string[];
  start: string;
  end: string;
  status?: string;
  notes?: string | null;
  packageId?: string | null;
  roomId?: string | null;
}

interface CallableResult {
  status: 'ok';
  appointment: Record<string, unknown>;
  slot: Record<string, unknown>;
}

function parseIsoDate(value: unknown, fieldName: string): Date {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} must be a non-empty ISO string`,
    );
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${fieldName} must be a valid ISO date string`,
    );
  }
  return parsed;
}

export const bookLastMinuteSlot = functions.region('europe-west1').https.onCall(
  async (data, context): Promise<CallableResult> => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
    }

    const slotId = String(data?.slotId ?? '').trim();
    if (!slotId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'A valid slotId must be provided.',
      );
    }

    const rawAppointment = (data?.appointment ?? null) as CallableAppointmentPayload | null;
    if (!rawAppointment || typeof rawAppointment !== 'object') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Appointment payload is required.',
      );
    }

    const appointmentId = String(rawAppointment.id ?? '').trim();
    const salonId = String(rawAppointment.salonId ?? '').trim();
    const clientId = String(rawAppointment.clientId ?? '').trim();
    const staffId = String(rawAppointment.staffId ?? '').trim();

    if (!appointmentId || !salonId || !clientId || !staffId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Appointment id, salonId, clientId and staffId are mandatory.',
      );
    }

    const start = parseIsoDate(rawAppointment.start, 'start');
    const end = parseIsoDate(rawAppointment.end, 'end');
    if (end.getTime() <= start.getTime()) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Appointment end must be after start.',
      );
    }

    const durationMinutes = Math.max(
      5,
      Math.round((end.getTime() - start.getTime()) / 60000),
    );

    const normalizedServiceIds = Array.isArray(rawAppointment.serviceIds)
      ? rawAppointment.serviceIds
          .map((value) => String(value))
          .filter((value) => value.trim().length > 0)
      : [];
    const rawServiceId = rawAppointment.serviceId
      ? String(rawAppointment.serviceId)
      : null;

    const appointmentStatus = String(rawAppointment.status ?? 'scheduled');
    const notes = rawAppointment.notes ? String(rawAppointment.notes) : null;
    const packageId = rawAppointment.packageId ? String(rawAppointment.packageId) : null;
    const roomId = rawAppointment.roomId ? String(rawAppointment.roomId) : null;

    const clientNameFromPayload = data?.clientName ? String(data.clientName) : null;

    const result = await db.runTransaction(async (tx) => {
      const slotRef = db.collection(LAST_MINUTE_SLOTS_COLLECTION).doc(slotId);
      const slotSnap = await tx.get(slotRef);
      if (!slotSnap.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Last-minute slot not found.',
        );
      }

      const slotData = slotSnap.data() ?? {};
      const slotSalonId = String(slotData.salonId ?? '').trim();
      if (slotSalonId && slotSalonId !== salonId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Slot belongs to a different salon.',
        );
      }
      const slotOperatorId = slotData.operatorId ? String(slotData.operatorId) : null;
      if (slotOperatorId && slotOperatorId !== staffId) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Slot is assigned to another staff member.',
        );
      }

      const appointmentRef = db.collection(APPOINTMENTS_COLLECTION).doc(appointmentId);
      const existingAppointmentSnap = await tx.get(appointmentRef);
      if (existingAppointmentSnap.exists) {
        throw new functions.https.HttpsError(
          'already-exists',
          'An appointment with the provided id already exists.',
        );
      }

      const rawSeats = Number(slotData.availableSeats ?? 0);
      const bookedClientId = slotData.bookedClientId ? String(slotData.bookedClientId) : null;
      const isAlreadyBookedByClient = bookedClientId === clientId;
      if (!isAlreadyBookedByClient) {
        if (bookedClientId && bookedClientId !== clientId) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Last-minute slot has already been booked.',
          );
        }
        if (!rawSeats || rawSeats <= 0) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Last-minute slot is no longer available.',
          );
        }
      }

      let clientName = clientNameFromPayload;
      if (!clientName) {
        const clientRef = db.collection(CLIENTS_COLLECTION).doc(clientId);
        const clientSnap = await tx.get(clientRef);
        if (clientSnap.exists) {
          clientName = String(clientSnap.data()?.fullName ?? '');
        }
      }

      const serverTimestamp = FieldValue.serverTimestamp();

      const slotServiceId = slotData.serviceId ? String(slotData.serviceId) : null;
      const serviceIdsForAppointment = normalizedServiceIds.length > 0
        ? normalizedServiceIds
        : slotServiceId
          ? [slotServiceId]
          : [];
      const serviceIdForAppointment = rawServiceId
        ? rawServiceId
        : serviceIdsForAppointment.length > 0
          ? serviceIdsForAppointment[0]
          : null;

      const appointmentData: Record<string, unknown> = {
        salonId,
        clientId,
        staffId,
        serviceId: serviceIdForAppointment,
        serviceIds: serviceIdsForAppointment,
        start: admin.firestore.Timestamp.fromDate(start),
        end: admin.firestore.Timestamp.fromDate(end),
        status: appointmentStatus,
        notes,
        packageId,
        roomId,
        lastMinuteSlotId: slotId,
        createdAt: serverTimestamp,
        updatedAt: serverTimestamp,
      };

      tx.set(appointmentRef, appointmentData, { merge: true });

      const updatedSlotData: Record<string, unknown> = {
        availableSeats: 0,
        bookedClientId: clientId,
        bookedClientName: clientName ?? null,
        startAt: admin.firestore.Timestamp.fromDate(start),
        durationMinutes,
        updatedAt: serverTimestamp,
      };

      tx.update(slotRef, updatedSlotData);

      return {
        appointment: {
          id: appointmentId,
          salonId,
          clientId,
          staffId,
          serviceId: serviceIdForAppointment,
          serviceIds: serviceIdsForAppointment,
          start: start.toISOString(),
          end: end.toISOString(),
          status: appointmentStatus,
          notes,
          packageId,
          roomId,
          lastMinuteSlotId: slotId,
        },
        slot: {
          id: slotId,
          salonId,
          serviceId: slotServiceId ?? serviceIdForAppointment,
          serviceName: slotData.serviceName ?? 'Slot last-minute',
          start: start.toISOString(),
          durationMinutes,
          basePrice: Number(slotData.basePrice ?? 0),
          discountPercentage: Number(slotData.discountPct ?? slotData.discountPercentage ?? 0),
          priceNow: Number(slotData.priceNow ?? slotData.price ?? 0),
          roomId: slotData.roomId ?? null,
          roomName: slotData.roomName ?? null,
          operatorId: slotOperatorId,
          operatorName: slotData.operatorName ?? null,
          availableSeats: 0,
          loyaltyPoints: Number(slotData.loyaltyPoints ?? 0),
          bookedClientId: clientId,
          bookedClientName: clientName ?? null,
          paymentMode:
            typeof slotData.paymentMode === 'string'
              ? String(slotData.paymentMode)
              : 'online',
        },
      };
    });

    return {
      status: 'ok',
      appointment: result.appointment,
      slot: result.slot,
    };
  },
);
