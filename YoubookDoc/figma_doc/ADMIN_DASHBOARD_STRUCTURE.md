# YouBook Admin Dashboard - Struttura Completa

## Overview
Dashboard amministrativa completa con 12 moduli funzionali, stati multipli (default/loading/empty/error) e responsive design completo per Mobile (390x844), Tablet (834x1194) e Desktop (1440x1024).

---

## Architettura

### File Structure
```
/src/app/pages/admin/
├── AdminDashboard.tsx      # Layout principale + moduli 1-7
└── AdminModules.tsx        # Moduli 8-12 (separati per gestibilità)
```

### Naming Convention
Pattern: `Admin/[Module]/[Screen]/Responsive/[State]`

Esempi:
- `Admin/Panoramica/Overview/Responsive/Default`
- `Admin/Saloni/List/Responsive/Loading`
- `Admin/Clienti/List/Responsive/Empty`

---

## 12 Moduli Admin

### 1. **PANORAMICA** 📊
**Path:** `activeModule === 'panoramica'`  
**Component:** `PanoramicaModule`

**Funzionalità:**
- 6 KPI Cards: Appuntamenti, Pacchetti, Scontrini, Incasso Anno, Incasso Posticipato, Punti Fedeltà
- Azioni Rapide: 4 CTA per navigazione veloce
- Layout: Grid responsive 1/2/4 colonne

**Stati:**
- ✅ Default - Vista completa con dati
- ✅ Loading - Spinner con messaggio

**Design:**
- Cards con icone colorate (Calendar, Package, ShoppingCart, Euro, Clock, Star)
- Trend indicators (↑ +12%, ↑ +15%)
- Hover states su action buttons

---

### 2. **SALONI** 🏢
**Path:** `activeModule === 'saloni'`  
**Component:** `SaloniModule`

**Funzionalità:**
- DataTable responsive con 3 saloni mock
- Filtri: Search bar + Filtri button
- Stats: Saloni Attivi (2), Staff Totale (20), Città (3)
- Actions: Visualizza, Modifica per ogni salone

**Colonne Tabella:**
1. Nome Salone (con indirizzo + icona MapPin)
2. Contatti (telefono + email)
3. Staff (numero persone)
4. Stato (Badge attivo/inattivo)
5. Azioni (Eye, Edit icons)

**Stati:**
- ✅ Default - Lista saloni
- ✅ Loading - LoadingState component
- ✅ Empty - DataTable empty message
- ✅ Error - ErrorState con retry button

**Design:**
- Mobile: Card layout verticale
- Desktop: Table layout con hover
- StatusBadge con colori semantic (green/gray)

---

### 3. **STAFF** 👥
**Path:** `activeModule === 'staff'`  
**Component:** `StaffModule`

**Funzionalità:**
- DataTable con membri team (3 mock)
- Search + Filtri
- Click su row per aprire profilo
- Button "Aggiungi Membro"

**Colonne Tabella:**
1. Membro Staff (nome + ruolo)
2. Salone di appartenenza
3. Contatti (email + telefono)
4. Appuntamenti totali
5. Stato (Badge attivo/inattivo)
6. Azioni (Eye, Edit)

**Stati:**
- ✅ Default
- ✅ Loading
- ✅ Empty

---

### 4. **CLIENTI** 👤
**Path:** `activeModule === 'clienti'`  
**Component:** `ClientiModule`

**Funzionalità:**
- DataTable clienti (3 mock)
- Search + Filtri + Export button
- Stats: Totali (342), Nuovi Mese (+18), VIP (24)
- Spesa totale evidenziata in oro

**Colonne Tabella:**
1. Cliente (nome + email)
2. Telefono
3. Visite totali
4. Ultima Visita (formattata IT)
5. Spesa Totale (€ in primary color)
6. Azioni (Eye, Mail)

**Stati:**
- ✅ Default
- ✅ Loading
- ✅ Empty

**Design:**
- Highlight VIP con colore primary
- Success color per nuovi clienti
- Email action per comunicazione diretta

---

### 5. **MOVIMENTI APP** 📲 *[NUOVO]*
**Path:** `activeModule === 'movimenti'`  
**Component:** `MovimentiModule`

**Funzionalità:**
- Tracking attività app cliente
- Stats: Oggi (12), Settimana (48), Volume € (3.240), In Attesa (5)
- Movimenti: Acquisti, Prenotazioni, Cancellazioni

**Colonne Tabella:**
1. Tipo Movimento (con data/ora)
2. Cliente
3. Importo (+ verde, - rosso, 0 neutro)
4. Metodo pagamento
5. Stato (Badge: Completato/In Attesa/Cancellato)

**Stati:**
- ✅ Default
- ✅ Loading
- ✅ Empty

**Design:**
- Color-coded importi (success/error)
- Real-time tracking feel
- Status badges con semantic colors

---

### 6. **AGENDA** 📅
**Path:** `activeModule === 'agenda'`  
**Component:** `AgendaModule`

**Funzionalità:**
- Stats: Oggi (24), Settimana (156), Confermati (140), Da Confermare (16)
- Placeholder calendario con 3 viste (Giorno/Settimana/Mese)
- Lista "Prossimi Appuntamenti" con 3 entries
- Button "Nuovo Appuntamento"

**Lista Appuntamenti:**
- Orario grande e bold
- Cliente + Servizio + Staff
- Button "Dettagli" per ogni entry
- Hover effect su row

**Stati:**
- ✅ Default
- ✅ Loading
- ⏳ Empty (possibile implementazione futura)

**Design:**
- Calendar icon centrale
- Time-based UI con orari prominenti
- Success/Warning colors per stati

---

### 7. **SERVIZI & PACCHETTI** 📦
**Path:** `activeModule === 'servizi'`  
**Component:** `ServiziModule`

**Funzionalità:**
- Tab switcher: Servizi (3) / Pacchetti (2)
- Stats dinamiche per tab attivo
- DataTable diversa per ogni tab
- Button "Aggiungi" context-aware

**Tab Servizi:**
- Colonne: Nome (+ categoria), Durata (min), Prezzo (€), Stato, Azioni
- Stats: Attivi (3), Categorie (5), Prezzo Medio (€47)
- Actions: Edit, Delete

**Tab Pacchetti:**
- Colonne: Nome (+ servizi inclusi), Prezzo, Validità (giorni), Venduti, Stato, Azioni
- Stats: Attivi (2), Venduti Mese (20), Ricavo (€13.220)
- Actions: Edit, Delete

**Stati:**
- ✅ Default (entrambi i tab)
- ✅ Loading
- ✅ Empty (per tab)

**Design:**
- Tab navigation con border-bottom indicator
- Color primary per prezzi
- Delete action in error color

---

### 8. **MAGAZZINO** 📦
**Path:** `activeModule === 'magazzino'`  
**Component:** `MagazzinoModule` *(AdminModules.tsx)*

**Funzionalità:**
- Inventario prodotti (3 mock)
- Stats: Totali (48), Valore (€3.240), Scorte Basse (5), Esauriti (2)
- Alert automatico per scorte sotto minimo
- Search + Filtri

**Colonne Tabella:**
1. Prodotto (nome + categoria)
2. Giacenza (quantità + soglia minima)
3. Prezzo unitario
4. Stato (Badge: Disponibile/Scorta Bassa)
5. Azioni (Edit, Plus per ricarico)

**Stati:**
- ✅ Default
- ✅ Loading
- ✅ Empty

**Design:**
- Warning color per scorte basse
- Error color per esauriti
- Plus icon per quick restock

---

### 9. **VENDITE & CASSA** 💰
**Path:** `activeModule === 'vendite'`  
**Component:** `VenditeModule` *(AdminModules.tsx)*

**Funzionalità:**
- Registro vendite (3 mock)
- Stats: Oggi (12, €1.420), Mese (€12.340), In Attesa (€420)
- Numero vendita progressivo (VEN-2026-NNN)
- Click su row per dettagli

**Colonne Tabella:**
1. Numero Vendita (+ data/ora)
2. Cliente
3. Importo (€ in primary)
4. Metodo pagamento
5. Stato (Badge: Completata/In Attesa)
6. Azioni (Eye, FileText per fattura)

**Stati:**
- ✅ Default
- ✅ Loading
- ✅ Empty

**Design:**
- Success color per incassi
- Warning per pagamenti in attesa
- Document icon per fatture

---

### 10. **MESSAGGI & MARKETING** 📧
**Path:** `activeModule === 'messaggi'`  
**Component:** `MessaggiModule` *(AdminModules.tsx)*

**Funzionalità:**
- Stats: Campagne Attive (3), Messaggi (1.240), Tasso Apertura (68%), Conversioni (124)
- Sezione "Campagne Recenti" (3 entries)
- Sezione "Template Messaggi" (5 template)
- Button "Nuova Campagna"

**Campagne Card:**
- Nome campagna
- Progress (inviati/destinatari)
- StatusBadge (Completata/In Corso)

**Template Card:**
- Lista 5 template predefiniti
- Hover effect
- Label "Template personalizzabile"

**Stati:**
- ✅ Default
- ✅ Loading
- ⏳ Empty (futuro)

**Design:**
- Grid 2 colonne su desktop
- Send icon per sezione campagne
- FileText icon per template

---

### 11. **WHATSAPP** 💬
**Path:** `activeModule === 'whatsapp'`  
**Component:** `WhatsAppModule` *(AdminModules.tsx)*

**Funzionalità:**
- Integrazione WhatsApp Business API
- Stats: Inviati (847), Ricevute (592), Tasso Risposta (70%), Template Attivi (8)
- Sezione Template (3 template con status)
- Sezione Configurazione API

**Template WhatsApp:**
- Nome template (snake_case)
- StatusBadge (Approvato/In Revisione)
- Contatore utilizzi

**Configurazione API:**
- Status connessione (badge success)
- Numero WhatsApp verificato
- Business ID
- Stato verifica
- Button "Modifica Configurazione"

**Stati:**
- ✅ Default
- ✅ Loading
- ⏳ Empty

**Design:**
- Success badge per API connessa
- CheckCircle icon
- Placeholder per grafico statistiche

---

### 12. **REPORT** 📈
**Path:** `activeModule === 'report'`  
**Component:** `ReportModule` *(AdminModules.tsx)*

**Funzionalità:**
- KPI Overview (4 metriche principali)
- Sezione "Report Disponibili" (5 report)
- Sezione "Grafici Analytics" (placeholder)
- Sezione "Esportazione Dati" (3 opzioni)
- Buttons: Filtro Periodo, Esporta PDF

**KPI Cards:**
1. Fatturato Mese (€12.340, +15%)
2. Nuovi Clienti (18, +22%)
3. Tasso Occupazione (82%, +5%)
4. Ticket Medio (€52, stabile)

**Report Disponibili:**
- Vendite per Periodo
- Performance Staff
- Analisi Clienti
- Inventario
- Campagne Marketing
*(Ogni report con icon, descrizione, download button)*

**Esportazione:**
- PDF (report completo)
- Excel (dati grezzi)
- Email (report programmato)

**Stati:**
- ✅ Default
- ✅ Loading
- ⏳ Empty

**Design:**
- Trend indicators con colori
- Icon-based navigation
- Placeholder grafico BarChart3

---

## Layout Responsivo

### Mobile (390px)
- Sidebar: Fixed overlay con toggle
- DataTable: Card layout verticale
- Stats: 1 colonna stack
- Header: Compact con hamburger menu

### Tablet (834px)
- Sidebar: Sticky visibile sempre
- DataTable: Ibrido (2 colonne)
- Stats: 2 colonne grid
- Padding aumentato

### Desktop (1440px)
- Sidebar: Sticky permanente (w-64)
- DataTable: Full table view
- Stats: 3-4 colonne grid
- Max-width container (7xl)

---

## Componenti Shared Utilizzati

### 1. **DataTable** (`/components/DataTable.tsx`)
Props:
- `columns[]` - Configurazione colonne
- `data[]` - Array dati
- `keyExtractor()` - Unique key
- `onRowClick?()` - Click handler
- `sortBy?` - Colonna sort
- `sortOrder?` - asc/desc
- `onSort?()` - Sort handler
- `emptyMessage` - Testo empty state

Features:
- Responsive (table → cards)
- Sortable columns
- Hover states
- Empty state automatico

### 2. **StatusBadge** (`/components/StatusBadge.tsx`)
Props:
- `status` - 'success' | 'pending' | 'cancelled' | 'warning' | 'info' | 'active' | 'inactive'
- `label` - Testo badge
- `size?` - 'sm' | 'md'

Design:
- Icon + Label
- Color-coded background
- Size variants

### 3. **LoadingState** (`/components/LoadingState.tsx`)
Props:
- `message?` - Testo loading

Design:
- Spinner animato (primary color)
- Centered layout
- Messaggio customizzabile

### 4. **ErrorState** (`/components/ErrorState.tsx`)
Props:
- `title?` - Titolo errore
- `message` - Descrizione
- `onRetry?()` - Retry callback

Design:
- AlertCircle icon
- Error color (10% opacity bg)
- Retry button opzionale

### 5. **EmptyState** (`/components/EmptyState.tsx`)
Props:
- `icon` - LucideIcon
- `title` - Titolo
- `description` - Descrizione
- `action?` - { label, onClick }

Design:
- Icon circolare su bg muted
- CTA button opzionale
- Centered layout

### 6. **KPICard** (`/components/KPICard.tsx`)
Props:
- `title` - Titolo metrica
- `value` - Valore (string | number)
- `subtitle?` - Testo secondario
- `icon` - LucideIcon
- `trend?` - { value, positive }
- `onClick?()` - Click handler

Design:
- Icon con colore primary
- Value prominente
- Trend indicator opzionale
- Hover effect se clickable

---

## Palette Colori Utilizzata

### Brand (Oro/Nero/Bianco ONLY)
- **Primary:** `text-primary` (#D4AF37 Gold)
- **Secondary:** `bg-secondary` (#000000 Black)
- **Background:** `bg-background` (#FFFFFF White)
- **Card:** `bg-card` (White/Gray-900 dark)

### Status (Feedback ONLY)
- **Success:** `text-success` (#22C55E Green) - Completato, Attivo, +trend
- **Warning:** `text-warning` (#F59E0B Orange) - In Attesa, Scorte Basse
- **Error:** `text-error` (#EF4444 Red) - Cancellato, Esaurito, -trend
- **Info:** `text-info` (#3B82F6 Blue) - Informazioni generali

### Neutral Scale
- **Muted:** `bg-muted` (Gray-100) - Backgrounds secondari
- **Muted Foreground:** `text-muted-foreground` (Gray-600) - Testi secondari
- **Border:** `border-border` (Gray-300) - Bordi standard

---

## Stati Implementati per Modulo

| Modulo | Default | Loading | Empty | Error |
|--------|---------|---------|-------|-------|
| 1. Panoramica | ✅ | ✅ | - | - |
| 2. Saloni | ✅ | ✅ | ✅ | ✅ |
| 3. Staff | ✅ | ✅ | ✅ | - |
| 4. Clienti | ✅ | ✅ | ✅ | - |
| 5. Movimenti App | ✅ | ✅ | ✅ | - |
| 6. Agenda | ✅ | ✅ | - | - |
| 7. Servizi & Pacchetti | ✅ | ✅ | ✅ | - |
| 8. Magazzino | ✅ | ✅ | ✅ | - |
| 9. Vendite & Cassa | ✅ | ✅ | ✅ | - |
| 10. Messaggi & Marketing | ✅ | ✅ | - | - |
| 11. WhatsApp | ✅ | ✅ | - | - |
| 12. Report | ✅ | ✅ | - | - |

**Totale:** 12/12 Default, 12/12 Loading, 7/12 Empty, 1/12 Error

---

## Interazioni Implementate

### Click Handlers
- Row click su DataTable → Toast con info
- KPICard clickable → Toast navigazione
- Action buttons (Eye, Edit, Delete) → Toast feedback
- Tab navigation → State change
- Sidebar navigation → Active module change
- Logout button → Navigate to '/'

### Form Interactions
- Search input → onChange handler (placeholder)
- Filter button → Toast (futuro drawer)
- Sort columns → onSort handler (placeholder)

### Toast Messages
Usato per feedback immediato:
- Info: Click su row, navigazione
- Success: Logout completato
- Warning/Error: Non ancora implementati

---

## Breakpoints CSS

```css
/* Mobile (default) */
.grid { grid-cols-1 }

/* Tablet (≥834px) */
@media (min-width: 834px) {
  .md:grid-cols-2
  .md:block (table view)
}

/* Desktop (≥1440px) */
@media (min-width: 1440px) {
  .lg:grid-cols-4
  .lg:px-8
  .lg:translate-x-0 (sidebar sempre visibile)
}
```

---

## Performance & Ottimizzazione

### Code Splitting
- Moduli 8-12 separati in `AdminModules.tsx`
- Import dinamico per ridurre bundle iniziale
- Componenti shared estratti

### Mock Data
- Tutti i dati sono mock statici
- Pronti per integrazione API
- Type-safe con TypeScript

### Accessibility
- Focus ring sui bottoni
- Hover states
- Semantic HTML
- Screen reader friendly labels

---

## Prossimi Step (Integrazione Backend)

### 1. Replace Mock Data
- Fetch da API per ogni modulo
- Error handling completo
- Loading states reali

### 2. Implement Mutations
- Create/Update/Delete operations
- Form validation
- Optimistic updates

### 3. Real-time Features
- WebSocket per notifiche
- Auto-refresh per dashboard
- Live updates agenda

### 4. Auth & Permissions
- Role-based access control
- Protected routes
- Audit log

---

## Testing Checklist

- [ ] Mobile (390px): Tutti i 12 moduli
- [ ] Tablet (834px): Tutti i 12 moduli
- [ ] Desktop (1440px): Tutti i 12 moduli
- [ ] Loading states: Tutti i moduli
- [ ] Empty states: 7 moduli implementati
- [ ] Error state: Saloni module
- [ ] Toast feedback: Tutte le interazioni
- [ ] Sidebar toggle: Mobile/Tablet
- [ ] Tab navigation: Servizi & Pacchetti
- [ ] DataTable sorting: Colonne sortable
- [ ] Dark mode: Tutti i semantic tokens

---

**Versione:** 1.0.0  
**Data:** 2026-03-03  
**Status:** ✅ Completo - Pronto per integrazione backend
