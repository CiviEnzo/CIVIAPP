# Stripe Payment Links – Implementation Guide (Multi‑Salon)

This kit provides a **ready-to-use blueprint** to integrate **Stripe Payment Links** into your multi-salon app (“CIVIAPP”) with minimal code. It covers: data model, admin backoffice UX, webhook listener (Cloud Functions for Firebase or any Node runtime), testing with Stripe CLI, GDPR/PCI notes, and **commands for Codex**.

> **Scenario**: Each salon admin creates & pastes Payment Links into your backoffice. Customers click those links to pay for standard items (services, packages, products). You record results via **webhooks** and reconcile orders in Firestore.

---

## 0) Quick overview

- **Why Payment Links**: zero backend to create sessions, SCA/3DS handled by Stripe, Apple Pay/Google Pay, receipts, coupons, subscriptions.
- **Limitations**: no true in-app cart, each variation = separate link, limited custom logic; inventory/agenda checks must be done outside of Stripe PL.
- **When to use**: fixed catalog, promos, QR at desk, WA/SMS links, landing pages—when you value speed & simplicity over dynamic carts.

---

## 1) Architecture at a glance

```
Salon Admin  ── creates Payment Links in Stripe Dashboard ─┐
                                                           ▼
CIVIAPP Backoffice ─ stores {salonId, serviceId, payment_link_url, metadata} in Firestore
                                                           ▼
Client App / Web ─ shows buttons "Paga ora" → opens Payment Link
                                                           ▼
Stripe Hosted Checkout (Payment Links) ─ PaymentIntent/Invoice/Receipt
                                                           ▼
Webhook Listener (Cloud Function / Node) ─ on payment succeeded →
  - Create "order" doc in Firestore
  - Credit package / mark appointment paid
  - (Italy) trigger e-invoice flow to SDI via provider (FattureInCloud/Aruba/etc.)
```

### Notes on money routing
- **Simplest**: each salon has **its own Stripe account** and owns + creates its Payment Links in their dashboard. You just store the URLs.
- **With Connect**: your platform can still use Payment Links per connected account. Use only if you *must* route funds programmatically.

---

## 2) Firestore data model (minimal)

Collections (example):
- `salons/{salonId}`: business profile, `stripe_account_type`, fiscal data, flags.
- `salon_payment_links/{docId}`: per salon service/product mapping.
- `orders/{orderId}`: created by webhook, immutable payment facts.

### Example documents

**salons/{salonId}**
```json
{
  "name": "Salon Roma Centro",
  "stripe_mode": "live", 
  "country": "IT",
  "vat_number": "IT01234567890",
  "sdi_channel": "fattureincloud",
  "sdi_config_id": "fic_prod_01"
}
```

**salon_payment_links/{docId}**
```json
{
  "salonId": "salon_roma_1",
  "serviceId": "cut_color_2025_10",
  "title": "Taglio + Colore Donna",
  "type": "service",
  "currency": "EUR",
  "price": 85.00,
  "isSubscription": false,
  "stripe_link_url": "https://buy.stripe.com/xxxyyy",
  "metadata": {
    "salonId": "salon_roma_1",
    "serviceId": "cut_color_2025_10",
    "version": "v2025.10"
  },
  "enabled": true,
  "updatedAt": 1759795200
}
```

**orders/{orderId}** (created on webhook)
```json
{
  "salonId": "salon_roma_1",
  "source": "payment_link",
  "status": "paid",
  "amount_total": 8500,
  "currency": "EUR",
  "customer_email": "client@example.com",
  "stripe": {
    "payment_intent_id": "pi_...",
    "charge_id": "ch_...",
    "checkout_session_id": "cs_...",
    "payment_link_id": "plink_...",
    "product_summary": [{"name":"Taglio + Colore Donna","quantity":1,"unit_amount":8500}]
  },
  "createdAt": 1759795200
}
```

> Keep Stripe IDs (no raw card data), and enough metadata to trace fulfillment.

---

## 3) Backoffice UX (admin)

- A page per salon with a **table of Payment Links**:
  - Columns: *Title*, *Type*, *Price*, *isSubscription*, *URL*, *Status*, *UpdatedAt*.
  - Actions: **Add**, **Disable**, **Copy URL**, **Open**.
- Validate URL format (`https://buy.stripe.com/`) before saving.
- Provide tags/filters (Servizi / Pacchetti / Prodotti).
- **Governance**: use naming conventions e.g. `PL_TAGLIO_DONNA_v2025_10`. Disable old links when price changes.

---

## 4) Client UX (customer)

- In the salon page, list standard items with **price + “Paga ora”** → open the link (in-app webview or external browser).
- After redirect to Stripe hosted page, user completes payment with wallet/cards.
- On success, your **webhook** will record the order and trigger fulfillment.

In Flutter, opening the URL is as simple as:
```dart
import 'package:url_launcher/url_launcher.dart';

Future<void> openPaymentLink(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw 'Could not launch $url';
  }
}
```

---

## 5) Webhooks (must-have)

Even with Payment Links you should consume Stripe events to:
- Mark orders **paid/failed/refunded**.
- Credit packages / update client entitlements.
- Fire **e-invoice** workflow (Italy) and send internal notifications.

**Key events** (choose your minimal set):
- `checkout.session.completed`
- `payment_intent.succeeded`
- `charge.refunded`
- `customer.subscription.*` (if selling subscriptions)

This kit includes **`functions/webhook/index.js`** (Express app) with verification of Stripe signatures and Firestore writes.

> Deploy with Firebase, Cloud Run, or any Node host. For Firebase: set runtime to Node 18+, enable env vars, and add the endpoint as a Stripe webhook URL.

---

## 6) Testing with Stripe CLI

See `monitoring/stripe_cli.md` for installing the Stripe CLI and **forwarding** events to your local endpoint while developing.

- Example:
  ```bash
  stripe login
  stripe listen --events checkout.session.completed,payment_intent.succeeded --forward-to http://localhost:8080/stripe/webhook
  ```

---

## 7) Security & compliance

- **Do not trust the client** for prices; with Payment Links the price lives in Stripe.
- **Validate** webhook signatures; use **idempotency** for any write operation.
- **GDPR**: store only Stripe IDs and minimal customer data (email). Define retention schedules.
- **PCI**: Stripe hosts the payment page (reduced scope). Never log card details.
- **Keys separation**: never mix test/live; record `stripe_mode` per salon.

---

## 8) Italy – e-invoicing (SDI)

Stripe does **not** send e-invoices to SDI. On payment success:
1. Build your **invoice payload** (client data, VAT splits, items, total).
2. Call your provider API (Fatture in Cloud / Aruba / TeamSystem) to produce **FatturaPA XML** and submit to SDI.
3. Store protocol/receipt IDs back into your `orders` doc.

Template notes in `backend/italy_einvoice_notes.md`.

---

## 9) Rollout checklist

- [ ] Stripe dashboard ready for each salon (or Connect).
- [ ] Webhook endpoint deployed & secret set (`STRIPE_WEBHOOK_SECRET`).
- [ ] Firestore rules restrict writes to orders to the backend only.
- [ ] Backoffice page to manage links per salon.
- [ ] Stripe CLI tests passing.
- [ ] E-invoice integration tested on sandbox (if needed).
- [ ] Monitoring & alerting on webhook failures.

---

## 10) Give this to Codex (VS Code)

Use the commands in **`codex_commands.md`** to scaffold files, set env vars, and deploy the webhook quickly.

Happy shipping!
