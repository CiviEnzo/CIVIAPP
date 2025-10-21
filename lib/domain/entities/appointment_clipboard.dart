import 'package:civiapp/domain/entities/appointment.dart';

class AppointmentClipboard {
  AppointmentClipboard({
    required this.appointment,
    required this.copiedAt,
  });

  final Appointment appointment;
  final DateTime copiedAt;

  AppointmentClipboard copyWith({
    Appointment? appointment,
    DateTime? copiedAt,
  }) {
    return AppointmentClipboard(
      appointment: appointment ?? this.appointment,
      copiedAt: copiedAt ?? this.copiedAt,
    );
  }
}
