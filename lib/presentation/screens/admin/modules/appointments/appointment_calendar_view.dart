import 'dart:async';
import 'dart:math';

import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/availability/appointment_conflicts.dart';
import 'package:you_book/domain/availability/equipment_availability.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/appointment_day_checklist.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/last_minute_slot.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_absence.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/staff_role.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/appointment_anomaly.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const double _kStaffColumnWidth = 220.0;
const double _kStaffHeaderHeight = 48.0;

final DateFormat _calendarWeekdayFormat = DateFormat('EEEE', 'it_IT');
final DateFormat _calendarDayNumberFormat = DateFormat('dd', 'it_IT');
final DateFormat _calendarMonthAbbrevFormat = DateFormat('MMM', 'it_IT');

String _formatCalendarDayLabel(DateTime date) {
  final weekday = _capitalizeItalianWord(_calendarWeekdayFormat.format(date));
  final dayNumber = _calendarDayNumberFormat.format(date);
  final month = _capitalizeItalianWord(_calendarMonthAbbrevFormat.format(date));
  return '$weekday $dayNumber $month';
}

String _capitalizeItalianWord(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}

String _firstNameOnly(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) {
    return fullName;
  }
  final parts = trimmed.split(RegExp(r'\s+'));
  return parts.isEmpty ? fullName : parts.first;
}

bool _hasAllowedRole(StaffMember staff, List<String> allowedRoles) {
  if (allowedRoles.isEmpty) {
    return true;
  }
  return staff.roleIds.any((roleId) => allowedRoles.contains(roleId));
}

enum AppointmentCalendarScope { day, week }

enum AppointmentWeekLayoutMode { detailed, compact, operatorBoard }

String _appointmentStatusLabel(AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.scheduled:
      return 'Programmato';
    case AppointmentStatus.completed:
      return 'Completato';
    case AppointmentStatus.cancelled:
      return 'Annullato';
    case AppointmentStatus.noShow:
      return 'No show';
  }
}

class AppointmentRescheduleRequest {
  AppointmentRescheduleRequest({
    required this.appointment,
    required this.newStart,
    required this.newEnd,
    this.newStaffId,
    this.newRoomId,
  });

  final Appointment appointment;
  final DateTime newStart;
  final DateTime newEnd;
  final String? newStaffId;
  final String? newRoomId;
}

typedef AppointmentRescheduleCallback =
    Future<void> Function(AppointmentRescheduleRequest request);
typedef AppointmentTapCallback = void Function(Appointment appointment);

class AppointmentSlotSelection {
  AppointmentSlotSelection({
    required this.start,
    required this.end,
    required this.staffId,
  });

  final DateTime start;
  final DateTime end;
  final String staffId;
}

typedef AppointmentSlotSelectionCallback =
    void Function(AppointmentSlotSelection selection);

class AppointmentCalendarView extends StatefulWidget {
  const AppointmentCalendarView({
    super.key,
    required this.anchorDate,
    required this.scope,
    required this.appointments,
    required this.allAppointments,
    required this.lastMinutePlaceholders,
    required this.staff,
    required this.clients,
    required this.clientsWithOutstandingPayments,
    required this.services,
    required this.serviceCategories,
    required this.shifts,
    required this.absences,
    required this.roles,
    this.schedule,
    required this.visibleWeekdays,
    required this.roomsById,
    required this.salonsById,
    required this.lockedAppointmentReasons,
    required this.dayChecklists,
    required this.onReschedule,
    required this.onEdit,
    required this.onCreate,
    required this.anomalies,
    required this.statusColor,
    this.weekLayout = AppointmentWeekLayoutMode.detailed,
    this.slotMinutes = 15,
    this.interactionSlotMinutes = 15,
    this.onTapLastMinuteSlot,
    required this.lastMinuteSlots,
    this.onAddChecklistItem,
    this.onToggleChecklistItem,
    this.onRenameChecklistItem,
    this.onDeleteChecklistItem,
    this.onCreateShift,
    this.onEditShift,
    this.onDeleteShift,
    this.onCreateAbsence,
    this.onEditAbsence,
    this.onDeleteAbsence,
  });
  final DateTime anchorDate;
  final AppointmentCalendarScope scope;
  final List<Appointment> appointments;
  final List<Appointment> allAppointments;
  final List<Appointment> lastMinutePlaceholders;
  final List<LastMinuteSlot> lastMinuteSlots;
  final List<StaffMember> staff;
  final List<StaffRole> roles;
  final List<Client> clients;
  final Set<String> clientsWithOutstandingPayments;
  final List<Service> services;
  final List<ServiceCategory> serviceCategories;
  final List<Shift> shifts;
  final List<StaffAbsence> absences;
  final List<SalonDailySchedule>? schedule;
  final Set<int> visibleWeekdays;
  final Map<String, String> roomsById;
  final Map<String, Salon> salonsById;
  final Map<String, String> lockedAppointmentReasons;
  final Map<DateTime, AppointmentDayChecklist> dayChecklists;
  final AppointmentRescheduleCallback onReschedule;
  final AppointmentTapCallback onEdit;
  final AppointmentSlotSelectionCallback onCreate;
  final Map<String, Set<AppointmentAnomalyType>> anomalies;
  final Color Function(AppointmentStatus status) statusColor;
  final AppointmentWeekLayoutMode weekLayout;
  final int slotMinutes;
  final int interactionSlotMinutes;
  final Future<void> Function(LastMinuteSlot slot)? onTapLastMinuteSlot;
  final Future<void> Function(DateTime day, String label)? onAddChecklistItem;
  final Future<void> Function(
    String checklistId,
    String itemId,
    bool isCompleted,
  )?
  onToggleChecklistItem;
  final Future<void> Function(String checklistId, String itemId, String label)?
  onRenameChecklistItem;
  final Future<void> Function(String checklistId, String itemId)?
  onDeleteChecklistItem;
  final Future<void> Function(StaffMember staff, DateTime day)? onCreateShift;
  final Future<void> Function(Shift shift)? onEditShift;
  final Future<void> Function(Shift shift)? onDeleteShift;
  final Future<void> Function(StaffMember staff, DateTime day)? onCreateAbsence;
  final Future<void> Function(StaffAbsence absence)? onEditAbsence;
  final Future<void> Function(StaffAbsence absence)? onDeleteAbsence;

  @override
  State<AppointmentCalendarView> createState() =>
      _AppointmentCalendarViewState();
}

enum _StaffDayActionType {
  addShift,
  editShift,
  deleteShift,
  addAbsence,
  editAbsence,
  deleteAbsence,
}

typedef _StaffDayManagementResult =
    ({_StaffDayActionType type, Shift? shift, StaffAbsence? absence});

Future<void> _handleStaffDayManagement(
  BuildContext context, {
  required StaffMember staff,
  required DateTime day,
  required List<Shift> shifts,
  required List<StaffAbsence> absences,
  required Map<String, String> roomsById,
  Future<void> Function(StaffMember staff, DateTime day)? onCreateShift,
  Future<void> Function(Shift shift)? onEditShift,
  Future<void> Function(Shift shift)? onDeleteShift,
  Future<void> Function(StaffMember staff, DateTime day)? onCreateAbsence,
  Future<void> Function(StaffAbsence absence)? onEditAbsence,
  Future<void> Function(StaffAbsence absence)? onDeleteAbsence,
}) async {
  final canCreate = onCreateShift != null;
  final canEdit = onEditShift != null;
  final canDelete = onDeleteShift != null;
  final canCreateAbs = onCreateAbsence != null;
  final canEditAbs = onEditAbsence != null;
  final canDeleteAbs = onDeleteAbsence != null;
  if (!canCreate &&
      !canEdit &&
      !canDelete &&
      !canCreateAbs &&
      !canEditAbs &&
      !canDeleteAbs) {
    return;
  }
  if (!canEdit &&
      !canDelete &&
      !canEditAbs &&
      !canDeleteAbs &&
      shifts.isEmpty &&
      absences.isEmpty) {
    return;
  }

  final result = await _showStaffDayManagementDialog(
    context,
    staff: staff,
    day: day,
    shifts: shifts,
    absences: absences,
    roomsById: roomsById,
    canCreate: canCreate,
    canEdit: canEdit,
    canDelete: canDelete,
    canCreateAbsence: canCreateAbs,
    canEditAbsence: canEditAbs,
    canDeleteAbsence: canDeleteAbs,
  );
  if (result == null) {
    return;
  }

  switch (result.type) {
    case _StaffDayActionType.addShift:
      if (onCreateShift != null) {
        await onCreateShift(staff, day);
      }
      break;
    case _StaffDayActionType.editShift:
      final shift = result.shift;
      if (shift != null && onEditShift != null) {
        await onEditShift(shift);
      }
      break;
    case _StaffDayActionType.deleteShift:
      final shift = result.shift;
      if (shift != null && onDeleteShift != null) {
        await onDeleteShift(shift);
      }
      break;
    case _StaffDayActionType.addAbsence:
      if (onCreateAbsence != null) {
        await onCreateAbsence(staff, day);
      }
      break;
    case _StaffDayActionType.editAbsence:
      final absence = result.absence;
      if (absence != null && onEditAbsence != null) {
        await onEditAbsence(absence);
      }
      break;
    case _StaffDayActionType.deleteAbsence:
      final absence = result.absence;
      if (absence != null && onDeleteAbsence != null) {
        await onDeleteAbsence(absence);
      }
      break;
  }
}

Future<_StaffDayManagementResult?> _showStaffDayManagementDialog(
  BuildContext context, {
  required StaffMember staff,
  required DateTime day,
  required List<Shift> shifts,
  required List<StaffAbsence> absences,
  required Map<String, String> roomsById,
  required bool canCreate,
  required bool canEdit,
  required bool canDelete,
  required bool canCreateAbsence,
  required bool canEditAbsence,
  required bool canDeleteAbsence,
}) {
  final timeFormat = DateFormat('HH:mm', 'it_IT');
  final dateLabel = _formatCalendarDayLabel(day);
  final sortedShifts = shifts
      .sortedBy((shift) => shift.start)
      .toList(growable: false);
  final sortedAbsences = absences
      .sortedBy((absence) => absence.start)
      .toList(growable: false);

  return showDialog<_StaffDayManagementResult>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final titleTextStyle = theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      );
      final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );

      final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');

      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(staff.fullName, style: titleTextStyle),
            const SizedBox(height: 4),
            Text(dateLabel, style: subtitleStyle),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Turni attivi',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (sortedShifts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      canCreate
                          ? 'Nessun turno pianificato per questa giornata.'
                          : 'Non ci sono turni visibili.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var index = 0;
                        index < sortedShifts.length;
                        index++
                      ) ...[
                        if (index != 0) const SizedBox(height: 12),
                        _ShiftTileActionRow(
                          shift: sortedShifts[index],
                          timeFormat: timeFormat,
                          roomsById: roomsById,
                          canEdit: canEdit,
                          canDelete: canDelete,
                          onEdit:
                              canEdit
                                  ? () => Navigator.of(dialogContext).pop((
                                    type: _StaffDayActionType.editShift,
                                    shift: sortedShifts[index],
                                    absence: null,
                                  ))
                                  : null,
                          onDelete:
                              canDelete
                                  ? () => Navigator.of(dialogContext).pop((
                                    type: _StaffDayActionType.deleteShift,
                                    shift: sortedShifts[index],
                                    absence: null,
                                  ))
                                  : null,
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 24),
                Text(
                  'Assenze',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (sortedAbsences.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      canCreateAbsence
                          ? 'Nessuna assenza registrata in questa data.'
                          : 'Non ci sono assenze visibili.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (
                        var index = 0;
                        index < sortedAbsences.length;
                        index++
                      ) ...[
                        if (index != 0) const SizedBox(height: 12),
                        _AbsenceTileActionRow(
                          absence: sortedAbsences[index],
                          dateFormat: dateFormat,
                          timeFormat: timeFormat,
                          canEdit: canEditAbsence,
                          canDelete: canDeleteAbsence,
                          onEdit:
                              canEditAbsence
                                  ? () => Navigator.of(dialogContext).pop((
                                    type: _StaffDayActionType.editAbsence,
                                    shift: null,
                                    absence: sortedAbsences[index],
                                  ))
                                  : null,
                          onDelete:
                              canDeleteAbsence
                                  ? () => Navigator.of(dialogContext).pop((
                                    type: _StaffDayActionType.deleteAbsence,
                                    shift: null,
                                    absence: sortedAbsences[index],
                                  ))
                                  : null,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Chiudi'),
          ),
          if (canCreateAbsence)
            FilledButton.tonalIcon(
              onPressed:
                  () => Navigator.of(dialogContext).pop((
                    type: _StaffDayActionType.addAbsence,
                    shift: null,
                    absence: null,
                  )),
              icon: const Icon(Icons.event_busy_rounded),
              label: const Text('Nuova assenza'),
            ),
          if (canCreate)
            FilledButton.icon(
              onPressed:
                  () => Navigator.of(dialogContext).pop((
                    type: _StaffDayActionType.addShift,
                    shift: null,
                    absence: null,
                  )),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuovo turno'),
            ),
        ],
      );
    },
  );
}

class _ShiftTileActionRow extends StatelessWidget {
  const _ShiftTileActionRow({
    required this.shift,
    required this.timeFormat,
    required this.roomsById,
    required this.canEdit,
    required this.canDelete,
    this.onEdit,
    this.onDelete,
  });

  final Shift shift;
  final DateFormat timeFormat;
  final Map<String, String> roomsById;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomName = shift.roomId != null ? roomsById[shift.roomId] : null;
    final hasBreak =
        shift.breakStart != null &&
        shift.breakEnd != null &&
        shift.breakEnd!.isAfter(shift.breakStart!);
    final details = <String>[];
    if (roomName != null && roomName.isNotEmpty) {
      details.add('Cabina: $roomName');
    }
    if (hasBreak) {
      details.add(
        'Pausa ${timeFormat.format(shift.breakStart!)} - ${timeFormat.format(shift.breakEnd!)}',
      );
    }
    if (shift.notes != null && shift.notes!.trim().isNotEmpty) {
      details.add(shift.notes!.trim());
    }
    if (shift.seriesId != null) {
      details.add('Parte di una serie');
    }

    final tooltipLines = <String>[
      '${timeFormat.format(shift.start)} - ${timeFormat.format(shift.end)}',
      if (roomName != null && roomName.isNotEmpty) 'Cabina: $roomName',
      if (hasBreak)
        'Pausa: ${timeFormat.format(shift.breakStart!)} - ${timeFormat.format(shift.breakEnd!)}',
      if (shift.notes != null && shift.notes!.trim().isNotEmpty)
        'Note: ${shift.notes!.trim()}',
      if (shift.seriesId != null) 'Turno ricorrente',
    ];

    return Tooltip(
      message: tooltipLines.join('\n'),
      waitDuration: const Duration(milliseconds: 250),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${timeFormat.format(shift.start)} - ${timeFormat.format(shift.end)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        details.join(' • '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Modifica turno',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                ),
              if (canDelete)
                IconButton(
                  tooltip: 'Elimina turno',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbsenceTileActionRow extends StatelessWidget {
  const _AbsenceTileActionRow({
    required this.absence,
    required this.dateFormat,
    required this.timeFormat,
    required this.canEdit,
    required this.canDelete,
    this.onEdit,
    this.onDelete,
  });

  final StaffAbsence absence;
  final DateFormat dateFormat;
  final DateFormat timeFormat;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  IconData _iconForType(StaffAbsenceType type) {
    switch (type) {
      case StaffAbsenceType.vacation:
        return Icons.beach_access_rounded;
      case StaffAbsenceType.permission:
        return Icons.event_available_rounded;
      case StaffAbsenceType.sickLeave:
        return Icons.local_hospital_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAllDay = absence.isAllDay;
    final isSingleDay = absence.isSingleDay;
    final primaryLabel =
        isSingleDay
            ? dateFormat.format(absence.start)
            : '${dateFormat.format(absence.start)} → ${dateFormat.format(absence.end)}';
    final timeLabel =
        isAllDay
            ? 'Intera giornata'
            : '${timeFormat.format(absence.start)} - ${timeFormat.format(absence.end)}';
    final notes = absence.notes?.trim();

    final tooltipLines = <String>[
      absence.type.label,
      primaryLabel,
      timeLabel,
      if (notes != null && notes.isNotEmpty) 'Note: $notes',
    ];

    return Tooltip(
      message: tooltipLines.join('\n'),
      waitDuration: const Duration(milliseconds: 250),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForType(absence.type),
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      absence.type.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      primaryLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (!isAllDay)
                      Text(
                        timeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Modifica assenza',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_note_rounded),
                ),
              if (canDelete)
                IconButton(
                  tooltip: 'Elimina assenza',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffHeaderButton extends StatelessWidget {
  const _StaffHeaderButton({
    required this.child,
    this.onPressed,
    this.tooltip,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || onPressed == null) {
      return child;
    }
    Widget content = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: child,
      ),
    );
    final tooltipMessage = tooltip?.trim();
    if (tooltipMessage != null && tooltipMessage.isNotEmpty) {
      content = Tooltip(
        message: tooltipMessage,
        waitDuration: const Duration(milliseconds: 250),
        child: content,
      );
    }
    return content;
  }
}

class _AppointmentCalendarViewState extends State<AppointmentCalendarView> {
  static const _slotExtent = 84.0;
  static const _timeScaleExtent = 74.0;

  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  bool _isSynchronizing = false;
  late final DateTime _initialScrollDate;
  bool _didAutoScrollToInitialDay = false;

  @override
  void initState() {
    super.initState();
    _horizontalHeaderController.addListener(_syncFromHeader);
    _horizontalBodyController.addListener(_syncFromBody);
    _initialScrollDate = DateUtils.dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _horizontalHeaderController
      ..removeListener(_syncFromHeader)
      ..dispose();
    _horizontalBodyController
      ..removeListener(_syncFromBody)
      ..dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _syncFromHeader() {
    if (_isSynchronizing) {
      return;
    }
    _isSynchronizing = true;
    _horizontalBodyController.jumpTo(_horizontalHeaderController.offset);
    _isSynchronizing = false;
  }

  void _syncFromBody() {
    if (_isSynchronizing) {
      return;
    }
    _isSynchronizing = true;
    _horizontalHeaderController.jumpTo(_horizontalBodyController.offset);
    _isSynchronizing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.staff.isEmpty) {
      return const Center(
        child: Text(
          'Aggiungi membri dello staff per pianificare appuntamenti.',
        ),
      );
    }
    final clientsById = {
      for (final client in widget.clients) client.id: client,
    };
    final servicesById = {
      for (final service in widget.services) service.id: service,
    };
    final categoriesById = {
      for (final category in widget.serviceCategories) category.id: category,
    };
    final categoriesByName = <String, ServiceCategory>{};
    for (final category in widget.serviceCategories) {
      final normalized = category.name.trim().toLowerCase();
      if (normalized.isNotEmpty) {
        categoriesByName[normalized] = category;
      }
    }
    switch (widget.scope) {
      case AppointmentCalendarScope.day:
        return _DaySchedule(
          anchorDate: widget.anchorDate,
          appointments: widget.appointments,
          allAppointments: widget.allAppointments,
          lastMinutePlaceholders: widget.lastMinutePlaceholders,
          lastMinuteSlots: widget.lastMinuteSlots,
          shifts: widget.shifts,
          absences: widget.absences,
          schedule: widget.schedule,
          staff: widget.staff,
          clientsWithOutstandingPayments: widget.clientsWithOutstandingPayments,
          clientsById: clientsById,
          servicesById: servicesById,
          categoriesById: categoriesById,
          categoriesByName: categoriesByName,
          roomsById: widget.roomsById,
          statusColor: widget.statusColor,
          salonsById: widget.salonsById,
          lockedAppointmentReasons: widget.lockedAppointmentReasons,
          dayChecklists: widget.dayChecklists,
          onReschedule: widget.onReschedule,
          onEdit: widget.onEdit,
          onCreate: widget.onCreate,
          onTapLastMinuteSlot: widget.onTapLastMinuteSlot,
          anomalies: widget.anomalies,
          horizontalHeaderController: _horizontalHeaderController,
          horizontalBodyController: _horizontalBodyController,
          verticalController: _verticalController,
          slotMinutes: widget.slotMinutes,
          interactionSlotMinutes: widget.interactionSlotMinutes,
          onAddChecklistItem: widget.onAddChecklistItem,
          onToggleChecklistItem: widget.onToggleChecklistItem,
          onRenameChecklistItem: widget.onRenameChecklistItem,
          onDeleteChecklistItem: widget.onDeleteChecklistItem,
          onCreateShift: widget.onCreateShift,
          onEditShift: widget.onEditShift,
          onDeleteShift: widget.onDeleteShift,
          onCreateAbsence: widget.onCreateAbsence,
          onEditAbsence: widget.onEditAbsence,
          onDeleteAbsence: widget.onDeleteAbsence,
        );
      case AppointmentCalendarScope.week:
        return _WeekSchedule(
          anchorDate: widget.anchorDate,
          appointments: widget.appointments,
          allAppointments: widget.allAppointments,
          lastMinutePlaceholders: widget.lastMinutePlaceholders,
          lastMinuteSlots: widget.lastMinuteSlots,
          shifts: widget.shifts,
          absences: widget.absences,
          schedule: widget.schedule,
          visibleWeekdays: widget.visibleWeekdays,
          staff: widget.staff,
          roles: widget.roles,
          clientsWithOutstandingPayments: widget.clientsWithOutstandingPayments,
          clientsById: clientsById,
          servicesById: servicesById,
          categoriesById: categoriesById,
          categoriesByName: categoriesByName,
          roomsById: widget.roomsById,
          statusColor: widget.statusColor,
          salonsById: widget.salonsById,
          lockedAppointmentReasons: widget.lockedAppointmentReasons,
          dayChecklists: widget.dayChecklists,
          onReschedule: widget.onReschedule,
          onEdit: widget.onEdit,
          onCreate: widget.onCreate,
          onTapLastMinuteSlot: widget.onTapLastMinuteSlot,
          anomalies: widget.anomalies,
          horizontalHeaderController: _horizontalHeaderController,
          horizontalBodyController: _horizontalBodyController,
          verticalController: _verticalController,
          slotMinutes: widget.slotMinutes,
          interactionSlotMinutes: widget.interactionSlotMinutes,
          onAddChecklistItem: widget.onAddChecklistItem,
          onToggleChecklistItem: widget.onToggleChecklistItem,
          onRenameChecklistItem: widget.onRenameChecklistItem,
          onDeleteChecklistItem: widget.onDeleteChecklistItem,
          autoScrollTargetDate: _initialScrollDate,
          autoScrollPending: !_didAutoScrollToInitialDay,
          layout: widget.weekLayout,
          onCreateShift: widget.onCreateShift,
          onEditShift: widget.onEditShift,
          onDeleteShift: widget.onDeleteShift,
          onCreateAbsence: widget.onCreateAbsence,
          onEditAbsence: widget.onEditAbsence,
          onDeleteAbsence: widget.onDeleteAbsence,
          onAutoScrollComplete: () {
            if (!_didAutoScrollToInitialDay && mounted) {
              setState(() {
                _didAutoScrollToInitialDay = true;
              });
            }
          },
        );
    }
  }
}

class _CompactMacScrollBehavior extends ScrollBehavior {
  const _CompactMacScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class _DaySchedule extends StatelessWidget {
  const _DaySchedule({
    required this.anchorDate,
    required this.appointments,
    required this.allAppointments,
    required this.lastMinutePlaceholders,
    required this.lastMinuteSlots,
    required this.shifts,
    required this.absences,
    required this.schedule,
    required this.staff,
    required this.clientsWithOutstandingPayments,
    required this.clientsById,
    required this.servicesById,
    required this.categoriesById,
    required this.categoriesByName,
    required this.roomsById,
    required this.statusColor,
    required this.salonsById,
    required this.lockedAppointmentReasons,
    required this.dayChecklists,
    required this.onReschedule,
    required this.onEdit,
    required this.onCreate,
    required this.onTapLastMinuteSlot,
    required this.anomalies,
    required this.horizontalHeaderController,
    required this.horizontalBodyController,
    required this.verticalController,
    required this.slotMinutes,
    required this.interactionSlotMinutes,
    this.onAddChecklistItem,
    this.onToggleChecklistItem,
    this.onRenameChecklistItem,
    this.onDeleteChecklistItem,
    this.onCreateShift,
    this.onEditShift,
    this.onDeleteShift,
    this.onCreateAbsence,
    this.onEditAbsence,
    this.onDeleteAbsence,
  });

  final DateTime anchorDate;
  final List<Appointment> appointments;
  final List<Appointment> allAppointments;
  final List<Appointment> lastMinutePlaceholders;
  final List<LastMinuteSlot> lastMinuteSlots;
  final List<Shift> shifts;
  final List<StaffAbsence> absences;
  final List<SalonDailySchedule>? schedule;
  final List<StaffMember> staff;
  final Set<String> clientsWithOutstandingPayments;
  final Map<String, Client> clientsById;
  final Map<String, Service> servicesById;
  final Map<String, ServiceCategory> categoriesById;
  final Map<String, ServiceCategory> categoriesByName;
  final Map<String, String> roomsById;
  final Map<String, Salon> salonsById;
  final Map<String, String> lockedAppointmentReasons;
  final Map<DateTime, AppointmentDayChecklist> dayChecklists;
  final Color Function(AppointmentStatus status) statusColor;
  final AppointmentRescheduleCallback onReschedule;
  final AppointmentTapCallback onEdit;
  final AppointmentSlotSelectionCallback onCreate;
  final Future<void> Function(LastMinuteSlot slot)? onTapLastMinuteSlot;
  final Map<String, Set<AppointmentAnomalyType>> anomalies;
  final ScrollController horizontalHeaderController;
  final ScrollController horizontalBodyController;
  final ScrollController verticalController;
  final int slotMinutes;
  final int interactionSlotMinutes;
  final Future<void> Function(DateTime day, String label)? onAddChecklistItem;
  final Future<void> Function(
    String checklistId,
    String itemId,
    bool isCompleted,
  )?
  onToggleChecklistItem;
  final Future<void> Function(String checklistId, String itemId, String label)?
  onRenameChecklistItem;
  final Future<void> Function(String checklistId, String itemId)?
  onDeleteChecklistItem;
  final Future<void> Function(StaffMember staff, DateTime day)? onCreateShift;
  final Future<void> Function(Shift shift)? onEditShift;
  final Future<void> Function(Shift shift)? onDeleteShift;
  final Future<void> Function(StaffMember staff, DateTime day)? onCreateAbsence;
  final Future<void> Function(StaffAbsence absence)? onEditAbsence;
  final Future<void> Function(StaffAbsence absence)? onDeleteAbsence;

  static const _slotExtent = _AppointmentCalendarViewState._slotExtent;
  static const _timeScaleExtent =
      _AppointmentCalendarViewState._timeScaleExtent;

  @override
  Widget build(BuildContext context) {
    final dayStart = DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayAppointments =
        appointments
            .where(
              (appointment) => _overlapsRange(
                appointment.start,
                appointment.end,
                dayStart,
                dayEnd,
              ),
            )
            .toList();
    final dayShifts =
        shifts
            .where(
              (shift) =>
                  _overlapsRange(shift.start, shift.end, dayStart, dayEnd),
            )
            .toList();
    final dayAbsences =
        absences
            .where(
              (absence) =>
                  _overlapsRange(absence.start, absence.end, dayStart, dayEnd),
            )
            .toList();
    final scheduleEntry = schedule?.firstWhereOrNull(
      (entry) => entry.weekday == dayStart.weekday,
    );
    DateTime? openingStart;
    DateTime? closingEnd;
    if (scheduleEntry != null &&
        scheduleEntry.isOpen &&
        scheduleEntry.openMinuteOfDay != null &&
        scheduleEntry.closeMinuteOfDay != null) {
      openingStart = dayStart.add(
        Duration(minutes: scheduleEntry.openMinuteOfDay!),
      );
      closingEnd = dayStart.add(
        Duration(minutes: scheduleEntry.closeMinuteOfDay!),
      );
    }

    final bounds = _computeTimelineBounds(
      dayStart,
      dayEnd,
      dayAppointments,
      dayShifts,
      dayAbsences,
      openingStart: openingStart,
      closingEnd: closingEnd,
      slotMinutes: slotMinutes,
    );
    final totalMinutes = bounds.end.difference(bounds.start).inMinutes;
    final slotCount = max(1, (totalMinutes / slotMinutes).ceil());
    final gridHeight = slotCount * _slotExtent;
    final timeSlots = List.generate(
      slotCount,
      (index) => bounds.start.add(Duration(minutes: index * slotMinutes)),
    );

    final appointmentsByStaff = groupBy<Appointment, String>(
      dayAppointments,
      (appointment) => appointment.staffId,
    );
    final shiftsByStaff = groupBy<Shift, String>(
      dayShifts,
      (shift) => shift.staffId,
    );
    final absencesByStaff = groupBy<StaffAbsence, String>(
      dayAbsences,
      (absence) => absence.staffId,
    );

    final dateLabel = _formatCalendarDayLabel(dayStart);
    final normalizedDay = DateTime(dayStart.year, dayStart.month, dayStart.day);
    final dayChecklist = dayChecklists[normalizedDay];
    final hasChecklistItems =
        dayChecklist != null && dayChecklist.items.isNotEmpty;
    final checklistTotal = dayChecklist?.items.length ?? 0;
    final checklistCompleted =
        dayChecklist?.items.where((item) => item.isCompleted).length ?? 0;
    final showChecklistLauncher =
        hasChecklistItems ||
        onAddChecklistItem != null ||
        onToggleChecklistItem != null ||
        onRenameChecklistItem != null ||
        onDeleteChecklistItem != null;

    final theme = Theme.of(context);
    final headerColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.55,
    );
    final timelineColor = theme.colorScheme.surfaceContainerLowest.withValues(
      alpha: 0.45,
    );
    final staffColumnBorderColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.55,
    );
    final staffColumnShadowColor = theme.colorScheme.shadow.withValues(
      alpha: 0.08,
    );
    final timeFormat = DateFormat('HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _timeScaleExtent,
                child: Center(
                  child: Text('Ora', style: theme.textTheme.labelMedium),
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              dateLabel,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (showChecklistLauncher) ...[
                            const SizedBox(width: 12),
                            _ChecklistDialogLauncher(
                              day: normalizedDay,
                              dateLabel: dateLabel,
                              checklist: dayChecklist,
                              total: checklistTotal,
                              completed: checklistCompleted,
                              salonId: dayChecklist?.salonId,
                              onAdd: onAddChecklistItem,
                              onToggle: onToggleChecklistItem,
                              onRename: onRenameChecklistItem,
                              onDelete: onDeleteChecklistItem,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: _timeScaleExtent,
                    height: _kStaffHeaderHeight,
                  ),
                  const SizedBox(width: 12, height: _kStaffHeaderHeight),
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: const _CompactMacScrollBehavior(),
                      child: Scrollbar(
                        controller: horizontalHeaderController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: horizontalHeaderController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var staffIndex = 0;
                                staffIndex < staff.length;
                                staffIndex++
                              ) ...[
                                Builder(
                                  builder: (context) {
                                    final staffMember = staff[staffIndex];
                                    final staffShifts =
                                        shiftsByStaff[staffMember.id] ??
                                        const <Shift>[];
                                    final staffAbsences =
                                        absencesByStaff[staffMember.id] ??
                                        const <StaffAbsence>[];
                                    final canManage =
                                        (onCreateShift != null ||
                                            onEditShift != null ||
                                            onDeleteShift != null) ||
                                        (onCreateAbsence != null ||
                                            onEditAbsence != null ||
                                            onDeleteAbsence != null);
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right:
                                            staffIndex == staff.length - 1
                                                ? 0
                                                : 16,
                                      ),
                                      child: _StaffHeaderButton(
                                        enabled: canManage,
                                        tooltip:
                                            'Gestisci turni e assenze per ${_formatCalendarDayLabel(dayStart)}',
                                        onPressed: () async {
                                          await _handleStaffDayManagement(
                                            context,
                                            staff: staffMember,
                                            day: dayStart,
                                            shifts: staffShifts,
                                            absences: staffAbsences,
                                            roomsById: roomsById,
                                            onCreateShift: onCreateShift,
                                            onEditShift: onEditShift,
                                            onDeleteShift: onDeleteShift,
                                            onCreateAbsence: onCreateAbsence,
                                            onEditAbsence: onEditAbsence,
                                            onDeleteAbsence: onDeleteAbsence,
                                          );
                                        },
                                        child: Container(
                                          width: _kStaffColumnWidth,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                theme.colorScheme.surfaceVariant
                                                    .withValues(alpha: 0.78),
                                                theme.colorScheme.surface,
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: staffColumnBorderColor,
                                              width: 1.1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: staffColumnShadowColor,
                                                blurRadius: 18,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _firstNameOnly(
                                                  staffMember.fullName,
                                                ),
                                                style:
                                                    theme.textTheme.titleSmall,
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Scrollbar(
                  controller: verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: verticalController,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 0, bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: _timeScaleExtent,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: timelineColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.dividerColor.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(slotCount, (index) {
                                final slotTime = timeSlots[index];
                                final label = timeFormat.format(slotTime);
                                return SizedBox(
                                  height: _slotExtent,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      label,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          Expanded(
                            child: ScrollConfiguration(
                              behavior: const _CompactMacScrollBehavior(),
                              child: Scrollbar(
                                controller: horizontalBodyController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: horizontalBodyController,
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (
                                        var staffIndex = 0;
                                        staffIndex < staff.length;
                                        staffIndex++
                                      ) ...[
                                        Padding(
                                          padding: EdgeInsets.only(
                                            right:
                                                staffIndex == staff.length - 1
                                                    ? 0
                                                    : 16,
                                          ),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  theme.colorScheme.surface,
                                                  theme
                                                      .colorScheme
                                                      .surfaceVariant
                                                      .withValues(alpha: 0.42),
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: staffColumnBorderColor,
                                                width: 1.05,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: staffColumnShadowColor,
                                                  blurRadius: 24,
                                                  offset: const Offset(0, 12),
                                                ),
                                              ],
                                            ),
                                            child: SizedBox(
                                              width: _kStaffColumnWidth,
                                              height: gridHeight,
                                              child: _StaffDayColumn(
                                                staffMember: staff[staffIndex],
                                                appointments:
                                                    appointmentsByStaff[staff[staffIndex]
                                                        .id] ??
                                                    const [],
                                                lastMinutePlaceholders:
                                                    lastMinutePlaceholders,
                                                lastMinuteSlots:
                                                    lastMinuteSlots,
                                                onTapLastMinuteSlot:
                                                    onTapLastMinuteSlot,
                                                shifts:
                                                    shiftsByStaff[staff[staffIndex]
                                                        .id] ??
                                                    const [],
                                                absences:
                                                    absencesByStaff[staff[staffIndex]
                                                        .id] ??
                                                    const [],
                                                timelineStart: bounds.start,
                                                timelineEnd: bounds.end,
                                                slotMinutes: slotMinutes,
                                                interactionSlotMinutes:
                                                    interactionSlotMinutes,
                                                slotExtent: _slotExtent,
                                                clientsWithOutstandingPayments:
                                                    clientsWithOutstandingPayments,
                                                clientsById: clientsById,
                                                servicesById: servicesById,
                                                categoriesById: categoriesById,
                                                categoriesByName:
                                                    categoriesByName,
                                                roomsById: roomsById,
                                                salonsById: salonsById,
                                                allAppointments:
                                                    allAppointments,
                                                statusColor: statusColor,
                                                lockedAppointmentReasons:
                                                    lockedAppointmentReasons,
                                                onReschedule: onReschedule,
                                                onEdit: onEdit,
                                                onCreate: onCreate,
                                                anomalies: anomalies,
                                                openStart: openingStart,
                                                openEnd: closingEnd,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static _TimelineBounds _computeTimelineBounds(
    DateTime dayStart,
    DateTime dayEnd,
    List<Appointment> appointments,
    List<Shift> shifts,
    List<StaffAbsence> absences, {
    DateTime? openingStart,
    DateTime? closingEnd,
    required int slotMinutes,
  }) {
    DateTime? earliest;
    DateTime? latest;

    for (final appointment in appointments) {
      final start =
          appointment.start.isBefore(dayStart) ? dayStart : appointment.start;
      final end = appointment.end.isAfter(dayEnd) ? dayEnd : appointment.end;
      earliest = _minDate(earliest, start);
      latest = _maxDate(latest, end);
    }

    for (final shift in shifts) {
      final start = shift.start.isBefore(dayStart) ? dayStart : shift.start;
      final end = shift.end.isAfter(dayEnd) ? dayEnd : shift.end;
      earliest = _minDate(earliest, start);
      latest = _maxDate(latest, end);
    }

    for (final absence in absences) {
      final start = absence.start.isBefore(dayStart) ? dayStart : absence.start;
      final end = absence.end.isAfter(dayEnd) ? dayEnd : absence.end;
      earliest = _minDate(earliest, start);
      latest = _maxDate(latest, end);
    }

    DateTime fallbackStart =
        openingStart != null && openingStart.isAfter(dayStart)
            ? openingStart
            : dayStart.add(const Duration(hours: 8));
    if (fallbackStart.isBefore(dayStart)) {
      fallbackStart = dayStart;
    }
    DateTime fallbackEnd =
        closingEnd != null && closingEnd.isBefore(dayEnd)
            ? closingEnd
            : dayStart.add(const Duration(hours: 20));
    if (fallbackEnd.isAfter(dayEnd)) {
      fallbackEnd = dayEnd;
    }

    var start = earliest ?? fallbackStart;
    var end = latest ?? fallbackEnd;

    if (start.isBefore(fallbackStart)) {
      start = fallbackStart;
    }
    if (end.isAfter(fallbackEnd)) {
      end = fallbackEnd;
    }

    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }

    start = _floorToSlot(start, slotMinutes);
    end = _ceilToSlot(end, slotMinutes);

    return _TimelineBounds(start: start, end: end);
  }
}

class _WeekSchedule extends StatelessWidget {
  const _WeekSchedule({
    required this.anchorDate,
    required this.appointments,
    required this.allAppointments,
    required this.lastMinutePlaceholders,
    required this.lastMinuteSlots,
    required this.shifts,
    required this.absences,
    required this.schedule,
    required this.visibleWeekdays,
    required this.staff,
    required this.roles,
    required this.clientsWithOutstandingPayments,
    required this.clientsById,
    required this.servicesById,
    required this.categoriesById,
    required this.categoriesByName,
    required this.roomsById,
    required this.statusColor,
    required this.salonsById,
    required this.lockedAppointmentReasons,
    required this.dayChecklists,
    required this.onReschedule,
    required this.onEdit,
    required this.onCreate,
    required this.onTapLastMinuteSlot,
    required this.horizontalHeaderController,
    required this.horizontalBodyController,
    required this.verticalController,
    required this.anomalies,
    required this.slotMinutes,
    required this.interactionSlotMinutes,
    this.onAddChecklistItem,
    this.onToggleChecklistItem,
    this.onRenameChecklistItem,
    this.onDeleteChecklistItem,
    this.onCreateShift,
    this.onEditShift,
    this.onDeleteShift,
    this.onCreateAbsence,
    this.onEditAbsence,
    this.onDeleteAbsence,
    this.autoScrollTargetDate,
    this.autoScrollPending = false,
    required this.layout,
    this.onAutoScrollComplete,
  });

  final DateTime anchorDate;
  final List<Appointment> appointments;
  final List<Appointment> allAppointments;
  final List<Appointment> lastMinutePlaceholders;
  final List<LastMinuteSlot> lastMinuteSlots;
  final List<Shift> shifts;
  final List<StaffAbsence> absences;
  final List<SalonDailySchedule>? schedule;
  final Set<int> visibleWeekdays;
  final List<StaffMember> staff;
  final List<StaffRole> roles;
  final Set<String> clientsWithOutstandingPayments;
  final Map<String, Client> clientsById;
  final Map<String, Service> servicesById;
  final Map<String, ServiceCategory> categoriesById;
  final Map<String, ServiceCategory> categoriesByName;
  final Map<String, String> roomsById;
  final Map<String, Salon> salonsById;
  final Map<String, String> lockedAppointmentReasons;
  final Color Function(AppointmentStatus status) statusColor;
  final AppointmentRescheduleCallback onReschedule;
  final AppointmentTapCallback onEdit;
  final AppointmentSlotSelectionCallback onCreate;
  final Future<void> Function(LastMinuteSlot slot)? onTapLastMinuteSlot;
  final ScrollController horizontalHeaderController;
  final ScrollController horizontalBodyController;
  final ScrollController verticalController;
  final Map<String, Set<AppointmentAnomalyType>> anomalies;
  final int slotMinutes;
  final int interactionSlotMinutes;
  final Map<DateTime, AppointmentDayChecklist> dayChecklists;
  final Future<void> Function(DateTime day, String label)? onAddChecklistItem;
  final Future<void> Function(
    String checklistId,
    String itemId,
    bool isCompleted,
  )?
  onToggleChecklistItem;
  final Future<void> Function(String checklistId, String itemId, String label)?
  onRenameChecklistItem;
  final Future<void> Function(String checklistId, String itemId)?
  onDeleteChecklistItem;
  final Future<void> Function(StaffMember staff, DateTime day)? onCreateShift;
  final Future<void> Function(Shift shift)? onEditShift;
  final Future<void> Function(Shift shift)? onDeleteShift;
  final Future<void> Function(StaffMember staff, DateTime day)? onCreateAbsence;
  final Future<void> Function(StaffAbsence absence)? onEditAbsence;
  final Future<void> Function(StaffAbsence absence)? onDeleteAbsence;
  final DateTime? autoScrollTargetDate;
  final bool autoScrollPending;
  final AppointmentWeekLayoutMode layout;
  final VoidCallback? onAutoScrollComplete;

  static const _slotExtent = _AppointmentCalendarViewState._slotExtent;
  static const _timeScaleExtent =
      _AppointmentCalendarViewState._timeScaleExtent;

  static Widget _summaryChip({
    required ThemeData theme,
    required IconData icon,
    required String label,
    Color? background,
    Color? foreground,
    String? tooltip,
  }) {
    final tooltipParts = <String>[];
    if (label.trim().isNotEmpty) {
      tooltipParts.add(label);
    }
    if (tooltip != null && tooltip.trim().isNotEmpty) {
      tooltipParts.add(tooltip);
    }
    final tooltipMessage = tooltipParts.join('\n');

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        icon,
        size: 18,
        color: foreground ?? theme.colorScheme.onSurfaceVariant,
      ),
    );
    if (tooltipMessage.isNotEmpty) {
      return Tooltip(
        message: tooltipMessage,
        waitDuration: const Duration(milliseconds: 250),
        child: chip,
      );
    }
    return chip;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startOfWeek = _weekStart(anchorDate);
    final days = List.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );
    final openSchedule = schedule?.where(
      (entry) =>
          entry.isOpen &&
          entry.openMinuteOfDay != null &&
          entry.closeMinuteOfDay != null,
    );
    final openWeekdays = openSchedule?.map((entry) => entry.weekday).toSet();
    final filteredDays =
        days.where((day) {
          final isVisible = visibleWeekdays.contains(day.weekday);
          final isOpen =
              openWeekdays == null || openWeekdays.contains(day.weekday);
          return isVisible && isOpen;
        }).toList();
    if (filteredDays.isEmpty) {
      filteredDays.add(startOfWeek);
    }

    final dayData =
        filteredDays.map((day) {
          final dayStart = DateTime(day.year, day.month, day.day);
          final dayEnd = dayStart.add(const Duration(days: 1));
          final dayAppointments =
              appointments
                  .where(
                    (appointment) => _overlapsRange(
                      appointment.start,
                      appointment.end,
                      dayStart,
                      dayEnd,
                    ),
                  )
                  .toList();
          final dayShifts =
              shifts
                  .where(
                    (shift) => _overlapsRange(
                      shift.start,
                      shift.end,
                      dayStart,
                      dayEnd,
                    ),
                  )
                  .toList();
          final dayAbsences =
              absences
                  .where(
                    (absence) => _overlapsRange(
                      absence.start,
                      absence.end,
                      dayStart,
                      dayEnd,
                    ),
                  )
                  .toList();
          final scheduleEntry = schedule?.firstWhereOrNull(
            (entry) => entry.weekday == day.weekday,
          );
          DateTime? openStart;
          DateTime? openEnd;
          if (scheduleEntry != null &&
              scheduleEntry.isOpen &&
              scheduleEntry.openMinuteOfDay != null &&
              scheduleEntry.closeMinuteOfDay != null) {
            openStart = dayStart.add(
              Duration(minutes: scheduleEntry.openMinuteOfDay!),
            );
            openEnd = dayStart.add(
              Duration(minutes: scheduleEntry.closeMinuteOfDay!),
            );
          }

          final bounds = _DaySchedule._computeTimelineBounds(
            dayStart,
            dayEnd,
            dayAppointments,
            dayShifts,
            dayAbsences,
            openingStart: openStart,
            closingEnd: openEnd,
            slotMinutes: slotMinutes,
          );

          return _WeekDayData(
            date: dayStart,
            appointmentsByStaff: groupBy<Appointment, String>(
              dayAppointments,
              (appointment) => appointment.staffId,
            ),
            shiftsByStaff: groupBy<Shift, String>(
              dayShifts,
              (shift) => shift.staffId,
            ),
            absencesByStaff: groupBy<StaffAbsence, String>(
              dayAbsences,
              (absence) => absence.staffId,
            ),
            openStart: openStart,
            openEnd: openEnd,
            bounds: bounds,
            scheduleEntry: scheduleEntry,
          );
        }).toList();

    int? minMinute;
    int? maxMinute;
    for (final data in dayData) {
      final startMinute = data.bounds.start.difference(data.date).inMinutes;
      final endMinute = data.bounds.end.difference(data.date).inMinutes;
      minMinute = minMinute == null ? startMinute : min(minMinute, startMinute);
      maxMinute = maxMinute == null ? endMinute : max(maxMinute, endMinute);
    }
    minMinute ??= 8 * 60;
    maxMinute ??= 20 * 60;
    if (maxMinute <= minMinute) {
      maxMinute = minMinute + 60;
    }

    final totalMinutes = maxMinute - minMinute;
    final slotCount = max(1, (totalMinutes / slotMinutes).ceil());
    const double staffHeaderHeight = 44.0;
    const double compactSlotExtent = 120.0;
    const double detailedSlotExtent = _slotExtent;
    final referenceDate = dayData.first.date;
    final referenceTimelineStart = referenceDate.add(
      Duration(minutes: minMinute),
    );
    final timeSlots = List.generate(
      slotCount,
      (index) =>
          referenceTimelineStart.add(Duration(minutes: index * slotMinutes)),
    );

    if (layout == AppointmentWeekLayoutMode.operatorBoard) {
      return _WeekOperatorBoardView(
        dayData: dayData,
        staff: staff,
        roles: roles,
        clientsById: clientsById,
        servicesById: servicesById,
        roomsById: roomsById,
        lockedAppointmentReasons: lockedAppointmentReasons,
        anomalies: anomalies,
        statusColor: statusColor,
        slotMinutes: slotMinutes,
        lastMinutePlaceholders: lastMinutePlaceholders,
        onEdit: onEdit,
        onCreate: onCreate,
        minMinute: minMinute!,
        verticalController: verticalController,
      );
    }

    if (layout == AppointmentWeekLayoutMode.compact) {
      return _WeekCompactView(
        dayData: dayData,
        staff: staff,
        roles: roles,
        clientsWithOutstandingPayments: clientsWithOutstandingPayments,
        clientsById: clientsById,
        servicesById: servicesById,
        categoriesById: categoriesById,
        categoriesByName: categoriesByName,
        roomsById: roomsById,
        salonsById: salonsById,
        lockedAppointmentReasons: lockedAppointmentReasons,
        dayChecklists: dayChecklists,
        onReschedule: onReschedule,
        onEdit: onEdit,
        onCreate: onCreate,
        onTapLastMinuteSlot: onTapLastMinuteSlot,
        lastMinutePlaceholders: lastMinutePlaceholders,
        lastMinuteSlots: lastMinuteSlots,
        allAppointments: allAppointments,
        anomalies: anomalies,
        statusColor: statusColor,
        slotMinutes: slotMinutes,
        slotExtent: compactSlotExtent,
        minMinute: minMinute!,
        maxMinute: maxMinute!,
        verticalController: verticalController,
        interactionSlotMinutes: interactionSlotMinutes,
        onAddChecklistItem: onAddChecklistItem,
        onToggleChecklistItem: onToggleChecklistItem,
        onRenameChecklistItem: onRenameChecklistItem,
        onDeleteChecklistItem: onDeleteChecklistItem,
        onCreateShift: onCreateShift,
        onEditShift: onEditShift,
        onDeleteShift: onDeleteShift,
        onCreateAbsence: onCreateAbsence,
        onEditAbsence: onEditAbsence,
        onDeleteAbsence: onDeleteAbsence,
      );
    }

    final gridHeight = slotCount * detailedSlotExtent;
    final timeFormat = DateFormat('HH:mm');

    final dayHeaderColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.55,
    );
    final dayBodyColor = theme.colorScheme.surfaceContainerLowest.withValues(
      alpha: 0.45,
    );
    final staffById = {for (final member in staff) member.id: member};
    final now = DateTime.now();
    final staffColumnBorderColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.55,
    );
    final staffColumnShadowColor = theme.colorScheme.shadow.withValues(
      alpha: 0.08,
    );
    const double dayHorizontalPadding = 12.0;
    const double dayGap = 16.0;
    const double staffGap = 8.0;
    const double minDayWidth = 320.0;
    const double minStaffColumnWidth = 110.0;
    const double dayBorderWidth = 1.0;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final availableRowWidth = max(
      0.0,
      viewportWidth - _timeScaleExtent - (dayGap + dayHorizontalPadding),
    );
    final targetVisibleDays = max(1, min(3, dayData.length));
    var dayWidth = max(
      minDayWidth,
      availableRowWidth / targetVisibleDays.toDouble(),
    );
    final staffCount = max(1, staff.length);
    final rawInnerWidth = max(
      0.0,
      dayWidth - (dayHorizontalPadding * 2) - (dayBorderWidth * 2),
    );
    final rawStaffWidth =
        (rawInnerWidth - staffGap * max(staffCount - 1, 0)) / staffCount;
    final staffColumnWidth = rawStaffWidth.clamp(
      minStaffColumnWidth,
      _kStaffColumnWidth,
    );
    final dayInnerWidth =
        (staffColumnWidth * staffCount) + staffGap * max(staffCount - 1, 0);
    dayWidth =
        dayInnerWidth + (dayHorizontalPadding * 2) + (dayBorderWidth * 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _timeScaleExtent,
                child: Center(
                  child: Text('Ora', style: theme.textTheme.labelMedium),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const _CompactMacScrollBehavior(),
                  child: Scrollbar(
                    controller: horizontalHeaderController,
                    thumbVisibility: true,
                    interactive: true,
                    thickness: 8,
                    radius: const Radius.circular(8),
                    child: SingleChildScrollView(
                      controller: horizontalHeaderController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (
                                var dayIndex = 0;
                                dayIndex < dayData.length;
                                dayIndex++
                              ) ...[
                                Builder(
                                  builder: (context) {
                                    final data = dayData[dayIndex];
                                    final dateLabel = _formatCalendarDayLabel(
                                      data.date,
                                    );
                                    final normalizedDate = DateUtils.dateOnly(
                                      data.date,
                                    );
                                    final isToday = DateUtils.isSameDay(
                                      normalizedDate,
                                      now,
                                    );
                                    final shouldAutoScroll =
                                        autoScrollPending &&
                                        autoScrollTargetDate != null &&
                                        DateUtils.isSameDay(
                                          normalizedDate,
                                          autoScrollTargetDate!,
                                        );
                                    if (shouldAutoScroll) {
                                      WidgetsBinding.instance.addPostFrameCallback((
                                        _,
                                      ) {
                                        onAutoScrollComplete?.call();
                                        Scrollable.ensureVisible(
                                          context,
                                          alignment: 0.25,
                                          duration: const Duration(
                                            milliseconds: 360,
                                          ),
                                          curve: Curves.easeOutCubic,
                                        ).catchError((_) {
                                          // Ignored: the scrollable may be gone.
                                        });
                                      });
                                    }
                                    final headerColor =
                                        isToday
                                            ? Color.alphaBlend(
                                              theme.colorScheme.primary
                                                  .withValues(alpha: 0.08),
                                              dayHeaderColor,
                                            )
                                            : dayHeaderColor;
                                    final borderColor =
                                        isToday
                                            ? theme.colorScheme.primary
                                                .withValues(alpha: 0.55)
                                            : theme.dividerColor.withValues(
                                              alpha: 0.4,
                                            );
                                    final List<BoxShadow>? boxShadow =
                                        isToday
                                            ? [
                                              BoxShadow(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.18),
                                                blurRadius: 18,
                                                offset: const Offset(0, 6),
                                              ),
                                            ]
                                            : null;
                                    final totalAppointments = data
                                        .appointmentsByStaff
                                        .values
                                        .fold<int>(
                                          0,
                                          (running, list) =>
                                              running + list.length,
                                        );
                                    final dayChecklist =
                                        dayChecklists[data.date];
                                    final hasChecklistItems =
                                        dayChecklist != null &&
                                        dayChecklist.items.isNotEmpty;
                                    final checklistTotal =
                                        dayChecklist?.items.length ?? 0;
                                    final checklistCompleted =
                                        dayChecklist?.items
                                            .where((item) => item.isCompleted)
                                            .length ??
                                        0;
                                    final showChecklistLauncher =
                                        hasChecklistItems ||
                                        onAddChecklistItem != null ||
                                        onToggleChecklistItem != null ||
                                        onRenameChecklistItem != null ||
                                        onDeleteChecklistItem != null;
                                    final scheduledStaffIds = data
                                        .shiftsByStaff
                                        .entries
                                        .where(
                                          (entry) => entry.value.isNotEmpty,
                                        )
                                        .map((entry) => entry.key)
                                        .toList(growable: false);
                                    final absenceStaffIds = data
                                        .absencesByStaff
                                        .entries
                                        .where(
                                          (entry) => entry.value.isNotEmpty,
                                        )
                                        .map((entry) => entry.key)
                                        .toList(growable: false);
                                    final scheduledNames = scheduledStaffIds
                                        .map((id) => staffById[id]?.fullName)
                                        .whereType<String>()
                                        .toList(growable: false);
                                    final absenceNames = absenceStaffIds
                                        .map((id) => staffById[id]?.fullName)
                                        .whereType<String>()
                                        .toList(growable: false);

                                    final summaryChips = <Widget>[
                                      _summaryChip(
                                        theme: theme,
                                        icon: Icons.event_available_rounded,
                                        label:
                                            '$totalAppointments appuntamenti',
                                        background: theme
                                            .colorScheme
                                            .tertiaryContainer
                                            .withValues(alpha: 0.6),
                                        foreground:
                                            theme
                                                .colorScheme
                                                .onTertiaryContainer,
                                      ),
                                    ];

                                    return Container(
                                      width: dayWidth,
                                      margin: EdgeInsets.only(
                                        right:
                                            dayIndex == dayData.length - 1
                                                ? 0
                                                : dayGap,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: headerColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: borderColor),
                                        boxShadow: boxShadow,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: dayHorizontalPadding,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isToday) ...[
                                                  Align(
                                                    alignment: Alignment.center,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: theme
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.15,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              999,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'Oggi',
                                                        style: theme
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color:
                                                                  theme
                                                                      .colorScheme
                                                                      .primary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    if (summaryChips
                                                        .isNotEmpty) ...[
                                                      Flexible(
                                                        flex: 2,
                                                        child: ScrollConfiguration(
                                                          behavior:
                                                              const _CompactMacScrollBehavior(),
                                                          child: SingleChildScrollView(
                                                            scrollDirection:
                                                                Axis.horizontal,
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                for (
                                                                  var i = 0;
                                                                  i <
                                                                      summaryChips
                                                                          .length;
                                                                  i++
                                                                ) ...[
                                                                  if (i != 0)
                                                                    const SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                  summaryChips[i],
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                    ],
                                                    Flexible(
                                                      flex: 3,
                                                      fit: FlexFit.loose,
                                                      child: Text(
                                                        dateLabel,
                                                        style:
                                                            theme
                                                                .textTheme
                                                                .titleMedium,
                                                      ),
                                                    ),
                                                    if (showChecklistLauncher) ...[
                                                      const SizedBox(width: 8),
                                                      _ChecklistDialogLauncher(
                                                        day: data.date,
                                                        dateLabel: dateLabel,
                                                        checklist: dayChecklist,
                                                        total: checklistTotal,
                                                        completed:
                                                            checklistCompleted,
                                                        salonId:
                                                            dayChecklist
                                                                ?.salonId,
                                                        onAdd:
                                                            onAddChecklistItem,
                                                        onToggle:
                                                            onToggleChecklistItem,
                                                        onRename:
                                                            onRenameChecklistItem,
                                                        onDelete:
                                                            onDeleteChecklistItem,
                                                        compact: true,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: dayHorizontalPadding,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                for (
                                                  var columnIndex = 0;
                                                  columnIndex < staff.length;
                                                  columnIndex++
                                                ) ...[
                                                  SizedBox(
                                                    width: staffColumnWidth,
                                                    height: 0,
                                                  ),
                                                  if (columnIndex !=
                                                      staff.length - 1)
                                                    SizedBox(width: staffGap),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              for (
                                var dayIndex = 0;
                                dayIndex < dayData.length;
                                dayIndex++
                              ) ...[
                                Builder(
                                  builder: (context) {
                                    final day = dayData[dayIndex];
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        right:
                                            dayIndex == dayData.length - 1
                                                ? 0
                                                : dayGap,
                                        top: 6,
                                        bottom: 6,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: dayWidth,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal:
                                                        dayHorizontalPadding,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  for (
                                                    var staffIndex = 0;
                                                    staffIndex < staff.length;
                                                    staffIndex++
                                                  ) ...[
                                                    Builder(
                                                      builder: (context) {
                                                        final staffMember =
                                                            staff[staffIndex];
                                                        final staffShifts =
                                                            day.shiftsByStaff[staffMember
                                                                .id] ??
                                                            const <Shift>[];
                                                        final staffAbsences =
                                                            day.absencesByStaff[staffMember
                                                                .id] ??
                                                            const <
                                                              StaffAbsence
                                                            >[];
                                                        final canManage =
                                                            (onCreateShift !=
                                                                    null ||
                                                                onEditShift !=
                                                                    null ||
                                                                onDeleteShift !=
                                                                    null) ||
                                                            (onCreateAbsence !=
                                                                    null ||
                                                                onEditAbsence !=
                                                                    null ||
                                                                onDeleteAbsence !=
                                                                    null);
                                                        return _StaffHeaderButton(
                                                          enabled: canManage,
                                                          tooltip:
                                                              'Gestisci turni e assenze per ${_formatCalendarDayLabel(day.date)}',
                                                          onPressed: () async {
                                                            await _handleStaffDayManagement(
                                                              context,
                                                              staff:
                                                                  staffMember,
                                                              day: day.date,
                                                              shifts:
                                                                  staffShifts,
                                                              absences:
                                                                  staffAbsences,
                                                              roomsById:
                                                                  roomsById,
                                                              onCreateShift:
                                                                  onCreateShift,
                                                              onEditShift:
                                                                  onEditShift,
                                                              onDeleteShift:
                                                                  onDeleteShift,
                                                              onCreateAbsence:
                                                                  onCreateAbsence,
                                                              onEditAbsence:
                                                                  onEditAbsence,
                                                              onDeleteAbsence:
                                                                  onDeleteAbsence,
                                                            );
                                                          },
                                                          child: Container(
                                                            width:
                                                                staffColumnWidth,
                                                            margin: EdgeInsets.only(
                                                              right:
                                                                  staffIndex ==
                                                                          staff.length -
                                                                              1
                                                                      ? 0
                                                                      : staffGap,
                                                            ),
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 10,
                                                                ),
                                                            constraints:
                                                                BoxConstraints(
                                                                  minHeight:
                                                                      staffHeaderHeight,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              gradient: LinearGradient(
                                                                colors: [
                                                                  theme
                                                                      .colorScheme
                                                                      .surfaceVariant
                                                                      .withValues(
                                                                        alpha:
                                                                            0.78,
                                                                      ),
                                                                  theme
                                                                      .colorScheme
                                                                      .surface,
                                                                ],
                                                                begin:
                                                                    Alignment
                                                                        .topCenter,
                                                                end:
                                                                    Alignment
                                                                        .bottomCenter,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    14,
                                                                  ),
                                                              border: Border.all(
                                                                color:
                                                                    staffColumnBorderColor,
                                                                width: 1.1,
                                                              ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color:
                                                                      staffColumnShadowColor,
                                                                  blurRadius:
                                                                      18,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        10,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                            child: Text(
                                                              _firstNameOnly(
                                                                staffMember
                                                                    .fullName,
                                                              ),
                                                              style:
                                                                  theme
                                                                      .textTheme
                                                                      .titleSmall,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: verticalController,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: _timeScaleExtent,
                      decoration: BoxDecoration(
                        color: dayHeaderColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: SizedBox(
                        height: gridHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(slotCount, (index) {
                              final slotTime = timeSlots[index];
                              final showLabel = slotTime.minute == 0;
                              final label =
                                  showLabel ? timeFormat.format(slotTime) : '';
                              return SizedBox(
                                height: _slotExtent,
                                child: Center(
                                  child: Text(
                                    label,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: const _CompactMacScrollBehavior(),
                        child: Scrollbar(
                          controller: horizontalBodyController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: horizontalBodyController,
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (
                                  var dayIndex = 0;
                                  dayIndex < dayData.length;
                                  dayIndex++
                                ) ...[
                                  Container(
                                    width: dayWidth,
                                    margin: EdgeInsets.only(
                                      right:
                                          dayIndex == dayData.length - 1
                                              ? 0
                                              : dayGap,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: dayBodyColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.dividerColor.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: dayBorderWidth,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: dayHorizontalPadding,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          for (
                                            var staffIndex = 0;
                                            staffIndex < staff.length;
                                            staffIndex++
                                          ) ...[
                                            Container(
                                              width: staffColumnWidth,
                                              margin: EdgeInsets.only(
                                                right:
                                                    staffIndex ==
                                                            staff.length - 1
                                                        ? 0
                                                        : staffGap,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    theme.colorScheme.surface,
                                                    theme
                                                        .colorScheme
                                                        .surfaceVariant
                                                        .withValues(
                                                          alpha: 0.42,
                                                        ),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: staffColumnBorderColor,
                                                  width: 1.05,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        staffColumnShadowColor,
                                                    blurRadius: 24,
                                                    offset: const Offset(0, 12),
                                                  ),
                                                ],
                                              ),
                                              child: SizedBox(
                                                height: gridHeight,
                                                child: _StaffDayColumn(
                                                  staffMember:
                                                      staff[staffIndex],
                                                  appointments:
                                                      dayData[dayIndex]
                                                          .appointmentsByStaff[staff[staffIndex]
                                                          .id] ??
                                                      const [],
                                                  lastMinutePlaceholders:
                                                      lastMinutePlaceholders,
                                                  lastMinuteSlots:
                                                      lastMinuteSlots,
                                                  onTapLastMinuteSlot:
                                                      onTapLastMinuteSlot,
                                                  shifts:
                                                      dayData[dayIndex]
                                                          .shiftsByStaff[staff[staffIndex]
                                                          .id] ??
                                                      const [],
                                                  absences:
                                                      dayData[dayIndex]
                                                          .absencesByStaff[staff[staffIndex]
                                                          .id] ??
                                                      const [],
                                                  timelineStart:
                                                      dayData[dayIndex].date
                                                          .add(
                                                            Duration(
                                                              minutes:
                                                                  minMinute,
                                                            ),
                                                          ),
                                                  timelineEnd: dayData[dayIndex]
                                                      .date
                                                      .add(
                                                        Duration(
                                                          minutes: maxMinute,
                                                        ),
                                                      ),
                                                  slotMinutes: slotMinutes,
                                                  interactionSlotMinutes:
                                                      interactionSlotMinutes,
                                                  slotExtent: _slotExtent,
                                                  clientsWithOutstandingPayments:
                                                      clientsWithOutstandingPayments,
                                                  clientsById: clientsById,
                                                  servicesById: servicesById,
                                                  categoriesById:
                                                      categoriesById,
                                                  categoriesByName:
                                                      categoriesByName,
                                                  roomsById: roomsById,
                                                  salonsById: salonsById,
                                                  allAppointments:
                                                      allAppointments,
                                                  statusColor: statusColor,
                                                  onReschedule: onReschedule,
                                                  onEdit: onEdit,
                                                  onCreate: onCreate,
                                                  anomalies: anomalies,
                                                  lockedAppointmentReasons:
                                                      lockedAppointmentReasons,
                                                  openStart:
                                                      dayData[dayIndex]
                                                          .openStart,
                                                  openEnd:
                                                      dayData[dayIndex].openEnd,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ChecklistItemAction { rename, delete }

class _ChecklistSection extends StatefulWidget {
  const _ChecklistSection({
    required this.day,
    this.checklist,
    this.onAdd,
    this.onToggle,
    this.onRename,
    this.onDelete,
    this.dense = false,
    this.maxVisibleItems,
    this.maxWidth,
  });

  final DateTime day;
  final AppointmentDayChecklist? checklist;
  final Future<void> Function(DateTime day, String label)? onAdd;
  final Future<void> Function(
    String checklistId,
    String itemId,
    bool isCompleted,
  )?
  onToggle;
  final Future<void> Function(String checklistId, String itemId, String label)?
  onRename;
  final Future<void> Function(String checklistId, String itemId)? onDelete;
  final bool dense;
  final int? maxVisibleItems;
  final double? maxWidth;

  @override
  State<_ChecklistSection> createState() => _ChecklistSectionState();
}

class _ChecklistSectionState extends State<_ChecklistSection> {
  late final TextEditingController _inputController;
  late final FocusNode _inputFocus;
  bool _isSubmitting = false;
  final Set<String> _pendingItemIds = <String>{};

  bool get _canAdd => widget.onAdd != null;
  bool get _hasChecklist => widget.checklist != null;
  bool get _canToggle => widget.onToggle != null && _hasChecklist;
  bool get _canRename => widget.onRename != null && _hasChecklist;
  bool get _canDelete => widget.onDelete != null && _hasChecklist;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _inputFocus = FocusNode();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ChecklistSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checklist?.id != oldWidget.checklist?.id) {
      _pendingItemIds.clear();
    } else if (widget.checklist != null) {
      final validIds = widget.checklist!.items.map((item) => item.id).toSet();
      _pendingItemIds.removeWhere((id) => !validIds.contains(id));
    }
    final previousCount = oldWidget.checklist?.items.length ?? 0;
    final currentCount = widget.checklist?.items.length ?? 0;
    if (_isSubmitting && currentCount > previousCount) {
      if (mounted) {
        setState(() => _isSubmitting = false);
      } else {
        _isSubmitting = false;
      }
    }
  }

  Future<void> _submitNewItem() async {
    if (!_canAdd || _isSubmitting) {
      return;
    }
    final originalText = _inputController.text;
    final text = originalText.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() => _isSubmitting = true);
    _inputController.clear();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        FocusScope.of(context).requestFocus(_inputFocus);
      });
    }
    try {
      await widget.onAdd!(widget.day, text);
      if (!mounted) {
        return;
      }
      // Ensure the field is ready for a new entry after the Firestore update.
      if (_inputController.text.isNotEmpty) {
        _inputController.clear();
      }
      FocusScope.of(context).requestFocus(_inputFocus);
    } catch (error) {
      if (mounted) {
        _inputController.text = originalText;
        _inputController.selection = TextSelection.collapsed(
          offset: originalText.length,
        );
        FocusScope.of(context).requestFocus(_inputFocus);
      }
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      } else {
        _isSubmitting = false;
      }
    }
  }

  Future<void> _runItemMutation(
    String itemId,
    Future<void> Function() task,
  ) async {
    if (mounted) {
      setState(() {
        _pendingItemIds.add(itemId);
      });
    } else {
      _pendingItemIds.add(itemId);
    }
    try {
      await task();
    } finally {
      if (mounted) {
        setState(() {
          _pendingItemIds.remove(itemId);
        });
      } else {
        _pendingItemIds.remove(itemId);
      }
    }
  }

  Future<void> _handleToggle(AppointmentChecklistItem item, bool value) async {
    if (!_canToggle || widget.onToggle == null || widget.checklist == null) {
      return;
    }
    if (item.isCompleted == value) {
      return;
    }
    await _runItemMutation(
      item.id,
      () => widget.onToggle!(widget.checklist!.id, item.id, value),
    );
  }

  Future<void> _handleItemAction(
    _ChecklistItemAction action,
    AppointmentChecklistItem item,
  ) async {
    switch (action) {
      case _ChecklistItemAction.rename:
        await _promptRename(item);
        break;
      case _ChecklistItemAction.delete:
        await _confirmDelete(item);
        break;
    }
  }

  Future<void> _promptRename(AppointmentChecklistItem item) async {
    if (!_canRename || widget.onRename == null || widget.checklist == null) {
      return;
    }
    final controller = TextEditingController(text: item.label);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifica attività'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value),
            decoration: const InputDecoration(hintText: 'Descrizione attività'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    final trimmed = result?.trim();
    if (trimmed == null) {
      return;
    }
    if (trimmed.isEmpty) {
      await _confirmDelete(item);
      return;
    }
    if (trimmed == item.label.trim()) {
      return;
    }
    await _runItemMutation(
      item.id,
      () => widget.onRename!(widget.checklist!.id, item.id, trimmed),
    );
  }

  Future<void> _confirmDelete(AppointmentChecklistItem item) async {
    if (!_canDelete || widget.onDelete == null || widget.checklist == null) {
      return;
    }
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Elimina attività'),
                content: Text(
                  'Vuoi rimuovere "${item.label}" dalla checklist?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Annulla'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Elimina'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await _runItemMutation(
      item.id,
      () => widget.onDelete!(widget.checklist!.id, item.id),
    );
  }

  Widget _buildItemRow(ThemeData theme, AppointmentChecklistItem item) {
    final isPending = _pendingItemIds.contains(item.id);
    final canToggle = _canToggle && !isPending;
    final canRename = _canRename && !isPending;
    final canDelete = _canDelete && !isPending;
    final baseStyle =
        widget.dense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium;
    final baseColor = baseStyle?.color ?? theme.colorScheme.onSurface;
    final displayColor =
        item.isCompleted ? baseColor.withValues(alpha: 0.6) : baseColor;
    final textStyle = baseStyle?.copyWith(
      decoration:
          item.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
      color: displayColor,
    );

    final rowChildren = <Widget>[
      Checkbox(
        visualDensity:
            widget.dense
                ? const VisualDensity(horizontal: -4, vertical: -4)
                : null,
        value: item.isCompleted,
        onChanged:
            canToggle ? (value) => _handleToggle(item, value ?? false) : null,
      ),
      const SizedBox(width: 6),
      Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap:
              canToggle ? () => _handleToggle(item, !item.isCompleted) : null,
          onLongPress: canRename ? () => _promptRename(item) : null,
          child: Text(
            item.label,
            style: textStyle,
            maxLines: widget.dense ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    if (canRename || canDelete) {
      rowChildren.add(
        PopupMenuButton<_ChecklistItemAction>(
          tooltip: 'Azioni',
          enabled: !isPending,
          onSelected: (action) => _handleItemAction(action, item),
          icon: Icon(Icons.more_vert_rounded, size: widget.dense ? 18 : 20),
          itemBuilder:
              (context) => [
                if (canRename)
                  const PopupMenuItem(
                    value: _ChecklistItemAction.rename,
                    child: Text('Rinomina'),
                  ),
                if (canDelete)
                  const PopupMenuItem(
                    value: _ChecklistItemAction.delete,
                    child: Text('Elimina'),
                  ),
              ],
        ),
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isPending ? 0.6 : 1,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.dense ? 4 : 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: rowChildren,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allItems =
        widget.checklist?.items ?? const <AppointmentChecklistItem>[];
    final maxItems = widget.maxVisibleItems;
    final visibleItems =
        maxItems != null && allItems.length > maxItems
            ? allItems.take(maxItems).toList(growable: false)
            : allItems;
    final overflowCount = allItems.length - visibleItems.length;

    final children = <Widget>[];

    if (_canAdd) {
      children.add(
        TextField(
          controller: _inputController,
          focusNode: _inputFocus,
          enabled: !_isSubmitting,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitNewItem(),
          decoration: InputDecoration(
            hintText: 'Aggiungi attività',
            isDense: widget.dense,
            contentPadding:
                widget.dense
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon:
                _isSubmitting
                    ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : IconButton(
                      tooltip: 'Aggiungi attività',
                      icon: Icon(
                        Icons.add_task_rounded,
                        size: widget.dense ? 20 : 22,
                      ),
                      onPressed: _submitNewItem,
                    ),
          ),
        ),
      );
    }

    if (visibleItems.isEmpty) {
      if (_canAdd) {
        children.add(SizedBox(height: widget.dense ? 12 : 16));
      }
      children.add(
        Text(
          'Nessuna attività in elenco',
          style: (widget.dense
                  ? theme.textTheme.bodySmall
                  : theme.textTheme.bodyMedium)
              ?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
        ),
      );
    } else {
      if (_canAdd) {
        children.add(SizedBox(height: widget.dense ? 12 : 16));
      }
      for (final item in visibleItems) {
        children.add(_buildItemRow(theme, item));
      }
      if (overflowCount > 0) {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: widget.dense ? 2 : 4),
            child: Text(
              '+$overflowCount attività nascoste',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ),
        );
      }
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );

    final maxWidth = widget.maxWidth;
    if (maxWidth != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      );
    }

    return content;
  }
}

class _ChecklistDialogLauncher extends StatelessWidget {
  const _ChecklistDialogLauncher({
    required this.day,
    required this.dateLabel,
    required this.total,
    required this.completed,
    this.checklist,
    this.salonId,
    this.onAdd,
    this.onToggle,
    this.onRename,
    this.onDelete,
    this.compact = false,
  });

  final DateTime day;
  final String dateLabel;
  final int total;
  final int completed;
  final AppointmentDayChecklist? checklist;
  final String? salonId;
  final Future<void> Function(DateTime day, String label)? onAdd;
  final Future<void> Function(
    String checklistId,
    String itemId,
    bool isCompleted,
  )?
  onToggle;
  final Future<void> Function(String checklistId, String itemId, String label)?
  onRename;
  final Future<void> Function(String checklistId, String itemId)? onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final pending = max(total - completed, 0);
    final hasAccess =
        total > 0 ||
        onAdd != null ||
        onToggle != null ||
        onRename != null ||
        onDelete != null;
    if (!hasAccess) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final iconData =
        pending > 0 ? Icons.checklist_rounded : Icons.checklist_rounded;
    final iconColor =
        pending > 0
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
    final tooltip =
        total == 0
            ? 'Checklist vuota'
            : pending == 0
            ? 'Checklist completata'
            : '$pending attività da completare';
    final splashRadius = compact ? 20.0 : 24.0;
    final size = compact ? 28.0 : 32.0;
    final iconSize = compact ? 22.0 : 26.0;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: IconButton(
        onPressed: () => _openDialog(context),
        splashRadius: splashRadius,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: compact ? 32 : 40,
          minHeight: compact ? 32 : 40,
        ),
        icon: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.center,
                child: Icon(iconData, color: iconColor, size: iconSize),
              ),
              Positioned(
                right: -8,
                top: -8,
                child: _ChecklistCountBadge(
                  label: pending > 99 ? '99+' : '$pending',
                  highlight: pending > 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final mediaQuery = MediaQuery.of(dialogContext);
        final maxWidth = min(
          mediaQuery.size.width * 0.9,
          compact ? 440.0 : 520.0,
        );
        final maxHeight = min(mediaQuery.size.height * 0.85, 560.0);
        final normalizedDay = DateTime(day.year, day.month, day.day);
        final expectedSalonId = salonId ?? checklist?.salonId;

        return Consumer(
          builder: (context, ref, _) {
            final latestChecklist = ref.watch(
              appDataProvider.select((state) {
                return state.appointmentDayChecklists.firstWhereOrNull((entry) {
                  final sameDay =
                      entry.date.year == normalizedDay.year &&
                      entry.date.month == normalizedDay.month &&
                      entry.date.day == normalizedDay.day;
                  if (!sameDay) {
                    return false;
                  }
                  if (expectedSalonId != null &&
                      expectedSalonId.isNotEmpty &&
                      entry.salonId != expectedSalonId) {
                    return false;
                  }
                  return true;
                });
              }),
            );
            final effectiveChecklist = latestChecklist ?? checklist;
            final currentTotal = effectiveChecklist?.items.length ?? total;
            final currentCompleted =
                effectiveChecklist?.items
                    .where((item) => item.isCompleted)
                    .length ??
                completed;
            final currentPending = max(currentTotal - currentCompleted, 0);
            final summaryText =
                currentTotal == 0
                    ? 'Nessuna attività ancora pianificata.'
                    : currentPending == 0
                    ? 'Tutte le $currentTotal attività sono completate.'
                    : '$currentPending attività da completare su $currentTotal.';

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              child: _ChecklistDialogContent(
                day: day,
                dateLabel: dateLabel,
                summaryText: summaryText,
                checklist: effectiveChecklist,
                onAdd: onAdd,
                onToggle: onToggle,
                onRename: onRename,
                onDelete: onDelete,
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
            );
          },
        );
      },
    );
  }
}

class _ChecklistDialogContent extends StatefulWidget {
  const _ChecklistDialogContent({
    required this.day,
    required this.dateLabel,
    required this.summaryText,
    required this.maxWidth,
    required this.maxHeight,
    this.checklist,
    this.onAdd,
    this.onToggle,
    this.onRename,
    this.onDelete,
  });

  final DateTime day;
  final String dateLabel;
  final String summaryText;
  final double maxWidth;
  final double maxHeight;
  final AppointmentDayChecklist? checklist;
  final Future<void> Function(DateTime day, String label)? onAdd;
  final Future<void> Function(
    String checklistId,
    String itemId,
    bool isCompleted,
  )?
  onToggle;
  final Future<void> Function(String checklistId, String itemId, String label)?
  onRename;
  final Future<void> Function(String checklistId, String itemId)? onDelete;

  @override
  State<_ChecklistDialogContent> createState() =>
      _ChecklistDialogContentState();
}

class _ChecklistDialogContentState extends State<_ChecklistDialogContent> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      ),
      child: SizedBox(
        width: widget.maxWidth,
        height: widget.maxHeight,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Checklist giornaliera',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                widget.dateLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.summaryText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    primary: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: _ChecklistSection(
                        day: widget.day,
                        checklist: widget.checklist,
                        onAdd: widget.onAdd,
                        onToggle: widget.onToggle,
                        onRename: widget.onRename,
                        onDelete: widget.onDelete,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Chiudi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistCountBadge extends StatelessWidget {
  const _ChecklistCountBadge({required this.label, required this.highlight});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        highlight
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9);
    final foreground =
        highlight
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant;
    final border =
        highlight
            ? null
            : Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: border,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _WeekCompactView extends StatelessWidget {
  const _WeekCompactView({
    required this.dayData,
    required this.staff,
    required this.roles,
    required this.clientsWithOutstandingPayments,
    required this.clientsById,
    required this.servicesById,
    required this.categoriesById,
    required this.categoriesByName,
    required this.roomsById,
    required this.salonsById,
    required this.lockedAppointmentReasons,
    required this.dayChecklists,
    required this.onReschedule,
    required this.onEdit,
    required this.onCreate,
    required this.onTapLastMinuteSlot,
    required this.lastMinutePlaceholders,
    required this.lastMinuteSlots,
    required this.allAppointments,
    required this.anomalies,
    required this.statusColor,
    required this.slotMinutes,
    required this.slotExtent,
    required this.minMinute,
    required this.maxMinute,
    required this.verticalController,
    required this.interactionSlotMinutes,
    this.onAddChecklistItem,
    this.onToggleChecklistItem,
    this.onRenameChecklistItem,
    this.onDeleteChecklistItem,
    this.onCreateShift,
    this.onEditShift,
    this.onDeleteShift,
    this.onCreateAbsence,
    this.onEditAbsence,
    this.onDeleteAbsence,
  });

  final List<_WeekDayData> dayData;
  final List<StaffMember> staff;
  final List<StaffRole> roles;
  final Set<String> clientsWithOutstandingPayments;
  final Map<String, Client> clientsById;
  final Map<String, Service> servicesById;
  final Map<String, ServiceCategory> categoriesById;
  final Map<String, ServiceCategory> categoriesByName;
  final Map<String, String> roomsById;
  final Map<String, Salon> salonsById;
  final Map<String, String> lockedAppointmentReasons;
  final Map<DateTime, AppointmentDayChecklist> dayChecklists;
  final AppointmentRescheduleCallback onReschedule;
  final AppointmentTapCallback onEdit;
  final AppointmentSlotSelectionCallback onCreate;
  final Future<void> Function(LastMinuteSlot slot)? onTapLastMinuteSlot;
  final List<Appointment> lastMinutePlaceholders;
  final List<LastMinuteSlot> lastMinuteSlots;
  final List<Appointment> allAppointments;
  final Map<String, Set<AppointmentAnomalyType>> anomalies;
  final Color Function(AppointmentStatus status) statusColor;
  final int slotMinutes;
  final double slotExtent;
  final int minMinute;
  final int maxMinute;
  final ScrollController verticalController;
  final int interactionSlotMinutes;
  final Future<void> Function(DateTime day, String label)? onAddChecklistItem;
  final Future<void> Function(
    String checklistId,
    String itemId,
    bool isCompleted,
  )?
  onToggleChecklistItem;
  final Future<void> Function(String checklistId, String itemId, String label)?
  onRenameChecklistItem;
  final Future<void> Function(String checklistId, String itemId)?
  onDeleteChecklistItem;
  final Future<void> Function(StaffMember staff, DateTime day)? onCreateShift;
  final Future<void> Function(Shift shift)? onEditShift;
  final Future<void> Function(Shift shift)? onDeleteShift;
  final Future<void> Function(StaffMember staff, DateTime day)? onCreateAbsence;
  final Future<void> Function(StaffAbsence absence)? onEditAbsence;
  final Future<void> Function(StaffAbsence absence)? onDeleteAbsence;

  static const double _dayGap = 12;
  static const double _staffGap = 6;
  static const double _kDayHorizontalPadding = 8;
  static const double _kDayHeaderVerticalPadding = 10;
  static const double _kDayHeaderBottomPadding = 10;
  static const double _kDayBodyTopPadding = 0;
  static const double _kDayBodyBottomPadding = 10;
  static const double _kStaffHeaderHeight = 40;
  static const double _kStaffHeaderSpacing = 4;
  static const double _kStaffGridTopInset =
      _kStaffHeaderHeight + _kStaffHeaderSpacing;
  static const double _kMinStaffColumnWidth = 44;
  static const double _kScrollVerticalPadding = 20;

  @override
  Widget build(BuildContext context) {
    if (dayData.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final rolesById = {for (final role in roles) role.id: role};
    final slotCount = max(1, ((maxMinute - minMinute) / slotMinutes).ceil());
    final referenceDate = dayData.first.date;
    final referenceTimelineStart = referenceDate.add(
      Duration(minutes: minMinute),
    );
    final timeSlots = List.generate(
      slotCount,
      (index) =>
          referenceTimelineStart.add(Duration(minutes: index * slotMinutes)),
    );
    final dayHeaderColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.55,
    );
    final dayBodyColor = theme.colorScheme.surfaceContainerLowest.withValues(
      alpha: 0.45,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth =
            constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
        final double contentWidth = max(
          0.0,
          maxWidth - _WeekSchedule._timeScaleExtent - 12 - 2,
        );
        final double dayWidth = _computeDayWidth(contentWidth, dayData.length);
        final double dayInnerWidth = max(
          0.0,
          dayWidth - (_kDayHorizontalPadding * 2),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(
              context,
              theme,
              now,
              dayHeaderColor,
              contentWidth,
              dayWidth,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, expandedConstraints) {
                  final bool hasBoundedHeight =
                      expandedConstraints.maxHeight.isFinite;
                  final double resolvedGridHeight = slotCount * slotExtent;
                  final double availableGridHeight =
                      hasBoundedHeight
                          ? max(
                            0.0,
                            expandedConstraints.maxHeight -
                                (_kStaffGridTopInset +
                                    _kDayBodyBottomPadding +
                                    _kScrollVerticalPadding),
                          )
                          : resolvedGridHeight;
                  final bool enableScroll =
                      !hasBoundedHeight ||
                      resolvedGridHeight > availableGridHeight + 0.5;

                  return Scrollbar(
                    controller: verticalController,
                    thumbVisibility: enableScroll,
                    interactive: enableScroll,
                    child: SingleChildScrollView(
                      controller: verticalController,
                      physics:
                          enableScroll
                              ? const ClampingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: _kStaffGridTopInset,
                                bottom: _kDayBodyBottomPadding,
                              ),
                              child: _buildTimeScale(
                                theme,
                                timeSlots,
                                timeFormat,
                                resolvedGridHeight,
                                slotExtent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: contentWidth,
                              child: _buildDayColumns(
                                context,
                                theme,
                                now,
                                dayBodyColor,
                                dayWidth,
                                dayInnerWidth,
                                resolvedGridHeight,
                                slotExtent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  static double _computeDayWidth(double contentWidth, int dayCount) {
    if (dayCount <= 0) {
      return 0;
    }
    final double totalGap = dayCount <= 1 ? 0 : _dayGap * (dayCount - 1);
    final double available = max(0.0, contentWidth - totalGap);
    if (available <= 0) {
      return 0;
    }
    final double width = available / dayCount;
    return width;
  }

  Widget _buildHeaderRow(
    BuildContext context,
    ThemeData theme,
    DateTime now,
    Color dayHeaderColor,
    double contentWidth,
    double dayWidth,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _WeekSchedule._timeScaleExtent,
            child: Center(
              child: Text('Ora', style: theme.textTheme.labelMedium),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: contentWidth,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (
                  var dayIndex = 0;
                  dayIndex < dayData.length;
                  dayIndex++
                ) ...[
                  SizedBox(
                    width: dayWidth,
                    child: _buildDayHeader(
                      context,
                      theme,
                      now,
                      dayData[dayIndex],
                      dayHeaderColor,
                    ),
                  ),
                  if (dayIndex != dayData.length - 1)
                    const SizedBox(width: _dayGap),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(
    BuildContext context,
    ThemeData theme,
    DateTime now,
    _WeekDayData data,
    Color background,
  ) {
    final normalizedDate = DateUtils.dateOnly(data.date);
    final isToday = DateUtils.isSameDay(normalizedDate, now);
    final dateLabel = _formatCalendarDayLabel(data.date);
    final dayChecklist = dayChecklists[data.date];
    final checklistTotal = dayChecklist?.items.length ?? 0;
    final checklistCompleted =
        dayChecklist?.items.where((item) => item.isCompleted).length ?? 0;
    final hasChecklistItems = checklistTotal > 0;
    final canManageChecklist =
        onAddChecklistItem != null ||
        onToggleChecklistItem != null ||
        onRenameChecklistItem != null ||
        onDeleteChecklistItem != null;
    final showChecklistLauncher = hasChecklistItems || canManageChecklist;

    final borderColor =
        isToday
            ? theme.colorScheme.primary.withValues(alpha: 0.55)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        _kDayHorizontalPadding,
        _kDayHeaderVerticalPadding,
        _kDayHorizontalPadding,
        _kDayHeaderBottomPadding,
      ),
      decoration: BoxDecoration(
        color:
            isToday
                ? Color.alphaBlend(
                  theme.colorScheme.primary.withValues(alpha: 0.08),
                  background,
                )
                : background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.05),
        boxShadow:
            isToday
                ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isToday) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Oggi',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(dateLabel, style: theme.textTheme.titleMedium),
              ),
              if (showChecklistLauncher) ...[
                const SizedBox(width: 8),
                _ChecklistDialogLauncher(
                  day: data.date,
                  dateLabel: dateLabel,
                  checklist: dayChecklist,
                  total: checklistTotal,
                  completed: checklistCompleted,
                  salonId: dayChecklist?.salonId,
                  onAdd: onAddChecklistItem,
                  onToggle: onToggleChecklistItem,
                  onRename: onRenameChecklistItem,
                  onDelete: onDeleteChecklistItem,
                  compact: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumns(
    BuildContext context,
    ThemeData theme,
    DateTime now,
    Color dayBodyColor,
    double dayWidth,
    double dayInnerWidth,
    double gridHeight,
    double slotExtent,
  ) {
    if (dayData.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var dayIndex = 0; dayIndex < dayData.length; dayIndex++) ...[
          SizedBox(
            width: dayWidth,
            child: _buildDayBody(
              context,
              theme,
              now,
              dayData[dayIndex],
              dayBodyColor,
              dayInnerWidth,
              gridHeight,
              slotExtent,
            ),
          ),
          if (dayIndex != dayData.length - 1) const SizedBox(width: _dayGap),
        ],
      ],
    );
  }

  Widget _buildDayBody(
    BuildContext context,
    ThemeData theme,
    DateTime now,
    _WeekDayData data,
    Color background,
    double dayInnerWidth,
    double gridHeight,
    double slotExtent,
  ) {
    final isToday = DateUtils.isSameDay(data.date, now);
    final borderColor =
        isToday
            ? theme.colorScheme.primary.withValues(alpha: 0.4)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.35);
    final staffCount = staff.length;
    double effectiveGap = _staffGap;
    if (staffCount > 1) {
      final maxAllowedGap = dayInnerWidth / (staffCount - 1);
      if (effectiveGap > maxAllowedGap) {
        effectiveGap = max(0.0, maxAllowedGap);
      }
    } else {
      effectiveGap = 0.0;
    }
    final gapsWidth = effectiveGap * max(staffCount - 1, 0);
    final availableForColumns = max(0.0, dayInnerWidth - gapsWidth);
    double columnWidth =
        staffCount == 0 ? 0.0 : availableForColumns / staffCount;
    if (staffCount > 0) {
      final minRequiredWidth = _kMinStaffColumnWidth * staffCount;
      if (minRequiredWidth + gapsWidth <= dayInnerWidth) {
        columnWidth = max(columnWidth, _kMinStaffColumnWidth);
      }
    }
    final columnWidths = List<double>.filled(
      staffCount,
      columnWidth,
      growable: true,
    );
    if (staffCount > 0) {
      final totalWidth = (columnWidth * staffCount) + gapsWidth;
      final remainder = dayInnerWidth - totalWidth;
      if (remainder.abs() > 0.001) {
        final adjusted = max(0.0, columnWidths.last + remainder);
        columnWidths[staffCount - 1] = adjusted;
      }
    }
    final enforceMinWidth =
        staffCount > 0 &&
        (_kMinStaffColumnWidth * staffCount) + gapsWidth <= dayInnerWidth;
    assert(() {
      final totalColumnsWidth = columnWidths.fold<double>(
        0,
        (sum, value) => sum + value,
      );
      final composedWidth = totalColumnsWidth + gapsWidth;
      debugPrint(
        '[WeekCompact] staff=$staffCount inner=${dayInnerWidth.toStringAsFixed(2)} total=${composedWidth.toStringAsFixed(2)} gap=$gapsWidth remainder=${(dayInnerWidth - composedWidth).toStringAsFixed(2)} widths=${columnWidths.map((w) => w.toStringAsFixed(2)).join(',')}',
      );
      return true;
    }());

    return Container(
      decoration: BoxDecoration(
        color:
            isToday
                ? Color.alphaBlend(
                  theme.colorScheme.primary.withValues(alpha: 0.05),
                  background,
                )
                : background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(
        _kDayHorizontalPadding,
        _kDayBodyTopPadding,
        _kDayHorizontalPadding,
        _kDayBodyBottomPadding,
      ),
      child: _buildStaffColumns(
        context: context,
        theme: theme,
        data: data,
        dayInnerWidth: dayInnerWidth,
        columnWidths: columnWidths,
        columnGap: effectiveGap,
        gridHeight: gridHeight,
        slotExtent: slotExtent,
        enforceMinWidth: enforceMinWidth,
      ),
    );
  }

  Widget _buildStaffColumns({
    required BuildContext context,
    required ThemeData theme,
    required _WeekDayData data,
    required double dayInnerWidth,
    required List<double> columnWidths,
    required double columnGap,
    required double gridHeight,
    required double slotExtent,
    required bool enforceMinWidth,
  }) {
    final staffCount = staff.length;
    if (staffCount == 0) {
      return SizedBox(
        height: gridHeight,
        child: Center(
          child: Text(
            'Aggiungi membri dello staff per pianificare.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    Widget buildStaffColumn(int index) {
      final staffMember = staff[index];
      final initialsValue = _staffInitials(staffMember.fullName);
      final displayInitials = initialsValue.isEmpty ? '--' : initialsValue;
      final width = index < columnWidths.length ? columnWidths[index] : 0.0;
      final avatarSize = width <= 0 ? 0.0 : min(width, 28.0);
      final columnRadius = width <= 0 ? 8.0 : min(12.0, max(width / 2, 6.0));
      final flex = max(1, (width * 1000).round());
      final minWidthConstraint = enforceMinWidth ? _kMinStaffColumnWidth : 0.0;
      return Flexible(
        flex: flex,
        child: ConstrainedBox(
          constraints:
              minWidthConstraint > 0
                  ? BoxConstraints(minWidth: minWidthConstraint)
                  : const BoxConstraints(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StaffHeaderButton(
                enabled:
                    (onCreateShift != null ||
                        onEditShift != null ||
                        onDeleteShift != null) ||
                    (onCreateAbsence != null ||
                        onEditAbsence != null ||
                        onDeleteAbsence != null),
                tooltip:
                    'Gestisci turni e assenze per ${_formatCalendarDayLabel(data.date)}',
                onPressed: () async {
                  await _handleStaffDayManagement(
                    context,
                    staff: staffMember,
                    day: data.date,
                    shifts:
                        data.shiftsByStaff[staffMember.id] ?? const <Shift>[],
                    absences:
                        data.absencesByStaff[staffMember.id] ??
                        const <StaffAbsence>[],
                    roomsById: roomsById,
                    onCreateShift: onCreateShift,
                    onEditShift: onEditShift,
                    onDeleteShift: onDeleteShift,
                    onCreateAbsence: onCreateAbsence,
                    onEditAbsence: onEditAbsence,
                    onDeleteAbsence: onDeleteAbsence,
                  );
                },
                child: SizedBox(
                  height: _kStaffHeaderHeight,
                  child: Center(
                    child:
                        avatarSize <= 0
                            ? const SizedBox.shrink()
                            : Tooltip(
                              message: staffMember.fullName,
                              waitDuration: const Duration(milliseconds: 250),
                              child: SizedBox(
                                width: avatarSize,
                                height: avatarSize,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      max(avatarSize / 2, 8.0),
                                    ),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      displayInitials,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.4,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                  ),
                ),
              ),
              const SizedBox(height: _kStaffHeaderSpacing),
              SizedBox(
                height: gridHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.25 : 0.85,
                    ),
                    borderRadius: BorderRadius.circular(columnRadius),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                  child: _StaffDayColumn(
                    staffMember: staffMember,
                    appointments:
                        data.appointmentsByStaff[staffMember.id] ?? const [],
                    lastMinutePlaceholders: lastMinutePlaceholders,
                    lastMinuteSlots: lastMinuteSlots,
                    onTapLastMinuteSlot: onTapLastMinuteSlot,
                    shifts: data.shiftsByStaff[staffMember.id] ?? const [],
                    absences: data.absencesByStaff[staffMember.id] ?? const [],
                    timelineStart: data.date.add(Duration(minutes: minMinute)),
                    timelineEnd: data.date.add(Duration(minutes: maxMinute)),
                    slotMinutes: slotMinutes,
                    interactionSlotMinutes: interactionSlotMinutes,
                    slotExtent: slotExtent,
                    clientsWithOutstandingPayments:
                        clientsWithOutstandingPayments,
                    clientsById: clientsById,
                    servicesById: servicesById,
                    categoriesById: categoriesById,
                    categoriesByName: categoriesByName,
                    roomsById: roomsById,
                    salonsById: salonsById,
                    allAppointments: allAppointments,
                    statusColor: statusColor,
                    onReschedule: onReschedule,
                    onEdit: onEdit,
                    onCreate: onCreate,
                    anomalies: anomalies,
                    lockedAppointmentReasons: lockedAppointmentReasons,
                    openStart: data.openStart,
                    openEnd: data.openEnd,
                    compact: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: dayInnerWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            for (var index = 0; index < staffCount; index++) ...[
              buildStaffColumn(index),
              if (index != staffCount - 1) SizedBox(width: columnGap),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeScale(
    ThemeData theme,
    List<DateTime> timeSlots,
    DateFormat timeFormat,
    double gridHeight,
    double slotExtent,
  ) {
    return Container(
      width: _WeekSchedule._timeScaleExtent,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: SizedBox(
        height: gridHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(timeSlots.length, (index) {
              final slotTime = timeSlots[index];
              final showLabel = slotTime.minute == 0;
              return SizedBox(
                height: slotExtent,
                child: Center(
                  child: Text(
                    showLabel ? timeFormat.format(slotTime) : '',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _WeekOperatorBoardView extends StatelessWidget {
  const _WeekOperatorBoardView({
    required this.dayData,
    required this.staff,
    required this.roles,
    required this.clientsById,
    required this.servicesById,
    required this.roomsById,
    required this.lockedAppointmentReasons,
    required this.anomalies,
    required this.statusColor,
    required this.slotMinutes,
    required this.lastMinutePlaceholders,
    required this.onEdit,
    required this.onCreate,
    required this.minMinute,
    required this.verticalController,
  });

  final List<_WeekDayData> dayData;
  final List<StaffMember> staff;
  final List<StaffRole> roles;
  final Map<String, Client> clientsById;
  final Map<String, Service> servicesById;
  final Map<String, String> roomsById;
  final Map<String, String> lockedAppointmentReasons;
  final Map<String, Set<AppointmentAnomalyType>> anomalies;
  final Color Function(AppointmentStatus status) statusColor;
  final int slotMinutes;
  final List<Appointment> lastMinutePlaceholders;
  final AppointmentTapCallback onEdit;
  final AppointmentSlotSelectionCallback onCreate;
  final int minMinute;
  final ScrollController verticalController;

  static const double _kOperatorColumnMinWidth = 240;
  static const double _kDayColumnMinWidth = 200;
  static const double _kDayGap = 12;
  static final DateFormat _timeLabelFormat = DateFormat('HH:mm', 'it_IT');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (dayData.isEmpty) {
      return const SizedBox.shrink();
    }
    if (staff.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nessun operatore disponibile per il periodo selezionato.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final placeholderIds =
        lastMinutePlaceholders.map((appointment) => appointment.id).toSet();
    final rolesById = {for (final role in roles) role.id: role};

    return ScrollConfiguration(
      behavior: const _CompactMacScrollBehavior(),
      child: Scrollbar(
        controller: verticalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: verticalController,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dayCount = dayData.length;
              final availableWidth =
                  constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : MediaQuery.sizeOf(context).width;
              final operatorWidth = _kOperatorColumnMinWidth;
              final gapsWidth = max(0, dayCount - 1) * _kDayGap;
              final minRequiredWidth =
                  operatorWidth + (dayCount * _kDayColumnMinWidth) + gapsWidth;
              final needsHorizontalScroll = minRequiredWidth > availableWidth;
              final remainingWidth = max(
                0.0,
                availableWidth - operatorWidth - gapsWidth,
              );
              final dayWidth =
                  needsHorizontalScroll || dayCount == 0
                      ? _kDayColumnMinWidth
                      : max(
                        _kDayColumnMinWidth,
                        remainingWidth / max(1, dayCount),
                      );

              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(theme, operatorWidth, dayWidth),
                  const SizedBox(height: 12),
                  ...staff.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildStaffRow(
                        context,
                        theme,
                        member,
                        rolesById,
                        placeholderIds,
                        operatorWidth,
                        dayWidth,
                      ),
                    ),
                  ),
                ],
              );

              if (!needsHorizontalScroll) {
                return content;
              }

              final totalWidth =
                  operatorWidth + (dayCount * dayWidth) + gapsWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(width: totalWidth, child: content),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(
    ThemeData theme,
    double operatorWidth,
    double dayWidth,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: operatorWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Operatore',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffRow(
    BuildContext context,
    ThemeData theme,
    StaffMember member,
    Map<String, StaffRole> rolesById,
    Set<String> placeholderIds,
    double operatorWidth,
    double dayWidth,
  ) {
    final weekAppointments = <Appointment>[];
    final placeholderAppointments = <Appointment>[];
    for (final day in dayData) {
      final appointmentsForDay = day.appointmentsByStaff[member.id] ?? const [];
      weekAppointments.addAll(appointmentsForDay);
      for (final placeholder in lastMinutePlaceholders) {
        final sameStaff = placeholder.staffId == member.id;
        final sameDay = DateUtils.isSameDay(placeholder.start, day.date);
        if (sameStaff && sameDay) {
          placeholderAppointments.add(placeholder);
        }
      }
    }

    final totalDurationMinutes = weekAppointments.fold<int>(
      0,
      (running, appointment) =>
          running + appointment.end.difference(appointment.start).inMinutes,
    );
    final totalAppointments = weekAppointments.length;
    final placeholderCount = placeholderAppointments.length;
    final roleNames =
        member.roleIds
            .map((roleId) => rolesById[roleId]?.displayName)
            .whereType<String>()
            .toSet()
            .toList();
    final summaryChips = <Widget>[];
    if (totalAppointments > 0) {
      summaryChips.add(
        _WeekSchedule._summaryChip(
          theme: theme,
          icon: Icons.event_available_rounded,
          label: '$totalAppointments appuntamenti',
        ),
      );
    }
    if (placeholderCount > 0) {
      summaryChips.add(
        _WeekSchedule._summaryChip(
          theme: theme,
          icon: Icons.flash_on_rounded,
          label: '$placeholderCount slot last-minute',
          background: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
          foreground: theme.colorScheme.onPrimaryContainer,
        ),
      );
    }
    if (totalDurationMinutes > 0) {
      final totalHours = totalDurationMinutes / 60;
      summaryChips.add(
        _WeekSchedule._summaryChip(
          theme: theme,
          icon: Icons.schedule_rounded,
          label:
              totalHours >= 5
                  ? '${totalHours.round()}h prenotate'
                  : '${totalHours.toStringAsFixed(1)}h prenotate',
        ),
      );
    }

    final rowChildren = <Widget>[
      SizedBox(
        width: operatorWidth,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.fullName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (roleNames.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  roleNames.join(', '),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (summaryChips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: summaryChips),
              ],
            ],
          ),
        ),
      ),
    ];

    for (var index = 0; index < dayData.length; index++) {
      final day = dayData[index];
      final appointmentsForDay = day.appointmentsByStaff[member.id] ?? const [];
      final placeholdersForDay = lastMinutePlaceholders.where(
        (placeholder) =>
            placeholder.staffId == member.id &&
            DateUtils.isSameDay(placeholder.start, day.date),
      );
      final shiftsForDay = day.shiftsByStaff[member.id] ?? const [];
      final absencesForDay = day.absencesByStaff[member.id] ?? const [];

      rowChildren..add(
        SizedBox(
          width: dayWidth,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _OperatorDayCell(
              staffMember: member,
              day: day,
              appointments: appointmentsForDay,
              placeholderAppointments: placeholdersForDay.toList(),
              shifts: shiftsForDay,
              absences: absencesForDay,
              clientsById: clientsById,
              servicesById: servicesById,
              roomsById: roomsById,
              lockedAppointmentReasons: lockedAppointmentReasons,
              anomalies: anomalies,
              statusColor: statusColor,
              slotMinutes: slotMinutes,
              onEdit: onEdit,
              onCreate: onCreate,
              minMinute: minMinute,
              placeholderIds: placeholderIds,
            ),
          ),
        ),
      );
      if (index != dayData.length - 1) {
        rowChildren.add(const SizedBox(width: _kDayGap));
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowChildren,
    );
  }
}

class _OperatorDayCell extends StatelessWidget {
  const _OperatorDayCell({
    required this.staffMember,
    required this.day,
    required this.appointments,
    required this.placeholderAppointments,
    required this.shifts,
    required this.absences,
    required this.clientsById,
    required this.servicesById,
    required this.roomsById,
    required this.lockedAppointmentReasons,
    required this.anomalies,
    required this.statusColor,
    required this.slotMinutes,
    required this.onEdit,
    required this.onCreate,
    required this.minMinute,
    required this.placeholderIds,
  });

  final StaffMember staffMember;
  final _WeekDayData day;
  final List<Appointment> appointments;
  final List<Appointment> placeholderAppointments;
  final List<Shift> shifts;
  final List<StaffAbsence> absences;
  final Map<String, Client> clientsById;
  final Map<String, Service> servicesById;
  final Map<String, String> roomsById;
  final Map<String, String> lockedAppointmentReasons;
  final Map<String, Set<AppointmentAnomalyType>> anomalies;
  final Color Function(AppointmentStatus status) statusColor;
  final int slotMinutes;
  final AppointmentTapCallback onEdit;
  final AppointmentSlotSelectionCallback onCreate;
  final int minMinute;
  final Set<String> placeholderIds;

  static final DateFormat _timeLabelFormat =
      _WeekOperatorBoardView._timeLabelFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final normalizedDay = DateUtils.dateOnly(day.date);
    final isToday = DateUtils.isSameDay(normalizedDay, now);
    final placeholderIdSet =
        placeholderAppointments.map((appointment) => appointment.id).toSet();

    final combinedById = <String, Appointment>{};
    for (final appointment in appointments) {
      combinedById[appointment.id] = appointment;
    }
    for (final placeholder in placeholderAppointments) {
      combinedById.putIfAbsent(placeholder.id, () => placeholder);
    }
    final combined =
        combinedById.values.toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final slotDuration = Duration(minutes: slotMinutes);
    final fallbackStart = day.date.add(Duration(minutes: minMinute));
    final defaultStart = day.openStart ?? day.bounds.start;
    final selectionStart =
        defaultStart.isBefore(fallbackStart) ? fallbackStart : defaultStart;
    final selectionEnd = selectionStart.add(slotDuration);

    final infoChips = <Widget>[];
    if (shifts.isNotEmpty) {
      final tooltip = shifts
          .map(
            (shift) =>
                '${_timeLabelFormat.format(shift.start)} - ${_timeLabelFormat.format(shift.end)}',
          )
          .join('\n');
      final label =
          shifts.length == 1 ? 'Turno attivo' : '${shifts.length} turni';
      infoChips.add(
        _WeekSchedule._summaryChip(
          theme: theme,
          icon: Icons.badge_rounded,
          label: label,
          tooltip: tooltip,
        ),
      );
    }
    if (absences.isNotEmpty) {
      final tooltip = absences.map(_describeAbsence).join('\n\n');
      final label =
          absences.length == 1
              ? absences.first.type.label
              : '${absences.length} assenze';
      infoChips.add(
        _WeekSchedule._summaryChip(
          theme: theme,
          icon: Icons.event_busy_rounded,
          label: label,
          tooltip: tooltip,
          background: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
          foreground: theme.colorScheme.onErrorContainer,
        ),
      );
    }

    final appointmentWidgets = <Widget>[];
    for (var index = 0; index < combined.length; index++) {
      final appointment = combined[index];
      final isPlaceholder =
          placeholderIdSet.contains(appointment.id) ||
          placeholderIds.contains(appointment.id);
      appointmentWidgets.add(
        _OperatorAppointmentTile(
          appointment: appointment,
          client: clientsById[appointment.clientId],
          serviceNames: _serviceNames(appointment),
          roomName:
              appointment.roomId != null
                  ? roomsById[appointment.roomId!]
                  : null,
          isPlaceholder: isPlaceholder,
          anomalies:
              anomalies[appointment.id] ?? const <AppointmentAnomalyType>{},
          lockReason: lockedAppointmentReasons[appointment.id],
          statusColor: statusColor(appointment.status),
          onTap: () => onEdit(appointment),
        ),
      );
      if (index != combined.length - 1) {
        appointmentWidgets.add(const SizedBox(height: 8));
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isToday
                  ? theme.colorScheme.primary.withValues(alpha: 0.55)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow:
            isToday
                ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCalendarDayLabel(day.date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isToday)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Oggi',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Nuovo appuntamento',
                onPressed:
                    () => onCreate(
                      AppointmentSlotSelection(
                        start: selectionStart,
                        end: selectionEnd,
                        staffId: staffMember.id,
                      ),
                    ),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          if (infoChips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: infoChips),
          ],
          const SizedBox(height: 12),
          if (appointmentWidgets.isEmpty)
            _buildEmptyState(theme)
          else
            Column(children: appointmentWidgets),
        ],
      ),
    );
  }

  static String _describeAbsence(StaffAbsence absence) {
    final buffer = StringBuffer(absence.type.label);
    if (!absence.isAllDay || !absence.isSingleDay) {
      buffer.write(
        ' • ${_timeLabelFormat.format(absence.start)} - ${_timeLabelFormat.format(absence.end)}',
      );
    }
    if (absence.notes != null && absence.notes!.trim().isNotEmpty) {
      buffer.write('\n${absence.notes!.trim()}');
    }
    return buffer.toString();
  }

  List<String> _serviceNames(Appointment appointment) {
    final names = <String>[];
    for (final serviceId in appointment.serviceIds) {
      final service = servicesById[serviceId];
      if (service != null && service.name.isNotEmpty) {
        names.add(service.name);
      }
    }
    return names;
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Center(
        child: Text(
          'Nessun appuntamento',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _OperatorAppointmentTile extends StatelessWidget {
  const _OperatorAppointmentTile({
    required this.appointment,
    required this.client,
    required this.serviceNames,
    required this.roomName,
    required this.isPlaceholder,
    required this.anomalies,
    required this.lockReason,
    required this.statusColor,
    required this.onTap,
  });

  final Appointment appointment;
  final Client? client;
  final List<String> serviceNames;
  final String? roomName;
  final bool isPlaceholder;
  final Set<AppointmentAnomalyType> anomalies;
  final String? lockReason;
  final Color statusColor;
  final VoidCallback onTap;

  static final DateFormat _timeFormat = DateFormat('HH:mm', 'it_IT');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel =
        '${_timeFormat.format(appointment.start)} - ${_timeFormat.format(appointment.end)}';
    final serviceLabel =
        serviceNames.isNotEmpty ? serviceNames.join(', ') : null;
    final subtitleColor = theme.colorScheme.onSurfaceVariant;
    final issues =
        anomalies.toList()..sort((a, b) => a.index.compareTo(b.index));
    final isCancelled = appointment.status == AppointmentStatus.cancelled;

    return Material(
      color:
          isPlaceholder
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
              : isCancelled
              ? Colors.transparent
              : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      timeLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.circle, size: 10, color: statusColor),
                  if (isPlaceholder) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Slot last-minute disponibile',
                      child: Icon(
                        Icons.flash_on_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                client?.fullName ?? 'Slot disponibile',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (serviceLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  serviceLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                  ),
                ),
              ],
              if (roomName != null && roomName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Stanza: $roomName',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                  ),
                ),
              ],
              if (issues.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children:
                      issues
                          .map(
                            (issue) => _WeekSchedule._summaryChip(
                              theme: theme,
                              icon: issue.icon,
                              label: issue.label,
                              background: theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.45),
                              foreground: theme.colorScheme.onErrorContainer,
                              tooltip: issue.description,
                            ),
                          )
                          .toList(),
                ),
              ],
              if (lockReason != null && lockReason!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lockReason!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekDayData {
  _WeekDayData({
    required this.date,
    required this.appointmentsByStaff,
    required this.shiftsByStaff,
    required this.absencesByStaff,
    required this.openStart,
    required this.openEnd,
    required this.bounds,
    required this.scheduleEntry,
  });

  final DateTime date;
  final Map<String, List<Appointment>> appointmentsByStaff;
  final Map<String, List<Shift>> shiftsByStaff;
  final Map<String, List<StaffAbsence>> absencesByStaff;
  final DateTime? openStart;
  final DateTime? openEnd;
  final _TimelineBounds bounds;
  final SalonDailySchedule? scheduleEntry;
}

class _StaffDayColumn extends StatefulWidget {
  const _StaffDayColumn({
    required this.staffMember,
    required this.appointments,
    required this.lastMinutePlaceholders,
    required this.lastMinuteSlots,
    required this.allAppointments,
    required this.shifts,
    required this.absences,
    required this.timelineStart,
    required this.timelineEnd,
    required this.slotMinutes,
    required this.interactionSlotMinutes,
    required this.slotExtent,
    required this.clientsWithOutstandingPayments,
    required this.clientsById,
    required this.servicesById,
    required this.categoriesById,
    required this.categoriesByName,
    required this.roomsById,
    required this.salonsById,
    required this.statusColor,
    required this.lockedAppointmentReasons,
    required this.onReschedule,
    required this.onEdit,
    required this.onCreate,
    required this.onTapLastMinuteSlot,
    required this.anomalies,
    this.openStart,
    this.openEnd,
    this.compact = false,
  });

  final StaffMember staffMember;
  final List<Appointment> appointments;
  final List<Appointment> lastMinutePlaceholders;
  final List<LastMinuteSlot> lastMinuteSlots;
  final Future<void> Function(LastMinuteSlot slot)? onTapLastMinuteSlot;
  final List<Appointment> allAppointments;
  final List<Shift> shifts;
  final List<StaffAbsence> absences;
  final DateTime timelineStart;
  final DateTime timelineEnd;
  final int slotMinutes;
  final int interactionSlotMinutes;
  final double slotExtent;
  final Set<String> clientsWithOutstandingPayments;
  final Map<String, Client> clientsById;
  final Map<String, Service> servicesById;
  final Map<String, ServiceCategory> categoriesById;
  final Map<String, ServiceCategory> categoriesByName;
  final Map<String, String> roomsById;
  final Map<String, Salon> salonsById;
  final Color Function(AppointmentStatus status) statusColor;
  final Map<String, String> lockedAppointmentReasons;
  final AppointmentRescheduleCallback onReschedule;
  final AppointmentTapCallback onEdit;
  final AppointmentSlotSelectionCallback onCreate;
  final Map<String, Set<AppointmentAnomalyType>> anomalies;
  final DateTime? openStart;
  final DateTime? openEnd;
  final bool compact;

  @override
  State<_StaffDayColumn> createState() => _StaffDayColumnState();
}

class _StaffDayColumnState extends State<_StaffDayColumn> {
  static final DateFormat _timeLabel = DateFormat('HH:mm', 'it_IT');
  DateTime? _hoverStart;
  DateTime? _dragPreviewStart;
  Duration? _dragPreviewDuration;
  bool _dragPreviewHasConflict = false;
  bool _isDragging = false;
  Appointment? _dragPreviewAppointment;

  double get _totalMinutes =>
      widget.timelineEnd.difference(widget.timelineStart).inMinutes.toDouble();

  bool _hasShiftDuring(DateTime start, DateTime end) {
    for (final shift in widget.shifts) {
      if (_overlapsRange(shift.start, shift.end, start, end)) {
        return true;
      }
    }
    return false;
  }

  void _setDragging(bool value) {
    if (_isDragging != value) {
      setState(() {
        _isDragging = value;
        if (!value) {
          _dragPreviewStart = null;
          _dragPreviewDuration = null;
          _dragPreviewHasConflict = false;
          _dragPreviewAppointment = null;
        } else {
          _hoverStart = null;
        }
      });
    }
  }

  void _handleHover(PointerHoverEvent event, double gridHeight) {
    if (_isDragging) {
      if (_hoverStart != null) {
        setState(() => _hoverStart = null);
      }
      return;
    }
    final totalMinutes = _totalMinutes;
    if (totalMinutes <= 0) {
      return;
    }
    final dy = event.localPosition.dy.clamp(0.0, gridHeight);
    var minuteOffset = (dy / gridHeight) * totalMinutes;
    final slotDuration = widget.interactionSlotMinutes.toDouble();
    if (totalMinutes > slotDuration) {
      minuteOffset = minuteOffset.clamp(0.0, totalMinutes - slotDuration);
    }
    final snappedMinutes =
        (minuteOffset / widget.interactionSlotMinutes).round() *
        widget.interactionSlotMinutes;
    final hoverStart = widget.timelineStart.add(
      Duration(minutes: snappedMinutes.toInt()),
    );
    if (_hoverStart != hoverStart) {
      setState(() => _hoverStart = hoverStart);
    }
  }

  void _clearHover(PointerExitEvent event) {
    if (_hoverStart != null) {
      setState(() => _hoverStart = null);
    }
  }

  void _handleTap(TapUpDetails details, double gridHeight) {
    if (_isDragging) {
      return;
    }
    final totalMinutes = _totalMinutes;
    if (totalMinutes <= 0) {
      return;
    }
    final localDy = details.localPosition.dy.clamp(0.0, gridHeight);
    var minuteOffset = (localDy / gridHeight) * totalMinutes;
    final slotDuration = widget.interactionSlotMinutes.toDouble();
    if (totalMinutes > slotDuration) {
      minuteOffset = minuteOffset.clamp(0.0, totalMinutes - slotDuration);
    }
    final snappedMinutes =
        (minuteOffset / widget.interactionSlotMinutes).round() *
        widget.interactionSlotMinutes;
    final tapMoment = widget.timelineStart.add(
      Duration(minutes: minuteOffset.round()),
    );

    final tappedHold = widget.lastMinuteSlots.firstWhereOrNull((slot) {
      if (slot.operatorId != widget.staffMember.id) {
        return false;
      }
      if (!slot.isAvailable) {
        return false;
      }
      final start = slot.start;
      final end = slot.end;
      final matchesStart = !tapMoment.isBefore(start);
      final matchesEnd = tapMoment.isBefore(end);
      return matchesStart && matchesEnd;
    });
    if (tappedHold != null && widget.onTapLastMinuteSlot != null) {
      widget.onTapLastMinuteSlot!(tappedHold);
      return;
    }

    final newStart = widget.timelineStart.add(
      Duration(minutes: snappedMinutes.toInt()),
    );
    final newEnd = newStart.add(
      Duration(minutes: widget.interactionSlotMinutes),
    );
    final hasOverlap = widget.appointments.any(
      (appointment) =>
          appointment.start.isBefore(newEnd) &&
          appointment.end.isAfter(newStart),
    );
    if (hasOverlap) {
      return;
    }
    widget.onCreate(
      AppointmentSlotSelection(
        start: newStart,
        end: newEnd,
        staffId: widget.staffMember.id,
      ),
    );
  }

  String? _slotConflictMessage(
    DateTime start,
    DateTime end,
    Appointment movingAppointment,
    StaffMember targetStaff,
  ) {
    final service = widget.servicesById[movingAppointment.serviceId];
    if (service != null && service.staffRoles.isNotEmpty) {
      final allowed = _hasAllowedRole(targetStaff, service.staffRoles);
      if (!allowed) {
        return 'L\'operatore selezionato non può erogare il servizio scelto. Scegli un altro operatore.';
      }
    }

    final hasStaffOverlap = hasStaffBookingConflict(
      appointments: widget.allAppointments,
      staffId: targetStaff.id,
      start: start,
      end: end,
      excludeAppointmentId: movingAppointment.id,
    );
    if (hasStaffOverlap) {
      return 'Impossibile riprogrammare: operatore già occupato in quel periodo';
    }

    final hasClientOverlap = hasClientBookingConflict(
      appointments: widget.allAppointments,
      clientId: movingAppointment.clientId,
      start: start,
      end: end,
      excludeAppointmentId: movingAppointment.id,
    );
    if (hasClientOverlap) {
      return 'Impossibile riprogrammare: il cliente ha già un appuntamento in quel periodo';
    }

    if (service == null || service.requiredEquipmentIds.isEmpty) {
      return null;
    }
    final salon = widget.salonsById[movingAppointment.salonId];
    if (salon == null) {
      return null;
    }

    final result = EquipmentAvailabilityChecker.check(
      salon: salon,
      service: service,
      allServices: widget.servicesById.values,
      appointments: widget.allAppointments,
      start: start,
      end: end,
      excludeAppointmentId: movingAppointment.id,
    );
    if (!result.hasConflicts) {
      return null;
    }
    final equipmentLabel = result.blockingEquipment.join(', ');
    final baseMessage =
        equipmentLabel.isEmpty
            ? 'Macchinario non disponibile per questo orario.'
            : 'Macchinario non disponibile per questo orario: $equipmentLabel.';
    return '$baseMessage Scegli un altro slot.';
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _totalMinutes;
    final totalSlots = max(1, (totalMinutes / widget.slotMinutes).ceil());
    final gridHeight = totalSlots * widget.slotExtent;
    final theme = Theme.of(context);
    final double pixelsPerMinute = widget.slotExtent / widget.slotMinutes;

    Widget? openOverlay;
    if (widget.openStart != null && widget.openEnd != null) {
      final segment = _segmentWithinTimeline(
        widget.openStart!,
        widget.openEnd!,
        widget.timelineStart,
        widget.timelineEnd,
      );
      if (segment != null) {
        final top =
            segment.start.difference(widget.timelineStart).inMinutes *
            pixelsPerMinute;
        final height = max(
          widget.slotExtent,
          segment.end.difference(segment.start).inMinutes * pixelsPerMinute,
        );
        openOverlay = Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
            ),
          ),
        );
      }
    }

    final dragStart = _dragPreviewStart;
    final dragDuration = _dragPreviewDuration;
    final dragAppointment = _dragPreviewAppointment;
    Widget? dragOverlay;
    if (dragStart != null && dragDuration != null && dragAppointment != null) {
      final dragEnd = dragStart.add(dragDuration);
      final segment = _segmentWithinTimeline(
        dragStart,
        dragEnd,
        widget.timelineStart,
        widget.timelineEnd,
      );
      if (segment != null) {
        final top =
            segment.start.difference(widget.timelineStart).inMinutes *
            pixelsPerMinute;
        final height = max(
          widget.slotExtent,
          segment.end.difference(segment.start).inMinutes * pixelsPerMinute,
        );
        final previewed = dragAppointment.copyWith(
          start: dragStart,
          end: dragEnd,
        );
        final anomalies =
            widget.anomalies[dragAppointment.id] ??
            const <AppointmentAnomalyType>{};
        final roomName =
            previewed.roomId != null
                ? widget.roomsById[previewed.roomId!]
                : null;
        final services =
            previewed.serviceIds
                .map((id) => widget.servicesById[id])
                .whereType<Service>()
                .toList();
        final previewService =
            services.isNotEmpty
                ? services.first
                : widget.servicesById[previewed.serviceId];
        final hasOutstandingPayments = widget.clientsWithOutstandingPayments
            .contains(previewed.clientId);
        final visibleMinutes = max(
          1,
          segment.end.difference(segment.start).inMinutes,
        );
        dragOverlay = Positioned(
          top: top,
          left: 0,
          right: 0,
          child: SizedBox(
            height: height,
            child: Opacity(
              opacity: _dragPreviewHasConflict ? 0.65 : 1,
              child: _AppointmentCard(
                appointment: previewed,
                client: widget.clientsById[previewed.clientId],
                service: previewService,
                services: services,
                staff: widget.staffMember,
                roomName: roomName,
                height: height,
                visibleDurationMinutes: visibleMinutes,
                anomalies: anomalies,
                lockReason: null,
                highlight: true,
                categoriesById: widget.categoriesById,
                categoriesByName: widget.categoriesByName,
                hideContent: false,
                hasOutstandingPayments: hasOutstandingPayments,
              ),
            ),
          ),
        );
      }
    }

    final hoverStart = _hoverStart;
    Widget? hoverOverlay;
    if (hoverStart != null) {
      final hoverEnd = hoverStart.add(
        Duration(minutes: widget.interactionSlotMinutes),
      );
      final segment = _segmentWithinTimeline(
        hoverStart,
        hoverEnd,
        widget.timelineStart,
        widget.timelineEnd,
      );
      if (segment != null) {
        final top =
            segment.start.difference(widget.timelineStart).inMinutes *
            pixelsPerMinute;
        final isBusyAppointments = widget.appointments.any(
          (appointment) =>
              appointment.start.isBefore(hoverEnd) &&
              appointment.end.isAfter(hoverStart),
        );
        final isBusyHolds = widget.lastMinutePlaceholders.any(
          (hold) =>
              hold.staffId == widget.staffMember.id &&
              hold.start.isBefore(hoverEnd) &&
              hold.end.isAfter(hoverStart),
        );
        final isBusy = isBusyAppointments || isBusyHolds;
        final fillColor =
            isBusy
                ? theme.colorScheme.error.withValues(alpha: 0.08)
                : theme.colorScheme.primary.withValues(alpha: 0.08);
        final outlineColor =
            isBusy
                ? theme.colorScheme.error.withValues(alpha: 0.35)
                : theme.colorScheme.primary.withValues(alpha: 0.25);
        final labelTextColor =
            isBusy
                ? theme.colorScheme.error.withValues(alpha: 0.9)
                : theme.colorScheme.primary.withValues(alpha: 0.85);
        final labelBackground = theme.colorScheme.surface.withValues(
          alpha: 0.94,
        );
        final slotLabel = _timeLabel.format(hoverStart);
        final hoverDurationMinutes =
            segment.end.difference(segment.start).inMinutes;
        final hoverHeight = max(
          pixelsPerMinute * widget.interactionSlotMinutes,
          hoverDurationMinutes * pixelsPerMinute,
        );
        hoverOverlay = Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: hoverHeight,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: outlineColor, width: 1.5),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: labelBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: outlineColor.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      slotLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: labelTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return MouseRegion(
      onHover: (event) => _handleHover(event, gridHeight),
      onExit: _clearHover,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTapUp: (details) => _handleTap(details, gridHeight),
        child: DragTarget<_AppointmentDragData>(
          onWillAcceptWithDetails: (_) => true,
          onMove: (details) {
            if (!_isDragging) {
              _setDragging(true);
            }
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox == null) {
              return;
            }
            final payload = details.data;
            final localOffset = renderBox.globalToLocal(details.offset);
            final clampedDy = localOffset.dy.clamp(0.0, renderBox.size.height);
            final totalMinutes = _totalMinutes;
            if (totalMinutes <= 0) {
              return;
            }
            var minuteOffset =
                (clampedDy / renderBox.size.height) * totalMinutes;
            final durationMinutes = payload.duration.inMinutes.toDouble();
            final maxStartMinutes = max(0.0, totalMinutes - durationMinutes);
            if (totalMinutes > durationMinutes) {
              minuteOffset = min(max(minuteOffset, 0.0), maxStartMinutes);
            } else {
              minuteOffset = 0.0;
            }
            final slotMinutes = widget.interactionSlotMinutes;
            final snappedMinutes =
                (minuteOffset / slotMinutes).round() * slotMinutes;
            final maxStartMinutesInt = maxStartMinutes.floor();
            final clampedMinutes = max(
              0,
              min(snappedMinutes, maxStartMinutesInt),
            );
            final previewStart = widget.timelineStart.add(
              Duration(minutes: clampedMinutes),
            );
            final previewEnd = previewStart.add(payload.duration);
            final hasConflict =
                _slotConflictMessage(
                  previewStart,
                  previewEnd,
                  payload.appointment,
                  widget.staffMember,
                ) !=
                null;
            if (_dragPreviewStart != previewStart ||
                _dragPreviewDuration != payload.duration ||
                _dragPreviewHasConflict != hasConflict ||
                _dragPreviewAppointment != payload.appointment) {
              setState(() {
                _dragPreviewStart = previewStart;
                _dragPreviewDuration = payload.duration;
                _dragPreviewHasConflict = hasConflict;
                _dragPreviewAppointment = payload.appointment;
              });
            }
          },
          onLeave: (_) {
            _setDragging(false);
          },
          builder: (context, candidateData, rejectedData) {
            final columnBackground = theme.colorScheme.surface.withValues(
              alpha: 0.96,
            );
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: gridHeight,
                color: columnBackground,
                child: Stack(
                  children: [
                    Column(
                      children: List.generate(totalSlots, (index) {
                        final DateTime slotStart = widget.timelineStart.add(
                          Duration(minutes: index * widget.slotMinutes),
                        );
                        final bool isHourBoundary = slotStart.minute == 0;
                        final DateTime slotEnd = slotStart.add(
                          Duration(minutes: widget.slotMinutes),
                        );
                        final bool hasShift = _hasShiftDuring(
                          slotStart,
                          slotEnd,
                        );
                        BorderSide topBorder = BorderSide.none;
                        BorderSide bottomBorder = BorderSide.none;
                        if (hasShift) {
                          final bool isDark =
                              theme.brightness == Brightness.dark;
                          final double hourTopAlpha = isDark ? 0.45 : 0.32;
                          final double hourBottomAlpha = isDark ? 0.34 : 0.24;
                          final double minorTopAlpha = isDark ? 0.28 : 0.18;
                          final double minorBottomAlpha = isDark ? 0.21 : 0.12;
                          final Color baseHourColor = theme
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: hourTopAlpha);
                          final Color baseMinorColor = theme.dividerColor
                              .withValues(alpha: minorTopAlpha);
                          final Color hourBottomColor = baseHourColor
                              .withValues(alpha: hourBottomAlpha);
                          final Color minorBottomColor = baseMinorColor
                              .withValues(alpha: minorBottomAlpha);
                          bottomBorder = BorderSide(
                            color: isDark ? Colors.white24 : Colors.black26,
                            width: 1,
                          );
                        }
                        return Container(
                          height: widget.slotExtent,
                          decoration: BoxDecoration(
                            border: Border(
                              top: topBorder,
                              bottom: bottomBorder,
                            ),
                          ),
                        );
                      }),
                    ),
                    if (openOverlay != null) openOverlay,
                    if (dragOverlay != null) dragOverlay,
                    if (hoverOverlay != null) hoverOverlay,
                    // Visual overlay for last-minute holds (blocked slots)
                    ...widget.lastMinuteSlots.expand((slot) {
                      if (!slot.isAvailable) {
                        return const Iterable<Widget>.empty();
                      }
                      if (slot.operatorId != widget.staffMember.id) {
                        return const Iterable<Widget>.empty();
                      }
                      final segment = _segmentWithinTimeline(
                        slot.start,
                        slot.end,
                        widget.timelineStart,
                        widget.timelineEnd,
                      );
                      if (segment == null) {
                        return const Iterable<Widget>.empty();
                      }
                      final top =
                          segment.start
                              .difference(widget.timelineStart)
                              .inMinutes /
                          widget.slotMinutes *
                          widget.slotExtent;
                      final height = max(
                        widget.slotExtent,
                        segment.end.difference(segment.start).inMinutes /
                            widget.slotMinutes *
                            widget.slotExtent,
                      );
                      return [
                        Positioned(
                          top: top,
                          left: 0,
                          right: 0,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap:
                                  widget.onTapLastMinuteSlot == null
                                      ? null
                                      : () => widget.onTapLastMinuteSlot!(slot),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: height,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.30),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.50,
                                    ),
                                  ),
                                ),
                                padding:
                                    widget.compact
                                        ? const EdgeInsets.all(4)
                                        : const EdgeInsets.all(6),
                                alignment:
                                    widget.compact
                                        ? Alignment.center
                                        : Alignment.topLeft,
                                child:
                                    widget.compact
                                        ? Icon(
                                          Icons.flash_on_rounded,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        )
                                        : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.flash_on_rounded,
                                              size: 14,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Slot last-minute',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color:
                                                        theme
                                                            .colorScheme
                                                            .primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ),
                              ),
                            ),
                          ),
                        ),
                      ];
                    }),
                    ...widget.absences.expand((absence) {
                      final segment = _segmentWithinTimeline(
                        absence.start,
                        absence.end,
                        widget.timelineStart,
                        widget.timelineEnd,
                      );
                      if (segment == null) {
                        return const Iterable<Widget>.empty();
                      }
                      final top =
                          segment.start
                              .difference(widget.timelineStart)
                              .inMinutes /
                          widget.slotMinutes *
                          widget.slotExtent;
                      final height = max(
                        widget.slotExtent,
                        segment.end.difference(segment.start).inMinutes /
                            widget.slotMinutes *
                            widget.slotExtent,
                      );
                      final timeLabel =
                          '${_timeLabel.format(segment.start)} - ${_timeLabel.format(segment.end)}';
                      final description = StringBuffer(absence.type.label);
                      if (!absence.isAllDay || !absence.isSingleDay) {
                        description.write(' • $timeLabel');
                      }
                      if (absence.notes != null && absence.notes!.isNotEmpty) {
                        description.write('\n${absence.notes}');
                      }
                      final descriptionText = description.toString();
                      final absenceContent =
                          widget.compact
                              ? Center(
                                child: Tooltip(
                                  message: descriptionText,
                                  child: Icon(
                                    Icons.event_busy_rounded,
                                    size: 18,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              )
                              : Text(
                                descriptionText,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              );

                      return [
                        Positioned(
                          top: top,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: height,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.error.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            padding:
                                widget.compact
                                    ? const EdgeInsets.all(4)
                                    : const EdgeInsets.all(6),
                            alignment:
                                widget.compact
                                    ? Alignment.center
                                    : Alignment.topLeft,
                            child: absenceContent,
                          ),
                        ),
                      ];
                    }),
                    ...widget.shifts.expand((shift) {
                      final segment = _segmentWithinTimeline(
                        shift.start,
                        shift.end,
                        widget.timelineStart,
                        widget.timelineEnd,
                      );
                      if (segment == null) {
                        return const Iterable<Widget>.empty();
                      }

                      final top =
                          segment.start
                              .difference(widget.timelineStart)
                              .inMinutes /
                          widget.slotMinutes *
                          widget.slotExtent;
                      final height = max(
                        widget.slotExtent,
                        segment.end.difference(segment.start).inMinutes /
                            widget.slotMinutes *
                            widget.slotExtent,
                      );

                      final widgets = <Widget>[
                        Positioned(
                          top: top,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: height,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ];

                      if (shift.breakStart != null && shift.breakEnd != null) {
                        final breakSegment = _segmentWithinTimeline(
                          shift.breakStart!,
                          shift.breakEnd!,
                          widget.timelineStart,
                          widget.timelineEnd,
                        );
                        if (breakSegment != null) {
                          final breakTop =
                              breakSegment.start
                                  .difference(widget.timelineStart)
                                  .inMinutes /
                              widget.slotMinutes *
                              widget.slotExtent;
                          final breakHeight = max(
                            widget.slotExtent / 2,
                            breakSegment.end
                                    .difference(breakSegment.start)
                                    .inMinutes /
                                widget.slotMinutes *
                                widget.slotExtent,
                          );
                          widgets.add(
                            Positioned(
                              top: breakTop,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: breakHeight,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.colorScheme.error.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      }

                      return widgets;
                    }),
                    ...widget.appointments.map((appointment) {
                      final segment = _segmentWithinTimeline(
                        appointment.start,
                        appointment.end,
                        widget.timelineStart,
                        widget.timelineEnd,
                      );
                      if (segment == null) {
                        return const SizedBox.shrink();
                      }
                      final top =
                          segment.start
                              .difference(widget.timelineStart)
                              .inMinutes /
                          widget.slotMinutes *
                          widget.slotExtent;
                      final height =
                          segment.end.difference(segment.start).inMinutes /
                          widget.slotMinutes *
                          widget.slotExtent;
                      final visibleMinutes = max(
                        1,
                        segment.end.difference(segment.start).inMinutes,
                      );
                      final client = widget.clientsById[appointment.clientId];
                      final services =
                          appointment.serviceIds
                              .map((id) => widget.servicesById[id])
                              .whereType<Service>()
                              .toList();
                      final service =
                          services.isNotEmpty
                              ? services.first
                              : widget.servicesById[appointment.serviceId];
                      final roomName =
                          appointment.roomId != null
                              ? widget.roomsById[appointment.roomId!]
                              : null;
                      final issues =
                          widget.anomalies[appointment.id] ??
                          const <AppointmentAnomalyType>{};
                      final slotId = appointment.lastMinuteSlotId;
                      final matchingSlot =
                          slotId == null
                              ? null
                              : widget.lastMinuteSlots.firstWhereOrNull(
                                (slot) => slot.id == slotId,
                              );
                      final lockReason =
                          widget.lockedAppointmentReasons[appointment.id];
                      final isLocked = lockReason != null;
                      final hasOutstandingPayments = widget
                          .clientsWithOutstandingPayments
                          .contains(appointment.clientId);
                      final card = _AppointmentCard(
                        appointment: appointment,
                        client: client,
                        service: service,
                        services: services,
                        staff: widget.staffMember,
                        roomName: roomName,
                        onTap: () => widget.onEdit(appointment),
                        height: height,
                        visibleDurationMinutes: visibleMinutes,
                        anomalies: issues,
                        lockReason: lockReason,
                        lastMinuteSlot: matchingSlot,
                        categoriesById: widget.categoriesById,
                        categoriesByName: widget.categoriesByName,
                        hideContent: widget.compact,
                        hasOutstandingPayments: hasOutstandingPayments,
                      );
                      if (isLocked) {
                        return Positioned(
                          top: top,
                          left: 4,
                          right: 4,
                          child: card,
                        );
                      }
                      return Positioned(
                        top: top,
                        left: 4,
                        right: 4,
                        child: LongPressDraggable<_AppointmentDragData>(
                          data: _AppointmentDragData(appointment: appointment),
                          dragAnchorStrategy: pointerDragAnchorStrategy,
                          onDragStarted: () => _setDragging(true),
                          onDragCompleted: () => _setDragging(false),
                          onDragEnd: (_) => _setDragging(false),
                          onDraggableCanceled: (_, __) => _setDragging(false),
                          feedback: _DragFeedback(
                            child: _DragPreviewCard(
                              appointment: appointment,
                              client: client,
                              service: service,
                              services: services,
                              staff: widget.staffMember,
                              roomName: roomName,
                              height: height,
                              anomalies: issues,
                              previewStart: _dragPreviewStart,
                              previewDuration: _dragPreviewDuration,
                              slotMinutes: widget.interactionSlotMinutes,
                              lastMinuteSlot: matchingSlot,
                              categoriesById: widget.categoriesById,
                              categoriesByName: widget.categoriesByName,
                              hasOutstandingPayments: hasOutstandingPayments,
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.4,
                            child: _AppointmentCard(
                              appointment: appointment,
                              client: client,
                              service: service,
                              services: services,
                              staff: widget.staffMember,
                              roomName: roomName,
                              height: height,
                              visibleDurationMinutes: visibleMinutes,
                              anomalies: issues,
                              lockReason: lockReason,
                              lastMinuteSlot: matchingSlot,
                              categoriesById: widget.categoriesById,
                              categoriesByName: widget.categoriesByName,
                              hideContent: widget.compact,
                              hasOutstandingPayments: hasOutstandingPayments,
                            ),
                          ),
                          child: card,
                        ),
                      );
                    }),
                    if (candidateData.isNotEmpty)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color:
                                _dragPreviewHasConflict
                                    ? theme.colorScheme.error.withValues(
                                      alpha: 0.08,
                                    )
                                    : theme.colorScheme.primary.withValues(
                                      alpha: 0.08,
                                    ),
                            border: Border.all(
                              color:
                                  _dragPreviewHasConflict
                                      ? theme.colorScheme.error.withValues(
                                        alpha: 0.2,
                                      )
                                      : theme.colorScheme.primary.withValues(
                                        alpha: 0.2,
                                      ),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          onAcceptWithDetails: (details) async {
            final payload = details.data;
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox == null) {
              return;
            }
            final localOffset = renderBox.globalToLocal(details.offset);
            final clampedDy = localOffset.dy.clamp(0.0, renderBox.size.height);
            final totalMinutes =
                widget.timelineEnd
                    .difference(widget.timelineStart)
                    .inMinutes
                    .toDouble();
            final durationMinutes = payload.duration.inMinutes.toDouble();
            var minuteOffset =
                (clampedDy / renderBox.size.height) * totalMinutes;
            final maxStartMinutes = max(0.0, totalMinutes - durationMinutes);
            if (totalMinutes > durationMinutes) {
              minuteOffset = min(max(minuteOffset, 0.0), maxStartMinutes);
            } else {
              minuteOffset = 0.0;
            }
            final slotMinutes = widget.interactionSlotMinutes;
            final snappedMinutes =
                (minuteOffset / slotMinutes).round() * slotMinutes;
            final maxStartMinutesInt = maxStartMinutes.floor();
            final clampedMinutes = max(
              0,
              min(snappedMinutes, maxStartMinutesInt),
            );
            final newStart = widget.timelineStart.add(
              Duration(minutes: clampedMinutes),
            );
            final newEnd = newStart.add(payload.duration);

            final conflictMessage = _slotConflictMessage(
              newStart,
              newEnd,
              payload.appointment,
              widget.staffMember,
            );
            if (conflictMessage != null) {
              _setDragging(false);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(conflictMessage)));
              return;
            }

            await widget.onReschedule(
              AppointmentRescheduleRequest(
                appointment: payload.appointment,
                newStart: newStart,
                newEnd: newEnd,
                newStaffId: widget.staffMember.id,
                newRoomId: payload.appointment.roomId,
              ),
            );
            _setDragging(false);
          },
        ),
      ),
    );
  }
}

String? _primaryCategoryLabel(List<Service> services, Service? fallback) {
  final categories = <String>{};
  for (final service in services) {
    final normalized = service.category.trim();
    if (normalized.isNotEmpty) {
      categories.add(normalized);
    }
  }
  if (fallback != null) {
    final normalized = fallback.category.trim();
    if (normalized.isNotEmpty) {
      categories.add(normalized);
    }
  }
  if (categories.isEmpty) {
    if (services.length > 1) {
      return 'Multi-servizio';
    }
    return null;
  }
  if (categories.length == 1) {
    return categories.first;
  }
  return 'Multi-servizio';
}

Color? _categoryAccentColor(String? label, ThemeData theme) {
  final normalized = label?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final hash = normalized.toLowerCase().hashCode & 0xFFFFFFFF;
  final hue = (hash % 360).toDouble();
  final saturation = theme.brightness == Brightness.dark ? 0.35 : 0.55;
  final lightness = theme.brightness == Brightness.dark ? 0.38 : 0.72;
  return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
}

Color? _resolveCategoryColor(
  List<Service> services,
  Map<String, ServiceCategory> categoriesById,
  Map<String, ServiceCategory> categoriesByName,
  String? fallbackLabel,
  ThemeData theme,
) {
  final ids = <String>{};
  final names = <String>{};

  for (final service in services) {
    final categoryId = service.categoryId?.trim();
    if (categoryId != null && categoryId.isNotEmpty) {
      ids.add(categoryId);
    }
    final normalizedName = service.category.trim().toLowerCase();
    if (normalizedName.isNotEmpty) {
      names.add(normalizedName);
    }
  }

  for (final id in ids) {
    final category = categoriesById[id];
    final colorValue = category?.color;
    if (colorValue != null) {
      return Color(colorValue);
    }
  }

  for (final name in names) {
    final category = categoriesByName[name];
    final colorValue = category?.color;
    if (colorValue != null) {
      return Color(colorValue);
    }
  }

  return _categoryAccentColor(fallbackLabel, theme);
}

Color _onColorFor(Color background, ThemeData theme) {
  final brightness = ThemeData.estimateBrightnessForColor(background);
  if (brightness == Brightness.dark) {
    return Colors.white.withValues(alpha: 0.92);
  }
  return theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.92);
}

class _AppointmentCard extends StatefulWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.client,
    required this.service,
    this.services = const <Service>[],
    required this.staff,
    required this.height,
    this.roomName,
    this.onTap,
    this.anomalies = const <AppointmentAnomalyType>{},
    this.lockReason,
    this.highlight = false,
    this.lastMinuteSlot,
    required this.categoriesById,
    required this.categoriesByName,
    this.hideContent = false,
    this.visibleDurationMinutes,
    this.hasOutstandingPayments = false,
  });

  final Appointment appointment;
  final Client? client;
  final Service? service;
  final List<Service> services;
  final StaffMember staff;
  final double height;
  final String? roomName;
  final VoidCallback? onTap;
  final Set<AppointmentAnomalyType> anomalies;
  final String? lockReason;
  final bool highlight;
  final LastMinuteSlot? lastMinuteSlot;
  final Map<String, ServiceCategory> categoriesById;
  final Map<String, ServiceCategory> categoriesByName;
  final bool hideContent;
  final int? visibleDurationMinutes;
  final bool hasOutstandingPayments;

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<_AppointmentCard> {
  static final DateFormat _timeFormat = DateFormat('HH:mm', 'it_IT');

  bool _isHovering = false;

  void _updateHovering(bool hovering) {
    if (_isHovering == hovering) {
      return;
    }
    setState(() {
      _isHovering = hovering;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appointment = widget.appointment;
    final client = widget.client;
    final service = widget.service;
    final services = widget.services;
    final height = widget.height;
    final roomName = widget.roomName;
    final onTap = widget.onTap;
    final anomalies = widget.anomalies;
    final lockReason = widget.lockReason;
    final highlight = widget.highlight;
    final lastMinuteSlot = widget.lastMinuteSlot;
    final categoriesById = widget.categoriesById;
    final categoriesByName = widget.categoriesByName;
    final hideContent = widget.hideContent;
    final visibleDurationMinutes = widget.visibleDurationMinutes;
    final hasOutstandingPayments = widget.hasOutstandingPayments;

    final status = appointment.status;
    final now = DateTime.now();
    final bool hasEnded = !appointment.end.isAfter(now);
    final bool isCompleted = status == AppointmentStatus.completed;
    final bool isNoShow = status == AppointmentStatus.noShow;
    final bool hidePastCompletedContent = hasEnded && (isCompleted || isNoShow);
    final bool hideNoShowColor = hidePastCompletedContent && isNoShow;

    final startTimeLabel = _timeFormat.format(appointment.start);
    final timeLabel = startTimeLabel;
    final hasAnomalies = anomalies.isNotEmpty;
    final isLocked = lockReason != null;
    final servicesToDisplay =
        services.isNotEmpty ? services : [if (service != null) service!];
    final serviceLabel =
        servicesToDisplay.isNotEmpty
            ? servicesToDisplay.map((service) => service.name).join(' + ')
            : null;
    final isLastMinute = lastMinuteSlot != null;
    final int contentDurationMinutes = max(
      1,
      visibleDurationMinutes ?? appointment.duration.inMinutes,
    );
    final bool showServiceInfo = contentDurationMinutes >= 30;
    final bool showClientInfo = contentDurationMinutes >= 45;
    final categoryLabel = _primaryCategoryLabel(servicesToDisplay, service);
    final categoryColor = _resolveCategoryColor(
      servicesToDisplay,
      categoriesById,
      categoriesByName,
      categoryLabel,
      theme,
    );
    final isCancelled = status == AppointmentStatus.cancelled;
    final baseColor =
        (isCancelled || hideNoShowColor)
            ? Colors.transparent
            : categoryColor ?? theme.colorScheme.primary;
    Color backgroundColor = baseColor;
    Color borderBlendColor = baseColor;
    if (!isCancelled && !hideNoShowColor && baseColor.opacity > 0.0) {
      final double fillAlpha =
          theme.brightness == Brightness.dark ? 0.22 : 0.60;
      final double borderAlpha =
          theme.brightness == Brightness.dark ? 0.38 : 0.90;
      backgroundColor = baseColor.withValues(alpha: fillAlpha);
      borderBlendColor = baseColor.withValues(alpha: borderAlpha);
    }
    final highlightAnomalies = hasAnomalies && !hideNoShowColor;
    if (highlightAnomalies) {
      final double startAlpha =
          theme.brightness == Brightness.dark ? 0.45 : 0.25;
      final double endAlpha = theme.brightness == Brightness.dark ? 0.3 : 0.12;
      backgroundColor = Color.alphaBlend(
        theme.colorScheme.error.withValues(alpha: startAlpha),
        backgroundColor,
      );
      borderBlendColor = Color.alphaBlend(
        theme.colorScheme.error.withValues(alpha: endAlpha),
        borderBlendColor,
      );
    }

    final Color surfaceTint = theme.colorScheme.surfaceVariant.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.28 : 0.16,
    );
    final Color elegantBorder =
        borderBlendColor.opacity > 0.0
            ? Color.alphaBlend(borderBlendColor, surfaceTint)
            : surfaceTint;
    final baseBorder =
        isCancelled
            ? theme.colorScheme.outlineVariant.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.5 : 0.4,
            )
            : hideNoShowColor
            ? theme.colorScheme.outlineVariant.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.28 : 0.18,
            )
            : elegantBorder;
    final List<String> issueDescriptions =
        hasAnomalies
            ? (anomalies.toList()..sort((a, b) => a.index.compareTo(b.index)))
                .map((issue) => issue.description)
                .toList()
            : const <String>[];
    final needsAttention = hasAnomalies || isCancelled;
    final highlightCompactAttention = hideContent && needsAttention;
    final borderColor =
        highlightCompactAttention
            ? (hasAnomalies
                ? theme.colorScheme.error
                : theme.colorScheme.secondary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.9 : 0.8,
                ))
            : hasAnomalies
            ? theme.colorScheme.error.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.85 : 0.75,
            )
            : isCancelled
            ? theme.colorScheme.outlineVariant.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.7 : 0.6,
            )
            : isLocked
            ? theme.colorScheme.outline.withValues(alpha: 0.8)
            : isLastMinute
            ? theme.colorScheme.primary.withValues(alpha: 0.45)
            : baseBorder;
    final borderWidth =
        highlightCompactAttention
            ? 2.5
            : needsAttention
            ? 2.0
            : isLocked
            ? 1.5
            : 1.2;
    final showBorder = true;
    final attentionTooltipLines = <String>[
      if (isCancelled) 'Appuntamento annullato',
      ...issueDescriptions,
    ];
    final attentionTooltip =
        attentionTooltipLines.isNotEmpty
            ? attentionTooltipLines.join('\n')
            : null;
    final double verticalPadding;
    if (height < 72) {
      verticalPadding = 6;
    } else if (height < 120) {
      verticalPadding = 10;
    } else {
      verticalPadding = 14;
    }
    const double stripeWidth = 8.0;
    const double stripeGap = 8.0;
    final double horizontalPadding = 14.0;
    final padding = EdgeInsets.only(
      left: horizontalPadding + stripeWidth + stripeGap,
      right: horizontalPadding,
      top: verticalPadding,
      bottom: verticalPadding,
    );
    final Color cardSurface =
        theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : Colors.white;
    final bool hasCategoryTone =
        !isCancelled && !hideNoShowColor && baseColor.opacity > 0.0;
    final Color stripeColor =
        hasCategoryTone
            ? Color.alphaBlend(
              baseColor.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.75 : 0.88,
              ),
              theme.colorScheme.surface.withValues(alpha: 0),
            )
            : theme.colorScheme.outlineVariant.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.6 : 0.45,
            );
    Color gradientStart = cardSurface;
    Color gradientEnd = cardSurface;
    if (hasCategoryTone || backgroundColor.opacity > 0.0) {
      final Color tintSource = hasCategoryTone ? baseColor : borderBlendColor;
      gradientStart = Color.alphaBlend(
        tintSource.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.36 : 0.26,
        ),
        cardSurface,
      );
      gradientEnd = Color.alphaBlend(
        tintSource.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.14 : 0.12,
        ),
        cardSurface,
      );
    }
    if (highlightAnomalies) {
      gradientStart = Color.alphaBlend(
        theme.colorScheme.error.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.24 : 0.18,
        ),
        gradientStart,
      );
      gradientEnd = Color.alphaBlend(
        theme.colorScheme.error.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.14 : 0.12,
        ),
        gradientEnd,
      );
    }
    final bool hasTranslucentFill = hasCategoryTone || highlightAnomalies;
    final borderRadius = BorderRadius.circular(12);
    final Color contentSampleColor =
        Color.lerp(gradientStart, gradientEnd, 0.5) ?? gradientStart;
    final Brightness contentBrightness = ThemeData.estimateBrightnessForColor(
      contentSampleColor.withAlpha(0xFF),
    );
    final bool prefersDarkContent = contentBrightness == Brightness.light;
    final Color primaryContentColor =
        prefersDarkContent ? theme.colorScheme.onSurface : Colors.white;
    final Color secondaryContentColor =
        prefersDarkContent
            ? theme.colorScheme.onSurface.withValues(alpha: 0.82)
            : Colors.white.withValues(alpha: 0.9);
    final Color iconContentColor = primaryContentColor;
    final Color infoPillBackgroundColor =
        prefersDarkContent
            ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
            : Colors.white.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.12 : 0.18,
            );
    final Color infoPillTextColor =
        prefersDarkContent
            ? primaryContentColor
            : Colors.white.withValues(alpha: 0.92);
    final Color infoPillIconColor =
        prefersDarkContent
            ? primaryContentColor.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.9);

    final card = Container(
      height: height,
      decoration: BoxDecoration(
        boxShadow: [
          if (hasTranslucentFill)
            BoxShadow(
              color: borderBlendColor.withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          if (highlight)
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
        ],
        border:
            showBorder
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
        borderRadius: borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: cardSurface,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [gradientStart, gradientEnd],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    stripeColor.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.9 : 1,
                    ),
                    stripeColor.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.75 : 0.82,
                    ),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: SizedBox(width: stripeWidth),
            ),
          ),
          Padding(
            padding: padding,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                if (availableHeight <= 0) {
                  return const SizedBox.shrink();
                }

                if (hidePastCompletedContent) {
                  if (hideContent) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "",
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }
                  final IconData iconData;
                  final Color iconColor;
                  if (isNoShow) {
                    iconData = Icons.close_rounded;
                    iconColor = theme.colorScheme.error;
                  } else {
                    iconData = Icons.check;
                    iconColor = iconContentColor;
                  }
                  final double iconSize =
                      availableHeight < 48
                          ? 20
                          : availableHeight < 80
                          ? 26
                          : 32;
                  return Center(
                    child: Icon(iconData, color: iconColor, size: iconSize),
                  );
                }

                if (hideContent) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "",
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }

                final showRoomInfo = roomName != null && availableHeight >= 120;
                final showOutstandingChip =
                    hasOutstandingPayments && availableHeight >= 72;
                final hasBottomSection = showRoomInfo || showOutstandingChip;

                final timeStyle =
                    theme.textTheme.bodyMedium?.copyWith(
                      color: primaryContentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ) ??
                    TextStyle(
                      color: primaryContentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    );
                final detailStyle =
                    theme.textTheme.bodySmall?.copyWith(
                      color: secondaryContentColor,
                      fontSize: 11,
                    ) ??
                    TextStyle(color: secondaryContentColor, fontSize: 11);
                final List<Widget> children = [];

                void addDetail(
                  String? value,
                  TextStyle style, {
                  double gap = 2,
                }) {
                  final text = value?.trim();
                  if (text == null || text.isEmpty) {
                    return;
                  }
                  if (children.isNotEmpty) {
                    children.add(SizedBox(height: gap));
                  }
                  children.add(
                    Text(
                      text,
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }

                addDetail(timeLabel, timeStyle);
                if (showServiceInfo) {
                  addDetail(serviceLabel, detailStyle);
                }
                if (showClientInfo) {
                  addDetail(client?.fullName, detailStyle);
                }

                if (children.isEmpty) {
                  return const SizedBox.shrink();
                }

                if (hasBottomSection) {
                  if (availableHeight >= 88) {
                    children
                      ..add(const Spacer())
                      ..add(const SizedBox(height: 4));
                  } else {
                    children.add(
                      SizedBox(height: availableHeight >= 76 ? 4 : 2),
                    );
                  }

                  final List<Widget> bottomWidgets = [];

                  Widget buildInfoPill({
                    required IconData icon,
                    required String label,
                    Color? background,
                    Color? iconColor,
                    Color? textColor,
                    EdgeInsets padding = const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  }) {
                    final Color defaultIconColor =
                        iconColor ?? infoPillIconColor;
                    final Color defaultTextColor =
                        textColor ?? infoPillTextColor;
                    final Color pillBackground =
                        background ?? infoPillBackgroundColor;
                    return Container(
                      padding: padding,
                      decoration: BoxDecoration(
                        color: pillBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: defaultIconColor),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style:
                                theme.textTheme.labelSmall?.copyWith(
                                  color: defaultTextColor,
                                  fontWeight: FontWeight.w600,
                                ) ??
                                TextStyle(
                                  color: defaultTextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    );
                  }

                  if (showRoomInfo) {
                    bottomWidgets.add(
                      buildInfoPill(
                        icon: Icons.room_outlined,
                        label: 'Stanza: $roomName',
                      ),
                    );
                  }

                  if (showOutstandingChip) {
                    bottomWidgets.add(
                      buildInfoPill(
                        icon: Icons.payments_outlined,
                        label: 'Pagamenti da saldare',
                        background: theme.colorScheme.tertiaryContainer
                            .withValues(
                              alpha:
                                  theme.brightness == Brightness.dark
                                      ? 0.8
                                      : 0.9,
                            ),
                        iconColor: theme.colorScheme.onTertiaryContainer,
                        textColor: theme.colorScheme.onTertiaryContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                    );
                  }

                  if (bottomWidgets.isNotEmpty) {
                    children.add(
                      Wrap(spacing: 8, runSpacing: 4, children: bottomWidgets),
                    );
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                );
              },
            ),
          ),
        ],
      ),
    );

    final overlayWidgets = <Widget>[];
    if (!hideContent) {
      Widget? attentionBadge;
      if (needsAttention) {
        final overlayColor =
            hasAnomalies
                ? theme.colorScheme.error
                : theme.colorScheme.outlineVariant.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.75 : 0.55,
                );
        final iconData =
            hasAnomalies
                ? AppointmentAnomalyType.noShift.icon
                : Icons.cancel_rounded;
        final iconColor =
            hasAnomalies
                ? theme.colorScheme.onError
                : theme.colorScheme.onSurfaceVariant;
        final shadowColor =
            hasAnomalies
                ? theme.colorScheme.error.withValues(alpha: 0.45)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.25);
        attentionBadge = Tooltip(
          message: attentionTooltip ?? 'Appuntamento da gestire',
          waitDuration: const Duration(milliseconds: 250),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: overlayColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
          ),
        );
      }

      Widget? lastMinuteBadge;
      if (isLastMinute) {
        final slot = lastMinuteSlot;
        if (slot != null) {
          lastMinuteBadge = Tooltip(
            message:
                slot.isAvailable
                    ? 'Slot last-minute disponibile'
                    : 'Appuntamento last-minute',
            waitDuration: const Duration(milliseconds: 250),
            child: Container(
              padding:
                  hideContent
                      ? const EdgeInsets.all(6)
                      : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  hideContent
                      ? Icon(
                        Icons.flash_on_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      )
                      : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flash_on_rounded,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Last-minute',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
            ),
          );
        }
      }

      final positionedChildren = <Widget>[];
      if (lastMinuteBadge != null) {
        positionedChildren.add(lastMinuteBadge);
      }
      if (attentionBadge != null) {
        if (positionedChildren.isNotEmpty) {
          positionedChildren.add(const SizedBox(height: 8));
        }
        positionedChildren.add(attentionBadge);
      }

      if (positionedChildren.isNotEmpty) {
        overlayWidgets.add(
          Positioned(
            bottom: 8,
            right: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: positionedChildren,
            ),
          ),
        );
      }
    }

    Widget decoratedCard =
        overlayWidgets.isEmpty
            ? card
            : Stack(children: [card, ...overlayWidgets]);

    final durationMinutes = max(1, appointment.duration.inMinutes);
    final hoverLines = <String>['Durata: $durationMinutes minuti'];

    final clientName = client?.fullName;
    final normalizedClientName = clientName?.trim();
    if (normalizedClientName != null && normalizedClientName.isNotEmpty) {
      hoverLines.add('Cliente: $normalizedClientName');
    }
    final normalizedServiceName = serviceLabel?.trim();
    if (normalizedServiceName != null && normalizedServiceName.isNotEmpty) {
      hoverLines.add('Servizio: $normalizedServiceName');
    }

    if (appointment.packageId != null) {
      hoverLines.add('Scalato da sessione');
    }
    if (hasOutstandingPayments) {
      hoverLines.add('Pagamenti: da saldare');
    }
    if (lastMinuteSlot != null) {
      hoverLines.add(
        lastMinuteSlot.isAvailable
            ? 'Slot last-minute disponibile'
            : 'Appuntamento last-minute',
      );
    }
    if (lockReason != null && lockReason!.trim().isNotEmpty) {
      hoverLines.add('Bloccato: ${lockReason!.trim()}');
    }
    for (final description in issueDescriptions) {
      final normalizedDescription = description.trim();
      if (normalizedDescription.isNotEmpty) {
        hoverLines.add('Anomalia: $normalizedDescription');
      }
    }
    final notes = appointment.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      hoverLines.add('Note: $notes');
    }
    final hoverTooltipLines =
        hoverLines.where((line) => line.trim().isNotEmpty).toList();
    final hoverTooltip =
        hoverTooltipLines.isEmpty ? null : hoverTooltipLines.join('\n');

    final bool enableHover = onTap != null;
    final double targetScale = enableHover && _isHovering ? 1.06 : 1.0;

    Widget interactiveCard = MouseRegion(
      cursor: enableHover ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: enableHover ? (_) => _updateHovering(true) : null,
      onExit: enableHover ? (_) => _updateHovering(false) : null,
      child: AnimatedScale(
        scale: targetScale,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: decoratedCard,
          ),
        ),
      ),
    );

    if (hoverTooltip != null) {
      interactiveCard = _SideTooltip(
        message: hoverTooltip,
        waitDuration: const Duration(milliseconds: 250),
        child: interactiveCard,
      );
    }

    return interactiveCard;
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: child,
      ),
    );
  }
}

enum _SideTooltipDirection { auto, left, right }

class _SideTooltip extends StatefulWidget {
  const _SideTooltip({
    required this.message,
    required this.child,
    this.direction = _SideTooltipDirection.auto,
    this.waitDuration = const Duration(milliseconds: 250),
    this.verticalOffset = 0.0,
    this.gap = 12.0,
  });

  final String message;
  final Widget child;
  final _SideTooltipDirection direction;
  final Duration waitDuration;
  final double verticalOffset;
  final double gap;

  @override
  State<_SideTooltip> createState() => _SideTooltipState();
}

class _SideTooltipState extends State<_SideTooltip> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _showTimer;
  _SideTooltipDirection _resolvedDirection = _SideTooltipDirection.right;

  @override
  void dispose() {
    _cancelShowTimer();
    _removeOverlay();
    super.dispose();
  }

  void _handlePointerEnter(PointerEnterEvent event) {
    if (widget.message.trim().isEmpty) {
      return;
    }
    _scheduleShow();
  }

  void _handlePointerExit(PointerExitEvent event) {
    _cancelShowTimer();
    _removeOverlay();
  }

  void _scheduleShow() {
    _cancelShowTimer();
    if (widget.waitDuration <= Duration.zero) {
      _showTooltip();
    } else {
      _showTimer = Timer(widget.waitDuration, _showTooltip);
    }
  }

  void _cancelShowTimer() {
    _showTimer?.cancel();
    _showTimer = null;
  }

  void _showTooltip() {
    if (!mounted || widget.message.trim().isEmpty) {
      return;
    }
    if (_overlayEntry != null) {
      return;
    }
    final overlay = Overlay.of(context);
    if (overlay == null) {
      return;
    }

    _resolvedDirection = _resolveDirection(overlay);
    _overlayEntry = OverlayEntry(
      builder:
          (context) => _SideTooltipOverlay(
            link: _layerLink,
            message: widget.message,
            direction: _resolvedDirection,
            verticalOffset: widget.verticalOffset,
            gap: widget.gap,
          ),
    );
    overlay.insert(_overlayEntry!);
  }

  _SideTooltipDirection _resolveDirection(OverlayState overlay) {
    if (widget.direction != _SideTooltipDirection.auto) {
      return widget.direction;
    }

    final targetRenderObject = context.findRenderObject() as RenderBox?;
    final overlayRenderObject =
        overlay.context.findRenderObject() as RenderBox?;
    if (targetRenderObject == null || overlayRenderObject == null) {
      return _SideTooltipDirection.right;
    }

    final targetOffset = targetRenderObject.localToGlobal(
      Offset.zero,
      ancestor: overlayRenderObject,
    );
    final targetWidth = targetRenderObject.size.width;
    final spaceLeft = targetOffset.dx;
    final spaceRight =
        overlayRenderObject.size.width - (targetOffset.dx + targetWidth);

    return spaceRight >= spaceLeft
        ? _SideTooltipDirection.right
        : _SideTooltipDirection.left;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _cancelShowTimer();
    _removeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      tooltip: widget.message,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Listener(
          onPointerDown: _handlePointerDown,
          child: MouseRegion(
            onEnter: _handlePointerEnter,
            onExit: _handlePointerExit,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _SideTooltipOverlay extends StatelessWidget {
  const _SideTooltipOverlay({
    required this.link,
    required this.message,
    required this.direction,
    required this.verticalOffset,
    required this.gap,
  });

  final LayerLink link;
  final String message;
  final _SideTooltipDirection direction;
  final double verticalOffset;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final tooltipTheme = TooltipTheme.of(context);
    final theme = Theme.of(context);
    final decoration =
        tooltipTheme.decoration ??
        BoxDecoration(
          color: theme.colorScheme.inverseSurface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        );
    final textStyle =
        tooltipTheme.textStyle ??
        theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onInverseSurface,
          fontSize: 13,
          height: 1.2,
        ) ??
        TextStyle(
          color: theme.colorScheme.onInverseSurface,
          fontSize: 13,
          height: 1.2,
        );
    final padding =
        tooltipTheme.padding ??
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    final margin = tooltipTheme.margin ?? EdgeInsets.zero;
    final textAlign = tooltipTheme.textAlign ?? TextAlign.start;

    final targetAnchor =
        direction == _SideTooltipDirection.right
            ? Alignment.centerRight
            : Alignment.centerLeft;
    final followerAnchor =
        direction == _SideTooltipDirection.right
            ? Alignment.centerLeft
            : Alignment.centerRight;
    final horizontalOffset =
        direction == _SideTooltipDirection.right ? gap : -gap;

    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: margin,
          child: Align(
            alignment: Alignment.topLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: CompositedTransformFollower(
              link: link,
              targetAnchor: targetAnchor,
              followerAnchor: followerAnchor,
              offset: Offset(horizontalOffset, verticalOffset),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 200),
                  padding: padding,
                  decoration: decoration,
                  child: Text(message, style: textStyle, textAlign: textAlign),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DragPreviewCard extends StatelessWidget {
  const _DragPreviewCard({
    required this.appointment,
    required this.client,
    required this.service,
    this.services = const <Service>[],
    required this.staff,
    required this.height,
    this.roomName,
    this.anomalies = const <AppointmentAnomalyType>{},
    this.previewStart,
    this.previewDuration,
    required this.slotMinutes,
    this.lastMinuteSlot,
    required this.categoriesById,
    required this.categoriesByName,
    this.hasOutstandingPayments = false,
  });

  final Appointment appointment;
  final Client? client;
  final Service? service;
  final List<Service> services;
  final StaffMember staff;
  final double height;
  final String? roomName;
  final Set<AppointmentAnomalyType> anomalies;
  final DateTime? previewStart;
  final Duration? previewDuration;
  final int slotMinutes;
  final LastMinuteSlot? lastMinuteSlot;
  final Map<String, ServiceCategory> categoriesById;
  final Map<String, ServiceCategory> categoriesByName;
  final bool hasOutstandingPayments;

  @override
  Widget build(BuildContext context) {
    final start = previewStart ?? appointment.start;
    final end =
        previewDuration != null ? start.add(previewDuration!) : appointment.end;
    final normalizedEnd =
        end.isBefore(start) ? start.add(Duration(minutes: slotMinutes)) : end;
    final previewed = appointment.copyWith(start: start, end: normalizedEnd);
    final visibleMinutes =
        previewDuration?.inMinutes ?? previewed.duration.inMinutes;
    return _AppointmentCard(
      appointment: previewed,
      client: client,
      service: service,
      services: services,
      staff: staff,
      roomName: roomName,
      height: height,
      visibleDurationMinutes: visibleMinutes,
      anomalies: anomalies,
      lockReason: null,
      highlight: true,
      lastMinuteSlot: lastMinuteSlot,
      categoriesById: categoriesById,
      categoriesByName: categoriesByName,
      hasOutstandingPayments: hasOutstandingPayments,
    );
  }
}

class _AppointmentDragData {
  _AppointmentDragData({required this.appointment});

  final Appointment appointment;

  Duration get duration => appointment.duration;
}

class _TimelineBounds {
  const _TimelineBounds({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class _DateSegment {
  const _DateSegment({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

bool _overlapsRange(
  DateTime start,
  DateTime end,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
}

_DateSegment? _segmentWithinTimeline(
  DateTime start,
  DateTime end,
  DateTime timelineStart,
  DateTime timelineEnd,
) {
  if (!_overlapsRange(start, end, timelineStart, timelineEnd)) {
    return null;
  }
  final segmentStart = start.isBefore(timelineStart) ? timelineStart : start;
  final segmentEnd = end.isAfter(timelineEnd) ? timelineEnd : end;
  return _DateSegment(start: segmentStart, end: segmentEnd);
}

DateTime _minDate(DateTime? current, DateTime candidate) {
  if (current == null) return candidate;
  return candidate.isBefore(current) ? candidate : current;
}

DateTime _maxDate(DateTime? current, DateTime candidate) {
  if (current == null) return candidate;
  return candidate.isAfter(current) ? candidate : current;
}

DateTime _floorToSlot(DateTime value, int slotMinutes) {
  final minutes = slotMinutes;
  final remainder = value.minute % minutes;
  return DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute - remainder,
  );
}

DateTime _ceilToSlot(DateTime value, int slotMinutes) {
  final minutes = slotMinutes;
  final remainder = value.minute % minutes;
  if (remainder == 0) {
    return value;
  }
  return value.add(Duration(minutes: minutes - remainder));
}

DateTime _weekStart(DateTime anchor) {
  final weekday = anchor.weekday; // Monday=1
  final difference = weekday - DateTime.monday;
  return DateUtils.dateOnly(anchor).subtract(Duration(days: difference));
}

String _staffInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final parts = trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final buffer = StringBuffer();
  for (final part in parts.take(2)) {
    buffer.write(part[0].toUpperCase());
  }
  if (buffer.isEmpty) {
    return trimmed[0].toUpperCase();
  }
  if (buffer.length == 1 && trimmed.length > 1) {
    buffer.write(trimmed[1].toUpperCase());
  }
  return buffer.toString();
}
