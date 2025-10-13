import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _functionsBaseOverride = String.fromEnvironment(
  'STRIPE_FUNCTIONS_BASE',
  defaultValue: '',
);
const _functionsRegionOverride = String.fromEnvironment(
  'STRIPE_FUNCTIONS_REGION',
  defaultValue: 'europe-west3',
);

@immutable
class StripeConnectAccount {
  const StripeConnectAccount({
    required this.accountId,
    required this.chargesEnabled,
    required this.payoutsEnabled,
    required this.detailsSubmitted,
  });

  final String accountId;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;

  factory StripeConnectAccount.fromJson(Map<String, dynamic> json) {
    return StripeConnectAccount(
      accountId: json['accountId'] as String? ?? '',
      chargesEnabled: json['chargesEnabled'] as bool? ?? false,
      payoutsEnabled: json['payoutsEnabled'] as bool? ?? false,
      detailsSubmitted: json['detailsSubmitted'] as bool? ?? false,
    );
  }
}

class StripeConnectService {
  StripeConnectService({http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final http.Client _client;

  Future<StripeConnectAccount> createAccount({
    required String email,
    required String salonId,
    String country = 'IT',
    String businessType = 'individual',
  }) async {
    final payload = {
      'email': email,
      'salonId': salonId,
      'country': country,
      'businessType': businessType,
    };
    final response = await _post(
      path: 'createStripeConnectAccount',
      body: payload,
    );
    return StripeConnectAccount.fromJson(response);
  }

  Future<Uri> createOnboardingLink({
    required String salonId,
    String? accountId,
    required String returnUrl,
    required String refreshUrl,
  }) async {
    final payload = {
      'salonId': salonId,
      if (accountId != null) 'accountId': accountId,
      'returnUrl': returnUrl,
      'refreshUrl': refreshUrl,
    };
    final response = await _post(
      path: 'createStripeOnboardingLink',
      body: payload,
    );
    final url = response['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Risposta onboarding non valida: manca l\'URL');
    }
    return Uri.parse(url);
  }

  Future<Map<String, dynamic>> _post({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final uri = _resolveFunctionUrl(path);
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Errore Stripe Connect (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Risposta inattesa dal backend Stripe');
  }

  Uri _resolveFunctionUrl(String functionName) {
    final override = _functionsBaseOverride.trim();
    if (override.isNotEmpty) {
      final parsed = Uri.tryParse(override);
      if (parsed != null) {
        final segments = <String>[
          ...parsed.pathSegments.where((segment) => segment.isNotEmpty),
          functionName,
        ];
        return parsed.replace(pathSegments: segments);
      }
    }
    try {
      final projectId =
          Firebase.apps.isNotEmpty ? Firebase.app().options.projectId : null;
      if (projectId != null && projectId.isNotEmpty) {
        final base =
            'https://$_functionsRegionOverride-$projectId.cloudfunctions.net/$functionName';
        final uri = Uri.tryParse(base);
        if (uri != null) {
          return uri;
        }
      }
    } catch (_) {
      // Firebase non inizializzato, si cade nell'errore generico sotto.
    }
    throw StateError(
      'Impossibile determinare l\'endpoint per $functionName. '
      'Configura STRIPE_FUNCTIONS_BASE oppure FIREBASE_PROJECT_ID.',
    );
  }
}
