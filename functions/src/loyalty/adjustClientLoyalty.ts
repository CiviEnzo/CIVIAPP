import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';

import { firestore, readSalonLoyaltySettings, toInt } from './utils';

const COLLECTION_CLIENTS = 'clients';
const functionsEU = functions.region('europe-west1');

export const adjustClientLoyalty = functionsEU.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required to adjust loyalty points.',
      );
    }

    const clientId = (data?.clientId as string | undefined) ?? '';
    const pointsRaw = data?.points;
    const note = (data?.note as string | undefined) ?? null;

    if (!clientId || typeof pointsRaw !== 'number' || pointsRaw === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'clientId and a non-zero numeric points value are required.',
      );
    }

    const points = Math.trunc(pointsRaw);

    const operatorId = context.auth.uid;
    const operatorName =
        (context.auth.token.name as string | undefined) ??
        (context.auth.token.email as string | undefined) ??
        operatorId;

    const clientRef = firestore.collection(COLLECTION_CLIENTS).doc(clientId);
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    const result = await firestore.runTransaction(async (tx) => {
      const clientSnap = await tx.get(clientRef);
      if (!clientSnap.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Client not found.',
        );
      }

      const clientData = clientSnap.data() ?? {};
      const salonId = clientData.salonId as string | undefined;
      const currentBalance = toInt(clientData.loyaltyPoints);
      const totalEarned = toInt(clientData.loyaltyTotalEarned);
      const totalRedeemed = toInt(clientData.loyaltyTotalRedeemed);

      const settings = salonId
        ? await readSalonLoyaltySettings(salonId)
        : null;
      const pointValueEuro = settings?.redemption.pointValueEuro ?? 1;

      const rawNextBalance = currentBalance + points;
      const nextBalance = rawNextBalance < 0 ? 0 : rawNextBalance;
      const actualDelta = nextBalance - currentBalance;
      const earnedDelta = actualDelta > 0 ? actualDelta : 0;
      const redeemedDelta = actualDelta < 0 ? Math.abs(actualDelta) : 0;

      const nextTotalEarned = totalEarned + earnedDelta;
      const nextTotalRedeemed = totalRedeemed + redeemedDelta;

      const movementRef = clientRef
        .collection('loyalty_movements')
        .doc();

      const trimmedNote = note?.trim();

      tx.set(movementRef, {
        salonId,
        type: 'adjustment',
        source: 'manual',
        points: actualDelta,
        earnedPoints: earnedDelta,
        redeemedPoints: redeemedDelta,
        earnedValue: earnedDelta * pointValueEuro,
        redeemedValue: redeemedDelta * pointValueEuro,
        operatorId,
        operatorName,
        note: trimmedNote && trimmedNote.length > 0 ? trimmedNote : null,
        createdAt: timestamp,
        updatedAt: timestamp,
        balanceAfter: nextBalance,
      });

      tx.update(clientRef, {
        loyaltyPoints: nextBalance,
        loyaltyTotalEarned: nextTotalEarned,
        loyaltyTotalRedeemed: nextTotalRedeemed,
        loyaltyUpdatedAt: timestamp,
      });

      return {
        clientId,
        salonId,
        balance: nextBalance,
        totalEarned: nextTotalEarned,
        totalRedeemed: nextTotalRedeemed,
        movementId: movementRef.id,
        delta: actualDelta,
      };
    });

    functions.logger.info('Manual loyalty adjustment applied', {
      clientId,
      points,
      operatorId,
      movementId: result.movementId,
    });

    return {
      status: 'ok',
      ...result,
    };
  },
);
