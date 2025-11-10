import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/availability/appointment_conflicts.dart';
import 'package:you_book/domain/availability/equipment_availability.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';

Future<bool> validateAndSaveAppointment({
  required BuildContext context,
  required WidgetRef ref,
  required Appointment appointment,
  required List<Service> fallbackServices,
  required List<Salon> fallbackSalons,
  List<Appointment>? fallbackAppointments,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final data = ref.read(appDataProvider);
  final existingAppointments = data.appointments.isNotEmpty
      ? data.appointments
      : (fallbackAppointments ?? const <Appointment>[]);
  final allServices =
      data.services.isNotEmpty ? data.services : fallbackServices;
  final allSalons = data.salons.isNotEmpty ? data.salons : fallbackSalons;
  final nowReference = DateTime.now();
  final expressPlaceholders = data.lastMinuteSlots
      .where((slot) {
        if (slot.salonId != appointment.salonId) {
          return false;
        }
        if (slot.operatorId != appointment.staffId) {
          return false;
        }
        if (!slot.isAvailable) {
          return false;
        }
        if (!slot.end.isAfter(nowReference)) {
          return false;
        }
        return true;
      })
      .map(
        (slot) => Appointment(
          id: 'last-minute-${slot.id}',
          salonId: slot.salonId,
          clientId: 'last-minute-${slot.id}',
          staffId: slot.operatorId ?? appointment.staffId,
          serviceIds: slot.serviceId != null && slot.serviceId!.isNotEmpty
              ? <String>[slot.serviceId!]
              : const <String>[],
          start: slot.start,
          end: slot.end,
          status: AppointmentStatus.scheduled,
          roomId: slot.roomId,
        ),
      )
      .toList();
  final combinedAppointments = <Appointment>[
    ...existingAppointments,
    ...expressPlaceholders,
  ];
  final hasStaffConflict = hasStaffBookingConflict(
    appointments: combinedAppointments,
    staffId: appointment.staffId,
    start: appointment.start,
    end: appointment.end,
    excludeAppointmentId: appointment.id,
  );
  if (hasStaffConflict) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Impossibile salvare: operatore già occupato in quel periodo',
        ),
      ),
    );
    return false;
  }
  final hasClientConflict = hasClientBookingConflict(
    appointments: existingAppointments,
    clientId: appointment.clientId,
    start: appointment.start,
    end: appointment.end,
    excludeAppointmentId: appointment.id,
  );
  if (hasClientConflict) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Impossibile salvare: il cliente ha già un appuntamento in quel periodo',
        ),
      ),
    );
    return false;
  }
  final appointmentServices = appointment.serviceIds
      .map((id) => allServices.firstWhereOrNull((service) => service.id == id))
      .whereType<Service>()
      .toList(growable: false);
  if (appointmentServices.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Servizio non valido.')),
    );
    return false;
  }
  final salon = allSalons.firstWhereOrNull(
    (item) => item.id == appointment.salonId,
  );
  final blockingEquipment = <String>{};
  var equipmentStart = appointment.start;
  for (final service in appointmentServices) {
    final equipmentEnd = equipmentStart.add(service.totalDuration);
    final equipmentCheck = EquipmentAvailabilityChecker.check(
      salon: salon,
      service: service,
      allServices: allServices,
      appointments: combinedAppointments,
      start: equipmentStart,
      end: equipmentEnd,
      excludeAppointmentId: appointment.id,
    );
    if (equipmentCheck.hasConflicts) {
      blockingEquipment.addAll(equipmentCheck.blockingEquipment);
    }
    equipmentStart = equipmentEnd;
  }
  if (blockingEquipment.isNotEmpty) {
    final equipmentLabel = blockingEquipment.join(', ');
    final message = equipmentLabel.isEmpty
        ? 'Macchinario non disponibile per questo orario.'
        : 'Macchinario non disponibile per questo orario: $equipmentLabel.';
    messenger.showSnackBar(
      SnackBar(content: Text('$message Scegli un altro slot.')),
    );
    return false;
  }
  try {
    await ref.read(appDataProvider.notifier).upsertAppointment(appointment);
    return true;
  } on StateError catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
    return false;
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Errore durante il salvataggio: $error')),
    );
    return false;
  }
}
