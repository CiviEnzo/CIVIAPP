# YouBook Staff Dashboard - Struttura Completa

## Overview
Dashboard Staff completa con Agenda (giorno/settimana), Richieste Ferie/Permessi e Dettaglio Cliente read-only. Design responsive per Mobile (390x844), Tablet (834x1194) e Desktop (1440x1024).

---

## Architettura

### File Structure
```
/src/app/pages/staff/
└── StaffDashboard.tsx      # Layout + 2 tab + Client Detail
```

### Naming Convention
Pattern: `Staff/[Area]/[Component]/Responsive/[State]`

Esempi:
- `Staff/Dashboard/Layout/Responsive/Default`
- `Staff/Agenda/Calendar/Responsive/Default`
- `Staff/Client/Detail/Responsive/ReadOnly`
- `Staff/Requests/List/Responsive/Default`

---

## Layout Principale

### Header
**Component:** `Staff/Dashboard/Header/Responsive/Default`

**Elementi:**
- Logo "YouBook Staff" (primary color)
- Bell icon con notification dot (error)
- Logout button

**Design:**
- Sticky top (z-40)
- Border bottom
- Height: 64px (h-16)

### Tab Navigation
**Component:** `Staff/Dashboard/Tabs/Responsive/Default`

**Tabs:**
1. **Agenda** (Calendar icon)
2. **Ferie & Permessi** (Briefcase icon)

**Stati:**
- Active: border-primary, text-primary, font-medium
- Inactive: border-transparent, text-muted-foreground
- Transition: smooth color change

**Design:**
- Border-bottom indicator
- Full-width flex layout
- Icon + Label su mobile/tablet/desktop

---

## 1. AGENDA TAB 📅

### Features
- ✅ Vista Giorno
- ✅ Vista Settimana  
- ✅ Navigation (prev/next)
- ✅ Stats cards (4 KPI)
- ✅ Click su appointment → Client Detail
- ✅ Status badges (confermato/in attesa)
- ✅ Empty state
- ✅ Loading state

### Vista Giorno
**Component:** `Staff/Agenda/DayView/Responsive/Default`

#### Header con View Switcher
```
[<- Oggi, 3 Marzo 2026 ->]  [Giorno] [Settimana]
```
- Navigation buttons (prev/next day)
- Current date display (weekday + full date IT)
- View toggle buttons (gold primary quando attivo)

#### Stats Cards (4 KPI)
Grid 2 colonne mobile, 4 colonne desktop:

1. **Appuntamenti** - Totale giornata (4)
2. **Confermati** - Success color (3)
3. **In Attesa** - Warning color (1)
4. **Incasso Previsto** - Primary color (€210)

**Design:**
- Card con border
- Label muted-foreground
- Value 2xl font-bold
- Semantic colors per status

#### Lista Appuntamenti
**Component:** `Staff/Agenda/AppointmentCard/Responsive/Default`

**Card Structure:**
```
┌─────────────────────────────────────┐
│ Maria Rossi           [Confermato]  │
│ Taglio e Piega                      │
│ [Note icon] Cliente preferisce...   │  (opzionale)
│                                     │
│ 🕐 09:00 - 10:30     €45    →      │
└─────────────────────────────────────┘
```

**Elementi:**
- Cliente name (font-semibold)
- StatusBadge (sm size)
- Service name (text-sm muted)
- Notes box (bg-muted/50) se presente
- Footer: Clock + Time range | Tag + Price

**Interazioni:**
- Hover: border-primary
- Click: Apre Client Detail Drawer
- Cursor pointer

**Stati:**
- Confermato: StatusBadge success
- In attesa: StatusBadge pending

**Empty State:**
- Calendar icon centrale
- Titolo: "Nessun appuntamento"
- Descrizione: "Non ci sono appuntamenti programmati per oggi"

### Vista Settimana
**Component:** `Staff/Agenda/WeekView/Responsive/Default`

#### Header Navigation
```
[<- Settimana 1 ->]
    Marzo 2026
```
- Prev/Next week buttons
- Week number
- Month + Year

#### Week Grid
Grid responsive: 2 colonne mobile, 3 tablet, 7 desktop

**Day Card:**
```
┌─────────┐
│ Mar     │  (label small)
│ 3       │  (day big+bold)
│ 📅 4 app.│ (count)
│ Weekend │  (se Sab/Dom, warning)
└─────────┘
```

**Stati:**
- Today: border-primary, bg-primary/5, text-primary
- Other days: border-border, hover:border-primary/50
- Weekend: label "Weekend" in warning color
- Click: Switch to day view con quella data

**Week Summary Card:**
- Tot. Appuntamenti settimana (33)
- Media Giornaliera (5)
- Incasso Previsto (€1.240)
- Grid 1/3 colonne

---

## 2. CLIENT DETAIL DRAWER 👤

### Trigger
Click su appointment card → Full screen drawer

### Layout
**Component:** `Staff/Client/Detail/Responsive/ReadOnly`

**Structure:**
- Sticky header con close button
- Scrollable content
- Max-width 4xl centered

### Sections

#### 1. Current Appointment (Highlighted)
**Design:** `bg-primary/10 border border-primary/20`

**Info Grid (2 colonne):**
- Servizio
- Orario (time + duration)
- Prezzo (€ in primary)
- Stato (StatusBadge)
- Note appuntamento (se presenti)

#### 2. Client Info
**Icon:** User (primary)

**Fields:**
- Nome Completo (text-lg font-medium)
- Email (Mail icon + value)
- Telefono (Phone icon + value)  
- Indirizzo (MapPin icon + value)

**Layout:** Grid responsive con icons

#### 3. Client Stats (4 cards)
Grid 2/4 colonne:

1. **Visite Totali** - 24
2. **Spesa Totale** - €1.240 (primary)
3. **Ultima Visita** - 28 Febbraio 2026
4. **Cliente dal** - Gennaio 2024

#### 4. Preferenze e Note
**Icon:** FileText (primary)

**Subsections:**
- **Preferenze** - Pills primary/10 bg
  - "Prodotti senza parabeni"
  - "Taglio scalato"
  - "Colore caldo"
- **Allergie** - Text semplice
- **Note Generali** - Text box bg-muted/50

#### 5. Servizi Recenti (3 entries)
**Card per servizio:**
```
┌───────────────────────────────┐
│ Taglio e Colore        €95    │
│ 28 Feb 2026                   │
└───────────────────────────────┘
```

**Design:**
- Border card
- Service name + price (primary)
- Date (xs muted)

#### Bottom Action
- Button "Chiudi" full-width
- bg-muted, hover effect
- Chiude drawer

### Data Structure (Read-Only)
```typescript
{
  id: string;
  name: string;
  email: string;
  phone: string;
  address: string;
  totalVisits: number;
  totalSpent: number;
  lastVisit: string;
  memberSince: string;
  notes: string;
  preferences: string[];
  allergies: string;
  recentServices: Array<{
    date: string;
    service: string;
    price: number;
  }>;
}
```

---

## 3. FERIE & PERMESSI TAB 📋

### Features
- ✅ Lista richieste con 3 stati (pending/approved/rejected)
- ✅ Form nuova richiesta
- ✅ Stats cards (4 KPI)
- ✅ Timeline eventi
- ✅ Rejection reason display
- ✅ Empty state
- ✅ Loading state

### List View
**Component:** `Staff/Requests/List/Responsive/Default`

#### Header
- Titolo + Descrizione
- Button "Nuova Richiesta" (primary, con Plus icon)

#### Stats Cards (4 KPI)
Grid 2/4 colonne:

1. **Totali** - 4
2. **In Attesa** - 1 (warning)
3. **Approvate** - 2 (success)
4. **Rifiutate** - 1 (error)

#### Request Card
**Component:** `Staff/Requests/Card/Responsive/[State]`

**Structure per stato:**

##### PENDING (In Attesa)
```
┌──────────────────────────────────────┐
│ FERIE              [In attesa] ⚠️    │
│ Dal 15 Mar al 20 Mar (6 giorni)     │
│                                      │
│ [Note box se presenti]              │
│                                      │
│ 🕐 Inviata il 1 Marzo 2026          │
└──────────────────────────────────────┘
```

**Design:**
- StatusBadge warning
- AlertCircle icon in bg-warning/10 box
- Note in bg-muted/50

##### APPROVED (Approvata)
```
┌──────────────────────────────────────┐
│ PERMESSO           [Approvata] ✓     │
│ Dal 8 Apr al 8 Apr (1 giorno)       │
│                                      │
│ [Note: Visita medica]               │
│                                      │
│ 🕐 Inviata il 25 Feb 2026           │
│ ✓ Approvata il 26 Feb 2026          │
└──────────────────────────────────────┘
```

**Design:**
- StatusBadge success
- Check icon in bg-success/10 box
- Timeline con check icon verde

##### REJECTED (Rifiutata)
```
┌──────────────────────────────────────┐
│ FERIE              [Rifiutata] ✗     │
│ Dal 1 Ago al 15 Ago (15 giorni)     │
│                                      │
│ [Note: Ferie estive]                │
│                                      │
│ ⚠️ Motivo Rifiuto:                  │
│ Periodo già richiesto da altro      │
│ staff                                │
│                                      │
│ 🕐 Inviata il 28 Feb 2026           │
│ ✗ Rifiutata il 29 Feb 2026          │
└──────────────────────────────────────┘
```

**Design:**
- StatusBadge cancelled (error)
- XCircle icon in bg-error/10 box
- Rejection reason box (bg-error/10, border-error/20)
- Timeline con X icon rosso

#### Empty State
- Briefcase icon
- Titolo: "Nessuna richiesta"
- Descrizione: "Non hai ancora inviato richieste..."
- Action button: "Nuova Richiesta"

### Form View
**Component:** `Staff/Requests/Form/Responsive/Default`

**Trigger:** Click "Nuova Richiesta" → Sostituisce List View

#### Form Fields

1. **Tipo*** (Required)
   - Dropdown: Ferie / Permesso / Malattia
   - Full width

2. **Date Grid (2 colonne)**
   - Data Inizio* (date input)
   - Data Fine* (date input)

3. **Note** (Optional)
   - Textarea (3 rows)
   - Placeholder: "Aggiungi dettagli o motivazione..."
   - Resize disabled

#### Action Buttons
- **Annulla** - bg-muted, flex-1
- **Invia Richiesta** - bg-primary, flex-1, shadow

**Comportamento:**
- Submit: Toast success + Close form + Reset
- Annulla: Close form + Reset

---

## Stati Implementati

### Per Componente

| Componente | Default | Loading | Empty | Error |
|------------|---------|---------|-------|-------|
| Agenda Day View | ✅ | ✅ | ✅ | - |
| Agenda Week View | ✅ | ✅ | - | - |
| Client Detail | ✅ | - | - | - |
| Requests List | ✅ | ✅ | ✅ | - |
| Requests Form | ✅ | - | - | - |

### Status Badge Mapping

#### Appuntamenti
- `confirmed` → StatusBadge `success` → "Confermato"
- `pending` → StatusBadge `pending` → "In attesa"

#### Richieste Ferie
- `pending` → StatusBadge `pending` → "In attesa" (warning)
- `approved` → StatusBadge `success` → "Approvata" (success)
- `rejected` → StatusBadge `cancelled` → "Rifiutata" (error)

---

## Responsive Behavior

### Mobile (390px)
- **Header:** Compact, icons only per actions
- **Tabs:** Full width, icon + label
- **Agenda Stats:** 2 colonne grid
- **Appointments:** Full width cards, stacked
- **Week Grid:** 2 colonne
- **Client Detail:** Full screen overlay
- **Requests:** Single column

### Tablet (834px)
- **Week Grid:** 3 colonne
- **Agenda Stats:** 4 colonne
- **Client Info:** 2 colonne grid per contacts
- **Form:** 2 colonne per date fields

### Desktop (1440px)
- **Max Width:** 6xl container per Agenda, 4xl per Requests, 4xl per Client Detail
- **Week Grid:** 7 colonne (full week visible)
- **Padding:** lg (8) per main content
- **Stats:** 4 colonne sempre

---

## Color Palette Usage

### Brand (Oro/Nero/Bianco)
- **Primary:** `text-primary` - Prices, selected states, icons
- **Background:** `bg-background` - Page bg
- **Card:** `bg-card` - Surface containers

### Status (Feedback ONLY)
- **Success:** `text-success` / `bg-success/10` - Confirmed, Approved
- **Warning:** `text-warning` / `bg-warning/10` - Pending
- **Error:** `text-error` / `bg-error/10` - Rejected

### Neutral
- **Muted:** `bg-muted` - Secondary surfaces
- **Muted Foreground:** `text-muted-foreground` - Secondary text
- **Border:** `border-border` - Separatori

---

## Interazioni

### Click Handlers
- **Appointment card** → Apre Client Detail Drawer
- **Week day card** → Switch to day view + set date
- **Close drawer button** → Chiude Client Detail
- **Nuova Richiesta button** → Mostra Form
- **Form Annulla** → Torna a List
- **Form Submit** → Toast + Reset + Torna a List
- **Logout** → Navigate to '/' + Toast

### Navigation
- **Prev/Next Day** → Cambia data selezionata (giorno)
- **Prev/Next Week** → Cambia data selezionata (settimana -/+ 7 giorni)
- **View Switcher** → Toggle day/week view
- **Tab Switcher** → Change active tab (agenda/ferie)

### Toast Messages
- Success: "Logout effettuato"
- Success: "Richiesta inviata con successo"
- (Future: Error handling per API failures)

---

## Data Structures

### Appointment
```typescript
{
  id: string;
  clientName: string;
  clientId: string;
  service: string;
  time: string;           // HH:mm format
  duration: number;       // minutes
  status: 'confirmed' | 'pending';
  price: number;
  notes: string;
}
```

### Request (Ferie/Permessi)
```typescript
{
  id: string;
  type: 'ferie' | 'permesso' | 'malattia';
  startDate: string;      // Formatted IT
  endDate: string;        // Formatted IT
  days: number;
  status: 'pending' | 'approved' | 'rejected';
  submittedAt: string;
  approvedAt?: string;
  rejectedAt?: string;
  rejectionReason?: string;
  notes: string;
}
```

### Week Day (Vista Settimana)
```typescript
{
  date: Date;
  label: string;          // Lun, Mar, Mer...
  day: string;            // 1, 2, 3...
  count: number;          // Num appuntamenti
}
```

---

## Componenti Shared Utilizzati

### StatusBadge
```typescript
<StatusBadge 
  status="success" | "pending" | "cancelled"
  label="Confermato" | "In attesa" | "Rifiutata"
  size="sm" | "md"
/>
```

### LoadingState
```typescript
<LoadingState message="Caricamento agenda..." />
```

### EmptyState
```typescript
<EmptyState
  icon={Calendar}
  title="Nessun appuntamento"
  description="Non ci sono appuntamenti per oggi"
  action={{ label: "...", onClick: () => {} }}  // optional
/>
```

---

## Accessibility

- ✅ Focus ring su tutti gli elementi interattivi
- ✅ Hover states chiari
- ✅ Color contrast AA compliant
- ✅ Semantic HTML (header, main, nav)
- ✅ Button text leggibile
- ✅ Icon + Label per clarity

---

## Animations & Transitions

### Smooth Transitions
- Tab switch: color change `transition-colors`
- Button hover: background opacity
- Card hover: border-primary
- View switcher: background color

### No Heavy Animations
- Preferenza per instant feedback
- Transizioni veloci (150-250ms)

---

## Mock Data vs API Ready

### Current: Mock Data
- 4 appointments hardcoded
- 4 requests hardcoded
- 1 client detail hardcoded
- Week data generated

### API Integration Points
```typescript
// Agenda
const appointments = await fetchAppointments(date);
const weekData = await fetchWeekSummary(weekStart, weekEnd);

// Requests
const requests = await fetchStaffRequests(staffId);
const submitRequest = async (data) => { ... };

// Client
const clientDetail = await fetchClientById(clientId);
```

---

## Testing Checklist

### Mobile (390px)
- [ ] Header responsive
- [ ] Tabs full width
- [ ] Agenda stats 2 cols
- [ ] Appointments stacked
- [ ] Week grid 2 cols
- [ ] Client detail full screen
- [ ] Form fields full width

### Tablet (834px)
- [ ] Week grid 3 cols
- [ ] Stats 4 cols
- [ ] Form date fields 2 cols

### Desktop (1440px)
- [ ] Week grid 7 cols
- [ ] Max-width containers
- [ ] Padding increased
- [ ] All layouts optimal

### Functionality
- [ ] Day navigation works
- [ ] Week navigation works
- [ ] View switcher toggles
- [ ] Client detail opens/closes
- [ ] Form submit works
- [ ] Form cancel works
- [ ] Empty states show
- [ ] Loading states show
- [ ] All status badges correct

---

## Performance

- ✅ No unnecessary re-renders
- ✅ useState per UI state locale
- ✅ Conditional rendering per views
- ✅ Lazy rendering per long lists
- ✅ Optimized for 60fps transitions

---

## Future Enhancements

### Agenda
- [ ] Drag & drop appuntamenti
- [ ] Filter per servizio
- [ ] Export calendario
- [ ] Sync con Google Calendar
- [ ] Real-time updates

### Ferie/Permessi
- [ ] Notification push per approval
- [ ] Attachment documenti (certificati)
- [ ] Calendario ferie team
- [ ] Balance giorni disponibili

### Client Detail
- [ ] Note editing (con permessi)
- [ ] Photo upload
- [ ] Appointment history full
- [ ] Direct messaging

---

**Versione:** 1.0.0  
**Data:** 2026-03-03  
**Status:** ✅ Completo - Ready for API integration
**Naming:** ✅ Conforme a Role/Area/Component/Variant/State
