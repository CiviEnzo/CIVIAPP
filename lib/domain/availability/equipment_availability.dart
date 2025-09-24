import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';

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
      final existingService = servicesById[appointment.serviceId];
      if (existingService == null) {
        continue;
      }
      for (final equipmentId in existingService.requiredEquipmentIds) {
        usageCount.update(equipmentId, (value) => value + 1, ifAbsent: () => 1);
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
      case AppointmentStatus.confirmed:
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
}
