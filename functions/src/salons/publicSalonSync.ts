import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

const firestore = admin.firestore;
const functionsEU = functions.region('europe-west1');

const COLLECTION_PUBLIC_SALONS = 'public_salons';
const COLLECTION_PUBLIC_PROMOTIONS = 'public_promotions';

type SalonSnapshot = admin.firestore.DocumentData;

function slugify(value: string, fallback: string): string {
  const normalized = value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
  return normalized || fallback;
}

function buildSalonSlug(salonId: string, salonName: string): string {
  const suffix = salonId.replace(/[^a-zA-Z0-9]/g, '').slice(-6).toLowerCase();
  const base = slugify(salonName, 'salone');
  return suffix ? `${base}-${suffix}` : base;
}

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

function normalizeFirestoreValues(value: unknown): unknown {
  if (value === undefined) {
    return null;
  }
  if (Array.isArray(value)) {
    return value.map(normalizeFirestoreValues);
  }
  if (!value || typeof value !== 'object') {
    return value;
  }
  const prototype = Object.getPrototypeOf(value);
  if (prototype !== Object.prototype && prototype !== null) {
    return value;
  }
  const result: Record<string, unknown> = {};
  Object.entries(value as Record<string, unknown>).forEach(([key, item]) => {
    result[key] = normalizeFirestoreValues(item);
  });
  return result;
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
  const requestedThemeColor = readString(data.webThemeColor) ?? '#6750A4';
  const webThemeColor = /^#[0-9a-fA-F]{6}$/.test(requestedThemeColor)
    ? requestedThemeColor.toUpperCase()
    : '#6750A4';
  const allowedFonts = new Set([
    'system',
    'DM Sans',
    'Inter',
    'Lato',
    'Montserrat',
    'Playfair Display',
    'playfairDmSans',
    'Poppins',
  ]);
  const requestedFont = readString(data.webFontFamily) ?? 'system';
  const webFontFamily = allowedFonts.has(requestedFont) ? requestedFont : 'system';

  const result: Record<string, unknown> = {
    accessMode,
    extraFields,
    webFormEnabled: readBoolean(data.webFormEnabled, false),
    webFormTitle: readString(data.webFormTitle) ?? 'Registrati al salone',
    webFormDescription: readString(data.webFormDescription),
    webFormConfirmationMessage:
      readString(data.webFormConfirmationMessage) ??
      'Grazie, i tuoi dati sono stati inviati al salone.',
    privacyPolicyUrl: readString(data.privacyPolicyUrl),
    privacyVersion: readString(data.privacyVersion) ?? '1',
    marketingConsentEnabled: readBoolean(data.marketingConsentEnabled, true),
    webThemeColor,
    webFontFamily,
  };
  Object.keys(result).forEach((key) => {
    if (result[key] === undefined) {
      delete result[key];
    }
  });
  return result;
}

function sanitizePromotionLanding(input: unknown, title: string): Record<string, unknown> {
  const data = input && typeof input === 'object'
    ? input as Record<string, unknown>
    : {};
  const interestOptions = readStringArray(data.interestOptions)
    .slice(0, 12)
    .map((value) => value.slice(0, 80));
  const allowedFonts = new Set([
    'system',
    'DM Sans',
    'Montserrat',
    'Lato',
    'Poppins',
    'playfairDmSans',
  ]);
  const requestedFont = readString(data.fontFamily) ?? 'playfairDmSans';
  const allowedTemplates = new Set([
    'editorialBeauty',
    'minimalGlow',
    'studioPop',
    'botanicalRitual',
  ]);
  const requestedTemplate = readString(data.templateId) ?? 'editorialBeauty';
  return {
    enabled: readBoolean(data.enabled, false),
    slug: slugify(readString(data.slug) ?? title, 'promozione'),
    eyebrow: readString(data.eyebrow) ?? 'Offerta esclusiva',
    formTitle: readString(data.formTitle) ?? 'Richiedi informazioni',
    formDescription:
      readString(data.formDescription) ??
      'Compila il modulo: il salone ti ricontatterà per fornirti tutti i dettagli.',
    submitLabel: readString(data.submitLabel) ?? 'Richiedi informazioni',
    interestOptions,
    offerPrice: readString(data.offerPrice),
    originalPrice: readString(data.originalPrice),
    fontFamily: allowedFonts.has(requestedFont) ? requestedFont : 'playfairDmSans',
    templateId: allowedTemplates.has(requestedTemplate)
      ? requestedTemplate
      : 'editorialBeauty',
  };
}

function sanitizePromotionSections(input: unknown): Record<string, unknown>[] {
  if (!Array.isArray(input)) return [];
  return input.slice(0, 30).map((raw, index) => {
    const data = raw && typeof raw === 'object'
      ? raw as Record<string, unknown>
      : {};
    return {
      id: readString(data.id) ?? `section-${index + 1}`,
      type: readString(data.type) === 'image' ? 'image' : 'text',
      order: readNumber(data.order) ?? index,
      title: readString(data.title),
      text: readString(data.text),
      imageUrl: readString(data.imageUrl),
      altText: readString(data.altText),
      caption: readString(data.caption),
      layout: readString(data.layout) ?? 'full',
      visible: readBoolean(data.visible, true),
    };
  });
}

export const publicSalonSyncTestHelpers = {
  sanitizePromotionLanding,
};

async function deletePublicPromotionsForSalon(salonId: string): Promise<void> {
  const snapshot = await firestore()
    .collection(COLLECTION_PUBLIC_PROMOTIONS)
    .where('salonId', '==', salonId)
    .get();
  if (snapshot.empty) return;
  const batch = firestore().batch();
  snapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
}

async function syncPublicPromotionDocument(
  promotionId: string,
  promotion: admin.firestore.DocumentData | null,
): Promise<void> {
  const publicRef = firestore().collection(COLLECTION_PUBLIC_PROMOTIONS).doc(promotionId);
  if (!promotion) {
    await publicRef.delete();
    return;
  }
  const salonId = readString(promotion.salonId);
  const title = readString(promotion.title) ?? '';
  const landing = sanitizePromotionLanding(promotion.webLanding, title);
  const isPublic =
    salonId &&
    landing.enabled === true &&
    readBoolean(promotion.isActive, false) &&
    readString(promotion.status) === 'published';
  if (!isPublic || !salonId) {
    await publicRef.delete();
    return;
  }
  const salonSnapshot = await firestore().collection('salons').doc(salonId).get();
  const salon = salonSnapshot.data();
  if (!salonSnapshot.exists || !salon || !readBoolean(salon.isPublished, false) ||
      (readString(salon.status) ?? 'active') !== 'active') {
    await publicRef.delete();
    return;
  }
  const salonName = readString(salon.name) ?? '';
  const salonSlug = buildSalonSlug(salonId, salonName);
  const publicPayload = normalizeFirestoreValues({
    promotionId,
    salonId,
    salonSlug,
    promotionSlug: landing.slug,
    title,
    subtitle: readString(promotion.subtitle),
    tagline: readString(promotion.tagline),
    coverImageUrl: readString(promotion.coverImageUrl) ?? readString(promotion.imageUrl),
    themeColor: promotion.themeColor ?? null,
    discountPercentage: readNumber(promotion.discountPercentage) ?? 0,
    startsAt: promotion.startsAt ?? null,
    endsAt: promotion.endsAt ?? null,
    sections: sanitizePromotionSections(promotion.sections),
    webLanding: landing,
    salon: {
      name: salonName,
      phone: readString(salon.phone) ?? '',
      email: readString(salon.email) ?? '',
      city: readString(salon.city) ?? '',
      logoImageUrl: readString(salon.logoImageUrl) ?? readString(salon.logoUrl),
      privacyPolicyUrl:
        readString((salon.clientRegistration as Record<string, unknown> | undefined)?.privacyPolicyUrl),
      privacyVersion:
        readString((salon.clientRegistration as Record<string, unknown> | undefined)?.privacyVersion) ?? '1',
    },
    status: 'published',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }) as Record<string, unknown>;
  await publicRef.set(publicPayload, { merge: true });
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
      await deletePublicPromotionsForSalon(salonId);
      return;
    }

    const isPublished = Boolean(after.isPublished);
    if (!isPublished) {
      await publicRef.delete();
      await deletePublicPromotionsForSalon(salonId);
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

    const promotions = await firestore()
      .collection('promotions')
      .where('salonId', '==', salonId)
      .get();
    await Promise.all(
      promotions.docs.map((doc) => syncPublicPromotionDocument(doc.id, doc.data())),
    );
  });

export const syncPublicPromotionLandingV2 = onDocumentWritten(
  {
    document: 'promotions/{promotionId}',
    region: 'europe-west1',
  },
  async (event) => {
    const after = event.data?.after;
    await syncPublicPromotionDocument(
      event.params.promotionId,
      after?.exists ? after.data() ?? null : null,
    );
  },
);

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
