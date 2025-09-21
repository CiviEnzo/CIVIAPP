import 'package:civiapp/app/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (error, stackTrace) {
    debugPrint(
      'Firebase initialization failed. Did you run flutterfire configure?\n$error',
    );
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
  await initializeDateFormatting('it_IT');
  runApp(const ProviderScope(child: CiviApp()));
}
