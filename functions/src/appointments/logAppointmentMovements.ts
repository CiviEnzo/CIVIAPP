import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

import { db, FieldValue } from '../utils/firestore';

const APPOINTMENTS_COLLECTION = 'appointments';
const MOVEMENTS_COLLECTION = 'client_app_movements';

type AppointmentData = FirebaseFirestore.DocumentData | null;

interface MovementPayload {
  salonId: string;
  clientId: string;
  appointmentId: string;
  type: 'appointmentUpdated' | 'appointmentCancelled';
  channel?: string | null;
  source?: string | null;
  createdBy?: string | null;
  metadata: Record<string, unknown>;
}

const CANCELLATION_STATUS = 'cancelled';

function normalizeString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function isClientChannel(channel: string): boolean {
  const normalized = channel.toLowerCase();
  return normalized.includes('self') || normalized.includes('client') || normalized.includes('app');
}

function normalizeStatus(value: unknown): string {
  const raw = normalizeString(value);
  if (!raw) {
    return 'scheduled';
  }
  return raw;
}

function parseTimestamp(value: unknown): Date | null {
  if (!value) {
    return null;
  }
  if (value instanceof Date) {
    return value;
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      return null;
    }
    if (value > 9_999_999_999) {
      return new Date(value);
    }
    return new Date(value * 1000);
  }
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (typeof value === 'object' && value !== null) {
    const seconds = (value as { seconds?: number }).seconds;
    if (typeof seconds === 'number') {
      const nanoseconds = (value as { nanoseconds?: number }).nanoseconds ?? 0;
      const millis = seconds * 1000 + Math.round(nanoseconds / 1_000_000);
      return new Date(millis);
    }
  }
  return null;
}

function toFirestoreTimestamp(value: Date | null): admin.firestore.Timestamp | undefined {
  if (!value) {
    return undefined;
  }
  return admin.firestore.Timestamp.fromDate(value);
}

function hasDateChanged(before: Date | null, after: Date | null): boolean {
  if (!before || !after) {
    return false;
  }
  return before.getTime() !== after.getTime();
}

function buildMovementPayload(
  appointmentId: string,
  beforeData: AppointmentData,
  afterData: AppointmentData,
): MovementPayload | null {
  if (!afterData && !beforeData) {
    return null;
  }

  const salonId = normalizeString(afterData?.salonId ?? beforeData?.salonId);
  const clientId = normalizeString(afterData?.clientId ?? beforeData?.clientId);
  if (!salonId || !clientId) {
    return null;
  }

  const beforeStatus = normalizeStatus(beforeData?.status);
  const afterStatus = normalizeStatus(afterData?.status ?? beforeStatus);
  const beforeStart = parseTimestamp(beforeData?.start);
  const afterStart = parseTimestamp(afterData?.start) ?? beforeStart;
  const beforeEnd = parseTimestamp(beforeData?.end);
  const afterEnd = parseTimestamp(afterData?.end) ?? beforeEnd;
  const beforeStaffId = normalizeString(beforeData?.staffId);
  const afterStaffId = normalizeString(afterData?.staffId ?? beforeStaffId);
  const bookingChannel = normalizeString(afterData?.bookingChannel ?? beforeData?.bookingChannel);

  if (bookingChannel && isClientChannel(bookingChannel)) {
    return null;
  }

  let movementType: MovementPayload['type'] | null = null;
  const metadata: Record<string, unknown> = {};

  if (!afterData) {
    if (beforeStatus === CANCELLATION_STATUS) {
      return null;
    }
    movementType = 'appointmentCancelled';
    metadata.previousStatus = beforeStatus;
    metadata.newStatus = CANCELLATION_STATUS;
    metadata.cancellationMode = 'deleted';
    metadata.previousStart = toFirestoreTimestamp(beforeStart);
    metadata.previousEnd = toFirestoreTimestamp(beforeEnd);
  } else if (!beforeData) {
    // Creation handled elsewhere (we only need update/cancel here).
    return null;
  } else {
    const statusChanged = beforeStatus !== afterStatus;
    const startChanged = hasDateChanged(beforeStart, afterStart);
    const endChanged = hasDateChanged(beforeEnd, afterEnd);
    const staffChanged = beforeStaffId !== afterStaffId;

    if (statusChanged && afterStatus === CANCELLATION_STATUS) {
      movementType = 'appointmentCancelled';
      metadata.previousStatus = beforeStatus;
      metadata.newStatus = afterStatus;
      metadata.previousStart = toFirestoreTimestamp(beforeStart);
      metadata.newStart = toFirestoreTimestamp(afterStart);
      metadata.previousEnd = toFirestoreTimestamp(beforeEnd);
      metadata.newEnd = toFirestoreTimestamp(afterEnd);
      const cancelReason = normalizeString(afterData.cancelReason ?? beforeData?.cancelReason);
      if (cancelReason) {
        metadata.cancelReason = cancelReason;
      }
      if ('cancelledByRole' in afterData) {
        metadata.actorRole = normalizeString(afterData.cancelledByRole);
      } else if ('updatedByRole' in afterData) {
        metadata.actorRole = normalizeString(afterData.updatedByRole);
      }
    } else if (statusChanged || startChanged || endChanged || staffChanged) {
      movementType = 'appointmentUpdated';
      metadata.previousStatus = beforeStatus;
      metadata.newStatus = afterStatus;
      if (startChanged) {
        metadata.previousStart = toFirestoreTimestamp(beforeStart);
        metadata.newStart = toFirestoreTimestamp(afterStart);
      }
      if (endChanged) {
        metadata.previousEnd = toFirestoreTimestamp(beforeEnd);
        metadata.newEnd = toFirestoreTimestamp(afterEnd);
      }
      if (staffChanged) {
        metadata.previousStaffId = beforeStaffId || undefined;
        metadata.newStaffId = afterStaffId || undefined;
      }
      const reason = normalizeString(afterData.updateReason ?? afterData.rescheduleReason);
      if (reason) {
        metadata.updateReason = reason;
      }
      if ('updatedByRole' in afterData) {
        metadata.actorRole = normalizeString(afterData.updatedByRole);
      }
    }
  }

  if (!movementType) {
    return null;
  }

  const createdBy = normalizeString(afterData?.updatedBy ?? beforeData?.updatedBy);

  const cleanedMetadata: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(metadata)) {
    if (value !== undefined && value !== null && value !== '') {
      cleanedMetadata[key] = value;
    }
  }

  return {
    salonId,
    clientId,
    appointmentId,
    type: movementType,
    channel: bookingChannel || undefined,
    source: bookingChannel || undefined,
    createdBy: createdBy || undefined,
    metadata: cleanedMetadata,
  };
}

export const logClientAppAppointmentMovements = functions
  .region('europe-west1')
  .firestore.document(`${APPOINTMENTS_COLLECTION}/{appointmentId}`)
  .onWrite(async (change, context) => {
    const beforeData = change.before.exists ? change.before.data() ?? null : null;
    const afterData = change.after.exists ? change.after.data() ?? null : null;

    const movement = buildMovementPayload(
      context.params.appointmentId,
      beforeData,
      afterData,
    );

    if (!movement) {
      return;
    }

    await db.collection(MOVEMENTS_COLLECTION).add({
      salonId: movement.salonId,
      clientId: movement.clientId,
      appointmentId: movement.appointmentId,
      type: movement.type,
      channel: movement.channel ?? null,
      source: movement.source ?? null,
      createdBy: movement.createdBy ?? null,
      metadata: movement.metadata,
      timestamp: FieldValue.serverTimestamp(),
    });
  });
