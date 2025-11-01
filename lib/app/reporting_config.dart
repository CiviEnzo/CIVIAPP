import 'package:flutter/foundation.dart';

const String _reportingCutoffDefine = String.fromEnvironment(
  'REPORTING_CUTOFF',
  defaultValue: '',
);

/// Global cutoff used to exclude legacy data from reporting metrics.
///
/// Configure via `--dart-define=REPORTING_CUTOFF=YYYY-MM-DD` (UTC) when
/// launching the app. When not provided, all historical data is considered.
final DateTime? kReportingCutoff = () {
  if (_reportingCutoffDefine.isEmpty) {
    return null;
  }
  try {
    final parsed = DateTime.parse(_reportingCutoffDefine);
    return parsed.isUtc ? parsed : parsed.toUtc();
  } catch (error, stackTrace) {
    debugPrint(
      'Invalid REPORTING_CUTOFF "$_reportingCutoffDefine": $error\n$stackTrace',
    );
    return null;
  }
}();

bool includeInReporting({required DateTime? primary, DateTime? fallback}) {
  final cutoff = kReportingCutoff;
  if (cutoff == null) {
    return true;
  }
  final value = primary ?? fallback;
  if (value == null) {
    return false;
  }
  return !value.toUtc().isBefore(cutoff);
}
