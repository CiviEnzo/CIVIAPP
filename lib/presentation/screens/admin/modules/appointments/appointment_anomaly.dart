import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_absence.dart';

enum AppointmentAnomalyType {
  noShift,
  breakOverlap,
  absenceOverlap,
  outdatedStatus,
}

extension AppointmentAnomalyTypeX on AppointmentAnomalyType {
  String get label {
    switch (this) {
      case AppointmentAnomalyType.noShift:
        return 'Orario senza turno';
      case AppointmentAnomalyType.breakOverlap:
        return 'Sovrapposto a pausa';
      case AppointmentAnomalyType.absenceOverlap:
        return 'Operatore assente';
      case AppointmentAnomalyType.outdatedStatus:
        return 'Stato da aggiornare';
    }
  }

  String get description {
    switch (this) {
      case AppointmentAnomalyType.noShift:
        return 'Appuntamento pianificato fuori da un turno attivo.';
      case AppointmentAnomalyType.breakOverlap:
        return 'L\'appuntamento ricade durante una pausa programmata.';
      case AppointmentAnomalyType.absenceOverlap:
        return 'Operatore assente (ferie, permesso o malattia).';
      case AppointmentAnomalyType.outdatedStatus:
        return 'Appuntamento nel passato con stato "Programmato".';
    }
  }

  IconData get icon => Icons.warning_amber_rounded;

  bool get requiresConfirmation {
    switch (this) {
      case AppointmentAnomalyType.noShift:
      case AppointmentAnomalyType.breakOverlap:
      case AppointmentAnomalyType.absenceOverlap:
        return true;
      case AppointmentAnomalyType.outdatedStatus:
        return false;
    }
  }
}

Set<AppointmentAnomalyType> calculateAppointmentAnomalies({
  required Appointment appointment,
  required Iterable<Shift> shifts,
  required Iterable<StaffAbsence> absences,
  required DateTime now,
  bool includeOutdatedStatus = true,
}) {
  final issues = <AppointmentAnomalyType>{};
  final relevantShifts =
      shifts.where((shift) {
          if (shift.staffId != appointment.staffId) {
            return false;
          }
          if (shift.salonId != appointment.salonId) {
            return false;
          }
          return shift.end.isAfter(appointment.start) &&
              shift.start.isBefore(appointment.end);
        }).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  final coveringShift = relevantShifts.firstWhereOrNull(
    (shift) =>
        !shift.start.isAfter(appointment.start) &&
        !shift.end.isBefore(appointment.end),
  );
  if (coveringShift == null) {
    issues.add(AppointmentAnomalyType.noShift);
  } else if (_overlapsBreak(appointment, coveringShift)) {
    issues
      ..add(AppointmentAnomalyType.breakOverlap)
      ..add(AppointmentAnomalyType.noShift);
  }

  final hasAbsenceOverlap = absences.any((absence) {
    if (absence.staffId != appointment.staffId) {
      return false;
    }
    if (absence.salonId != appointment.salonId) {
      return false;
    }
    return _rangesOverlap(
      appointment.start,
      appointment.end,
      absence.start,
      absence.end,
    );
  });
  if (hasAbsenceOverlap) {
    issues
      ..add(AppointmentAnomalyType.absenceOverlap)
      ..add(AppointmentAnomalyType.noShift);
  }

  if (includeOutdatedStatus &&
      appointment.end.isBefore(now) &&
      appointment.status == AppointmentStatus.scheduled) {
    issues.add(AppointmentAnomalyType.outdatedStatus);
  }

  return issues;
}

Set<AppointmentAnomalyType> confirmableAppointmentAnomalies(
  Iterable<AppointmentAnomalyType> anomalies,
) {
  return anomalies.where((anomaly) => anomaly.requiresConfirmation).toSet();
}

List<StaffAbsence> mergeStaffAbsenceLists({
  required Iterable<StaffAbsence> staffAbsences,
  required Iterable<StaffAbsence> publicStaffAbsences,
}) {
  final merged = <String, StaffAbsence>{};
  for (final absence in publicStaffAbsences) {
    merged[absence.id] = absence;
  }
  for (final absence in staffAbsences) {
    merged[absence.id] = absence;
  }
  return merged.values.toList(growable: false);
}

Future<bool> showAppointmentWarningConfirmationDialog({
  required BuildContext context,
  required Iterable<AppointmentAnomalyType> anomalies,
  String title = 'Conferma posizionamento',
  String message =
      'Questo slot slot orario non è disponibile. Vuoi continuare comunque?',
}) async {
  final confirmable = confirmableAppointmentAnomalies(anomalies);
  if (confirmable.isEmpty) {
    return true;
  }
  final sorted =
      confirmable.toList()
        ..sort((first, second) => first.index.compareTo(second.index));
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final colorScheme = theme.colorScheme;
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              ...sorted.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          issue.icon,
                          size: 18,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              issue.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              issue.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Conferma'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

bool _overlapsBreak(Appointment appointment, Shift shift) {
  final breakStart = shift.breakStart;
  final breakEnd = shift.breakEnd;
  if (breakStart == null || breakEnd == null) {
    return false;
  }
  return _rangesOverlap(
    appointment.start,
    appointment.end,
    breakStart,
    breakEnd,
  );
}

bool _rangesOverlap(
  DateTime start,
  DateTime end,
  DateTime otherStart,
  DateTime otherEnd,
) {
  return start.isBefore(otherEnd) && end.isAfter(otherStart);
}
