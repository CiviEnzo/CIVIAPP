import 'package:flutter/foundation.dart';
import 'package:you_book/domain/entities/staff_absence.dart';

enum StaffAbsenceRequestStatus { pending, approved, rejected, cancelled }

extension StaffAbsenceRequestStatusX on StaffAbsenceRequestStatus {
  String get label {
    switch (this) {
      case StaffAbsenceRequestStatus.pending:
        return 'In attesa';
      case StaffAbsenceRequestStatus.approved:
        return 'Approvata';
      case StaffAbsenceRequestStatus.rejected:
        return 'Rifiutata';
      case StaffAbsenceRequestStatus.cancelled:
        return 'Annullata';
    }
  }

  bool get isPending => this == StaffAbsenceRequestStatus.pending;
}

@immutable
class StaffAbsenceRequest {
  const StaffAbsenceRequest({
    required this.id,
    required this.salonId,
    required this.staffId,
    this.userId,
    required this.type,
    required this.start,
    required this.end,
    this.notes,
    this.attachmentUrl,
    this.status = StaffAbsenceRequestStatus.pending,
    this.adminNote,
    this.absenceId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String salonId;
  final String staffId;
  final String? userId;
  final StaffAbsenceType type;
  final DateTime start;
  final DateTime end;
  final String? notes;
  final String? attachmentUrl;
  final StaffAbsenceRequestStatus status;
  final String? adminNote;
  final String? absenceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StaffAbsenceRequest copyWith({
    String? id,
    String? salonId,
    String? staffId,
    Object? userId = _sentinel,
    StaffAbsenceType? type,
    DateTime? start,
    DateTime? end,
    Object? notes = _sentinel,
    Object? attachmentUrl = _sentinel,
    StaffAbsenceRequestStatus? status,
    Object? adminNote = _sentinel,
    Object? absenceId = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffAbsenceRequest(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      staffId: staffId ?? this.staffId,
      userId: identical(userId, _sentinel) ? this.userId : userId as String?,
      type: type ?? this.type,
      start: start ?? this.start,
      end: end ?? this.end,
      notes: identical(notes, _sentinel) ? this.notes : notes as String?,
      attachmentUrl:
          identical(attachmentUrl, _sentinel)
              ? this.attachmentUrl
              : attachmentUrl as String?,
      status: status ?? this.status,
      adminNote:
          identical(adminNote, _sentinel)
              ? this.adminNote
              : adminNote as String?,
      absenceId:
          identical(absenceId, _sentinel)
              ? this.absenceId
              : absenceId as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _sentinel = Object();
