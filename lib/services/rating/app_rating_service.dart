import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:you_book/services/telemetry/app_telemetry_service.dart';

class AppRatingService {
  const AppRatingService({required AppTelemetryService telemetry})
    : _telemetry = telemetry;

  static const String androidPackageId = String.fromEnvironment(
    'ANDROID_PACKAGE_ID',
    defaultValue: 'com.cividevops.civiapp',
  );
  static const String appStoreId = String.fromEnvironment('APP_STORE_ID');
  static const String appStoreUrl = String.fromEnvironment('APP_STORE_URL');

  final AppTelemetryService _telemetry;

  Future<bool> openStoreListing({required String source}) async {
    await _telemetry.logRateAppTapped(source: source);

    if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
      return _launchWithFallback(
        primary: Uri.parse('market://details?id=$androidPackageId'),
        fallback: Uri.https('play.google.com', '/store/apps/details', {
          'id': androidPackageId,
        }),
      );
    }

    if ((defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) &&
        !kIsWeb) {
      return _openAppleStoreListing();
    }

    return launchUrl(
      Uri.https('play.google.com', '/store/apps/details', {
        'id': androidPackageId,
      }),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<bool> _openAppleStoreListing() async {
    final fallback = _appleWebUri();
    if (fallback == null) {
      return false;
    }

    final id = appStoreId.trim();
    if (id.isEmpty) {
      return launchUrl(fallback, mode: LaunchMode.externalApplication);
    }

    final primary =
        defaultTargetPlatform == TargetPlatform.macOS
            ? Uri.parse('macappstore://itunes.apple.com/app/id$id')
            : Uri.parse('itms-apps://itunes.apple.com/app/id$id');
    return _launchWithFallback(primary: primary, fallback: fallback);
  }

  Uri? _appleWebUri() {
    final configuredUrl = appStoreUrl.trim();
    if (configuredUrl.isNotEmpty) {
      return Uri.tryParse(configuredUrl);
    }

    final id = appStoreId.trim();
    if (id.isEmpty) {
      return null;
    }
    return Uri.https('apps.apple.com', '/app/id$id');
  }

  Future<bool> _launchWithFallback({
    required Uri primary,
    required Uri fallback,
  }) async {
    final launchedPrimary = await launchUrl(
      primary,
      mode: LaunchMode.externalApplication,
    );
    if (launchedPrimary) {
      return true;
    }
    return launchUrl(fallback, mode: LaunchMode.externalApplication);
  }
}
