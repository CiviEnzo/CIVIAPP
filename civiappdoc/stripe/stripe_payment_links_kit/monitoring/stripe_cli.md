# Stripe CLI – Local testing

## Install
- macOS: `brew install stripe/stripe-cli/stripe`

## Login
stripe login

## Listen and forward events
stripe listen --events checkout.session.completed,payment_intent.succeeded,charge.refunded --forward-to http://localhost:8080/stripe/webhook

## Trigger test events
# Replace with your test Payment Link; complete a test payment using 4242 4242 4242 4242
# You can also use: stripe trigger payment_intent.succeeded
stripe trigger checkout.session.completed
