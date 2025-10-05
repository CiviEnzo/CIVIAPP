import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

import {
  LoyaltySettings,
  coerceLoyaltySettings,
  firestore,
  toInt,
} from './utils';

const COLLECTION_SALONS = 'salons';
const COLLECTION_CLIENTS = 'clients';

export const scheduleLoyaltyReset = functions.pubsub
  .schedule('0 3 * * *')
  .timeZone('Europe/Rome')
  .onRun(async () => {
    const snapshot = await firestore
      .collection(COLLECTION_SALONS)
      .where('loyaltySettings.enabled', '==', true)
      .get();

    if (snapshot.empty) {
      functions.logger.info('No salons with loyalty enabled found for reset');
      return null;
    }

    const now = new Date();
    let processedSalons = 0;

    for (const salonDoc of snapshot.docs) {
      const salonData = salonDoc.data();
      const settings = coerceLoyaltySettings(salonData.loyaltySettings);
      if (!settings?.enabled) {
        continue;
      }
      if (!shouldResetToday(settings)) {
        continue;
      }
      await resetSalonLoyalty(salonDoc.id, settings);
      processedSalons += 1;
    }

    functions.logger.info('scheduleLoyaltyReset completed', {
      processedSalons,
      timestamp: now.toISOString(),
    });
    return null;
  });

function shouldResetToday(settings: LoyaltySettings): boolean {
  const tz = settings.expiration.timezone ?? 'Europe/Rome';
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: tz,
    month: 'numeric',
    day: 'numeric',
  });
  const parts = formatter.formatToParts(new Date());
  const month = Number(parts.find((p) => p.type === 'month')?.value ?? '0');
  const day = Number(parts.find((p) => p.type === 'day')?.value ?? '0');
  return (
    month === settings.expiration.resetMonth &&
    day === settings.expiration.resetDay
  );
}

async function resetSalonLoyalty(
  salonId: string,
  settings: LoyaltySettings,
) {
  const clientsSnap = await firestore
    .collection(COLLECTION_CLIENTS)
    .where('salonId', '==', salonId)
    .get();

  if (clientsSnap.empty) {
    functions.logger.info('No clients to reset for salon', { salonId });
    return;
  }

  const initialBalance = settings.initialBalance ?? 0;
  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  for (const clientDoc of clientsSnap.docs) {
    await firestore.runTransaction(async (tx) => {
      const clientRef = clientDoc.ref;
      const snap = await tx.get(clientRef);
      if (!snap.exists) {
        return;
      }
      const data = snap.data() ?? {};
      const currentPoints = toInt(data.loyaltyPoints);
      const totalEarned = toInt(data.loyaltyTotalEarned);
      const totalRedeemed = toInt(data.loyaltyTotalRedeemed);

      const target = initialBalance;
      const delta = target - currentPoints;
      if (delta === 0) {
        return;
      }

      const earnedDelta = delta > 0 ? delta : 0;
      const redeemedDelta = delta < 0 ? Math.abs(delta) : 0;
      const nextEarned = totalEarned + earnedDelta;
      const nextRedeemed = totalRedeemed + redeemedDelta;

      const movementRef = clientRef
        .collection('loyalty_movements')
        .doc(`reset-${Date.now()}`);

      const note =
        delta < 0
          ? 'Reset annuale: punti scaduti'
          : 'Reset annuale: saldo iniziale';

      tx.set(movementRef, {
        salonId,
        type: 'expiration',
        source: 'system',
        points: delta,
        earnedPoints: earnedDelta,
        redeemedPoints: redeemedDelta,
        earnedValue: 0,
        redeemedValue: 0,
        note,
        createdAt: timestamp,
        updatedAt: timestamp,
        balanceAfter: target,
      });

      tx.update(clientRef, {
        loyaltyPoints: target,
        loyaltyTotalEarned: nextEarned,
        loyaltyTotalRedeemed: nextRedeemed,
        loyaltyUpdatedAt: timestamp,
      });
    });
  }
}
