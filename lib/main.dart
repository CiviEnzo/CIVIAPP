import 'dart:io';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/presentation/branding/widgets/branded_app_shell.dart';
import 'package:civiapp/services/notifications/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';

const _stripePublishableKey = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
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

  if (_stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = _stripePublishableKey;
    Stripe.merchantIdentifier = _stripeMerchantId;
    await Stripe.instance.applySettings();
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
      child: const BrandedAppShell(),
    ),
  );
}
