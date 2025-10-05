import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

import { firestore, readSalonLoyaltySettings, toInt, toNumber } from './utils';

const COLLECTION_CLIENTS = 'clients';
const MOVEMENT_PREFIX = 'sale-';

export const syncLoyaltyOnSaleWrite = functions.firestore
  .document('sales/{saleId}')
  .onWrite(async (change, context) => {
    const saleId = context.params.saleId as string;
    const beforeData: admin.firestore.DocumentData | null =
      change.before.exists ? change.before.data() ?? null : null;
    const afterData = change.after.exists ? change.after.data() : null;

    if (!afterData) {
      await handleSaleDeletion({ saleId, beforeData });
      return;
    }

    const salonId = (afterData.salonId as string | undefined) ?? '';
    const clientId = (afterData.clientId as string | undefined) ?? '';

    if (!salonId || !clientId) {
      functions.logger.debug('Missing salonId or clientId on sale; skip loyalty sync', {
        saleId,
      });
      return;
    }

    const loyalty = afterData.loyalty as Record<string, unknown> | undefined;
    if (!loyalty) {
      functions.logger.debug('Sale without loyalty payload, skipping sync', { saleId });
      return;
    }

    const settings = await readSalonLoyaltySettings(salonId);
    if (!settings?.enabled) {
      functions.logger.debug('Loyalty disabled for salon, skipping sync', {
        saleId,
        salonId,
      });
      return;
    }

    const movementId = `${MOVEMENT_PREFIX}${saleId}`;
    const clientRef = firestore.collection(COLLECTION_CLIENTS).doc(clientId);
    const saleRef = change.after.ref;

    await firestore.runTransaction(async (tx) => {
      const clientSnap = await tx.get(clientRef);
      if (!clientSnap.exists) {
        functions.logger.warn('Client not found during loyalty sync', {
          saleId,
          clientId,
        });
        return;
      }

      const movementRef = clientRef.collection('loyalty_movements').doc(movementId);
      const movementSnap = await tx.get(movementRef);

      const prevMovement = movementSnap.exists ? movementSnap.data() ?? {} : {};
      const prevEarned = toInt(prevMovement.earnedPoints);
      const prevRedeemed = toInt(prevMovement.redeemedPoints);
      const prevNet = toInt(
        prevMovement.netPoints ?? prevEarned - prevRedeemed,
      );

      const earnedPoints = resolveEarnedPoints(loyalty);
      const redeemedPoints = toInt(loyalty.redeemedPoints);
      const earnedValue = resolveEarnedValue(loyalty);
      const redeemedValue = toNumber(loyalty.redeemedValue);
      const eligibleAmount = toNumber(loyalty.eligibleAmount);
      const requestedEarnPoints = toInt(loyalty.requestedEarnPoints);
      const requestedEarnValue = toNumber(loyalty.requestedEarnValue);
      const netPoints = resolveNetPoints(loyalty, earnedPoints, redeemedPoints);

      const clientData = clientSnap.data() ?? {};
      const currentBalance = toInt(clientData.loyaltyPoints);
      const totalEarned = toInt(clientData.loyaltyTotalEarned);
      const totalRedeemed = toInt(clientData.loyaltyTotalRedeemed);

      const nextBalance = currentBalance - prevNet + netPoints;
      const nextTotalEarned = totalEarned - prevEarned + earnedPoints;
      const nextTotalRedeemed = totalRedeemed - prevRedeemed + redeemedPoints;

      const timestamp = admin.firestore.FieldValue.serverTimestamp();

      const movementPayload: Record<string, unknown> = {
        salonId,
        saleId,
        type: 'sale',
        source: 'sale',
        earnedPoints,
        redeemedPoints,
        netPoints,
        earnedValue,
        redeemedValue,
        requestedEarnPoints,
        requestedEarnValue,
        eligibleAmount,
        balanceAfter: nextBalance,
        updatedAt: timestamp,
      };

      if (movementSnap.exists && prevMovement.createdAt) {
        movementPayload.createdAt = prevMovement.createdAt;
      } else {
        movementPayload.createdAt = timestamp;
      }

      tx.set(movementRef, movementPayload, { merge: true });

      tx.update(clientRef, {
        loyaltyPoints: nextBalance,
        loyaltyTotalEarned: nextTotalEarned,
        loyaltyTotalRedeemed: nextTotalRedeemed,
        loyaltyUpdatedAt: timestamp,
      });

      const updatedLoyalty: Record<string, unknown> = {
        ...loyalty,
        earnedPoints,
        earnedValue,
        netPoints,
        redeemedPoints,
        redeemedValue,
        processedMovementIds: [movementId],
        computedAt: timestamp,
        requestedEarnPoints,
        requestedEarnValue,
      };

      tx.update(saleRef, { loyalty: updatedLoyalty });
    });
  });

async function handleSaleDeletion({
  saleId,
  beforeData,
}: {
  saleId: string;
  beforeData: FirebaseFirestore.DocumentData | null;
}) {
  if (!beforeData) {
    return;
  }
  const clientId = (beforeData.clientId as string | undefined) ?? '';
  if (!clientId) {
    return;
  }
  const loyaltyBefore = (beforeData.loyalty ?? {}) as Record<string, unknown>;
  const fallbackEarned = resolveEarnedPoints(loyaltyBefore);
  const fallbackRedeemed = toInt(loyaltyBefore.redeemedPoints);
  const fallbackNet = resolveNetPoints(
    loyaltyBefore,
    fallbackEarned,
    fallbackRedeemed,
  );
  const movementId = `${MOVEMENT_PREFIX}${saleId}`;
  const clientRef = firestore.collection(COLLECTION_CLIENTS).doc(clientId);

  await firestore.runTransaction(async (tx) => {
    const clientSnap = await tx.get(clientRef);
    if (!clientSnap.exists) {
      return;
    }

    const movementRef = clientRef.collection('loyalty_movements').doc(movementId);
    const movementSnap = await tx.get(movementRef);
    if (!movementSnap.exists) {
      if (fallbackEarned === 0 && fallbackRedeemed === 0 && fallbackNet === 0) {
        return;
      }
    }

    const movementData = movementSnap.data() ?? {};
    let prevEarned = toInt(movementData.earnedPoints);
    let prevRedeemed = toInt(movementData.redeemedPoints);
    let prevNet = toInt(
      movementData.netPoints ?? prevEarned - prevRedeemed,
    );

    if (prevEarned === 0 && fallbackEarned !== 0) {
      prevEarned = fallbackEarned;
    }
    if (prevRedeemed === 0 && fallbackRedeemed !== 0) {
      prevRedeemed = fallbackRedeemed;
    }
    if (prevNet === 0 && (fallbackNet !== 0 || fallbackEarned !== 0 || fallbackRedeemed !== 0)) {
      prevNet = fallbackNet;
    }

    const clientData = clientSnap.data() ?? {};
    const currentBalance = toInt(clientData.loyaltyPoints);
    const totalEarned = toInt(clientData.loyaltyTotalEarned);
    const totalRedeemed = toInt(clientData.loyaltyTotalRedeemed);
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    tx.delete(movementRef);
    tx.update(clientRef, {
      loyaltyPoints: currentBalance - prevNet,
      loyaltyTotalEarned: totalEarned - prevEarned,
      loyaltyTotalRedeemed: totalRedeemed + prevRedeemed,
      loyaltyUpdatedAt: timestamp,
    });
  });
}

function resolveEarnedPoints(loyalty: Record<string, unknown>): number {
  const earned = toInt(loyalty.earnedPoints);
  if (earned !== 0) {
    return earned;
  }
  const requested = toInt(loyalty.requestedEarnPoints);
  if (requested !== 0) {
    return requested;
  }
  const redeemed = toInt(loyalty.redeemedPoints);
  const net = toInt(loyalty.netPoints);
  if (net !== 0) {
    return net + redeemed;
  }
  return earned;
}

function resolveEarnedValue(loyalty: Record<string, unknown>): number {
  const earned = toNumber(loyalty.earnedValue);
  if (earned !== 0) {
    return earned;
  }
  const requested = toNumber(loyalty.requestedEarnValue);
  if (requested !== 0) {
    return requested;
  }
  return earned;
}

function resolveNetPoints(
  loyalty: Record<string, unknown>,
  earnedPoints: number,
  redeemedPoints: number,
): number {
  const storedNet = toInt(loyalty.netPoints);
  const computedNet = earnedPoints - redeemedPoints;
  if (storedNet !== 0 || computedNet === 0) {
    return storedNet;
  }
  return computedNet;
}
