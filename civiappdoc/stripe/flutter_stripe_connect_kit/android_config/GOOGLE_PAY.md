# Android – Google Pay setup
1) Enable Google Pay in Stripe Dashboard (Payments → Payment methods).
2) In PaymentSheet params set `googlePay: PaymentSheetGooglePay(merchantCountryCode: 'IT', testEnv: true)`.
3) Test on a real device with Google Pay available.
