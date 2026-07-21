# Modulo Uscite

## Obiettivo
Introdurre un nuovo modulo admin per gestire le uscite economiche del salone, separato da `Vendite & Cassa` ma integrato con calendario, agenda e report.

Il modulo deve permettere all'admin di:
- configurare le voci di uscita;
- inserire uscite singole;
- inserire uscite ricorrenti;
- segnare una o piu' uscite come pagate;
- visualizzare le uscite in un calendario dedicato;
- scegliere se mostrare un indicatore delle uscite anche nell'agenda;
- aggiornare i report con entrate, uscite, netto e KPI economici;
- ricercare, modificare, annullare o cancellare uscite singole e ricorrenti.

## Navigazione admin
Inserire nella barra sinistra del pannello admin un nuovo modulo:

- **Titolo:** `Uscite`
- **Id consigliato:** `expenses`
- **Icona consigliata:** `FontAwesomeIcons.fileInvoiceDollar`, `FontAwesomeIcons.moneyBillTransfer` oppure `Icons.receipt_long_outlined`
- **Posizione consigliata:** area economica/gestionale, vicino a `Vendite & Cassa` e `Report`
- **Route/query:** `/admin?module=expenses`
- **Badge opzionale:** numero di uscite scadute o in pagamento nei prossimi 7 giorni

La struttura admin passa quindi da 12 a 13 moduli:
1. Panoramica
2. Saloni
3. Staff
4. Clienti
5. Movimenti App
6. Agenda
7. Servizi & Pacchetti
8. Magazzino
9. Vendite & Cassa
10. Uscite
11. Messaggi & Marketing
12. WhatsApp
13. Report

## Terminologia
- **Voce di uscita:** categoria configurabile dall'admin, ad esempio affitto, utenze, stipendi, prodotti, marketing, tasse, manutenzione.
- **Uscita:** movimento economico passivo registrato manualmente o generato da una ricorrenza.
- **Uscita ricorrente:** regola che genera uscite nel tempo, ad esempio affitto mensile o software annuale.
- **Istanza ricorrente:** singola uscita generata da una regola ricorrente.
- **Pagata:** uscita saldata, con data pagamento e metodo pagamento.
- **Da pagare:** uscita non ancora saldata.
- **Scaduta:** uscita non pagata con data scadenza precedente a oggi.
- **Annullata:** uscita non valida ma conservata per storico/audit.
- **Cancellata:** eliminazione logica, non hard delete.

## Funzionalita del modulo

### 1. Configurare le voci di uscita
L'admin deve poter creare e gestire le voci/categorie di uscita.

Campi minimi:
- nome voce;
- descrizione opzionale;
- colore o icona per calendario/report;
- stato `attiva` / `disattivata`;
- gruppo report, ad esempio costi fissi, costi variabili, personale, fiscale, marketing;
- budget mensile opzionale;
- metodo pagamento predefinito opzionale;
- flag `richiede allegato` opzionale, utile per fatture o ricevute;
- ordinamento nella UI.

Regole:
- una voce disattivata non puo' essere scelta per nuove uscite;
- le uscite storiche mantengono la voce anche se questa viene disattivata;
- non permettere nomi duplicati nello stesso salone, ignorando maiuscole/minuscole e spazi finali.

### 2. Inserire un'uscita singola
Dal modulo `Uscite` deve essere presente una CTA primaria `Nuova uscita`.

Campi minimi del form:
- salone di riferimento;
- voce di uscita;
- titolo/descrizione breve;
- fornitore o beneficiario opzionale;
- importo totale;
- importo imponibile e IVA opzionali;
- data competenza;
- data scadenza;
- stato pagamento;
- data pagamento, obbligatoria se lo stato e' `pagata`;
- metodo pagamento, ad esempio contanti, POS, carta, bonifico, app, altro;
- note interne;
- allegato opzionale, ad esempio fattura o ricevuta;
- tag opzionali.

Stati disponibili:
- `da_pagare`;
- `pagata`;
- `annullata`.

Stati derivati lato UI/report:
- `in_scadenza`, se non pagata e scade entro N giorni;
- `scaduta`, se non pagata e la scadenza e' nel passato.

Validazioni:
- importo maggiore di zero;
- data pagamento non precedente alla data competenza, salvo override con conferma;
- metodo pagamento obbligatorio quando l'uscita viene segnata come pagata;
- voce di uscita obbligatoria.

### 3. Inserire un'uscita ricorrente
Dal modulo deve essere presente una CTA `Nuova ricorrente`.

Campi minimi:
- voce di uscita;
- titolo;
- importo;
- fornitore/beneficiario opzionale;
- frequenza: settimanale, mensile, trimestrale, semestrale, annuale;
- data inizio;
- data fine opzionale;
- giorno di generazione/scadenza;
- metodo pagamento predefinito opzionale;
- note;
- allegato opzionale comune alla serie.

Comportamento:
- mostrare anteprima delle prossime occorrenze prima del salvataggio;
- generare le istanze future in modo controllato, ad esempio 12 mesi in avanti;
- ogni istanza deve poter essere modificata, pagata o annullata singolarmente;
- modificando una ricorrenza gia' esistente, chiedere se applicare la modifica a:
  - solo questa uscita;
  - questa e le future;
  - tutta la serie.

Regole ricorrenza:
- se una ricorrenza mensile cade il giorno 31 e il mese non lo contiene, usare l'ultimo giorno del mese;
- se una ricorrenza cade in un giorno di chiusura, mantenerla comunque nel calendario economico; non e' un appuntamento operativo;
- non rigenerare duplicati: usare `recurrenceRuleId + occurrenceDate` come vincolo logico.

### 4. Segnare un'uscita come pagata
L'admin deve poter segnare come pagata:
- una singola uscita;
- piu' uscite selezionate dalla lista;
- una singola istanza ricorrente.

Azioni disponibili:
- `Segna come pagata`;
- `Segna come da pagare`, solo se serve correggere un errore;
- `Annulla uscita`;
- `Modifica pagamento`.

Campi richiesti al pagamento:
- data pagamento;( di default è la data odierna)
- metodo pagamento;
- importo pagato, default uguale al totale;
- nota pagamento opzionale;
- utente che registra il pagamento.

Per MVP e' sufficiente considerare un'uscita come pagata interamente. Per una fase successiva si puo' introdurre il pagamento parziale con `paidAmount` e storico movimenti.

### 5. Visualizzare le uscite sul calendario
Il modulo deve includere una vista calendario dedicata alle uscite.

Viste:
- mese;
- settimana;
- lista cronologica.

Ogni elemento calendario mostra:
- titolo;
- importo;
- voce/categoria;
- stato pagamento;
- indicatore di ricorrenza se generato da una serie.

Colori/stati:
- pagata: stato positivo/neutro;
- da pagare: stato informativo;
- in scadenza: warning;
- scaduta: danger;
- annullata: neutro disattivato.

Interazioni:
- click su giorno vuoto: crea nuova uscita con data precompilata;
- click su uscita: apre dettaglio con azioni rapide;
- drag & drop opzionale: sposta scadenza con conferma;
- filtri per voce, stato, salone, metodo pagamento, ricorrenza.

### 6. Toggle per visualizzare le uscite anche nell'agenda
Nel modulo `Uscite` aggiungere un'impostazione:

- **Label:** `Mostra uscite in agenda`
- **Default:** disattivato
- **Scope:** per salone e per utente admin, da decidere in implementazione; consigliato salone + preferenza utente per non forzare tutti gli admin.

Quando il toggle e' attivo:
- nell'agenda admin compare una piccola icona nel giorno in cui sono presenti uscite;
- l'icona deve stare nella testata del giorno o in un punto che non interferisce con gli appuntamenti;
- se ci sono piu' uscite nello stesso giorno, mostrare contatore, ad esempio icona + `3`;
- hover/tap apre un popover compatto con titolo, importo e stato;
- il click sul popover puo' aprire il modulo `Uscite` filtrato su quel giorno.

Regole:
- non mostrare le uscite nell'agenda cliente;
- per lo staff mostrare le uscite solo se esiste un permesso esplicito;
- l'indicatore non deve occupare slot orari e non deve creare conflitti con appuntamenti, turni o assenze.

### 7. Aggiornare il modulo Report
Il modulo `Report` deve includere le uscite nei calcoli economici, mantenendo visibili sia le entrate sia le uscite.

Nuove metriche principali:
- **Entrate totali:** somma vendite/incassi nel periodo.
- **Uscite totali:** somma uscite nel periodo.
- **Netto:** entrate totali meno uscite totali.
- **Margine netto percentuale:** netto / entrate totali.
- **Uscite pagate:** totale uscite saldate.
- **Uscite da pagare:** totale uscite non saldate.
- **Uscite scadute:** totale e numero delle uscite oltre scadenza.
- **Uscite ricorrenti previste:** impegno economico futuro generato dalle ricorrenze.
- **Cash flow previsto:** entrate stimate da agenda meno uscite future pianificate.

Nuove analisi:
- uscite per voce/categoria;
- uscite per gruppo report, ad esempio fissi, variabili, personale, marketing;
- andamento entrate/uscite/netto nel tempo;
- incidenza delle uscite sulle entrate;
- confronto periodo corrente vs periodo precedente;
- top voci di uscita;
- breakdown per metodo pagamento;
- scadenzario uscite future;
- proiezione mensile del netto.

KPI consigliati:
- `revenue_total`: entrate;
- `expenses_total`: uscite;
- `net_profit`: netto;
- `net_margin`: margine netto;
- `paid_expenses_total`: uscite pagate;
- `unpaid_expenses_total`: uscite da pagare;
- `overdue_expenses_count`: numero uscite scadute;
- `overdue_expenses_total`: valore uscite scadute;
- `recurring_monthly_commitment`: costo ricorrente mensile stimato;
- `expense_to_revenue_ratio`: incidenza costi su entrate;
- `cashflow_forecast_30d`: previsione cassa prossimi 30 giorni.

Aggiornamenti tecnici al report:
- estendere `ReportsSnapshot` con `filteredExpenses`;
- estendere `ReportsAggregator` per includere le uscite filtrate per salone e periodo;
- aggiungere sezione analytics `Uscite`;
- aggiungere dataset export `expenses`;
- aggiornare export CSV/PDF con entrate, uscite e netto;
- aggiungere filtri per voce uscita, stato pagamento e ricorrenza;
- usare timezone del salone per filtri e aggregazioni giornaliere.

### 8. Ricerca, modifica e cancellazione
Il modulo deve avere una lista ricercabile con filtri avanzati.

Filtri:
- testo libero su titolo, note, fornitore;
- voce di uscita;
- stato pagamento;
- periodo competenza;
- periodo scadenza;
- periodo pagamento;
- importo da/a;
- metodo pagamento;
- ricorrente / non ricorrente;
- allegato presente / assente.

Azioni:
- modifica uscita;
- duplica uscita;
- segna come pagata;
- annulla uscita;
- cancella uscita;
- cancella ricorrenza.

Cancellazione:
- usare soft delete, non hard delete;
- salvare `deletedAt`, `deletedBy`, `deleteReason`;
- escludere le uscite cancellate da calendario, agenda e report;
- permettere ripristino solo ad admin, se previsto.

Cancellazione ricorrenti:
- cancellare solo l'istanza selezionata;
- cancellare questa e le future;
- cancellare tutta la serie;
- mantenere audit trail delle istanze gia' pagate.

## Modello dati consigliato

### `expense_categories`
```json
{
  "id": "categoryId",
  "salonId": "salonId",
  "name": "Affitto",
  "description": "Canone mensile locale",
  "color": "#7C3AED",
  "icon": "receipt_long",
  "reportGroup": "fixed_costs",
  "monthlyBudget": 1200.0,
  "defaultPaymentMethod": "bank_transfer",
  "requiresAttachment": false,
  "isActive": true,
  "sortOrder": 10,
  "createdAt": "serverTimestamp",
  "createdBy": "uid",
  "updatedAt": "serverTimestamp",
  "updatedBy": "uid"
}
```

### `expenses`
```json
{
  "id": "expenseId",
  "salonId": "salonId",
  "categoryId": "categoryId",
  "title": "Affitto luglio",
  "supplierName": "Immobiliare Rossi",
  "amount": 1200.0,
  "taxAmount": 0.0,
  "totalAmount": 1200.0,
  "currency": "EUR",
  "competenceDate": "2026-07-01",
  "dueDate": "2026-07-05",
  "paymentDate": null,
  "paymentMethod": null,
  "status": "da_pagare",
  "notes": "",
  "tags": ["affitto", "fisso"],
  "attachmentUrls": [],
  "isRecurring": true,
  "recurrenceRuleId": "ruleId",
  "occurrenceDate": "2026-07-05",
  "createdAt": "serverTimestamp",
  "createdBy": "uid",
  "updatedAt": "serverTimestamp",
  "updatedBy": "uid",
  "deletedAt": null,
  "deletedBy": null,
  "deleteReason": null
}
```

### `expense_recurring_rules`
```json
{
  "id": "ruleId",
  "salonId": "salonId",
  "categoryId": "categoryId",
  "title": "Affitto locale",
  "supplierName": "Immobiliare Rossi",
  "amount": 1200.0,
  "taxAmount": 0.0,
  "totalAmount": 1200.0,
  "currency": "EUR",
  "frequency": "monthly",
  "interval": 1,
  "startDate": "2026-01-01",
  "endDate": null,
  "dueDay": 5,
  "defaultPaymentMethod": "bank_transfer",
  "notes": "",
  "isActive": true,
  "createdAt": "serverTimestamp",
  "createdBy": "uid",
  "updatedAt": "serverTimestamp",
  "updatedBy": "uid",
  "cancelledAt": null,
  "cancelledBy": null
}
```

### `expense_settings`
```json
{
  "salonId": "salonId",
  "showExpensesInAgenda": false,
  "agendaIndicatorMode": "icon_with_count",
  "upcomingWarningDays": 7,
  "updatedAt": "serverTimestamp",
  "updatedBy": "uid"
}
```

## UI proposta

### Tab del modulo
1. **Dashboard**
   - KPI rapidi: mese corrente, da pagare, scadute, ricorrenti attive.
   - CTA: `Nuova uscita`, `Nuova ricorrente`.
2. **Uscite**
   - tabella/lista con ricerca e filtri.
   - azioni rapide su riga.
3. **Ricorrenti**
   - elenco regole ricorrenti.
   - anteprima prossime occorrenze.
4. **Calendario**
   - calendario economico mese/settimana/lista.
5. **Configurazione**
   - voci di uscita.
   - toggle agenda.
   - preferenze scadenze.

### Stati UI
- loading con skeleton;
- empty state con CTA `Crea la prima voce di uscita`;
- empty state lista con CTA `Nuova uscita`;
- errore con retry;
- warning se non esistono voci attive;
- warning se ci sono uscite scadute.

## Permessi e sicurezza
- Admin: accesso completo.
- Staff: nessun accesso di default.
- Staff autorizzato: permessi separati per vedere, creare, modificare, segnare pagata.
- Ogni scrittura deve salvare `createdBy` / `updatedBy`.
- Ogni cancellazione deve essere logica e tracciata.
- Le regole Firestore devono limitare lettura/scrittura al `salonId` dell'utente autorizzato.
- Gli allegati devono essere salvati in path Storage scoped per salone e uscita.

## Integrazioni

### Agenda
- recuperare il conteggio uscite per giorno solo quando il toggle e' attivo;
- mostrare indicatore compatto nel calendario admin;
- click su indicatore apre popover e deep link al modulo `Uscite` filtrato per data.

### Report
- includere uscite nei KPI economici;
- aggiungere export CSV/PDF;
- aggiungere grafici entrate/uscite/netto;
- aggiungere sezione scadenzario.

### Vendite & Cassa
- non mescolare le uscite nella lista vendite;
- le uscite influenzano solo report economici, cash flow e panoramica;
- eventuale integrazione futura con prima nota/cassa puo' registrare movimenti di cassa in entrata e uscita.

### Panoramica admin
- aggiungere card opzionale:
  - uscite mese corrente;
  - uscite scadute;
  - netto mese corrente;
  - prossime uscite ricorrenti.

## Indici Firestore consigliati
- `expenses`: `salonId, dueDate`
- `expenses`: `salonId, competenceDate`
- `expenses`: `salonId, paymentDate`
- `expenses`: `salonId, status, dueDate`
- `expenses`: `salonId, categoryId, competenceDate`
- `expenses`: `salonId, recurrenceRuleId, occurrenceDate`
- `expense_categories`: `salonId, isActive, sortOrder`
- `expense_recurring_rules`: `salonId, isActive, startDate`

## Checklist implementazione
- [ ] Creare entity/domain model `Expense`, `ExpenseCategory`, `ExpenseRecurringRule`, `ExpenseSettings`.
- [ ] Creare mapper Firestore e repository/store.
- [ ] Aggiungere collezioni e regole Firestore.
- [ ] Aggiungere modulo admin `ExpensesModule`.
- [ ] Inserire voce `Uscite` nella sidebar admin.
- [ ] Creare form `ExpenseFormSheet`.
- [ ] Creare form `RecurringExpenseFormSheet`.
- [ ] Creare manager voci uscita.
- [ ] Implementare generatore ricorrenze e prevenzione duplicati.
- [ ] Implementare lista, ricerca, filtri e azioni bulk.
- [ ] Implementare calendario uscite.
- [ ] Implementare toggle e indicatore in agenda admin.
- [ ] Estendere `ReportsSnapshot`, `ReportsAggregator`, UI report ed export.
- [ ] Aggiornare panoramica admin con KPI economici opzionali.
- [ ] Aggiungere test unitari su ricorrenze, filtri, KPI e soft delete.
- [ ] Aggiungere widget test per form, lista, calendario e agenda indicator.

## Criteri di accettazione
- L'admin vede il nuovo modulo `Uscite` nella sidebar.
- L'admin puo' creare, modificare e disattivare voci di uscita.
- L'admin puo' registrare un'uscita singola e ritrovarla in lista e calendario.
- L'admin puo' creare una ricorrenza e vedere le prossime istanze generate.
- L'admin puo' segnare un'uscita come pagata con data e metodo pagamento.
- Le uscite scadute sono evidenziate.
- Il toggle agenda mostra una piccola icona nei giorni con uscite, senza alterare gli slot appuntamento.
- Il report mostra entrate, uscite, netto e KPI economici.
- La ricerca trova uscite per testo, voce, stato, periodo e ricorrenza.
- La cancellazione e' logica e non rimuove dati storici gia' usati nei report.
- Le uscite cancellate o annullate non vengono conteggiate nei KPI ordinari.
