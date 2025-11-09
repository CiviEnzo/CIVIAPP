import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';

class EquipmentBookingResult {
  EquipmentBookingResult._({
    required this.isAvailable,
    required List<String> blockingEquipment,
  }) : blockingEquipment = List.unmodifiable(blockingEquipment);

  final bool isAvailable;
  final List<String> blockingEquipment;

  factory EquipmentBookingResult.available() {
    return EquipmentBookingResult._(
      isAvailable: true,
      blockingEquipment: <String>[],
    );
  }

  factory EquipmentBookingResult.unavailable(List<String> blockingEquipment) {
    return EquipmentBookingResult._(
      isAvailable: false,
      blockingEquipment: blockingEquipment,
    );
  }

  bool get hasConflicts => !isAvailable;
}

class EquipmentAvailabilityChecker {
  const EquipmentAvailabilityChecker._();

  static EquipmentBookingResult check({
    required Salon? salon,
    required Service service,
    required Iterable<Service> allServices,
    required Iterable<Appointment> appointments,
    required DateTime start,
    required DateTime end,
    String? excludeAppointmentId,
  }) {
    final requiredIds = service.requiredEquipmentIds;
    if (requiredIds.isEmpty) {
      return EquipmentBookingResult.available();
    }
    if (salon == null) {
      return EquipmentBookingResult.unavailable(requiredIds);
    }

    final equipmentById = {
      for (final equipment in salon.equipment) equipment.id: equipment,
    };

    final unavailableEquipment = <String>[];
    for (final equipmentId in requiredIds) {
      final equipment = equipmentById[equipmentId];
      final capacity = _effectiveCapacity(equipment);
      if (capacity <= 0) {
        unavailableEquipment.add(equipment?.name ?? equipmentId);
      }
    }
    if (unavailableEquipment.isNotEmpty) {
      return EquipmentBookingResult.unavailable(unavailableEquipment);
    }

    final servicesById = {for (final item in allServices) item.id: item};

    final overlappingAppointments = appointments.where((appointment) {
      if (appointment.id == excludeAppointmentId) {
        return false;
      }
      if (appointment.salonId != salon.id) {
        return false;
      }
      if (!_blocksEquipment(appointment)) {
        return false;
      }
      if (!appointment.start.isBefore(end)) {
        return false;
      }
      if (!appointment.end.isAfter(start)) {
        return false;
      }
      return true;
    });

    final usageCount = <String, int>{};
    for (final appointment in overlappingAppointments) {
      final serviceWindows = _appointmentServiceWindows(
        appointment: appointment,
        servicesById: servicesById,
      );
      for (final window in serviceWindows) {
        if (!_windowsOverlap(window.start, window.end, start, end)) {
          continue;
        }
        for (final equipmentId in window.service.requiredEquipmentIds) {
          usageCount.update(
            equipmentId,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    final blocking = <String>[];
    for (final equipmentId in requiredIds) {
      final equipment = equipmentById[equipmentId];
      if (equipment == null) {
        blocking.add(equipmentId);
        continue;
      }
      final capacity = _effectiveCapacity(equipment);
      final used = usageCount[equipmentId] ?? 0;
      if (used >= capacity) {
        blocking.add(equipment.name);
      }
    }

    if (blocking.isNotEmpty) {
      return EquipmentBookingResult.unavailable(blocking);
    }

    return EquipmentBookingResult.available();
  }

  static bool _blocksEquipment(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.cancelled:
      case AppointmentStatus.noShow:
        return false;
      case AppointmentStatus.completed:
      case AppointmentStatus.scheduled:
        return true;
    }
  }

  static int _effectiveCapacity(SalonEquipment? equipment) {
    if (equipment == null) {
      return 0;
    }
    if (equipment.quantity <= 0) {
      return 0;
    }
    if (equipment.status != SalonEquipmentStatus.operational) {
      return 0;
    }
    return equipment.quantity;
  }

  static List<_ServiceWindow> _appointmentServiceWindows({
    required Appointment appointment,
    required Map<String, Service> servicesById,
  }) {
    final orderedServices = <Service>[];
    final allocations = appointment.serviceAllocations;
    if (allocations.isNotEmpty) {
      for (final allocation in allocations) {
        if (allocation.serviceId.isEmpty) {
          continue;
        }
        final service = servicesById[allocation.serviceId];
        if (service == null) {
          continue;
        }
        final repetitions = allocation.quantity <= 0 ? 1 : allocation.quantity;
        for (var i = 0; i < repetitions; i++) {
          orderedServices.add(service);
        }
      }
    }
    if (orderedServices.isEmpty) {
      final fallbackService = servicesById[appointment.serviceId];
      if (fallbackService != null) {
        orderedServices.add(fallbackService);
      }
    }
    if (orderedServices.isEmpty) {
      return const <_ServiceWindow>[];
    }
    return _buildServiceTimeline(
      start: appointment.start,
      services: orderedServices,
      limitEnd: appointment.end,
    );
  }

  static List<_ServiceWindow> _buildServiceTimeline({
    required DateTime start,
    required Iterable<Service> services,
    DateTime? limitEnd,
  }) {
    final windows = <_ServiceWindow>[];
    var cursor = start;
    for (final service in services) {
      final duration = service.totalDuration;
      if (duration <= Duration.zero) {
        continue;
      }
      final projectedEnd = cursor.add(duration);
      final end =
          limitEnd != null && projectedEnd.isAfter(limitEnd)
              ? limitEnd
              : projectedEnd;
      if (!end.isAfter(cursor)) {
        cursor = projectedEnd;
        continue;
      }
      windows.add(_ServiceWindow(service: service, start: cursor, end: end));
      cursor = projectedEnd;
      if (limitEnd != null && !cursor.isBefore(limitEnd)) {
        break;
      }
    }
    return windows;
  }

  static bool _windowsOverlap(
    DateTime start,
    DateTime end,
    DateTime otherStart,
    DateTime otherEnd,
  ) {
    return start.isBefore(otherEnd) && end.isAfter(otherStart);
  }
}

class _ServiceWindow {
  const _ServiceWindow({
    required this.service,
    required this.start,
    required this.end,
  });

  final Service service;
  final DateTime start;
  final DateTime end;
}
