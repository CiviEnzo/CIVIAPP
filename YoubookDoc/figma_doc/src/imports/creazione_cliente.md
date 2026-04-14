# Registrazione e gestione clienti

Questo documento descrive il nuovo flusso di registrazione cliente, le
impostazioni amministrative e la creazione manuale da backoffice.

## 1. Registrazione account cliente (app)

1. **Dati obbligatori** raccolti nella schermata
   `ClientRegistrationScreen`:
   - Nome
   - Cognome
   - Data di nascita (input da tastiera con helper sul formato)
   - Email (univoca)
   - Numero di telefono
   - Password

   L’account Firebase viene creato come `client` e i valori inseriti
   vengono salvati in un draft locale per il passo successivo.

2. **Scelta del salone e completamento** (`OnboardingScreen`)
   - L’utente seleziona il salone di riferimento.
   - Il salone espone le proprie regole di registrazione (vedi §2).
   - Se il salone è **aperto**, l’app richiede eventuali campi
     aggiuntivi obbligatori, crea il documento `Client` e assegna il
     numero progressivo.
   - Se il salone è **a invito/valutazione**, l’app crea un documento
     `salon_access_requests/{requestId}` in stato `pending`. L’utente
     riceve conferma della richiesta e l’onboarding termina in attesa di
     approvazione.

## 2. Impostazioni di registrazione (modulo Salone)

Nel form `SalonFormSheet` è presente la sezione **Registrazione clienti**
che popola il campo `clientRegistration` del documento salone.

Opzioni disponibili:

- **Modalità di accesso**
  - `aperto`: il cliente completa autonomamente l’iscrizione.
  - `solo_approvazione`: la richiesta viene messa in coda per l’admin.
- **Campi aggiuntivi obbligatori** (checkbox):
  - Indirizzo
  - Professione
  - Come ci ha conosciuto?
  - Note

Le impostazioni sono serializzate in Firestore e lette dall’onboarding
per applicare la validazione dinamica.

## 3. Gestione richieste accesso salone

- I saloni in modalità `solo_approvazione` raccolgono le richieste nella
  collezione `salon_access_requests/{requestId}` con i campi:
  `salonId`, `userId`, `firstName`, `lastName`, `email`, `phone`,
  `dateOfBirth`, `extraData`, `status`, `createdAt`, `updatedAt`.
- L’admin visualizza le richieste in una sezione dedicata del modulo
  `Clienti` con azioni **Approva** / **Rifiuta**.
  - Approva: viene creato il `Client`, assegnato il numero progressivo
    e aggiornato l’utente Firebase con `clientId` e `salonIds`.
  - Rifiuta: la richiesta è marcata `rejected`; il cliente resta senza
    salone associato.
- Tutte le operazioni passano da nuovi metodi di
  `AppDataStore` (`approveSalonAccessRequest`, `rejectSalonAccessRequest`)
  e sono protette da regole Firestore che limitano la creazione alle app
  client e la gestione a staff/admin del salone.

## 4. Creazione manuale cliente (backoffice)

Il backoffice continua ad utilizzare `ClientFormSheet` con validazione
tempo reale.

### Campi obbligatori
- Nome e cognome
- Salone di appartenenza
- Telefono
- Email
- Data di nascita
- Origine del contatto

### Campi opzionali
- Indirizzo, professione, note
- Preferenze di contatto
- Parametri fedeltà

### Numerazione cliente
- Assegnata automaticamente al salvataggio tramite incremento atomico
  del documento `salon_sequences/<salonId>`.
- Sequenza monotona (nessun riutilizzo dei numeri).

## 5. Persistenza su Firestore

- `clients/{clientId}`: anagrafica, stato onboarding e preferenze.
- `salon_access_requests/{requestId}`: richieste di adesione pendenti.
- `salon_sequences/{salonId}`: ultimo numero progressivo generato.

## 6. Considerazioni progettuali

- Evitare modifiche manuali alle collezioni precedenti.
- Garantire idempotenza dei flussi di approvazione (un client non deve
  essere creato due volte).
- Aggiornare le regole Firestore in base ai nuovi campi e collezioni.
- Documentare eventuali estensioni (es. nuovi campi extra) sia lato app
  sia lato amministratore.
