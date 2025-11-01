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

### 4.1 Caching e osservabilità lato backend
- **Chiavi di cache**: `report:{tenantId}:{scope}:{hash(filters)}` con hash calcolato includendo range data, salone, operatori, canale; TTL default 10 minuti (configurabile 5–15) e invalidazione tramite pub/sub su eventi `sale.created`, `appointment.completed`, `appointment.deleted`.
- **Layer**: wrapper `CachedReportsRepository` che delega a `ReportsRepository` e registra metriche (hit/miss, durata query, payload size); fallback automatico al repository origin in caso di errore cache.
- **Metriche**: esportare `reports_cache_hit_total`, `reports_cache_miss_total`, `reports_request_duration_ms`, `reports_request_errors_total` con label `scope`, `storeId`, `status`; aggiungere `reports_cache_staleness_seconds` per monitorare età del dato servito.
- **Alerting**: soglie su latenza p95 (>2s), error rate (>2%) e rapporto miss (>40%); integrare con dashboard Grafana/Datadog e canale incident Slack.
- **Tracing**: propagare `traceId`/`spanId` da gateway e arricchire log con `cacheStatus` (`HIT`, `MISS`, `STALE`) e `filterHash` per facilitare il debugging condiviso con il team frontend.

## 5. API
- **Endpoint REST**
  - `GET /reports/summary`
  - `GET /reports/operational`
  - `GET /reports/economic`
  - `GET /reports/packages`
  - `GET /reports/export` (CSV/PDF opzionali)
- **Parametri comuni**: `date_from`, `date_to`, `store_id`, `operator_ids[]`, `service_ids[]`, `category_ids[]`, `channel` (app/self).
- **Payload**: includere `appliedFilters` nella risposta (chiave-valore già localizzata) per mostrare i filtri attivi sui widget di sintesi.
- **Requisiti `appliedFilters`**: array di oggetti `{ id, label, value, type, metadata }`; label già tradotte lato backend, `value` in formato human-readable (es. `10-24 feb`), `metadata` per mappe colore/icone; garantire consistenza con gli identificativi usati dal design system (`FilterToken`).
- **Sicurezza**: rate limiting leggero (es. 60 req/min per admin), versioning (`/v1/reports`), risposta cacheable lato client con `ETag`.
- **Pagamenti**: endpoint dedicato per breakdown per metodo (`/reports/payments`).
- **Documentazione**: OpenAPI/Swagger aggiornato con esempi; contratto condiviso con frontend.

### 5.1 Contratto request/response condiviso
- **Richiesta tipo**  
  `GET /v1/reports/summary?date_from=2024-01-01&date_to=2024-01-31&store_id=salon-42&operator_ids=op-1,op-7&channel=app`  
  Header minimi: `X-Requested-By`, `X-Tenant-Id`, `If-None-Match` per sfruttare l’`ETag`. I filtri multi-valore usano comma-separated values o array (`operator_ids[]`) a seconda del client; definire lo standard nel contratto e documentarlo in OpenAPI.
- **Payload successo (`200`)**
```json
{
  "meta": {
    "generatedAt": "2024-02-01T09:05:12Z",
    "scope": "summary",
    "resolution": "daily"
  },
  "data": {
    "kpi": [
      { "id": "new_clients", "label": "Nuovi clienti", "value": 42, "delta": { "value": 0.17, "trend": "up" } },
      { "id": "appointments_completed", "label": "Sedute completate", "value": 128, "delta": { "value": -0.05, "trend": "down" } }
    ],
    "charts": {
      "revenue": {
        "type": "line",
        "series": [
          { "id": "revenue", "label": "Fatturato", "points": [{ "x": "2024-01-01", "y": 1500.0 }] }
        ]
      }
    },
    "tables": {
      "top_services": {
        "columns": ["serviceName", "appointments", "revenue"],
        "rows": [
          { "serviceName": "Taglio donna", "appointments": 34, "revenue": 980.5 }
        ]
      }
    }
  },
  "appliedFilters": [
    { "id": "date_range", "label": "Periodo", "value": "01-31 gen 2024", "type": "date_range" },
    { "id": "channel", "label": "Canale", "value": "Booking app", "type": "enum" }
  ],
  "pagination": { "cursor": null, "hasNextPage": false }
}
```
- **Errori standard**: struttura `{ "error": { "code": "REPORTS_INVALID_FILTER", "message": "...", "details": { "field": "date_from" } } }`; codici principali: `REPORTS_UNAUTHORIZED`, `REPORTS_INVALID_FILTER`, `REPORTS_BACKEND_TIMEOUT`, `REPORTS_DATA_GAP`. Ogni errore include `traceId` per triage con il backend.
- **Condivisione contratto**: allegare estratto OpenAPI e snippet JSON su Confluence/Slack, annotare esempi edge-case (nessun dato, filtri non supportati) e definire cadenza di review API con il team frontend.

## 6. Frontend
- **Struttura UI**: pagina `Reports` con tab o sezioni verticali (Analisi principali, Operativa, Economica, Pacchetti & App).
- **State management**: store globale (Redux/Pinia/Vuex) o query client (React Query) per caching locale e refetch intelligente.
- **Filtri**: componente condivisa con selettori per intervallo date (range mantenuto nella query string), salone, operatore, servizio/categoria e canale di prenotazione; sincronizzazione con store globale e url per abilitare deep link.
- **Design system**: estendere `Card` con varianti `metric`, `empty`, `clickable`; introdurre `FilterBadge`/`FilterChip` per proiettare i filtri usando token esistenti (`color.brand`, `radius.md`, `spacing.xs`); aggiornare guidelines di spacing/typography per assicurare leggibilità nelle griglie responsive.
- **Summary**: proiettare i filtri attivi (badge/chip derivati da `appliedFilters`) dentro alle card KPI e nei titoli delle sezioni.
- **Visualizzazioni**: libreria grafici (es. Chart.js, ECharts) già usata in app; garantire asse X completo per il grafico incassi anche in presenza di gap nei dati.
- **Esportazione**: pulsanti `Download CSV`/`Download PDF` che colpiscono endpoint export; loader e handling errori.
- **Responsive**: layout adattivo con card fluide (min/max width) che mantengono leggibilità su breakpoints tablet/mobile; fallback tabellare su mobile.
- **Stato empty**: arricchire lo stato "nessun dato" con messaggi contestuali, CTA rapide (es. modifica intervallo) e link a documentazione.
- **Interazioni**: tooltip granulari o pulsanti di drill-down sui grafici/card per navigare verso viste di dettaglio (es. elenco appuntamenti o vendite filtrate).
- **Mockup**: produrre wireframe hi-fi (desktop/tablet/mobile) per card responsive, grafico incassi, empty state e tooltip/drill-down; condividere prototipo interattivo (Figma) per convalidare transizioni e micro-interazioni.

### 6.1 Widget asincrono e test di copertura
- **Provider**: definire `ReportSummaryNotifier extends AsyncNotifier<ReportSummary>` che richiama `ReportsRepository.fetchSummary(filters)` e propaga gli `AsyncValue` (`loading`, `error`, `data`). Le key dei provider includono `filters.hashCode` per riallineare al caching backend e invalidare con `ref.invalidate(reportSummaryProvider(filters))` dopo azioni dell’utente.
- **Stati UI**: `loading` → shimmer/card scheletro con altezza fissa; `error` → card con icona, messaggio e `Retry` che richiama `ref.refresh`; `data` → view normale con gestione empty (`ReportEmptyState`) che mostra CTA "Modifica periodo" e usa `appliedFilters` per copy contestuale.
- **Gestione errori**: mappare codici backend a messaggi localizzati (`REPORTS_DATA_GAP` → "Dati incompleti, verifica il periodo selezionato"); loggare su Sentry con `scope` e `filters`.
- **Test**: unit test su `ReportSummaryNotifier` (mock repository, verifica transizioni `loading -> data/error`), golden test per UI `loading/error/empty`, widget test per assicurare la presenza del bottone retry e l’invocazione di `ref.refresh`.
- **Documentazione**: includere snippet provider+widget nel design doc frontend e creare checklist QA per validare stati dinamici su ambienti beta.

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

### 9.1 Backlog osservabilità
- **Instrumentazione**: task per implementare gli export Prometheus delle metriche `reports_cache_hit_total`, `reports_cache_miss_total`, `reports_request_duration_ms`, `reports_request_errors_total`, `reports_cache_staleness_seconds` su `ReportsService`.
- **Dashboard**: creare grafici dedicati (hit rate, latenza p95, error rate, staleness) e integrare la vista nel board “CIVI Reports”.
- **Alerting**: configurare regole sull’osservabilità (p95 > 2s per 5 minuti, error rate > 2%, cache miss > 40%) con notifica Slack #alerts-civi e runbook collegato.

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
