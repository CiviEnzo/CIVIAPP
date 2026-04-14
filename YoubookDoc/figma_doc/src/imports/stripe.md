# Stripe (YouBook) - Stato, hardening e da fare per produzione

## Stato attuale (aggiornato)
- Integrazione mobile Flutter con `flutter_stripe` (PaymentSheet).
- Backend Firebase Functions con Stripe Connect Express:
  - creazione account Connect
  - onboarding link
  - creazione PaymentIntent (Connect `on_behalf_of` + `transfer_data`)
  - ephemeral key
  - webhook Stripe
- Gestione webhook con scrittura su Firestore (ordini, vendite, quote, cash flow, sync stato account).

## Patch applicate (questa attività)

### 1) Hardening produzione (backend + client)
- Aggiunta autenticazione Firebase (`Authorization: Bearer <idToken>`) alle chiamate Stripe dal client.
- Protezione endpoint Stripe `onRequest`:
  - `createStripeConnectAccount` -> richiede admin del salone
  - `createStripeOnboardingLink` -> richiede admin del salone
  - `createStripePaymentIntent` -> richiede client autenticato proprietario del `clientId`
  - `createStripeEphemeralKey` -> richiede client autenticato proprietario del `clientId`
- Validazione importi lato server per `PaymentIntent`:
  - carrello: totale ricalcolato da Firestore (`carts`)
  - preventivo: totale verificato da Firestore (`quotes`)
  - se importo richiesto != importo server -> errore
- Verifica ownership `customerId`:
  - il `customerId` Stripe deve corrispondere al `stripeCustomerId` del `clientId` su Firestore
- Idempotency su `paymentIntents.create(...)` con `idempotencyKey` stabile (cart/quote + account + amount + currency).
- Verifica coerenza `salonStripeAccountId` vs account Stripe salvato sul salone (se mismatch -> errore).

### 2) UX/Admin Stripe Connect (individual/company)
- La creazione account Stripe Connect ora chiede:
  - email
  - tipo soggetto (`individual` / `company`)
- Il valore viene inviato al backend e validato.

## Da fare prima del go-live (checklist)

### Bloccanti
- Rimuovere la chiave Stripe test da `ios/Flutter/Release.xcconfig` (attualmente c'è una `pk_test` codificata).
- Impostare chiavi **Live**:
  - `STRIPE_SECRET_KEY` (Secret Manager)
  - `STRIPE_WEBHOOK_SECRET` (Secret Manager)
  - `STRIPE_PUBLISHABLE_KEY` (dart-define release)
  - `STRIPE_TEST_MODE=false` (release)
- Configurare `STRIPE_ALLOWED_ORIGIN` con dominio reale (evitare `*` in produzione).
- Configurare webhook Stripe in dashboard verso `handleStripeWebhook` (evento almeno):
  - `payment_intent.succeeded`
  - `payment_intent.payment_failed`
  - `account.updated`

### Consigliato (alta priorità)
- Aggiungere test automatici per:
  - validazione amount cart/quote
  - ownership `customerId`
  - permessi admin/client sugli endpoint
  - idempotency / retry
- Aggiungere logging strutturato per audit (esito auth, mismatch amount, mismatch account).
- Verificare regole Firestore per `carts` e `quotes` (evitare manipolazioni lato client su campi sensibili).
- Valutare retry/riuso esplicito del PaymentIntent in caso di timeout rete lato app (oltre all'idempotency).

### Config mobile / pagamenti
- Verificare Apple Pay (`merchant id`, capability, certificati) e Google Pay (merchant profile) in ambiente live.
- Allineare `tool/dart_defines.json.example` con tutte le define Stripe usate dal codice:
  - `STRIPE_FUNCTIONS_REGION`
  - `STRIPE_FUNCTIONS_BASE` (solo dev)
  - `STRIPE_MERCHANT_COUNTRY_CODE`
  - `STRIPE_MERCHANT_NAME`

### Operativo / fiscale (Italia)
- Confermare con commercialista:
  - modello contrattuale piattaforma-salone
  - fatturazione commissioni piattaforma
  - necessità/gestione Partita IVA per i soggetti che vendono in modo abituale
- In pratica, per saloni e operatività continuativa in produzione la P.IVA è normalmente necessaria.

## File principali coinvolti
- `functions/src/stripe/routes.ts`
- `functions/src/stripe/config.ts`
- `lib/services/payments/stripe_payments_service.dart`
- `lib/services/payments/stripe_connect_service.dart`
- `lib/presentation/screens/admin/modules/salon_management_module.dart`
- `functions/.env.example`
