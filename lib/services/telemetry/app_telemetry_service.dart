import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AppTelemetryService {
  const AppTelemetryService({
    required FirebaseAnalytics? analytics,
    required FirebaseCrashlytics? crashlytics,
  }) : _analytics = analytics,
       _crashlytics = crashlytics;

  final FirebaseAnalytics? _analytics;
  final FirebaseCrashlytics? _crashlytics;

  Future<void> setUserContext({
    required String? uid,
    required String? role,
    required String? selectedSalonId,
    required String? entityId,
  }) async {
    final normalizedUid = _trimmedOrNull(uid);
    final normalizedRole = _trimmedOrNull(role);
    final normalizedSalonId = _trimmedOrNull(selectedSalonId);
    final normalizedEntityId = _trimmedOrNull(entityId);

    final analytics = _analytics;
    if (analytics != null) {
      await _safeAnalyticsCall(() async {
        await analytics.setUserId(id: normalizedUid);
        await analytics.setUserProperty(name: 'role', value: normalizedRole);
        await analytics.setUserProperty(
          name: 'has_active_salon',
          value: normalizedSalonId == null ? 'false' : 'true',
        );
      });
    }

    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      return;
    }
    await _safeCrashlyticsCall(() async {
      await crashlytics.setUserIdentifier(normalizedUid ?? '');
      await crashlytics.setCustomKey('role', normalizedRole ?? 'anonymous');
      await crashlytics.setCustomKey(
        'has_active_salon',
        normalizedSalonId != null,
      );
      await crashlytics.setCustomKey('entity_id', normalizedEntityId ?? '');
    });
  }

  Future<void> logEvent(
    String name, {
    Map<String, Object?> parameters = const <String, Object?>{},
  }) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }
    await _safeAnalyticsCall(() {
      return analytics.logEvent(
        name: name,
        parameters: _sanitizeParameters(parameters),
      );
    });
  }

  Future<void> logRateAppTapped({required String source}) {
    return logEvent('rate_app_tapped', parameters: {'source': source});
  }

  Future<void> logFeedbackStarted({required String source}) {
    return logEvent('app_feedback_started', parameters: {'source': source});
  }

  Future<void> logFeedbackSubmitted({
    required String source,
    required String category,
  }) {
    return logEvent(
      'app_feedback_submitted',
      parameters: {'source': source, 'category': category},
    );
  }

  Future<void> logOnboardingStarted({
    required String source,
    required String version,
  }) {
    return logEvent(
      'onboarding_started',
      parameters: {'source': source, 'version': version},
    );
  }

  Future<void> logOnboardingStepViewed({
    required String source,
    required String version,
    required String stepId,
    required int stepIndex,
  }) {
    return logEvent(
      'onboarding_step_viewed',
      parameters: {
        'source': source,
        'version': version,
        'step_id': stepId,
        'step_index': stepIndex,
      },
    );
  }

  Future<void> logOnboardingCompleted({
    required String source,
    required String version,
  }) {
    return logEvent(
      'onboarding_completed',
      parameters: {'source': source, 'version': version},
    );
  }

  Future<void> logOnboardingSkipped({
    required String source,
    required String version,
    required String stepId,
    required int stepIndex,
  }) {
    return logEvent(
      'onboarding_skipped',
      parameters: {
        'source': source,
        'version': version,
        'step_id': stepId,
        'step_index': stepIndex,
      },
    );
  }

  Future<void> recordNonFatalError(
    Object error,
    StackTrace stackTrace, {
    String reason = 'non_fatal_error',
  }) async {
    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      return;
    }
    await _safeCrashlyticsCall(() {
      return crashlytics.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: false,
      );
    });
  }

  Map<String, Object> _sanitizeParameters(Map<String, Object?> parameters) {
    final sanitized = <String, Object>{};
    for (final entry in parameters.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is String) {
        sanitized[key] = value.length > 100 ? value.substring(0, 100) : value;
      } else if (value is num) {
        sanitized[key] = value;
      } else if (value is bool) {
        sanitized[key] = value ? 'true' : 'false';
      } else {
        sanitized[key] = value.toString();
      }
    }
    return sanitized;
  }

  Future<void> _safeAnalyticsCall(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stackTrace) {
      debugPrint('Analytics non disponibile: $error');
      unawaited(
        recordNonFatalError(error, stackTrace, reason: 'analytics_call_failed'),
      );
    }
  }

  Future<void> _safeCrashlyticsCall(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Crashlytics non disponibile: $error');
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
