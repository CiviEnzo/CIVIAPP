# YouBook - Prompt Figma End-to-End (Rebranding Completo)

## Summary
Questo documento definisce un prompt completo per Figma AI, pronto per un refactor UI/UX totale dell'applicazione YouBook su mobile e desktop, per i ruoli Admin, Staff e Client.

Output atteso:
1. Prompt master unico con copertura end-to-end.
2. Blocchi prompt separati per ruolo (Admin, Staff, Client, Auth/Onboarding).
3. Specifiche handoff MCP/Figma e naming per Code Connect.

File target: `YoubookDoc/ui_app.md`

## Decisioni gia fissate
1. Scope: end-to-end completo.
2. Direzione visual: rebranding completo.
3. Formato: master prompt + blocchi per ruolo.
4. Lingua: italiano.
5. Strategia: sostituzione integrale del file (file originale vuoto).

## Important Changes / Public Interfaces / Types
1. Nessuna modifica API runtime dell'app in questa attivita.
2. Introduzione di un "Prompt Contract v1" con sezioni stabili:
- `Product Context`
- `Information Architecture`
- `Design System`
- `Role Flows`
- `States & Edge Cases`
- `MCP Handoff Rules`
3. Convenzione naming per Figma/Code Connect:
- `Role/Area/Component/Variant/State`
- Esempio: `Admin/Agenda/AppointmentCard/Compact/Warning`

---

## Prompt Contract v1

### Product Context
- Prodotto: piattaforma multi-ruolo per gestione salone, prenotazioni, vendite, cassa, marketing, reportistica e self-service cliente.
- Stack attuale (da rispettare nel refactor UX): Flutter + Riverpod + GoRouter + Firebase (Auth, Firestore, Functions, Storage, Messaging) + Stripe + modulo WhatsApp.
- Obiettivo refactor: redesign completo visuale e di interazione, senza cambiare la logica di business.
- Vincolo chiave: output Figma deve essere MCP-ready (componenti chiari, naming consistente, varianti/stati espliciti) per integrazione codice da Figma.
- Ambito device: mobile, tablet, desktop.
- Localizzazione primaria: italiano.

### Information Architecture

#### Route-level as-is (da codice)
- `/` -> Sign in
- `/register` -> Registrazione cliente
- `/register-center` -> Registrazione centro/admin
- `/password-reset` -> Recupero password
- `/onboarding` -> Completamento profilo e assegnazione salone/ruolo
- `/admin` -> Dashboard admin modulare
- `/staff` -> Dashboard staff
- `/client` -> Discovery/ingresso cliente per scelta salone
- `/client/dashboard` -> Dashboard cliente principale

#### IA Admin as-is
Navigazione principale (Rail desktop / Drawer mobile) con moduli:
1. Panoramica
2. Saloni
3. Staff
4. Clienti
5. Movimenti App
6. Agenda
7. Servizi & Pacchetti
8. Magazzino
9. Vendite & Cassa
10. Messaggi & Marketing
11. WhatsApp
12. Report

Sotto-flussi/admin detail da coprire:
- Agenda: viste calendario/lista, scope giorno/settimana, filtri staff, checklist giornaliera, anomalie, creazione appuntamento, slot express last-minute, turni, assenze.
- Clienti: ricerca, richieste accesso salone, ricerca avanzata, dettaglio cliente multi-tab (anagrafica, appuntamenti, pacchetti, preventivi, fatturazione, foto, questionari, note).
- Saloni: overview + setup checklist + configurazioni (profilo, operativita, loyalty, social, integrazioni).
- Messaggi & Marketing: tab Automazione, Manuali, Promozioni, Last-minute.
- WhatsApp: tab Impostazioni, Template, Campagne.
- Vendite & Cassa: ticket aperti/chiusi, registrazione vendita, pagamenti parziali/acconto/saldo, punti fedelta.
- Report: filtri (periodo, salone, operatore, servizio, categoria, canale), KPI, trend, drill-down.

#### IA Staff as-is
- Tab 1: Agenda (giorno/settimana, dettaglio appuntamento)
- Tab 2: Ferie & Permessi
- Accesso scheda cliente in sola lettura dal dettaglio appuntamento.

#### IA Client as-is
Bottom Navigation:
1. Home
2. Agenda
3. Prenota
4. Carrello
5. Info salone

Drawer cliente:
- Punti fedelta
- Pacchetti
- Preventivi
- Fatturazione
- Questionari
- Le mie foto
- Impostazioni

Notifiche:
- Accesso da icona top bar
- Pagina notifiche dedicata
- Badge incrementali (agenda/notifiche/drawer items)

Flussi client chiave:
- Prenotazione standard e multi-servizio
- Booking slot last-minute
- Carrello + checkout Stripe (se abilitato)
- Gestione preventivi e pagamento online quote
- Consultazione loyalty, pacchetti, pagamenti, foto e questionari

### Design System

#### Direzione rebrand (nuovo brand)
- Mood: premium ma operativo, professionale ma caldo, forte leggibilita.
- Linguaggio visual: moderno editoriale + dashboard data-driven.
- Evitare look generico "template app": servono gerarchie forti e componenti riconoscibili.

#### Typography
- Family primaria suggerita: `Space Grotesk` (UI/headline)
- Family secondaria suggerita: `Manrope` (body/table)
- Family numerica suggerita: `IBM Plex Mono` (metriche, importi, badge numerici)
- Scala tipografica coerente mobile/tablet/desktop con line-height generoso su viste dense.

#### Color system (rebrand)
Definire variabili semantiche (non hardcoded per schermata):
- `color.bg.canvas`
- `color.bg.surface`
- `color.bg.elevated`
- `color.text.primary`
- `color.text.secondary`
- `color.border.default`
- `color.brand.primary`
- `color.brand.secondary`
- `color.state.success`
- `color.state.warning`
- `color.state.error`
- `color.state.info`

Vincolo palette globale:
- Base obbligatoria: oro, nero, bianco.
- Nessun quarto colore brand permanente.
- Colori di stato (success/warning/error/info) ammessi solo come accenti funzionali su badge, alert e feedback.

Token cromatici consigliati:
- `color.brand.primary = gold`
- `color.brand.secondary = black`
- `color.neutral.0 = white`
- `color.neutral.900 = black`
- `color.border.default = black` con opacita variabile
- `color.bg.canvas = white` e `color.bg.elevated = white` con layering tramite bordo/ombra, non con nuovi colori brand

#### Spacing, radius, elevation
- Spacing scale: 4, 8, 12, 16, 20, 24, 32, 40.
- Radius scale: 8, 12, 16, 20, 28.
- Shadow/elevation: almeno 3 livelli (`low`, `mid`, `high`).

#### Component library obbligatoria
- App shell (mobile, tablet, desktop)
- NavigationRail / Drawer / Bottom Navigation
- Header con badge stato e azioni rapide
- KPI cards
- Data cards/list rows
- Advanced filter bar
- Calendario agenda (giorno/settimana/lista)
- Appointment card con stati/anomalie
- Empty/Error/Loading blocks
- Form controls (input, dropdown, chip, segmented, date/time)
- Modal/Bottom sheet/Side panel
- Notification cards
- Payment/quote cards
- Last-minute card
- Promotion card/detail
- Loyalty widgets

### Role Flows

#### Auth/Onboarding
- Login con ruoli multipli
- Password reset page dedicata
- Registrazione cliente
- Registrazione centro (account in pending)
- Onboarding guidato:
  - scelta ruolo (se necessario)
  - scelta salone
  - richiesta accesso salone (pending/approved/rejected)
  - completamento profilo

#### Admin
- Dashboard panoramica KPI e shortcut.
- Saloni:
  - creazione minima + checklist setup
  - profilo, operativita, macchinari/cabine, loyalty, social
  - integrazioni Stripe/WhatsApp
- Staff:
  - anagrafica staff, ruoli, ordine visualizzazione
  - turni, assenze, richieste ferie/permessi approva/rifiuta
- Clienti:
  - ricerca base + ricerca avanzata
  - access requests workflow
  - client detail completo
- Agenda:
  - calendario operativo full day/week
  - lista appuntamenti
  - creazione/modifica/spostamento appuntamenti
  - gestione anomalie "da gestire"
  - checklist giornaliera
  - slot express last-minute
- Servizi & Pacchetti:
  - servizi attivi/disattivati
  - pacchetti visibili/non visibili
  - categorie
- Magazzino:
  - articoli, soglie, alert low stock
- Vendite & Cassa:
  - registra vendita
  - ticket aperti/chiusi
  - acconto/saldo/posticipato
  - punti fedelta e impatto su margini
- Messaggi & Marketing:
  - automazioni reminder
  - invii manuali
  - promozioni
  - last-minute visibility + invio
- WhatsApp:
  - settings OAuth/stato
  - template
  - campagne
- Report:
  - filtri avanzati
  - KPI, trend, drill-down

#### Staff
- Agenda operativa con dettaglio appuntamento.
- Accesso scheda cliente read-only (dati base, note, pacchetti, appuntamenti, foto/questionari).
- Ferie & Permessi:
  - invio richiesta
  - stato richiesta (pending/approved/rejected/cancelled)
  - storico

#### Client
- Home con:
  - prossimo appuntamento
  - promozioni
  - slot last-minute
  - pacchetti disponibili
- Agenda:
  - prossimi + storico
  - modifica/annulla dove consentito
- Prenota:
  - flow guidato categoria/servizio/staff/slot/riepilogo
  - controlli disponibilita reali (turni, assenze, pause, conflitti)
- Carrello:
  - servizi/pacchetti
  - totale dinamico
  - checkout Stripe (se abilitato)
- Info salone:
  - contatti, orari, posizione, social
- Drawer:
  - loyalty, pacchetti, preventivi, fatturazione, questionari, foto, settings
- Notifiche:
  - lista notifiche
  - deep-link da push

### States & Edge Cases

#### Stati UI obbligatori
- Loading
- Empty
- Error + retry
- Success confirmation
- Disabled
- Pending approval

#### Edge cases obbligatori
- Agenda:
  - conflitto slot/staff
  - anomalia fuori turno
  - appuntamento passato non gestito
- Vendite:
  - pagamento parziale (acconto/saldo)
  - residuo da incassare
- Quote:
  - quote scaduto
  - quote accettato via Stripe
  - quote rifiutato
- Staff requests:
  - richiesta pending/approved/rejected/cancelled
- Client onboarding:
  - richiesta salone pending/rejected
- Integrazioni:
  - salone senza Stripe con checkout disabilitato
  - salone senza WhatsApp collegato

### MCP Handoff Rules
- Naming componenti: `Role/Area/Component/Variant/State`
- Naming esempi:
  - `Admin/Agenda/AppointmentCard/Compact/Warning`
  - `Client/Home/LastMinuteCard/Default/Active`
  - `Staff/Requests/RequestCard/Default/Pending`
  - `Auth/SignIn/Form/Default/Error`
- Variants obbligatorie per ogni componente riusabile:
  - `size` (sm/md/lg)
  - `state` (default/hover/focus/disabled/error/success)
  - `density` (comfortable/compact) dove serve.
- Auto layout obbligatorio su tutti i componenti base.
- Constraints/resizing obbligatori su frame responsive.
- Definire local variables/tokens in Figma per color, type, spacing, radius, elevation.
- Ogni frame pagina deve includere:
  - nome screen
  - ruolo
  - device target
  - stato (default/loading/empty/error)
  - note di comportamento.
- Preparare component map per Code Connect con naming spec allineato ai path Flutter.

---

## Target Figma Strutturato per Pagine/Frame

### Struttura pagine Figma consigliata
1. `00_Foundations`
2. `01_Design_System`
3. `02_Auth_Onboarding`
4. `10_Admin_Mobile`
5. `11_Admin_Tablet`
6. `12_Admin_Desktop`
7. `20_Staff_Mobile`
8. `21_Staff_Tablet_Desktop`
9. `30_Client_Mobile`
10. `31_Client_Tablet_Desktop`
11. `40_Cross_Module_States`
12. `50_MCP_Code_Connect_Mapping`

### Breakpoint frame richiesti
- Mobile: 390x844
- Tablet: 834x1194
- Desktop: 1440x1024

### Regole di output per ogni pagina
- Almeno uno screen "happy path" per flusso.
- Varianti stato per screen critici (loading/empty/error).
- Componenti estratti e riutilizzati.
- Nomenclatura conforme a `Role/Area/Component/Variant/State`.

---

## Prompt Master Figma (copia/incolla)

```text
Sei Figma AI.
Obiettivo: eseguire un refactor completo UI/UX di YouBook con rebranding totale, mantenendo invariata la logica funzionale.

Contesto prodotto:
- App multi-ruolo: Admin, Staff, Client.
- Tech runtime: Flutter + Riverpod + GoRouter + Firebase + Stripe + WhatsApp.
- Lingua primaria: italiano.
- Device: mobile, tablet, desktop.

Crea un file Figma completo con:
1) Design system nuovo brand.
2) Tutte le schermate Auth, Admin, Staff, Client.
3) Stati UI completi (loading, empty, error, success, disabled, pending).
4) Componenti modulari MCP-ready per integrazione code-connect.

Vincoli di architettura (as-is da rispettare):
- Routes: /, /register, /register-center, /password-reset, /onboarding, /admin, /staff, /client, /client/dashboard.
- Admin modules: Panoramica, Saloni, Staff, Clienti, Movimenti App, Agenda, Servizi & Pacchetti, Magazzino, Vendite & Cassa, Messaggi & Marketing, WhatsApp, Report.
- Staff: Agenda + Ferie & Permessi + scheda cliente read-only.
- Client: Home, Agenda, Prenota, Carrello, Info salone + drawer (Punti fedelta, Pacchetti, Preventivi, Fatturazione, Questionari, Le mie foto, Impostazioni) + pagina notifiche.

Cross-cutting obbligatori:
- Promozioni, Last-minute, Loyalty, Quote + Stripe, WhatsApp template/campagne, badge/stati notifiche.

Output Figma richiesto:
- Pagine:
  - 00_Foundations
  - 01_Design_System
  - 02_Auth_Onboarding
  - 10_Admin_Mobile
  - 11_Admin_Tablet
  - 12_Admin_Desktop
  - 20_Staff_Mobile
  - 21_Staff_Tablet_Desktop
  - 30_Client_Mobile
  - 31_Client_Tablet_Desktop
  - 40_Cross_Module_States
  - 50_MCP_Code_Connect_Mapping
- Breakpoint frame: 390x844, 834x1194, 1440x1024.
- Tutti i componenti devono usare naming: Role/Area/Component/Variant/State.
- Esempio naming: Admin/Agenda/AppointmentCard/Compact/Warning.

Style direction (rebranding):
- Visual language premium-operational, moderno, non generico.
- Typography consigliata: Space Grotesk + Manrope + IBM Plex Mono.
- Palette obbligatoria: oro, nero, bianco (stati solo funzionali come accento).
- Gerarchie nette, contrasto alto, azioni primarie sempre chiare.

Per ogni screen critico crea:
- Versione default
- Versione loading
- Versione empty
- Versione error

Per ogni flusso critico crea prototipazione:
- Auth: login -> reset -> onboarding -> routing ruolo
- Admin agenda: vista -> filtro -> creazione appuntamento -> anomalia -> checklist
- Vendite: registra vendita -> acconto/saldo -> ticket -> fatturazione
- Staff: richiesta ferie/permesso -> stato approvazione
- Client booking: scelta servizio -> staff -> slot -> riepilogo -> conferma
- Quote client: visualizza -> accetta e paga -> stato aggiornato

Alla fine crea pagina "50_MCP_Code_Connect_Mapping" con:
- tabella componenti principali
- nome Figma component
- ruolo
- stato/variant
- destinazione prevista in codice Flutter.
```

---

## Prompt Admin (copia/incolla)

```text
Progetta il dominio Admin di YouBook (mobile/tablet/desktop) con approccio modulare.

Navigazione principale:
- Panoramica
- Saloni
- Staff
- Clienti
- Movimenti App
- Agenda
- Servizi & Pacchetti
- Magazzino
- Vendite & Cassa
- Messaggi & Marketing
- WhatsApp
- Report

Richieste principali:
1) Dashboard Panoramica con KPI cards, alert, upcoming appuntamenti.
2) Modulo Saloni con setup checklist e cards di configurazione (profilo, operativita, loyalty, social, integrazioni).
3) Modulo Staff con anagrafica, turni, assenze, richieste ferie/permessi approva-rifiuta.
4) Modulo Clienti con:
   - ricerca base
   - ricerca avanzata
   - richieste accesso salone
   - dettaglio cliente multi-tab.
5) Modulo Agenda con:
   - vista calendario/lista
   - scope giorno/settimana
   - filtri staff
   - cards appuntamento con stati/anomalie
   - checklist giornaliera
   - creazione appuntamento standard
   - creazione slot express last-minute.
6) Modulo Servizi & Pacchetti con attivi/disattivati, categorie e visibilita lato client.
7) Modulo Magazzino con low-stock states.
8) Modulo Vendite & Cassa con ticket aperti/chiusi, acconto/saldo/posticipato, loyalty impact.
9) Modulo Messaggi & Marketing con tab Automazione/Manuali/Promozioni/Last-minute.
10) Modulo WhatsApp con tab Impostazioni/Template/Campagne.
11) Modulo Report con filter bar avanzata, KPI, trend, drill-down.

Stati obbligatori:
- loading, empty, error, success.

Naming componenti:
- Admin/<Area>/<Component>/<Variant>/<State>
```

---

## Prompt Staff (copia/incolla)

```text
Progetta il dominio Staff di YouBook (mobile first + adattamento tablet/desktop).

IA Staff:
- Tab Agenda
- Tab Ferie & Permessi

Flow Agenda:
- vista giorno/settimana
- apertura dettaglio appuntamento
- accesso scheda cliente read-only (dati base, note, pacchetti, appuntamenti, foto/questionari)

Flow Ferie & Permessi:
- lista richieste
- nuova richiesta (ferie/permesso/malattia)
- stati richiesta: pending/approved/rejected/cancelled
- storico richieste

Stati UX:
- loading, empty, error, success
- pending approval

Naming componenti:
- Staff/<Area>/<Component>/<Variant>/<State>
```

---

## Prompt Client (copia/incolla)

```text
Progetta il dominio Client di YouBook (mobile first + varianti tablet/desktop), con rebranding completo.

Bottom navigation:
1. Home
2. Agenda
3. Prenota
4. Carrello
5. Info salone

Drawer:
- Punti fedelta
- Pacchetti
- Preventivi
- Fatturazione
- Questionari
- Le mie foto
- Impostazioni

Notifiche:
- accesso da top bar
- pagina notifiche dedicata
- gestione badge progressivi

Flow principali:
1) Home:
   - prossimo appuntamento
   - promozioni attive
   - slot last-minute
   - pacchetti disponibili
2) Agenda:
   - prossimi appuntamenti
   - storico
   - azioni modifica/annulla dove consentito
3) Prenota:
   - categoria -> servizio -> staff -> slot -> riepilogo -> conferma
   - blocco slot non disponibili (turni/assenze/conflitti)
4) Carrello:
   - item multipli
   - totale dinamico
   - checkout Stripe se abilitato
5) Info salone:
   - contatti, orari, posizione, social
6) Drawer sheets:
   - loyalty summary + movimenti
   - pacchetti attivi/passati
   - preventivi con stato e CTA "accetta e paga"
   - fatturazione con residui e storico
   - questionari assegnati
   - archivio foto
   - settings

Stati obbligatori:
- loading, empty, error, success, disabled.

Naming componenti:
- Client/<Area>/<Component>/<Variant>/<State>
```

---

## Prompt Auth/Onboarding (copia/incolla)

```text
Progetta il dominio Auth/Onboarding di YouBook per mobile/tablet/desktop.

Screens obbligatorie:
- Sign in
- Registrazione cliente
- Registrazione centro/admin
- Password reset
- Onboarding profilo

Flow obbligatori:
1) Login standard con gestione notice/errore.
2) Recupero password su pagina dedicata.
3) Registrazione cliente -> verifica -> onboarding.
4) Registrazione centro -> account pending abilitazione.
5) Onboarding:
   - scelta ruolo (quando necessario)
   - scelta salone
   - richiesta accesso salone (pending/rejected/approved)
   - completamento profilo con campi dinamici.

Stati obbligatori:
- loading, empty (no salons), error, pending approval, success.

Naming componenti:
- Auth/<Area>/<Component>/<Variant>/<State>
```

---

## Prompt Shared Design System (copia/incolla)

```text
Crea un design system rebrand per YouBook che supporti i domini Admin/Staff/Client/Auth.

Richieste:
1) Token semantici:
   - color
   - typography
   - spacing
   - radius
   - elevation
   - motion
2) Foundations:
   - grid responsive mobile/tablet/desktop
   - icone
   - stati focus/hover/pressed/disabled
3) Componenti base:
   - Buttons
   - Inputs
   - Dropdown/Select
   - Chips
   - Tabs
   - Badge
   - Card
   - Table rows
   - Modal/Bottom sheet/Side panel
   - Toast/Inline alert
4) Componenti avanzati:
   - Calendar views
   - Appointment cards
   - KPI cards
   - Quote cards
   - Payment ticket cards
   - Last-minute cards
   - Promotion cards
5) Varianti obbligatorie:
   - size (sm/md/lg)
   - density (comfortable/compact)
   - state (default/hover/focus/disabled/error/success/warning)
6) Naming componenti obbligatorio:
   - Role/Area/Component/Variant/State

Vincolo cromatico non negoziabile:
- Usa solo palette brand oro/nero/bianco per tutte le superfici principali.
- Definisci i token color partendo da:
  - brand.primary = gold
  - brand.secondary = black
  - neutral.0 = white
  - neutral.900 = black
- Usa success/warning/error/info solo per feedback di stato, non per branding.

Genera pagina dedicata con inventario componenti e mappa di riuso cross-ruolo.
```

---

## Test Cases e Scenari di Validazione del Prompt

1. Copertura IA 100% per ruolo
- Auth: tutte le route coperte.
- Admin: tutti i 12 moduli coperte con almeno uno screen per modulo.
- Staff: Agenda + Ferie/Permessi + dettaglio cliente read-only.
- Client: 5 tab bottom nav + drawer + notifiche.

2. Coerenza multi-device
- Ogni macroflusso presente in mobile/tablet/desktop.
- Nessun componente critico perso nel passaggio di breakpoint.

3. Copertura stati UI
- Ogni screen critico con loading/empty/error/success/disabled.
- Stati pending espliciti per approval workflows.

4. Edge case operativi
- Agenda conflitti/anomalie.
- Vendite con acconto/saldo/residuo.
- Quote scaduti/accettati/rifiutati.
- Staff requests pending/approved/rejected.

5. Coerenza cross-modulo
- Agenda -> Vendite & Cassa
- Clienti -> Fatturazione/Preventivi
- Messaggi/Promozioni -> Client Home
- Report -> dati coerenti con vendite/appuntamenti/clienti

6. Handoff MCP-ready
- Naming componenti conforme.
- Variants complete.
- Pagina mapping per Code Connect compilata.

---

## Checklist MCP Handoff + Naming Componenti

- [ ] Tutti i componenti hanno naming `Role/Area/Component/Variant/State`
- [ ] Tutte le varianti di stato sono presenti
- [ ] Componenti condivisi estratti in `01_Design_System`
- [ ] Frame annotati con ruolo/device/stato
- [ ] Token design definiti come variabili Figma
- [ ] Pagina `50_MCP_Code_Connect_Mapping` completata
- [ ] Mapping componenti principali verso destinazioni Flutter identificato
- [ ] Nessun flusso business critico mancante

Esempi naming minimi da applicare:
- `Admin/Agenda/AppointmentCard/Compact/Warning`
- `Admin/Sales/TicketRow/Default/Open`
- `Staff/Requests/RequestCard/Default/Pending`
- `Client/Home/PromoCard/Featured/Active`
- `Client/Drawer/NavItem/Default/Badge`
- `Auth/SignIn/Form/Default/Error`

---

## Assunzioni Esplicite
1. Il file `CIVIAPPTOSHARE.txt` citato nell'IDE non e disponibile nel repository attuale; il prompt e stato costruito solo su fonti realmente presenti (`YoubookDoc` + `lib`).
2. Il prompt riflette stato implementato e requisiti documentali correnti.
3. Il rebranding non cambia la logica funzionale runtime: cambia solo UX/UI, IA visuale e consistenza del design system.

## Definition of Done
Il documento e pronto quando:
1. puo essere copiato in Figma AI senza integrazioni manuali aggiuntive;
2. copre integralmente i flussi Admin/Staff/Client/Auth;
3. include regole MCP/Code Connect utili alla successiva integrazione codice.

---

## Figma Upload Manifest (Current)

Pacchetto definitivo "Figma Upload - completo" allineato allo stato corrente del branch locale.
Nota operativa: `YoubookDoc/flowchart.rtf` e escluso dall'upload Figma Make per vincolo formato.

### A. Core orchestration
1. `YoubookDoc/ui_app.md`

### B. Auth / onboarding
2. `YoubookDoc/login/login_admin.md`
3. `YoubookDoc/login/login_creazione_client.md`
4. `YoubookDoc/cliente/creazione_cliente.md`

### C. Admin IA + UX
5. `YoubookDoc/admin/UI/admin_ui_mobile.md`
6. `YoubookDoc/admin/UI/UI MODULO SALONE`
7. `YoubookDoc/modulo/overview.md`
8. `YoubookDoc/appointments/control_Appointment.md`
9. `YoubookDoc/appointments/UI_appointments_calendar.txt`
10. `YoubookDoc/appointments/manage_appintments_admin_side.txt`
11. `YoubookDoc/appointments/manage_appointmets_admin_multiservice.md`
12. `YoubookDoc/ricerca_avanzata/ricerca_avanzata.md`
13. `YoubookDoc/vendite_cassa/vendite_cassa.txt`
14. `YoubookDoc/vendite_cassa/FATTURAZIONE`
15. `YoubookDoc/report/report.md`

### D. Staff
16. `YoubookDoc/staff/app_staff.md`
17. `YoubookDoc/staff/staff.txt`
18. `YoubookDoc/staff/creazione_turni.txt`

### E. Client
19. `YoubookDoc/cliente/cliente UI.md`
20. `YoubookDoc/cliente/prenotazione_cliente.txt`
21. `YoubookDoc/appointments/NUOVO SISTEMA DI PRENOTAZIONE LATO CLIEN.txt`
22. `YoubookDoc/foto_cliente/archivio_fotografico.md`
23. `YoubookDoc/cliente/Anamnesi.md`

### F. Cross-cutting funzionale
24. `YoubookDoc/modulo/stripe.md`
25. `YoubookDoc/modulo/whatsapp.md`
26. `YoubookDoc/modulo/whatsapp_reminder.md`
27. `YoubookDoc/messaggi/CIVIAPP_MESSAGGI_GUIDA_Codex.md`
28. `YoubookDoc/notifications/notifications.md`
29. `YoubookDoc/promozioni/new_promo.md`
30. `YoubookDoc/PREVENTIVO.md`

## Ordine di Upload Consigliato
1. Core (`ui_app.md`)
2. Admin (blocchi C)
3. Staff (blocco D)
4. Client (blocco E)
5. Cross-cutting (blocco F)

## Legacy Excluded
File esclusi in modo esplicito per evitare regressioni su materiale non piu valido:
- `YoubookDoc/CIVIAPPTOSHARE.txt` (legacy rimosso dal branch corrente)
- `YoubookDoc/admin/UI/UI` (legacy rimosso dal branch corrente)
- `YoubookDoc/admin/UI/UI MODULO APPUNTAMENTI` (legacy rimosso dal branch corrente)

## Upload Excluded (Tool Constraints)
- `YoubookDoc/flowchart.rtf` (presente nel repo ma escluso dal caricamento Figma Make per limite formato)
- `YoubookDoc/punti fedeltà/punti fedelta.ini` (presente nel repo ma escluso dal caricamento su richiesta operativa)
- `YoubookDoc/assets/segna_viso.png` (presente nel repo ma escluso dal caricamento su richiesta operativa)
- `YoubookDoc/assets/segna_corpo.png` (presente nel repo ma escluso dal caricamento su richiesta operativa)

Motivazione policy:
- Fonte di verita: stato corrente del codice/documentazione.
- I legacy cancellati non devono essere ripristinati ne caricati in Figma.
- Upload ripetibile, senza dipendenze da conoscenza implicita.

## Refresh Cadence
Aggiornare questo manifest quando accade almeno uno dei seguenti eventi:
1. aggiunta/rimozione/rinomina file in `YoubookDoc` legati a UX/UI o flussi;
2. refactor IA (route, moduli, ruolo, drawer/tab principali);
3. cambio policy integrazione MCP/Code Connect;
4. prima di ogni ciclo di redesign end-to-end su Figma Make.
