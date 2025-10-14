import * as admin from 'firebase-admin';
import type { DocumentData } from 'firebase-admin/firestore';
import * as functions from 'firebase-functions';

import { db, FieldValue } from '../utils/firestore';

const SALES_COLLECTION = 'sales';
const CASH_FLOWS_COLLECTION = 'cash_flows';
const LAST_MINUTE_SLOTS_COLLECTION = 'last_minute_slots';
const CLIENTS_COLLECTION = 'clients';

type EnsureLastMinutePayload = {
  paymentIntentId?: string;
  salonId?: string;
  clientId?: string;
  slotId?: string;
  clientName?: string;
  slot?: Record<string, unknown>;
};

type EnsureLastMinuteResult = {
  status: 'ok';
  createdSale: boolean;
  createdCashFlow: boolean;
};

export const ensureLastMinutePaymentRecords = functions
  .region('europe-west1')
  .https.onCall(
    async (data: EnsureLastMinutePayload, context): Promise<EnsureLastMinuteResult> => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'Authentication required.',
        );
      }

      const paymentIntentId = normalizeString(data.paymentIntentId);
      const salonId = normalizeString(data.salonId);
      const clientId = normalizeString(data.clientId);
      const slotId = normalizeString(data.slotId);

      if (!paymentIntentId || !salonId || !clientId || !slotId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'paymentIntentId, salonId, clientId and slotId are required.',
        );
      }

      const result: EnsureLastMinuteResult = {
        status: 'ok',
        createdSale: false,
        createdCashFlow: false,
      };

      await db.runTransaction(async (tx) => {
        const saleRef = db.collection(SALES_COLLECTION).doc(paymentIntentId);
        const cashFlowRef = db.collection(CASH_FLOWS_COLLECTION).doc(paymentIntentId);
        const slotRef = db.collection(LAST_MINUTE_SLOTS_COLLECTION).doc(slotId);
        const clientRef = db.collection(CLIENTS_COLLECTION).doc(clientId);
        const fallbackSlot = normalizeSlotPayload(data.slot);

        const [saleSnap, cashFlowSnap, slotSnap, clientSnap] = await Promise.all([
          tx.get(saleRef),
          tx.get(cashFlowRef),
          tx.get(slotRef),
          tx.get(clientRef),
        ]);

        const slotDoc = slotSnap.exists ? slotSnap.data() ?? {} : null;
        if (!slotDoc && !fallbackSlot) {
          throw new functions.https.HttpsError(
            'not-found',
            'Last-minute slot not found.',
          );
        }

        const slotContext = resolveSlotContext(slotDoc, fallbackSlot, slotId);

        if (slotContext.price <= 0 && !saleSnap.exists) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Cannot create sale without a valid slot price.',
          );
        }

        if (!saleSnap.exists) {
          const salePayload: DocumentData = {
            salonId,
            clientId,
            items: [
              {
                referenceId: slotContext.serviceId,
                referenceType: 'service',
                description: slotContext.serviceName,
                quantity: 1,
                unitPrice: slotContext.price,
              },
            ],
            total: slotContext.price,
            createdAt: FieldValue.serverTimestamp(),
            paymentMethod: 'pos',
            paymentStatus: 'paid',
            paidAmount: slotContext.price,
            discountAmount: 0,
            notes: 'Vendita last minute generata automaticamente',
            staffId: slotContext.operatorId,
            metadata: {
              source: 'client-fallback',
              lastMinuteSlotId: slotId,
            },
            loyalty: buildEmptyLoyaltyPayload(slotContext.price),
          };

          tx.set(saleRef, salePayload, { merge: false });
          result.createdSale = true;
        }

        if (!cashFlowSnap.exists) {
          let saleTotal = slotContext.price;
          let saleStaffId = slotContext.operatorId;
          let saleDescription = slotContext.serviceName;

          const saleData = saleSnap.exists ? saleSnap.data() ?? {} : null;
          if (saleData) {
            saleTotal = normalizeCurrency(saleData.total ?? saleTotal);
            if (saleTotal <= 0) {
              saleTotal = slotContext.price;
            }
            if (typeof saleData.staffId === 'string' && saleData.staffId.trim().length > 0) {
              saleStaffId = saleData.staffId.trim();
            }
            if (
              Array.isArray(saleData.items) &&
              saleData.items.length > 0 &&
              typeof saleData.items[0].description === 'string' &&
              saleData.items[0].description.trim().length > 0
            ) {
              saleDescription = saleData.items[0].description.trim();
            }
          }

          if (saleTotal <= 0) {
            throw new functions.https.HttpsError(
              'failed-precondition',
              'Cannot create cash flow without a valid sale amount.',
            );
          }

          const clientData = clientSnap.exists ? clientSnap.data() ?? {} : {};
          const clientName =
            resolveClientName(clientData) || normalizeString(data.clientName);

          const cashFlowDescription = [
            `Last minute ${saleDescription}`,
            clientName || null,
          ]
            .filter((part) => part && part.trim().length > 0)
            .join(' · ');

          const cashFlowPayload: DocumentData = {
            salonId,
            type: 'income',
            amount: saleTotal,
            date: slotContext.start,
            description: cashFlowDescription,
            category: 'Vendite',
            staffId: saleStaffId,
            clientId,
            lastMinuteSlotId: slotId,
            source: 'client-fallback',
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          };

          tx.set(cashFlowRef, cashFlowPayload, { merge: false });
          result.createdCashFlow = true;
        }
      });

      return result;
    },
  );

function normalizeString(value: unknown): string {
  if (typeof value === 'string') {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : '';
  }
  return '';
}

function normalizeNumber(value: unknown, fallback = 0): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return fallback;
}

function normalizeCurrency(value: unknown): number {
  const numeric = normalizeNumber(value);
  return Math.round(numeric * 100) / 100;
}

function readTimestamp(value: unknown): Date | null {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return new Date(value);
  }
  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  return null;
}

function buildEmptyLoyaltyPayload(totalAmount: number): Record<string, unknown> {
  return {
    earnedPoints: 0,
    redeemedPoints: 0,
    netPoints: 0,
    earnedValue: 0,
    redeemedValue: 0,
    eligibleAmount: totalAmount,
    requestedEarnPoints: 0,
    requestedEarnValue: 0,
    processedMovementIds: [],
    computedAt: null,
    version: 1,
  };
}

function resolveClientName(data: DocumentData): string | null {
  const explicitFullName = normalizeString(data.fullName);
  if (explicitFullName) {
    return explicitFullName;
  }
  const firstName = normalizeString(data.firstName);
  const lastName = normalizeString(data.lastName);
  const combined = [firstName, lastName].filter((part) => part.length > 0).join(' ');
  return combined.length > 0 ? combined : null;
}

type NormalizedSlotPayload = {
  serviceId?: string;
  serviceName?: string;
  operatorId?: string;
  price?: number;
  start?: Date;
  durationMinutes?: number;
  roomId?: string;
};

type SlotContext = {
  serviceId: string;
  serviceName: string;
  operatorId: string | null;
  price: number;
  start: Date;
  durationMinutes: number;
  roomId: string | null;
};

function normalizeSlotPayload(raw: unknown): NormalizedSlotPayload | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const record = raw as Record<string, unknown>;
  const price =
    normalizeCurrency(
      record.priceNow ?? record.price ?? record.basePrice ?? record.amount ?? 0,
    );
  const start =
    readTimestamp(record.startAt) ??
    readTimestamp(record.start) ??
    readTimestamp(record.slotStart) ??
    readTimestamp(record.startIso);
  const durationMinutes = normalizeNumber(
    record.durationMinutes ?? record.duration ?? record.length,
    0,
  );

  return {
    serviceId: normalizeString(record.serviceId),
    serviceName: normalizeString(record.serviceName),
    operatorId: normalizeString(record.operatorId),
    price: price > 0 ? price : undefined,
    start: start ?? undefined,
    durationMinutes: durationMinutes > 0 ? Math.round(durationMinutes) : undefined,
    roomId: normalizeString(record.roomId),
  };
}

function resolveSlotContext(
  slotDoc: DocumentData | null,
  fallback: NormalizedSlotPayload | null,
  slotId: string,
): SlotContext {
  const serviceId =
    normalizeString(slotDoc ? slotDoc['serviceId'] : undefined) ||
    fallback?.serviceId ||
    slotId;
  const serviceName =
    normalizeString(slotDoc ? slotDoc['serviceName'] : undefined) ||
    fallback?.serviceName ||
    'Servizio last minute';
  const operatorId =
    normalizeString(slotDoc ? slotDoc['operatorId'] : undefined) ||
    fallback?.operatorId ||
    null;
  const price = normalizeCurrency(
    (slotDoc ? slotDoc['priceNow'] : undefined) ??
      (slotDoc ? slotDoc['price'] : undefined) ??
      (slotDoc ? slotDoc['basePrice'] : undefined) ??
      fallback?.price ??
      0,
  );
  const start =
    readTimestamp(slotDoc ? slotDoc['startAt'] : undefined) ??
    readTimestamp(slotDoc ? slotDoc['start'] : undefined) ??
    fallback?.start ??
    new Date();
  const durationMinutesRaw = normalizeNumber(
    (slotDoc ? slotDoc['durationMinutes'] : undefined) ??
      (slotDoc ? slotDoc['duration'] : undefined) ??
      fallback?.durationMinutes ??
      0,
    0,
  );
  const durationMinutes =
    durationMinutesRaw > 0 ? Math.round(durationMinutesRaw) : 30;
  const roomId =
    normalizeString(slotDoc ? slotDoc['roomId'] : undefined) ||
    fallback?.roomId ||
    null;

  return {
    serviceId,
    serviceName,
    operatorId,
    price,
    start,
    durationMinutes,
    roomId,
  };
}
