import { createHash } from 'crypto';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

const REGION = 'europe-west1';
const REQUESTS = 'web_client_requests';
const RATE_LIMITS = 'web_client_request_limits';
const CLIENTS = 'clients';
const ALLOWED_EXTRA_FIELDS = new Set([
  'address',
  'profession',
  'referralSource',
  'notes',
  'gender',
  'interest',
]);

function text(value: unknown, maxLength: number): string {
  if (typeof value !== 'string') return '';
  return value.trim().replace(/\s+/g, ' ').slice(0, maxLength);
}

function requiredText(value: unknown, field: string, maxLength: number): string {
  const normalized = text(value, maxLength);
  if (!normalized) {
    throw new HttpsError('invalid-argument', `Field "${field}" is required.`);
  }
  return normalized;
}

function normalizeEmail(value: unknown): string {
  const normalized = text(value, 320).toLowerCase();
  if (normalized && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) {
    throw new HttpsError('invalid-argument', 'Email address is not valid.');
  }
  return normalized;
}

function normalizePhone(value: unknown): { display: string; normalized: string } {
  const display = text(value, 40);
  const digits = display.replace(/\D/g, '');
  if (display && (digits.length < 7 || digits.length > 15)) {
    throw new HttpsError('invalid-argument', 'Phone number is not valid.');
  }
  return { display, normalized: digits };
}

function optionalDate(value: unknown): Timestamp | null {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'Date of birth is not valid.');
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime()) || parsed.getTime() > Date.now()) {
    throw new HttpsError('invalid-argument', 'Date of birth is not valid.');
  }
  return Timestamp.fromDate(parsed);
}

function configuredExtraFields(value: unknown): Set<string> {
  if (!Array.isArray(value)) return new Set<string>();
  return new Set(
    value
      .map((item) => text(item, 40))
      .filter((item) => ALLOWED_EXTRA_FIELDS.has(item)),
  );
}

function sanitizeExtraData(value: unknown, allowed: Set<string>): Record<string, string> {
  if (!value || typeof value !== 'object') return {};
  const input = value as Record<string, unknown>;
  const result: Record<string, string> = {};
  for (const key of allowed) {
    const maxLength = key === 'notes' ? 1000 : 160;
    const normalized = text(input[key], maxLength);
    if (normalized) result[key] = normalized;
  }
  return result;
}

function userSalonIds(data: Record<string, unknown>): string[] {
  const values = new Set<string>();
  const rawIds = Array.isArray(data.salonIds) ? data.salonIds : [];
  for (const value of rawIds) {
    const id = text(value, 160);
    if (id) values.add(id);
  }
  const primary = text(data.salonId, 160);
  if (primary) values.add(primary);
  return [...values];
}

async function duplicateClientIds(
  salonId: string,
  normalizedEmail: string,
  normalizedPhone: string,
): Promise<string[]> {
  if (!normalizedEmail && !normalizedPhone) return [];
  const db = getFirestore();
  const snapshot = await db.collection(CLIENTS).where('salonId', '==', salonId).get();
  const matches = new Set<string>();
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const email = text(data.email, 320).toLowerCase();
    const phone = text(data.phone, 40).replace(/\D/g, '');
    if ((normalizedEmail && email === normalizedEmail) ||
        (normalizedPhone && phone === normalizedPhone)) {
      matches.add(doc.id);
    }
  }
  return [...matches].slice(0, 10);
}

export const submitWebClientRequest = onCall(
  { region: REGION, cors: true, maxInstances: 20 },
  async (request) => {
    const data = (request.data ?? {}) as Record<string, unknown>;
    if (text(data.website, 100)) {
      // Honeypot: return a neutral success response without storing the payload.
      return { success: true };
    }

    const salonId = requiredText(data.salonId, 'salonId', 160);
    const db = getFirestore();
    const publicSalonSnapshot = await db.collection('public_salons').doc(salonId).get();
    if (!publicSalonSnapshot.exists) {
      throw new HttpsError('not-found', 'Registration form is not available.');
    }
    const publicSalon = publicSalonSnapshot.data() ?? {};
    const registration =
      publicSalon.clientRegistration && typeof publicSalon.clientRegistration === 'object'
        ? publicSalon.clientRegistration as Record<string, unknown>
        : {};
    if (registration.webFormEnabled !== true || publicSalon.status !== 'active') {
      const promotionId = text(data.promotionId, 160);
      if (!promotionId) {
        throw new HttpsError('failed-precondition', 'Registration form is not available.');
      }
    }

    const promotionId = text(data.promotionId, 160);
    let promotionTitle = '';
    let promotionSlug = '';
    let promotionInterestOptions: string[] = [];
    if (promotionId) {
      const promotionSnapshot = await db.collection('public_promotions').doc(promotionId).get();
      const promotion = promotionSnapshot.data() ?? {};
      if (!promotionSnapshot.exists || text(promotion.salonId, 160) !== salonId ||
          promotion.status !== 'published') {
        throw new HttpsError('failed-precondition', 'Promotion form is not available.');
      }
      promotionTitle = text(promotion.title, 160);
      promotionSlug = text(promotion.promotionSlug, 120);
      const landing = promotion.webLanding && typeof promotion.webLanding === 'object'
        ? promotion.webLanding as Record<string, unknown>
        : {};
      promotionInterestOptions = Array.isArray(landing.interestOptions)
        ? landing.interestOptions.map((item) => text(item, 80)).filter(Boolean)
        : [];
    }

    const firstName = requiredText(data.firstName, 'firstName', 100);
    const lastName = requiredText(data.lastName, 'lastName', 100);
    const email = normalizeEmail(data.email);
    const phone = normalizePhone(data.phone);
    if (!email && !phone.normalized) {
      throw new HttpsError('invalid-argument', 'Email or phone is required.');
    }
    if (data.privacyAccepted !== true) {
      throw new HttpsError('failed-precondition', 'Privacy consent is required.');
    }

    const dateOfBirth = optionalDate(data.dateOfBirth);
    const allowedExtras = configuredExtraFields(registration.extraFields);
    if (promotionId) allowedExtras.add('interest');
    const extraData = sanitizeExtraData(data.extraData, allowedExtras);
    if (promotionId && promotionInterestOptions.length > 0) {
      const interest = text(extraData.interest, 80);
      if (!promotionInterestOptions.includes(interest)) {
        throw new HttpsError('invalid-argument', 'Promotion interest is not valid.');
      }
    }
    const marketingEnabled = registration.marketingConsentEnabled !== false;
    const marketingAccepted = marketingEnabled && data.marketingAccepted === true;
    const privacyVersion = text(registration.privacyVersion, 40) || '1';
    const now = Timestamp.now();
    const duplicates = await duplicateClientIds(salonId, email, phone.normalized);

    const fingerprint = createHash('sha256')
      .update(`${salonId}|${email}|${phone.normalized}`)
      .digest('hex');
    const rateRef = db.collection(RATE_LIMITS).doc(fingerprint);
    const requestRef = db.collection(REQUESTS).doc();

    await db.runTransaction(async (transaction) => {
      const rateSnapshot = await transaction.get(rateRef);
      const lastSubmittedAt = rateSnapshot.data()?.lastSubmittedAt;
      if (lastSubmittedAt instanceof Timestamp &&
          now.toMillis() - lastSubmittedAt.toMillis() < 60_000) {
        throw new HttpsError('resource-exhausted', 'Please wait before submitting again.');
      }

      const payload: Record<string, unknown> = {
        salonId,
        firstName,
        lastName,
        phone: phone.display,
        normalizedPhone: phone.normalized,
        email,
        normalizedEmail: email,
        extraData,
        status: 'new',
        source: promotionId ? 'promotionLanding' : 'website',
        promotionId: promotionId || null,
        promotionTitle: promotionTitle || null,
        promotionSlug: promotionSlug || null,
        sourceUrl: text(data.sourceUrl, 500) || null,
        referrer: text(data.referrer, 500) || null,
        utmSource: text(data.utmSource, 120) || null,
        utmMedium: text(data.utmMedium, 120) || null,
        utmCampaign: text(data.utmCampaign, 160) || null,
        consents: {
          privacyAccepted: true,
          privacyAcceptedAt: now,
          privacyVersion,
          marketingAccepted,
          marketingAcceptedAt: marketingAccepted ? now : null,
        },
        duplicateCandidateClientIds: duplicates,
        linkedClientId: null,
        createdAt: now,
        updatedAt: now,
        processedAt: null,
        processedBy: null,
      };
      if (dateOfBirth) payload.dateOfBirth = dateOfBirth;
      transaction.create(requestRef, payload);
      transaction.set(rateRef, {
        salonId,
        lastSubmittedAt: now,
        expiresAt: Timestamp.fromMillis(now.toMillis() + 86_400_000),
      });
    });

    return { success: true, requestId: requestRef.id };
  },
);

export const processWebClientRequest = onCall(
  { region: REGION, maxInstances: 20 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication is required.');
    }
    const input = (request.data ?? {}) as Record<string, unknown>;
    const requestId = requiredText(input.requestId, 'requestId', 160);
    const action = requiredText(input.action, 'action', 20);
    if (!['accept', 'reject', 'archive'].includes(action)) {
      throw new HttpsError('invalid-argument', 'Action is not valid.');
    }

    const db = getFirestore();
    const operatorSnapshot = await db.collection('users').doc(request.auth.uid).get();
    const operator = operatorSnapshot.data() ?? {};
    const role = text(operator.role, 40).toLowerCase();
    if (role !== 'admin' && role !== 'staff') {
      throw new HttpsError('permission-denied', 'User cannot process web requests.');
    }

    const webRequestRef = db.collection(REQUESTS).doc(requestId);
    const initialSnapshot = await webRequestRef.get();
    if (!initialSnapshot.exists) {
      throw new HttpsError('not-found', 'Web request was not found.');
    }
    const initialData = initialSnapshot.data() ?? {};
    const salonId = text(initialData.salonId, 160);
    if (!salonId || !userSalonIds(operator).includes(salonId)) {
      throw new HttpsError('permission-denied', 'User cannot manage this salon.');
    }

    const requestedLinkedClientId = text(input.linkedClientId, 160);
    const newClientRef = requestedLinkedClientId
      ? null
      : db.collection(CLIENTS).doc();
    const sequenceRef = db.collection('salon_sequences').doc(salonId);
    const salonRef = db.collection('salons').doc(salonId);

    const result = await db.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(webRequestRef);
      if (!currentSnapshot.exists) {
        throw new HttpsError('not-found', 'Web request was not found.');
      }
      const current = currentSnapshot.data() ?? {};
      const currentStatus = text(current.status, 20);
      if (currentStatus !== 'new') {
        return {
          success: true,
          clientId: text(current.linkedClientId, 160) || null,
          status: currentStatus,
        };
      }

      const processedPayload = {
        status: action === 'accept' ? 'accepted' : action === 'reject' ? 'rejected' : 'archived',
        updatedAt: FieldValue.serverTimestamp(),
        processedAt: FieldValue.serverTimestamp(),
        processedBy: request.auth!.uid,
      };
      if (action !== 'accept') {
        transaction.update(webRequestRef, processedPayload);
        return { success: true, clientId: null, status: processedPayload.status };
      }

      const extra = current.extraData && typeof current.extraData === 'object'
        ? current.extraData as Record<string, unknown>
        : {};
      const requestEmail = normalizeEmail(current.email);
      const requestPhone = normalizePhone(current.phone).display;
      const marketingConsent =
        current.consents && typeof current.consents === 'object'
          ? (current.consents as Record<string, unknown>).marketingAccepted === true
          : false;
      const marketingAcceptedAt =
        current.consents && typeof current.consents === 'object'
          ? (current.consents as Record<string, unknown>).marketingAcceptedAt
          : null;

      if (requestedLinkedClientId) {
        const clientRef = db.collection(CLIENTS).doc(requestedLinkedClientId);
        const clientSnapshot = await transaction.get(clientRef);
        if (!clientSnapshot.exists || text(clientSnapshot.data()?.salonId, 160) !== salonId) {
          throw new HttpsError('failed-precondition', 'Selected client is not valid.');
        }
        const existing = clientSnapshot.data() ?? {};
        const updates: Record<string, unknown> = {};
        if (!text(existing.firstName, 100)) updates.firstName = text(current.firstName, 100);
        if (!text(existing.lastName, 100)) updates.lastName = text(current.lastName, 100);
        if (!text(existing.phone, 40) && requestPhone) updates.phone = requestPhone;
        if (!text(existing.email, 320) && requestEmail) updates.email = requestEmail;
        if (!existing.dateOfBirth && current.dateOfBirth) updates.dateOfBirth = current.dateOfBirth;
        if (!text(existing.address, 160) && text(extra.address, 160)) {
          updates.address = text(extra.address, 160);
          updates.city = text(extra.address, 160);
        }
        if (!text(existing.profession, 160) && text(extra.profession, 160)) {
          updates.profession = text(extra.profession, 160);
        }
        if (!text(existing.referralSource, 160) && text(extra.referralSource, 160)) {
          updates.referralSource = text(extra.referralSource, 160);
        }
        if (!text(existing.gender, 40) && text(extra.gender, 40)) {
          updates.gender = text(extra.gender, 40);
        }
        if (!text(existing.notes, 1000) && text(extra.notes, 1000)) {
          updates.notes = text(extra.notes, 1000);
        }
        if (marketingConsent) {
          updates.consents = FieldValue.arrayUnion({
            type: 'marketing',
            acceptedAt: marketingAcceptedAt ?? Timestamp.now(),
          });
        }
        if (Object.keys(updates).length > 0) transaction.update(clientRef, updates);
        transaction.update(webRequestRef, {
          ...processedPayload,
          linkedClientId: requestedLinkedClientId,
        });
        return { success: true, clientId: requestedLinkedClientId, status: 'accepted' };
      }

      const [sequenceSnapshot, salonSnapshot] = await Promise.all([
        transaction.get(sequenceRef),
        transaction.get(salonRef),
      ]);
      const sequence = typeof sequenceSnapshot.data()?.clientSequence === 'number'
        ? sequenceSnapshot.data()!.clientSequence as number
        : 0;
      const clientNumber = sequence + 1;
      const loyalty = salonSnapshot.data()?.loyaltySettings;
      const loyaltyEnabled = loyalty && typeof loyalty === 'object' &&
        (loyalty as Record<string, unknown>).enabled === true;
      const initialBalance = loyaltyEnabled &&
        typeof (loyalty as Record<string, unknown>).initialBalance === 'number'
        ? (loyalty as Record<string, unknown>).initialBalance as number
        : 0;
      const clientId = newClientRef!.id;
      const consents = marketingConsent
        ? [{ type: 'marketing', acceptedAt: marketingAcceptedAt ?? Timestamp.now() }]
        : [];
      transaction.create(newClientRef!, {
        salonId,
        firstName: text(current.firstName, 100),
        lastName: text(current.lastName, 100),
        phone: requestPhone,
        email: requestEmail || null,
        clientNumber: clientNumber.toString(),
        dateOfBirth: current.dateOfBirth ?? null,
        address: text(extra.address, 160) || null,
        city: text(extra.address, 160) || null,
        profession: text(extra.profession, 160) || null,
        referralSource: text(extra.referralSource, 160) || 'Sito web',
        gender: text(extra.gender, 40) || null,
        notes: text(extra.notes, 1000) || null,
        loyaltyInitialPoints: initialBalance,
        loyaltyPoints: initialBalance,
        loyaltyUpdatedAt: initialBalance > 0 ? FieldValue.serverTimestamp() : null,
        fcmTokens: [],
        consents,
        channelPreferences: {
          push: true,
          email: true,
          whatsapp: false,
          sms: false,
        },
        invitationStatus: 'notSent',
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.set(sequenceRef, {
        clientSequence: clientNumber,
        updatedAt: FieldValue.serverTimestamp(),
        ...(sequenceSnapshot.exists ? {} : { createdAt: FieldValue.serverTimestamp() }),
      }, { merge: true });
      transaction.update(webRequestRef, {
        ...processedPayload,
        linkedClientId: clientId,
      });
      return { success: true, clientId, status: 'accepted' };
    });

    return result;
  },
);

export const webClientRequestTestHelpers = {
  normalizeEmail,
  normalizePhone,
  configuredExtraFields,
  sanitizeExtraData,
};
