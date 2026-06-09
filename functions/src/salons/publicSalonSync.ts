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

function readBoolean(value: unknown, fallback = false): boolean {
  if (typeof value === 'boolean') {
    return value;
  }
  return fallback;
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

function readStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((item) => (typeof item === 'string' ? item.trim() : String(item ?? '').trim()))
    .filter((item) => item.length > 0);
}

function readIntMap(value: unknown): Record<string, number> {
  if (!value || typeof value !== 'object') {
    return {};
  }

  const result: Record<string, number> = {};
  Object.entries(value as Record<string, unknown>).forEach(([key, raw]) => {
    const parsed = readNumber(raw);
    if (!key.trim() || parsed === undefined) {
      return;
    }
    result[key] = Math.max(0, Math.floor(parsed));
  });
  return result;
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

async function loadPublicServices(salonId: string): Promise<Record<string, unknown>[]> {
  const snapshot = await firestore()
    .collection('services')
    .where('salonId', '==', salonId)
    .get();

  const services = snapshot.docs
    .map((doc) => {
      const data = doc.data();
      if (!readBoolean(data.isActive, true) || !readBoolean(data.showOnPublicProfile, true)) {
        return null;
      }
      const payload: Record<string, unknown> = {
        id: doc.id,
        name: readString(data.name) ?? '',
        category: readString(data.category) ?? 'Generale',
        durationMinutes: Math.max(0, Math.floor(readNumber(data.durationMinutes) ?? 0)),
        price: readNumber(data.price) ?? 0,
        description: readString(data.description),
      };
      Object.keys(payload).forEach((key) => {
        if (payload[key] === undefined) {
          delete payload[key];
        }
      });
      return payload;
    })
    .filter((item): item is Record<string, unknown> => item !== null);

  services.sort((left, right) => {
    const categoryCompare = String(left.category ?? '').localeCompare(
      String(right.category ?? ''),
      'it',
    );
    if (categoryCompare !== 0) {
      return categoryCompare;
    }
    return String(left.name ?? '').localeCompare(String(right.name ?? ''), 'it');
  });
  return services;
}

async function loadPublicPackages(salonId: string): Promise<Record<string, unknown>[]> {
  const snapshot = await firestore()
    .collection('packages')
    .where('salonId', '==', salonId)
    .get();

  const packages = snapshot.docs
    .map((doc) => {
      const data = doc.data();
      const showOnClientDashboard = readBoolean(data.showOnClientDashboard, true);
      const showOnPublicProfile = readBoolean(
        data.showOnPublicProfile,
        showOnClientDashboard,
      );
      if (!showOnClientDashboard || !showOnPublicProfile) {
        return null;
      }

      const serviceSessionCounts = readIntMap(data.serviceSessionCounts);
      const computedSessions = Object.values(serviceSessionCounts).reduce(
        (sum, value) => sum + value,
        0,
      );
      const sessionCount =
        readNumber(data.sessionCount) ??
        (computedSessions > 0 ? computedSessions : undefined);

      const payload: Record<string, unknown> = {
        id: doc.id,
        name: readString(data.name) ?? '',
        price: readNumber(data.price) ?? 0,
        fullPrice: readNumber(data.fullPrice) ?? readNumber(data.price) ?? 0,
        discountPercentage: readNumber(data.discountPercentage),
        description: readString(data.description),
        serviceIds: readStringArray(data.serviceIds),
        sessionCount,
        validDays: readNumber(data.validDays),
      };
      Object.keys(payload).forEach((key) => {
        if (payload[key] === undefined) {
          delete payload[key];
        }
      });
      return payload;
    })
    .filter((item): item is Record<string, unknown> => item !== null);

  packages.sort((left, right) =>
    String(left.name ?? '').localeCompare(String(right.name ?? ''), 'it'),
  );
  return packages;
}

async function buildPublicSalonPayload(
  salonId: string,
  data: SalonSnapshot,
): Promise<Record<string, unknown>> {
  const showPublicCatalog = readBoolean(data.showPublicCatalog, true);
  const [publicServices, publicPackages] = showPublicCatalog
    ? await Promise.all([
        loadPublicServices(salonId),
        loadPublicPackages(salonId),
      ])
    : [[], []];

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
    showPublicCatalog,
    publicServices,
    publicPackages,
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

async function refreshPublicSalonCatalog(salonId: string): Promise<void> {
  if (!salonId.trim()) {
    return;
  }

  const salonRef = firestore().collection('salons').doc(salonId);
  const salonSnapshot = await salonRef.get();
  if (!salonSnapshot.exists) {
    await firestore().collection(COLLECTION_PUBLIC_SALONS).doc(salonId).delete();
    return;
  }

  const salonData = salonSnapshot.data() ?? {};
  if (!readBoolean(salonData.isPublished, false)) {
    await firestore().collection(COLLECTION_PUBLIC_SALONS).doc(salonId).delete();
    return;
  }

  const showPublicCatalog = readBoolean(salonData.showPublicCatalog, true);
  const [publicServices, publicPackages] = showPublicCatalog
    ? await Promise.all([
        loadPublicServices(salonId),
        loadPublicPackages(salonId),
      ])
    : [[], []];

  await firestore()
    .collection(COLLECTION_PUBLIC_SALONS)
    .doc(salonId)
    .set(
      {
        showPublicCatalog,
        publicServices,
        publicPackages,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

async function refreshCatalogForChangedSalonIds(
  before: admin.firestore.DocumentData | null,
  after: admin.firestore.DocumentData | null,
): Promise<void> {
  const salonIds = new Set<string>();
  const beforeSalonId = readString(before?.salonId);
  const afterSalonId = readString(after?.salonId);
  if (beforeSalonId) {
    salonIds.add(beforeSalonId);
  }
  if (afterSalonId) {
    salonIds.add(afterSalonId);
  }
  await Promise.all(Array.from(salonIds).map(refreshPublicSalonCatalog));
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

    const payload = await buildPublicSalonPayload(salonId, after);
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    payload.updatedAt = timestamp;

    const wasPublished = Boolean(before?.isPublished);
    if (!wasPublished) {
      payload.createdAt = timestamp;
      payload.publishedAt = timestamp;
    }

    await publicRef.set(payload, { merge: true });
  });

export const syncPublicSalonCatalogOnServiceWrite = functionsEU.firestore
  .document('services/{serviceId}')
  .onWrite(async (change) => {
    const before = change.before.exists ? change.before.data() ?? null : null;
    const after = change.after.exists ? change.after.data() ?? null : null;
    await refreshCatalogForChangedSalonIds(before, after);
  });

export const syncPublicSalonCatalogOnPackageWrite = functionsEU.firestore
  .document('packages/{packageId}')
  .onWrite(async (change) => {
    const before = change.before.exists ? change.before.data() ?? null : null;
    const after = change.after.exists ? change.after.data() ?? null : null;
    await refreshCatalogForChangedSalonIds(before, after);
  });
