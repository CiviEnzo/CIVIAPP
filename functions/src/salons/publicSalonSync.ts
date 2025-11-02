import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

const firestore = admin.firestore;
const functionsEU = functions.region('europe-west1');

const COLLECTION_PUBLIC_SALONS = 'public_salons';

type SalonSnapshot = admin.firestore.DocumentData;

function readString(value: unknown): string | undefined {
  if (typeof value === 'string') {
    return value.trim();
  }
  return undefined;
}

function readNumber(value: unknown): number | undefined {
  if (typeof value === 'number' && !Number.isNaN(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value);
    if (!Number.isNaN(parsed)) {
      return parsed;
    }
  }
  return undefined;
}

function sanitizeSocialLinks(input: unknown): Record<string, string> {
  if (!input || typeof input !== 'object') {
    return {};
  }

  const result: Record<string, string> = {};
  Object.entries(input as Record<string, unknown>).forEach(([key, value]) => {
    const label = key.trim();
    const link = readString(value);
    if (!label || !link) {
      return;
    }
    result[label] = link;
  });
  return result;
}

function sanitizeClientRegistration(input: unknown): Record<string, unknown> {
  if (!input || typeof input !== 'object') {
    return {
      accessMode: 'open',
      extraFields: [],
    };
  }

  const data = input as Record<string, unknown>;
  const accessMode =
    typeof data.accessMode === 'string' && data.accessMode.trim().length > 0
      ? data.accessMode
      : 'open';
  const extraFields = Array.isArray(data.extraFields)
    ? data.extraFields
        .map((item) => (typeof item === 'string' ? item : String(item ?? '')))
        .map((item) => item.trim())
        .filter((item) => item.length > 0)
    : [];

  return {
    accessMode,
    extraFields,
  };
}

function buildPublicSalonPayload(
  salonId: string,
  data: SalonSnapshot,
): Record<string, unknown> {
  const payload: Record<string, unknown> = {
    salonId,
    name: readString(data.name) ?? '',
    address: readString(data.address) ?? '',
    city: readString(data.city) ?? '',
    phone: readString(data.phone) ?? '',
    email: readString(data.email) ?? '',
    description: readString(data.description),
    bookingLink: readString(data.bookingLink),
    googlePlaceId: readString(data.googlePlaceId),
    status: readString(data.status) ?? 'active',
    socialLinks: sanitizeSocialLinks(data.socialLinks),
    clientRegistration: sanitizeClientRegistration(data.clientRegistration),
    latitude: readNumber(data.latitude),
    longitude: readNumber(data.longitude),
    coverImageUrl:
      readString(
        (data.coverImageUrl as unknown) ?? (data.imageUrl as unknown),
      ) ?? undefined,
    logoImageUrl:
      readString((data.logoImageUrl as unknown) ?? (data.logoUrl as unknown)) ??
      undefined,
    isPublished: true,
  };

  Object.keys(payload).forEach((key) => {
    if (payload[key] === undefined) {
      delete payload[key];
    }
  });

  return payload;
}

export const syncPublicSalonDirectory = functionsEU.firestore
  .document('salons/{salonId}')
  .onWrite(async (change, context) => {
    const salonId = context.params.salonId as string;
    const before = change.before.exists ? change.before.data() ?? null : null;
    const after = change.after.exists ? change.after.data() ?? null : null;

    const publicRef = firestore()
      .collection(COLLECTION_PUBLIC_SALONS)
      .doc(salonId);

    if (!after) {
      await publicRef.delete();
      return;
    }

    const isPublished = Boolean(after.isPublished);
    if (!isPublished) {
      await publicRef.delete();
      return;
    }

    const payload = buildPublicSalonPayload(salonId, after);
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    payload.updatedAt = timestamp;

    const wasPublished = Boolean(before?.isPublished);
    if (!wasPublished) {
      payload.createdAt = timestamp;
      payload.publishedAt = timestamp;
    }

    await publicRef.set(payload, { merge: true });
  });
