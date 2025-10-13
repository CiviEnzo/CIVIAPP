import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

import '../../domain/cart/cart_models.dart';

const _functionsBaseOverride = String.fromEnvironment(
  'STRIPE_FUNCTIONS_BASE',
  defaultValue: '',
);
const _functionsRegionOverride = String.fromEnvironment(
  'STRIPE_FUNCTIONS_REGION',
  defaultValue: 'europe-west3',
);
const _merchantDisplayNameDefine = String.fromEnvironment(
  'STRIPE_MERCHANT_NAME',
  defaultValue: 'CIVIAPP',
);
const _merchantCountryCodeDefine = String.fromEnvironment(
  'STRIPE_MERCHANT_COUNTRY_CODE',
  defaultValue: 'IT',
);

class StripeCheckoutResult {
  const StripeCheckoutResult({
    required this.paymentIntentId,
    required this.clientSecret,
  });

  final String paymentIntentId;
  final String clientSecret;
}

class StripePaymentsService {
  StripePaymentsService({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final http.Client _client;

  bool get isConfigured => Stripe.publishableKey.isNotEmpty;

  Future<StripeCheckoutResult> checkoutCart({
    required CartSnapshot cart,
    String? salonStripeAccountId,
    String? customerId,
    Map<String, dynamic>? metadataOverrides,
  }) async {
    if (cart.isEmpty) {
      throw StateError('Il carrello è vuoto.');
    }

    final requestBody = <String, dynamic>{
      'amount': cart.totalAmountCents,
      'currency': cart.currency.toLowerCase(),
      'salonId': cart.salonId,
      'clientId': cart.clientId,
      'cartId': cart.id,
    };

    if (salonStripeAccountId != null) {
      requestBody['salonStripeAccountId'] = salonStripeAccountId;
    }
    if (customerId != null && customerId.isNotEmpty) {
      requestBody['customerId'] = customerId;
    }

    final metadata = cart.toStripeMetadata();
    if (metadataOverrides != null && metadataOverrides.isNotEmpty) {
      for (final entry in metadataOverrides.entries) {
        if (entry.value == null) continue;
        metadata[entry.key] = entry.value.toString();
      }
    }
    requestBody['metadata'] = metadata;

    final intentResponse = await _postJson(
      path: 'createStripePaymentIntent',
      body: requestBody,
    );

    final clientSecret = intentResponse['clientSecret'] as String?;
    final paymentIntentId = intentResponse['paymentIntentId'] as String?;

    if (clientSecret == null || paymentIntentId == null) {
      throw StateError('Risposta non valida dal backend Stripe.');
    }

    String? ephemeralKeySecret;
    if (customerId != null && customerId.isNotEmpty) {
      final keyResponse = await _postJson(
        path: 'createStripeEphemeralKey',
        body: <String, dynamic>{'customerId': customerId},
        headers: const <String, String>{'Stripe-Version': '2024-06-20'},
      );
      ephemeralKeySecret = keyResponse['secret'] as String?;
    }

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: _merchantDisplayNameDefine,
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKeySecret,
          applePay: PaymentSheetApplePay(
            merchantCountryCode: _merchantCountryCodeDefine,
          ),
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: _merchantCountryCodeDefine,
            testEnv: kDebugMode,
          ),
          style: ThemeMode.system,
          allowsDelayedPaymentMethods: true,
        ),
      );
    } on StripeException catch (error) {
      throw StripePaymentsException.failed(
        message: error.error.message ?? 'Configurazione pagamento non riuscita',
      );
    } catch (error) {
      throw StripePaymentsException.failed(
        message: 'Configurazione pagamento non riuscita: $error',
      );
    }

    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (error) {
      if (error.error.code == FailureCode.Canceled) {
        throw StripePaymentsException.canceled(
          message: error.error.message ?? 'Pagamento annullato',
        );
      }
      throw StripePaymentsException.failed(
        message: error.error.message ?? 'Pagamento non riuscito',
      );
    }

    return StripeCheckoutResult(
      paymentIntentId: paymentIntentId,
      clientSecret: clientSecret,
    );
  }

  Future<Map<String, dynamic>> _postJson({
    required String path,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final url = _resolveFunctionUrl(path);
    final response = await _client.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (headers != null) ...headers,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw StripePaymentsException.failed(
      message: 'Errore Stripe ${response.statusCode}: ${response.body}',
    );
  }

  Uri _resolveFunctionUrl(String functionName) {
    final override = _functionsBaseOverride.trim();
    if (override.isNotEmpty) {
      final uri = Uri.tryParse(override);
      if (uri != null) {
        final segments = <String>[
          ...uri.pathSegments.where((segment) => segment.isNotEmpty),
          functionName,
        ];
        return uri.replace(pathSegments: segments);
      }
    }

    try {
      final app = Firebase.app();
      final projectId = app.options.projectId;
      if (projectId.isNotEmpty) {
        final base =
            'https://$_functionsRegionOverride-$projectId.cloudfunctions.net/$functionName';
        final resolved = Uri.tryParse(base);
        if (resolved != null) {
          return resolved;
        }
      }
    } catch (_) {
      // Firebase not ready; will fall back to throw.
    }

    throw StateError(
      'Impossibile costruire l\'endpoint Stripe. '
      'Configura STRIPE_FUNCTIONS_BASE oppure verifica l\'inizializzazione di Firebase.',
    );
  }
}

class StripePaymentsException implements Exception {
  const StripePaymentsException._(this.code, this.message);

  factory StripePaymentsException.canceled({required String message}) {
    return StripePaymentsException._('canceled', message);
  }

  factory StripePaymentsException.failed({required String message}) {
    return StripePaymentsException._('failed', message);
  }

  final String code;
  final String message;

  @override
  String toString() => 'StripePaymentsException($code, $message)';
}
