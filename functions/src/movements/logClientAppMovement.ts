import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';

type MovementType =
  | 'registration'
  | 'appointmentCreated'
  | 'appointmentUpdated'
  | 'appointmentCancelled'
  | 'purchase'
  | 'reviewClick'
  | 'lastMinutePurchase';

const ALLOWED_TYPES: Set<MovementType> = new Set([
  'registration',
  'appointmentCreated',
  'appointmentUpdated',
  'appointmentCancelled',
  'purchase',
  'reviewClick',
  'lastMinutePurchase',
]);

const sanitizeString = (value: unknown, field: string, optional = false): string | undefined => {
  if (typeof value === 'undefined' || value === null) {
    if (optional) {
      return undefined;
    }
    throw new HttpsError('invalid-argument', `Field "${field}" is required.`);
  }
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', `Field "${field}" must be a string.`);
  }
  const trimmed = value.trim();
  if (!trimmed && !optional) {
    throw new HttpsError('invalid-argument', `Field "${field}" cannot be empty.`);
  }
  return trimmed || undefined;
};

const sanitizeMetadata = (value: unknown): Record<string, unknown> | undefined => {
  if (value === null || typeof value === 'undefined') {
    return undefined;
  }
  if (typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'Metadata must be an object.');
  }
  const normalized: Record<string, unknown> = {};
  Object.entries(value as Record<string, unknown>).forEach(([key, entry]) => {
    if (typeof key !== 'string' || !key.trim()) {
      return;
    }
    normalized[key.trim()] = entry;
  });
  return Object.keys(normalized).length ? normalized : undefined;
};

const db = getFirestore();

export const logClientAppMovement = onCall({ region: 'europe-west3' }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const rawData = (request.data ?? {}) as Record<string, unknown>;
  const type = sanitizeString(rawData.type, 'type') as MovementType;
  if (!ALLOWED_TYPES.has(type)) {
    throw new HttpsError('invalid-argument', `Movement type "${type}" is not supported.`);
  }
  const salonId = sanitizeString(rawData.salonId, 'salonId')!;
  const clientId = sanitizeString(rawData.clientId, 'clientId')!;
  const channel = sanitizeString(rawData.channel, 'channel', true);
  const source = sanitizeString(rawData.source, 'source', true);
  const label = sanitizeString(rawData.label, 'label', true);
  const description = sanitizeString(rawData.description, 'description', true);
  const appointmentId = sanitizeString(rawData.appointmentId, 'appointmentId', true);
  const saleId = sanitizeString(rawData.saleId, 'saleId', true);
  const lastMinuteSlotId = sanitizeString(rawData.lastMinuteSlotId, 'lastMinuteSlotId', true);
  const metadata = sanitizeMetadata(rawData.metadata);

  let resolvedTimestamp: Date | undefined;
  if (rawData.timestamp) {
    const parsed = sanitizeString(rawData.timestamp, 'timestamp');
    if (parsed) {
      const date = new Date(parsed);
      if (Number.isNaN(date.valueOf())) {
        throw new HttpsError('invalid-argument', 'Invalid timestamp format.');
      }
      resolvedTimestamp = date;
    }
  }

  const requesterRef = db.collection('users').doc(request.auth.uid);
  const requesterSnapshot = await requesterRef.get();
  if (!requesterSnapshot.exists) {
    throw new HttpsError('permission-denied', 'Requester profile not found.');
  }

  const requesterData = requesterSnapshot.data() ?? {};
  const requesterRole = typeof requesterData.role === 'string'
    ? requesterData.role.toLowerCase()
    : '';
  if (requesterRole !== 'client') {
    throw new HttpsError('permission-denied', 'Only clients can log movements.');
  }
  const requesterClientId = typeof requesterData.clientId === 'string'
    ? requesterData.clientId
    : '';
  const salonIds: string[] = Array.isArray(requesterData.salonIds)
    ? requesterData.salonIds.filter((id: unknown): id is string => typeof id === 'string')
    : typeof requesterData.salonId === 'string'
      ? [requesterData.salonId]
      : [];
  const pendingSalonId = typeof requesterData.pendingSalonId === 'string'
    ? requesterData.pendingSalonId
    : null;

  const hasSalonAccess = salonIds.includes(salonId);
  const isRegistration = type === 'registration';
  const clientMatchesProfile = requesterClientId && requesterClientId === clientId;
  const pendingMatchesSalon = pendingSalonId === salonId;

  if (isRegistration) {
    if (!clientMatchesProfile && !pendingMatchesSalon) {
      throw new HttpsError(
        'permission-denied',
        'Registration events must target the authenticated client.',
      );
    }
  } else {
    if (!clientMatchesProfile) {
      throw new HttpsError('permission-denied', 'Only the owning client can log this event.');
    }
    if (!hasSalonAccess) {
      throw new HttpsError('permission-denied', 'Client does not have access to this salon.');
    }
  }

  const docRef = db.collection('client_app_movements').doc();
  const payload: Record<string, unknown> = {
    salonId,
    clientId,
    type,
    timestamp: resolvedTimestamp ?? FieldValue.serverTimestamp(),
    channel,
    source,
    label,
    description,
    appointmentId,
    saleId,
    lastMinuteSlotId,
    metadata,
    createdBy: request.auth.uid,
  };

  Object.keys(payload).forEach((key) => {
    if (typeof payload[key] === 'undefined' || payload[key] === null) {
      delete payload[key];
    }
  });

  await docRef.set(payload);
  const snapshot = await docRef.get();
  const stored = snapshot.data() ?? {};
  const storedTimestamp = stored.timestamp instanceof Timestamp
    ? stored.timestamp.toDate().toISOString()
    : resolvedTimestamp?.toISOString() ?? new Date().toISOString();

  return {
    movement: {
      id: docRef.id,
      salonId,
      clientId,
      type,
      timestamp: storedTimestamp,
      channel: stored.channel ?? channel ?? null,
      source: stored.source ?? source ?? null,
      label: stored.label ?? label ?? null,
      description: stored.description ?? description ?? null,
      appointmentId: stored.appointmentId ?? appointmentId ?? null,
      saleId: stored.saleId ?? saleId ?? null,
      lastMinuteSlotId: stored.lastMinuteSlotId ?? lastMinuteSlotId ?? null,
      metadata: stored.metadata ?? metadata ?? {},
      createdBy: stored.createdBy ?? request.auth.uid,
    },
  };
});
