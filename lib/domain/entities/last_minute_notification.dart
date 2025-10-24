import 'package:you_book/domain/entities/reminder_settings.dart';

class LastMinuteNotificationRequest {
  const LastMinuteNotificationRequest({
    required this.audience,
    this.clientIds = const <String>[],
  });

  final LastMinuteNotificationAudience audience;
  final List<String> clientIds;
}

class LastMinuteNotificationResult {
  const LastMinuteNotificationResult({
    required this.successCount,
    required this.failureCount,
    required this.skippedCount,
  });

  final int successCount;
  final int failureCount;
  final int skippedCount;
}
