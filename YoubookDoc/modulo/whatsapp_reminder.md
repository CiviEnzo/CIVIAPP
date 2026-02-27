# WhatsApp Reminder - processo e soluzioni (proposta)

## Obiettivo
Integrare WhatsApp nel modulo `Messaggi & marketing` in modo coerente con i reminder automatici gia presenti (push), consentendo:

- scelta del tipo di reminder (`push` o `WhatsApp`) per ogni offset (es. 24h, 3h, 1h)
- scelta del template WhatsApp da usare (solo template con uso `reminder`)
- popolamento automatico dei campi dinamici (nome cliente, servizio, data, ora, salone, ecc.)
- estensione futura dello stesso schema a `Promozioni`, `Last-minute` e `Manuali`

## Stato attuale (as-is)
### Frontend / backoffice
- Il tab `Automazione` nel modulo `Messaggi & marketing` gestisce i reminder tramite `ReminderSettings.offsets`.
- Ogni offset contiene oggi:
  - `id`
  - `minutesBefore`
  - `active`
  - `title` (push / descrittivo)
  - `bodyTemplate` (push / testo libero con placeholder)
- Non esiste ancora una scelta esplicita del canale reminder per offset.
- Non esiste ancora una selezione del template WhatsApp nel reminder settings.

### Backend reminder
- Esistono due flussi reminder:
  - `functions/src/messaging/scheduler.ts` (legacy, push-only, basato su `appointmentOffsetsMinutes`)
  - `functions/src/reminders/hybrid.ts` (piu evoluto: usa `offsets`, task per appuntamento, ma invia ancora solo push)
- Il flusso `hybrid.ts` e il candidato migliore da estendere a WhatsApp perche:
  - legge gia `offsets` completi da `salons/{salonId}/settings/reminders`
  - schedula per offset specifico
  - ha gia outbox/audit push minimo e flag per offset inviato

### Template WhatsApp (YouBook)
- I template locali WhatsApp hanno ora:
  - `metaTemplateName`
  - `metaTemplateLanguage` (fallback `it`)
- In alcuni casi i template importati vengono salvati con `usage` predefinito (spesso `reminder`): serve rendere il campo utilizzo piu esplicito/modificabile nel flusso reminder e nella libreria.

## Principio guida (importante)
Separare chiaramente:

- `Evento/trigger`: reminder appuntamento, promozione, last-minute, manuale
- `Canale`: push / WhatsApp (e in futuro email/sms)
- `Template`: dipendente dal canale e dal tipo di evento

Questo evita logiche duplicate e rende estendibile lo stesso approccio anche agli altri tab.

## Soluzione proposta (Reminder appuntamenti)
### 1) Estendere il modello dati reminder per offset
Estendere `ReminderOffsetConfig` con metadata di delivery:

```ts
ReminderOffsetConfig {
  id: string
  minutesBefore: number
  active: boolean

  // push copy legacy (resta supportata)
  title?: string
  bodyTemplate?: string

  // nuovo
  deliveryChannel?: 'push' | 'whatsapp'   // default: 'push'

  // usato solo se deliveryChannel = 'whatsapp'
  whatsappTemplateId?: string             // id template locale YouBook
  whatsappTemplateName?: string           // opzionale cache/meta snapshot
}
```

Note:
- `whatsappTemplateId` punta al template locale YouBook (non direttamente al nome Meta), cosi manteniamo controllo lato app.
- Dal template locale ricaviamo:
  - `resolvedMetaTemplateName`
  - `resolvedMetaTemplateLanguage`
- `title/bodyTemplate` restano per compatibilita e per reminder push.

### 2) UX nel tab "Messaggi & marketing" > Automazione
Per ogni offset reminder aggiungere:

- `Tipo reminder` (segmented / dropdown):
  - `Push`
  - `WhatsApp`
- Se `WhatsApp`:
  - mostrare selettore `Template WhatsApp`
  - filtrare solo template:
    - `channel == whatsapp`
    - `usage == reminder`
    - `isActive == true`
    - `salonId == salone corrente`

Comportamento UI consigliato:
- Se non esistono template WhatsApp reminder:
  - messaggio guida "Crea/importa un template WhatsApp con uso Promemoria"
  - CTA rapida "Apri template WhatsApp"
- Non mostrare selezione lingua: la lingua arriva dal template approvato (`metaTemplateLanguage`, fallback `it`).

### 3) Rendere modificabile l'uso dei template locali (usage)
Problema segnalato: "i template salvati su YouBook risultano tutti reminder".

Soluzione UX:
- Rendere sempre modificabile `usage` nel template locale (gia presente nel form generale, ma va reso evidente anche nel flusso WhatsApp).
- Nel salvataggio/import da template Meta:
  - mantenere un `default` suggerito (guess da category Meta)
  - ma permettere override esplicito (`Promemoria`, `Promozione`, `Follow-up`, `Compleanno`)
- Nella lista template WhatsApp locali:
  - mostrare badge uso
  - aggiungere azione rapida "Cambia utilizzo" (anche menu `...`)

Obiettivo pratico:
- Il reminder settings deve vedere solo i template `usage == reminder`.
- Gli altri tab (promozioni/manuali/last-minute) vedranno solo il sottoinsieme pertinente.

### 4) Placeholder dinamici: contesto unico per appuntamento
Per WhatsApp reminder servono valori reali per i campi del template (e per eventuale preview locale).

### Dati da recuperare
Dall'appuntamento + anagrafiche correlate:

- `client_name` / `first_name`
- `service_name`
- `date`
- `time`
- `appointment_label`
- `salon_name`
- `staff_name` (utile e consigliato)
- `reminder_offset_label` (es. "tra 3 ore")

### Dove costruire il contesto
Nel backend reminder (`functions/src/reminders/hybrid.ts`) creare un builder unico, ad esempio:

```ts
buildAppointmentReminderTemplateContext(...)
```

che:
- legge appuntamento
- risolve cliente (nome)
- risolve salone
- risolve servizio/staff se presenti
- formatta data/ora in `it-IT`
- genera alias compatibili

### Riuso utility esistente
Riusare `functions/src/messaging/placeholders.ts` (`renderTemplate`) per:
- preview push personalizzata
- fallback / debug
- supporto alias (`nome`, `cliente`, `service`, `orario`, ecc.)

### 5) Invio reminder WhatsApp (backend)
### Strategia consigliata (fase 1 pragmatic)
Estendere `functions/src/reminders/hybrid.ts` per inviare:

- `push` come oggi
- `whatsapp` quando `offset.deliveryChannel == 'whatsapp'`

Passi runtime:
1. Il task reminder legge l'offset.
2. Se canale `push`, flusso attuale.
3. Se canale `whatsapp`:
   - recupera template locale da `whatsappTemplateId`
   - valida che sia:
     - stesso `salonId`
     - `channel == whatsapp`
     - `usage == reminder`
     - `isActive == true`
   - costruisce context placeholder da appuntamento
   - costruisce `components` WhatsApp (body parameters in ordine)
   - invia via `sendTemplateMessage(...)`
   - salva audit/outbox + provider message id
   - marca flag `reminder_{offsetId}_sent`

### Perche fase 1 nel `hybrid.ts`
- Minimo impatto sul flusso gia funzionante di scheduling per offset.
- Riutilizza i task per appuntamento e i flag di deduplica.
- Evita di duplicare la logica tra scheduler legacy e nuovi reminder.

### Evoluzione consigliata (fase 2)
Portare reminder push e reminder WhatsApp a un outbox unificato (`message_outbox`) con `channel in ['push','whatsapp']`, in modo da:
- uniformare audit/traces
- retry centralizzato
- quiet hours/dispatcher comuni

Nota: oggi `dispatchOutbox` filtra ancora `['push','email']`, quindi per usare outbox WhatsApp in automazione serve estendere anche il dispatcher.

### 6) Mapping placeholder -> componenti WhatsApp
### Soluzione semplice (subito)
Usare il `body` del template locale YouBook come "schema di mapping" per estrarre placeholder in ordine:

- esempio body locale:
  - `Ciao {{client_name}}, ti ricordiamo {{service_name}} il {{date}} alle {{time}}`
- il backend:
  - estrae placeholder in ordine
  - sostituisce dal context
  - costruisce `components[0].parameters[]`

Vantaggi:
- non serve UI complessa di mapping per ogni template
- comportamento coerente con il tab campagne gia esistente

Limiti noti (accettabili in fase 1):
- copre bene i template con variabili solo nel body
- header/button dinamici richiedono mapping esplicito (fase 2)

### Soluzione robusta (fase 2)
Aggiungere nel template locale una configurazione opzionale:

```ts
whatsappBindings: {
  body?: ['client_name', 'service_name', 'date', 'time']
  header?: [...]
  buttons?: [...]
}
```

### 7) Validazioni e fallback
### Validazioni in salvataggio reminder settings
- Se `deliveryChannel == whatsapp`:
  - `whatsappTemplateId` obbligatorio
  - template selezionato deve esistere ed essere `usage == reminder`
- Se template WhatsApp viene disattivato/eliminato:
  - il reminder offset resta configurato ma entra in stato `Errore configurazione`
  - UI mostra warning e richiesta di reselezionare template

### Fallback operativi
- Se invio WhatsApp fallisce:
  - registrare errore con dettaglio (`message_outbox` / audit)
  - opzionale (decisione da prendere): fallback a push solo per reminder critici 
- Se placeholders mancanti:
  - sostituire stringa vuota o valore safe
  - loggare warning con nome placeholder mancante

### 8) Processo end-to-end (reminder appuntamento)
### Configurazione backoffice
1. Admin/staff apre `Messaggi & marketing > Automazione`.
2. Aggiunge/modifica un offset (es. 24h).
3. Sceglie `Tipo reminder`:
   - `Push` -> usa testo push (title/bodyTemplate)
   - `WhatsApp` -> seleziona template locale `usage=reminder`
4. Salva settings reminder.

### Scheduling
1. Creazione/modifica appuntamento attiva `appointmentReminderOnWrite`.
2. `reminders/hybrid.ts` legge offset da `salons/{salonId}/settings/reminders`.
3. Enqueue task per ciascun offset attivo.

### Invio
1. Task reminder rilegge appuntamento e verifica stato.
2. Recupera offset specifico.
3. Costruisce context (cliente, servizio, data, ora, salone, staff).
4. Invia via canale selezionato.
5. Scrive audit/outbox e marca flag "sent" per l'offset.

## Estensione allo stesso modello (Promozioni, Last-minute, Manuali)
L'idea e usare la stessa struttura mentale ovunque:

- `evento`
- `canale`
- `template`
- `context placeholders`

### Promozioni
Per ogni campagna promozionale:
- scegliere canale (`push` / `whatsapp`)
- se WhatsApp, scegliere template `usage == promotion`
- placeholder possibili:
  - `client_name`
  - `promotion_title`
  - `discount`
  - `expiry_date`
  - `booking_link`

### Last-minute
Per invio slot last-minute:
- canale `push` / `whatsapp`
- template `usage == reminder` o `usage == promotion` (decisione UI: meglio `promotion` o nuovo `lastMinute`)
- placeholder:
  - `client_name`
  - `service_name`
  - `date`
  - `time`
  - `price`
  - `staff_name`
  - `booking_link`

Nota: se il volume cresce, valutare un nuovo `TemplateUsage.lastMinute` per filtro piu preciso.

### Manuali
Per invio manuale da backoffice:
- scelta canale per singolo invio
- se WhatsApp, template filtrati per uso coerente con il tab (manuale/promo/follow-up)
- preview con placeholders precompilati quando il contesto e noto (cliente selezionato)

## Compatibilita e migrazione (importante)
Per non rompere il sistema attuale:

- Default reminder existing -> `deliveryChannel = push`
- Se offset esistente non ha nuovi campi:
  - UI e backend assumono `push`
- `appointmentOffsetsMinutes` resta valorizzato per compatibilita legacy, ma la fonte principale diventa `offsets[*]`
- `messaging/scheduler.ts` (legacy) puo continuare finche non si completa la migrazione al `hybrid.ts` esteso

## Roadmap implementativa consigliata
### Fase 1 - Reminder WhatsApp operativo (MVP)
- Estendere `ReminderOffsetConfig` frontend + mapper Firestore
- UI `Automazione`: `Tipo reminder` + selezione template WhatsApp (`usage=reminder`)
- Estendere `functions/src/reminders/hybrid.ts` a `deliveryChannel`
- Context placeholder per appuntamento (cliente/servizio/data/ora/salone/staff)
- Invio WhatsApp reminder via `sendTemplateMessage(...)`
- Audit essenziale (success/error, providerMessageId)

### Fase 2 - Qualita / robustezza
- Stato configurazione reminder (warning template mancante/disattivo)
- Mapping avanzato header/button WhatsApp
- Outbox unificato reminder push/WhatsApp + dispatcher (`channel in ['push','email','whatsapp']`)
- Metriche e dashboard invii reminder per canale

### Fase 3 - Estensione agli altri tab
- Promozioni con canale selezionabile + template `promotion`
- Last-minute con canale selezionabile + placeholder slot
- Manuali con UX coerente e preview contestuale

## Decisioni aperte (da chiudere)
- Reminder WhatsApp: `push` OR `whatsapp`, oppure supportiamo anche `entrambi`? Anche entrambi a scelta dell' admin
- Se invio WhatsApp reminder fallisce: fallback automatico a push oppure no? nessun fallback
- `Last-minute`: usare `TemplateUsage.promotion` o introdurre `TemplateUsage.lastMinute`? introdurre `TemplateUsage.lastMinute`
- Per i template Meta con header/button dinamici: rimandiamo mapping avanzato alla fase 2? Si rimandiamo alla fase 2
 