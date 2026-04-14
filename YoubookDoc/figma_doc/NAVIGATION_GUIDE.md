# YouBook - Navigation Guide

**Quick Reference** per navigare tra i diversi dashboard durante lo sviluppo

---

## 🏠 **Homepage - Dashboard Selector**

**URL:** `http://localhost:5173/`

Pagina di selezione con cards per:
- ✅ Admin Dashboard
- ✅ Staff Dashboard  
- ✅ Client Dashboard
- ✅ Client Discovery
- ✅ Cross-Module States
- ✅ MCP Code Connect

**Funzione:** Click su una card per navigare direttamente

---

## 🎯 **URL Diretti (Copy-Paste)**

### **Main Dashboards:**

```bash
# Admin Dashboard (12 moduli)
http://localhost:5173/admin

# Staff Dashboard (2 sezioni)
http://localhost:5173/staff

# Client Dashboard (5 tab + 7 drawer)
http://localhost:5173/client/dashboard

# Client Discovery
http://localhost:5173/client
```

### **Utility Pages:**

```bash
# Cross-Module States (18 edge cases)
http://localhost:5173/cross-module-states

# MCP Code Connect (22 componenti)
http://localhost:5173/mcp-code-connect
```

### **Auth Pages:**

```bash
# Sign In
http://localhost:5173/signin

# Register Client
http://localhost:5173/register

# Register Center
http://localhost:5173/register-center

# Onboarding
http://localhost:5173/onboarding

# Password Reset
http://localhost:5173/password-reset
```

---

## 🔀 **Navigazione Veloce Browser**

### **Chrome DevTools:**

Apri Console (F12) e usa:

```javascript
// Vai ad Admin
location.href = '/admin'

// Vai a Staff
location.href = '/staff'

// Vai a Client
location.href = '/client/dashboard'

// Torna al selector
location.href = '/'
```

---

## ⌨️ **Keyboard Shortcuts (Opzionale)**

Se vuoi aggiungere shortcuts:

```typescript
// In /src/app/App.tsx
useEffect(() => {
  const handleKeyPress = (e: KeyboardEvent) => {
    if (e.ctrlKey || e.metaKey) {
      switch(e.key) {
        case '1': navigate('/admin'); break;
        case '2': navigate('/staff'); break;
        case '3': navigate('/client/dashboard'); break;
        case '0': navigate('/'); break; // Back to selector
      }
    }
  };
  
  window.addEventListener('keydown', handleKeyPress);
  return () => window.removeEventListener('keydown', handleKeyPress);
}, []);
```

**Shortcuts:**
- `Ctrl/Cmd + 1` → Admin
- `Ctrl/Cmd + 2` → Staff
- `Ctrl/Cmd + 3` → Client
- `Ctrl/Cmd + 0` → Selector

---

## 📱 **Responsive Testing**

### **Chrome DevTools Device Mode (F12):**

1. Click su **Toggle Device Toolbar** (Ctrl+Shift+M)
2. Seleziona device:
   - **Mobile:** iPhone 14 Pro (390x844)
   - **Tablet:** iPad Pro 11" (834x1194)  
   - **Desktop:** Custom 1440x1024

### **Quick Dimensions:**

```
Mobile:  390x844
Tablet:  834x1194
Desktop: 1440x1024
```

---

## 🗂️ **Struttura Admin (12 Moduli)**

Dalla sidebar Admin puoi navigare tra:

1. **Panoramica** - KPI + overview
2. **Saloni** - Gestione multi-sede
3. **Staff** - Team management
4. **Clienti** - Client database
5. **Movimenti** - Transactions
6. **Agenda** - Calendar (grid + settimana)
7. **Servizi** - Services/Products/Packages
8. **Magazzino** - Inventory
9. **Vendite** - Sales + Cassa
10. **Messaggi** - SMS/Email campaigns
11. **WhatsApp** - WhatsApp templates
12. **Report** - Analytics

**Come navigare:** Click su voce sidebar o usa URL:
```
http://localhost:5173/admin/saloni
http://localhost:5173/admin/staff
http://localhost:5173/admin/clienti
...
```

---

## 👥 **Struttura Staff (2 Sezioni)**

Bottom navigation mobile o sidebar desktop:

1. **Agenda** - Vista giorno/settimana appuntamenti
2. **Ferie** - Richieste permessi

**Come navigare:** Click su tab o URL:
```
http://localhost:5173/staff/agenda
http://localhost:5173/staff/ferie
```

---

## 🧑 **Struttura Client (5 Tab + 7 Drawer)**

### **Main Tabs (Bottom Nav):**

1. **Home** - Welcome + next appointment + promos
2. **Agenda** - Lista appuntamenti (upcoming + history)
3. **Prenota** - Booking flow (4 step)
4. **Carrello** - Cart summary
5. **Info** - Salon info + gallery

### **Drawer Sections (Hamburger Menu):**

1. **Punti Fedeltà** - Loyalty points (420 pts)
2. **Pacchetti** - Active packages (3)
3. **Preventivi** - Quotes with Stripe payment
4. **Fatturazione** - Invoices list
5. **Questionari** - Surveys
6. **Le Mie Foto** - Photo gallery
7. **Impostazioni** - Settings

**Come navigare:** 
- Tabs: Click su bottom nav
- Drawer: Click su ☰ top-left → Select item

---

## 🎨 **Testing Flow Completo**

### **Booking Flow (Client):**

1. Home → Click "Prenota Ora"
2. Step 1: Seleziona Servizio (lista)
3. Step 2: Seleziona Data/Ora (calendario)
4. Step 3: Seleziona Staff (preferito/disponibile)
5. Step 4: Conferma + Note
6. → Success toast + redirect Agenda

### **Quote Payment Flow (Client):**

1. Drawer → Preventivi
2. Click su quote "Pending"
3. Click "Paga €XXX"
4. Modal Stripe form
5. Compila carta/scadenza/CVV
6. Click "Paga con Stripe"
7. → Loading → Success → Quote status "Accepted"

### **Time Off Request (Staff):**

1. Ferie tab
2. Click "+ Nuova Richiesta"
3. Modal: Tipo + Date + Motivo
4. Submit
5. → Pending status (admin deve approvare)

---

## 🔍 **Testing Edge Cases**

Visita: `http://localhost:5173/cross-module-states`

**18 Edge Cases Precaricati:**

1. **Conflitto Agenda:** 2 appuntamenti stesso orario
2. **Pagamento Fallito:** Stripe error on checkout
3. **Quote Scaduto:** Expired quote con rigenera
4. **Richiesta Ferie Rifiutata:** Con motivo admin
5. **Scorte Sotto Minimo:** Inventory alert
6. **Appuntamento No-Show:** Client non si presenta
7. **Pacchetto Scaduto:** Unused services
8. **Sovrapposizione Staff:** Double booking
9. **Cliente Blacklist:** Blocked customer
10. **Pagamento Parziale:** Partial payment pending
11. **Servizio Disabilitato:** Service no longer available
12. **Staff In Ferie:** No availability
13. **Slot Doppio Booking:** Multiple clients same time
14. **Fattura Scaduta:** Overdue invoice 30+ days
15. **Promo Scaduta:** Expired promotion
16. **Questionario Obbligatorio:** Mandatory survey
17. **Foto Richiesta Approvazione:** Photo pending review
18. **Notifica Non Letta Urgente:** Critical unread

---

## 📊 **MCP Code Connect Testing**

Visita: `http://localhost:5173/mcp-code-connect`

**Features:**
- **Filtri:** Priority (P0/P1/P2) + Role
- **Cards:** 22 componenti con metadata
- **Detail Modal:** Click ChevronRight per props dettagliate
- **Copy Code:** Click Copy per Flutter code

**Priority Filter:**
- **P0** (5): Agenda Cards + KPI
- **P1** (10): Drawer + Quote/Payment + Notifications
- **P2** (7): Shared States + Client Home

---

## 🚀 **Production URLs (Post Deploy)**

Dopo `vercel --prod`:

```bash
# Dashboard Selector
https://youbook-abc123.vercel.app/

# Admin
https://youbook-abc123.vercel.app/admin

# Staff
https://youbook-abc123.vercel.app/staff

# Client
https://youbook-abc123.vercel.app/client/dashboard

# MCP Code Connect
https://youbook-abc123.vercel.app/mcp-code-connect
```

---

## 🐛 **Troubleshooting**

### **404 Not Found**

**Causa:** SPA routing

**Fix:** Ricarica pagina o usa navigation dal selector

### **Blank Page**

**Causa:** JavaScript error

**Fix:** 
1. Apri Console (F12)
2. Verifica errori
3. Check import paths

### **Styling Issues**

**Causa:** Tailwind non caricato

**Fix:** Verifica `/src/styles/theme.css` importato

---

## 💡 **Tips**

1. **Usa sempre il Dashboard Selector** (`/`) come punto di partenza
2. **Bookmark URL diretti** per dashboard frequenti
3. **Chrome DevTools Device Mode** per responsive testing
4. **Console logs** disabilitati in prod, abilitati in dev
5. **Hot reload** funziona su tutte le pagine

---

## 📞 **Quick Help**

**Dashboard non si carica?**
→ Check console (F12) per errori

**Styling rotto?**
→ Verifica `/src/styles/theme.css`

**404 su reload?**
→ Vercel/Netlify rewrites non configurati (vedi `/DEPLOY_INSTRUCTIONS.md`)

**Performance slow?**
→ Apri Chrome DevTools → Performance tab → Record

---

**Happy Development!** 🚀
