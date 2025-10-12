# CIVIAPP — Guida SaaS “brand autonomo” (WhatsApp Cloud API multi-tenant)
[Versione Codex‑ready] Architettura, data model, onboarding OAuth, webhook routing, boilerplate Cloud Functions/Flutter e comandi pronti.

## 0) Overview
- Ogni salone collega il **proprio** WABA (OAuth), numero e template → invia con **brand e crediti** propri.
- Backend unico con **routing multi‑tenant** (phone_number_id → salonId).
- Token e verify token per salone in **Secret Manager**.

## 1) Data model essenziale
/salons/{salonId}.whatsapp = { mode: "own", businessId, wabaId, phoneNumberId, tokenSecretId, verifyTokenSecretId }
...
/message_outbox, /delivery_receipts, /message_templates (scopo salone)

## 2) Endpoints
- POST /wa/sendTemplate
- GET|POST /wa/webhook
- GET /wa/oauth/start, GET /wa/oauth/callback
- scheduler: dispatchOutbox (every 5 min)

## 3) Boilerplate TS (estratto)
- wa/config.ts getSalonWaConfig()
- wa/secrets.ts readSecret()
- wa/sendTemplate.ts (chiama Graph API v19)
- wa/webhook.ts (verify + routing + handlers)
- scheduler/dispatchOutbox.ts (quiet hours + rate limit base)

## 4) Flutter Admin (stub)
- whatsapp_settings_page.dart
- template_list_page.dart
- campaign_editor_page.dart
- whatsapp_service.dart → HTTPS sendTemplate

## 5) GDPR & Sicurezza
- Consenso marketing separato; opt‑out STOP; quiet hours 09‑21 Europe/Rome
- Secret Manager per token per‑tenant; Firestore Rules per salonId/ruolo

## 6) Comandi per Codex
[COPIA/INCOLLA]
---
Crea in functions/src:
- wa/config.ts, wa/secrets.ts, wa/sendTemplate.ts, wa/webhook.ts
- scheduler/dispatchOutbox.ts
Aggiungi dipendenze: axios, @google-cloud/secret-manager.
Crea env: WA_VERIFY_TOKEN, SEND_ENDPOINT.
Implementa in Flutter: services/whatsapp_service.dart, views/admin/* come da guida.
---

## 7) Curl test
curl -X POST "$SEND_ENDPOINT" -H "Content-Type: application/json" -d '{"salonId":"salon_abc","to":"+393331234567","templateName":"appt_reminder_it_v1","lang":"it","components":[{"type":"body","parameters":[{"type":"text","text":"Maria"},{"type":"text","text":"Epilazione"},{"type":"text","text":"12/10"},{"type":"text","text":"15:00"}]}]}'

## 8) Checklist Go‑Live
- Business verificato; numero dedicato; OAuth completato; phone_number_id salvato
- Template approvati; webhook verified; test invio OK; quiet hours/rate limit attivi
