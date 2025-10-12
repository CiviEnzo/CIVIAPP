# Codex Commands (VS Code)

## Prerequisites
- Node 18+, npm
- Flutter 3.24+
- Xcode / Android SDK
- Stripe account (Test mode) with Connect (Express) enabled

## 1) Install backend deps
mkdir -p backend/functions lib/lib_payments android_config ios_config docs
cd backend
npm init -y
npm i express cors stripe firebase-admin dotenv
cd ..

## 2) Copy .env example
cp backend/.env.example backend/.env

## 3) Run backend
cd backend && node server.js

## 4) Run Flutter app
flutter pub get
flutter run

## 5) Stripe CLI (optional)
stripe login
stripe listen --events payment_intent.succeeded,payment_intent.payment_failed,charge.refunded --forward-to http://localhost:8080/stripe/webhook
