# Firebase Functions env migration

The legacy `functions.config()` Runtime Config API will stop working for new
deployments in March 2026. This project now reads configuration from standard
`.env` files. Follow these steps to migrate the existing runtime config:

1. Export the values currently stored in Runtime Config (still available during the deprecation period):
   ```bash
   firebase functions:config:get > /tmp/runtime-config.json
   cat /tmp/runtime-config.json
   ```
2. Copy the example env file and create a project-specific file (keep it **out of git**):
   ```bash
   cp functions/.env.example functions/.env.civiapp-38b51
   ```
3. Edit `functions/.env.civiapp-38b51` and copy the values from the exported JSON:
   - `stripe.secret` → `STRIPE_API_KEY`
   - `stripe.webhook` → `STRIPE_WEBHOOK_SECRET`
   - Keep or adjust the messaging feature toggles as needed.
4. (Optional) create `functions/.env.local` with test or emulator values.
5. Deploy as usual:
   ```bash
   npm --prefix functions run build
   firebase deploy --only functions
   ```

The Firebase CLI automatically loads `.env` files from the `functions/` folder
during emulation and deploys, so `process.env.*` is now populated without
`functions.config()`. Secrets should also be materialised in Google Cloud Secret
Manager with `firebase functions:secrets:set` for production workloads. The Stripe
Cloud Functions already fall back to secrets named `STRIPE_API_KEY` and
`STRIPE_WEBHOOK_SECRET` if present.
