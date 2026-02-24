# Flutter – PaymentSheet (flutter_stripe)

## pubspec.yaml
```yaml
dependencies:
  flutter_stripe: ^10.0.0
  http: ^1.2.2
```

## main.dart init
```dart
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Stripe.publishableKey = 'pk_test_********************************';
  Stripe.merchantIdentifier = 'merchant.com.civiapp'; // iOS
  await Stripe.instance.applySettings();
  runApp(const MyApp());
}
```

## Service to call backend & present sheet
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';

class PaymentsService {
  final String baseUrl;
  PaymentsService(this.baseUrl);

  Future<Map<String, dynamic>> createIntent({
    required int amountCents,
    required String salonStripeAccountId,
    String currency = 'eur',
    String? customerId,
    Map<String, String>? metadata,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/payments/create-intent'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'amount': amountCents,
        'currency': currency,
        'salonStripeAccountId': salonStripeAccountId,
        'customerId': customerId,
        'metadata': metadata ?? {},
      }),
    );
    if (res.statusCode != 200) throw Exception(res.body);
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<void> pay({
    required int amountCents,
    required String salonStripeAccountId,
    required String clientId,
    required String salonId,
    String? customerId,
  }) async {
    final resp = await createIntent(
      amountCents: amountCents,
      salonStripeAccountId: salonStripeAccountId,
      customerId: customerId,
      metadata: {'clientId': clientId, 'salonId': salonId},
    );
    final clientSecret = resp['clientSecret'];

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'CIVIAPP',
        paymentIntentClientSecret: clientSecret,
        applePay: const PaymentSheetApplePay(merchantCountryCode: 'IT'),
        googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'IT', testEnv: true),
        allowsDelayedPaymentMethods: true, // Klarna eligible
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  }
}
```
