import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
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
    required this.graphApiVersion,
    required this.tokenExpiresAt,
    required this.connectedAt,
    required this.onboardingStatus,
    required this.lastPreviewSendStatus,
    required this.lastPreviewSendMessageId,
    required this.lastPreviewSendError,
    required this.lastPreviewSendAt,
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
  final String? graphApiVersion;
  final DateTime? tokenExpiresAt;
  final DateTime? connectedAt;
  final String? onboardingStatus;
  final String? lastPreviewSendStatus;
  final String? lastPreviewSendMessageId;
  final String? lastPreviewSendError;
  final DateTime? lastPreviewSendAt;
  final DateTime? updatedAt;

  bool get isConfigured =>
      phoneNumberId != null &&
      phoneNumberId!.isNotEmpty &&
      tokenSecretId != null;

  factory WhatsAppConfig.fromMap(
    Map<String, dynamic> map, {
    required String salonId,
  }) {
    DateTime? parseDate(Object? value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
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
      graphApiVersion: map['graphApiVersion'] as String?,
      tokenExpiresAt: parseDate(map['tokenExpiresAt']),
      connectedAt: parseDate(map['connectedAt']),
      onboardingStatus: map['onboardingStatus'] as String?,
      lastPreviewSendStatus: map['lastPreviewSendStatus'] as String?,
      lastPreviewSendMessageId: map['lastPreviewSendMessageId'] as String?,
      lastPreviewSendError: map['lastPreviewSendError'] as String?,
      lastPreviewSendAt: parseDate(map['lastPreviewSendAt']),
      updatedAt: parseDate(map['updatedAt']),
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
    String? graphApiVersion,
    DateTime? tokenExpiresAt,
    DateTime? connectedAt,
    String? onboardingStatus,
    String? lastPreviewSendStatus,
    String? lastPreviewSendMessageId,
    String? lastPreviewSendError,
    DateTime? lastPreviewSendAt,
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
      graphApiVersion: graphApiVersion ?? this.graphApiVersion,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      connectedAt: connectedAt ?? this.connectedAt,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      lastPreviewSendStatus:
          lastPreviewSendStatus ?? this.lastPreviewSendStatus,
      lastPreviewSendMessageId:
          lastPreviewSendMessageId ?? this.lastPreviewSendMessageId,
      lastPreviewSendError: lastPreviewSendError ?? this.lastPreviewSendError,
      lastPreviewSendAt: lastPreviewSendAt ?? this.lastPreviewSendAt,
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
      if (graphApiVersion != null) 'graphApiVersion': graphApiVersion,
      if (tokenExpiresAt != null)
        'tokenExpiresAt': Timestamp.fromDate(tokenExpiresAt!),
      if (connectedAt != null) 'connectedAt': Timestamp.fromDate(connectedAt!),
      if (onboardingStatus != null) 'onboardingStatus': onboardingStatus,
      if (lastPreviewSendStatus != null)
        'lastPreviewSendStatus': lastPreviewSendStatus,
      if (lastPreviewSendMessageId != null)
        'lastPreviewSendMessageId': lastPreviewSendMessageId,
      if (lastPreviewSendError != null)
        'lastPreviewSendError': lastPreviewSendError,
      if (lastPreviewSendAt != null)
        'lastPreviewSendAt': Timestamp.fromDate(lastPreviewSendAt!),
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

class MetaWhatsAppTemplate {
  const MetaWhatsAppTemplate({
    required this.name,
    this.id,
    this.language,
    this.status,
    this.category,
    this.components = const <Map<String, dynamic>>[],
    this.headerFormat,
    this.headerTextPreview,
    this.bodyPreview,
    this.rejectedReason,
  });

  final String name;
  final String? id;
  final String? language;
  final String? status;
  final String? category;
  final List<Map<String, dynamic>> components;
  final String? headerFormat;
  final String? headerTextPreview;
  final String? bodyPreview;
  final String? rejectedReason;

  bool get hasImageHeader =>
      (headerFormat ?? '').trim().toUpperCase() == 'IMAGE';

  bool get hasMediaHeader => const <String>{
    'IMAGE',
    'VIDEO',
    'DOCUMENT',
  }.contains((headerFormat ?? '').trim().toUpperCase());

  factory MetaWhatsAppTemplate.fromMap(Map<String, dynamic> map) {
    String? asTrimmedString(Object? value) {
      if (value is! String) {
        return null;
      }
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final components = <Map<String, dynamic>>[];
    final rawComponents = map['components'];
    if (rawComponents is List) {
      for (final item in rawComponents) {
        if (item is! Map) {
          continue;
        }
        components.add(Map<String, dynamic>.from(item));
      }
    }

    String? headerFormat;
    String? headerTextPreview;
    String? extractedBodyPreview;
    for (final component in components) {
      final type = asTrimmedString(component['type'])?.toUpperCase();
      if (type == 'HEADER') {
        headerFormat = asTrimmedString(component['format'])?.toUpperCase();
        headerTextPreview = asTrimmedString(component['text']);
      } else if (type == 'BODY') {
        extractedBodyPreview = asTrimmedString(component['text']);
      }
    }

    return MetaWhatsAppTemplate(
      name: asTrimmedString(map['name']) ?? 'template_senza_nome',
      id: asTrimmedString(map['id']),
      language: asTrimmedString(map['language']),
      status: asTrimmedString(map['status']),
      category: asTrimmedString(map['category']),
      components: List<Map<String, dynamic>>.unmodifiable(components),
      headerFormat: headerFormat,
      headerTextPreview: headerTextPreview,
      bodyPreview: asTrimmedString(map['bodyPreview']) ?? extractedBodyPreview,
      rejectedReason: asTrimmedString(map['rejectedReason']),
    );
  }
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

  Stream<WhatsAppConfig?> watchConfig(String salonId) async* {
    final doc = _firestore.collection('salons').doc(salonId);
    var permissionDeniedRetries = 0;

    while (true) {
      try {
        await _prepareFirestoreAuthSession();

        await for (final snapshot in doc.snapshots()) {
          permissionDeniedRetries = 0;
          final data = snapshot.data();
          if (data == null) {
            yield null;
            continue;
          }
          final whatsapp = data['whatsapp'];
          if (whatsapp is Map<String, dynamic>) {
            yield WhatsAppConfig.fromMap(whatsapp, salonId: salonId);
            continue;
          }
          yield null;
        }

        return;
      } on FirebaseException catch (error) {
        final isPermissionDenied = error.code == 'permission-denied';
        if (!isPermissionDenied || permissionDeniedRetries >= 2) {
          rethrow;
        }

        permissionDeniedRetries += 1;
        if (kDebugMode) {
          debugPrint(
            '[WhatsAppService] Firestore permission-denied transitorio su config WhatsApp, retry #$permissionDeniedRetries (salone: $salonId)',
          );
        }

        await _refreshFirebaseAuthTokenIfAvailable();
        await Future<void>.delayed(
          Duration(milliseconds: 350 * permissionDeniedRetries),
        );
      }
    }
  }

  Future<void> disconnect(String salonId) async {
    final doc = _firestore.collection('salons').doc(salonId);
    await doc.update({
      'whatsapp.mode': 'disconnected',
      'whatsapp.phoneNumberId': FieldValue.delete(),
      'whatsapp.displayPhoneNumber': FieldValue.delete(),
      'whatsapp.tokenSecretId': FieldValue.delete(),
      'whatsapp.verifyTokenSecretId': FieldValue.delete(),
      'whatsapp.graphApiVersion': FieldValue.delete(),
      'whatsapp.tokenExpiresAt': FieldValue.delete(),
      'whatsapp.connectedAt': FieldValue.delete(),
      'whatsapp.onboardingStatus': FieldValue.delete(),
      'whatsapp.lastOnboardingErrorMessage': FieldValue.delete(),
      'whatsapp.lastOnboardingErrorAt': FieldValue.delete(),
      'whatsapp.lastPreviewSendStatus': FieldValue.delete(),
      'whatsapp.lastPreviewSendAt': FieldValue.delete(),
      'whatsapp.lastPreviewSendMessageId': FieldValue.delete(),
      'whatsapp.lastPreviewSendError': FieldValue.delete(),
      'whatsapp.lastPreviewSendByUserId': FieldValue.delete(),
      'whatsapp.lastPreviewSendByEmail': FieldValue.delete(),
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

    final response = await _authorizedPostJson(endpoint, payload);

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

    final response = await _authorizedGet(uri, forceRefreshFirst: true);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final authUrl = decoded['authUrl'] as String?;
      if (authUrl == null) {
        throw WhatsAppSendException('Risposta OAuth senza authUrl');
      }
      return Uri.parse(authUrl);
    }

    final decodedBody =
        response.body.isEmpty
            ? const <String, dynamic>{}
            : jsonDecode(response.body);
    final body =
        decodedBody is Map<String, dynamic> ? decodedBody : <String, dynamic>{};

    throw WhatsAppSendException(
      'Impossibile generare URL OAuth (${response.statusCode}): '
      '${body['error'] ?? response.body}',
    );
  }

  Future<void> openOAuthFlow(String salonId) async {
    final url = await buildOAuthStartUrl(salonId);
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw WhatsAppSendException('Impossibile aprire il browser');
    }
  }

  Future<List<MetaWhatsAppTemplate>> listMetaTemplates({
    required String salonId,
    int limit = 100,
  }) async {
    final functionUri = _resolveFunctionUrl('listWhatsappTemplates');
    final uri = functionUri.replace(
      queryParameters: {'salonId': salonId, 'limit': '$limit'},
    );
    final response = await _authorizedGet(uri);

    final decodedBody =
        response.body.isEmpty
            ? const <String, dynamic>{}
            : jsonDecode(response.body);
    final body =
        decodedBody is Map<String, dynamic> ? decodedBody : <String, dynamic>{};

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhatsAppSendException(
        'Impossibile leggere i template Meta (${response.statusCode}): '
        '${body['error'] ?? response.body}',
      );
    }

    final rawTemplates = body['templates'];
    if (rawTemplates is! List) {
      return const <MetaWhatsAppTemplate>[];
    }

    return rawTemplates
        .whereType<Map>()
        .map(
          (item) =>
              MetaWhatsAppTemplate.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<http.Response> _authorizedGet(
    Uri uri, {
    bool forceRefreshFirst = false,
  }) async {
    var idToken = await _requireFirebaseIdToken(
      forceRefresh: forceRefreshFirst,
    );
    var response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      if (kDebugMode) {
        debugPrint(
          '[WhatsAppService] auth ${response.statusCode}, retry con token refresh per $uri',
        );
      }
      idToken = await _requireFirebaseIdToken(forceRefresh: true);
      response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $idToken'},
      );
    }

    return response;
  }

  Future<http.Response> _authorizedPostJson(
    Uri uri,
    Map<String, dynamic> body, {
    bool forceRefreshFirst = false,
  }) async {
    var idToken = await _requireFirebaseIdToken(
      forceRefresh: forceRefreshFirst,
    );
    var response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      if (kDebugMode) {
        debugPrint(
          '[WhatsAppService] auth ${response.statusCode}, retry POST con token refresh per $uri',
        );
      }
      idToken = await _requireFirebaseIdToken(forceRefresh: true);
      response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(body),
      );
    }

    return response;
  }

  Future<String> _requireFirebaseIdToken({bool forceRefresh = false}) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw WhatsAppSendException(
        'Devi essere autenticato per usare WhatsApp Business.',
      );
    }
    final idToken = await user.getIdToken(forceRefresh);
    if (idToken == null || idToken.isEmpty) {
      throw WhatsAppSendException(
        'Impossibile ottenere il token di autenticazione.',
      );
    }
    return idToken;
  }

  Future<void> _prepareFirestoreAuthSession() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _refreshFirebaseAuthTokenIfAvailable(forceRefresh: true);
      return;
    }

    try {
      final signedInUser = await firebase_auth.FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((candidate) => candidate != null)
          .timeout(const Duration(seconds: 2));
      if (signedInUser != null) {
        await _refreshFirebaseAuthTokenIfAvailable(forceRefresh: true);
      }
    } on TimeoutException {
      // Se l'auth non e ancora pronta, lasciamo che Firestore ritenti/errore.
    }
  }

  Future<void> _refreshFirebaseAuthTokenIfAvailable({
    bool forceRefresh = true,
  }) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      await user.getIdToken(forceRefresh);
    } catch (_) {
      // Best-effort: la lettura Firestore gestisce gia i retry/errori.
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
