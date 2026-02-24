# CIVIAPP – flutter_stripe + Stripe Connect (Express) – Implementation Guide

This kit gives you a minimal, production-ready baseline to accept in‑app payments with **PaymentSheet** (Apple Pay / Google Pay / Klarna) and route funds to each salon via **Stripe Connect (Express)**.

It includes:
- Flutter setup (PaymentSheet flow)
- Backend (Node/Express) endpoints: **create Express account**, **onboarding link**, **PaymentIntent** with `on_behalf_of` + `transfer_data`, **Ephemeral Keys**, **webhook**
- iOS/Android configuration checklists
- Ops & security notes
- Commands for Codex / VS Code

## Firebase Functions rollout

Stripe endpoints live in `functions/src/stripe` and are exported as HTTPS functions:
- `createStripeConnectAccount`
- `createStripeOnboardingLink`
- `createStripePaymentIntent`
- `createStripeEphemeralKey`
- `handleStripeWebhook`

### Secret Manager

Configure the secrets/parameters before deploying:
```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
firebase functions:params:set STRIPE_PLATFORM_NAME="CIVIAPP"
firebase functions:params:set STRIPE_APPLICATION_FEE_AMOUNT=0
firebase functions:params:set STRIPE_ALLOWED_ORIGIN="https://your-app.web.app"
```

If your Firebase CLI does not support `functions:params:set`, create local dotenv files instead:

```bash
cat <<'EOF' > functions/.env.<project-id>
STRIPE_PLATFORM_NAME=CIVIAPP
STRIPE_APPLICATION_FEE_AMOUNT=0
STRIPE_ALLOWED_ORIGIN=https://your-app.web.app
EOF

cat <<'EOF' > functions/.env.<project-id>.secret
STRIPE_SECRET_KEY=projects/<project-number>/secrets/STRIPE_SECRET_KEY/versions/latest
STRIPE_WEBHOOK_SECRET=projects/<project-number>/secrets/STRIPE_WEBHOOK_SECRET/versions/latest
EOF
```

Deploy after installing the new dependency:
```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

### Flutter env vars

Run the app passing the Stripe configuration via `--dart-define`:

```bash
flutter run \
  --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx \
  --dart-define=STRIPE_MERCHANT_ID=merchant.com.civiapp \
  --dart-define=STRIPE_FUNCTIONS_REGION=europe-west3 \
  --dart-define=STRIPE_MERCHANT_COUNTRY_CODE=IT
```

For local testing against a custom backend URL use:

```bash
--dart-define=STRIPE_FUNCTIONS_BASE=http://localhost:5001/civiapp-38b51/europe-west3
```
