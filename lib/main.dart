import 'dart:async';

import 'package:you_book/app/app.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/firebase_options.dart';
import 'package:you_book/services/notifications/notification_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';

const _stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
const _isStripeTestMode = bool.fromEnvironment(
  'STRIPE_TEST_MODE',
  defaultValue: true,
);
const _stripeMerchantId = String.fromEnvironment(
  'STRIPE_MERCHANT_ID',
  defaultValue: 'merchant.com.civiapp.youbook',
);
const _firebaseWebVapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

bool _isTargetPlatform(TargetPlatform platform) {
  return !kIsWeb && defaultTargetPlatform == platform;
}

bool _isDebugMacOSCapsLockKeyUpAssertion(Object error) {
  if (!kDebugMode || !_isTargetPlatform(TargetPlatform.macOS)) {
    return false;
  }

  final message = error.toString();
  return message.contains('hardware_keyboard.dart') &&
      message.contains('_pressedKeys.containsKey(event.physicalKey)') &&
      message.contains('A KeyUpEvent is dispatched') &&
      message.contains('Caps Lock');
}

void _installDebugMacOSKeyboardAssertionWorkaround() {
  if (!kDebugMode || !_isTargetPlatform(TargetPlatform.macOS)) {
    return;
  }

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_isDebugMacOSCapsLockKeyUpAssertion(details.exception)) {
      debugPrint(
        'Ignorato assert Flutter/macOS debug su KeyUp sintetico Caps Lock.',
      );
      return;
    }
    previousFlutterOnError?.call(details);
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isDebugMacOSCapsLockKeyUpAssertion(error)) {
      debugPrint(
        'Ignorato assert Flutter/macOS debug su KeyUp sintetico Caps Lock.',
      );
      return true;
    }
    return previousPlatformOnError?.call(error, stack) ?? false;
  };
}

bool get _supportsCrashlytics {
  if (kIsWeb) {
    return false;
  }
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

Future<void> _installCrashlyticsErrorReporting() async {
  if (!_supportsCrashlytics) {
    return;
  }

  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  } catch (error, stackTrace) {
    debugPrint('Impossibile configurare Crashlytics: $error');
    debugPrintStack(stackTrace: stackTrace);
    return;
  }

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    previousFlutterOnError?.call(details);
    if (_isDebugMacOSCapsLockKeyUpAssertion(details.exception)) {
      return;
    }
    unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    if (!_isDebugMacOSCapsLockKeyUpAssertion(error)) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
      );
    }
    return previousPlatformOnError?.call(error, stack) ?? true;
  };
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installDebugMacOSKeyboardAssertionWorkaround();
  final notificationService = NotificationService();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    debugPrint(
      'Firebase initialization failed. Did you run flutterfire configure?\n$error',
    );
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
  await _installCrashlyticsErrorReporting();

  /* if (kDebugMode) {
    final emulatorHost = _isTargetPlatform(TargetPlatform.android)
        ? '10.0.2.2'
        : 'localhost';
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
    FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001);
    for (final region in ['europe-west1', 'europe-west3']) {
      FirebaseFunctions.instanceFor(region: region)
          .useFunctionsEmulator(emulatorHost, 5001);
    }
  }*/

  if (kIsWeb) {
    debugPrint('Stripe non supportato su web.');
  } else if (_stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = _stripePublishableKey;
    Stripe.merchantIdentifier = _stripeMerchantId;
    await Stripe.instance.applySettings();
    if (_isStripeTestMode) {
      debugPrint(
        'Stripe configurato in modalità TEST. '
        'Imposta STRIPE_TEST_MODE=false e usa le chiavi Live prima del rilascio.',
      );
    }
  } else {
    debugPrint(
      'Stripe non è configurato: STRIPE_PUBLISHABLE_KEY non impostato.',
    );
  }

  if (_isTargetPlatform(TargetPlatform.android) ||
      _isTargetPlatform(TargetPlatform.iOS)) {
    try {
      final inAppMessaging = FirebaseInAppMessaging.instance;
      await inAppMessaging.setAutomaticDataCollectionEnabled(true);
      await inAppMessaging.setMessagesSuppressed(false);
    } catch (error, stackTrace) {
      debugPrint('Impossibile inizializzare Firebase In-App Messaging: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    if (_isTargetPlatform(TargetPlatform.iOS)) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }
  await notificationService.init();
  if (!kIsWeb) {
    FirebaseMessaging.onMessageOpenedApp.listen(
      notificationService.handleMessageInteraction,
    );
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notificationService.handleMessageInteraction(initialMessage);
      });
    }
  } else if (_firebaseWebVapidKey.isEmpty) {
    debugPrint(
      'Firebase web push: FIREBASE_VAPID_KEY non impostata. '
      'Imposta la chiave VAPID per ottenere token FCM su web.',
    );
  }
  await initializeDateFormatting('it_IT');
  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const CiviApp(),
    ),
  );
}
