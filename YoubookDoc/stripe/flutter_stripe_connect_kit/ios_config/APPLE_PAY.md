# iOS – Apple Pay setup
1) Apple Developer → create Merchant ID (e.g., merchant.com.civiapp).
2) Xcode → Capabilities → Apple Pay → add Merchant ID.
3) Stripe Dashboard → Settings → Payments → Apple Pay: follow verification steps.
4) In Flutter set: `Stripe.merchantIdentifier = 'merchant.com.civiapp'`.
