import 'package:civiapp/domain/entities/message_template.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.salonId,
    required this.clientId,
    required this.channel,
    required this.status,
    required this.createdAt,
    this.title,
    this.body,
    this.payload = const <String, dynamic>{},
    this.scheduledAt,
    this.sentAt,
    this.type,
    this.offsetMinutes,
  });

  final String id;
  final String salonId;
  final String clientId;
  final MessageChannel channel;
  final String status;
  final DateTime createdAt;
  final String? title;
  final String? body;
  final Map<String, dynamic> payload;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final String? type;
  final int? offsetMinutes;
}
