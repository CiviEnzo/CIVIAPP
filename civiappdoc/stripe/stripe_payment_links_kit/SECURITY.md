# Security & Compliance

- Use `.env` and **never** commit keys.
- Separate **test** and **live** mode per salon (`stripe_mode`).
- Validate the **Stripe signature** for every webhook request.
- Idempotency: make writes inside Firestore transactions to avoid duplicates.
- GDPR: store minimal personal data; define retention; allow data access/deletion.
- Logging: do not log full payloads containing PII in production.
