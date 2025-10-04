# CIVIAPP – Messaggistica (stato 2024)

Questa guida allinea la componente messaggistica con l'implementazione Flutter/Firebase attuale. È un promemoria per chi opera (marketing/legale) e un brief tecnico per Codex, coerente con l'architettura Riverpod già in uso nell'app.

---

## 0) Visione rapida
- Modulo `Messaggi` (lib/presentation/screens/admin/modules/messages_module.dart) consente agli admin di creare e modificare template legati al salone selezionato.
- `MessageTemplate` (lib/domain/entities/message_template.dart) definisce i campi effettivamente salvati in Firestore (`channel`: whatsapp/email/sms, `usage`: reminder/followUp/promotion/birthday, `isActive`).
- `AppDataStore` (lib/data/repositories/app_data_store.dart) sincronizza in tempo reale la collezione `message_templates` filtrando per `salonId`.
- I consensi cliente sono persistiti in `/clients/{clientId}.consents[]` come coppie `{type, acceptedAt}`; l'app oggi li legge ma non li aggiorna ancora tramite UI.
- Non esistono ancora `message_outbox`, scheduler o integrazioni push/email: la messaggistica è limitata alla gestione dei template.

## 1) Cose operative & compliance
- **Fatto**: ogni template richiede un `salonId`, mantenendo separata la comunicazione multi-salone.
- **Fatto**: la struttura dati cliente supporta tre consensi (`marketing`, `privacy`, `profilazione`) con timestamp, già serializzati da/verso Firestore.
- **Da completare**: raccolta esplicita della preferenza per canale (push/email/WhatsApp/SMS) e opt-out granulari; oggi non esiste un campo dedicato.
- **Da completare**: verifica di telefono/email durante onboarding (OTP o doppio opt-in) prima di usare canali esterni.
- **Da completare**: gestione del processo WhatsApp Business (numero dedicato, template approvati) e aggiornamento della Privacy Policy per i nuovi canali.
- **Da completare**: definizione di finestre orarie e limiti giornalieri condivisi con il team operativo.

## 2) Data model Firestore (attuale + estensioni previste)
```
/clients/{clientId}
  salonId: string
  firstName: string
  lastName: string
  phone: string
  email?: string
  consents: [
    { type: "marketing" | "privacy" | "profilazione", acceptedAt: Timestamp }
  ]
  onboardingStatus: "notSent" | "invitationSent" | "firstLogin" | "onboardingCompleted"
  invitationSentAt?: Timestamp
  firstLoginAt?: Timestamp
  onboardingCompletedAt?: Timestamp
  loyaltyPoints: number
  notes?: string

/message_templates/{templateId}
  salonId: string
  title: string
  body: string
  channel: "whatsapp" | "email" | "sms"
  usage: "reminder" | "followUp" | "promotion" | "birthday"
  isActive: bool
  // TODO: createdAt/updatedAt, placeholders[] per audit

/appointments/{appointmentId}
  salonId: string
  clientId: string
  staffId: string
  serviceId: string
  start: Timestamp
  end: Timestamp
  status: "scheduled" | "confirmed" | "completed" | "cancelled" | "noShow"

/message_outbox/{messageId}   // da introdurre
  salonId: string
  clientId: string
  templateId: string
  channel: string
  payload: map
  scheduledAt: Timestamp
  status: "pending" | "queued" | "sent" | "failed" | "skipped"
  traces: [{ at: Timestamp, event: string, info?: map }]
  rateLimitKey?: string
```
Note:
- `message_outbox` non è ancora in Firestore; va creato contestualmente al dispatcher.
- Qualsiasi campo opzionale nuovo va aggiunto in `lib/data/mappers/firestore_mappers.dart` e nei test.

## 3) Flussi applicativi attuali
- **Admin – gestione template**: dal dashboard admin (lib/presentation/screens/admin/admin_dashboard_screen.dart) il modulo `Messaggi` mostra i template del salone corrente e apre `MessageTemplateFormSheet` per creazione/modifica.
- **Data flow**: `AppDataStore` ascolta la collezione `message_templates` filtrando per gli `salonId` consentiti all'utente (`_listenCollectionBySalonIds`). Le operazioni CRUD usano `upsertTemplate` / `deleteTemplate`.
- **Clienti**: l'onboarding cliente (`lib/presentation/screens/auth/onboarding_screen.dart`) popola i dati anagrafici ma non chiede ancora consensi o preferenze canale; questi valori restano fissi a database o vengono caricati via import.
- **Notifiche in app**: non esiste ancora un centro notifiche o una tab per lo storico messaggi nel client.
- **Automazioni**: non sono configurati Cloud Scheduler o Functions; qualsiasi invio è al momento manuale / esterno.

## 4) Gap tecnici e priorità
- Modellare le preferenze canale (`channelPreferences` sul cliente) e relativo UI/admin.
- Introdurre `/message_outbox` con stato e tracciamento eventi, più rate limiting per salone/utente.
- Implementare funzioni pianificate (`createReminders`, `runCampaigns`, `birthdayGreetings`) e il dispatcher multi-canale.
- Collegare i template agli slot reali (appointment status, staff disponibile, orari).
- Gestire STOP/opt-out automatici su WhatsApp/SMS ed evitare invii fuori quiet hours.
- Preparare una dashboard di metriche (invii, fallimenti, conversioni) in area admin.
- Audit log su modifiche template e consensi.

## 5) KPI & logging (target)
- Deliverability per canale (queued → sent → delivered → read se disponibile).
- Engagement: conferme appuntamento, click email, risposte WhatsApp.
- Conversione promo: nuovi appuntamenti/vendite associate alla campagna.
- Compliance: numero opt-out per canale, versioni consenso accettate.
- Logging tecnico: `message_outbox.traces`, errori provider, payload normalizzati.

## 6) Sicurezza Firestore
Regole già presenti (`firestore.rules:319`):
```javascript
match /message_templates/{templateId} {
  allow read: if isSignedIn() && canManageSalonDocument(resourceSalonId());
  allow create, update, delete: if isSignedIn() &&
    canManageSalonDocument(
      request.resource != null && request.resource.data != null && request.resource.data.salonId is string
        ? request.resource.data.salonId
        : resourceSalonId()
    );
}
```
- Il controllo `canManageSalonDocument` limita l'accesso a admin/staff autorizzati.
- Quando verrà introdotto `/message_outbox`, replicare lo stesso pattern ma permettere `write` solo a ruoli di sistema (Cloud Functions) o admin.

## 7) Prompt Codex (aggiornati)

### A. Flutter (Riverpod, Material 3)
Struttura:
- Dominio: `lib/domain/entities/`
- Mapper & Repository: `lib/data/mappers/`, `lib/data/repositories/app_data_store.dart`
- UI: `lib/presentation/...` con widget Material 3 + Riverpod

Prompt di lavoro:
```
Aggiorna la gestione dei consensi e delle preferenze canale.
- Estendi Client con `channelPreferences` (push/email/whatsapp/sms bool) e aggiorna mappers.
- Porta le preferenze su `Client` form e `ClientDetailPage` con toggle e timestamp ultima modifica.
- Aggiorna `MessageTemplateFormSheet` per mostrare placeholder disponibili e validare canale in base alle preferenze del cliente.
- Adegua AppDataState/AppDataStore per propagare i nuovi campi senza rompere il seed mock.
Test: aggiorna eventuali mock in `lib/data/mock_data.dart` e crea widget test basilare se servono.
```

### B. Cloud Functions (TypeScript, ancora da creare)
Struttura prevista quando si attiva la messaggistica:
```
functions/
  src/
    index.ts
    messaging/
      scheduler.ts      // createReminders, runCampaigns, birthdayGreetings
      dispatcher.ts     // dispatchOutbox
      channels/
        push.ts
        email.ts
        whatsapp.ts
      webhooks/
        whatsapp.ts
    utils/
      firestore.ts
      time.ts
      consent.ts
```
Prompt:
```
Inizializza functions TypeScript per la messaggistica.
- Crea la struttura sopra con export da index.ts.
- Implementa stub di createReminders/runCampaigns/birthdayGreetings che scrivono in /message_outbox.
- dispatcher.ts legge i pending, rispetta quiet hours e aggiorna status/traces.
- channels/*.ts simulano l'invio (log + finto response), pronto per integrazioni future.
- webhook/whatsapp.ts gestisce risposta "1/2/STOP" aggiornando appuntamento o channelPreferences.
Aggiungi dipendenze: firebase-functions, firebase-admin, axios, date-fns-tz.
```

### C. Seed & tool
- Aggiorna `MockData.messageTemplates` e crea fixture per `channelPreferences`.
- Prepara script in `tool/` per reindicizzare i template o pulire l'outbox (facoltativo ma utile in dev).

## 8) Roadmap
1. **Fase 0 (completata)**: gestione template in app admin + sincronizzazione Firestore.
2. **Fase 1 (in corso)**: consensi granulari, preferenze canale, struttura `/message_outbox`.
3. **Fase 2**: Cloud Functions con scheduler/dispatcher, invio push/email, webhook opt-out.
4. **Fase 3**: Integrazione WhatsApp Business, KPI avanzati, A/B test, throttling per salone.

---

## Appendice
- Timezone di riferimento: `Europe/Rome` (gestire DST nelle funzioni).
- Placeholder raccomandati: `{{customer.firstName}}`, `{{appointment.date}}`, `{{salon.name}}`.
- Conserva i log tecnici in Firestore e Cloud Logging; evita invii diretti dal client.
- Quando si introducono nuovi canali, aggiornare contestualmente la documentazione legale e le regole di retention dati.
