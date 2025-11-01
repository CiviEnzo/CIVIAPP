# Architettura Modulo Report

## 1. Obiettivi e ambito
- Centralizzare le metriche chiave (clienti, sedute, vendite, pacchetti) con filtri temporali e per operatore/salone.
- Garantire performance stabili anche su dataset ampi, con aggregazioni pre-calcolate dove opportuno.
- Offrire un'esperienza di consultazione unica per admin e operatori con viste sintetiche e drill-down.

## 2. Visione end-to-end
1. **Raccolta dati** da moduli esistenti (anagrafiche, agenda, vendite, pagamenti, pacchetti).
2. **Normalizzazione** tramite viste SQL/ETL leggere che uniformano timestamp, valute, riferimenti a salone/operatore.
3. **Servizi backend** dedicati (`ReportsService`) che eseguono aggregazioni parametrizzate e applicano la sicurezza.
4. **API REST/GraphQL** per fornire dati pronti al frontend (card riepilogo, grafici, tabelle).
5. **Frontend dashboard** con libreria grafica condivisa, filtri sincroni e esportazione dati.
6. **Caching e job schedulati** per snapshot giornaliere e proiezioni su agenda.

## 3. Data layer
- **Inventario tabelle esistenti**: `clients`, `appointments`, `sales`, `services`, `packages`, `payments`, `operators`, `stores`.
- **Campi obbligatori**: `created_at`, `executed_at`, `status`, `operator_id`, `store_id`, `service_id`, `payment_method`.
- **Normalizzazione date**: tutte le query usano timezone del salone; conversione lato DB tramite `AT TIME ZONE` o equivalente.
- **Viste/materialized views**
  - `mv_report_clients`: nuovi clienti, primi acquisti, prime sedute.
  - `mv_report_sales`: aggregazioni per servizio, categoria, prodotto, operatore.
  - `mv_report_appointments`: no-show, occupazione slot, proiezione agenda.
  - Aggiornamento tramite job pianificati (es. ogni 15 minuti) e ricalcolo manuale su richiesta.
- **Indici e partizionamento**: indici composite su `store_id, executed_at` e `operator_id, executed_at`; valutare partizioni mensili per tabelle voluminose (es. `appointments`).
- **Dati storici**: conservare raw data per analisi future; eventuale archivio freddo in storage separato.

### 3.1 Disponibilità dati Firebase

| Ambito | Metrica/bisogno | Collezioni Firebase | Campi chiave | Stato | Note |
| --- | --- | --- | --- | --- | --- |
| Trasversale | Filtri data (da/a) | `clients`, `appointments`, `sales` | `salonId`, `createdAt` | OK (nuovi record) | Nuovi clienti archiviano `createdAt`; per i legacy è previsto backfill solo se si vuole includerli nel reporting. |
| Analisi principali | Nuovi clienti | `clients` | `salonId`, `createdAt` | Gap | Aggiungere `createdAt` server-side e backfill per consentire query per periodo. |
| Analisi principali | Primi acquisti | `sales` | `salonId`, `clientId`, `createdAt` | OK | Dato disponibile e indicizzabile; usare `createdAt` per finestra temporale. |
| Analisi principali | Prime sedute | `appointments` | `salonId`, `clientId`, `status`, `start`, `createdAt` | OK | `status` comprende `completed`; `createdAt` viene settato via `FieldValue.serverTimestamp()`. |
| Analisi principali | Come ci hai conosciuto | `clients` | `referralSource` | OK | Campo valorizzato da UI con enumerazioni personalizzabili. |
| Analisi principali | Città di residenza | `clients` | `address` | Gap | Manca un campo strutturato per città; valutare aggiunta `city` o normalizzazione indirizzo. |
| Analisi operativa | Numero sedute per servizio | `appointments`, `services` | `serviceAllocations.serviceId`, `status` | OK | Le allocazioni coprono multipli servizi sullo stesso appuntamento. |
| Analisi operativa | Elenco sedute per servizio | `appointments`, `services`, `clients` | `serviceIds`, `clientId`, `start` | OK | Necessario join per mostrare dati cliente/operatore. |
| Analisi operativa | No show | `appointments` | `status = noShow` | OK | Enum già presente nel dominio (`AppointmentStatus.noShow`). |
| Analisi operativa | Occupazione slot | `appointments`, `shifts`, `staff_absences`, `salons` | `staffId`, `start/end`, turni | OK | Disponibili turni ricorrenti e assenze per costruire capacità operatore. |
| Analisi operativa | Occupazione per operatore | `appointments`, `shifts` | `staffId`, `duration` | OK | Stesso set dati di cui sopra con grouping per operatore. |
| Analisi economica | Fatturato totale | `sales` | `total`, `createdAt` | OK | Fare attenzione a vendite cancellate eventualmente marcate altrove. |
| Analisi economica | Vendite totali | `sales` | `id`, `createdAt` | OK | Conteggio diretto per periodo e salone. |
| Analisi economica | Ripartizione fatturato per servizio | `sales.items`, `services` | `referenceType=service`, `referenceId` | OK | Richiede join con catalogo per label e categoria. |
| Analisi economica | Fatturato per operatore e servizio | `sales`, `sales.items`, `staff` | `staffId`, `referenceType` | Da estendere | Le vendite create via Stripe non impostano `staffId`; gestire voce “non assegnato” o enrichment manuale. |
| Analisi economica | Ripartizione vendite per operatore | `sales`, `staff` | `staffId`, `total` | Da estendere | Stessa considerazione su vendite senza operatore associato. |
| Analisi economica | Fatturato per categoria | `sales.items`, `services`, `service_categories`, `inventory` | `category`/`categoryId` | OK | Catalogo servizi/prodotti già espone categoria; serve mapping coerente lato report. |
| Analisi economica | Vendite per categoria | `sales.items`, `inventory` | `referenceType`, `category` | OK | Copia della logica precedente con conteggio unità. |
| Analisi economica | Ripartizione vendite e unità per prodotto | `sales.items`, `inventory` | `referenceType=product`, `quantity`, `unitPrice` | OK | Quantità e prezzo unitario salvati per ogni riga. |
| Analisi economica | Fatturato stimato (agenda) | `appointments`, `services`, `packages` | `status`, `serviceIds`, `price` | Da estendere | Serve gestire casi prepagati/pacchetti per non doppiare ricavi. |
| Pacchetti & App | Pacchetti venduti | `sales.items`, `packages` | `referenceType=package`, `quantity` | OK | `SaleItem` conserva stato, sessioni e scadenza. |
| Pacchetti & App | Sedute restanti per pacchetto | `sales.items`, `appointments` | `remainingSessions`, `packageConsumptions` | OK | Disponibili residui e consumi per servizio; verificare backfill legacy. |
| Pacchetti & App | Fatturazione per modalità di pagamento | `sales`, `paymentHistory` | `paymentMethod`, `paymentHistory[].paymentMethod` | OK | Tracciati movimenti multipli con metodo e timestamp. |
| Pacchetti & App | Appuntamenti tramite app (self) | `appointments`, `public_appointments` | `createdBy`/`bookingChannel` | Gap | Attualmente non viene salvata l’origine della prenotazione; introdurre attributo dedicato. |
| Pacchetti & App | Acquisti tramite app | `sales` | `metadata.source` | Da estendere | Le Cloud Functions Stripe salvano `metadata.source='stripe'`, ma il modello `Sale` non lo espone ancora al client/reporting. |

**Azioni raccomandate a breve**
- Persistenza e backfill di `createdAt` e `city` sui documenti `clients`.
- Estensione delle funzioni di creazione prenotazioni per salvare `bookingChannel` / `createdByRole`.
- Esporre `metadata.source` (e altri metadati utili) nel modello `Sale` e nelle API di report.
- Verifica/creazione degli indici Firestore su `(salonId, createdAt)` per `clients`, `appointments`, `sales` e `(salonId, staffId, start)` per le analisi operative.

### 3.2 Cut-off legacy data
- Il modulo report filtra i dataset tramite `REPORTING_CUTOFF` (`--dart-define=REPORTING_CUTOFF=YYYY-MM-DD`); tutti i record con `createdAt` antecedente (o non valorizzato) vengono esclusi dai KPI.
- `includeInReporting` è centralizzato in `lib/app/reporting_config.dart` e riutilizzabile anche lato server/API.
- `AppDataStore.reporting{Sales,Appointments,Clients}` espongono liste già filtrate per favorire riuso nei nuovi widget/API.

## 4. Backend
- **Servizio dedicato**: `ReportsService`
  - Funzioni per ogni blocco logico (analisi principali, operativa, economica, pacchetti/app).
  - API signature coerente: `getReportSummary(filters)`, `getOperationalMetrics(filters)`, ecc.
  - Validazione filtri (date, salone, operatori, categorie) con fallback default (ultimi 30 giorni).
- **Query layer**: repository o query builder con CTE/window functions per calcoli complessi (occupazione slot, fatturato stimato).
- **Caching**: Redis/memcache con chiave `report:{scope}:{hashFilters}`; TTL 5-15 minuti; invalidazione su eventi critici (nuova vendita, nuova prenotazione).
- **Autorizzazione**: middleware che verifica ruoli (admin, operator) e limita scope ai saloni permessi.
- **Error handling e auditing**: logging strutturato per query pesanti, tracing tramite correlation id.

## 5. API
- **Endpoint REST**
  - `GET /reports/summary`
  - `GET /reports/operational`
  - `GET /reports/economic`
  - `GET /reports/packages`
  - `GET /reports/export` (CSV/PDF opzionali)
- **Parametri comuni**: `date_from`, `date_to`, `store_id`, `operator_ids[]`, `service_ids[]`, `category_ids[]`, `channel` (app/self).
- **Sicurezza**: rate limiting leggero (es. 60 req/min per admin), versioning (`/v1/reports`), risposta cacheable lato client con `ETag`.
- **Pagamenti**: endpoint dedicato per breakdown per metodo (`/reports/payments`).
- **Documentazione**: OpenAPI/Swagger aggiornato con esempi; contratto condiviso con frontend.

## 6. Frontend
- **Struttura UI**: pagina `Reports` con tab o sezioni verticali (Analisi principali, Operativa, Economica, Pacchetti & App).
- **State management**: store globale (Redux/Pinia/Vuex) o query client (React Query) per caching locale e refetch intelligente.
- **Filtri**: componente condivisa con selettore intervallo date, operatori, servizi; persistenza in query string per deep link.
- **Visualizzazioni**: libreria grafici (es. Chart.js, ECharts) già usata in app; componenti card con KPI principali.
- **Esportazione**: pulsanti `Download CSV`/`Download PDF` che colpiscono endpoint export; loader e handling errori.
- **Responsive**: layout adattivo, card + grafici con fallback tabellare su mobile.

## 7. Integrazione con moduli esistenti
- **Agenda/Appuntamenti**: riuso logica slot e no-show; aggiungere flag `is_no_show` se assente.
- **Vendite/POS**: includere imposte, sconti, pacchetti; verificare coerenza con report fiscali.
- **Anagrafiche clienti**: assicurarsi che origine (`referral_source`) sia normalizzata per analisi "Come ci hai conosciuto".
- **Operatori**: recuperare turni e disponibilità per calcolo occupazione; sincronizzare con eventuale modulo HR.
- **App mobile**: integrare evento `booking_created_self` per distinguere prenotazioni app/self.

## 8. Sicurezza, privacy e compliance
- Mascherare dati sensibili (es. email clienti) nelle esportazioni; applicare regole GDPR per retention.
- Audit trail per accessi al modulo report; loggare user id, parametri, timestamp.
- Validare autorizzazioni su ogni richiesta export; crittografare file generati e limitarne la vita utile.

## 9. Monitoring e performance
- Metriche tecniche: tempo medio query, hit/miss cache, dimensione payload, error rate per endpoint.
- Allarmi su ricalcoli delle materialized view e job falliti.
- Dashboard osservabilità integrata (es. Grafana) con breakdown per salone.

## 10. Strategia di test
- **Unit test** su funzioni di aggregazione e normalizzazione filtri.
- **Integration test** con dataset seed (nuovi clienti, no-show, pacchetti scaduti).
- **E2E/UI test** per flusso filtri → visualizzazione → export.
- **Data validation**: confronti automatici tra numeri dashboard e query SQL di riferimento.
- **Test di carico** su endpoint critici (>= 10 concurrent admin) per garantire latenza accettabile.

## 11. Roadmap di implementazione
1. **Assessment dati**: inventario Tabelle, gap analysis su campi mancanti, definizione viste.
2. **Backend foundation**: servizi, repository, caching, API contract, test unitari.
3. **Frontend MVP**: layout pagina, card KPI principali, filtri base.
4. **Job schedulati & caching avanzato**: snapshot giornaliere, ricalcoli.
5. **Funzioni avanzate**: esportazioni, proiezioni agenda, breakdown per canale/app.
6. **Hardening**: test carico, security review, ottimizzazione query.

## 12. Piano di rollout
- **Fase 1 (beta interna)**: accesso limitato a admin; feature flag; monitoraggio query.
- **Fase 2 (pilot saloni selezionati)**: raccolta feedback, aggiunta metriche mancanti.
- **Fase 3 (GA)**: apertura a tutti gli utenti autorizzati, documentazione e formazione.
- **Post-release**: backlog miglioramenti, KPI di successo (adozione, frequenza uso, tempi risposta).

## 13. Dipendenze e rischi
- Qualità dati nei moduli esistenti (no-show, referral) può compromettere accuratezza.
- Query pesanti su tabelle non indicizzate: mitigare con viste materializzate/indici.
- Gestione timezone multipli se l'app scala in nuove regioni.
- Necessità di licenze/limiti per librerie grafiche o strumenti PDF.

## 14. Open points
- Confermare se esiste già un data warehouse o se il modulo opera direttamente sul DB transazionale.
- Definire SLA degli endpoint (es. < 2s p95) e capacità infrastrutturale necessaria.
- Chiarire responsabilità team (backend, frontend, data) per job ETL e manutenzione viste.
