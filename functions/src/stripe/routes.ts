import type { Request, Response } from 'express';
import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import Stripe from 'stripe';

import { coerceLoyaltySettings } from '../loyalty/utils';

import {
  stripeSecretKey,
  stripeWebhookSecret,
  stripeApplicationFeeAmount,
  stripePlatformName,
  stripeAllowedOrigin,
} from './config';
import { getStripeClient } from './stripeClient';
import { applyCors, parseJsonBody, toStripeMetadata } from './utils';

const db = getFirestore();

const SALES_COLLECTION = 'sales';
const CARTS_COLLECTION = 'carts';
const ORDERS_COLLECTION = 'orders';
const LAST_MINUTE_SLOTS_COLLECTION = 'last_minute_slots';
const APPOINTMENTS_COLLECTION = 'appointments';
const CLIENTS_COLLECTION = 'clients';
const SALON_SEQUENCES_COLLECTION = 'salon_sequences';
const CASH_FLOWS_COLLECTION = 'cash_flows';

const getCorsOrigin = (): string => stripeAllowedOrigin.value() || '*';
const getPlatformName = (): string => stripePlatformName.value() || 'CIVIAPP';
const getApplicationFeeAmount = (): number => stripeApplicationFeeAmount.value();

const respondMethodNotAllowed = (res: Response): void => {
  res.set('Allow', 'POST, OPTIONS');
  res.status(405).json({ error: 'Method not allowed' });
};

const handleError = (res: Response, error: unknown, message = 'Internal error'): void => {
  console.error(message, error);
  res.status(500).json({ error: message });
};

const getSalonStripeAccountId = async (
  salonId?: string,
  explicitAccountId?: string,
): Promise<string | null> => {
  if (explicitAccountId) {
    return explicitAccountId;
  }
  if (!salonId) {
    return null;
  }
  const snapshot = await db.collection('salons').doc(salonId).get();
  if (!snapshot.exists) {
    return null;
  }
  const data = snapshot.data() as { stripeAccountId?: string } | undefined;
  return data?.stripeAccountId ?? null;
};

const updateSalonAccountSnapshot = async (account: Stripe.Account): Promise<void> => {
  const snapshot = await db
    .collection('salons')
    .where('stripeAccountId', '==', account.id)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return;
  }

  const salonRef = snapshot.docs[0].ref;
  await salonRef.set(
    {
      stripeAccount: {
        chargesEnabled: account.charges_enabled ?? false,
        payoutsEnabled: account.payouts_enabled ?? false,
        detailsSubmitted: account.details_submitted ?? false,
        requirements: {
          currentlyDue: account.requirements?.currently_due ?? [],
          pastDue: account.requirements?.past_due ?? [],
          eventuallyDue: account.requirements?.eventually_due ?? [],
          disabledReason: account.requirements?.disabled_reason ?? null,
        },
        updatedAt: FieldValue.serverTimestamp(),
      },
    },
    { merge: true },
  );
};

export const createStripeConnectAccount = onRequest(
  { secrets: [stripeSecretKey], cors: false, region: 'europe-west3' },
  async (req: Request, res: Response) => {
    const origin = getCorsOrigin();
    if (applyCors(req, res, origin)) {
      return;
    }
    if (req.method !== 'POST') {
      respondMethodNotAllowed(res);
      return;
    }

    try {
      const body = parseJsonBody<{
        email?: string;
        country?: string;
        businessType?: Stripe.AccountCreateParams.BusinessType;
        salonId?: string;
      }>(req.body);

      const { email, country = 'IT', businessType = 'individual', salonId } = body;

      if (!email) {
        res.status(400).json({ error: 'email is required' });
        return;
      }

      const stripe = getStripeClient();
      const account = await stripe.accounts.create({
        type: 'express',
        email,
        country,
        business_type: businessType,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
      });

      if (salonId) {
        await db
          .collection('salons')
          .doc(salonId)
          .set(
            {
              stripeAccountId: account.id,
              stripeAccount: {
                createdAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp(),
                chargesEnabled: account.charges_enabled ?? false,
                payoutsEnabled: account.payouts_enabled ?? false,
                detailsSubmitted: account.details_submitted ?? false,
              },
            },
            { merge: true },
          );
      }

      res.status(200).json({
        accountId: account.id,
        chargesEnabled: account.charges_enabled ?? false,
        payoutsEnabled: account.payouts_enabled ?? false,
        detailsSubmitted: account.details_submitted ?? false,
      });
    } catch (error) {
      if (error instanceof Stripe.errors.StripeError) {
        res.status(error.statusCode ?? 400).json({ error: error.message });
        return;
      }
      handleError(res, error);
    }
  },
);

type FirestoreCartItem = {
  id?: string;
  referenceId?: string;
  type?: string;
  name?: string;
  quantity?: number;
  unitPrice?: number;
  totalAmount?: number;
  totalAmountCents?: number;
  metadata?: Record<string, unknown>;
};

type SaleItemSummary = {
  referenceId: string | null;
  referenceType: string | null;
  description: string | null;
  quantity: number;
  unitPrice: number;
};

async function handlePaymentIntentSuccess(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  const metadata = extractMetadata(paymentIntent.metadata);
  const cartId = normalizeString(metadata.cartId);
  const orderRef = db.collection(ORDERS_COLLECTION).doc(paymentIntent.id);
  const saleRef = db.collection(SALES_COLLECTION).doc(paymentIntent.id);
  const stripeCustomerId =
    typeof paymentIntent.customer === 'string' ? paymentIntent.customer : null;
  const totalAmountCents = paymentIntent.amount_received ?? paymentIntent.amount ?? 0;
  const totalAmount = normalizeCurrency(totalAmountCents / 100);
  const createdDate = paymentIntent.created
    ? new Date(paymentIntent.created * 1000)
    : new Date();
  const createdTimestamp = Timestamp.fromDate(createdDate);

  let resolvedSalonId: string | null = normalizeString(metadata.salonId);
  let resolvedClientId: string | null = normalizeString(metadata.clientId);
  let saleItemsSummary: SaleItemSummary[] = [];
  let cartItemTypes: string[] = [];
  let lastMinuteSlotId: string | null = normalizeString(metadata.slotId);
  let generatedAppointmentId: string | null = null;
  let cartCurrency: string | null = paymentIntent.currency ?? null;
  let saleDocumentExists = false;

  await db.runTransaction(async (tx) => {
    const cartRef = cartId ? db.collection(CARTS_COLLECTION).doc(cartId) : null;
    let cartData: FirebaseFirestore.DocumentData | null = null;
    let rawCartItems: FirestoreCartItem[] = [];

    if (cartRef) {
      const cartSnap = await tx.get(cartRef);
      if (cartSnap.exists) {
        cartData = cartSnap.data() ?? {};
        if (!resolvedSalonId) {
          resolvedSalonId = normalizeString(cartData.salonId);
        }
        if (!resolvedClientId) {
          resolvedClientId = normalizeString(cartData.clientId);
        }
        if (!cartCurrency && typeof cartData.currency === 'string') {
          cartCurrency = cartData.currency;
        }
        rawCartItems = extractCartItems(cartData);
        const typesSet = new Set(
          rawCartItems
            .map((item) => normalizeString(item.type))
            .filter((value) => value.length > 0),
        );
        cartItemTypes = Array.from(typesSet);
      }
    }

    if (rawCartItems.length === 0) {
      rawCartItems = [buildFallbackCartItem(paymentIntent, metadata, totalAmount)];
      if (cartItemTypes.length === 0) {
        cartItemTypes = [
          normalizeString(rawCartItems[0]?.type) || 'service',
        ];
      }
    }

    // Capture last-minute slot id if present in cart items.
    for (const item of rawCartItems) {
      if (normalizeString(item.type) === 'lastMinute') {
        const candidateSlot = normalizeString(
          (item.metadata?.slotId as string | undefined) ?? item.referenceId,
        );
        if (candidateSlot) {
          lastMinuteSlotId = candidateSlot;
          break;
        }
      }
    }

    const saleItems = rawCartItems.map(mapCartItemToSaleItem);
    saleItemsSummary = saleItems.map(buildSaleItemSummary);

    const saleSnap = await tx.get(saleRef);
    saleDocumentExists = saleSnap.exists;
    const loyaltyPayload = await buildInitialLoyaltyPayload(
      tx,
      resolvedSalonId,
      totalAmount,
      metadata,
    );
    if (!saleDocumentExists && resolvedSalonId && resolvedClientId) {
      const sequencesRef = db
        .collection(SALON_SEQUENCES_COLLECTION)
        .doc(resolvedSalonId);
      const sequencesSnap = await tx.get(sequencesRef);
      let saleSequence = 0;
      let invoiceSequence = 0;
      if (sequencesSnap.exists) {
        const seqData = sequencesSnap.data() ?? {};
        saleSequence = coercePositiveInt(seqData.saleSequence);
        invoiceSequence = coercePositiveInt(seqData.invoiceSequence);
      }
      saleSequence += 1;
      invoiceSequence += 1;
      tx.set(
        sequencesRef,
        {
          saleSequence,
          invoiceSequence,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      const saleNumber = formatSaleNumber(saleSequence);
      const invoiceNumber = formatInvoiceNumber(invoiceSequence);

      const salePayload: FirebaseFirestore.DocumentData = {
        salonId: resolvedSalonId,
        clientId: resolvedClientId,
        items: saleItems,
        total: totalAmount,
        createdAt: createdTimestamp,
        paymentMethod: 'pos',
        paymentStatus: 'paid',
        paidAmount: totalAmount,
        discountAmount: 0,
        invoiceNumber,
        saleNumber,
        paymentHistory: [
          {
            id: `${paymentIntent.id}-settlement`,
            amount: totalAmount,
            type: 'settlement',
            date: createdTimestamp,
            paymentMethod: 'pos',
          },
        ],
        loyalty: loyaltyPayload,
        metadata: {
          source: 'stripe',
          cartId: cartId || null,
          origin: metadata.origin ?? metadata.type ?? null,
          cartItemTypes,
          lastMinuteSlotId,
        },
        stripe: {
          paymentIntentId: paymentIntent.id,
          customerId: stripeCustomerId,
          latestChargeId: paymentIntent.latest_charge ?? null,
          chargeIds: extractChargeIds(paymentIntent),
        },
      };
      tx.set(saleRef, salePayload, { merge: false });
      saleDocumentExists = true;
    } else if (!resolvedSalonId || !resolvedClientId) {
      console.warn('Stripe webhook: missing salonId/clientId for sale creation', {
        paymentIntentId: paymentIntent.id,
        salonId: resolvedSalonId,
        clientId: resolvedClientId,
      });
    }

    if (resolvedClientId && stripeCustomerId) {
      const clientRef = db.collection(CLIENTS_COLLECTION).doc(resolvedClientId);
      tx.set(
        clientRef,
        { stripeCustomerId },
        { merge: true },
      );
    }

    let generatedAppointmentIdLocal: string | null = null;
    if (lastMinuteSlotId && resolvedSalonId && resolvedClientId) {
      const slotRef = db.collection(LAST_MINUTE_SLOTS_COLLECTION).doc(lastMinuteSlotId);
      const slotSnap = await tx.get(slotRef);
      if (slotSnap.exists) {
        const slotData = slotSnap.data() ?? {};
        const slotStart =
          readTimestamp(slotData.startAt) ??
          readTimestamp(slotData.start) ??
          new Date();
        const durationMinutes = Math.max(
          5,
          Math.round(
            normalizeNumber(slotData.durationMinutes ?? slotData.duration ?? 30),
          ),
        );
        const slotEnd = new Date(slotStart.getTime() + durationMinutes * 60000);
        const serviceId =
          normalizeString(slotData.serviceId) ||
          normalizeString(
            rawCartItems
              .find((item) => normalizeString(item.type) === 'lastMinute')
              ?.metadata?.serviceId as string | undefined,
          );
        const staffId =
          normalizeString(slotData.operatorId) || 'auto-stripe';
        const roomId = normalizeString(slotData.roomId) || null;
        const clientDisplayName =
          (await fetchClientDisplayName(tx, resolvedClientId)) ||
          metadata.clientName ||
          null;
        const appointmentRef = db
          .collection(APPOINTMENTS_COLLECTION)
          .doc(`stripe-${paymentIntent.id}`);
        const appointmentSnap = await tx.get(appointmentRef);
        if (!appointmentSnap.exists) {
          tx.set(
            appointmentRef,
            {
              salonId: resolvedSalonId,
              clientId: resolvedClientId,
              staffId,
              serviceId: serviceId || null,
              serviceIds: serviceId ? [serviceId] : [],
              start: Timestamp.fromDate(slotStart),
              end: Timestamp.fromDate(slotEnd),
              status: 'confirmed',
              notes: `Prenotazione last-minute ${lastMinuteSlotId} (Stripe)`,
              lastMinuteSlotId,
              roomId,
              createdAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: false },
          );
          generatedAppointmentIdLocal = appointmentRef.id;
        }

        tx.set(
          slotRef,
          {
            availableSeats: 0,
            bookedClientId: resolvedClientId,
            bookedClientName: clientDisplayName,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    }
    generatedAppointmentId = generatedAppointmentIdLocal ?? generatedAppointmentId;

    if (cartRef) {
      const cartUpdate: Record<string, unknown> = {
        status: saleDocumentExists ? 'paid' : 'processed',
        paymentIntentId: paymentIntent.id,
        amountPaid: totalAmount,
        currency: cartCurrency ?? paymentIntent.currency ?? 'eur',
        updatedAt: FieldValue.serverTimestamp(),
        paidAt: FieldValue.serverTimestamp(),
      };
      if (saleDocumentExists) {
        cartUpdate.saleId = saleRef.id;
      }
      if (lastMinuteSlotId) {
        cartUpdate.lastMinuteSlotId = lastMinuteSlotId;
      }
      if (generatedAppointmentId) {
        cartUpdate.appointmentId = generatedAppointmentId;
      }
      if (resolvedSalonId && !normalizeString(cartData?.salonId)) {
        cartUpdate.salonId = resolvedSalonId;
      }
      if (resolvedClientId && !normalizeString(cartData?.clientId)) {
        cartUpdate.clientId = resolvedClientId;
      }
      tx.set(cartRef, cartUpdate, { merge: true });
    }
  });

  // Reload sale document status after transaction (for orders payload).
  const saleSnapAfter = await saleRef.get();
  saleDocumentExists = saleSnapAfter.exists;
  if (resolvedSalonId) {
    const cashFlowRef = db.collection(CASH_FLOWS_COLLECTION).doc(paymentIntent.id);
    const cashFlowSnapshot = await cashFlowRef.get();
    const serviceNameFromMetadata =
      normalizeString(metadata.serviceName) ||
      normalizeString(metadata['cart_serviceName']);
    const saleItemServiceName =
      saleItemsSummary.find((item) => item.referenceType === 'service')?.description ?? null;
    const clientNameFromMetadata =
      normalizeString(metadata.clientName) ||
      normalizeString(metadata['cart_clientName']);
    const isLastMinuteSale =
      normalizeString(metadata.type) === 'lastMinute' ||
      cartItemTypes.includes('lastMinute') ||
      !!lastMinuteSlotId;
    const descriptionParts: string[] = [];
    if (isLastMinuteSale) {
      const serviceLabel = serviceNameFromMetadata || saleItemServiceName || 'Last minute';
      descriptionParts.push(`Last minute ${serviceLabel}`);
    } else {
      descriptionParts.push('Vendita Stripe');
    }
    if (clientNameFromMetadata) {
      descriptionParts.push(clientNameFromMetadata);
    }
    const cashFlowDescription = descriptionParts.join(' · ');
    const cashFlowPayload: FirebaseFirestore.DocumentData = {
      salonId: resolvedSalonId,
      type: 'income',
      amount: totalAmount,
      date: createdTimestamp,
      description: cashFlowDescription,
      category: 'Vendite',
      staffId: 'auto-stripe',
      source: 'stripe',
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (saleDocumentExists) {
      cashFlowPayload.saleId = saleRef.id;
    }
    if (resolvedClientId) {
      cashFlowPayload.clientId = resolvedClientId;
    }
    if (lastMinuteSlotId) {
      cashFlowPayload.lastMinuteSlotId = lastMinuteSlotId;
    }
    if (generatedAppointmentId) {
      cashFlowPayload.appointmentId = generatedAppointmentId;
    }
    if (!cashFlowSnapshot.exists) {
      cashFlowPayload.createdAt = FieldValue.serverTimestamp();
    }
    await cashFlowRef.set(
      cashFlowPayload,
      cashFlowSnapshot.exists ? { merge: true } : { merge: false },
    );
  }

  const orderPayload: FirebaseFirestore.DocumentData = {
    status: 'paid',
    amount: paymentIntent.amount,
    amountReceived: paymentIntent.amount_received ?? paymentIntent.amount ?? null,
    currency: paymentIntent.currency,
    clientId: resolvedClientId ?? null,
    salonId: resolvedSalonId ?? null,
    cartId: cartId || null,
    type: metadata.type ?? null,
    metadata,
    saleId: saleDocumentExists ? saleRef.id : null,
    items: saleItemsSummary,
    cartItemTypes,
    lastMinuteSlotId,
    appointmentId: generatedAppointmentId,
    stripe: {
      paymentIntentId: paymentIntent.id,
      customerId: stripeCustomerId,
      latestChargeId: paymentIntent.latest_charge ?? null,
    },
    updatedAt: FieldValue.serverTimestamp(),
  };

  const orderSnap = await orderRef.get();
  if (!orderSnap.exists || !orderSnap.data()?.createdAt) {
    orderPayload.createdAt = FieldValue.serverTimestamp();
  }

  await orderRef.set(orderPayload, { merge: true });
}

async function handlePaymentIntentFailure(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  const metadata = extractMetadata(paymentIntent.metadata);
  const cartId = normalizeString(metadata.cartId);
  const stripeCustomerId =
    typeof paymentIntent.customer === 'string' ? paymentIntent.customer : null;

  if (cartId) {
    await db
      .collection(CARTS_COLLECTION)
      .doc(cartId)
      .set(
        {
          status: 'failed',
          paymentIntentId: paymentIntent.id,
          updatedAt: FieldValue.serverTimestamp(),
          errorCode: paymentIntent.last_payment_error?.code ?? null,
          errorMessage: paymentIntent.last_payment_error?.message ?? null,
        },
        { merge: true },
      );
  }

  if (stripeCustomerId && metadata.clientId) {
    await db
      .collection(CLIENTS_COLLECTION)
      .doc(metadata.clientId)
      .set(
        { stripeCustomerId },
        { merge: true },
      );
  }

  const orderRef = db.collection(ORDERS_COLLECTION).doc(paymentIntent.id);
  const orderPayload: FirebaseFirestore.DocumentData = {
    status: 'failed',
    amount: paymentIntent.amount,
    amountReceived: paymentIntent.amount_received ?? paymentIntent.amount ?? null,
    currency: paymentIntent.currency,
    clientId: metadata.clientId ?? null,
    salonId: metadata.salonId ?? null,
    cartId: cartId || null,
    type: metadata.type ?? null,
    metadata,
    stripe: {
      paymentIntentId: paymentIntent.id,
      customerId: stripeCustomerId,
      latestChargeId: paymentIntent.latest_charge ?? null,
      failureCode: paymentIntent.last_payment_error?.code ?? null,
      failureMessage: paymentIntent.last_payment_error?.message ?? null,
    },
    updatedAt: FieldValue.serverTimestamp(),
  };

  const orderSnap = await orderRef.get();
  if (!orderSnap.exists || !orderSnap.data()?.createdAt) {
    orderPayload.createdAt = FieldValue.serverTimestamp();
  }

  await orderRef.set(orderPayload, { merge: true });
}

function extractMetadata(metadata: Stripe.Metadata | undefined | null): Record<string, string> {
  if (!metadata) {
    return {};
  }
  const entries = Object.entries(metadata)
    .filter((entry): entry is [string, string] => typeof entry[1] === 'string');
  return Object.fromEntries(entries);
}

function extractCartItems(
  cartData: FirebaseFirestore.DocumentData | null,
): FirestoreCartItem[] {
  if (!cartData || !Array.isArray(cartData.items)) {
    return [];
  }
  return cartData.items.map((raw) => {
    const metadata =
      raw && typeof raw.metadata === 'object' && !Array.isArray(raw.metadata)
        ? (raw.metadata as Record<string, unknown>)
        : {};
    return {
      id: normalizeString(raw.id),
      referenceId: normalizeString(raw.referenceId),
      type: normalizeString(raw.type),
      name: typeof raw.name === 'string' ? raw.name : undefined,
      quantity: typeof raw.quantity === 'number' ? raw.quantity : Number(raw.quantity),
      unitPrice: typeof raw.unitPrice === 'number' ? raw.unitPrice : Number(raw.unitPrice),
      totalAmount:
        typeof raw.totalAmount === 'number' ? raw.totalAmount : Number(raw.totalAmount),
      totalAmountCents:
        typeof raw.totalAmountCents === 'number'
          ? raw.totalAmountCents
          : Number(raw.totalAmountCents),
      metadata,
    };
  });
}

function mapCartItemToSaleItem(item: FirestoreCartItem): Record<string, unknown> {
  const metadata = item.metadata ?? {};
  const quantity = normalizeNumber(item.quantity, 1);
  const unitPrice = normalizeCurrency(
    item.unitPrice !== undefined ? item.unitPrice : computeCartItemSubtotal(item) / quantity,
  );
  const referenceType = resolveReferenceType(
    normalizeString(item.type),
    metadata,
  );
  const referenceId =
    normalizeString(item.referenceId) ||
    normalizeString(metadata.referenceId) ||
    (referenceType === 'package'
      ? normalizeString(metadata.packageId)
      : normalizeString(metadata.serviceId)) ||
    normalizeString(item.id) ||
    'item';
  const description =
    typeof item.name === 'string' && item.name.trim().length > 0
      ? item.name
      : typeof metadata.name === 'string' && metadata.name.trim().length > 0
        ? metadata.name
        : referenceType === 'package'
          ? 'Pacchetto'
          : referenceType === 'service'
            ? 'Servizio'
            : 'Prodotto';

  const saleItem: Record<string, unknown> = {
    referenceId,
    referenceType,
    description,
    quantity,
    unitPrice,
  };

  if (referenceType === 'package') {
    const sessions = normalizeNumber(metadata.sessionCount, 0);
    if (sessions > 0) {
      saleItem.totalSessions = sessions;
      saleItem.remainingSessions = sessions;
    }
    saleItem.packageStatus = 'active';
    saleItem.packagePaymentStatus = 'paid';
  }

  if (metadata.packageServiceSessions && typeof metadata.packageServiceSessions === 'object') {
    saleItem.packageServiceSessions = metadata.packageServiceSessions;
  }

  return saleItem;
}

function resolveReferenceType(
  itemType: string,
  metadata: Record<string, unknown>,
): 'service' | 'package' | 'product' {
  if (itemType === 'package') {
    return 'package';
  }
  if (itemType === 'service' || itemType === 'lastMinute' || metadata.serviceId) {
    return 'service';
  }
  return 'product';
}

function buildFallbackCartItem(
  paymentIntent: Stripe.PaymentIntent,
  metadata: Record<string, string>,
  totalAmount: number,
): FirestoreCartItem {
  const description =
    metadata.description ??
    metadata.type ??
    `Pagamento ${paymentIntent.id.slice(-6)}`;
  return {
    id: `pi-${paymentIntent.id}`,
    referenceId: metadata.serviceId ?? metadata.packageId ?? paymentIntent.id,
    type: metadata.type ?? 'service',
    name: description,
    quantity: 1,
    unitPrice: totalAmount,
    metadata: {
      source: 'stripe',
    },
  };
}

function buildSaleItemSummary(item: Record<string, unknown>): SaleItemSummary {
  return {
    referenceId: typeof item.referenceId === 'string' ? item.referenceId : null,
    referenceType: typeof item.referenceType === 'string' ? item.referenceType : null,
    description: typeof item.description === 'string' ? item.description : null,
    quantity: normalizeNumber(item.quantity, 1),
    unitPrice: normalizeCurrency(item.unitPrice),
  };
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

async function buildInitialLoyaltyPayload(
  tx: FirebaseFirestore.Transaction,
  salonId: string | null,
  totalAmount: number,
  metadata: Record<string, string>,
): Promise<Record<string, unknown>> {
  const basePayload = buildEmptyLoyaltyPayload(totalAmount);
  if (!salonId) {
    return basePayload;
  }

  const salonRef = db.collection('salons').doc(salonId);
  const salonSnap = await tx.get(salonRef);
  if (!salonSnap.exists) {
    return basePayload;
  }
  const salonData = salonSnap.data() ?? {};
  const settings = coerceLoyaltySettings(salonData.loyaltySettings);
  if (!settings || !settings.enabled) {
    return basePayload;
  }

  const eligibleAmountFromMetadata = normalizeNumber(metadata.loyaltyEligibleAmount);
  const eligibleAmount =
    eligibleAmountFromMetadata > 0
      ? normalizeCurrency(eligibleAmountFromMetadata)
      : normalizeCurrency(totalAmount);
  if (eligibleAmount <= 0) {
    return {
      ...basePayload,
      eligibleAmount,
    };
  }

  const euroPerPoint =
    settings.earning.euroPerPoint > 0 ? settings.earning.euroPerPoint : 10;
  const roundingMode = settings.earning.rounding ?? 'floor';
  const rawPoints = eligibleAmount / euroPerPoint;
  const earnedPoints = applyLoyaltyRounding(rawPoints, roundingMode);
  const pointValue =
    settings.redemption.pointValueEuro > 0 ? settings.redemption.pointValueEuro : 1;
  const earnedValue = normalizeCurrency(earnedPoints * pointValue);

  return {
    ...basePayload,
    eligibleAmount,
    requestedEarnPoints: earnedPoints,
    requestedEarnValue: earnedValue,
    earnedPoints,
    earnedValue,
    netPoints: earnedPoints,
  };
}

function applyLoyaltyRounding(
  value: number,
  mode: 'floor' | 'round' | 'ceil',
): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  switch (mode) {
    case 'round':
      return Math.round(value);
    case 'ceil':
      return Math.ceil(value);
    case 'floor':
    default:
      return Math.floor(value);
  }
}

function extractChargeIds(paymentIntent: Stripe.PaymentIntent): string[] {
  const chargeId =
    typeof paymentIntent.latest_charge === 'string' ? paymentIntent.latest_charge : null;
  return chargeId ? [chargeId] : [];
}

function formatSaleNumber(sequence: number): string {
  const year = new Date().getFullYear();
  return `SALE-${year}-${sequence.toString().padStart(4, '0')}`;
}

function formatInvoiceNumber(sequence: number): string {
  const year = new Date().getFullYear();
  return `INV-${year}-${sequence.toString().padStart(4, '0')}`;
}

function coercePositiveInt(value: unknown): number {
  const numeric = Number(value);
  if (Number.isFinite(numeric) && numeric >= 0) {
    return Math.trunc(numeric);
  }
  return 0;
}

function computeCartItemSubtotal(item: FirestoreCartItem): number {
  if (typeof item.totalAmount === 'number' && Number.isFinite(item.totalAmount)) {
    return item.totalAmount;
  }
  if (
    typeof item.totalAmountCents === 'number' &&
    Number.isFinite(item.totalAmountCents)
  ) {
    return normalizeCurrency(item.totalAmountCents / 100);
  }
  const quantity = normalizeNumber(item.quantity, 1);
  const unitPrice = normalizeCurrency(item.unitPrice ?? 0);
  return normalizeCurrency(quantity * unitPrice);
}

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
  const numeric = normalizeNumber(value, 0);
  return Math.round(numeric * 100) / 100;
}

function readTimestamp(value: unknown): Date | null {
  if (value instanceof Timestamp) {
    return value.toDate();
  }
  if (value instanceof Date) {
    return value;
  }
  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  return null;
}

async function fetchClientDisplayName(
  tx: FirebaseFirestore.Transaction,
  clientId: string,
): Promise<string | null> {
  if (!clientId) {
    return null;
  }
  const clientRef = db.collection(CLIENTS_COLLECTION).doc(clientId);
  const clientSnap = await tx.get(clientRef);
  if (!clientSnap.exists) {
    return null;
  }
  const data = clientSnap.data() ?? {};
  if (typeof data.fullName === 'string' && data.fullName.trim().length > 0) {
    return data.fullName.trim();
  }
  const firstName = typeof data.firstName === 'string' ? data.firstName.trim() : '';
  const lastName = typeof data.lastName === 'string' ? data.lastName.trim() : '';
  const joined = `${firstName} ${lastName}`.trim();
  return joined.length > 0 ? joined : null;
}

export const createStripeOnboardingLink = onRequest(
  { secrets: [stripeSecretKey], cors: false, region: 'europe-west3' },
  async (req: Request, res: Response) => {
    const origin = getCorsOrigin();
    if (applyCors(req, res, origin)) {
      return;
    }
    if (req.method !== 'POST') {
      respondMethodNotAllowed(res);
      return;
    }

    try {
      const body = parseJsonBody<{
        accountId?: string;
        account_id?: string;
        salonId?: string;
        returnUrl?: string;
        return_url?: string;
        refreshUrl?: string;
        refresh_url?: string;
      }>(req.body);

      const salonId = body.salonId;
      const explicitAccountId = body.accountId ?? body.account_id;
      const accountId = await getSalonStripeAccountId(salonId, explicitAccountId);
      if (!accountId) {
        res.status(400).json({ error: 'Stripe account id missing or salon not linked' });
        return;
      }

      const returnUrl = body.returnUrl ?? body.return_url;
      const refreshUrl = body.refreshUrl ?? body.refresh_url ?? returnUrl;

      if (!returnUrl) {
        res.status(400).json({ error: 'returnUrl is required' });
        return;
      }
      if (!refreshUrl) {
        res.status(400).json({ error: 'refreshUrl is required' });
        return;
      }

      const stripe = getStripeClient();
      const link = await stripe.accountLinks.create({
        account: accountId,
        return_url: returnUrl,
        refresh_url: refreshUrl,
        type: 'account_onboarding',
      });

      if (salonId) {
        await db
          .collection('salons')
          .doc(salonId)
          .set(
            {
              stripeAccount: {
                lastOnboardingLinkCreatedAt: FieldValue.serverTimestamp(),
              },
            },
            { merge: true },
          );
      }

      res.status(200).json({ url: link.url, expiresAt: link.expires_at, accountId });
    } catch (error) {
      if (error instanceof Stripe.errors.StripeError) {
        res.status(error.statusCode ?? 400).json({ error: error.message });
        return;
      }
      handleError(res, error);
    }
  },
);

export const createStripePaymentIntent = onRequest(
  { secrets: [stripeSecretKey], cors: false, region: 'europe-west3' },
  async (req: Request, res: Response) => {
    const origin = getCorsOrigin();
    if (applyCors(req, res, origin)) {
      return;
    }
    if (req.method !== 'POST') {
      respondMethodNotAllowed(res);
      return;
    }

    try {
      const body = parseJsonBody<{
        amount?: number | string;
        amountCents?: number | string;
        currency?: string;
        salonId?: string;
        salonStripeAccountId?: string;
        customerId?: string;
        metadata?: Record<string, unknown>;
        cartId?: string;
        clientId?: string;
        type?: string;
      }>(req.body);

      const amountValue = body.amount ?? body.amountCents;
      const amount = typeof amountValue === 'string' ? Number.parseInt(amountValue, 10) : amountValue;

      if (!Number.isInteger(amount) || (amount as number) <= 0) {
        res.status(400).json({ error: 'amount must be a positive integer (in the smallest currency unit)' });
        return;
      }

      const currency = (body.currency ?? 'eur').toLowerCase();
      const salonId = body.salonId;
      const stripeAccountId = await getSalonStripeAccountId(salonId, body.salonStripeAccountId);

      if (!stripeAccountId) {
        res.status(400).json({ error: 'salonStripeAccountId is required' });
        return;
      }

      const stripe = getStripeClient();
      const connectAccount = await stripe.accounts.retrieve(stripeAccountId);
      if (!connectAccount.charges_enabled) {
        res.status(403).json({ error: 'Connected account is not charges_enabled' });
        return;
      }

      const baseMetadata: Record<string, string> = {
        platform: getPlatformName(),
      };
      if (salonId) {
        baseMetadata.salonId = salonId;
      }
      if (body.clientId) {
        baseMetadata.clientId = body.clientId;
      }
      if (body.cartId) {
        baseMetadata.cartId = body.cartId;
      }
      if (body.type) {
        baseMetadata.type = body.type;
      }

      const metadata = toStripeMetadata(body.metadata ?? {}, baseMetadata);
      const applicationFeeAmount = getApplicationFeeAmount();

      const intent = await stripe.paymentIntents.create({
        amount: amount as number,
        currency,
        customer: body.customerId || undefined,
        automatic_payment_methods: {
          enabled: true,
        },
        on_behalf_of: stripeAccountId,
        transfer_data: {
          destination: stripeAccountId,
        },
        application_fee_amount: applicationFeeAmount > 0 ? applicationFeeAmount : undefined,
        metadata,
      });

      res.status(200).json({
        clientSecret: intent.client_secret,
        paymentIntentId: intent.id,
      });
    } catch (error) {
      if (error instanceof Stripe.errors.StripeError) {
        res.status(error.statusCode ?? 400).json({ error: error.message });
        return;
      }
      handleError(res, error);
    }
  },
);

export const createStripeEphemeralKey = onRequest(
  { secrets: [stripeSecretKey], cors: false, region: 'europe-west3' },
  async (req: Request, res: Response) => {
    const origin = getCorsOrigin();
    if (applyCors(req, res, origin)) {
      return;
    }
    if (req.method !== 'POST') {
      respondMethodNotAllowed(res);
      return;
    }

    try {
      const body = parseJsonBody<{ customerId?: string }>(req.body);
      const customerId = body.customerId;
      if (!customerId) {
        res.status(400).json({ error: 'customerId is required' });
        return;
      }
      const stripeVersion = req.header('Stripe-Version') ?? req.header('stripe-version');
      if (!stripeVersion) {
        res.status(400).json({ error: 'Stripe-Version header is required' });
        return;
      }

      const stripe = getStripeClient();
      const key = await stripe.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: stripeVersion },
      );

      res.status(200).json(key);
    } catch (error) {
      if (error instanceof Stripe.errors.StripeError) {
        res.status(error.statusCode ?? 400).json({ error: error.message });
        return;
      }
      handleError(res, error);
    }
  },
);

export const handleStripeWebhook = onRequest(
  { secrets: [stripeSecretKey, stripeWebhookSecret], cors: false, region: 'europe-west3' },
  async (req: Request, res: Response) => {
    if (req.method !== 'POST') {
      respondMethodNotAllowed(res);
      return;
    }

    try {
      const signature = req.header('stripe-signature');
      if (!signature) {
        res.status(400).send('Missing Stripe-Signature header');
        return;
      }

      const webhookSecretRaw = stripeWebhookSecret.value();
      if (!webhookSecretRaw) {
        throw new Error('Missing STRIPE_WEBHOOK_SECRET secret');
      }

      const stripe = getStripeClient();
      const rawBody = (req as Request & { rawBody: Buffer }).rawBody;
      const webhookSecrets = webhookSecretRaw
        .split(/[\s,]+/)
        .map((entry) => entry.trim())
        .filter((entry) => entry.length > 0);

      let event: Stripe.Event | null = null;
      let lastError: unknown = null;

      for (const secret of webhookSecrets) {
        try {
          event = stripe.webhooks.constructEvent(rawBody, signature, secret);
          break;
        } catch (error) {
          lastError = error;
        }
      }

      if (!event) {
        throw lastError ?? new Error('Unable to verify Stripe webhook signature');
      }

      switch (event.type) {
        case 'payment_intent.succeeded': {
          const paymentIntent = event.data.object as Stripe.PaymentIntent;
          await handlePaymentIntentSuccess(paymentIntent);
          break;
        }
        case 'payment_intent.payment_failed': {
          const paymentIntent = event.data.object as Stripe.PaymentIntent;
          await handlePaymentIntentFailure(paymentIntent);
          break;
        }
        case 'account.updated': {
          const account = event.data.object as Stripe.Account;
          await updateSalonAccountSnapshot(account);
          break;
        }
        default:
          break;
      }

      res.status(200).json({ received: true });
    } catch (error) {
      if (error instanceof Stripe.errors.StripeError) {
        console.error('Stripe webhook signature verification failed', error);
        res.status(400).send(`Webhook Error: ${error.message}`);
        return;
      }
      console.error('Stripe webhook handling error', error);
      res.status(500).send('Internal error');
    }
  },
);
