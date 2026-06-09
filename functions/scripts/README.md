\# Firestore sync tools

Questo script consente di allineare rapidamente i saloni pilota con i nuovi flag di feature e le collezioni `promotions` / `last_minute_slots` richieste dalla dashboard cliente.

## Requisiti

1. **Credenziali**: imposta la variabile `GOOGLE_APPLICATION_CREDENTIALS` verso un service account con permessi `cloud.firestore` oppure esegui `gcloud auth application-default login`.
2. **Dipendenze**: sfrutta `firebase-admin` già installato nelle Functions, quindi non servono installazioni aggiuntive.

## Esecuzione

```bash
node functions/scripts/sync_pilot_salons.js --config=functions/scripts/pilot_salons.example.json
```

Aggiungi `--dryRun` per vedere le operazioni senza applicarle.

### Configurazione

Il file JSON accetta un array `salons`, ciascuno con:

- `id`: ID del documento in `salons/{id}`.
- `featureFlags`: oggetto con `clientPromotions` e `clientLastMinute` (altri flag opzionali).
- `promotions`: elenco di documenti da creare (sovrascrive quelli esistenti per quel salone).
- `lastMinuteSlots`: elenco di slot last-minute (anche questo sostituisce i precedenti).

Campi data (`startsAt`, `endsAt`, `startAt`, `windowStart`, `windowEnd`, ecc.) vanno espressi come ISO string (es. `2024-10-05T18:30:00+02:00`).

### Esempio

Vedi `pilot_salons.example.json` per un template precompilato che puoi adattare ai tuoi saloni pilota.

## Output

Lo script aggiorna:

- `salons/{id}` con `featureFlags` (merge)
- Tutti i documenti `promotions` e `last_minute_slots` filtrati su `salonId`

Con `--dryRun` vengono soltanto loggate le operazioni che verrebbero eseguite.

---

## Provisioning admin salone

Per creare in modo sistematico un admin salone con utente Firebase Auth, documento `/users/{uid}`, documento `/salons/{salonId}` e checklist iniziale:

```bash
node functions/scripts/provision_salon_admin.js --config=functions/scripts/provision_salon_admin.example.json --dryRun
node functions/scripts/provision_salon_admin.js --config=functions/scripts/provision_salon_admin.example.json
```

Se l'Admin SDK non riesce a determinare il progetto, passa il project ID esplicitamente:

```bash
node functions/scripts/provision_salon_admin.js --projectId=civiapp-38b51 --config=functions/scripts/provision_salon_admin.example.json --dryRun
```

Oppure tramite npm:

```bash
npm --prefix functions run provision:salon-admin -- --config=functions/scripts/provision_salon_admin.example.json --dryRun
npm --prefix functions run provision:salon-admin -- --config=functions/scripts/provision_salon_admin.example.json
```

Prima copia `provision_salon_admin.example.json` in un file locale non tracciato, sostituisci email, password temporanea e dati salone, poi esegui sempre il `--dryRun`.
cp functions/scripts/provision_salon_admin.example.json /tmp/provision_salon_admin.json
e poi
node functions/scripts/provision_salon_admin.js --config=/tmp/provision_salon_admin.json


Per evitare sovrascritture accidentali, lo script non usa un `salonId` fisso: parte da `salon.idBase` o, se manca, da `salon.id`/`salon.name`, e aggiunge sempre un suffisso data+ora nel formato `yyyyMMdd_HHmmss`. Esempio: `salon_civi_20260605_143012`.

Nel JSON usa quindi preferibilmente:

```json
"salon": {
  "idBase": "salon_civi",
  "name": "Salone Mario Rossi"
}
```

Lo script:

- crea o recupera l'utente in Firebase Authentication;
- imposta la password temporanea solo se l'utente Auth non esiste;
- con `--forcePassword` aggiorna la password anche se l'utente Auth esiste gia';
- crea o aggiorna `salons/{salonId}`;
- crea o aggiorna `users/{uid}` con ruolo admin, `salonIds`, `enabled` e `mustChangePassword`;
- crea `salon_setup_progress/{salonId}` se manca;
- crea `salons/{salonId}/settings/reminders` se manca;
- crea/aggiorna i ruoli staff globali di default (`manager`, `receptionist`, `estetista`, ecc.);
- sincronizza direttamente le custom claims, salvo flag `--skipClaims`.

Campi minimi del JSON:

- `admin.email`
- `admin.displayName`
- `admin.temporaryPassword`
- `salon.name`
- `salon.address`
- `salon.city`
- `salon.phone`
- `salon.email`

Non committare file reali con password temporanee.

---

## Backfill setup saloni esistenti

Quando dobbiamo migrare saloni già attivi al nuovo flusso di onboarding (card checklist + reminder dashboard) usa:

```bash
node functions/scripts/backfill_salon_setup_progress.js [--salonIds=salon-001,salon-002] [--dryRun] [--force]
```

Lo script:

- legge tutti i documenti `salons` (o solo quelli indicati)
- calcola lo stato delle voci di checklist a partire dai dati esistenti
- scrive/aggiorna `salons/{id}.setupChecklist`
- crea o aggiorna `salon_setup_progress/{id}` con gli item, il reminder e i metadati

Flag utili:

- `--dryRun` mostra le modifiche senza applicarle.
- `--force` sovrascrive anche i saloni già configurati (di default vengono saltati).

## Backfill createdAt/city clienti

Per normalizzare i documenti `clients` aggiungendo `createdAt` dove mancante e valorizzando `city` a partire da dati esistenti usa:

```bash
node functions/scripts/backfill_clients_created_at_city.js [--salonIds=salon-001,salon-002] [--clientIds=client-001,client-002] [--batchSize=500] [--dryRun]
```

Parametri utili:

- `--salonIds`: limita l'esecuzione ai clienti dei saloni indicati.
- `--clientIds`: processa solo gli ID specificati (salta l'iterazione completa).
- `--batchSize`: numero di documenti letti per batch (default 500).
- `--dryRun`: logga gli aggiornamenti senza scriverli su Firestore.
