import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_absence.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/appointment_anomaly.dart';

void main() {
  Appointment buildAppointment({
    DateTime? start,
    DateTime? end,
    AppointmentStatus status = AppointmentStatus.scheduled,
  }) {
    final appointmentStart = start ?? DateTime(2026, 2, 17, 10);
    final appointmentEnd =
        end ?? appointmentStart.add(const Duration(minutes: 30));
    return Appointment(
      id: 'appt-1',
      salonId: 'salon-1',
      clientId: 'client-1',
      staffId: 'staff-1',
      serviceIds: const <String>['service-1'],
      start: appointmentStart,
      end: appointmentEnd,
      status: status,
    );
  }

  Shift buildShift({
    DateTime? start,
    DateTime? end,
    DateTime? breakStart,
    DateTime? breakEnd,
  }) {
    return Shift(
      id: 'shift-1',
      salonId: 'salon-1',
      staffId: 'staff-1',
      start: start ?? DateTime(2026, 2, 17, 9),
      end: end ?? DateTime(2026, 2, 17, 18),
      breakStart: breakStart,
      breakEnd: breakEnd,
    );
  }

  StaffAbsence buildAbsence({DateTime? start, DateTime? end}) {
    return StaffAbsence(
      id: 'absence-1',
      salonId: 'salon-1',
      staffId: 'staff-1',
      type: StaffAbsenceType.vacation,
      start: start ?? DateTime(2026, 2, 17, 10),
      end: end ?? DateTime(2026, 2, 17, 11),
    );
  }

  test('calculateAppointmentAnomalies reports positional warnings', () {
    final appointment = buildAppointment();
    final anomalies = calculateAppointmentAnomalies(
      appointment: appointment,
      shifts: <Shift>[
        buildShift(
          breakStart: DateTime(2026, 2, 17, 10, 15),
          breakEnd: DateTime(2026, 2, 17, 10, 45),
        ),
      ],
      absences: <StaffAbsence>[buildAbsence()],
      now: DateTime(2026, 2, 18, 12),
    );

    expect(anomalies, contains(AppointmentAnomalyType.noShift));
    expect(anomalies, contains(AppointmentAnomalyType.breakOverlap));
    expect(anomalies, contains(AppointmentAnomalyType.absenceOverlap));
    expect(anomalies, contains(AppointmentAnomalyType.outdatedStatus));
    expect(
      confirmableAppointmentAnomalies(anomalies),
      isNot(contains(AppointmentAnomalyType.outdatedStatus)),
    );
  });

  test('calculateAppointmentAnomalies stays clean on covered slot', () {
    final anomalies = calculateAppointmentAnomalies(
      appointment: buildAppointment(),
      shifts: <Shift>[buildShift()],
      absences: const <StaffAbsence>[],
      now: DateTime(2026, 2, 17, 9),
    );

    expect(anomalies, isEmpty);
  });
}
