/** Backend for flutter_stripe + Connect */
import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import Stripe from 'stripe';
import admin from 'firebase-admin';

const app = express();
app.use('/stripe/webhook', express.raw({ type: 'application/json' }));
app.use(express.json());
app.use(cors());

const { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, FIREBASE_PROJECT_ID, PORT = 8080, APPLICATION_FEE_AMOUNT = 0, PLATFORM_NAME = 'CIVIAPP' } = process.env;
if (!STRIPE_SECRET_KEY) { console.error('Missing STRIPE_SECRET_KEY'); process.exit(1); }

const stripe = new Stripe(STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' });

if (FIREBASE_PROJECT_ID && !admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId: FIREBASE_PROJECT_ID });
}
const db = FIREBASE_PROJECT_ID ? admin.firestore() : null;

app.post('/connect/create-account', async (req, res) => {
  try {
    const { email, country = 'IT', business_type = 'individual' } = req.body || {};
    const account = await stripe.accounts.create({ type: 'express', country, email, business_type });
    res.json({ account });
  } catch (e) { res.status(400).json({ error: e.message }); }
});

app.post('/connect/account-link', async (req, res) => {
  try {
    const { account_id, return_url = 'https://example.com/return', refresh_url = 'https://example.com/refresh' } = req.body || {};
    const link = await stripe.accountLinks.create({ account: account_id, refresh_url, return_url, type: 'account_onboarding' });
    res.json({ url: link.url });
  } catch (e) { res.status(400).json({ error: e.message }); }
});

app.post('/payments/create-intent', async (req, res) => {
  try {
    const { amount, currency = 'eur', salonStripeAccountId, customerId, metadata } = req.body || {};
    if (!amount || !salonStripeAccountId) return res.status(400).json({ error: 'amount and salonStripeAccountId required' });

    const intent = await stripe.paymentIntents.create({
      amount, currency, customer: customerId || undefined,
      automatic_payment_methods: { enabled: true },
      on_behalf_of: salonStripeAccountId,
      transfer_data: { destination: salonStripeAccountId },
      application_fee_amount: Number(APPLICATION_FEE_AMOUNT) || undefined,
      metadata: { platform: PLATFORM_NAME, ...(metadata || {}) }
    });
    res.json({ clientSecret: intent.client_secret, paymentIntentId: intent.id });
  } catch (e) { res.status(400).json({ error: e.message }); }
});

app.post('/ephemeral-keys', async (req, res) => {
  try {
    const { customerId } = req.body || {};
    const stripeVersion = req.headers['stripe-version'];
    if (!customerId) return res.status(400).json({ error: 'customerId required' });
    if (!stripeVersion) return res.status(400).json({ error: 'Stripe-Version header required' });
    const key = await stripe.ephemeralKeys.create({ customer: customerId }, { apiVersion: stripe.getApiField('version') });
    res.json(key);
  } catch (e) { res.status(400).json({ error: e.message }); }
});

app.post('/stripe/webhook', async (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;
  try { event = stripe.webhooks.constructEvent(req.body, sig, STRIPE_WEBHOOK_SECRET); }
  catch (err) { return res.status(400).send(`Webhook Error: ${err.message}`); }

  try {
    switch (event.type) {
      case 'payment_intent.succeeded': {
        const pi = event.data.object;
        if (db) {
          const ref = db.collection('orders').doc(pi.id);
          await ref.set({
            status: 'paid', amount: pi.amount, currency: pi.currency,
            clientId: pi.metadata?.clientId || null, salonId: pi.metadata?.salonId || null, packageId: pi.metadata?.packageId || null,
            stripe: { payment_intent_id: pi.id, customer_id: pi.customer || null, charge_id: pi.latest_charge || null },
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
        }
        break;
      }
      case 'payment_intent.payment_failed': {
        const pi = event.data.object;
        if (db) {
          const ref = db.collection('orders').doc(pi.id);
          await ref.set({ status: 'failed', stripe: { payment_intent_id: pi.id } }, { merge: true });
        }
        break;
      }
      default: break;
    }
    res.json({ received: true });
  } catch (e) { res.status(500).send('Internal error'); }
});

app.get('/health', (_, res) => res.send('ok'));
app.listen(PORT, () => console.log(`Listening on :${PORT}`));
