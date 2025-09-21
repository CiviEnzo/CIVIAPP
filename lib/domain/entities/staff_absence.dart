import 'package:flutter/foundation.dart';

enum StaffAbsenceType { sickLeave, vacation, permission }

extension StaffAbsenceTypeX on StaffAbsenceType {
  String get label {
    switch (this) {
      case StaffAbsenceType.sickLeave:
        return 'Malattia';
      case StaffAbsenceType.vacation:
        return 'Ferie';
      case StaffAbsenceType.permission:
        return 'Permesso';
    }
  }
}

@immutable
class StaffAbsence {
  const StaffAbsence({
    required this.id,
    required this.salonId,
    required this.staffId,
    required this.type,
    required this.start,
    required this.end,
    this.notes,
  });

  final String id;
  final String salonId;
  final String staffId;
  final StaffAbsenceType type;
  final DateTime start;
  final DateTime end;
  final String? notes;

  bool get isSingleDay =>
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;

  bool get isAllDay =>
      start.hour == 0 &&
      start.minute == 0 &&
      start.second == 0 &&
      end.hour == 23 &&
      end.minute == 59;

  StaffAbsence copyWith({
    String? id,
    String? salonId,
    String? staffId,
    StaffAbsenceType? type,
    DateTime? start,
    DateTime? end,
    String? notes,
  }) {
    return StaffAbsence(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      staffId: staffId ?? this.staffId,
      type: type ?? this.type,
      start: start ?? this.start,
      end: end ?? this.end,
      notes: notes ?? this.notes,
    );
  }
}
