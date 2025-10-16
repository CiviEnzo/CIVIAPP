import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wrapper around [FlutterLocalNotificationsPlugin] that centralises
/// initialisation, channel creation and tap handling.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'civiapp_push';
  static const String _channelName = 'Notifiche Civiapp';
  static const String _channelDescription =
      'Aggiornamenti e promemoria inviati dal salone';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<NotificationTap> _tapStreamController =
      StreamController<NotificationTap>.broadcast();

  bool _initialized = false;

  Stream<NotificationTap> get onNotificationTap => _tapStreamController.stream;

  /// Initialises the plugin once per applicazione.
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initializationSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: handleNotificationResponse,
    );

    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableLights: true,
        enableVibration: true,
      ),
    );

    _initialized = true;
  }

  Future<void> updateBadgeCount(int count) async {
    if (!_initialized || kIsWeb) {
      return;
    }
    try {
      final isSupported = await FlutterAppBadger.isAppBadgeSupported();
      if (!isSupported) {
        return;
      }
      if (count <= 0) {
        await FlutterAppBadger.removeBadge();
        return;
      }
      await FlutterAppBadger.updateBadgeCount(count);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Failed to update badge: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      return;
    }
  }

  /// Shows a local notification mirroring an FCM payload in foreground.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    Map<String, Object?>? payload,
    NotificationDetails? notificationDetails,
  }) async {
    if (!_initialized) {
      if (kDebugMode) {
        throw StateError('NotificationService not initialised');
      }
      return;
    }

    final details =
        notificationDetails ??
        NotificationDetails(
          android: const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
          macOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        );

    final payloadJson =
        payload == null || payload.isEmpty ? null : jsonEncode(payload);

    await _plugin.show(id, title, body, details, payload: payloadJson);
  }

  /// Dispatches the tap event to listeners so navigation can be handled.
  void handleNotificationResponse(NotificationResponse response) {
    if (response.payload == null) {
      _tapStreamController.add(
        NotificationTap(id: response.id, payload: const <String, Object?>{}),
      );
      return;
    }

    try {
      final decoded = Map<String, Object?>.from(
        jsonDecode(response.payload!) as Map<String, dynamic>,
      );
      _tapStreamController.add(
        NotificationTap(id: response.id, payload: decoded),
      );
    } on FormatException {
      _tapStreamController.add(
        NotificationTap(
          id: response.id,
          payload: <String, Object?>{'raw': response.payload},
        ),
      );
    }
  }

  /// Bridges a remote message interaction (tap on system notification) to the
  /// local notification tap stream so navigation can react uniformly.
  void handleMessageInteraction(RemoteMessage message) {
    final payload = <String, Object?>{
      ...message.data.map((key, value) => MapEntry(key, value)),
      if (message.messageId != null) 'messageId': message.messageId!,
    };
    final badgeRaw = message.data['badge'] ?? message.data['unreadCount'];
    final badgeCount = _parseBadgeCount(badgeRaw);
    if (badgeCount != null) {
      unawaited(updateBadgeCount(badgeCount));
    }

    _tapStreamController.add(
      NotificationTap(id: message.messageId?.hashCode, payload: payload),
    );
  }

  Future<void> dispose() async {
    await _tapStreamController.close();
  }

  int? _parseBadgeCount(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }
}

/// Simple model emitted when l’utente interagisce con una notifica.
class NotificationTap {
  const NotificationTap({required this.id, required this.payload});

  final int? id;
  final Map<String, Object?> payload;
}
