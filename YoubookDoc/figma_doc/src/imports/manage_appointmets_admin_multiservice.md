# Gestione appuntamenti multi-servizio con pacchetti multi-sessione

## Obiettivo
Introdurre nel pannello admin la possibilità di compilare appuntamenti con più servizi legati allo stesso cliente, consentendo l'utilizzo combinato di:
- più pacchetti all'interno dello stesso appuntamento;
- pacchetti che includono sessioni di servizi differenti (pacchetti “misti”).

Il nuovo flusso deve permettere all'operatore di selezionare, per ogni servizio in appuntamento, da quale pacchetto scalare le sessioni disponibili e in quale quantità.

## Requisiti funzionali
1. **Selezione servizi**  
   - Possibile selezionare n servizi nello stesso appuntamento (scenario già supportato, resta invariato).
   - Per ogni servizio è necessario indicare quante “unità” vengono erogate (di default 1, ma estensibile per servizi che accumulano durata).

2. **Visualizzazione pacchetti**  
   - Dopo aver scelto il cliente, l’interfaccia mostra tutti i pacchetti attivi (anche se non compatibili con i servizi correnti).
   - Per ogni pacchetto vengono evidenziati i servizi inclusi e le sessioni residue per ciascun servizio.
   - Le combinazioni servizio/pacchetto non compatibili risultano disabilitate ma visibili.

3. **Scalata sessioni**  
   - L’admin assegna manualmente, per ogni servizio, un pacchetto da cui scalare.  
   - È possibile combinare più pacchetti nello stesso appuntamento (es. Servizio A da Pacchetto 1, Servizio B da Pacchetto 2).  
   - Se un servizio richiede più unità di quante disponibili su un singolo pacchetto, è possibile suddividere la scalata su più pacchetti o marcare le unità eccedenti come “fuori pacchetto”.

4. **Consumi multipli**  
   - Un pacchetto può coprire più servizi dello stesso appuntamento se include sessioni compatibili e ha disponibilità residua.
   - Deve essere gestita la scalata parziale: se il pacchetto offre 2 sessioni e l’appuntamento ne consuma 1, bisogna registrare correttamente il residuo (1).

5. **Salvataggio**  
   - Ogni appuntamento salva un array di “consumi pacchetto” in cui è tracciato: `serviceId`, `packageReferenceId`, `quantity`, `sessionType` (se necessario per differenziare categorie nel pacchetto).
   - Gli appuntamenti esistenti possono essere cancellati, quindi non è richiesta una migrazione automatica (semplifica il rollout).

6. **Suggerimento automatico**  
   - Il sistema propone automaticamente la ripartizione delle sessioni disponibili sui pacchetti compatibili.
   - Quando l’auto-allocazione non copre l’intero fabbisogno, l’admin può intervenire manualmente mantenendo pieno controllo sulle quantità.

## Data model proposto
```
Appointment {
  ...
  services: [
    {
      serviceId: string,
      durationMinutes: number,
      quantity: number,
      packageConsumptions: [
        {
          packageReferenceId: string,
          sessionTypeId?: string,   // opzionale, utile per pacchetti misti strutturati
          quantity: number,
        }
      ]
    },
    ...
  ],
  packageConsumptionsSummary: [
    {
      packageReferenceId: string,
      totalQuantity: number,        // somma delle quantity per reporting veloce
    }
  ]
}
```
Note:
- `packageReferenceId` rimanda all’identificativo univoco dell’acquisto (non al template del pacchetto).
- `sessionTypeId` è utile se il pacchetto codifica sessioni differenti (es. “massaggio” vs “sauna” nello stesso pacchetto).
- `quantity` consente di scalare più unità dello stesso servizio dal medesimo pacchetto.

## UI / UX
1. **Sezione servizi**  
   - Tabella/card con l’elenco dei servizi selezionati. Ogni riga mostra: nome servizio, durata totale, quantità, icona per aprire la scheda “Pacchetti”.

2. **Pannello pacchetti**  
   - Per il cliente selezionato, mostra un elenco di card. Ogni card include: nome pacchetto, data scadenza, saldo totale, e un’accordion con dettaglio delle sessioni per servizio.
   - All’interno della card, per ogni servizio compatibile, un controllo (es. spinner o input numerico) permette di assegnare quante unità usare per quel servizio in questo appuntamento.
   - Le combinazioni non compatibili sono visualizzate ma disabilitate con tooltip esplicativo.

3. **Riepilogo scalature**  
   - Sotto la lista dei servizi, un box riepiloga quali pacchetti verranno scalati (es. “Pacchetto Relax • 1 sessione di Massaggio, 1 sessione di Sauna”).
   - Se restano servizi senza copertura, viene mostrato un badge “Da pagare fuori pacchetto” con il totale delle unità scoperte.

4. **Validazioni e feedback**  
   - Blocco salvataggio se la quantità associata ai pacchetti supera la disponibilità residua.
   - Se la quantità assegnata non copre tutte le unità dei servizi, la UI mantiene lo stato ma mostra warning finché l’operatore non conferma esplicitamente (es. checkbox “Conferma incasso fuori pacchetto”).

## Allocazione automatica delle sessioni
- **Algoritmo**  
  1. Raccoglie i servizi selezionati (con quantità/durata) e la lista dei pacchetti del cliente con le sessioni disponibili per ciascun servizio.  
  2. Ordina le “domande” di sessione in base a criteri configurabili (es. servizi con minore disponibilità complessiva o scadenza pacchetto più vicina).  
  3. Per ogni servizio, assegna sessioni partendo dal pacchetto più “urgente”: se le unità richieste eccedono la disponibilità, consuma l’intero pacchetto e passa al successivo.  
  4. Restituisce una matrice `serviceId -> packageReferenceId -> quantity` da applicare all’appuntamento e al riepilogo.

- **Interazione con la UI**  
  - Le proposte automatiche vengono mostrate nella tabella servizi con badge “Suggerito”.  
  - Se il sistema non riesce a coprire tutto, evidenzia le righe scoperte con alert “Sessioni non sufficienti”.  
  - L’admin può modificare qualsiasi assegnazione: le righe manualmente toccate escono dal ricalcolo automatico finché non si clicca “Ripristina suggerimento”.

- **Validazioni**  
  - Prima del salvataggio, il sistema verifica che le sessioni allocate non superino i residui nel momento corrente.  
  - In caso di conflitti (es. consumo simultaneo da un altro operatore), viene rieseguito l’algoritmo e richiesto un nuovo intervento manuale.

## Flusso di prenotazione
1. Admin seleziona operatore → filtra i servizi compatibili.
2. Admin seleziona servizi (uno o più).
3. Dopo la scelta dei servizi:
   - l’algoritmo di allocazione propone automaticamente come distribuire le sessioni sui pacchetti compatibili;
   - il pannello pacchetti si aggiorna evidenziando le scelte suggerite e quelle ancora da completare;
   - se esiste un solo pacchetto disponibile per un servizio, viene precompilata tutta la scalata (comportamento configurabile).
4. Admin definisce la distribuzione delle sessioni sui pacchetti.
5. Admin conferma data/ora e salva l’appuntamento.

## Logica di scalatura lato dominio
0. Suggerimento automatico:
   - Prima di salvare, il dominio espone un servizio `SessionAllocator` che riceve servizi selezionati e pacchetti disponibili, esegue l’algoritmo descritto sopra e restituisce la proposta da applicare nello sheet.

1. Quadro generale:
   - Alla conferma dell’appuntamento, i consumi vengono salvati nell’entità `Appointment`.
   - Al completamento dell’appuntamento (o al momento di “chiudere” la prestazione), la logica `appointments` applica le scalature effettive aggiornando i `ClientPackagePurchase`.

2. Regole di scalatura:
   - Ridurre `effectiveRemainingSessions` del pacchetto per il servizio specificato.
   - Se un pacchetto esaurisce tutte le sessioni, segnarlo come “Non più disponibile” per i futuri appuntamenti.
   - In caso di annullamento appuntamento prima dell’esecuzione, ripristinare le sessioni scalate (invertendo i consumi).

3. Gestione errori:
   - Se durante il salvataggio le sessioni non sono più sufficienti (condizione race con altre prenotazioni), lo sheet deve ricaricare lo stato del pacchetto e richiedere un nuovo input all’admin.

## Backend e persistenza (Firestore)
- **Collezione Appointments**  
  - Serializzare la nuova struttura `packageConsumptions` dentro ogni servizio.
  - Aggiornare le cloud functions / repository per leggere e scrivere il nuovo schema.

- **Collezione ClientPackagePurchase**  
  - Aggiungere metadati opzionali per sessioni specifiche (es. `serviceIdsSupported`, `sessionTypes`).
  - Introdurre un metodo atomico per scalare più servizi in una singola operazione, evitando condizioni di race.

- **API/UI bridging**  
  - Adeguare i DTO e le funzioni remota a trasmettere il nuovo payload.

## Frontend (Flutter)
- **Model aggiornati**  
  - Estendere `Appointment` e `AppointmentBuilder` con i nuovi campi.
  - Aggiornare provider Riverpod per manipolare la mappa `serviceId -> consumi`.

- **Sheet**  
  - Refactor di `_PackageSelectionList` per gestire controlli per servizio, probabilmente introducendo un nuovo widget per la matrice `servizi x pacchetti`.
  - Gestire stato locale delle quantità e sincronia con `_serviceIds`.

- **Validazioni**  
  - Aggiornare il `FormState` in modo da validare le quantità assegnate ai pacchetti prima del submit.
  - Mostrare errori inline quando l’input è incoerente.

## Considerazioni addizionali
- Reportistica: aggiornare calcoli di fatturato/pacchetti per leggere il nuovo formato.
- Notifiche/Reminder: nessun impatto diretto, ma eventuali template che menzionano il pacchetto devono leggere dal nuovo schema.
- Testing: coprire i casi
  - scalatura multipla con pacchetti differenti,
  - scalatura parziale + residuo,
  - annullamento con ripristino,
  - assegnazione manuale vs auto-suggerita.

## Prossimi passi
1. Allineamento interno sul data model proposto. ✅ (in corso: entità, mapper e repository aggiornati con `serviceAllocations`)
2. Implementazione SessionAllocator con logica di suggerimento automatica. ✅
3. Implementazione UI (sezione servizi + matrice pacchetti).
4. Aggiornamento logica di scalatura e test end-to-end. (scalata implementata lato dominio; test da completare)
