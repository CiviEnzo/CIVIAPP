class Appointment {
  const Appointment({
    required this.id,
    required this.salonId,
    required this.clientId,
    required this.staffId,
    required this.serviceId,
    required this.start,
    required this.end,
    this.status = AppointmentStatus.scheduled,
    this.notes,
    this.packageId,
    this.roomId,
  });

  final String id;
  final String salonId;
  final String clientId;
  final String staffId;
  final String serviceId;
  final DateTime start;
  final DateTime end;
  final AppointmentStatus status;
  final String? notes;
  final String? packageId;
  final String? roomId;
}

enum AppointmentStatus { scheduled, confirmed, completed, cancelled, noShow }

extension AppointmentX on Appointment {
  Duration get duration => end.difference(start);

  Appointment copyWith({
    String? id,
    String? salonId,
    String? clientId,
    String? staffId,
    String? serviceId,
    DateTime? start,
    DateTime? end,
    AppointmentStatus? status,
    String? notes,
    String? packageId,
    String? roomId,
  }) {
    return Appointment(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      clientId: clientId ?? this.clientId,
      staffId: staffId ?? this.staffId,
      serviceId: serviceId ?? this.serviceId,
      start: start ?? this.start,
      end: end ?? this.end,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      packageId: packageId ?? this.packageId,
      roomId: roomId ?? this.roomId,
    );
  }
}
