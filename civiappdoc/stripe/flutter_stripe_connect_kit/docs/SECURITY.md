# Security & Ops
- Keep secrets in `.env` and out of git.
- Use raw body on webhook and verify Stripe-Signature.
- Separate test/live envs completely.
- Only allow payments if connected account `charges_enabled=true`.
