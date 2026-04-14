# Figma Make Commands (Operativo)

Obiettivo: usare `ui_app.md` come prompt master e rifinire per fase senza perdere copertura.
Vincolo globale brand: palette obbligatoria `oro + nero + bianco`.

## 1) Comando iniziale master

```text
Usa integralmente il file ui_app.md come contratto di progetto.
Genera il file Figma completo con pagine 00..50, coprendo Auth, Admin, Staff, Client su mobile/tablet/desktop.
Mantieni invariata la logica funzionale esistente.
Vincolo cromatico globale non negoziabile: usa solo oro/nero/bianco per il branding; colori di stato (success/warning/error/info) solo come feedback funzionali.
Applica naming componenti: Role/Area/Component/Variant/State.
```

## 2) Refinement per fase

### 2.1 Design System

```text
Raffina solo 00_Foundations e 01_Design_System.
Definisci token e variabili Figma per color/typography/spacing/radius/elevation/motion.
Color tokens obbligatori: brand.primary=gold, brand.secondary=black, neutral.0=white, neutral.900=black.
Nessun quarto colore brand persistente.
Completa componenti base e avanzati con varianti size/density/state.
```

### 2.2 Admin

```text
Raffina pagine 10_Admin_Mobile, 11_Admin_Tablet, 12_Admin_Desktop.
Copri tutti i 12 moduli admin: Panoramica, Saloni, Staff, Clienti, Movimenti App, Agenda, Servizi&Pacchetti, Magazzino, Vendite&Cassa, Messaggi&Marketing, WhatsApp, Report.
Per ogni screen critico includi default/loading/empty/error.
Conserva coerenza con palette oro/nero/bianco.
```

### 2.3 Staff

```text
Raffina pagine 20_Staff_Mobile e 21_Staff_Tablet_Desktop.
Copri agenda giorno/settimana, richieste ferie/permessi, dettaglio cliente read-only.
Per richieste staff includi stati pending/approved/rejected.
Mantieni naming Role/Area/Component/Variant/State.
```

### 2.4 Client

```text
Raffina pagine 30_Client_Mobile e 31_Client_Tablet_Desktop.
Copri Home, Agenda, Prenota, Carrello, Info salone + drawer (Punti fedelta, Pacchetti, Preventivi, Fatturazione, Questionari, Le mie foto, Impostazioni) + Notifiche.
Includi flow booking completo e flow quote+Stripe.
Mantieni coerenza palette e contrasto alto su CTA primarie.
```

## 3) Comandi di validazione finale

### 3.1 Copertura stati + edge cases

```text
Esegui audit finale su tutte le pagine: verifica presenza stati default/loading/empty/error/success/disabled/pending dove applicabile.
Verifica edge cases: conflitti agenda, pagamenti parziali, quote scaduti, richieste staff rifiutate.
Se manca uno stato, aggiungi frame dedicato nella pagina 40_Cross_Module_States.
```

### 3.2 Naming MCP + handoff

```text
Esegui audit naming su componenti principali e correggi tutto in formato Role/Area/Component/Variant/State.
Compila la pagina 50_MCP_Code_Connect_Mapping con: nome componente Figma, ruolo, variant/state, destinazione prevista in codice Flutter.
Priorita mapping: Agenda, AppointmentCard, KPI cards, Client drawer items, Quote/Payment cards, Notification cards.
```

## 4) Formula rapida da usare in chat Figma Make

```text
Procedi in 3 step: (1) genera struttura completa 00..50 da ui_app.md, (2) rifinisci Design System + Admin + Staff + Client, (3) valida stati e naming MCP.
Non cambiare logica runtime. Branding obbligatorio oro/nero/bianco.
```
