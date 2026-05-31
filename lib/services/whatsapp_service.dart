import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'whatsapp_embedded_signup_launcher.dart';
import 'whatsapp_embedded_signup_models.dart';
import 'whatsapp_embedded_signup_launcher_stub.dart'
    if (dart.library.html) 'whatsapp_embedded_signup_launcher_web.dart'
    as embedded_signup_launcher;

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
    required this.registrationStatus,
    required this.connectionMethod,
    required this.requiresReconnect,
    required this.registeredAt,
    required this.lastRegistrationErrorMessage,
    required this.lastRegistrationErrorAt,
    required this.lastCodeMethod,
    required this.lastCodeRequestedAt,
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
  final String? registrationStatus;
  final String? connectionMethod;
  final bool requiresReconnect;
  final DateTime? registeredAt;
  final String? lastRegistrationErrorMessage;
  final DateTime? lastRegistrationErrorAt;
  final String? lastCodeMethod;
  final DateTime? lastCodeRequestedAt;
  final String? lastPreviewSendStatus;
  final String? lastPreviewSendMessageId;
  final String? lastPreviewSendError;
  final DateTime? lastPreviewSendAt;
  final DateTime? updatedAt;

  bool get needsReconnect =>
      requiresReconnect || (connectionMethod ?? '').trim() == 'legacy_oauth';

  bool get needsVerification =>
      (onboardingStatus ?? '').trim() == 'awaiting_verification' ||
      (registrationStatus ?? '').trim() == 'verification_required';

  bool get isConfigured =>
      phoneNumberId != null &&
      phoneNumberId!.isNotEmpty &&
      !needsReconnect &&
      (registrationStatus ?? '').trim() == 'registered' &&
      (onboardingStatus ?? '').trim() == 'ready';

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

    String inferConnectionMethod() {
      final configured = (map['connectionMethod'] as String?)?.trim();
      if (configured == 'embedded_signup' ||
          configured == 'legacy_oauth' ||
          configured == 'manual_setup' ||
          configured == 'standard_oauth') {
        return configured!;
      }
      final legacyTokenSecret = (map['tokenSecretId'] as String?)?.trim();
      if (legacyTokenSecret != null && legacyTokenSecret.isNotEmpty) {
        return 'legacy_oauth';
      }
      return 'embedded_signup';
    }

    bool inferRequiresReconnect(String connectionMethod) {
      return map['requiresReconnect'] == true ||
          connectionMethod == 'legacy_oauth';
    }

    String? inferOnboardingStatus(bool requiresReconnect) {
      final configured = (map['onboardingStatus'] as String?)?.trim();
      if (configured != null && configured.isNotEmpty) {
        return configured;
      }
      if (requiresReconnect) {
        return 'reconnect_required';
      }
      final phoneNumberId = (map['phoneNumberId'] as String?)?.trim();
      if (phoneNumberId != null && phoneNumberId.isNotEmpty) {
        return 'ready';
      }
      return 'disconnected';
    }

    String? inferRegistrationStatus({
      required bool requiresReconnect,
      required String? onboardingStatus,
    }) {
      final configured = (map['registrationStatus'] as String?)?.trim();
      if (configured != null && configured.isNotEmpty) {
        return configured;
      }
      if (requiresReconnect) {
        return 'error';
      }
      if (onboardingStatus == 'awaiting_verification') {
        return 'verification_required';
      }
      final phoneNumberId = (map['phoneNumberId'] as String?)?.trim();
      if (onboardingStatus == 'ready' &&
          phoneNumberId != null &&
          phoneNumberId.isNotEmpty) {
        return 'registered';
      }
      return 'pending';
    }

    final connectionMethod = inferConnectionMethod();
    final requiresReconnect = inferRequiresReconnect(connectionMethod);
    final onboardingStatus = inferOnboardingStatus(requiresReconnect);
    final registrationStatus = inferRegistrationStatus(
      requiresReconnect: requiresReconnect,
      onboardingStatus: onboardingStatus,
    );

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
      onboardingStatus: onboardingStatus,
      registrationStatus: registrationStatus,
      connectionMethod: connectionMethod,
      requiresReconnect: requiresReconnect,
      registeredAt: parseDate(map['registeredAt']),
      lastRegistrationErrorMessage:
          map['lastRegistrationErrorMessage'] as String?,
      lastRegistrationErrorAt: parseDate(map['lastRegistrationErrorAt']),
      lastCodeMethod: map['lastCodeMethod'] as String?,
      lastCodeRequestedAt: parseDate(map['lastCodeRequestedAt']),
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
    String? registrationStatus,
    String? connectionMethod,
    bool? requiresReconnect,
    DateTime? registeredAt,
    String? lastRegistrationErrorMessage,
    DateTime? lastRegistrationErrorAt,
    String? lastCodeMethod,
    DateTime? lastCodeRequestedAt,
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
      registrationStatus: registrationStatus ?? this.registrationStatus,
      connectionMethod: connectionMethod ?? this.connectionMethod,
      requiresReconnect: requiresReconnect ?? this.requiresReconnect,
      registeredAt: registeredAt ?? this.registeredAt,
      lastRegistrationErrorMessage:
          lastRegistrationErrorMessage ?? this.lastRegistrationErrorMessage,
      lastRegistrationErrorAt:
          lastRegistrationErrorAt ?? this.lastRegistrationErrorAt,
      lastCodeMethod: lastCodeMethod ?? this.lastCodeMethod,
      lastCodeRequestedAt: lastCodeRequestedAt ?? this.lastCodeRequestedAt,
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
      if (registrationStatus != null) 'registrationStatus': registrationStatus,
      if (connectionMethod != null) 'connectionMethod': connectionMethod,
      'requiresReconnect': requiresReconnect,
      if (registeredAt != null)
        'registeredAt': Timestamp.fromDate(registeredAt!),
      if (lastRegistrationErrorMessage != null)
        'lastRegistrationErrorMessage': lastRegistrationErrorMessage,
      if (lastRegistrationErrorAt != null)
        'lastRegistrationErrorAt': Timestamp.fromDate(lastRegistrationErrorAt!),
      if (lastCodeMethod != null) 'lastCodeMethod': lastCodeMethod,
      if (lastCodeRequestedAt != null)
        'lastCodeRequestedAt': Timestamp.fromDate(lastCodeRequestedAt!),
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
    WhatsAppEmbeddedSignupLauncher? embeddedSignupLauncher,
  }) : _client = httpClient ?? http.Client(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _sendEndpoint = sendEndpoint ?? _tryResolveEndpoint(),
       _embeddedSignupLauncher =
           embeddedSignupLauncher ??
           embedded_signup_launcher.createWhatsAppEmbeddedSignupLauncher();

  final http.Client _client;
  final FirebaseFirestore _firestore;
  final Uri? _sendEndpoint;
  final WhatsAppEmbeddedSignupLauncher _embeddedSignupLauncher;

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
      'whatsapp.businessId': FieldValue.delete(),
      'whatsapp.wabaId': FieldValue.delete(),
      'whatsapp.phoneNumberId': FieldValue.delete(),
      'whatsapp.displayPhoneNumber': FieldValue.delete(),
      'whatsapp.connectionMethod': FieldValue.delete(),
      'whatsapp.requiresReconnect': false,
      'whatsapp.tokenSecretId': FieldValue.delete(),
      'whatsapp.verifyTokenSecretId': FieldValue.delete(),
      'whatsapp.graphApiVersion': FieldValue.delete(),
      'whatsapp.tokenExpiresAt': FieldValue.delete(),
      'whatsapp.connectedAt': FieldValue.delete(),
      'whatsapp.registeredAt': FieldValue.delete(),
      'whatsapp.registrationStatus': 'pending',
      'whatsapp.onboardingStatus': 'disconnected',
      'whatsapp.lastOnboardingErrorMessage': FieldValue.delete(),
      'whatsapp.lastOnboardingErrorAt': FieldValue.delete(),
      'whatsapp.lastRegistrationErrorMessage': FieldValue.delete(),
      'whatsapp.lastRegistrationErrorAt': FieldValue.delete(),
      'whatsapp.lastCodeMethod': FieldValue.delete(),
      'whatsapp.lastCodeRequestedAt': FieldValue.delete(),
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

  Future<WhatsAppEmbeddedSignupSession> createEmbeddedSignupSession(
    String salonId, {
    Uri? redirectUri,
  }) async {
    final functionUri = _resolveFunctionUrl(
      'createWhatsappEmbeddedSignupSession',
    );
    final response = await _authorizedPostJson(functionUri, <String, dynamic>{
      'salonId': salonId,
      if (redirectUri != null)
        'redirectUri': redirectUri.toString()
      else if (kIsWeb)
        'redirectUri': Uri.base.replace(fragment: '').toString(),
    }, forceRefreshFirst: true);
    final body = _decodeJsonBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhatsAppSendException(
        'Impossibile creare la sessione Embedded Signup (${response.statusCode}): '
        '${body['error'] ?? response.body}',
      );
    }

    final sessionId = body['sessionId'] as String?;
    final sessionToken = body['sessionToken'] as String?;
    final appId = body['appId'] as String?;
    final configId = body['configId'] as String?;
    final graphApiVersion = body['graphApiVersion'] as String?;
    if (sessionId == null ||
        sessionToken == null ||
        appId == null ||
        configId == null ||
        graphApiVersion == null) {
      throw WhatsAppSendException(
        'Risposta Embedded Signup incompleta dal backend.',
      );
    }

    return WhatsAppEmbeddedSignupSession(
      salonId: salonId,
      sessionId: sessionId,
      sessionToken: sessionToken,
      appId: appId,
      configId: configId,
      graphApiVersion: graphApiVersion,
    );
  }

  Future<WhatsAppEmbeddedSignupResult> configureManualSetup({
    required String salonId,
    required String accessToken,
    required String wabaId,
    required String phoneNumberId,
    String? businessId,
    String? displayPhoneNumber,
    String? pin,
  }) async {
    final functionUri = _resolveFunctionUrl('configureWhatsappManualSetup');
    final response = await _authorizedPostJson(functionUri, <String, dynamic>{
      'salonId': salonId,
      'accessToken': accessToken,
      'wabaId': wabaId,
      'phoneNumberId': phoneNumberId,
      if (businessId != null && businessId.trim().isNotEmpty)
        'businessId': businessId.trim(),
      if (displayPhoneNumber != null && displayPhoneNumber.trim().isNotEmpty)
        'displayPhoneNumber': displayPhoneNumber.trim(),
      if (pin != null && pin.trim().isNotEmpty) 'pin': pin.trim(),
    }, forceRefreshFirst: true);
    final body = _decodeJsonBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhatsAppSendException(
        'Impossibile salvare la configurazione manuale (${response.statusCode}): '
        '${body['error'] ?? response.body}',
      );
    }
    return _parseEmbeddedSignupResult(
      body,
      defaultPhase: WhatsAppEmbeddedSignupPhase.ready,
    );
  }

  Future<WhatsAppEmbeddedSignupLaunchResult> launchEmbeddedSignup(
    WhatsAppEmbeddedSignupSession session,
  ) {
    return _embeddedSignupLauncher.launch(session);
  }

  Uri buildEmbeddedSignupDialogUrl({
    required WhatsAppEmbeddedSignupSession session,
    required Uri redirectUri,
  }) {
    final graphApiVersion =
        session.graphApiVersion.trim().isEmpty
            ? 'v25.0'
            : session.graphApiVersion.trim();
    return Uri.https('www.facebook.com', '/$graphApiVersion/dialog/oauth', {
      'client_id': session.appId,
      'redirect_uri': redirectUri.toString(),
      'config_id': session.configId,
      'response_type': 'code',
      'override_default_response_type': 'true',
      'scope':
          'business_management,whatsapp_business_management,whatsapp_business_messaging',
      'extras': jsonEncode(<String, Object?>{
        'feature': 'whatsapp_embedded_signup',
        'sessionInfoVersion': 3,
      }),
      'state': session.sessionId,
      'display': 'page',
    });
  }

  Uri buildStandardOAuthDialogUrl({
    required WhatsAppEmbeddedSignupSession session,
    required Uri redirectUri,
  }) {
    final graphApiVersion =
        session.graphApiVersion.trim().isEmpty
            ? 'v25.0'
            : session.graphApiVersion.trim();
    return Uri.https('www.facebook.com', '/$graphApiVersion/dialog/oauth', {
      'client_id': session.appId,
      'redirect_uri': redirectUri.toString(),
      'response_type': 'code',
      'scope':
          'business_management,whatsapp_business_management,whatsapp_business_messaging',
      'state': base64Url
          .encode(
            utf8.encode(
              jsonEncode(<String, String>{
                'salonId': session.salonId,
                'sessionId': session.sessionId,
              }),
            ),
          )
          .replaceAll('=', ''),
      'display': 'page',
      'auth_type': 'rerequest',
    });
  }

  Future<WhatsAppEmbeddedSignupResult> completeEmbeddedSignup({
    required String salonId,
    required String sessionId,
    required String sessionToken,
    required String code,
    required String pin,
    String? businessId,
    String? wabaId,
    String? phoneNumberId,
    String? displayPhoneNumber,
  }) async {
    final functionUri = _resolveFunctionUrl('completeWhatsappEmbeddedSignup');
    final response = await _authorizedPostJson(functionUri, <String, dynamic>{
      'salonId': salonId,
      'sessionId': sessionId,
      'sessionToken': sessionToken,
      'code': code,
      'pin': pin,
      if (businessId != null) 'businessId': businessId,
      if (wabaId != null) 'wabaId': wabaId,
      if (phoneNumberId != null) 'phoneNumberId': phoneNumberId,
      if (displayPhoneNumber != null) 'displayPhoneNumber': displayPhoneNumber,
    });
    final body = _decodeJsonBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhatsAppSendException(
        'Impossibile completare Embedded Signup (${response.statusCode}): '
        '${body['error'] ?? response.body}',
      );
    }
    return _parseEmbeddedSignupResult(
      body,
      defaultPhase: WhatsAppEmbeddedSignupPhase.signupCompleted,
    );
  }

  Future<WhatsAppEmbeddedSignupResult> requestPhoneVerificationCode({
    required String salonId,
    required WhatsAppVerificationCodeMethod codeMethod,
    String? sessionId,
  }) async {
    final functionUri = _resolveFunctionUrl(
      'requestWhatsappPhoneVerificationCode',
    );
    final response = await _authorizedPostJson(functionUri, <String, dynamic>{
      'salonId': salonId,
      'codeMethod':
          codeMethod == WhatsAppVerificationCodeMethod.voice ? 'VOICE' : 'SMS',
      if (sessionId != null) 'sessionId': sessionId,
      'locale': 'it_IT',
    });
    final body = _decodeJsonBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhatsAppSendException(
        'Impossibile richiedere il codice di verifica (${response.statusCode}): '
        '${body['error'] ?? response.body}',
      );
    }
    return _parseEmbeddedSignupResult(
      body,
      defaultPhase: WhatsAppEmbeddedSignupPhase.awaitingVerification,
    );
  }

  Future<WhatsAppEmbeddedSignupResult> confirmPhoneVerificationCode({
    required String salonId,
    required String verificationCode,
    required String pin,
    String? sessionId,
  }) async {
    final functionUri = _resolveFunctionUrl(
      'confirmWhatsappPhoneVerificationCode',
    );
    final response = await _authorizedPostJson(functionUri, <String, dynamic>{
      'salonId': salonId,
      'verificationCode': verificationCode,
      'pin': pin,
      if (sessionId != null) 'sessionId': sessionId,
    });
    final body = _decodeJsonBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WhatsAppSendException(
        'Impossibile confermare il codice di verifica (${response.statusCode}): '
        '${body['error'] ?? response.body}',
      );
    }
    return _parseEmbeddedSignupResult(
      body,
      defaultPhase: WhatsAppEmbeddedSignupPhase.ready,
    );
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

  Map<String, dynamic> _decodeJsonBody(http.Response response) {
    final decodedBody =
        response.body.isEmpty
            ? const <String, dynamic>{}
            : jsonDecode(response.body);
    return decodedBody is Map<String, dynamic>
        ? decodedBody
        : <String, dynamic>{};
  }

  WhatsAppEmbeddedSignupResult _parseEmbeddedSignupResult(
    Map<String, dynamic> body, {
    required WhatsAppEmbeddedSignupPhase defaultPhase,
  }) {
    final nextStep = (body['nextStep'] as String?)?.trim();
    final phase = switch (nextStep) {
      'verification_required' =>
        WhatsAppEmbeddedSignupPhase.awaitingVerification,
      'ready' => WhatsAppEmbeddedSignupPhase.ready,
      _ => defaultPhase,
    };
    final codeMethodRaw = (body['codeMethod'] as String?)?.trim().toUpperCase();

    return WhatsAppEmbeddedSignupResult(
      phase: phase,
      onboardingStatus:
          (body['onboardingStatus'] as String?) ??
          switch (phase) {
            WhatsAppEmbeddedSignupPhase.awaitingVerification =>
              'awaiting_verification',
            WhatsAppEmbeddedSignupPhase.ready => 'ready',
            _ => 'registering',
          },
      registrationStatus:
          (body['registrationStatus'] as String?) ??
          switch (phase) {
            WhatsAppEmbeddedSignupPhase.awaitingVerification =>
              'verification_required',
            WhatsAppEmbeddedSignupPhase.ready => 'registered',
            _ => 'pending',
          },
      phoneNumberId: body['phoneNumberId'] as String?,
      displayPhoneNumber: body['displayPhoneNumber'] as String?,
      sessionId: body['sessionId'] as String?,
      codeMethod:
          codeMethodRaw == 'VOICE'
              ? WhatsAppVerificationCodeMethod.voice
              : codeMethodRaw == 'SMS'
              ? WhatsAppVerificationCodeMethod.sms
              : null,
    );
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
