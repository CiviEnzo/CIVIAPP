# Codex Commands (VS Code)

## Prerequisites
- Node 18+ and npm
- Firebase Tools (`npm i -g firebase-tools`) if using Firebase Functions
- Stripe CLI (`brew install stripe/stripe-cli/stripe` on macOS)

## 1) Create folders & install deps
mkdir -p functions/webhook firestore admin_panel backend monitoring flutter examples
cd functions/webhook
npm init -y
npm i express stripe firebase-admin dotenv
cd ../../

## 2) Create env file (copy from example)
cp functions/webhook/.env.example functions/webhook/.env

## 3) Run locally
cd functions/webhook
node index.js

## 4) Stripe CLI to forward webhooks
stripe login
stripe listen --events checkout.session.completed,payment_intent.succeeded,charge.refunded --forward-to http://localhost:8080/stripe/webhook

## 5) Firebase deploy (optional)
# Initialize once: firebase init functions (Node 18), then adapt.
# Or deploy the standalone Express app to Cloud Run.
# If you keep it as Functions:
firebase deploy --only functions:webhook

## 6) Firestore seed (optional)
# Import the example CSV in your admin page or write a small script.
