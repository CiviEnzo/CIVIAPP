import 'package:you_book/domain/entities/message_template.dart';

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
    this.readAt,
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
  final DateTime? readAt;

  bool get isRead => readAt != null;

  AppNotification copyWith({String? status, DateTime? readAt}) {
    return AppNotification(
      id: id,
      salonId: salonId,
      clientId: clientId,
      channel: channel,
      status: status ?? this.status,
      createdAt: createdAt,
      title: title,
      body: body,
      payload: payload,
      scheduledAt: scheduledAt,
      sentAt: sentAt,
      type: type,
      offsetMinutes: offsetMinutes,
      readAt: readAt ?? this.readAt,
    );
  }
}
