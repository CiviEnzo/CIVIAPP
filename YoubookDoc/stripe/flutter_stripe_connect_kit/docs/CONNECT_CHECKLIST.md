# Connect (Express) – What you configure
- Enable Connect → Express in your Stripe Dashboard.
- Backend endpoints:
  - POST /connect/create-account
  - POST /connect/account-link
- Save `acct_***` in `salons/{salonId}.stripe_account_id`.
- Create PaymentIntent with `on_behalf_of` + `transfer_data.destination`.
- Optional `application_fee_amount` for platform fee.
- Webhook at `/stripe/webhook` with secret `whsec_...`.
