# YouBook - Deploy Instructions per MCP Code Connect

## 🚀 Quick Start

### 1️⃣ **Deploy Veloce (5 minuti)**

```bash
# Installa Vercel CLI
npm i -g vercel

# Deploy
vercel --prod

# Output esempio:
# ✅ Production: https://youbook-abc123.vercel.app
```

**Link MCP Code Connect:**
```
https://youbook-abc123.vercel.app/mcp-code-connect
```

---

## 📦 **Contenuti Disponibili**

### **A. Interface Web Interattiva**
**URL:** `/mcp-code-connect`

Features:
- 22 componenti mappati con dettagli completi
- Filtri per Priority (P0/P1/P2) e Role
- Flutter code generator automatico
- Copy-to-clipboard
- Modal dettaglio con props

### **B. JSON API Statico**
**URL:** `/mcp-mappings.json`

Contenuto:
- Lista completa mappings
- Props in Dart syntax
- 9 enums definiti
- Color system
- Dependencies tree

```bash
# Accesso diretto
curl https://youbook-abc123.vercel.app/mcp-mappings.json
```

### **C. Documentation Markdown**
**URL:** `/MCP_CODE_CONNECT_SUMMARY.md` (view source)

Contenuto:
- Implementation guide completa
- Testing strategy
- Code snippets
- Checklist 4 fasi

---

## 🔧 **Configurazione Figma Code Connect**

### **Step 1: Installa CLI**

```bash
npm install -g @figma/code-connect
```

### **Step 2: Ottieni Credenziali Figma**

1. Vai su **Figma → Settings → Personal Access Tokens**
2. Crea un nuovo token con scope `file:read`
3. Copia il token: `figd_xxxxxxxxxxxx`

### **Step 3: Ottieni File Key**

1. Apri il file Figma del Design System
2. Copia dalla URL: `https://figma.com/file/FILE_KEY/YouBook`
3. Il `FILE_KEY` è la stringa alfanumerica

### **Step 4: Configura Progetto**

Crea `/figma-code-connect.config.json`:

```json
{
  "figma": {
    "token": "figd_xxxxxxxxxxxx",
    "fileKey": "YOUR_FILE_KEY"
  },
  "codeConnect": {
    "framework": "flutter",
    "mappingSource": "https://youbook-abc123.vercel.app/mcp-mappings.json",
    "parser": "dart",
    "include": ["lib/widgets/**/*.dart"],
    "exclude": ["**/*.g.dart", "**/*.freezed.dart"]
  },
  "output": {
    "directory": "lib/generated",
    "format": "dart"
  }
}
```

### **Step 5: Pubblica Mappings**

```bash
# Dry run (test)
figma-code-connect publish --dry-run

# Publish per real
figma-code-connect publish

# Output:
# ✅ Published 22 component mappings
# ✅ YouBook Design System connected
```

---

## 🌐 **Deploy Options Dettagliati**

### **Opzione A: Vercel (Raccomandato)**

**Pro:**
- Deploy in 1 minuto
- SSL automatico
- CDN globale
- Zero config

**Steps:**

```bash
# 1. Login (prima volta)
vercel login

# 2. Deploy
vercel --prod

# 3. Custom domain (opzionale)
vercel domains add youbook-mcp.com
```

**Costi:** Gratuito (Hobby plan)

---

### **Opzione B: Netlify**

**Pro:**
- Drag & drop deploy
- Forms gratuite
- Split testing

**Steps:**

```bash
# 1. Build
npm run build

# 2. Deploy
netlify deploy --prod --dir=dist

# O via UI:
# Trascina cartella /dist su app.netlify.com
```

**Costi:** Gratuito (Starter plan)

---

### **Opzione C: Firebase Hosting**

**Pro:**
- Integrazione con Firebase services
- Rollback facile
- Multi-site hosting

**Steps:**

```bash
# 1. Install Firebase CLI
npm i -g firebase-tools

# 2. Login
firebase login

# 3. Init
firebase init hosting

# 4. Build
npm run build

# 5. Deploy
firebase deploy --only hosting
```

**Costi:** Gratuito (Spark plan: 10GB storage, 360MB/day transfer)

---

### **Opzione D: GitHub Pages**

**Pro:**
- Gratis per repo pubblici
- CI/CD con GitHub Actions

**Steps:**

1. Crea `.github/workflows/deploy.yml`:

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 18
      - run: npm ci
      - run: npm run build
      - uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./dist
```

2. Settings → Pages → Source: `gh-pages` branch

**URL:** `https://yourusername.github.io/youbook/mcp-code-connect`

**Costi:** Gratuito

---

## 🔐 **Opzione con API Protetta**

Se vuoi proteggere l'accesso:

### **1. Aggiungi API Key al Deploy**

```bash
# Vercel
vercel env add API_KEY production

# Netlify
netlify env:set API_KEY "your-secret-key"
```

### **2. Proteggi Endpoint**

Modifica `/supabase/functions/server/index.tsx`:

```typescript
app.get('/api/mcp-mappings', async (c) => {
  const apiKey = c.req.header('x-api-key');
  
  if (apiKey !== Deno.env.get('API_KEY')) {
    return c.json({ error: 'Unauthorized' }, 401);
  }
  
  // Return mappings
  return c.json(mappings);
});
```

### **3. Usa in Figma Code Connect**

```json
{
  "codeConnect": {
    "mappingSource": "https://youbook-abc123.vercel.app/api/mcp-mappings",
    "headers": {
      "x-api-key": "your-secret-key"
    }
  }
}
```

---

## 📊 **Verifica Deploy**

### **Checklist Post-Deploy:**

```bash
# ✅ Interface web accessibile
curl -I https://youbook-abc123.vercel.app/mcp-code-connect

# ✅ JSON API risponde
curl https://youbook-abc123.vercel.app/mcp-mappings.json | jq

# ✅ CORS abilitato
curl -I -X OPTIONS https://youbook-abc123.vercel.app/mcp-mappings.json

# ✅ SSL valido (A+ rating)
https://www.ssllabs.com/ssltest/analyze.html?d=youbook-abc123.vercel.app
```

### **Expected Output:**

```
HTTP/2 200
content-type: application/json
access-control-allow-origin: *
x-vercel-cache: HIT
```

---

## 🔗 **Link Finali da Condividere**

Dopo il deploy, condividi questi link:

### **1. Interface Web (Developers)**
```
https://youbook-abc123.vercel.app/mcp-code-connect
```
Per sviluppatori che vogliono esplorare i componenti con UI

### **2. JSON API (Automazione)**
```
https://youbook-abc123.vercel.app/mcp-mappings.json
```
Per tool di code generation automatica

### **3. Documentation**
```
https://youbook-abc123.vercel.app/MCP_CODE_CONNECT_SUMMARY.md
```
Per implementation guide completa

### **4. Cross-Module States**
```
https://youbook-abc123.vercel.app/cross-module-states
```
Per visualizzare tutti gli edge cases

---

## 🐛 **Troubleshooting**

### **Problema: 404 Not Found**

**Causa:** SPA routing non configurato

**Fix per Vercel:**

Crea `/vercel.json`:
```json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

**Fix per Netlify:**

Crea `/public/_redirects`:
```
/*    /index.html   200
```

---

### **Problema: CORS Error**

**Causa:** Mancano headers CORS

**Fix per Vercel:**

Aggiungi in `/vercel.json`:
```json
{
  "headers": [
    {
      "source": "/mcp-mappings.json",
      "headers": [
        { "key": "Access-Control-Allow-Origin", "value": "*" },
        { "key": "Access-Control-Allow-Methods", "value": "GET" }
      ]
    }
  ]
}
```

---

### **Problema: Build Failed**

**Causa:** Dependency errors

**Fix:**
```bash
# Pulisci cache
rm -rf node_modules package-lock.json

# Reinstalla
npm install

# Rebuild
npm run build
```

---

## 📈 **Analytics (Opzionale)**

### **Traccia Uso API:**

```typescript
// In /supabase/functions/server/index.tsx
app.get('/mcp-mappings.json', async (c) => {
  // Log request
  console.log('MCP Mapping accessed:', {
    ip: c.req.header('x-forwarded-for'),
    userAgent: c.req.header('user-agent'),
    timestamp: new Date().toISOString()
  });
  
  return c.json(mappings);
});
```

### **Dashboard con Vercel Analytics:**

```bash
# Abilita analytics
vercel analytics enable

# View dashboard
https://vercel.com/yourusername/youbook/analytics
```

---

## 🎯 **Prossimi Step**

1. ✅ Deploy su Vercel/Netlify
2. ✅ Ottieni link pubblico
3. ✅ Configura Figma Code Connect
4. ✅ Pubblica mappings
5. ⏳ Testa generazione code in Figma
6. ⏳ Itera su feedback team

---

## 📞 **Support**

**Issues:** GitHub Issues  
**Docs:** `/MCP_CODE_CONNECT_SUMMARY.md`  
**Contact:** [team@youbook.dev]

---

**Status:** ✅ READY TO DEPLOY  
**Estimated Time:** 5-10 minuti  
**Difficulty:** ⭐ Facile
