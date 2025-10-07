import { getAuth } from 'firebase-admin/auth';
import logger from 'firebase-functions/logger';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

type NullableString = string | null;

type ClaimSnapshot = {
  role: NullableString;
  salonIds: string[];
  staffId: NullableString;
  clientId: NullableString;
};

const normalizeString = (value: unknown): NullableString => {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.length ? trimmed : null;
  }
  return null;
};

const normalizeSalonIds = (value: unknown, fallback: unknown): string[] => {
  const ids = new Set<string>();

  const push = (candidate: unknown) => {
    const normalized = normalizeString(candidate);
    if (normalized) {
      ids.add(normalized);
    }
  };

  if (Array.isArray(value)) {
    value.forEach(push);
  } else {
    push(value);
  }

  if (ids.size === 0) {
    if (Array.isArray(fallback)) {
      fallback.forEach(push);
    } else {
      push(fallback);
    }
  }

  return Array.from(ids); // already unique
};

const currentClaimsSnapshot = (claims: Record<string, unknown> | undefined): ClaimSnapshot => {
  const role = normalizeString(claims?.role);
  const salonIdsSource = claims?.salonIds;
  const salonIds = Array.isArray(salonIdsSource)
    ? salonIdsSource.map((entry) => normalizeString(entry)).filter((entry): entry is string => entry != null)
    : [];
  return {
    role,
    salonIds,
    staffId: normalizeString(claims?.staffId),
    clientId: normalizeString(claims?.clientId),
  };
};

const claimsEqual = (a: ClaimSnapshot, b: ClaimSnapshot): boolean => {
  if (a.role !== b.role) {
    return false;
  }
  if (a.staffId !== b.staffId || a.clientId !== b.clientId) {
    return false;
  }
  if (a.salonIds.length !== b.salonIds.length) {
    return false;
  }
  const sortedA = [...a.salonIds].sort();
  const sortedB = [...b.salonIds].sort();
  return sortedA.every((value, index) => value === sortedB[index]);
};

export const syncUserClaims = onDocumentWritten({
  region: 'europe-west1',
  document: 'users/{userId}',
}, async (event) => {
  const userId = event.params.userId as string;
  const auth = getAuth();
  const after = event.data?.after;

  if (!after?.exists) {
    try {
      await auth.setCustomUserClaims(userId, {});
    } catch (error) {
      logger.warn('Unable to clear custom claims', { userId, error });
    }
    return;
  }

  const data = after.data() ?? {};
  const role = normalizeString(data.role);
  const salonIds = normalizeSalonIds(data.salonIds, data.salonId);
  const staffId = normalizeString(data.staffId);
  const clientId = normalizeString(data.clientId);

  try {
    const userRecord = await auth.getUser(userId);
    const snapshot = currentClaimsSnapshot(
      userRecord.customClaims as Record<string, unknown> | undefined,
    );
    const desired: ClaimSnapshot = {
      role,
      salonIds,
      staffId,
      clientId,
    };

    if (claimsEqual(snapshot, desired)) {
      logger.info('Claims already up to date', { userId, desired });
      return;
    }

    const nextClaims: Record<string, unknown> = {};
    if (role) {
      nextClaims.role = role;
    }
    if (salonIds.length) {
      nextClaims.salonIds = salonIds;
    }
    if (staffId) {
      nextClaims.staffId = staffId;
    }
    if (clientId) {
      nextClaims.clientId = clientId;
    }

    await auth.setCustomUserClaims(userId, nextClaims);
    logger.info('Custom claims synced', {
      userId,
      role,
      salonIds,
      staffId,
      clientId,
    });
  } catch (rawError) {
    logger.error('Unable to sync custom claims', {
      userId,
      error: rawError instanceof Error ? rawError.message : String(rawError),
    });
  }
});
