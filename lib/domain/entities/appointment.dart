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

const Object _appointmentUnset = Object();

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
    Object? notes = _appointmentUnset,
    Object? packageId = _appointmentUnset,
    Object? roomId = _appointmentUnset,
    Object? lastMinuteSlotId = _appointmentUnset,
    Object? createdAt = _appointmentUnset,
    Object? bookingChannel = _appointmentUnset,
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
      notes:
          identical(notes, _appointmentUnset) ? this.notes : notes as String?,
      packageId:
          identical(packageId, _appointmentUnset)
              ? this.packageId
              : packageId as String?,
      roomId:
          identical(roomId, _appointmentUnset)
              ? this.roomId
              : roomId as String?,
      lastMinuteSlotId:
          identical(lastMinuteSlotId, _appointmentUnset)
              ? this.lastMinuteSlotId
              : lastMinuteSlotId as String?,
      createdAt:
          identical(createdAt, _appointmentUnset)
              ? this.createdAt
              : createdAt as DateTime?,
      bookingChannel:
          identical(bookingChannel, _appointmentUnset)
              ? this.bookingChannel
              : bookingChannel as String?,
    );
  }
}
