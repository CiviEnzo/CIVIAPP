# Stripe configuration - YouBook

## Obiettivo

Portare live i pagamenti Stripe per YouBook usando Stripe Connect Express, in modo che ogni salone colleghi il proprio account Stripe e riceva gli incassi dei pagamenti effettuati dai clienti dall'app.

## Stato attuale integrazione

- App Flutter: Stripe viene inizializzato in `lib/main.dart` tramite `STRIPE_PUBLISHABLE_KEY`, `STRIPE_TEST_MODE` e `STRIPE_MERCHANT_ID`.
- Backend Firebase Functions: esistono gia' endpoint per:
  - creare account Stripe Connect Express;
  - generare link onboarding;
  - creare PaymentIntent;
  - creare Ephemeral Key;
  - gestire webhook Stripe;
  - finalizzare pagamenti preventivo.
- Il pagamento usa `on_behalf_of` e `transfer_data.destination`, quindi l'incasso viene instradato verso l'account Stripe del salone.
- Il backend ricalcola e valida l'importo da carrello/preventivo prima di creare il PaymentIntent.
- Il salone puo' accettare pagamenti solo se:
  - ha `stripeAccountId`;
  - `stripeAccount.chargesEnabled == true`;
  - `stripeAccount.detailsSubmitted == true`;
  - `featureFlags.clientOnlinePayments == true`.

## Checklist per andare live

### 1. Completare account Stripe piattaforma

- [ ] Completare il profilo business dell'account Stripe YouBook.
- [ ] Verificare che l'account Stripe sia in modalita' live.
- [ ] Configurare branding pubblico:
  - nome: `YOUBOOK`;
  - logo;
  - colore brand;
  - URL sito/app.
- [ ] Configurare la voce estratto conto piattaforma:
  - `YOUBOOK`;
  - abbreviata: `YOUBOOK`.
- [ ] Abilitare Stripe Connect.
- [ ] Usare account Connect di tipo Express per i saloni.

### 2. Configurare Firebase Functions production

Impostare i secret live:

```bash
firebase functions:secrets:set STRIPE_SECRET_KEY
firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
```

Valori attesi:

- [x] `STRIPE_SECRET_KEY`: secret presente su Firebase.
- [x] `STRIPE_WEBHOOK_SECRET`: secret presente su Firebase.

Impostare i parametri:

- [x] `STRIPE_PLATFORM_NAME=YOUBOOK`
- [x] `STRIPE_APPLICATION_FEE_AMOUNT=0`
- [x] `STRIPE_ALLOWED_ORIGIN=https://youbook.civiapp.it`

Note:

- `STRIPE_APPLICATION_FEE_AMOUNT` e' un importo fisso in centesimi, non una percentuale.
- Se YouBook deve trattenere una commissione, decidere prima modello fee:
  - fee fissa per transazione;
  - percentuale;
  - abbonamento esterno;
  - nessuna fee iniziale.
- Se serve una fee percentuale, il backend va modificato per calcolarla dinamicamente.

### 3. Deploy Functions

- [x] Verificare build TypeScript:

```bash
cd functions
npm run build
```

- [x] Deployare le Functions Stripe:

```bash
firebase deploy --only functions:createStripeConnectAccount,functions:createStripeDashboardLoginLink,functions:createStripeOnboardingLink,functions:createStripePaymentIntent,functions:createStripeEphemeralKey,functions:handleStripeWebhook,functions:finalizeQuotePaymentIntent,hosting
```

- [x] Verificare che le Functions siano deployate nella regione corretta:
  - endpoint Stripe principali: `europe-west3`;
  - `finalizeQuotePaymentIntent`: `europe-west1`.

### 4. Configurare webhook Stripe live

Creare un webhook live in Stripe Dashboard con endpoint:

```text
https://europe-west3-<project-id>.cloudfunctions.net/handleStripeWebhook
```

Eventi minimi da abilitare:

```text
payment_intent.succeeded
payment_intent.payment_failed
account.updated
```

Dopo la creazione:

- [ ] Copiare il signing secret `whsec_...`.
- [ ] Impostarlo in Firebase Secret Manager come `STRIPE_WEBHOOK_SECRET`.
- [ ] Ridistribuire la Function se necessario.
- [ ] Inviare un evento test dal Dashboard Stripe.
- [ ] Verificare log Firebase della Function `handleStripeWebhook`.

### 5. Sistemare configurazione Flutter live

Per build live usare:

```text
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_TEST_MODE=false
STRIPE_MERCHANT_ID=merchant.com.civiapp.youbook
STRIPE_MERCHANT_NAME=YouBook
STRIPE_MERCHANT_COUNTRY_CODE=IT
CLIENT_PURCHASES_ENABLED=true
```

Controlli:

- [x] Rimosso `pk_test_...` hardcoded da `ios/Flutter/Release.xcconfig`.
- [ ] Non usare `pk_test_...` in build production.
- [ ] Non lasciare `STRIPE_TEST_MODE=true` in production.
- [ ] Abilitare `CLIENT_PURCHASES_ENABLED=true`.
- [x] Verificare `tool/dart_defines.json` reale, non solo `.example`.
- [x] Rimuovere o sostituire il `DART_DEFINES` test hardcoded in `ios/Flutter/Release.xcconfig`.

Nota importante:

`ios/Flutter/Release.xcconfig` non contiene piu' una configurazione Stripe test hardcoded. La chiave Stripe release deve arrivare dalla pipeline di build o dal comando `flutter build` tramite dart define.

### 6. Configurare Apple Pay

Necessario se si vuole mostrare Apple Pay nella PaymentSheet.

- [x] Creare/abilitare Merchant ID Apple:
  - `merchant.com.civiapp.youbook`
- [ ] Collegare il Merchant ID a Stripe Dashboard.
- [x] Abilitare Apple Pay nel progetto iOS.
- [x] Aggiungere negli entitlements iOS:

```xml
<key>com.apple.developer.in-app-payments</key>
<array>
  <string>merchant.com.civiapp.youbook</string>
</array>
```

File da controllare:

- `ios/Runner/RunnerDebug.entitlements`
- `ios/Runner/RunnerProfile.entitlements`
- `ios/Runner/RunnerRelease.entitlements`

Stato attuale:

- Gli entitlements contengono `merchant.com.civiapp.youbook`.
- Resta da completare/validare il collegamento Apple Pay nel Dashboard Stripe.

### 7. Configurare Google Pay

- [ ] Verificare configurazione Google Pay in Stripe.
- [ ] Verificare che `STRIPE_TEST_MODE=false` in production.
- [ ] Testare PaymentSheet su Android reale.
- [ ] Verificare che il paese merchant sia `IT`.

### 8. Sistemare URL onboarding saloni

Nel codice admin ci sono URL hardcoded per return/refresh onboarding.

Da uniformare a dominio live YouBook:

```text
https://youbook.civiapp.it/stripe-success
https://youbook.civiapp.it/stripe/onboarding/retry
```

Azioni:

- [x] Aggiornare `returnUrl`.
- [x] Aggiornare `refreshUrl`.
- [x] Creare pagine web minime per:
  - onboarding completato;
  - onboarding da riprovare.
- [x] Deployare le rewrite Hosting.

### 9. Migliorare bottone Dashboard Stripe

Stato attuale:

- Se l'account esiste, il bottone mostra `Dashboard`, ma genera ancora un onboarding link.

Da decidere:

- [x] Se l'account non e' completo: generare onboarding link.
- [x] Se l'account e' completo: generare login link Express Dashboard.

Endpoint backend aggiunto:

```ts
stripe.accounts.createLoginLink(accountId)
```

### 10. Flusso salone

Per ogni salone:

- [ ] Admin apre modulo gestione salone.
- [ ] Clicca `Configura` su Stripe.
- [ ] Inserisce email e tipo business:
  - `individual`;
  - `company`.
- [ ] YouBook crea account Express.
- [ ] Admin/salone completa onboarding Stripe.
- [ ] Webhook `account.updated` aggiorna Firestore.
- [ ] Verificare su Firestore:
  - `salons/{salonId}.stripeAccountId`;
  - `stripeAccount.chargesEnabled`;
  - `stripeAccount.payoutsEnabled`;
  - `stripeAccount.detailsSubmitted`;
  - `featureFlags.clientOnlinePayments`.
- [ ] Abilitare pagamenti online per il salone.

### 11. Test end-to-end prima del live

Test in modalita' test:

- [ ] Creare salone test.
- [ ] Collegare account Connect Express test.
- [ ] Completare onboarding test.
- [ ] Pagare un carrello cliente.
- [ ] Pagare un preventivo cliente.
- [ ] Pagare uno slot last-minute.
- [ ] Verificare creazione documenti:
  - `orders`;
  - `sales`;
  - `cash_flows`;
  - `carts`;
  - eventuale `appointments`;
  - eventuale `payment_tickets`.
- [ ] Verificare che il PaymentIntent sia arrivato sull'account salone collegato.
- [ ] Verificare che il webhook aggiorni correttamente Firestore.
- [ ] Simulare pagamento fallito.
- [ ] Simulare account Connect aggiornato.

Test live controllato:

- [ ] Creare un salone pilota reale.
- [ ] Collegare account Stripe reale del salone.
- [ ] Fare pagamento reale di importo minimo.
- [ ] Verificare incasso e trasferimento verso account salone.
- [ ] Verificare ricevuta cliente.
- [ ] Verificare comparsa in vendite/cassa YouBook.
- [ ] Verificare rimborso dal Dashboard Stripe.

### 12. Verifiche tecniche finali

- [x] `npm run build` in `functions`.
- [x] `flutter build web --dart-define-from-file=tool/dart_defines.json`.
- [ ] `flutter analyze` e valutazione warning bloccanti.
- [ ] Build Android release con dart defines live.
- [ ] Build iOS release con dart defines live.
- [ ] Test su dispositivo iOS reale.
- [ ] Test su dispositivo Android reale.
- [ ] Controllo log Firebase Functions.
- [ ] Controllo log Stripe webhook.

## Rischi aperti

- Collegamento Apple Pay da validare nel Dashboard Stripe.
- Il file locale `tool/dart_defines.json` contiene ancora placeholder per `STRIPE_PUBLISHABLE_KEY`.
- La fee piattaforma e' solo fissa; se serve percentuale va implementata.
- Stripe non e' disponibile su web: attualmente i pagamenti sono solo mobile.
- Runtime Cloud Functions `nodejs20` e' deprecato dal 2026-04-30 e andra' aggiornato prima del 2026-10-30.

## Priorita' immediata

1. Inserire la `pk_live_...` in configurazione build mobile release.
2. Impostare `STRIPE_TEST_MODE=false` e `CLIENT_PURCHASES_ENABLED=true` per la build live.
3. Collegare Apple Pay Merchant ID nel Dashboard Stripe.
4. Verificare webhook live Stripe dal Dashboard Stripe.
5. Fare test end-to-end in test mode.
6. Fare un pagamento live pilota con un salone reale.
7. Pianificare upgrade runtime Functions da Node.js 20.
