# CiviApp — Hybrid Reminders (Cloud Tasks + Scheduler)

**Goal:** Deliver reliable reminders for salon appointments using **Cloud Tasks** for punctual notifications and a **Cloud Scheduler** sweeper as safety net. Reminder offsets are configurable by each salon admin while respecting the Cloud Tasks scheduling window.

> Stack: Firebase Functions v2 (Node 20, TypeScript), Firestore, FCM (o e-mail/WhatsApp), Cloud Tasks, Cloud Scheduler.  
> Timezone: memorizza gli orari in **UTC**; mostra in **Europe/Rome** su client e messaggi.

---

## 1) Firestore data model & reminder settings

```
/salons/{salonId}
  name                : string
  ...

/salons/{salonId}/settings/reminders
  offsets: [
    {
      id             : "T24H",        // slug stabile deciso dall'admin
      minutesBefore  : 1440,          // 24 ore prima dello start
      active         : true,
      title          : "Promemoria 24h", // opzionale, usato per copy
      bodyTemplate   : "Ci vediamo domani alle {{time}}"
    },
    ...
  ]
  updatedAt          : serverTimestamp

/salons/{salonId}/appointments/{appointmentId}
  customerUid        : string
  startAt            : Timestamp (UTC)
  title              : string
  cancelled          : boolean
  updatedAt          : serverTimestamp
  reminder_T24H_sent : boolean
  reminder_T3H_sent  : boolean
  reminder_T30M_sent : boolean
  deviceToken        : string | null
  whatsappPhone      : string | null
  email              : string | null
```

- Gli slug (`id`) devono essere alfanumerici per poter comporre il flag `reminder_{id}_sent`.  
- L’UI admin deve impedire configurazioni oltre i **30 giorni** prima dell’appuntamento perché non schedulabili su Cloud Tasks.

---

## 2) Project setup

```bash
# Nella cartella functions/
npm i firebase-admin firebase-functions
npm i -D typescript ts-node @types/node

# SDK provider (WhatsApp, e-mail, ecc.) se necessari

# Se manca la configurazione TypeScript
npx tsc --init

# Opzionale, se il progetto usa gli experiment webframeworks
firebase experiments:enable webframeworks
```

**`tsconfig.json` (estratto)**
```jsonc
{
  "compilerOptions": {
    "target": "es2022",
    "lib": ["es2022"],
    "module": "es2022",
    "moduleResolution": "node",
    "strict": true,
    "outDir": "lib",
    "sourceMap": true
  },
  "include": ["src"]
}
```

**`package.json` (scripts suggeriti)**
```jsonc
{
  "engines": { "node": ">=20" },
  "scripts": {
    "build": "tsc -p .",
    "serve": "firebase emulators:start",
    "deploy": "firebase deploy --only functions",
    "lint": "eslint ."
  }
}
```

**`firebase.json`**
```jsonc
{
  "functions": {
    "source": "functions",
    "runtime": "nodejs20"
  }
}
```

> **Billing obbligatoria** per Cloud Tasks e Cloud Scheduler. Usare un progetto di staging per i test end-to-end.

---

## 3) Offsets gestiti dall’admin & checkpoint < 30 giorni

- Ogni salone gestisce le proprie finestre di reminder tramite il documento `settings/reminders`.  
- Gli offset sono espressi in minuti prima dell’inizio (`minutesBefore > 0`).  
- Cloud Tasks può schedulare al massimo **30 giorni** in anticipo: tutti gli offset vengono quindi clampati a 30d (43200 minuti).
- Se il documento non esiste o non contiene offset attivi, non viene inviato alcun promemoria: serve un salvataggio esplicito da parte dell’admin.

**Strategia:**

1. Quando un appuntamento è creato/aggiornato, carichiamo gli offset del salone.
2. Se `startAt - now > 30 giorni`, scheduliamo una **CHECKPOINT task** a `startAt - 30d`.
3. Alla partenza della CHECKPOINT (o se l’appuntamento è già entro i 30 giorni), pianifichiamo i reminder effettivi sui Cloud Tasks.
4. Una funzione schedulata (sweeper) ogni 15 minuti analizza gli appuntamenti entro 30 giorni e si assicura che le task esistano (rete di sicurezza).

---

## 4) Functions code (TypeScript)

File: `functions/src/reminders.ts`

```ts
import * as admin from "firebase-admin";
import {
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import {
  onTaskDispatched,
  TaskContext,
  enqueue as enqueueTask,
} from "firebase-functions/v2/tasks";
import { onSchedule } from "firebase-functions/v2/scheduler";

admin.initializeApp();

// ---------- Config ----------
const REGION = "europe-west1";
const MAX_AHEAD_MS = 30 * 24 * 60 * 60 * 1000;

type ReminderConfig = {
  id: string;
  minutesBefore: number;
  active?: boolean;
  title?: string;
  bodyTemplate?: string;
};

type ReminderPayload = {
  salonId: string;
  appointmentId: string;
  offsetId: string | "CHECKPOINT";
};

// ---------- Helpers ----------
function nowMs() {
  return Date.now();
}

function toDate(ms: number) {
  return new Date(ms);
}

function keyForOffset(id: string) {
  return `reminder_${id}_sent`;
}

function sentFlag(appt: FirebaseFirestore.DocumentData, id: string) {
  return Boolean(appt[keyForOffset(id)]);
}

function isCancelled(appt: FirebaseFirestore.DocumentData) {
  return Boolean(appt.cancelled);
}

async function loadReminderOffsets(salonId: string): Promise<ReminderConfig[]> {
  const snap = await admin.firestore()
    .doc(`salons/${salonId}/settings/reminders`)
    .get();

  if (!snap.exists) return [];

  const data = snap.data() as { offsets?: ReminderConfig[] } | undefined;
  const offsets = (data?.offsets ?? [])
    .filter((offset) => offset && offset.id && typeof offset.minutesBefore === "number")
    .filter((offset) => offset.minutesBefore > 0)
    .filter((offset) => offset.active !== false)
    .map((offset) => ({
      ...offset,
      minutesBefore: Math.min(offset.minutesBefore, MAX_AHEAD_MS / 60000),
    }));

  return offsets;
}

async function markSent(
  ref: FirebaseFirestore.DocumentReference,
  offsetId: string,
) {
  await ref.update({
    [keyForOffset(offsetId)]: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function sendNotification(
  appt: FirebaseFirestore.DocumentData,
  salonId: string,
  appointmentId: string,
  offsetId: string,
) {
  if (appt.deviceToken) {
    await admin.messaging().send({
      token: appt.deviceToken,
      notification: {
        title: "Promemoria appuntamento",
        body: appt.title
          ? `${appt.title} in arrivo`
          : "Hai un appuntamento imminente",
      },
      data: { salonId, appointmentId, offsetId },
    });
  }

  // Integrare eventuali provider aggiuntivi (WhatsApp, email, ecc.)
}

function enqueueReminderTask(
  payload: ReminderPayload,
  fireAt: Date,
) {
  return enqueueTask({
    scheduleTime: fireAt,
    data: payload,
    dispatchDeadlineSeconds: 300,
  });
}

async function enqueueForAppointment(
  apptRef: FirebaseFirestore.DocumentReference,
  appt: FirebaseFirestore.DocumentData,
) {
  const salonId = apptRef.parent.parent!.id;
  const appointmentId = apptRef.id;
  const startMs = appt.startAt.toMillis();
  const now = nowMs();

  if (startMs - now > MAX_AHEAD_MS) {
    const checkpointAt = startMs - MAX_AHEAD_MS;
    await enqueueReminderTask(
      { salonId, appointmentId, offsetId: "CHECKPOINT" },
      toDate(checkpointAt),
    );
    return;
  }

  const offsets = await loadReminderOffsets(salonId);

  for (const offset of offsets) {
    const fireAtMs = startMs - offset.minutesBefore * 60 * 1000;
    if (fireAtMs <= now) continue;
    if (sentFlag(appt, offset.id)) continue;

    await enqueueReminderTask(
      { salonId, appointmentId, offsetId: offset.id },
      toDate(fireAtMs),
    );
  }
}

// ---------- Triggers ----------

export const onAppointmentWrite = onDocumentWritten(
  { region: REGION, document: "salons/{salonId}/appointments/{appointmentId}" },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;

    const appt = after.data();
    if (!appt?.startAt) return;
    if (isCancelled(appt)) return;

    await enqueueForAppointment(after.ref, appt);
  },
);

export const processReminder = onTaskDispatched(
  {
    region: REGION,
    retryConfig: { maxAttempts: 5 },
    rateLimits: { maxConcurrentDispatches: 20 },
  },
  async (task: TaskContext<ReminderPayload>) => {
    const { salonId, appointmentId, offsetId } = task.data;

    const apptRef = admin.firestore()
      .doc(`salons/${salonId}/appointments/${appointmentId}`);
    const snap = await apptRef.get();
    if (!snap.exists) return;

    const appt = snap.data()!;
    if (isCancelled(appt)) return;

    if (offsetId === "CHECKPOINT") {
      await enqueueForAppointment(apptRef, appt);
      return;
    }

    if (sentFlag(appt, offsetId)) return;

    const now = nowMs();
    if (appt.startAt.toMillis() <= now) return;

    await sendNotification(appt, salonId, appointmentId, offsetId);
    await markSent(apptRef, offsetId);
  },
);

export const sweeperBackfill = onSchedule(
  { region: REGION, schedule: "every 15 minutes" },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const in30d = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + MAX_AHEAD_MS,
    );

    const snap = await db.collectionGroup("appointments")
      .where("cancelled", "==", false)
      .where("startAt", ">=", now)
      .where("startAt", "<=", in30d)
      .limit(500)
      .get();

    await Promise.all(
      snap.docs.map((doc) => enqueueForAppointment(doc.ref, doc.data())),
    );
  },
);
```

**Note implementative**
- Considera una cache in memoria (es. `Map`) per ridurre le letture di `settings/reminders` durante i burst di trigger.
- Aggiorna i flag (`reminder_{id}_sent`) quando l’admin modifica gli offset per evitare collisioni di slug.
- L’UI admin dovrebbe forzare slug univoci per salone.

---

## 5) Sicurezza, idempotenza & gestione delle modifiche

- **Idempotenza:** i flag `reminder_{offsetId}_sent` evitano duplicati anche in presenza di retry di Cloud Tasks o della sweeper.
- **Aggiornamenti appuntamento:** quando data/ora cambiano, il trigger ricalcola la coda. Il consumer rilegge lo stato corrente prima di inviare.
- **Aggiornamenti offset:** al salvataggio delle impostazioni, ricalcola gli appuntamenti imminenti (entro 30 giorni) forzando `enqueueForAppointment`. In alternativa, marca i flag come `false` per rigenerare la programmazione.
- **Retry/Backoff:** personalizza `retryConfig` e `rateLimits` per allinearsi al carico atteso e ai provider di notifica.

---

## 6) Local development & testing

- I simulatori Firebase non emulano Cloud Tasks/Scheduler. Per test locali:
  - incapsula `enqueueReminderTask` dietro un’interfaccia e stubbalo;
  - oppure usa un progetto di staging con API abilitate.
- Scrivi unit/integration test con l’emulatore Firestore per provare:
  - generazione dei flag,
  - ricalcolo quando l’admin modifica gli offset,
  - logica CHECKPOINT + sweeper.
- Usa log strutturati (`console.log(JSON.stringify({...}))`) per facilitare l’osservabilità.

---

## 7) Deployment

```bash
npm run build
firebase deploy --only functions
```

- Il primo deploy di `processReminder` crea automaticamente la coda Cloud Tasks.
- Abilita le API Cloud Scheduler e Cloud Tasks sul progetto.
- Verifica i ruoli IAM: le funzioni devono poter leggere `settings/reminders`.

---

## 8) Operational tips

- **Monitoring:** Cloud Logging + Error Reporting per eccezioni, metriche Cloud Tasks (esecuzioni, retry count).
- **Alerting:** imposta alert su failure rate della coda e sullo scheduler.
- **Multi-tenant:** se necessario, usa code diverse per saloni ad alto traffico o aggiungi un `queue` per salone con limiti dedicati.
- **Timezone & copy:** calcola `scheduleTime` sempre in UTC, ma formatta messaggi usando `Europe/Rome` o il timezone specifico del salone.

---

## 9) Checklist

- [ ] Creare `functions/src/reminders.ts` con la logica sopra.
- [ ] Aggiornare `tsconfig.json`, `package.json`, `firebase.json` se mancanti.
- [ ] Implementare l’UI admin per salvare gli offset nel documento `settings/reminders`.
- [ ] Abilitare Cloud Tasks e Cloud Scheduler, poi deployare su staging (billing attivo).
- [ ] Testare appuntamenti futuri (>30d, <30d, modificati/cancellati) verificando flag e enqueue.
- [ ] Integrare i provider di notifica reali (FCM/WhatsApp/email) e testarli su device.
- [ ] Monitorare Cloud Tasks + logs e controllare l’esecuzione periodicità della sweeper.
