# Arrivi dal web — piano di implementazione

## Obiettivo

Permettere a ogni salone di pubblicare sul proprio sito un link verso un modulo
anagrafico pubblico YouBook. I dati inviati non diventano immediatamente clienti:
arrivano nel modulo **Clienti**, nel nuovo tab **Arrivi dal web**, dove il salone
può verificarli, gestire eventuali duplicati e decidere se creare o aggiornare
un'anagrafica cliente.

L'MVP riguarda esclusivamente la raccolta anagrafica. Non include prenotazioni,
scelta di servizi, pagamenti o creazione automatica dell'account cliente.

## Flusso utente

1. Il salone configura e attiva il modulo dalle impostazioni YouBook.
2. YouBook genera un URL pubblico univoco, ad esempio
   `https://<dominio>/registrazione/<salonSlug>`.
3. Il salone collega l'URL a un pulsante del proprio sito, per esempio
   **Registrati** o **Lascia i tuoi dati**.
4. Il visitatore apre la pagina, compila il modulo anagrafico, prende visione
   dell'informativa privacy e invia i dati.
5. Il backend valida la richiesta, applica i controlli anti-abuso e salva un
   nuovo arrivo web in stato `new`.
6. Il salone vede il nuovo elemento nel tab **Clienti > Arrivi dal web**.
7. Il salone può:
   - creare un nuovo cliente;
   - collegare e integrare un cliente esistente;
   - rifiutare o archiviare la richiesta;
   - contattare il richiedente;
   - facoltativamente inviare, in un secondo momento, l'invito all'app cliente.

## Scelta architetturale

Gli arrivi web devono essere separati dalla raccolta `clients`. Un invio pubblico
potrebbe essere incompleto, duplicato o indesiderato e non deve contaminare
l'anagrafica definitiva.

Si introduce quindi una raccolta dedicata:

```text
web_client_requests/{requestId}
```

Le richieste dell'app esistenti (`salon_access_requests`) restano separate perché
sono associate a un utente autenticato. Un arrivo dal sito è invece anonimo e
non possiede necessariamente un account YouBook. La logica comune di
normalizzazione, ricerca duplicati e conversione in cliente dovrà essere
riutilizzata o estratta in un servizio condiviso.

## Modello dati proposto

```text
WebClientRequest
  id: string
  salonId: string
  firstName: string
  lastName: string
  phone: string?
  normalizedPhone: string?
  email: string?
  normalizedEmail: string?
  dateOfBirth: timestamp?
  extraData: map
    city: string?
    profession: string?
    gender: string?
    referralSource: string?
    notes: string?
  status: new | accepted | rejected | archived
  source: website
  sourceUrl: string?
  referrer: string?
  utmSource: string?
  utmMedium: string?
  utmCampaign: string?
  consents:
    privacyAccepted: bool
    privacyAcceptedAt: timestamp
    privacyVersion: string
    marketingAccepted: bool
    marketingAcceptedAt: timestamp?
  duplicateCandidateClientIds: string[]
  linkedClientId: string?
  createdAt: timestamp
  updatedAt: timestamp
  processedAt: timestamp?
  processedBy: string?
```

Telefono o email devono essere richiesti come recapito minimo; nome e cognome
sono obbligatori. I valori normalizzati servono solo per ricerca e deduplicazione.

## Configurazione per salone

Estendere `ClientRegistrationSettings` o introdurre una configurazione web
dedicata contenente:

- `webFormEnabled`;
- `publicSlug` univoco e stabile;
- campi visibili;
- campi obbligatori;
- titolo e testo introduttivo;
- testo del pulsante di invio;
- messaggio di conferma;
- versione e URL dell'informativa privacy;
- consenso marketing abilitato/disabilitato;
- notifica al salone abilitata/disabilitata;
- eventuali impostazioni grafiche base: logo, colore e immagine copertina.

Nel pannello del salone devono essere disponibili:

- copia del link pubblico;
- apertura dell'anteprima;
- attivazione/disattivazione del modulo;
- rigenerazione o modifica controllata dello slug;
- in una fase successiva, QR code e codice `iframe`.

## Pagina pubblica

Creare una pagina responsive raggiungibile senza autenticazione. La pagina carica
esclusivamente i dati pubblici e la configurazione del salone dalla raccolta
`public_salons`.

Campi MVP:

- nome;
- cognome;
- telefono;
- email;
- data di nascita, se abilitata;
- campi aggiuntivi configurati dal salone;
- presa visione/accettazione privacy obbligatoria;
- consenso marketing distinto e facoltativo.

La pagina deve gestire:

- caricamento e salone non disponibile;
- validazione accessibile lato client;
- invio in corso senza doppi submit;
- errore recuperabile;
- conferma finale senza mostrare dati sensibili nell'URL.

Per l'MVP il salone inserisce un normale link nel proprio sito. L'incorporamento
con `iframe` rimane una fase successiva per ridurre complessità, problemi di CORS,
dimensionamento e compatibilità con i vari CMS.

## Endpoint pubblico e sicurezza

Il form non deve scrivere direttamente in Firestore. Deve invocare una Cloud
Function HTTPS dedicata, per esempio:

```text
POST /public/client-registration
```

Responsabilità dell'endpoint:

1. validare `salonId`/slug e verificare che il modulo sia attivo;
2. accettare solo i campi previsti dalla configurazione del salone;
3. normalizzare email, telefono e testi;
4. imporre limiti di lunghezza e rifiutare payload inattesi;
5. verificare CAPTCHA o meccanismo anti-bot equivalente;
6. applicare rate limiting per salone e origine tecnica della richiesta;
7. impedire invii ripetuti ravvicinati;
8. cercare candidati duplicati nello stesso salone;
9. registrare data e versione dei consensi;
10. creare soltanto `web_client_requests`, mai direttamente `clients`;
11. restituire una risposta generica che non riveli l'esistenza di un cliente;
12. produrre log tecnici senza dati personali non necessari.

Le regole Firestore devono impedire la creazione anonima diretta e consentire la
lettura/gestione degli arrivi solo ad amministratori e staff autorizzati per il
salone associato.

## Tab “Arrivi dal web”

Il modulo Clienti passa a cinque tab:

```text
Ricerca | Ricerca avanzata | Richieste | Arrivi dal web | Ultimi
```

Il nuovo tab include:

- badge con il numero di richieste `new`;
- ordinamento dalla più recente;
- filtri per stato e intervallo temporale;
- ricerca per nome, telefono ed email;
- dati anagrafici e data di arrivo;
- provenienza e parametri campagna, quando presenti;
- indicazione del consenso marketing;
- avviso di possibile duplicato;
- azioni **Crea cliente**, **Collega a cliente**, **Rifiuta/Archivia** e
  **Contatta**.

### Creazione di un nuovo cliente

1. Aprire un'anteprima modificabile con i dati ricevuti.
2. Ricontrollare i duplicati sul server al momento della conferma.
3. Assegnare il numero cliente con la logica esistente.
4. Creare il documento `clients` in modo transazionale/idempotente.
5. Impostare la richiesta come `accepted`, con `linkedClientId`, `processedAt`
   e `processedBy`.
6. Non creare automaticamente un account Firebase/Auth.
7. Proporre separatamente l'eventuale invito all'app.

### Collegamento a un cliente esistente

- mostrare i candidati trovati per email o telefono;
- richiedere una scelta esplicita dell'operatore;
- presentare un confronto tra valori esistenti e valori ricevuti;
- non sovrascrivere automaticamente dati valorizzati senza conferma;
- salvare `linkedClientId` e lo stato finale sulla richiesta.

### Idempotenza

L'approvazione deve essere eseguita dal backend. Una richiesta già elaborata non
può creare un secondo cliente in seguito a doppio click, retry o concorrenza tra
due operatori.

## Notifiche

Per l'MVP:

- badge nel tab Clienti;
- aggiornamento in tempo reale tramite listener Firestore;
- opzionalmente notifica email al salone, se configurata.

Push, WhatsApp e automazioni successive non sono bloccanti per il primo rilascio.

## Privacy e conservazione

- L'accettazione dell'informativa privacy è obbligatoria.
- Il consenso marketing è separato, facoltativo e non preselezionato.
- Devono essere memorizzati timestamp e versione del testo mostrato.
- Non raccogliere dati tecnici o personali non necessari.
- Definire una politica di conservazione per richieste rifiutate o mai elaborate.
- Testi, basi giuridiche e tempi di conservazione devono essere validati con il
  referente privacy del prodotto prima della pubblicazione.

## Fasi di implementazione

### Fase 1 — Dominio e configurazione

- creare entità `WebClientRequest` e relativi enum;
- estendere la configurazione registrazione del salone;
- aggiungere mapper Firestore e stato/provider;
- aggiornare mock data e test dei mapper;
- sincronizzare nel profilo pubblico solo la configurazione necessaria.

### Fase 2 — Backend pubblico

- implementare endpoint HTTPS;
- validazione e normalizzazione condivise;
- protezione anti-bot e rate limiting;
- deduplicazione preliminare;
- regole e indici Firestore;
- test unitari e test con emulatori.

### Fase 3 — Form pubblico

- routing `/registrazione/:slug`;
- caricamento dati pubblici del salone;
- form dinamico e responsive;
- gestione consensi, errori e conferma;
- test mobile, desktop e accessibilità base.

### Fase 4 — Gestione nel modulo Clienti

- nuovo tab e badge;
- lista, filtri e dettaglio richiesta;
- creazione nuovo cliente;
- collegamento/merge controllato;
- rifiuto e archiviazione;
- test UI e test della concorrenza/idempotenza.

### Fase 5 — Impostazioni salone e rilascio

- attivazione del modulo;
- gestione campi e testi;
- link copiabile e anteprima;
- metriche minime e monitoraggio errori;
- documentazione per inserire il link nei siti dei saloni.

## Criteri di accettazione MVP

- Ogni salone può attivare un proprio URL pubblico.
- Il modulo mostra logo/nome e i campi configurati per quel salone.
- Un visitatore anonimo può inviare dati validi senza creare un account.
- Nessun visitatore può scrivere direttamente nelle raccolte Firestore.
- Ogni invio valido compare in **Clienti > Arrivi dal web** in tempo reale.
- Il salone può creare un cliente nuovo oppure collegarne uno esistente.
- Email e telefono vengono controllati per possibili duplicati nello stesso salone.
- Un doppio invio dell'azione di approvazione non crea clienti duplicati.
- Il salone può rifiutare o archiviare una richiesta.
- I consensi conservano valore, timestamp e versione dell'informativa.
- Le richieste di un salone non sono visibili agli operatori di altri saloni.

## Fuori scope MVP

- prenotazione di appuntamenti;
- scelta di servizi o pacchetti;
- pagamenti;
- creazione automatica dell'account cliente;
- widget JavaScript o `iframe` incorporabile;
- QR code;
- form builder completamente libero;
- automazioni marketing avanzate;
- allegati o fotografie.

## Evoluzioni successive

- QR code scaricabile;
- widget incorporabile nel sito;
- personalizzazione grafica avanzata;
- campagne e report UTM;
- risposta automatica email/WhatsApp;
- conversione da arrivo web ad appuntamento;
- statistiche su invii, clienti creati e tasso di conversione.
