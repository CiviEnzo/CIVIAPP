import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _sendEndpointDefine = String.fromEnvironment(
  'SEND_ENDPOINT',
  defaultValue: '',
);
const _functionsRegionDefine = String.fromEnvironment(
  'WA_REGION',
  defaultValue: 'europe-west1',
);

class WhatsAppConfig {
  const WhatsAppConfig({
    required this.salonId,
    required this.mode,
    required this.businessId,
    required this.wabaId,
    required this.phoneNumberId,
    required this.displayPhoneNumber,
    required this.tokenSecretId,
    required this.verifyTokenSecretId,
    required this.updatedAt,
  });

  final String salonId;
  final String mode;
  final String? businessId;
  final String? wabaId;
  final String? phoneNumberId;
  final String? displayPhoneNumber;
  final String? tokenSecretId;
  final String? verifyTokenSecretId;
  final DateTime? updatedAt;

  bool get isConfigured =>
      phoneNumberId != null &&
      phoneNumberId!.isNotEmpty &&
      tokenSecretId != null;

  factory WhatsAppConfig.fromMap(
    Map<String, dynamic> map, {
    required String salonId,
  }) {
    final updatedAtRaw = map['updatedAt'];
    DateTime? updatedAt;
    if (updatedAtRaw is Timestamp) {
      updatedAt = updatedAtRaw.toDate();
    } else if (updatedAtRaw is DateTime) {
      updatedAt = updatedAtRaw;
    } else if (updatedAtRaw is String) {
      updatedAt = DateTime.tryParse(updatedAtRaw);
    }

    return WhatsAppConfig(
      salonId: salonId,
      mode: (map['mode'] as String?) ?? 'pending',
      businessId: map['businessId'] as String?,
      wabaId: map['wabaId'] as String?,
      phoneNumberId: map['phoneNumberId'] as String?,
      displayPhoneNumber: map['displayPhoneNumber'] as String?,
      tokenSecretId: map['tokenSecretId'] as String?,
      verifyTokenSecretId: map['verifyTokenSecretId'] as String?,
      updatedAt: updatedAt,
    );
  }

  WhatsAppConfig copyWith({
    String? mode,
    String? businessId,
    String? wabaId,
    String? phoneNumberId,
    String? displayPhoneNumber,
    String? tokenSecretId,
    String? verifyTokenSecretId,
    DateTime? updatedAt,
  }) {
    return WhatsAppConfig(
      salonId: salonId,
      mode: mode ?? this.mode,
      businessId: businessId ?? this.businessId,
      wabaId: wabaId ?? this.wabaId,
      phoneNumberId: phoneNumberId ?? this.phoneNumberId,
      displayPhoneNumber: displayPhoneNumber ?? this.displayPhoneNumber,
      tokenSecretId: tokenSecretId ?? this.tokenSecretId,
      verifyTokenSecretId: verifyTokenSecretId ?? this.verifyTokenSecretId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode,
      if (businessId != null) 'businessId': businessId,
      if (wabaId != null) 'wabaId': wabaId,
      if (phoneNumberId != null) 'phoneNumberId': phoneNumberId,
      if (displayPhoneNumber != null) 'displayPhoneNumber': displayPhoneNumber,
      if (tokenSecretId != null) 'tokenSecretId': tokenSecretId,
      if (verifyTokenSecretId != null)
        'verifyTokenSecretId': verifyTokenSecretId,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}

class WhatsAppSendResult {
  const WhatsAppSendResult({required this.success, this.messageId, this.raw});

  final bool success;
  final String? messageId;
  final Map<String, dynamic>? raw;
}

class WhatsAppService {
  WhatsAppService({
    http.Client? httpClient,
    FirebaseFirestore? firestore,
    Uri? sendEndpoint,
  }) : _client = httpClient ?? http.Client(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _sendEndpoint = sendEndpoint ?? _tryResolveEndpoint();

  final http.Client _client;
  final FirebaseFirestore _firestore;
  final Uri? _sendEndpoint;

  Uri? get sendEndpoint => _sendEndpoint;

  static Uri? _tryResolveEndpoint() {
    if (_sendEndpointDefine.isNotEmpty) {
      return Uri.tryParse(_sendEndpointDefine);
    }

    // Build default Cloud Functions URL using Firebase project/region.
    try {
      final app = Firebase.app();
      final projectId = app.options.projectId;
      if (projectId.isNotEmpty) {
        final url =
            'https://$_functionsRegionDefine-$projectId.cloudfunctions.net/sendWhatsappTemplate';
        return Uri.tryParse(url);
      }
    } catch (_) {
      // Firebase might not be initialized yet; ignore and return null.
    }

    return null;
  }

  Uri _resolveFunctionUrl(String functionName) {
    final endpoint = _sendEndpoint;
    if (endpoint != null) {
      final segments = List<String>.from(endpoint.pathSegments);
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
      segments.add(functionName);
      return endpoint.replace(pathSegments: segments);
    }

    final fallback = _computeDefaultFunctionUrl(functionName);
    if (fallback != null) {
      return fallback;
    }

    throw StateError(
      'Impossibile costruire l\'URL per la funzione $functionName. '
      'Configura SEND_ENDPOINT con --dart-define oppure specifica projectId manualmente.',
    );
  }

  Uri _resolveSendUrl() {
    final endpoint =
        _sendEndpoint ?? _computeDefaultFunctionUrl('sendWhatsappTemplate');
    if (endpoint == null) {
      throw StateError(
        'SEND_ENDPOINT non configurato. Passa un endpoint al costruttore o usa --dart-define=SEND_ENDPOINT=...',
      );
    }
    return endpoint;
  }

  Uri? _computeDefaultFunctionUrl(String functionName) {
    try {
      final app = Firebase.app();
      final projectId = app.options.projectId;
      if (projectId.isEmpty) {
        return null;
      }
      final url =
          'https://$_functionsRegionDefine-$projectId.cloudfunctions.net/$functionName';
      return Uri.tryParse(url);
    } catch (_) {
      return null;
    }
  }

  Stream<WhatsAppConfig?> watchConfig(String salonId) {
    final doc = _firestore.collection('salons').doc(salonId);
    return doc.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return null;
      }
      final whatsapp = data['whatsapp'];
      if (whatsapp is Map<String, dynamic>) {
        return WhatsAppConfig.fromMap(whatsapp, salonId: salonId);
      }
      return null;
    });
  }

  Future<void> disconnect(String salonId) async {
    final doc = _firestore.collection('salons').doc(salonId);
    await doc.update({
      'whatsapp.mode': 'disconnected',
      'whatsapp.phoneNumberId': FieldValue.delete(),
      'whatsapp.displayPhoneNumber': FieldValue.delete(),
      'whatsapp.tokenSecretId': FieldValue.delete(),
      'whatsapp.verifyTokenSecretId': FieldValue.delete(),
      'whatsapp.updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<WhatsAppSendResult> sendTemplate({
    required String salonId,
    required String to,
    required String templateName,
    String lang = 'it',
    List<Map<String, dynamic>> components = const [],
    bool? allowPreviewUrl,
  }) async {
    final endpoint = _resolveSendUrl();
    final payload = <String, dynamic>{
      'salonId': salonId,
      'to': to,
      'templateName': templateName,
      'lang': lang,
      if (components.isNotEmpty) 'components': components,
      if (allowPreviewUrl != null) 'allowPreviewUrl': allowPreviewUrl,
    };

    if (kDebugMode) {
      debugPrint(
        '[WhatsAppService] invio template $templateName a $to (salone: $salonId)',
      );
    }

    final response = await _client.post(
      endpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final decodedBody =
        response.body.isEmpty
            ? const <String, dynamic>{}
            : jsonDecode(response.body);
    final body =
        decodedBody is Map<String, dynamic> ? decodedBody : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (kDebugMode) {
        debugPrint('[WhatsAppService] risposta sendTemplate: $body');
      }
      return WhatsAppSendResult(
        success: body['success'] == true,
        messageId: body['messageId'] as String?,
        raw: body,
      );
    }

    throw WhatsAppSendException(
      'Errore ${response.statusCode}: ${body['error'] ?? response.body}',
    );
  }

  Future<Uri> buildOAuthStartUrl(String salonId, {Uri? redirectUri}) async {
    final functionUri = _resolveFunctionUrl('startWhatsappOAuth');
    final uri = functionUri.replace(
      queryParameters: {
        'salonId': salonId,
        if (redirectUri != null) 'redirectUri': redirectUri.toString(),
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final authUrl = decoded['authUrl'] as String?;
      if (authUrl == null) {
        throw WhatsAppSendException('Risposta OAuth senza authUrl');
      }
      return Uri.parse(authUrl);
    }

    throw WhatsAppSendException(
      'Impossibile generare URL OAuth (${response.statusCode})',
    );
  }

  Future<void> openOAuthFlow(String salonId) async {
    final url = await buildOAuthStartUrl(salonId);
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw WhatsAppSendException('Impossibile aprire il browser');
    }
  }

  void dispose() {
    _client.close();
  }
}

class WhatsAppSendException implements Exception {
  WhatsAppSendException(this.message);

  final String message;

  @override
  String toString() => 'WhatsAppSendException: $message';
}
