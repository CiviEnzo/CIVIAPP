import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/availability/appointment_conflicts.dart';
import 'package:you_book/domain/availability/equipment_availability.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/appointment_anomaly.dart';

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
  final existingAppointments =
      data.appointments.isNotEmpty
          ? data.appointments
          : (fallbackAppointments ?? const <Appointment>[]);
  final allServices =
      data.services.isNotEmpty ? data.services : fallbackServices;
  final allSalons = data.salons.isNotEmpty ? data.salons : fallbackSalons;
  final nowReference = DateTime.now();
  final expressPlaceholders =
      data.lastMinuteSlots
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
              serviceIds:
                  slot.serviceId != null && slot.serviceId!.isNotEmpty
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
    messenger.showAppSnackBar(
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
    messenger.showAppSnackBar(
      const SnackBar(
        content: Text(
          'Impossibile salvare: il cliente ha già un appuntamento in quel periodo',
        ),
      ),
    );
    return false;
  }
  final servicesById = {for (final service in allServices) service.id: service};
  final serviceWindows =
      EquipmentAvailabilityChecker.serviceWindowsForAppointment(
        appointment: appointment,
        servicesById: servicesById,
        startOverride: appointment.start,
        endOverride: appointment.end,
      );
  if (serviceWindows.isEmpty) {
    messenger.showAppSnackBar(
      const SnackBar(content: Text('Servizio non valido.')),
    );
    return false;
  }
  final salon = allSalons.firstWhereOrNull(
    (item) => item.id == appointment.salonId,
  );
  final blockingEquipment = <String>{};
  for (final window in serviceWindows) {
    final service = window.service;
    if (service.requiredEquipmentIds.isEmpty) {
      continue;
    }
    final equipmentCheck = EquipmentAvailabilityChecker.check(
      salon: salon,
      service: service,
      allServices: allServices,
      appointments: combinedAppointments,
      start: window.start,
      end: window.end,
      excludeAppointmentId: appointment.id,
    );
    if (equipmentCheck.hasConflicts) {
      blockingEquipment.addAll(equipmentCheck.blockingEquipment);
    }
  }
  if (blockingEquipment.isNotEmpty) {
    final equipmentLabel = blockingEquipment.join(', ');
    final message =
        equipmentLabel.isEmpty
            ? 'Macchinario non disponibile per questo orario.'
            : 'Macchinario non disponibile per questo orario: $equipmentLabel.';
    messenger.showAppSnackBar(
      SnackBar(content: Text('$message Scegli un altro slot.')),
    );
    return false;
  }
  final warningAnomalies = calculateAppointmentAnomalies(
    appointment: appointment,
    shifts: data.shifts,
    absences: mergeStaffAbsenceLists(
      staffAbsences: data.staffAbsences,
      publicStaffAbsences: data.publicStaffAbsences,
    ),
    now: DateTime.now(),
  );
  final shouldContinue = await showAppointmentWarningConfirmationDialog(
    context: context,
    anomalies: warningAnomalies,
  );
  if (!shouldContinue) {
    return false;
  }
  try {
    await ref.read(appDataProvider.notifier).upsertAppointment(appointment);
    return true;
  } on StateError catch (error) {
    messenger.showAppSnackBar(SnackBar(content: Text(error.message)));
    return false;
  } catch (error) {
    messenger.showAppSnackBar(
      SnackBar(content: Text('Errore durante il salvataggio: $error')),
    );
    return false;
  }
}
