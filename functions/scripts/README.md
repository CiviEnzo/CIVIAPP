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
