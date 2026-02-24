Ricerca Avanzata — Architettura

Obiettivi
- Permettere una ricerca clienti potente e flessibile, applicando filtri prima di avviare la ricerca o affinando i risultati dopo una prima selezione.
- Eseguire i filtri in memoria per rapidità e zero round‑trip, con un percorso evolutivo verso filtri lato server quando necessario.

Scope Fase 1 (in memoria)
- Numero cliente: range Da/A (stringa numerica esatta o intervallo).
- Età: range calcolato a partire da data di nascita.
- Data di nascita: range e scorciatoie (compleanni prossima settimana/mese).
- Sesso: Uomo/Donna/Altro.
- Installazione/uso app: ha effettuato primo login o ha token push (onboarding/fcmTokens).
- Importo speso: totale e/o in intervallo temporale (da/fino a), con opzione “incassato” (paid) vs “totale scontrinato”.
- Come ci hai conosciuto: `referralSource` (lista valori).
- Prossimo appuntamento: esiste entro prossima settimana/mese, opzionalmente filtrabile per categoria/servizio.
- Ultima seduta: data ultimo appuntamento completato, con filtri per categoria/servizio (es. “non torna da > X giorni”).
- Acquisti: include/esclude per categoria/servizio/prodotto/pacchetto; opzionale “last-minute” se indicato nei metadati vendita.
- Punti fedeltà: range su `client.loyaltyPoints`.
- Contatti: ha email/telefono.
- Luogo/anagrafica: città, professione, note presenti, stato onboarding.

Fonti Dati Disponibili (già in memoria)
- Clienti: `AppDataState.clients` (anagrafica, referralSource, loyalty, onboarding) — lib/data/repositories/app_data_state.dart:73
- Appuntamenti: `AppDataState.appointments` (storico e futuri, stato, servizi) — lib/data/repositories/app_data_state.dart:77, lib/domain/entities/appointment.dart:1
- Vendite: `AppDataState.sales` (importi, item, pagamenti) — lib/data/repositories/app_data_state.dart:82, lib/domain/entities/sale.dart:1
- Pacchetti acquistati: derivabili dalle vendite con `SaleItem.referenceType == package` + consumi dagli appuntamenti; helper: `resolveClientPackagePurchases(...)` — lib/presentation/shared/client_package_purchase.dart:1
- Ticket di pagamento: `AppDataState.paymentTickets` (collegamento appuntamento→vendita) — lib/data/repositories/app_data_state.dart:80, lib/domain/entities/payment_ticket.dart:1

UX e Flusso
- Nuova tab “Ricerca avanzata” nel modulo Clienti, accanto a Ricerca / Richieste / Ultimi (vedi TabBar in lib/presentation/screens/admin/modules/clients_module.dart:995).
- Due modalità d’uso supportate senza duplicare logica:
  - Pre‑filtri: l’utente imposta i filtri e preme “Cerca”.
  - Post‑filtri: l’utente effettua una prima ricerca ampia e poi affina con gli stessi controlli (aggiornamento live).
- Azioni: “Cerca”, “Azzera”, opzionale “Esporta CSV”. Ordinamento base alfabetico o per data creazione; evidenziamento match.

Modello Filtri (Fase 1)
- Campi anagrafici: testo generico, numero cliente Da/A, sesso, città, professione, referralSource, ha email/telefono.
- Date: range su `createdAt`, `dateOfBirth`, scorciatoie compleanni prossima settimana/mese.
- Appuntamenti: ha prossimi entro N giorni (range), ha ultimi completati entro/oltre X giorni; filtri per servizio e/o categoria.
- Vendite: spesa totale min/max (globale o su intervallo), ultimo acquisto entro/oltre, stato pagamento (deposito/saldo), importo residuo > 0.
- Pacchetti: ha pacchetti attivi, sessioni residue > 0, pacchetti scaduti; include/esclude acquisti per servizio/categoria/prodotto.
- Loyalty: punti min/max su `client.loyaltyPoints`.
- Onboarding/App: stato (`onboardingStatus`), ha effettuato login (`firstLoginAt`), ha `fcmTokens`.

Architettura Tecnica (Fase 1)
- Stato: si usa `appDataProvider` (Riverpod) già in uso nel modulo Clienti.
- Rendering: nuova tab con pannello filtri sopra lista risultati; controlli raggruppati per sezioni (Anagrafica, Attività, Pagamenti/Pacchetti, Tempo).
- Valutazione filtri (AND tra criteri):
  1) Pre‑filtri leggeri (stringhe/anagrafica) → applicati sempre.
  2) Filtri “attività” calcolati on‑demand solo se necessari (evita costi quando non servono).
- Indici locali per performance (costruiti quando si apre la tab o su cambio dati):
  - `appointmentsByClientId: Map<String, List<Appointment>>` (ordinati per data, con slice futuri/completati).
  - `salesByClientId: Map<String, List<Sale>>` (ordinati per `createdAt`).
  - `lastCompletedAppointmentByClientId: Map<String, DateTime?>` (cache per filtro “ultima seduta”).
  - `purchasesByClientId: Map<String, List<ClientPackagePurchase>>` calcolato solo se attivi filtri pacchetti.
  - `spentTotalsByClientId` pre‑aggregato opzionale per intervallo corrente (se filtro su importo è attivo).
- Debounce input testuale; computazioni pesanti (p.es. calcolo pacchetti) protette da memoization locale.

Pseudocodice Applicazione Filtri
```
List<Client> applyFilters(AdvancedSearchFilters f, AppDataState s) {
  final base = s.clients.where((c) => f.matchesAnagrafica(c)).toList();

  if (f.requiresAppointments) {
    buildAppointmentsIndexIfNeeded(s.appointments);
  }
  if (f.requiresSalesOrPackages) {
    buildSalesIndexIfNeeded(s.sales);
  }
  if (f.requiresPackages) {
    buildPurchasesForClientsIfNeeded(base, s); // usa resolveClientPackagePurchases
  }

  return base.where((c) {
    return f.matchesAppointments(c, indexes) &&
           f.matchesSales(c, indexes) &&
           f.matchesPackages(c, indexes) &&
           f.matchesLoyalty(c);
  }).toList();
}
```

Prestazioni e Limiti
- Dataset medi (fino a qualche migliaio di clienti per salone): filtri in memoria ok su device moderni.
- Ottimizzazioni: valutazione pigra dei filtri “attività”, indici riusati, UI con ListView virtualizzata.
- Quando passare a server‑side: se il tempo di filtro supera soglie UX o i dataset crescono sensibilmente.

Evoluzione Fase 2 (lato server opzionale)
- Firestore query per pre‑filtri “semplici” (es. `salonId`, range date, uguaglianze su singolo campo) con indici compositi dedicati.
- Limiti Firestore: niente contains/substring, una sola field con range per query, nessun OR tra field diversi; `whereIn` max 10 valori (già gestibile via chunking in AppDataStore).
- Full‑text/ricerca libera: integrare motore esterno (Algolia/Meilisearch) se serve.
- Indici suggeriti (da valutare quando si implementa Fase 2):
  - `clients`: `(salonId ASC, createdAt ASC)`; opzionali `(salonId ASC, gender ASC, createdAt ASC)`, `(salonId ASC, onboardingStatus ASC, createdAt ASC)`.

Prerequisiti Dati
- Backfill `createdAt` e normalizzazione `city` per tutti i clienti: `functions/scripts/backfill_clients_created_at_city.js`.
- Verifica campi vendite e collegamenti: `Sale.items` distingue `service/package/product`, `Sale.paymentStatus/paidAmount` per residui.
- “Last minute”: usare `sale.metadata.source` se presente; in mancanza, il filtro sarà limitato ai tipi noti (servizi/prodotti/pacchetti).

Roadmap Implementativa
1) Definizione modello `AdvancedSearchFilters` e UI tab “Ricerca avanzata”.
2) Filtri anagrafica + numero cliente + testo generico.
3) Indici locali base (appointmentsByClientId, salesByClientId) e filtri attività (prossimi/ultimi, conteggi).
4) Filtri spesa totale/intervallo e stato pagamento (deposito/saldo/residuo > 0).
5) Pacchetti: attivi/scaduti/residui e include/esclude per categoria/servizio.
6) Azzera/Cerca, mostra conteggio risultati, opzionale Esporta CSV.
7) Valutazione performance e, se necessario, piano Fase 2 (indici Firestore e/o ricerca esterna).

Note sui Requisiti Originali → Mappatura Filtri
- Numero cliente Da/A → range su `client.clientNumber` (parse int, confronto).
- Età → derivata da `client.dateOfBirth` (in anni) con range.
- Compleanni prossima settimana/mese → match su `dateOfBirth` rispetto a “oggi”.
- Sesso → `client.gender`.
- Hanno installato l’app → `client.firstLoginAt` non nullo oppure `client.fcmTokens` non vuoto.
- Importo fatturazione → somma `Sale.total` o `paidAmount` su range date opzionale.
- Come ci hai conosciuto → `client.referralSource`.
- Prossimo appuntamento (categoria/servizio; pross. sett/mese) → appuntamenti `scheduled` nel futuro, con filtro per `serviceId` o categoria via mappa servizi.
- Ultima seduta (categoria/servizio) → ultimo appuntamento `completed`, con eventuale filtro su servizio/categoria.
- Cosa deve/non deve aver acquistato → filtri su `Sale.items` per `referenceType` + mapping a servizi/categorie; opzionale filtro “last-minute” via `sale.metadata.source`.
- Quanti punti ha → range su `client.loyaltyPoints`.
