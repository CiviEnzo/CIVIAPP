import 'dart:io';

import 'package:you_book/app/app.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/services/notifications/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  defaultValue: 'merchant.com.cividevops.civiapp',
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  try {
    await Firebase.initializeApp();
  } catch (error, stackTrace) {
    debugPrint(
      'Firebase initialization failed. Did you run flutterfire configure?\n$error',
    );
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }

  /* if (kDebugMode) {
    final emulatorHost = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
    FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001);
    for (final region in ['europe-west1', 'europe-west3']) {
      FirebaseFunctions.instanceFor(region: region)
          .useFunctionsEmulator(emulatorHost, 5001);
    }
  }*/

  if (_stripePublishableKey.isNotEmpty) {
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

  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final inAppMessaging = FirebaseInAppMessaging.instance;
      await inAppMessaging.setAutomaticDataCollectionEnabled(true);
      await inAppMessaging.setMessagesSuppressed(false);
    } catch (error, stackTrace) {
      debugPrint('Impossibile inizializzare Firebase In-App Messaging: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  if (Platform.isIOS) {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }
  await notificationService.init();
  FirebaseMessaging.onMessageOpenedApp.listen(
    notificationService.handleMessageInteraction,
  );
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notificationService.handleMessageInteraction(initialMessage);
    });
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
