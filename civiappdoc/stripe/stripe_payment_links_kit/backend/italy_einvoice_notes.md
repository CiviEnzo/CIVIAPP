# Italy e-Invoicing (SDI) Notes

Stripe does not submit e-invoices to SDI. Typical flow:
1. On `payment_intent.succeeded` or `checkout.session.completed`, gather invoice data:
   - Supplier (your salon): VAT, fiscal code, address, regime.
   - Customer: name, address, VAT or CF if business, PEC or Codice Destinatario.
   - Items: description, qty, unit price, VAT rate (22%, 10%, 5%, split if needed).
2. Create FatturaPA XML via provider API (Fatture in Cloud, Aruba, TeamSystem, etc.).
3. Submit to SDI and store protocol & receipt in `orders/{orderId}`.
4. Send PDF courtesy invoice to customer (optional).

Tip: keep a mapping of VAT profiles per item in your backoffice and tag each Payment Link row with `vat_profile_id` if needed.
