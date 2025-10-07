/**
 * Stripe Webhook Listener (Express)
 * - Verifies Stripe signature
 * - Persists orders to Firestore
 * - Hooks for Italy e-invoice submission
 */
import 'dotenv/config';
import express from 'express';
import Stripe from 'stripe';
import admin from 'firebase-admin';

// ---- ENV
const {
  STRIPE_SECRET_KEY,
  STRIPE_WEBHOOK_SECRET,
  GOOGLE_APPLICATION_CREDENTIALS,
  FIREBASE_PROJECT_ID,
  PORT = 8080
} = process.env;

if (!STRIPE_SECRET_KEY || !STRIPE_WEBHOOK_SECRET) {
  console.error('Missing STRIPE_SECRET_KEY or STRIPE_WEBHOOK_SECRET in env');
  process.exit(1);
}

const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' });

// ---- Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: FIREBASE_PROJECT_ID
  });
}
const db = admin.firestore();

const app = express();

// Stripe requires the raw body to validate signatures
app.post('/stripe/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    console.error('⚠️  Webhook signature verification failed.', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object;
        await handleCheckoutCompleted(session);
        break;
      }
      case 'payment_intent.succeeded': {
        const pi = event.data.object;
        await handlePaymentIntentSucceeded(pi);
        break;
      }
      case 'charge.refunded': {
        const charge = event.data.object;
        await handleChargeRefunded(charge);
        break;
      }
      default:
        console.log(`Unhandled event type ${event.type}`);
    }
    res.json({ received: true });
  } catch (e) {
    console.error('Webhook handler error', e);
    res.status(500).send('Internal error');
  }
});

async function handleCheckoutCompleted(session) {
  // Extract safe fields
  const { id, payment_intent, customer_details, amount_total, currency, payment_link } = session;

  // Optional: product lines via expanded API call if needed
  // const lineItems = await stripe.checkout.sessions.listLineItems(id);

  const orderRef = db.collection('orders').doc(id);
  const payload = {
    source: 'payment_link',
    status: 'paid',
    salonId: session?.metadata?.salonId || null,
    amount_total,
    currency,
    customer_email: customer_details?.email || null,
    stripe: {
      checkout_session_id: id,
      payment_intent_id: typeof payment_intent === 'string' ? payment_intent : payment_intent?.id,
      payment_link_id: payment_link || null
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) {
      tx.set(orderRef, payload);
    }
  });

  // TODO: fulfillment (credit packages, confirm appointment, send email)
  // TODO: if IT → call e-invoice provider and store protocol numbers
}

async function handlePaymentIntentSucceeded(pi) {
  const orderRef = db.collection('orders').doc(pi.id);
  const payload = {
    source: 'payment_link',
    status: 'paid',
    amount_total: pi.amount,
    currency: pi.currency,
    stripe: {
      payment_intent_id: pi.id,
      charge_id: pi.latest_charge || null
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) {
      tx.set(orderRef, payload);
    } else {
      tx.update(orderRef, { status: 'paid' });
    }
  });
}

async function handleChargeRefunded(charge) {
  const orderRef = db.collection('orders').doc(charge.payment_intent);
  await orderRef.set(
    {
      status: 'refunded',
      stripe: {
        refund_ids: admin.firestore.FieldValue.arrayUnion(
          ...(charge.refunds?.data?.map(r => r.id) || [])
        )
      }
    },
    { merge: true }
  );
}

app.get('/health', (req, res) => res.send('ok'));

app.listen(PORT, () => {
  console.log(`Webhook server listening on :${PORT}`);
  console.log('POST /stripe/webhook to receive events');
});
