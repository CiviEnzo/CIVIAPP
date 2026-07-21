import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:you_book/services/telemetry/app_telemetry_service.dart';

enum AppFeedbackCategory {
  bug,
  suggestion,
  usability,
  performance,
  account,
  other,
}

extension AppFeedbackCategoryLabel on AppFeedbackCategory {
  String get label {
    switch (this) {
      case AppFeedbackCategory.bug:
        return 'Problema tecnico';
      case AppFeedbackCategory.suggestion:
        return 'Suggerimento';
      case AppFeedbackCategory.usability:
        return 'Usabilita';
      case AppFeedbackCategory.performance:
        return 'Prestazioni';
      case AppFeedbackCategory.account:
        return 'Account o accesso';
      case AppFeedbackCategory.other:
        return 'Altro';
    }
  }
}

class AppFeedbackService {
  const AppFeedbackService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required AppTelemetryService telemetry,
  }) : _firestore = firestore,
       _auth = auth,
       _telemetry = telemetry;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AppTelemetryService _telemetry;

  Future<void> submitFeedback({
    required AppFeedbackCategory category,
    required String message,
    required String source,
    String? userRole,
    String? contextEntityId,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.length < 8) {
      throw ArgumentError('Il feedback deve contenere almeno 8 caratteri.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Devi accedere per inviare un feedback.');
    }

    final packageInfo = await _resolvePackageInfo();
    final payload = <String, Object?>{
      'category': category.name,
      'message': trimmedMessage,
      'status': 'new',
      'source': source,
      'userId': user.uid,
      'userEmail': user.email,
      'userRole': _trimmedOrNull(userRole),
      'contextEntityId': _trimmedOrNull(contextEntityId),
      'platform': _platformName(),
      'isWeb': kIsWeb,
      'appVersion': packageInfo?.version,
      'buildNumber': packageInfo?.buildNumber,
      'packageName': packageInfo?.packageName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('app_feedback').add(payload);
      await _telemetry.logFeedbackSubmitted(
        source: source,
        category: category.name,
      );
    } catch (error, stackTrace) {
      await _telemetry.recordNonFatalError(
        error,
        stackTrace,
        reason: 'app_feedback_submit_failed',
      );
      rethrow;
    }
  }

  Future<PackageInfo?> _resolvePackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static String? _trimmedOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
