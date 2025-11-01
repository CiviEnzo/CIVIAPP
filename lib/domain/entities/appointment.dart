import 'appointment_service_allocation.dart';

class Appointment {
  Appointment({
    required this.id,
    required this.salonId,
    required this.clientId,
    required this.staffId,
    String? serviceId,
    List<String>? serviceIds,
    List<AppointmentServiceAllocation>? serviceAllocations,
    required this.start,
    required this.end,
    this.status = AppointmentStatus.scheduled,
    this.notes,
    this.packageId,
    this.roomId,
    this.lastMinuteSlotId,
    this.createdAt,
    this.bookingChannel,
  }) : _serviceAllocations = List<AppointmentServiceAllocation>.unmodifiable(
         _resolveServiceAllocations(
           serviceAllocations: serviceAllocations,
           serviceId: serviceId,
           serviceIds: serviceIds,
         ),
       );

  final String id;
  final String salonId;
  final String clientId;
  final String staffId;
  final List<AppointmentServiceAllocation> _serviceAllocations;
  final DateTime start;
  final DateTime end;
  final AppointmentStatus status;
  final String? notes;
  final String? packageId;
  final String? roomId;
  final String? lastMinuteSlotId;
  final DateTime? createdAt;
  final String? bookingChannel;

  List<AppointmentServiceAllocation> get serviceAllocations =>
      _serviceAllocations;

  List<String> get serviceIds => _serviceAllocations
      .map((allocation) => allocation.serviceId)
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

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

List<AppointmentServiceAllocation> _resolveServiceAllocations({
  List<AppointmentServiceAllocation>? serviceAllocations,
  String? serviceId,
  List<String>? serviceIds,
}) {
  if (serviceAllocations != null && serviceAllocations.isNotEmpty) {
    return serviceAllocations;
  }
  final resolvedIds = _resolveServiceIds(
    serviceId: serviceId,
    serviceIds: serviceIds,
  );
  if (resolvedIds.isEmpty) {
    return const <AppointmentServiceAllocation>[];
  }
  return resolvedIds
      .map(
        (id) => AppointmentServiceAllocation(
          serviceId: id,
          quantity: 1,
          packageConsumptions: const [],
        ),
      )
      .toList(growable: false);
}

enum AppointmentStatus { scheduled, completed, cancelled, noShow }

extension AppointmentX on Appointment {
  Duration get duration => end.difference(start);

  bool get hasPackageConsumptions => serviceAllocations.any(
    (allocation) => allocation.packageConsumptions.isNotEmpty,
  );

  Appointment copyWith({
    String? id,
    String? salonId,
    String? clientId,
    String? staffId,
    String? serviceId,
    List<String>? serviceIds,
    List<AppointmentServiceAllocation>? serviceAllocations,
    DateTime? start,
    DateTime? end,
    AppointmentStatus? status,
    String? notes,
    String? packageId,
    String? roomId,
    String? lastMinuteSlotId,
    DateTime? createdAt,
    String? bookingChannel,
  }) {
    final updatedAllocations =
        serviceAllocations ??
        (serviceIds != null
            ? serviceIds
                .map(
                  (id) => AppointmentServiceAllocation(
                    serviceId: id,
                    quantity: 1,
                    packageConsumptions: const [],
                  ),
                )
                .toList(growable: false)
            : (serviceId != null
                ? <AppointmentServiceAllocation>[
                  AppointmentServiceAllocation(
                    serviceId: serviceId,
                    quantity: serviceId.isNotEmpty ? 1 : 0,
                    packageConsumptions: const [],
                  ),
                ]
                : serviceAllocations ?? _serviceAllocations));
    return Appointment(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      clientId: clientId ?? this.clientId,
      staffId: staffId ?? this.staffId,
      serviceAllocations: updatedAllocations,
      start: start ?? this.start,
      end: end ?? this.end,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      packageId: packageId ?? this.packageId,
      roomId: roomId ?? this.roomId,
      lastMinuteSlotId: lastMinuteSlotId ?? this.lastMinuteSlotId,
      createdAt: createdAt ?? this.createdAt,
      bookingChannel: bookingChannel ?? this.bookingChannel,
    );
  }
}
