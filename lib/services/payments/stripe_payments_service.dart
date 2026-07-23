import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

import '../../domain/cart/cart_models.dart';

const _stripeTestMode = bool.fromEnvironment(
  'STRIPE_TEST_MODE',
  defaultValue: true,
);
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
  defaultValue: 'You Book',
);
const _merchantCountryCodeDefine = String.fromEnvironment(
  'STRIPE_MERCHANT_COUNTRY_CODE',
  defaultValue: 'IT',
);
const _stripeReturnUrl = 'youbook://stripe-redirect';

String italianPaymentErrorMessage(Object error) {
  if (error is StripeException) {
    final details = error.error;
    if (details.code == FailureCode.Canceled) {
      return 'Pagamento annullato. Non è stato effettuato alcun addebito.';
    }
    if (details.code == FailureCode.Timeout) {
      return 'Il pagamento ha impiegato troppo tempo. Controlla la connessione e riprova.';
    }
    return _italianPaymentMessageFromRaw(
      [
        details.stripeErrorCode,
        details.declineCode,
        details.type,
        details.localizedMessage,
        details.message,
      ].whereType<String>().join(' '),
    );
  }

  if (error is StripePaymentsException) {
    if (error.code == 'canceled') {
      return 'Pagamento annullato. Non è stato effettuato alcun addebito.';
    }
    return _italianPaymentMessageFromRaw(error.message);
  }

  final rawMessage =
      error is StateError ? error.message.toString() : error.toString();
  return _italianPaymentMessageFromRaw(rawMessage);
}

String _italianPaymentMessageFromRaw(String rawMessage) {
  final normalized = rawMessage.trim().toLowerCase();

  if (_containsAny(normalized, const [
    'canceled',
    'cancelled',
    'annullato',
    'annullata',
  ])) {
    return 'Pagamento annullato. Non è stato effettuato alcun addebito.';
  }
  if (_containsAny(normalized, const [
    'insufficient_funds',
    'insufficient funds',
    'fondi insufficienti',
  ])) {
    return 'Fondi insufficienti. Usa un’altra carta o un altro metodo di pagamento.';
  }
  if (_containsAny(normalized, const [
    'expired_card',
    'card has expired',
    'carta scaduta',
  ])) {
    return 'La carta è scaduta. Usa una carta valida e riprova.';
  }
  if (_containsAny(normalized, const [
    'incorrect_cvc',
    'invalid_cvc',
    'security code is incorrect',
    'cvc',
    'codice di sicurezza',
  ])) {
    return 'Il codice di sicurezza della carta non è corretto. Controlla il CVC e riprova.';
  }
  if (_containsAny(normalized, const [
    'incorrect_number',
    'invalid_number',
    'card number is incorrect',
    'numero della carta',
  ])) {
    return 'Il numero della carta non è corretto. Controllalo e riprova.';
  }
  if (_containsAny(normalized, const [
    'invalid_expiry',
    'invalid_expiration',
    'expiry month',
    'expiry year',
  ])) {
    return 'La data di scadenza della carta non è valida. Controllala e riprova.';
  }
  if (_containsAny(normalized, const [
    'authentication_required',
    'authentication_failure',
    'payment_intent_authentication_failure',
    '3d secure',
    '3ds',
  ])) {
    return 'La banca non ha autorizzato il pagamento. Completa la verifica richiesta oppure usa un’altra carta.';
  }
  if (_containsAny(normalized, const [
    'card_declined',
    'generic_decline',
    'do_not_honor',
    'declined',
    'rifiutat',
  ])) {
    return 'La carta è stata rifiutata. Contatta la banca oppure usa un altro metodo di pagamento.';
  }
  if (_containsAny(normalized, const [
    'network',
    'socketexception',
    'failed host lookup',
    'connection',
    'timeout',
    'timed out',
  ])) {
    return 'Connessione assente o instabile. Controlla la rete e riprova il pagamento.';
  }
  if (_containsAny(normalized, const [
    'utente non autenticato',
    'token di autenticazione',
    'unauthenticated',
    'unauthorized',
    '401',
  ])) {
    return 'La sessione è scaduta. Accedi di nuovo e riprova il pagamento.';
  }
  if (_containsAny(normalized, const [
    'stripe non è configurato',
    'stripe non disponibile',
    'pagamento stripe non disponibile',
    'publishable_key',
    'not configured',
  ])) {
    return 'Il pagamento online non è disponibile in questo momento. Riprova più tardi o contatta il salone.';
  }
  if (_containsAny(normalized, const ['carrello è vuoto', 'carrello vuoto'])) {
    return 'Il carrello è vuoto. Aggiungi almeno un elemento prima di pagare.';
  }
  if (_containsAny(normalized, const [
    'totale del preventivo non è valido',
    'totale non è valido',
    'invalid amount',
  ])) {
    return 'L’importo da pagare non è valido. Contatta il salone prima di riprovare.';
  }
  if (_containsAny(normalized, const [
    'processing_error',
    'processing error',
  ])) {
    return 'Il pagamento non è stato completato. Attendi qualche istante e riprova.';
  }
  if (_containsAny(normalized, const [
    'backend',
    'server',
    'internal',
    'http',
    'stripe 4',
    'stripe 5',
    'risposta non valida',
    'endpoint',
  ])) {
    return 'Il servizio di pagamento è temporaneamente non disponibile. Riprova tra qualche minuto.';
  }

  return 'Pagamento non riuscito. Controlla i dati della carta oppure prova un altro metodo di pagamento.';
}

bool _containsAny(String value, List<String> patterns) {
  return patterns.any(value.contains);
}

class StripeCheckoutResult {
  const StripeCheckoutResult({
    required this.paymentIntentId,
    required this.clientSecret,
    this.connectedAccountId,
  });

  final String paymentIntentId;
  final String clientSecret;
  final String? connectedAccountId;
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
    if (kIsWeb) {
      throw StateError('Pagamento Stripe non disponibile su web.');
    }
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
    if (customerId != null &&
        customerId.isNotEmpty &&
        salonStripeAccountId == null) {
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
    if (customerId != null &&
        customerId.isNotEmpty &&
        salonStripeAccountId == null) {
      final keyResponse = await _postJson(
        path: 'createStripeEphemeralKey',
        body: <String, dynamic>{
          'customerId': customerId,
          'clientId': cart.clientId,
        },
        headers: const <String, String>{'Stripe-Version': '2024-06-20'},
      );
      ephemeralKeySecret = keyResponse['secret'] as String?;
    }

    await _initPaymentSheet(
      clientSecret: clientSecret,
      stripeAccountId: salonStripeAccountId,
      customerId: customerId,
      customerEphemeralKeySecret: ephemeralKeySecret,
    );

    await _presentPaymentSheet();

    return StripeCheckoutResult(
      paymentIntentId: paymentIntentId,
      clientSecret: clientSecret,
      connectedAccountId: salonStripeAccountId,
    );
  }

  Future<StripeCheckoutResult> checkoutQuote({
    required String quoteId,
    String? quoteNumber,
    String? quoteTitle,
    required double totalAmount,
    required String salonId,
    required String clientId,
    String currency = 'eur',
    String? salonStripeAccountId,
    String? customerId,
    String? clientName,
    String? salonName,
  }) async {
    if (kIsWeb) {
      throw StateError('Pagamento Stripe non disponibile su web.');
    }
    if (totalAmount <= 0) {
      throw StateError('Il totale del preventivo non è valido.');
    }
    if (!isConfigured) {
      throw StateError(
        'Stripe non è configurato. Assicurati di impostare STRIPE_PUBLISHABLE_KEY nei dart-define.',
      );
    }

    final amountCents = _toMinorUnits(totalAmount);
    final metadata = <String, String>{
      'quoteId': quoteId,
      'quoteTotal': totalAmount.toStringAsFixed(2),
      'quoteAmountCents': amountCents.toString(),
      'origin': 'quoteCheckout',
    };
    if (quoteNumber != null && quoteNumber.isNotEmpty) {
      metadata['quoteNumber'] = quoteNumber;
    }
    if (quoteTitle != null && quoteTitle.isNotEmpty) {
      metadata['quoteTitle'] = quoteTitle;
    }
    if (clientName != null && clientName.isNotEmpty) {
      metadata['clientName'] = clientName;
    }
    if (salonName != null && salonName.isNotEmpty) {
      metadata['salonName'] = salonName;
    }
    final descriptionSource =
        quoteTitle?.trim().isNotEmpty == true
            ? quoteTitle!.trim()
            : (quoteNumber != null && quoteNumber.isNotEmpty)
            ? 'Preventivo $quoteNumber'
            : 'Preventivo $quoteId';
    metadata['description'] = descriptionSource;

    final requestBody = <String, dynamic>{
      'amount': amountCents,
      'currency': currency.toLowerCase(),
      'salonId': salonId,
      'clientId': clientId,
      'type': 'quote',
      'metadata': metadata,
    };
    if (salonStripeAccountId != null && salonStripeAccountId.isNotEmpty) {
      requestBody['salonStripeAccountId'] = salonStripeAccountId;
    }
    if (customerId != null &&
        customerId.isNotEmpty &&
        salonStripeAccountId == null) {
      requestBody['customerId'] = customerId;
    }

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
    if (customerId != null &&
        customerId.isNotEmpty &&
        salonStripeAccountId == null) {
      final keyResponse = await _postJson(
        path: 'createStripeEphemeralKey',
        body: <String, dynamic>{'customerId': customerId, 'clientId': clientId},
        headers: const <String, String>{'Stripe-Version': '2024-06-20'},
      );
      ephemeralKeySecret = keyResponse['secret'] as String?;
    }

    await _initPaymentSheet(
      clientSecret: clientSecret,
      stripeAccountId: salonStripeAccountId,
      customerId: customerId,
      customerEphemeralKeySecret: ephemeralKeySecret,
    );

    await _presentPaymentSheet();

    return StripeCheckoutResult(
      paymentIntentId: paymentIntentId,
      clientSecret: clientSecret,
      connectedAccountId: salonStripeAccountId,
    );
  }

  Future<Map<String, dynamic>> _postJson({
    required String path,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final url = _resolveFunctionUrl(path);
    final authHeaders = await _buildAuthHeaders();
    final response = await _client.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json',
        ...authHeaders,
        if (headers != null) ...headers,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw StripePaymentsException.failed(
      message: italianPaymentErrorMessage(
        'Errore Stripe ${response.statusCode}: ${response.body}',
      ),
    );
  }

  Future<Map<String, String>> _buildAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Utente non autenticato. Effettua di nuovo il login.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Token di autenticazione non disponibile.');
    }
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  Future<void> _initPaymentSheet({
    required String clientSecret,
    String? stripeAccountId,
    String? customerId,
    String? customerEphemeralKeySecret,
  }) async {
    try {
      await _applyStripeAccount(stripeAccountId);
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: _merchantDisplayNameDefine,
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          customerEphemeralKeySecret: customerEphemeralKeySecret,
          returnURL: _stripeReturnUrl,
          applePay: PaymentSheetApplePay(
            merchantCountryCode: _merchantCountryCodeDefine,
          ),
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: _merchantCountryCodeDefine,
            testEnv: _stripeTestMode,
          ),
          style: ThemeMode.system,
          allowsDelayedPaymentMethods: true,
        ),
      );
    } on StripeException catch (error) {
      throw StripePaymentsException.failed(
        message: italianPaymentErrorMessage(error),
      );
    } catch (error) {
      throw StripePaymentsException.failed(
        message: italianPaymentErrorMessage(error),
      );
    }
  }

  Future<void> _applyStripeAccount(String? stripeAccountId) async {
    final normalized =
        stripeAccountId != null && stripeAccountId.trim().isNotEmpty
            ? stripeAccountId.trim()
            : null;
    if (Stripe.stripeAccountId == normalized) {
      return;
    }
    Stripe.stripeAccountId = normalized;
    await Stripe.instance.applySettings();
  }

  Future<void> _presentPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (error) {
      if (error.error.code == FailureCode.Canceled) {
        throw StripePaymentsException.canceled(
          message: italianPaymentErrorMessage(error),
        );
      }
      throw StripePaymentsException.failed(
        message: italianPaymentErrorMessage(error),
      );
    }
  }

  int _toMinorUnits(double amount) {
    final normalized = amount.toStringAsFixed(2);
    final isNegative = normalized.startsWith('-');
    final digits = normalized.replaceAll('-', '').replaceAll('.', '');
    final value = int.parse(digits);
    return isNegative ? -value : value;
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
