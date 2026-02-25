# WhatsApp Business - Piano operativo (OAuth + setup Meta/WABA)

## Obiettivo
- Consentire agli admin del salone di collegare il proprio account WhatsApp Business (WABA) tramite OAuth.
- Salvare in modo sicuro configurazione e token per salone.
- Abilitare invio template reminder e, in fase successiva, gestione lead con risposte automatiche.

## Stato attuale (gia presente nel progetto)
- Esiste un modulo admin WhatsApp con tab `Impostazioni`, `Template`, `Campagne`.
- Esistono Cloud Functions per:
  - avvio OAuth (`startWhatsappOAuth`)
  - callback OAuth (`handleWhatsappOAuthCallback`)
  - sync onboarding da codice OAuth (`syncWhatsappOAuth`)
  - invio template (`sendWhatsappTemplate`)
  - webhook WhatsApp (`onWhatsappWebhook`)
- Esiste dispatcher schedulato per `message_outbox` canale `whatsapp`.

## Priorita 1 - OAuth (da fare adesso)

### 1) Hardening sicurezza endpoint OAuth
- [ ] Proteggere `startWhatsappOAuth` con autenticazione Firebase (ID token) e verifica ruolo admin del salone.
- [ ] Verificare che l'utente autenticato sia autorizzato sul `salonId` richiesto.
- [ ] Non accettare `salonId` anonimo da query senza controllo server-side.
- [ ] Limitare `returnTo` / `successRedirect` a una allowlist di domini (`civiapp.app`, staging).

### 2) Gestione `state` OAuth robusta
- [ ] Sostituire il `state` solo-base64 con `state` firmato oppure `nonce` server-side (Firestore) con TTL.
- [ ] Salvare sessione OAuth in `salons/{salonId}/integrations/whatsapp_oauth_sessions/{sessionId}` con:
  - `requestedByUserId`
  - `salonId`
  - `createdAt`
  - `expiresAt`
  - `status` (`started`, `callback_received`, `processed`, `error`)
- [ ] Validare in callback che `state` non sia scaduto e non sia riutilizzato (anti replay).

### 3) Callback OAuth e tracciamento stato
- [ ] In `handleWhatsappOAuthCallback` salvare esito piu esplicito (`error`, `errorDescription`, `callbackAt`).
- [ ] Migliorare pagina di callback con messaggio chiaro per admin (successo / errore / prossimi passi).
- [ ] Mostrare stato onboarding nel tab `Impostazioni` (es. `In attesa`, `Sincronizzato`, `Errore`).

### 4) Onboarding token/WABA post-callback
- [ ] In `syncWhatsappOAuth` aggiungere generazione/salvataggio `verifyTokenSecretId` se manteniamo token per salone.
- [x] Strategia token scelta per ora: **Opzione A**
  - usare token utente ottenuto via OAuth e gestire refresh/ricollegamento
  - nota: pianificare monitoraggio scadenza (`tokenExpiresAt`) e UX di ricollegamento
- [ ] Salvare anche metadati utili per audit:
  - `connectedByUserId`
  - `connectedByEmail`
  - `graphApiVersion`
  - `tokenExpiresAt` (calcolato)

### 5) Protezione endpoint invio (bloccante produzione)
- [ ] Proteggere `sendWhatsappTemplate` con auth + autorizzazione salon admin / backend trusted.
- [ ] Evitare endpoint pubblico con solo `salonId` nel body.
- [ ] Aggiungere rate limit / abuse guard per invio manuale preview.

### 6) Webhook sicurezza (bloccante produzione)
- [ ] Validare firma webhook Meta (`X-Hub-Signature-256`) nel `POST`.
- [ ] Loggare e scartare payload non firmati/non validi.
- [ ] Verificare strategia `verify_token`:
  - per il modello attuale (app unica multi-tenant) e sufficiente un verify token globale di app
  - il supporto per `verifyTokenSecretId` per salone va chiarito/semplificato se non serve

## Cosa fare su Meta / WABA (configurazione esterna)

### A) Prerequisiti lato salone (prima del collegamento)
- [ ] Il titolare/admin del salone deve essere admin del proprio Meta Business Manager.
- [ ] Deve avere accesso al WhatsApp Business Account (WABA) relativo al salone.
- [ ] Deve avere accesso al numero da collegare (SMS o chiamata per verifica, se richiesta).
- [ ] Attivare 2FA sugli account admin Meta (raccomandato / spesso richiesto).

### B) Meta Business Manager (Business portfolio)
- [ ] Verificare il Business (Business Verification) se si vuole andare in produzione con volumi e template reali.
- [ ] Associare persone/ruoli corretti al business del salone.
- [ ] Verificare stato del numero, quality rating e limiti di messaggistica in WhatsApp Manager.

### C) Meta Developer App (app unica CiviApp)
- [ ] Creare o confermare una Meta App di tipo Business (app piattaforma).
- [ ] Aggiungere il prodotto WhatsApp alla Meta App.
- [ ] Configurare `App ID` e `App Secret` (poi copiarli in Firebase Secrets).
- [ ] Configurare OAuth redirect URI esatti usati dal progetto:
  - `https://civiapp.app/oauth/whatsapp/callback` (Opzione A con Hosting/rewrite)
  - `https://europe-west1-civiapp-38b51.cloudfunctions.net/handleWhatsappOAuthCallback` (Opzione B temporanea senza Hosting)
  - eventuale staging (es. `https://staging.../oauth/whatsapp/callback`)
- [ ] Configurare domini app (`civiapp.app`, staging) se richiesto da Meta Login/OAuth.
- [ ] Configurare URL policy/privacy/termini/dati (se richiesti da review).
- [ ] Richiedere e ottenere i permessi necessari per produzione:
  - `whatsapp_business_management`
  - `whatsapp_business_messaging`

### D) WABA / WhatsApp Manager (per ogni salone)
- [ ] Verificare che il salone abbia un WABA attivo e il numero sia presente nel WABA corretto.
- [ ] Configurare display name del numero e completare eventuali approvazioni.
- [ ] Verificare il numero (se non gia verificato).
- [ ] Controllare che il numero non sia bloccato o con limitazioni di qualita.
- [ ] Preparare template approvati per reminder (esempi minimi):
  - `appointment_reminder_it_v1`
  - `appointment_confirmation_it_v1`
  - `new_lead_ack_it_v1` (fase lead/autoreply)

### E) Webhook Meta (app-level)
- [ ] Configurare callback URL verso funzione webhook (diretto o tramite rewrite Hosting).
- [ ] Impostare il verify token scelto (globale app oppure strategia per-salone da definire).
- [ ] Completare verifica `hub.challenge`.
- [ ] Sottoscrivere i campi webhook necessari (almeno messaggi e status).
- [ ] Verificare che gli eventi del numero arrivino alla callback dopo il collegamento WABA.

## Configurazioni Firebase / GCP / Hosting (da fare)

### Firebase Functions / Secrets
- [ ] Impostare secrets:
  - `WA_APP_ID`
  - `WA_APP_SECRET`
- [ ] Verificare env/config:
  - `WA_REGION`
  - `WA_OAUTH_REDIRECT`
  - `WA_OAUTH_SCOPES`
  - `WA_SUCCESS_REDIRECT`
  - `WA_VERIFY_TOKEN` (se globale)
  - `WA_TOKEN_SECRET_PREFIX`

### GCP Secret Manager / IAM
- [ ] Verificare permessi runtime Functions per leggere/scrivere Secret Manager.
- [ ] Verificare naming e lifecycle dei secret per salone (`wa-salon-...`).

### Firebase Hosting (se callback via dominio app)
- [ ] Verificare rewrite `https://civiapp.app/oauth/whatsapp/callback` -> `handleWhatsappOAuthCallback`.
  - non necessario finché si usa temporaneamente Opzione B (callback diretta `cloudfunctions.net`)
- [ ] Verificare rewrite/route webhook se esposto dietro dominio custom (opzionale).

### Deploy funzioni coinvolte (minimo)
- [ ] `startWhatsappOAuth`
- [ ] `handleWhatsappOAuthCallback`
- [ ] `syncWhatsappOAuth`
- [ ] `onWhatsappWebhook`
- [ ] `sendWhatsappTemplate`
- [ ] `dispatchWhatsAppOutbox`

## Adeguamenti applicativi subito dopo OAuth (necessari per reminder)
- [ ] Mappare esplicitamente `Meta template name` nel modello `MessageTemplate` (oggi si usa `doc.id`, rischio mismatch).
- [ ] Aggiungere test "Invia anteprima" con template Meta reale approvato.
- [ ] Mostrare nel backoffice stato connessione completo:
  - WABA ID
  - Phone Number ID
  - numero visualizzato
  - data collegamento
  - esito ultimo test invio

## Fase successiva (non-OAuth) - Reminder e Lead

### Reminder WhatsApp automatici
- [ ] Generare entry `message_outbox` con `channel: whatsapp` dagli scheduler reminder.
- [ ] Selezionare canale in base a `channelPreferences.whatsapp`.
- [ ] Usare template approvati (non testo libero).
- [ ] Gestire quiet hours e fallback (push/email) se WhatsApp non disponibile.

### Lead e risposte automatiche (inbound)
- [ ] Aggiungere processor per `salons/{salonId}/message_inbox`.
- [ ] Regole base:
  - messaggio nuovo da numero sconosciuto -> crea lead
  - primo messaggio fuori orario -> auto reply template / testo consentito
  - routing a salone/staff
- [ ] Gestire opt-out / STOP e consenso marketing separato.

## Sequenza operativa consigliata (ordine pratico)
1. Hardening endpoint OAuth + `state` + auth admin.
2. Verifica callback domain/rewrite (`/oauth/whatsapp/callback`).
3. Config Meta App (redirect URI + permessi).
4. Test collegamento con 1 salone pilota.
5. Config webhook Meta e verifica ricezione eventi.
6. Protezione `sendWhatsappTemplate` + test invio template approvato.
7. Mappatura template Meta nel backoffice.
8. Integrazione reminder automatici su `message_outbox` WhatsApp.
9. Processor inbound per lead/autoreply.

## Test di accettazione OAuth (check rapido)
- [ ] Admin salone clicca "Collega WhatsApp" e si apre browser.
- [ ] Login Meta + consenso completati.
- [ ] Callback salva codice OAuth.
- [ ] Trigger `syncWhatsappOAuth` salva `businessId`, `wabaId`, `phoneNumberId`, `tokenSecretId`.
- [ ] UI backoffice mostra stato `Collegato`.
- [ ] Invio anteprima template restituisce `messageId`.
- [ ] Webhook riceve almeno `status` del messaggio inviato.

## Note aperte da decidere
- [ ] Verify token webhook: globale app (consigliato per app unica) vs per-salone.
- [ ] Strategia token a lungo termine (refresh/ricollegamento).
- [ ] Se adottare in futuro Meta Embedded Signup (UX migliore) invece del solo OAuth attuale.
