// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'whatsapp_embedded_signup_launcher.dart';
import 'whatsapp_embedded_signup_models.dart';

class WebWhatsAppEmbeddedSignupLauncher
    implements WhatsAppEmbeddedSignupLauncher {
  Future<void>? _sdkLoadFuture;
  String? _initializedAppId;
  String? _initializedGraphApiVersion;

  @override
  Future<WhatsAppEmbeddedSignupLaunchResult> launch(
    WhatsAppEmbeddedSignupSession session,
  ) async {
    await _ensureSdkLoaded(
      appId: session.appId,
      graphApiVersion: session.graphApiVersion,
    );

    Map<String, dynamic>? latestFinishPayload;
    final completer = Completer<WhatsAppEmbeddedSignupLaunchResult>();

    late html.EventListener messageListener;
    messageListener = (event) {
      if (event is! html.MessageEvent) {
        return;
      }
      final origin = event.origin.toLowerCase();
      if (!origin.contains('facebook.com') && !origin.contains('meta.com')) {
        return;
      }

      final payload = _extractPayload(event.data);
      if (payload == null) {
        return;
      }
      latestFinishPayload = payload;

      final eventName = (payload['event'] as String?)?.trim().toUpperCase();
      if (eventName == 'CANCEL' && !completer.isCompleted) {
        completer.completeError(
          StateError('Il collegamento WhatsApp e stato annullato.'),
        );
      }
    };

    html.window.addEventListener('message', messageListener);

    try {
      final fb = js_util.getProperty(html.window, 'FB');
      js_util.callMethod<void>(
        fb,
        'login',
        <Object?>[
          js_util.allowInterop((dynamic response) {
            if (completer.isCompleted) {
              return;
            }

            final code =
                _readString(_getProperty(response, 'authResponse'), 'code') ??
                _readString(response, 'code');
            if (code != null && code.isNotEmpty) {
              completer.complete(
                _buildLaunchResult(
                  code: code,
                  payload: latestFinishPayload,
                ),
              );
              return;
            }

            completer.completeError(
              StateError(
                'Meta non ha restituito un codice Embedded Signup valido.',
              ),
            );
          }),
          js_util.jsify(<String, Object?>{
            'config_id': session.configId,
            'response_type': 'code',
            'override_default_response_type': true,
            'scope':
                'business_management,whatsapp_business_management,whatsapp_business_messaging',
            'extras': <String, Object?>{
              'feature': 'whatsapp_embedded_signup',
              'sessionInfoVersion': 3,
            },
          }),
        ],
      );

      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw StateError(
          'Timeout durante il collegamento WhatsApp con Meta.',
        ),
      );
    } finally {
      html.window.removeEventListener('message', messageListener);
    }
  }

  Future<void> _ensureSdkLoaded({
    required String appId,
    required String graphApiVersion,
  }) async {
    if (js_util.hasProperty(html.window, 'FB')) {
      _initFacebookSdk(appId: appId, graphApiVersion: graphApiVersion);
      return;
    }

    if (_sdkLoadFuture != null) {
      await _sdkLoadFuture;
      _initFacebookSdk(appId: appId, graphApiVersion: graphApiVersion);
      return;
    }

    final completer = Completer<void>();
    _sdkLoadFuture = completer.future;

    js_util.setProperty(
      html.window,
      'fbAsyncInit',
      js_util.allowInterop(() {
        completer.complete();
      }),
    );

    final script = html.ScriptElement()
      ..src = 'https://connect.facebook.net/en_US/sdk.js'
      ..async = true
      ..defer = true;

    script.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Impossibile caricare il Meta JavaScript SDK.'),
        );
      }
    });

    html.document.head?.append(script);
    await completer.future;
    _initFacebookSdk(appId: appId, graphApiVersion: graphApiVersion);
  }

  void _initFacebookSdk({
    required String appId,
    required String graphApiVersion,
  }) {
    if (_initializedAppId == appId &&
        _initializedGraphApiVersion == graphApiVersion &&
        js_util.hasProperty(html.window, 'FB')) {
      return;
    }

    final fb = js_util.getProperty(html.window, 'FB');
    js_util.callMethod<void>(
      fb,
      'init',
      <Object?>[
        js_util.jsify(<String, Object?>{
          'appId': appId,
          'cookie': true,
          'xfbml': false,
          'version': graphApiVersion,
        }),
      ],
    );

    _initializedAppId = appId;
    _initializedGraphApiVersion = graphApiVersion;
  }

  Map<String, dynamic>? _extractPayload(Object? rawData) {
    Object? candidate = rawData;
    if (candidate is String) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      try {
        candidate = jsonDecode(trimmed);
      } catch (_) {
        return null;
      }
    } else if (candidate != null) {
      try {
        candidate = js_util.dartify(candidate);
      } catch (_) {
        candidate = null;
      }
    }

    if (candidate is! Map) {
      return null;
    }

    final payload = Map<String, dynamic>.from(candidate);
    final payloadType = (payload['type'] as String?)?.trim().toUpperCase();
    if (payloadType != null &&
        payloadType.isNotEmpty &&
        payloadType != 'WHATSAPP_EMBEDDED_SIGNUP') {
      return null;
    }
    return payload;
  }

  WhatsAppEmbeddedSignupLaunchResult _buildLaunchResult({
    required String code,
    Map<String, dynamic>? payload,
  }) {
    final data =
        payload != null && payload['data'] is Map
            ? Map<String, dynamic>.from(payload['data'] as Map)
            : const <String, dynamic>{};

    return WhatsAppEmbeddedSignupLaunchResult(
      code: code,
      businessId: _stringOrNull(data['business_id'] ?? data['businessId']),
      wabaId:
          _stringOrNull(
            data['waba_id'] ?? data['whatsapp_business_account_id'],
          ) ??
          _stringOrNull(data['wabaId']),
      phoneNumberId:
          _stringOrNull(data['phone_number_id']) ??
          _stringOrNull(data['phoneNumberId']),
      displayPhoneNumber:
          _stringOrNull(data['phone_number']) ??
          _stringOrNull(data['display_phone_number']) ??
          _stringOrNull(data['displayPhoneNumber']),
      verifiedName:
          _stringOrNull(data['verified_name']) ??
          _stringOrNull(data['verifiedName']),
      rawPayload: payload,
    );
  }
}

Object? _getProperty(Object? value, String name) {
  if (value == null) {
    return null;
  }
  try {
    return js_util.getProperty(value, name);
  } catch (_) {
    return null;
  }
}

String? _readString(Object? object, String property) {
  final value = _getProperty(object, property);
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _stringOrNull(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

WhatsAppEmbeddedSignupLauncher createWhatsAppEmbeddedSignupLauncher() {
  return WebWhatsAppEmbeddedSignupLauncher();
}
