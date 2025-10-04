class Appointment {
  Appointment({
    required this.id,
    required this.salonId,
    required this.clientId,
    required this.staffId,
    String? serviceId,
    List<String>? serviceIds,
    required this.start,
    required this.end,
    this.status = AppointmentStatus.scheduled,
    this.notes,
    this.packageId,
    this.roomId,
  }) : serviceIds = _resolveServiceIds(serviceId: serviceId, serviceIds: serviceIds);

  final String id;
  final String salonId;
  final String clientId;
  final String staffId;
  final List<String> serviceIds;
  final DateTime start;
  final DateTime end;
  final AppointmentStatus status;
  final String? notes;
  final String? packageId;
  final String? roomId;
  String get serviceId => serviceIds.isNotEmpty ? serviceIds.first : '';
}

List<String> _resolveServiceIds({String? serviceId, List<String>? serviceIds}) {
  if (serviceIds != null && serviceIds.isNotEmpty) {
    return List<String>.unmodifiable(serviceIds);
  }
  if (serviceId != null && serviceId.isNotEmpty) {
    return List<String>.unmodifiable([serviceId]);
  }
  return const <String>[];
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
    List<String>? serviceIds,
    DateTime? start,
    DateTime? end,
    AppointmentStatus? status,
    String? notes,
    String? packageId,
    String? roomId,
  }) {
    final updatedServiceIds =
        serviceIds ??
        (serviceId != null
            ? (serviceId.isNotEmpty ? [serviceId] : <String>[])
            : this.serviceIds);
    return Appointment(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      clientId: clientId ?? this.clientId,
      staffId: staffId ?? this.staffId,
      serviceIds: updatedServiceIds,
      start: start ?? this.start,
      end: end ?? this.end,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      packageId: packageId ?? this.packageId,
      roomId: roomId ?? this.roomId,
    );
  }
}
