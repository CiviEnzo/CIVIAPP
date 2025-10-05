import * as admin from 'firebase-admin';

export interface LoyaltySettings {
  enabled: boolean;
  earning: {
    euroPerPoint: number;
    rounding: 'floor' | 'round' | 'ceil';
  };
  redemption: {
    pointValueEuro: number;
    maxPercent: number;
    autoSuggest: boolean;
  };
  initialBalance: number;
  expiration: {
    resetMonth: number;
    resetDay: number;
    timezone: string;
  };
  updatedAt?: FirebaseFirestore.Timestamp;
}

export const LOYALTY_MOVEMENTS_SUBCOLLECTION = 'loyalty_movements';

export const firestore = admin.firestore();

export async function readSalonLoyaltySettings(
  salonId: string,
): Promise<LoyaltySettings | null> {
  if (!salonId) {
    return null;
  }
  const doc = await firestore.collection('salons').doc(salonId).get();
  if (!doc.exists) {
    return null;
  }
  const data = doc.data();
  if (!data) {
    return null;
  }
  return coerceLoyaltySettings(data.loyaltySettings);
}

export function coerceLoyaltySettings(
  raw: FirebaseFirestore.DocumentData | undefined,
): LoyaltySettings | null {
  if (!raw) {
    return null;
  }
  const enabled = Boolean(raw.enabled);
  if (!enabled) {
    return {
      enabled: false,
      earning: { euroPerPoint: 10, rounding: 'floor' },
      redemption: { pointValueEuro: 1, maxPercent: 0.3, autoSuggest: true },
      initialBalance: Number(raw.initialBalance ?? 0),
      expiration: {
        resetMonth: Number(raw.expiration?.resetMonth ?? 1),
        resetDay: Number(raw.expiration?.resetDay ?? 1),
        timezone: String(raw.expiration?.timezone ?? 'Europe/Rome'),
      },
      updatedAt: raw.updatedAt,
    };
  }
  const earning = raw.earning ?? {};
  const redemption = raw.redemption ?? {};
  const expiration = raw.expiration ?? {};
  return {
    enabled,
    earning: {
      euroPerPoint: Number(earning.euroPerPoint ?? 10),
      rounding: normalizeRoundingMode(earning.rounding),
    },
    redemption: {
      pointValueEuro: Number(redemption.pointValueEuro ?? 1),
      maxPercent: Number(redemption.maxPercent ?? 0.3),
      autoSuggest: Boolean(redemption.autoSuggest ?? true),
    },
    initialBalance: Number(raw.initialBalance ?? 0),
    expiration: {
      resetMonth: Number(expiration.resetMonth ?? 1),
      resetDay: Number(expiration.resetDay ?? 1),
      timezone: String(expiration.timezone ?? 'Europe/Rome'),
    },
    updatedAt: raw.updatedAt,
  };
}

export function normalizeRoundingMode(
  value: unknown,
): 'floor' | 'round' | 'ceil' {
  if (value === 'round' || value === 'ceil') {
    return value;
  }
  return 'floor';
}

export function toNumber(value: unknown, fallback = 0): number {
  if (typeof value === 'number') {
    if (Number.isNaN(value) || !Number.isFinite(value)) {
      return fallback;
    }
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isNaN(parsed) || !Number.isFinite(parsed)) {
      return fallback;
    }
    return parsed;
  }
  if (typeof value === 'boolean') {
    return value ? 1 : 0;
  }
  return fallback;
}

export function toInt(value: unknown, fallback = 0): number {
  const numeric = toNumber(value, fallback);
  if (!Number.isFinite(numeric)) {
    return fallback;
  }
  return Math.trunc(numeric);
}
