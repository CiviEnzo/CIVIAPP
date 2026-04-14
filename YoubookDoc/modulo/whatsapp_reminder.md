# WhatsApp Reminder e Template Configurator (Fase 2)

## Obiettivo aggiornato
MVP reminder WhatsApp raggiunto.
Il focus ora e la **Fase 2**: introdurre un **configuratore template centralizzato** nel modulo WhatsApp, in modo che l'admin possa:

- configurare template `reminder` con tutti i parametri disponibili
- configurare template `promotion` con tutti i parametri disponibili
- usare CTA gia definite nel template WhatsApp Manager (nessuna selezione CTA in YouBook in Fase 2)
- riusare i template configurati negli altri moduli (`Automazione`, `Promozioni`, `Manuali`)

## Stato corrente (MVP completato)
### Reminder automation
- Gli offset reminder supportano `deliveryMode: push | whatsapp | both`.
- Per offset WhatsApp e selezionabile un template locale con `usage=reminder`.
- Il backend reminder usa `functions/src/reminders/hybrid.ts` per scheduling e invio.

### Template reminder WhatsApp
- Validazioni attive in invio reminder:
  - template esistente
  - `channel == whatsapp`
  - `usage == reminder`
  - `isActive == true`
  - `salonId` coerente
- Invio via `sendTemplateMessage(...)` con audit su `message_outbox`.

### Placeholder reminder gia supportati
Nel backend reminder (`hybrid.ts`) sono gia risolti questi parametri canonici:

- `firstName`
- `lastName`
- `clientName`
- `salonName`
- `serviceName`
- `staffName`
- `dateTimeFull`
- `date`
- `time`
- `appointmentLabel` (legacy, alias di `dateTimeFull`)

Alias gia supportati (esempi):

- `{{nome}}`, `{{first_name}}`, `{{firstname}}` -> `firstName`
- `{{cliente}}`, `{{client_name}}` -> `clientName`
- `{{servizio}}`, `{{service_name}}` -> `serviceName`
- `{{salone}}`, `{{salon_name}}` -> `salonName`
- `{{data_completa}}`, `{{datetime}}`, `{{date_time_full}}` -> `dateTimeFull`
- `{{data}}`, `{{giorno}}` -> `date`
- `{{ora}}`, `{{orario}}` -> `time`
- `{{appuntamento}}`, `{{appointment_label}}` -> `appointmentLabel` (legacy -> data completa)

Formato valori data/ora richiesto:

- `dateTimeFull`: `15 aprile alle 15:00`
- `date`: `15 aprile`
- `time`: `15:00`

## Fase 2: requisito funzionale
## 1) Configuratore template centralizzato (modulo WhatsApp)
Il modulo WhatsApp diventa la **fonte unica di configurazione template**.

Ogni template WhatsApp deve avere:

- metadati base: `title`, `usage`, `metaTemplateName`, `metaTemplateLanguage`, `isActive`
- schema parametri disponibili per il tipo (`reminder`, `promotion`, ...)
- binding dei parametri usati in:
  - `body`
  - `header` (se previsto da Meta)

Output del configuratore:

- template pronto per essere selezionato negli altri moduli
- preview con parametri valorizzati
- validazione preventiva (prima del salvataggio)

## 2) Template `reminder`: configurazione parametri
Nel configuratore reminder l'admin deve poter:

- vedere la lista completa parametri reminder disponibili
- selezionare quali parametri usare nel template
- definire l'ordine dei parametri per `body/header` (se necessari)
- associare in modo esplicito ogni posizione Meta (`{{1}}`, `{{2}}`, ...) a un campo YouBook
- ricavare il numero di parametri direttamente dall'anteprima template in alto

Set minimo disponibile da mostrare in UI (allineato al backend attuale):

- `firstName`, `lastName`, `clientName`
- `serviceName`, `staffName`
- `dateTimeFull`, `date`, `time`
- `salonName`

Formato UX obbligatorio per chiarezza mapping:

- all'apertura dialog mostrare in alto l'anteprima messaggio template
- il numero di parametri da configurare e derivato dall'anteprima/template Meta
- non e consentito aggiungere o eliminare parametri
- riga per posizione: `Parametro 1 (Meta {{1}}) -> [campo YouBook]`
- riga per posizione: `Parametro 2 (Meta {{2}}) -> [campo YouBook]`
- usare drag and drop dei parametri YouBook verso ogni posizione Meta
- mostrare sempre la sorgente YouBook del campo selezionato (es. `serviceName -> Appuntamento.servizio.nome`)
- accanto a ogni posizione mappata mostrare un campo `testo libero anteprima` che aggiorna l'anteprima in tempo reale
- per ogni posizione Meta e possibile impostare anche un `testo custom` manuale: se valorizzato, viene inviato come valore fisso al posto del parametro YouBook

## 3) Template `promotion`: configurazione parametri
Nel configuratore promotion l'admin deve poter:

- configurare i parametri testo del template
- usare i dati promozione come sorgente dei parametri (senza mapping CTA lato YouBook)
- inviare il template WhatsApp a utenti selezionati (clienti scelti manualmente)

Fonte dati obbligatoria per `promotion`:

- i valori dei parametri vanno letti dal **Tab Promozioni** del modulo `Messaggi & marketing`
- il contesto e la promozione selezionata/pubblicata (record `Promotion`)
- non sono previsti valori manuali scollegati dalla promozione

Destinatari promozione:

- selezione manuale clienti dal salone (multi-selezione)
- invio verso i clienti selezionati con numero telefono disponibile
- personalizzazione `clientName` (e `firstName` se usato) per ogni destinatario
- anteprima campagna valorizzata sul cliente selezionato (se nessun cliente e selezionato, mostra hint dedicato)

Parametri promotion (base):

- `clientName`
- `promotionTitle`
- `promotionSubtitle`
- `discountPercentage`
- `startsAtDateTimeFull`
- `startsAtDate`
- `startsAtTime`
- `endsAtDateTimeFull`
- `endsAtDate`
- `endsAtTime`
- `salonName`

Parametri promotion (legacy, retrocompatibilita):

- `startsAt` (equivale a `startsAtDateTimeFull`)
- `endsAt` (equivale a `endsAtDateTimeFull`)

Parametri promotion (cta/link):

- `landingUrl`
- `ctaLabel`

Mappatura consigliata parametro -> sorgente Tab Promozioni:

- `promotionTitle` -> `promotion.title`
- `promotionSubtitle` -> `promotion.subtitle`
- `discountPercentage` -> `promotion.discountPercentage`
- `startsAtDateTimeFull` -> `promotion.startsAt` formattata completa (`15 aprile alle 15:00`)
- `startsAtDate` -> `promotion.startsAt` solo data (`15 aprile`)
- `startsAtTime` -> `promotion.startsAt` solo ora (`15:00`)
- `endsAtDateTimeFull` -> `promotion.endsAt` formattata completa (`20 aprile alle 18:30`)
- `endsAtDate` -> `promotion.endsAt` solo data (`20 aprile`)
- `endsAtTime` -> `promotion.endsAt` solo ora (`18:30`)
- `salonName` -> salone corrente
- `landingUrl` -> `promotion.ctaUrl` oppure `promotion.cta.url`
- `ctaLabel` -> `promotion.cta.label`

## 4) CTA WhatsApp: regole Fase 2
Per la Fase 2:

- la CTA non si configura nel modulo WhatsApp di YouBook
- eventuale bottone/URL e definito direttamente nel template su WhatsApp Manager
- YouBook invia il template senza configurazione CTA aggiuntiva lato app

Validazioni minime:

- coerenza tra template locale YouBook e template approvato su WhatsApp Manager

## 5) Modello dati consigliato (estensione `message_templates`)
Aggiungere una configurazione dedicata WhatsApp riusabile:

```ts
message_templates/{templateId} {
  salonId: string
  title: string
  channel: "whatsapp"
  usage: "reminder" | "promotion" | "followUp" | "birthday"
  body: string
  metaTemplateName: string
  metaTemplateLanguage: string
  isActive: boolean

  whatsappConfig?: {
    schemaVersion: 2
    allowedParams: string[]
    bindings?: {
      body?: string[]
      header?: string[]
      buttons?: Array<...> // opzionale, non configurato da UI in Fase 2
    }
  }
}
```

Note:

- mantenere fallback legacy: se `bindings` assente, usare estrazione placeholder dal `body`.
- i template `last-minute` sono fuori scope e non vanno implementati.

## 6) Riuso cross-modulo (obbligatorio)
Dopo la configurazione nel modulo WhatsApp:

- `Automazione` usa template con `usage=reminder`
- `Promozioni` usa template con `usage=promotion`
- `Manuali` filtra per usage coerente al contesto di invio

Principio: i moduli di invio **non** configurano mapping avanzati; consumano solo template gia configurati.

## 7) Impatti backend fase 2
### Reminder
- `functions/src/reminders/hybrid.ts`:
  - continuare a supportare mapping body attuale
  - usare `whatsappConfig.bindings` quando presente
  - estendere a header quando configurati

### Promotion
- introdurre builder contesto promotion e invio template WhatsApp con bindings
- mantenere CTA gestita direttamente nel template WhatsApp Manager

### Dispatcher
- `dispatchOutbox` supporta gia `components`; riusarlo anche per promotion WhatsApp.

## 8) UX minima del configuratore
Per ogni template WhatsApp:

1. Sezione `Meta`: nome template, lingua, stato attivo
2. Sezione `Uso`: reminder / promotion / followUp / birthday
3. Anteprima messaggio in alto (base per conteggio parametri)
4. Sezione `Parametri disponibili` (YouBook) con drag and drop
5. Sezione `Mapping`:
   - body con mapping posizionale esplicito `Meta {{n}} -> parametro YouBook`
   - numero posizioni fisso (no add/remove)
   - campo testo libero per ogni posizione mappata, con aggiornamento realtime anteprima
   - header (opzionale)
6. Validazione e salvataggio

## 9) Decisioni chiuse
- Modalita reminder supportata: `push`, `whatsapp`, `both`
- Se invio WhatsApp fallisce: **nessun fallback automatico a push**
- `Last-minute`: non implementare template dedicati
- Mapping avanzato `header/buttons`: rimandato
- CTA WhatsApp in Fase 2: **non configurata in YouBook, gestita in WhatsApp Manager**
- miglioramento CTA WhatsApp (deep link app, CTA avanzate lato app): **rimandato alla Fase 3**

## 10) Piano operativo Fase 2
### Sprint 2.1 - Data model + configuratore base
- estendere entity/mappers template con `whatsappConfig`
- UI configuratore parametri reminder/promotion
- validazioni base mapping

### Sprint 2.2 - Preview + coerenza template
- preview con simulazione parametri testo
- check consistenza con componenti template Meta (body/header)

### Sprint 2.3 - Integrazione moduli
- aggancio in `Automazione`, `Promozioni`, `Manuali`
- filtri per `usage`
- warning template non valido/non attivo

### Sprint 2.4 - Backend completo
- reminder con bindings estesi
- invio promotion WhatsApp senza gestione CTA lato app
- audit/tracing allineato in `message_outbox`

## 11) Anticipo Fase 3 (CTA WhatsApp)
In Fase 3 verra estesa la CTA WhatsApp con:

- deep link verso pagine specifiche dell'app
- gestione target multipli CTA
- regole avanzate di validazione e fallback CTA
