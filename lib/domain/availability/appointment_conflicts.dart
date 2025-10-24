import 'package:you_book/domain/entities/appointment.dart';

bool appointmentBlocksAvailability(Appointment appointment) {
  switch (appointment.status) {
    case AppointmentStatus.cancelled:
    case AppointmentStatus.noShow:
      return false;
    case AppointmentStatus.completed:
    case AppointmentStatus.scheduled:
      return true;
  }
}

bool appointmentsOverlap({
  required DateTime start,
  required DateTime end,
  required DateTime otherStart,
  required DateTime otherEnd,
}) {
  return start.isBefore(otherEnd) && end.isAfter(otherStart);
}

bool hasClientBookingConflict({
  required Iterable<Appointment> appointments,
  required String clientId,
  required DateTime start,
  required DateTime end,
  String? excludeAppointmentId,
}) {
  for (final appointment in appointments) {
    if (appointment.clientId != clientId) {
      continue;
    }
    if (excludeAppointmentId != null &&
        appointment.id == excludeAppointmentId) {
      continue;
    }
    if (!appointmentBlocksAvailability(appointment)) {
      continue;
    }
    if (appointmentsOverlap(
      start: appointment.start,
      end: appointment.end,
      otherStart: start,
      otherEnd: end,
    )) {
      return true;
    }
  }
  return false;
}

bool hasStaffBookingConflict({
  required Iterable<Appointment> appointments,
  required String staffId,
  required DateTime start,
  required DateTime end,
  String? excludeAppointmentId,
}) {
  for (final appointment in appointments) {
    if (appointment.staffId != staffId) {
      continue;
    }
    if (excludeAppointmentId != null &&
        appointment.id == excludeAppointmentId) {
      continue;
    }
    if (!appointmentBlocksAvailability(appointment)) {
      continue;
    }
    if (appointmentsOverlap(
      start: appointment.start,
      end: appointment.end,
      otherStart: start,
      otherEnd: end,
    )) {
      return true;
    }
  }
  return false;
}
