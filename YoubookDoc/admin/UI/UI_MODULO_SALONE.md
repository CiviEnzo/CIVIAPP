UI MODULO SALONE

Obiettivo generale: rendere piu user friendly la gestione del salone introducendo un layout a card che separi chiaramente consultazione e modifica.

Linee guida UX
- Gerarchia visiva chiara: le card critiche (stato salone, disponibilita, promozioni attive) devono occupare piu spazio e includere indicatori visivi (badge, colori neutri + accenti).
- Modularita: ogni card copre un ambito funzionale autonomo per favorire la manutenzione e l evoluzione futura del modulo.
- Contesto prima dell azione: prima di consentire modifiche mostriamo sempre lo stato corrente e, dove utile, uno storico sintetico.
- Prevenzione degli errori: per categorie sensibili (pagamenti, integrazioni) adottiamo azioni confermate, informazioni di warning e campi precompilati.

Cluster di card
- Moduli essenziali (visualizzazione primaria): Informazioni generali del salone, Stato operativo (aperto/chiuso, disponibilita agenda), Performance del giorno (prenotazioni, ricavi), Prossimi appuntamenti.
- Moduli configurabili (integrazioni): WhatsApp Business (WABA), Stripe (tutte le funzioni in un unica card), altri gateway/CRM esterni. Evidenziare lo stato dell integrazione (connesso, azione richiesta) e fornire call-to-action rapidi.
- Impostazioni, macchinari, settaggi: Card secondarie con dettagli tecnici, sala macchine, listini, gestione servizi e staff. Offrire filtri e quick search per elementi numerosi.

Flussi di modifica
- Separare sempre la modale o la vista di editing dalla card di lettura; introdurre pulsante Edit e riquadro laterale o modale dedicata.
- Mantenere stati locali delle modifiche con salvataggio esplicito; prevenire sovrascritture recuperando i dati piu recenti prima del submit.
- Offrire undo light (annulla modifiche) e conferma finale quando la modifica impatta piu elementi (es. disponibilita multipla).

Bottom sheet di configurazione salone (refactoring)
- Obiettivo: dividere l attuale bottom sheet unica in micro pannelli coerenti con le card dell overview (profilo salone, operativita, macchinari, cabine, fedelta, social) e semplificare la creazione iniziale.
- Creazione salone (step 1, obbligatori minimi): Nome, Email, Telefono. Tutto il resto e opzionale e potra essere completato successivamente.
- Profilo salone (step 2 opzionale / edit): indirizzo, citta, descrizione, booking link, Google Place ID, coordinate, CAP.
- Operativita base (obbligatori: stato salone; opzionali: orari, chiusure, toggle dashboard). Questo pannello deve anche esporre la selezione delle sotto card mostrate nella macro card Operativita e risorse.
- Macchinari (obbligatori per ciascun item: nome, quantita > 0; opzionali: note, stato).
- Cabine e stanze (obbligatori: nome, capienza > 0; opzionali: categoria, servizi).
- Programma fedelta (obbligatori se attivo: euro per punto, valore punto, percentuale massima; opzionali: saldo iniziale, reset annuale, timezone, auto suggest).
- Presenza online e social (obbligatori per CDN: label + url valido; gestire duplicati).
- Strategia: ogni sotto card apre una modale dedicata (gia disponibile per macchinari/cabine) o un form leggero (modal bottom sheet o side sheet) con salvataggio immediato e feedback inline, evitando snackbar.
- Nota: macchinari, cabine, integrazioni e ulteriori preferenze sono facoltativi per la creazione; vanno suggeriti dopo il setup iniziale tramite prompt o checklist.

Dettagli per card principali
- Informazioni generali: nome, indirizzo, contatti, descrizione breve, link rapidi. Azioni: modifica, disattiva temporaneamente.
- Operatività e risorse (card unica): KPI sintetici (staff, clienti, appuntamenti futuri), badge stato salone, riepilogo slot orari. I contenuti sono organizzati in sotto-card a griglia (KPI, stato operativo, macchinari, cabine, fedeltà, social) con icone maggiorate, tooltip stato/note e fallback testuale quando vuote. Ogni sotto-card mostra elevation e una CTA di modifica contestuale (modale dedicata per macchinari/cabine, form salone per fedeltà e social). Accanto al titolo è presente un filtro (icona) per aprire la selezione delle sotto-card visibili. Lista appuntamenti rimossa per ridurre rumore. Se attivo, evidenzia anche programma fedeltà (earning, redemption, reset) e riepilogo dei canali social collegati.
- Integrazioni (WABA, Stripe): card con stato connessione, data ultimo sync, errori. CTA: Riconnetti, Configura, Visualizza log.
- WhatsApp Business: card dedicata con stato account, numero associato, token configurati e azioni per collegare/disconnettere. Allineare CTA con flow OAuth già previsto dal servizio.
- Stripe: card unica che raccoglie stato account, abilita pagamenti e bonifici, onboarding e copia ID account; evitare duplicazioni in altre card.

Considerazioni tecniche
- Definire componenti condivisi per card primarie e secondarie per garantire consistenza (header, body, footer con CTA).
- Predisporre un sistema di breakpoint responsive: la vista desktop mostra piu card in griglia, la vista mobile passa a stack verticale con sezioni collassabili.
- Rispettare accessibilita: contrasto sufficiente, stati focus per elementi interattivi, testo alternativo per icone.
- Gestire loading e error state in modo esplicito per ogni card, evitando spinner globali.

Prossimi passi
- Allineare con il team prodotto la priorita delle card essenziali e configurabili.
- Preparare wireframe o mockup di alto livello per validare la gerarchia visiva.
- Definire il modello dati necessario per alimentare le card (API, DTO, adapter).
- Pianificare la migrazione incrementale dal layout attuale al nuovo schema modulare.
Onboarding salone – user flow
1. Step iniziale (modal/sheet compatta)
   - Campi richiesti: Nome salone, Email principale, Numero di telefono principale.
   - Azioni disponibili: "Crea e continua", "Annulla".
   - Validazioni: form incompleto => pulsante disabilitato; format email/telefono.
2. Success screen (checklist guidata)
   - Messaggio: "Salone creato. Completa le seguenti aree per attivare tutte le funzionalità".
   - Checklist (con stato completion):
     • Profilo e indirizzo
     • Operatività (orari, chiusure, visibilità sezioni)
     • Macchinari
     • Cabine e stanze
     • Programma fedeltà
     • Presenza online e social
     • Integrazioni (WhatsApp, Stripe, ecc.)
   - Ogni voce apre la rispettiva bottom sheet di dettaglio (vedi sezione seguente).
   - Opzione "Salta per ora" per accedere comunque al modulo admin con badge di reminder.

Nuove bottom sheet/moduli di modifica
- Profilo e indirizzo
  • Campi: indirizzo, città, CAP, coordinate, Google Place ID, descrizione.
  • CTA: Salva.
  • Accesso da card "Informazioni generali".
- Operatività
  • Campi: stato salone, orari settimanali, chiusure straordinarie, toggle visibilità sotto-card.
  • Include anteprima sezione "Programma fedeltà" (link al pannello dedicato).
- Macchinari
  • Gestione elencata (già implementata) ma separata dalla form principale.
- Cabine e stanze
  • Come sopra.
- Programma fedeltà
  • Attiva/disattiva + parametri obbligatori quando abilitato.
- Presenza online e social
  • Gestione coppie label/link, validazione URL.
- Integrazioni
  • Sheet dedicate per WhatsApp/Stripe con stato e azioni.

Considerazioni UX
- Conservare breadcrumb/chips completati nella checklist per dare feedback.
- Mostrare reminder in dashboard finché alcune milestone restano incomplete (es. banner "Completa il setup del salone").

### User Flow – Creazione Salone

1. **Step 1: Dati essenziali**
   - UI: bottom sheet compatta con i soli campi obbligatori , , .
   - Logica: validazioni sincrone (form incompleto => CTA disabilitata, formati email/telefono).
   - CTA principali: , .

2. **Step 2: Checklist post-creazione**
   - Success bottom sheet (o side panel) che conferma la creazione e presenta la checklist delle aree opzionali.
   - Ogni voce mostra stato (non iniziato/in corso/completato) e CTA .
   - Azioni rapide: ,  (chiude il pannello ma mantiene reminder).
   - Reminder nel dashboard admin finché esistono attività non completate (es. banner o chip).

### Checklist e micro-flow di approfondimento

| Voce checklist | Destinazione | Campo obbligatorio? | Note UX |
| --- | --- | --- | --- |
| Profilo e indirizzo | Bottom sheet  | Nessuno (post step1) | suggerire auto-compilazione indirizzo; consentire salvataggio parziale |
| Operatività | Bottom sheet  | Solo stato salone già presente; orari/chiusure opzionali | mostra preview orari + toggle visibilità sotto-card |
| Macchinari | Bottom sheet  (già esistente) | nessuno | aggiungere badge 0

### User Flow – Creazione Salone

1. **Step 1: Dati essenziali**
   - UI: bottom sheet compatta con i soli campi obbligatori `Nome`, `Email`, `Telefono`.
   - Logica: validazioni sincrone (form incompleto => CTA disabilitata, formati email/telefono).
   - CTA principali: `Crea e continua`, `Annulla`.

2. **Step 2: Checklist post-creazione**
   - Success bottom sheet (o side panel) che conferma la creazione e presenta la checklist delle aree opzionali.
   - Ogni voce mostra stato (non iniziato/in corso/completato) e CTA `Configura`.
   - Azioni rapide: `Apri sezione`, `Salta per ora` (chiude il pannello ma mantiene reminder).
   - Reminder nel dashboard admin finché esistono attività non completate (es. banner o chip).

### Checklist e micro-flow di approfondimento

| Voce checklist | Destinazione | Campo obbligatorio? | Note UX |
| --- | --- | --- | --- |
| Profilo e indirizzo | Bottom sheet `Profilo` | Nessuno (post step1) | suggerire auto-compilazione indirizzo; consentire salvataggio parziale |
| Operatività | Bottom sheet `Operatività` | Solo stato salone già presente; orari/chiusure opzionali | mostra preview orari + toggle visibilità sotto-card |
| Macchinari | Bottom sheet `Macchinari` (già esistente) | nessuno | aggiungere badge "0 macchinari" se vuoto |
| Cabine e stanze | Bottom sheet `Cabine` | nessuno | simile macchinari |
| Programma fedeltà | Bottom sheet `Fedeltà` | solo se attivo: euro per punto, valore punto, max sconto | include link rapido dalla card operatività |
| Presenza online e social | Bottom sheet `Social` | coppie label + url valido | validazioni duplicati/URL |
| Integrazioni | Bottom sheet `Integrazioni` (tab WhatsApp/Stripe) | nessuno | mostra stato + CTA "Configura" |

### Suddivisione bottom sheet / moduli

- `Step1EssentialSalonSheet` (nuova) – racchiude i 3 campi obbligatori e crea il record.
- `SalonProfileSheet` – dati anagrafici estesi (indirizzo, descrizione, coordinate).
- `SalonOperationsSheet` – stato salone, orari, chiusure, toggle dashboard.
- `SalonEquipmentSheet` – già esistente, riutilizzata.
- `SalonRoomsSheet` – già esistente, riutilizzata.
- `SalonLoyaltySheet` – nuovo pannello dedicato al programma punti.
- `SalonSocialSheet` – gestione social links.
- `SalonIntegrationsSheet` – hub con tab per WhatsApp/Stripe (o rimando alle schermate esistenti).

### Navigation di riferimento

1. Admin apre `+ Salone` → `Step1EssentialSalonSheet`.
2. Success → Checklist overlay.
3. Ogni item: aprire sheet corrispondente, salvare inline → aggiornare stato checklist.
4. Reminder nel dashboard finché non completate tutte (opzionale: richiedere almeno Operatività).

### Considerazioni tecniche

- Memorizzare stato checklist via `Salon` (es. mappa completions) o `AdminSetupProgress`.
- Fornire hook per riaprire checklist in seguito (menu "Completa setup").
- Tutte le sheet devono gestire salvataggio immediato via provider e mostrare feedback inline (no snackbar di successo).

### Stati checklist e regole di avanzamento

- Stato iniziale `non_iniziato` per tutti gli item subito dopo la creazione del salone.
- Apertura di una sheet dalla checklist imposta lo stato su `in_corso` e blocca la CTA `Configura` finche la modale resta aperta.
- Salvataggio valido aggiorna lo stato a `completato`, chiude la sheet e mostra check verde nella checklist.
- Azione `Salta per ora` segna l item come `posticipato`, mantiene il reminder e offre un link rapido nella dashboard.
- In caso di errore di salvataggio ripristinare lo stato precedente e mostrare il messaggio inline nel form.

### Micro-flow per voce della checklist

#### Profilo e indirizzo
1. Admin preme `Configura` da checklist o dalla card Informazioni generali.
2. Si apre `SalonProfileSheet` con campi precompilati dai dati esistenti; suggerire autocompletamento indirizzo.
3. L admin aggiorna i campi necessari; validazione immediata su CAP, coordinate e URL booking.
4. `Salva` commit immediato, chiude la sheet, aggiorna stato checklist e synca i riepiloghi nella card overview.

#### Operativita
1. Selezione da checklist oppure CTA nella card Operativita e risorse.
2. `SalonOperationsSheet` mostra stato corrente, orari e chiusure; toggle per card visibili inline.
3. L admin imposta stato e opzionalmente orari; preview si aggiorna live nella sheet.
4. `Salva` aggiorna la card principale; se il salone rimane senza slot attivi mostra warning inline.

#### Macchinari
1. Apertura `SalonEquipmentSheet` dalla checklist.
2. Lista esistente con badge "0 macchinari" se vuota + CTA `Aggiungi macchinario`.
3. Ogni nuovo item richiede nome e quantita > 0; salvataggio immediato per riga.
4. Chiusura sheet sincronizza conteggi nella card e marca checklist come completa se almeno un macchinario e registrato o se l admin conferma l assenza tramite toggle "Nessun macchinario".

#### Cabine e stanze
1. Apertura da checklist -> `SalonRoomsSheet`.
2. Visualizzazione tabellare con CTA `Nuova cabina`; validazione capienza > 0.
3. Salvataggio inline per ogni voce, con feedback sotto il campo se dati non validi.
4. Completamento checklist al primo salvataggio valido o conferma esplicita di assenza cabine.

#### Programma fedelta
1. CTA `Configura` apre `SalonLoyaltySheet`.
2. Primissimo step: toggle `Attiva programma`; se off la check resta opzionale ma marcata come completata dopo la conferma.
3. Se attivo, rendere obbligatori euro per punto, valore punto e percentuale massima; calcolare anteprima conversione in tempo reale.
4. Salvataggio aggiorna gli indicatori nella card Operativita e aggiunge badge fedelta nell overview.

#### Presenza online e social
1. Apertura `SalonSocialSheet` dalla checklist.
2. L admin puo aggiungere righe label + URL; validazione asincrona su duplicati e formato.
3. `Salva` committa tutte le righe, mostra stato aggiornato nella checklist e aggiunge icone social nella card.
4. In caso di errori specifici su un URL mantenere la modale aperta con messaggio inline e lasciare le altre righe salvate.

#### Integrazioni
1. CTA `Configura` punta a `SalonIntegrationsSheet` con tab WhatsApp e Stripe.
2. Ogni tab mostra stato connessione, ultimo sync e CTA principali (`Collega`, `Riconnetti`, `Visualizza log`).
3. Per WABA avviare flow OAuth in modale separata; al termine aggiornare la tab e chiudere automaticamente se l integrazione va a buon fine.
4. Per Stripe gestire onboarding e fetch stato; checklist segna completato appena entrambi i servizi sono marcati `connesso` o se l admin imposta `Configura piu tardi`.

#### Reminder dashboard
1. Se esistono item `non_iniziato` o `posticipato`, mostrare chip di reminder nella dashboard admin.
2. Click sul chip riapre la checklist; in assenza di item aperti il chip scompare automaticamente.

### Pianificazione hook backend (Salon/AdminSetupProgress)

#### Modellazione dati
- Estendere `Salon` con campo `setupChecklist` (mappa `{itemKey: ChecklistItemState}`) per mostrare una snapshot rapida nel read model.
- Introdurre documento/record `AdminSetupProgress` legato al salon (`salonId`, `tenantId`, `createdBy`) con struttura:
  - `items`: array di oggetti `{ key, status, updatedAt, updatedBy, metadata }`.
  - `pendingReminder`: bool che abilita il chip nel dashboard.
  - `requiredCompleted`: bool per forzare Operatività prima di rimuovere reminder.
- Stati ammessi: `non_iniziato`, `in_corso`, `completato`, `posticipato`.
- `metadata` contiene info aggiuntive per item (es. `hasEquipment=false` quando l admin conferma assenza macchinari).

#### Hook di inizializzazione
1. `Step1EssentialSalonSheet` → al `CreateSalonService` aggiungere `SetupProgressService.initialize(salonId, adminId)`.
2. L inizializzazione crea `AdminSetupProgress` con tutti gli item in `non_iniziato`, `pendingReminder=true`.
3. Sincronizzare anche `Salon.setupChecklist` con la stessa mappa per evitare doppi fetch in UI read-heavy.

#### Hook di aggiornamento per sheet
| Evento UI | Metodo backend | Logica |
| --- | --- | --- |
| Apertura sheet da checklist | `SetupProgressService.markInProgress(salonId, itemKey, adminId)` | Aggiorna stato `in_corso` se era `non_iniziato`, timestamp e `updatedBy`. |
| Salvataggio valido | `SetupProgressService.markCompleted(...)` | Stato `completato`, imposta `metadata` (es. count macchinari, toggles). Se Operatività completata → `requiredCompleted=true`. |
| Conferma assenza (macchinari/cabine) | `markCompleted` con `metadata.skip=true`. | Permette completamento anche senza record. |
| Attivazione toggle "Configura piu tardi" | `SetupProgressService.postpone(...)` | Stato `posticipato`, mantiene `pendingReminder=true`. |
| Richiesta reminder manuale off | `SetupProgressService.clearReminder(...)` | Setta `pendingReminder=false` solo se tutti gli item sono `completato` o `posticipato` senza obbligatori mancanti. |

#### Esempi di API/endpoint
- `GET /admin/salons/:salonId/setup-progress` → restituisce `AdminSetupProgress` + snapshot `setupChecklist`.
- `PATCH /admin/salons/:salonId/setup-progress/:itemKey` con payload `{action: start|complete|postpone, metadata}`.
- Gli endpoint sheet riutilizzano i servizi esistenti e, a salvataggio riuscito, chiamano `SetupProgressService` (evitare roundtrip extra dal frontend).
- Webhook/eventi interni: emettere `SalonSetupProgressUpdated` per alimentare analytics o notifiche.

#### Reminder dashboard
- Cron job giornaliero (o trigger evento) che verifica item `non_iniziato`/`posticipato` > N giorni e invia email/notification a owner.
- UI dashboard legge `Salon.setupChecklist` e `pendingReminder`; se `pendingReminder=false` non mostra chip.
- Quando l admin riapre checklist dalla dashboard, il frontend invoca `markInProgress` per il primo item aperto.

#### Considerazioni tecniche
- Rendere le operazioni idempotenti: `markCompleted` deve poter essere chiamato piu volte senza duplicare logica.
- Audit trail: salvare `updatedBy` e `updatedAt` per ogni item per supportare analytics e eventuali revert manuali.
- Garantire consistenza tra `AdminSetupProgress` e `Salon.setupChecklist` tramite transazione o scrittura atomica (batch transaction se Firestore).
- Prevedere migrazione dati per saloni esistenti: script che inizializza record `AdminSetupProgress` con stati dedotti dai dati attuali.
