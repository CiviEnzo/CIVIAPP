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
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const double _kStaffColumnWidth = 220.0;
const double _kStaffHeaderHeight = 48.0;
const double _kDayColumnBorderWidth = 1.6;
const double _kDayHeaderBorderRadius = 16.0;
const double _kBasePreviewHeight = 210.0;
const double _kHoverPreviewWidth = 410.0;
const double _kHoverPreviewGap = 12.0;
const double _kAutoScrollEdgeExtent = 120.0;
const double _kAutoScrollMinStep = 10.0;
const double _kAutoScrollMaxStep = 34.0;
const Duration _kMinDragUpdateInterval = Duration(milliseconds: 16);
const ValueKey<String> _kAppointmentHoverPreviewKey = ValueKey<String>(
  'appointment_hover_preview',
);

final DateFormat _calendarWeekdayFormat = DateFormat('EEEE', 'it_IT');
final DateFormat _calendarWeekdayShortFormat = DateFormat('EEE', 'it_IT');
final DateFormat _calendarDayNumberFormat = DateFormat('dd', 'it_IT');
final DateFormat _calendarMonthAbbrevFormat = DateFormat('MMM', 'it_IT');
final DateFormat _closureTimeFormat = DateFormat('HH:mm', 'it_IT');

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

String _calendarCompactDayLabel(DateTime date) {
  final weekday = _calendarWeekdayShortFormat.format(date).replaceAll('.', '');
  final dayNumber = _calendarDayNumberFormat.format(date);
  return '${_capitalizeItalianWord(weekday)} $dayNumber';
}

String _primaryStaffRoleLabel(
  StaffMember staffMember,
  Map<String, StaffRole> rolesById,
) {
  for (final roleId in staffMember.roleIds) {
    final label = rolesById[roleId]?.displayName.trim();
    if (label != null && label.isNotEmpty) {
      return label;
    }
  }
  return '';
}

class _StaffAvatarTone {
  const _StaffAvatarTone({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

enum _ChecklistStateKind { empty, completed, pending }

class _ChecklistVisualState {
  const _ChecklistVisualState({
    required this.kind,
    required this.icon,
    required this.tooltip,
    required this.label,
    required this.bannerTitle,
    required this.badgeLabel,
    required this.background,
    required this.foreground,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.borderColor,
  });

  final _ChecklistStateKind kind;
  final IconData icon;
  final String tooltip;
  final String label;
  final String bannerTitle;
  final String badgeLabel;
  final Color background;
  final Color foreground;
  final Color badgeBackground;
  final Color badgeForeground;
  final Color borderColor;
}

int _completedChecklistCount(AppointmentDayChecklist? checklist) =>
    checklist?.items.where((item) => item.isCompleted).length ?? 0;

String _checklistSummaryText({required int total, required int completed}) {
  final pending = max(total - completed, 0);
  if (total == 0) {
    return 'Nessuna attività ancora pianificata.';
  }
  if (pending == 0) {
    return 'Tutte le $total attività sono completate.';
  }
  return '$pending attività da completare su $total.';
}

_ChecklistVisualState _resolveChecklistVisualState(
  ThemeData theme, {
  required int total,
  required int completed,
  required bool isCurrentDay,
}) {
  final pending = max(total - completed, 0);
  if (total == 0) {
    return _ChecklistVisualState(
      kind: _ChecklistStateKind.empty,
      icon: Icons.playlist_add_rounded,
      tooltip: 'Checklist vuota',
      label: 'Checklist vuota',
      bannerTitle: 'Nessuna attività in checklist',
      badgeLabel: '0',
      background: theme.colorScheme.surfaceContainerHighest,
      foreground: theme.colorScheme.onSurfaceVariant,
      badgeBackground: theme.colorScheme.surface,
      badgeForeground: theme.colorScheme.onSurfaceVariant,
      borderColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.9),
    );
  }
  if (pending == 0) {
    return _ChecklistVisualState(
      kind: _ChecklistStateKind.completed,
      icon: Icons.task_alt_rounded,
      tooltip: 'Checklist completata',
      label: 'Checklist completata',
      bannerTitle: 'Tutto eseguito',
      badgeLabel: 'OK',
      background: Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: 0.08),
        theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
      ),
      foreground: theme.colorScheme.onPrimaryContainer,
      badgeBackground: theme.colorScheme.primary,
      badgeForeground: theme.colorScheme.onPrimary,
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.32),
    );
  }
  return _ChecklistVisualState(
    kind: _ChecklistStateKind.pending,
    icon:
        isCurrentDay ? Icons.pending_actions_rounded : Icons.checklist_rounded,
    tooltip:
        isCurrentDay
            ? '$pending attività da completare'
            : '$pending attività pianificate',
    label: isCurrentDay ? 'Checklist $pending da fare' : 'Checklist',
    bannerTitle:
        isCurrentDay
            ? (pending == 1
                ? '1 attività da fare'
                : '$pending attività da fare')
            : (pending == 1
                ? '1 attività pianificata'
                : '$pending attività pianificate'),
    badgeLabel: pending > 99 ? '99+' : '$pending',
    background:
        isCurrentDay
            ? Color.alphaBlend(
              theme.colorScheme.error.withValues(alpha: 0.08),
              theme.colorScheme.errorContainer.withValues(alpha: 0.92),
            )
            : theme.colorScheme.surfaceContainerHighest,
    foreground:
        isCurrentDay
            ? theme.colorScheme.onErrorContainer
            : theme.colorScheme.onSurfaceVariant,
    badgeBackground: theme.colorScheme.error,
    badgeForeground: theme.colorScheme.onError,
    borderColor:
        isCurrentDay
            ? theme.colorScheme.error.withValues(alpha: 0.26)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.9),
  );
}

_StaffAvatarTone _staffAvatarTone(StaffMember staffMember) {
  const tones = <_StaffAvatarTone>[
    _StaffAvatarTone(
      background: Color(0xFFF4B266),
      foreground: Color(0xFFFFFFFF),
    ),
    _StaffAvatarTone(
      background: Color(0xFFF395B5),
      foreground: Color(0xFFFFFFFF),
    ),
    _StaffAvatarTone(
      background: Color(0xFF62D1A7),
      foreground: Color(0xFFFFFFFF),
    ),
    _StaffAvatarTone(
      background: Color(0xFF5DA7F8),
      foreground: Color(0xFFFFFFFF),
    ),
    _StaffAvatarTone(
      background: Color(0xFF9B8AF8),
      foreground: Color(0xFFFFFFFF),
    ),
    _StaffAvatarTone(
      background: Color(0xFFF28A6D),
      foreground: Color(0xFFFFFFFF),
    ),
  ];
  final seed = '${staffMember.id}:${staffMember.fullName}';
  final hash = seed.codeUnits.fold<int>(0, (sum, code) => sum + code);
  return tones[hash % tones.length];
}

bool _hasAllowedRole(StaffMember staff, List<String> allowedRoles) {
  if (allowedRoles.isEmpty) {
    return true;
  }
  return staff.roleIds.any((roleId) => allowedRoles.contains(roleId));
}

enum AppointmentCalendarScope { day, week }

enum AppointmentWeekLayoutMode { detailed, compact, operatorBoard }

double _resolveSlotExtent(
  BuildContext context, {
  required AppointmentCalendarScope scope,
  required AppointmentWeekLayoutMode weekLayout,
  required int slotMinutes,
}) {
  final viewportWidth = MediaQuery.sizeOf(context).width;
  final bool isPhone = viewportWidth < 720;
  final bool isTablet = viewportWidth < 1280;
  final bool isCompactWeekLayout =
      scope == AppointmentCalendarScope.week &&
      weekLayout == AppointmentWeekLayoutMode.compact;
  final double quarterHourTarget =
      isCompactWeekLayout
          ? isPhone
              ? 48.0
              : isTablet
              ? 44.0
              : 40.0
          : isPhone
          ? 76.0
          : isTablet
          ? 68.0
          : 60.0;
  final normalizedSlotMinutes = max(1, slotMinutes);
  return quarterHourTarget * (normalizedSlotMinutes / 15.0);
}

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

IconData _appointmentStatusIcon(AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.scheduled:
      return Icons.event_available_rounded;
    case AppointmentStatus.completed:
      return Icons.check_circle_rounded;
    case AppointmentStatus.cancelled:
      return Icons.close_rounded;
    case AppointmentStatus.noShow:
      return Icons.person_off_rounded;
  }
}

Color _appointmentStatusColor(ColorScheme scheme, AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.scheduled:
      return scheme.primary;
    case AppointmentStatus.completed:
      return const Color(0xFF1E9C63);
    case AppointmentStatus.cancelled:
      return const Color(0xFF8D8D8D);
    case AppointmentStatus.noShow:
      return const Color(0xFFE24C5A);
  }
}

Color _appointmentCardBackgroundColor(
  ThemeData theme,
  AppointmentStatus status,
) {
  final bool isDark = theme.brightness == Brightness.dark;
  switch (status) {
    case AppointmentStatus.scheduled:
    case AppointmentStatus.completed:
      return isDark ? const Color(0xFF211D1A) : Colors.white;
    case AppointmentStatus.cancelled:
      return isDark ? const Color(0xFF3A312E) : const Color(0xFFF3E8E4);
    case AppointmentStatus.noShow:
      return isDark ? const Color(0xFF4B2A31) : const Color(0xFFF6D9DC);
  }
}

bool _appointmentHasActivePackage(Appointment appointment) {
  final packageId = appointment.packageId?.trim();
  return (packageId != null && packageId.isNotEmpty) ||
      appointment.hasPackageConsumptions;
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

class _DayClosureInfo {
  const _DayClosureInfo({
    required this.salonId,
    required this.salonName,
    required this.start,
    required this.end,
    required this.reason,
    required this.isFullDay,
  });

  final String salonId;
  final String salonName;
  final DateTime start;
  final DateTime end;
  final String? reason;
  final bool isFullDay;
}

List<_DayClosureInfo> _closuresForDay({
  required DateTime day,
  required Map<String, Salon> salonsById,
  String? focusSalonId,
  Set<String>? relatedSalonIds,
}) {
  final dayStart = DateUtils.dateOnly(day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final targetSalonIds = <String>{};
  if (focusSalonId != null && focusSalonId.trim().isNotEmpty) {
    targetSalonIds.add(focusSalonId.trim());
  }
  if (relatedSalonIds != null && relatedSalonIds.isNotEmpty) {
    targetSalonIds.addAll(relatedSalonIds.where((id) => id.trim().isNotEmpty));
  }
  if (targetSalonIds.isEmpty) {
    targetSalonIds.addAll(salonsById.keys);
  }
  final result = <_DayClosureInfo>[];
  for (final salonId in targetSalonIds) {
    final salon = salonsById[salonId];
    if (salon == null || salon.closures.isEmpty) {
      continue;
    }
    for (final closure in salon.closures) {
      if (!closure.end.isAfter(dayStart) || !closure.start.isBefore(dayEnd)) {
        continue;
      }
      final overlapStart =
          closure.start.isAfter(dayStart) ? closure.start : dayStart;
      final overlapEnd = closure.end.isBefore(dayEnd) ? closure.end : dayEnd;
      result.add(
        _DayClosureInfo(
          salonId: salon.id,
          salonName: salon.name,
          start: overlapStart,
          end: overlapEnd,
          reason: closure.reason?.trim(),
          isFullDay:
              overlapStart.isAtSameMomentAs(dayStart) &&
              overlapEnd.isAtSameMomentAs(dayEnd),
        ),
      );
    }
  }
  result.sort((a, b) {
    final comparison = a.start.compareTo(b.start);
    if (comparison != 0) {
      return comparison;
    }
    return a.salonName.compareTo(b.salonName);
  });
  return result;
}

class _ClosureBanner extends StatelessWidget {
  const _ClosureBanner({
    required this.info,
    required this.showSalonName,
    this.compact = false,
  });

  final _DayClosureInfo info;
  final bool showSalonName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    final borderRadius = BorderRadius.circular(compact ? 10 : 12);
    final padding =
        compact
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
            : const EdgeInsets.all(12);
    final textStyle = (compact
            ? theme.textTheme.bodySmall
            : theme.textTheme.bodyMedium)
        ?.copyWith(color: color, fontWeight: FontWeight.w600);
    final label = _buildLabel();
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: compact ? 0.12 : 0.1),
        borderRadius: borderRadius,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: color,
            size: compact ? 18 : 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: textStyle)),
        ],
      ),
    );
  }

  String _buildLabel() {
    final buffer = StringBuffer();
    if (showSalonName) {
      buffer.write('${info.salonName} • ');
    }
    if (info.isFullDay) {
      buffer.write('Chiusura straordinaria tutto il giorno');
    } else {
      buffer.write(
        'Chiusura straordinaria ${_closureTimeFormat.format(info.start)} - ${_closureTimeFormat.format(info.end)}',
      );
    }
    final reason = info.reason;
    if (reason != null && reason.isNotEmpty) {
      buffer.write(' • $reason');
    }
    return buffer.toString();
  }
}

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
    this.selectedSalonId,
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
    this.extraDetailedDay,
    this.onJumpToNextWeek,
    this.scrollToDate,
    this.scrollToDateRequestId = 0,
    this.readOnly = false,
    this.showStaffHeader = true,
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
  final String? selectedSalonId;
  final Map<String, String> lockedAppointmentReasons;
  final Map<DateTime, AppointmentDayChecklist> dayChecklists;
  final DateTime? extraDetailedDay;
  final VoidCallback? onJumpToNextWeek;
  final DateTime? scrollToDate;
  final int scrollToDateRequestId;
  final bool readOnly;
  final bool showStaffHeader;
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
  static const _timeScaleExtent = 74.0;

  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final _hoverPreviewController = _AppointmentHoverPreviewController();
  bool _isSynchronizing = false;
  late final DateTime _initialScrollDate;
  bool _didAutoScrollToInitialDay = false;
  DateTime? _requestedScrollDate;

  @override
  void initState() {
    super.initState();
    _horizontalHeaderController.addListener(_syncFromHeader);
    _horizontalBodyController.addListener(_syncFromBody);
    _initialScrollDate = DateUtils.dateOnly(DateTime.now());
    _requestedScrollDate =
        widget.scrollToDate != null
            ? DateUtils.dateOnly(widget.scrollToDate!)
            : null;
  }

  @override
  void didUpdateWidget(covariant AppointmentCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newScrollDate =
        widget.scrollToDate != null
            ? DateUtils.dateOnly(widget.scrollToDate!)
            : null;
    final oldScrollDate =
        oldWidget.scrollToDate != null
            ? DateUtils.dateOnly(oldWidget.scrollToDate!)
            : null;
    final requestChanged =
        widget.scrollToDateRequestId != oldWidget.scrollToDateRequestId;
    final dateChanged = !DateUtils.isSameDay(newScrollDate, oldScrollDate);
    if (newScrollDate != null && (dateChanged || requestChanged)) {
      _requestedScrollDate = newScrollDate;
    } else if (newScrollDate == null && oldScrollDate != null) {
      _requestedScrollDate = null;
    }

    final activePreviewId =
        _hoverPreviewController.activeRequest?.appointmentId;
    final shouldDismissPreview =
        widget.scope != oldWidget.scope ||
        widget.weekLayout != oldWidget.weekLayout ||
        widget.readOnly != oldWidget.readOnly ||
        (activePreviewId != null &&
            !widget.appointments.any(
              (appointment) => appointment.id == activePreviewId,
            ));
    if (shouldDismissPreview) {
      _hoverPreviewController.dismiss();
    }
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
    _hoverPreviewController.dispose();
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

  Widget _buildCalendarBody(Widget child) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: _AppointmentHoverPreviewLayer(
              controller: _hoverPreviewController,
            ),
          ),
        ),
      ],
    );
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
    final resolvedSlotExtent = _resolveSlotExtent(
      context,
      scope: widget.scope,
      weekLayout: widget.weekLayout,
      slotMinutes: widget.slotMinutes,
    );
    switch (widget.scope) {
      case AppointmentCalendarScope.day:
        return _buildCalendarBody(
          ScrollConfiguration(
            behavior: const _CompactMacScrollBehavior(),
            child: _DaySchedule(
              anchorDate: widget.anchorDate,
              appointments: widget.appointments,
              allAppointments: widget.allAppointments,
              lastMinutePlaceholders: widget.lastMinutePlaceholders,
              lastMinuteSlots: widget.lastMinuteSlots,
              shifts: widget.shifts,
              absences: widget.absences,
              schedule: widget.schedule,
              staff: widget.staff,
              clientsWithOutstandingPayments:
                  widget.clientsWithOutstandingPayments,
              clientsById: clientsById,
              servicesById: servicesById,
              categoriesById: categoriesById,
              categoriesByName: categoriesByName,
              roomsById: widget.roomsById,
              statusColor: widget.statusColor,
              salonsById: widget.salonsById,
              selectedSalonId: widget.selectedSalonId,
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
              slotExtent: resolvedSlotExtent,
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
              hoverPreviewController: _hoverPreviewController,
              readOnly: widget.readOnly,
              showStaffHeader: widget.showStaffHeader,
            ),
          ),
        );
      case AppointmentCalendarScope.week:
        final autoScrollTargetDate = _requestedScrollDate ?? _initialScrollDate;
        final autoScrollPending =
            _requestedScrollDate != null || !_didAutoScrollToInitialDay;
        return _buildCalendarBody(
          ScrollConfiguration(
            behavior: const _CompactMacScrollBehavior(),
            child: _WeekSchedule(
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
              clientsWithOutstandingPayments:
                  widget.clientsWithOutstandingPayments,
              clientsById: clientsById,
              servicesById: servicesById,
              categoriesById: categoriesById,
              categoriesByName: categoriesByName,
              roomsById: widget.roomsById,
              statusColor: widget.statusColor,
              salonsById: widget.salonsById,
              selectedSalonId: widget.selectedSalonId,
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
              slotExtent: resolvedSlotExtent,
              interactionSlotMinutes: widget.interactionSlotMinutes,
              onAddChecklistItem: widget.onAddChecklistItem,
              onToggleChecklistItem: widget.onToggleChecklistItem,
              onRenameChecklistItem: widget.onRenameChecklistItem,
              onDeleteChecklistItem: widget.onDeleteChecklistItem,
              autoScrollTargetDate: autoScrollTargetDate,
              autoScrollPending: autoScrollPending,
              autoScrollIsManual: _requestedScrollDate != null,
              layout: widget.weekLayout,
              onCreateShift: widget.onCreateShift,
              onEditShift: widget.onEditShift,
              onDeleteShift: widget.onDeleteShift,
              onCreateAbsence: widget.onCreateAbsence,
              onEditAbsence: widget.onEditAbsence,
              onDeleteAbsence: widget.onDeleteAbsence,
              extraDetailedDay: widget.extraDetailedDay,
              onJumpToNextWeek: widget.onJumpToNextWeek,
              hoverPreviewController: _hoverPreviewController,
              readOnly: widget.readOnly,
              showStaffHeader: widget.showStaffHeader,
              onAutoScrollComplete: () {
                if (mounted) {
                  setState(() {
                    _didAutoScrollToInitialDay = true;
                    _requestedScrollDate = null;
                  });
                }
              },
            ),
          ),
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

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
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
    this.selectedSalonId,
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
    required this.slotExtent,
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
    required this.hoverPreviewController,
    required this.readOnly,
    required this.showStaffHeader,
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
  final String? selectedSalonId;
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
  final double slotExtent;
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
  final _AppointmentHoverPreviewController hoverPreviewController;
  final bool readOnly;
  final bool showStaffHeader;

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
    final gridHeight = slotCount * slotExtent;

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

    final theme = Theme.of(context);
    final headerColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.55,
    );
    final timelineColor = theme.colorScheme.surfaceContainerLowest.withValues(
      alpha: 0.45,
    );
    final viewportWidth = MediaQuery.sizeOf(context).width;
    const double outerBorderWidth = 1.0;
    const double innerDividerWidth = 1.0;
    final staffColumnWidth =
        showStaffHeader
            ? _kStaffColumnWidth
            : min(_kStaffColumnWidth, max(0.0, viewportWidth - 32));
    final staffCount = staff.length;
    final totalStaffWidth =
        staffCount == 0 ? 0.0 : staffColumnWidth * staffCount;
    final centerStaffColumns =
        !showStaffHeader &&
        staffCount > 0 &&
        totalStaffWidth > 0 &&
        totalStaffWidth < viewportWidth;
    final staffGridWidth = totalStaffWidth;
    final staffGridOuterWidth =
        staffGridWidth == 0 ? 0.0 : staffGridWidth + (outerBorderWidth * 2);
    final staffGridOuterHeight = gridHeight + (outerBorderWidth * 2);
    final staffRowWidth =
        centerStaffColumns ? viewportWidth : staffGridOuterWidth;
    final staffColumnBorderColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.64,
    );
    final isCompact = MediaQuery.of(context).size.width < 720;
    final relevantSalonIds =
        staff.map((member) => member.salonId).whereType<String>().toSet();
    final closures = _closuresForDay(
      day: dayStart,
      salonsById: salonsById,
      focusSalonId: selectedSalonId,
      relatedSalonIds: relevantSalonIds,
    );
    final showClosureSalonName =
        closures.map((closure) => closure.salonId).toSet().length > 1;
    final showChecklistLauncher =
        !isCompact &&
        (hasChecklistItems ||
            onAddChecklistItem != null ||
            onToggleChecklistItem != null ||
            onRenameChecklistItem != null ||
            onDeleteChecklistItem != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        if (closures.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (var i = 0; i < closures.length; i++) ...[
                            if (i != 0) const SizedBox(height: 8),
                            _ClosureBanner(
                              info: closures[i],
                              showSalonName: showClosureSalonName,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (closures.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < closures.length; i++) ...[
                  if (i != 0) const SizedBox(height: 6),
                  _ClosureBanner(
                    info: closures[i],
                    showSalonName: showClosureSalonName,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: Column(
            children: [
              if (showStaffHeader) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: const _CompactMacScrollBehavior(),
                        child: SingleChildScrollView(
                          controller: horizontalHeaderController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: staffGridOuterWidth,
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                border: Border.all(
                                  color: staffColumnBorderColor,
                                  width: outerBorderWidth,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (
                                    var staffIndex = 0;
                                    staffIndex < staff.length;
                                    staffIndex++
                                  )
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
                                        return SizedBox(
                                          width: staffColumnWidth,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              border:
                                                  staffIndex == staff.length - 1
                                                      ? null
                                                      : Border(
                                                        right: BorderSide(
                                                          color:
                                                              staffColumnBorderColor,
                                                          width:
                                                              innerDividerWidth,
                                                        ),
                                                      ),
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
                                                  onCreateAbsence:
                                                      onCreateAbsence,
                                                  onEditAbsence: onEditAbsence,
                                                  onDeleteAbsence:
                                                      onDeleteAbsence,
                                                );
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10,
                                                    ),
                                                child: Center(
                                                  child: Text(
                                                    _firstNameOnly(
                                                      staffMember.fullName,
                                                    ),
                                                    style:
                                                        theme
                                                            .textTheme
                                                            .titleSmall,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: SingleChildScrollView(
                  controller: verticalController,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0, bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ScrollConfiguration(
                            behavior: const _CompactMacScrollBehavior(),
                            child: SingleChildScrollView(
                              controller: horizontalBodyController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: staffRowWidth,
                                child: Align(
                                  alignment:
                                      centerStaffColumns
                                          ? Alignment.topCenter
                                          : Alignment.topLeft,
                                  child:
                                      staffCount == 0
                                          ? SizedBox(
                                            height: gridHeight,
                                            child: Center(
                                              child: Text(
                                                'Aggiungi membri dello staff per pianificare.',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .onSurfaceVariant
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                    ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          )
                                          : Container(
                                            width: staffGridOuterWidth,
                                            height: staffGridOuterHeight,
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              color: timelineColor,
                                              border: Border.all(
                                                color: staffColumnBorderColor,
                                                width: outerBorderWidth,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                for (
                                                  var staffIndex = 0;
                                                  staffIndex < staff.length;
                                                  staffIndex++
                                                )
                                                  SizedBox(
                                                    width: staffColumnWidth,
                                                    height: gridHeight,
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        border:
                                                            staffIndex ==
                                                                    staff.length -
                                                                        1
                                                                ? null
                                                                : Border(
                                                                  right: BorderSide(
                                                                    color:
                                                                        staffColumnBorderColor,
                                                                    width:
                                                                        innerDividerWidth,
                                                                  ),
                                                                ),
                                                      ),
                                                      child: _StaffDayColumn(
                                                        staffMember:
                                                            staff[staffIndex],
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
                                                        timelineStart:
                                                            bounds.start,
                                                        timelineEnd: bounds.end,
                                                        slotMinutes:
                                                            slotMinutes,
                                                        interactionSlotMinutes:
                                                            interactionSlotMinutes,
                                                        slotExtent: slotExtent,
                                                        verticalController:
                                                            verticalController,
                                                        horizontalScrollController:
                                                            horizontalBodyController,
                                                        clientsWithOutstandingPayments:
                                                            clientsWithOutstandingPayments,
                                                        clientsById:
                                                            clientsById,
                                                        servicesById:
                                                            servicesById,
                                                        categoriesById:
                                                            categoriesById,
                                                        categoriesByName:
                                                            categoriesByName,
                                                        roomsById: roomsById,
                                                        salonsById: salonsById,
                                                        allAppointments:
                                                            allAppointments,
                                                        statusColor:
                                                            statusColor,
                                                        lockedAppointmentReasons:
                                                            lockedAppointmentReasons,
                                                        onReschedule:
                                                            onReschedule,
                                                        onEdit: onEdit,
                                                        onCreate: onCreate,
                                                        anomalies: anomalies,
                                                        hoverPreviewController:
                                                            hoverPreviewController,
                                                        openStart: openingStart,
                                                        openEnd: closingEnd,
                                                        showSlotStartTimes:
                                                            isCompact,
                                                        readOnly: readOnly,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
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
    this.selectedSalonId,
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
    required this.slotExtent,
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
    this.autoScrollIsManual = false,
    required this.layout,
    this.onAutoScrollComplete,
    this.extraDetailedDay,
    this.onJumpToNextWeek,
    required this.hoverPreviewController,
    required this.readOnly,
    required this.showStaffHeader,
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
  final String? selectedSalonId;
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
  final double slotExtent;
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
  final bool autoScrollIsManual;
  final AppointmentWeekLayoutMode layout;
  final VoidCallback? onAutoScrollComplete;
  final DateTime? extraDetailedDay;
  final VoidCallback? onJumpToNextWeek;
  final _AppointmentHoverPreviewController hoverPreviewController;
  final bool readOnly;
  final bool showStaffHeader;

  static const _timeScaleExtent =
      _AppointmentCalendarViewState._timeScaleExtent;

  static Widget _summaryChip({
    required ThemeData theme,
    required IconData icon,
    required String label,
    Color? background,
    Color? foreground,
    String? tooltip,
    VoidCallback? onTap,
    bool showLabel = false,
  }) {
    final tooltipParts = <String>[];
    if (label.trim().isNotEmpty) {
      tooltipParts.add(label);
    }
    if (tooltip != null && tooltip.trim().isNotEmpty) {
      tooltipParts.add(tooltip);
    }
    final tooltipMessage = tooltipParts.join('\n');
    final bool iconOnly = !showLabel || label.trim().isEmpty;

    Widget chip = Container(
      padding: EdgeInsets.symmetric(horizontal: iconOnly ? 6 : 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: []),
    );
    if (onTap != null) {
      chip = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: chip,
        ),
      );
    }
    if (tooltipMessage.isNotEmpty) {
      return Tooltip(
        message: tooltipMessage,
        waitDuration: const Duration(milliseconds: 250),
        child: chip,
      );
    }
    return chip;
  }

  Widget _buildDetailedDayHeaderCard({
    required BuildContext context,
    required ThemeData theme,
    required _WeekDayData data,
    required bool isToday,
    required bool isNextWeekDay,
    required Color borderColor,
    required double dayWidth,
    required double summaryHorizontalPadding,
    required double staffColumnWidth,
    required double staffGap,
    required Color staffDividerColor,
    required double dayBorderWidth,
    required double staffDividerWidth,
    required Color dayHeaderColor,
    required Map<String, StaffRole> rolesById,
    required Set<String> relevantSalonIds,
  }) {
    final dateLabel = _formatCalendarDayLabel(data.date);
    final compactDayLabel = _calendarCompactDayLabel(data.date);
    final totalAppointments = data.appointmentsByStaff.values.fold<int>(
      0,
      (running, list) => running + list.length,
    );
    final dayChecklist = dayChecklists[data.date];
    final checklistTotal = dayChecklist?.items.length ?? 0;
    final checklistCompleted =
        dayChecklist?.items.where((item) => item.isCompleted).length ?? 0;
    final closures = _closuresForDay(
      day: data.date,
      salonsById: salonsById,
      focusSalonId: selectedSalonId,
      relatedSalonIds: relevantSalonIds,
    );
    final showClosureSalonName =
        closures.map((closure) => closure.salonId).toSet().length > 1;
    final headerBackground =
        isToday
            ? Color.alphaBlend(
              theme.colorScheme.primary.withValues(alpha: 0.05),
              dayHeaderColor,
            )
            : isNextWeekDay
            ? Color.alphaBlend(
              theme.colorScheme.secondary.withValues(alpha: 0.08),
              dayHeaderColor,
            )
            : dayHeaderColor;
    final bool showHeaderChipLabels = dayWidth >= 320;

    return Container(
      width: dayWidth,
      decoration: BoxDecoration(
        color: headerBackground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_kDayHeaderBorderRadius),
        ),
        border: Border(
          top: BorderSide(color: borderColor, width: dayBorderWidth),
          left: BorderSide(color: borderColor, width: dayBorderWidth),
          right: BorderSide(color: borderColor, width: dayBorderWidth),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              summaryHorizontalPadding,
              14,
              summaryHorizontalPadding,
              showStaffHeader && staff.isNotEmpty ? 12 : 14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNextWeekDay)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _summaryChip(
                      theme: theme,
                      icon: Icons.north_east_rounded,
                      label: 'Settimana prossima',
                      background: theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.7),
                      foreground: theme.colorScheme.onSecondaryContainer,
                      onTap: onJumpToNextWeek,
                      showLabel: true,
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      compactDayLabel,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _summaryChip(
                              theme: theme,
                              icon: Icons.event_available_rounded,
                              label: '$totalAppointments appuntamenti',
                              background: theme.colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.62),
                              foreground: theme.colorScheme.onTertiaryContainer,
                              showLabel: showHeaderChipLabels,
                            ),
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
                              showLabel: showHeaderChipLabels,
                              forceVisible: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (closures.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (var index = 0; index < closures.length; index++) ...[
                    if (index != 0) const SizedBox(height: 6),
                    _ClosureBanner(
                      info: closures[index],
                      showSalonName: showClosureSalonName,
                      compact: true,
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (showStaffHeader && staff.isNotEmpty) ...[
            Divider(
              height: 1,
              thickness: staffDividerWidth,
              color: staffDividerColor,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (
                  var staffIndex = 0;
                  staffIndex < staff.length;
                  staffIndex++
                ) ...[
                  _buildDetailedStaffHeaderCell(
                    context: context,
                    theme: theme,
                    data: data,
                    staffMember: staff[staffIndex],
                    rolesById: rolesById,
                    width: staffColumnWidth,
                    dividerColor: staffDividerColor,
                    dividerWidth: staffDividerWidth,
                    showTrailingDivider: staffIndex != staff.length - 1,
                  ),
                  if (staffIndex != staff.length - 1) SizedBox(width: staffGap),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedStaffHeaderCell({
    required BuildContext context,
    required ThemeData theme,
    required _WeekDayData data,
    required StaffMember staffMember,
    required Map<String, StaffRole> rolesById,
    required double width,
    required Color dividerColor,
    required double dividerWidth,
    required bool showTrailingDivider,
  }) {
    final canManageDay =
        (onCreateShift != null ||
            onEditShift != null ||
            onDeleteShift != null) ||
        (onCreateAbsence != null ||
            onEditAbsence != null ||
            onDeleteAbsence != null);
    final manageCallback =
        !canManageDay
            ? null
            : () async {
              await _handleStaffDayManagement(
                context,
                staff: staffMember,
                day: data.date,
                shifts: data.shiftsByStaff[staffMember.id] ?? const <Shift>[],
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
            };
    final avatarTone = _staffAvatarTone(staffMember);
    final roleLabel = _primaryStaffRoleLabel(staffMember, rolesById);
    final initialsValue = _staffInitials(staffMember.fullName).toUpperCase();
    final displayInitials = initialsValue.isEmpty ? '--' : initialsValue;

    return SizedBox(
      width: width,
      child: _StaffHeaderButton(
        enabled: canManageDay,
        tooltip:
            'Gestisci turni e assenze per ${_formatCalendarDayLabel(data.date)}',
        onPressed: manageCallback,
        child: Container(
          decoration: BoxDecoration(
            border:
                showTrailingDivider
                    ? Border(
                      right: BorderSide(
                        color: dividerColor,
                        width: dividerWidth,
                      ),
                    )
                    : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarTone.background,
                  child: Text(
                    displayInitials,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: avatarTone.foreground,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startOfWeek = _weekStart(anchorDate);
    final days = List.generate(
      7,
      (index) => startOfWeek.add(Duration(days: index)),
    );
    final normalizedExtraDay =
        extraDetailedDay != null ? DateUtils.dateOnly(extraDetailedDay!) : null;
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
    if (layout == AppointmentWeekLayoutMode.detailed &&
        normalizedExtraDay != null) {
      final alreadyIncluded = filteredDays.any(
        (day) =>
            DateUtils.isSameDay(DateUtils.dateOnly(day), normalizedExtraDay),
      );
      if (!alreadyIncluded) {
        filteredDays.add(normalizedExtraDay);
        filteredDays.sort();
      }
    }
    final hasAutoScrollTarget =
        autoScrollPending &&
        autoScrollTargetDate != null &&
        filteredDays.any(
          (day) => DateUtils.isSameDay(day, autoScrollTargetDate),
        );
    if (autoScrollPending &&
        autoScrollIsManual &&
        autoScrollTargetDate != null &&
        !hasAutoScrollTarget) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onAutoScrollComplete?.call();
      });
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
        minMinute: minMinute,
        verticalController: verticalController,
        readOnly: readOnly,
      );
    }

    if (layout == AppointmentWeekLayoutMode.compact) {
      return _WeekCompactView(
        dayData: dayData,
        staff: staff,
        hoverPreviewController: hoverPreviewController,
        roles: roles,
        clientsWithOutstandingPayments: clientsWithOutstandingPayments,
        clientsById: clientsById,
        servicesById: servicesById,
        categoriesById: categoriesById,
        categoriesByName: categoriesByName,
        roomsById: roomsById,
        salonsById: salonsById,
        selectedSalonId: selectedSalonId,
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
        slotExtent: slotExtent,
        minMinute: minMinute,
        maxMinute: maxMinute,
        verticalController: verticalController,
        interactionSlotMinutes: interactionSlotMinutes,
        readOnly: readOnly,
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
        showStaffHeader: showStaffHeader,
      );
    }

    final gridHeight = slotCount * slotExtent;
    final showSlotStartTimes = MediaQuery.of(context).size.width < 720;

    final dayHeaderColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.55,
    );
    final dayBodyColor = theme.colorScheme.surfaceContainerLowest.withValues(
      alpha: 0.45,
    );
    final rolesById = {for (final role in roles) role.id: role};
    final relevantSalonIds =
        staff.map((member) => member.salonId).whereType<String>().toSet();
    final now = DateTime.now();
    final staffColumnBorderColor =
        theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.52)
            : Colors.black.withValues(alpha: 0.68);
    const double summaryHorizontalPadding = 12.0;
    const double dayGap = 16.0;
    const double staffGap = 0.0;
    const double minDayWidth = 320.0;
    const double minStaffColumnWidth = 124.0;
    const double dayBorderWidth = _kDayColumnBorderWidth;
    const double staffDividerWidth = 1.0;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final availableRowWidth = max(
      0.0,
      viewportWidth - _timeScaleExtent - dayGap,
    );
    final targetVisibleDays = max(1, min(3, dayData.length));
    var dayWidth = max(
      minDayWidth,
      availableRowWidth / targetVisibleDays.toDouble(),
    );
    final staffCount = max(1, staff.length);
    final rawInnerWidth = max(0.0, dayWidth - (dayBorderWidth * 2));
    final rawStaffWidth =
        (rawInnerWidth - staffGap * max(staffCount - 1, 0)) / staffCount;
    final staffColumnWidth = rawStaffWidth.clamp(
      minStaffColumnWidth,
      _kStaffColumnWidth,
    );
    final dayInnerWidth =
        (staffColumnWidth * staffCount) + staffGap * max(staffCount - 1, 0);
    dayWidth = dayInnerWidth + (dayBorderWidth * 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ScrollConfiguration(
                  behavior: const _CompactMacScrollBehavior(),
                  child: SingleChildScrollView(
                    controller: horizontalHeaderController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(top: 4),
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
                                  final normalizedDate = DateUtils.dateOnly(
                                    data.date,
                                  );
                                  final isToday = DateUtils.isSameDay(
                                    normalizedDate,
                                    now,
                                  );
                                  final isNextWeekDay =
                                      normalizedExtraDay != null &&
                                      DateUtils.isSameDay(
                                        normalizedExtraDay,
                                        normalizedDate,
                                      );
                                  final dayBorderColor =
                                      isNextWeekDay
                                          ? theme.colorScheme.secondary
                                              .withValues(alpha: 0.66)
                                          : isToday
                                          ? theme.colorScheme.primary
                                              .withValues(alpha: 0.7)
                                          : staffColumnBorderColor;
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
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right:
                                          dayIndex == dayData.length - 1
                                              ? 0
                                              : dayGap,
                                    ),
                                    child: _buildDetailedDayHeaderCard(
                                      context: context,
                                      theme: theme,
                                      data: data,
                                      isToday: isToday,
                                      isNextWeekDay: isNextWeekDay,
                                      borderColor: dayBorderColor,
                                      dayWidth: dayWidth,
                                      summaryHorizontalPadding:
                                          summaryHorizontalPadding,
                                      staffColumnWidth: staffColumnWidth,
                                      staffGap: staffGap,
                                      staffDividerColor: staffColumnBorderColor,
                                      dayBorderWidth: dayBorderWidth,
                                      staffDividerWidth: staffDividerWidth,
                                      dayHeaderColor: dayHeaderColor,
                                      rolesById: rolesById,
                                      relevantSalonIds: relevantSalonIds,
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
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: verticalController,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: const _CompactMacScrollBehavior(),
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
                              Builder(
                                builder: (context) {
                                  final currentDay = dayData[dayIndex];
                                  final normalizedDay = DateUtils.dateOnly(
                                    currentDay.date,
                                  );
                                  final isNextWeekDay =
                                      normalizedExtraDay != null &&
                                      DateUtils.isSameDay(
                                        normalizedExtraDay,
                                        normalizedDay,
                                      );
                                  final isToday = DateUtils.isSameDay(
                                    normalizedDay,
                                    now,
                                  );
                                  final dayBorderColor =
                                      isNextWeekDay
                                          ? theme.colorScheme.secondary
                                              .withValues(alpha: 0.66)
                                          : isToday
                                          ? theme.colorScheme.primary
                                              .withValues(alpha: 0.7)
                                          : staffColumnBorderColor;
                                  final bodyColor =
                                      isNextWeekDay
                                          ? Color.alphaBlend(
                                            theme.colorScheme.secondary
                                                .withValues(alpha: 0.06),
                                            dayBodyColor,
                                          )
                                          : dayBodyColor;
                                  final List<BoxShadow>? bodyShadow =
                                      isNextWeekDay
                                          ? [
                                            BoxShadow(
                                              color: theme.colorScheme.secondary
                                                  .withValues(alpha: 0.08),
                                              blurRadius: 14,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                          : null;
                                  return Container(
                                    width: dayWidth,
                                    margin: EdgeInsets.only(
                                      right:
                                          dayIndex == dayData.length - 1
                                              ? 0
                                              : dayGap,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bodyColor,
                                      border: Border(
                                        left: BorderSide(
                                          color: dayBorderColor,
                                          width: dayBorderWidth,
                                        ),
                                        right: BorderSide(
                                          color: dayBorderColor,
                                          width: dayBorderWidth,
                                        ),
                                        bottom: BorderSide(
                                          color: dayBorderColor,
                                          width: dayBorderWidth,
                                        ),
                                      ),
                                      boxShadow: bodyShadow,
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
                                          Builder(
                                            builder: (context) {
                                              final showTrailingDivider =
                                                  staffIndex !=
                                                  staff.length - 1;
                                              return Container(
                                                width: staffColumnWidth,
                                                margin: EdgeInsets.only(
                                                  right:
                                                      showTrailingDivider
                                                          ? staffGap
                                                          : 0,
                                                ),
                                                decoration: BoxDecoration(
                                                  border:
                                                      showTrailingDivider
                                                          ? Border(
                                                            right: BorderSide(
                                                              color:
                                                                  staffColumnBorderColor,
                                                              width:
                                                                  staffDividerWidth,
                                                            ),
                                                          )
                                                          : null,
                                                ),
                                                child: SizedBox(
                                                  height: gridHeight,
                                                  child: _StaffDayColumn(
                                                    staffMember:
                                                        staff[staffIndex],
                                                    appointments:
                                                        currentDay
                                                            .appointmentsByStaff[staff[staffIndex]
                                                            .id] ??
                                                        const [],
                                                    lastMinutePlaceholders:
                                                        lastMinutePlaceholders,
                                                    lastMinuteSlots:
                                                        lastMinuteSlots,
                                                    allAppointments:
                                                        allAppointments,
                                                    shifts:
                                                        currentDay
                                                            .shiftsByStaff[staff[staffIndex]
                                                            .id] ??
                                                        const [],
                                                    absences:
                                                        currentDay
                                                            .absencesByStaff[staff[staffIndex]
                                                            .id] ??
                                                        const [],
                                                    timelineStart: currentDay
                                                        .date
                                                        .add(
                                                          Duration(
                                                            minutes: minMinute!,
                                                          ),
                                                        ),
                                                    timelineEnd: currentDay.date
                                                        .add(
                                                          Duration(
                                                            minutes: maxMinute!,
                                                          ),
                                                        ),
                                                    slotMinutes: slotMinutes,
                                                    interactionSlotMinutes:
                                                        interactionSlotMinutes,
                                                    slotExtent: slotExtent,
                                                    verticalController:
                                                        verticalController,
                                                    horizontalScrollController:
                                                        horizontalBodyController,
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
                                                    statusColor: statusColor,
                                                    lockedAppointmentReasons:
                                                        lockedAppointmentReasons,
                                                    onReschedule: onReschedule,
                                                    onEdit: onEdit,
                                                    onCreate: onCreate,
                                                    onTapLastMinuteSlot:
                                                        onTapLastMinuteSlot,
                                                    anomalies: anomalies,
                                                    hoverPreviewController:
                                                        hoverPreviewController,
                                                    openStart:
                                                        currentDay.openStart,
                                                    openEnd: currentDay.openEnd,
                                                    showSlotStartTimes:
                                                        showSlotStartTimes,
                                                    readOnly: readOnly,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ],
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
                ],
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
    final completed = allItems.where((item) => item.isCompleted).length;
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
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(widget.dense ? 12 : 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.75),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.playlist_add_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                size: widget.dense ? 18 : 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nessuna attività inserita',
                      style: (widget.dense
                              ? theme.textTheme.bodySmall
                              : theme.textTheme.bodyMedium)
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _canAdd
                          ? 'Aggiungi la prima attività della giornata.'
                          : 'Non ci sono attività per questa giornata.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.82,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      if (_canAdd) {
        children.add(SizedBox(height: widget.dense ? 12 : 16));
      }
      if (!widget.dense && completed == allItems.length) {
        children.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tutte le attività risultano eseguite.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
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
    this.showLabel = false,
    this.forceVisible = false,
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
  final bool showLabel;
  final bool forceVisible;

  @override
  Widget build(BuildContext context) {
    final pending = max(total - completed, 0);
    final hasAccess =
        forceVisible ||
        total > 0 ||
        onAdd != null ||
        onToggle != null ||
        onRename != null ||
        onDelete != null;
    if (!hasAccess) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final isCurrentDay = DateUtils.isSameDay(
      DateUtils.dateOnly(day),
      DateUtils.dateOnly(DateTime.now()),
    );
    final visualState = _resolveChecklistVisualState(
      theme,
      total: total,
      completed: completed,
      isCurrentDay: isCurrentDay,
    );
    final size = compact ? 26.0 : 28.0;
    final iconSize = compact ? 18.0 : 20.0;

    void onPressed() => _openDialog(context);

    if (showLabel) {
      return Tooltip(
        message: visualState.tooltip,
        waitDuration: const Duration(milliseconds: 250),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 6 : 8,
              ),
              decoration: BoxDecoration(
                color: visualState.background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: visualState.borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    visualState.icon,
                    color: visualState.foreground,
                    size: compact ? 18 : 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    visualState.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: visualState.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (pending > 0 && !isCurrentDay) ...[
                    const SizedBox(width: 8),
                    _ChecklistCountBadge(
                      label: visualState.badgeLabel,
                      background: visualState.badgeBackground,
                      foreground: visualState.badgeForeground,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: visualState.tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(compact ? 16 : 18),
          child: Ink(
            padding: EdgeInsets.all(compact ? 6 : 8),
            decoration: BoxDecoration(
              color: visualState.background,
              borderRadius: BorderRadius.circular(compact ? 16 : 18),
              border: Border.all(color: visualState.borderColor),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: compact ? 10 : 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Icon(
                      visualState.icon,
                      color: visualState.foreground,
                      size: iconSize,
                    ),
                  ),
                  Positioned(
                    right: -10,
                    top: -10,
                    child: _ChecklistCountBadge(
                      label: visualState.badgeLabel,
                      background: visualState.badgeBackground,
                      foreground: visualState.badgeForeground,
                      borderColor:
                          visualState.kind == _ChecklistStateKind.empty
                              ? theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.55,
                              )
                              : null,
                    ),
                  ),
                ],
              ),
            ),
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
                effectiveChecklist != null
                    ? _completedChecklistCount(effectiveChecklist)
                    : completed;
            final summaryText = _checklistSummaryText(
              total: currentTotal,
              completed: currentCompleted,
            );

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

Future<void> showAppointmentChecklistDialog({
  required BuildContext context,
  required DateTime day,
  AppointmentDayChecklist? checklist,
  String? salonId,
  Future<void> Function(DateTime day, String label)? onAdd,
  Future<void> Function(String checklistId, String itemId, bool isCompleted)?
  onToggle,
  Future<void> Function(String checklistId, String itemId, String label)?
  onRename,
  Future<void> Function(String checklistId, String itemId)? onDelete,
  bool compact = false,
}) {
  final normalizedDay = DateUtils.dateOnly(day);
  final dateLabel = _formatCalendarDayLabel(normalizedDay);
  final initialTotal = checklist?.items.length ?? 0;
  final initialCompleted =
      checklist?.items.where((item) => item.isCompleted).length ?? 0;
  final expectedSalonId = salonId ?? checklist?.salonId;

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final mediaQuery = MediaQuery.of(dialogContext);
      final maxWidth = min(
        mediaQuery.size.width * 0.9,
        compact ? 440.0 : 520.0,
      );
      final maxHeight = min(mediaQuery.size.height * 0.85, 560.0);

      return Consumer(
        builder: (context, ref, _) {
          final latestChecklist = ref.watch(
            appDataProvider.select((state) {
              return state.appointmentDayChecklists.firstWhereOrNull((entry) {
                final sameDay = DateUtils.isSameDay(entry.date, normalizedDay);
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
          final currentTotal = effectiveChecklist?.items.length ?? initialTotal;
          final currentCompleted =
              effectiveChecklist != null
                  ? _completedChecklistCount(effectiveChecklist)
                  : initialCompleted;
          final summaryText = _checklistSummaryText(
            total: currentTotal,
            completed: currentCompleted,
          );

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: _ChecklistDialogContent(
              day: normalizedDay,
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
    final total = widget.checklist?.items.length ?? 0;
    final completed = _completedChecklistCount(widget.checklist);
    final pending = max(total - completed, 0);
    final isCurrentDay = DateUtils.isSameDay(
      DateUtils.dateOnly(widget.day),
      DateUtils.dateOnly(DateTime.now()),
    );
    final visualState = _resolveChecklistVisualState(
      theme,
      total: total,
      completed: completed,
      isCurrentDay: isCurrentDay,
    );
    final isUrgentPending =
        visualState.kind == _ChecklistStateKind.pending && isCurrentDay;
    final summaryBackground =
        isUrgentPending
            ? Color.alphaBlend(
              theme.colorScheme.error.withValues(alpha: 0.04),
              theme.colorScheme.surface,
            )
            : visualState.background;
    final summaryBorderColor =
        isUrgentPending
            ? theme.colorScheme.error.withValues(alpha: 0.18)
            : visualState.borderColor;
    final summaryForeground =
        isUrgentPending ? theme.colorScheme.onSurface : visualState.foreground;
    final summaryAccent =
        isUrgentPending ? theme.colorScheme.error : visualState.badgeBackground;
    final totalChipBackground =
        isUrgentPending
            ? theme.colorScheme.surface
            : theme.colorScheme.surface.withValues(alpha: 0.72);
    final totalChipForeground = theme.colorScheme.onSurface;
    final totalChipBorderColor =
        isUrgentPending
            ? theme.colorScheme.outlineVariant.withValues(alpha: 0.65)
            : null;
    final completedChipBackground =
        isUrgentPending
            ? Color.alphaBlend(
              theme.colorScheme.primary.withValues(alpha: 0.10),
              theme.colorScheme.surface,
            )
            : theme.colorScheme.primary.withValues(alpha: 0.12);
    final completedChipForeground =
        isUrgentPending
            ? theme.colorScheme.onSurface
            : theme.colorScheme.primary;
    final completedChipBorderColor =
        isUrgentPending
            ? theme.colorScheme.primary.withValues(alpha: 0.24)
            : null;
    final pendingChipBackground =
        pending > 0
            ? (isUrgentPending
                ? theme.colorScheme.error
                : theme.colorScheme.error.withValues(alpha: 0.12))
            : theme.colorScheme.surface.withValues(alpha: 0.72);
    final pendingChipForeground =
        pending > 0
            ? (isUrgentPending
                ? theme.colorScheme.onError
                : theme.colorScheme.error)
            : theme.colorScheme.onSurfaceVariant;
    final pendingChipBorderColor =
        pending > 0 && isUrgentPending ? theme.colorScheme.error : null;
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: summaryBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: summaryBorderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: summaryAccent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            visualState.icon,
                            color: summaryAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                visualState.bannerTitle,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: summaryForeground,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.summaryText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: summaryForeground.withValues(
                                    alpha: 0.80,
                                  ),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ChecklistCountBadge(
                          label: visualState.badgeLabel,
                          background: visualState.badgeBackground,
                          foreground: visualState.badgeForeground,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChecklistStatChip(
                          label:
                              total == 0
                                  ? 'Nessun elemento'
                                  : '$total attività',
                          background: totalChipBackground,
                          foreground: totalChipForeground,
                          borderColor: totalChipBorderColor,
                        ),
                        _ChecklistStatChip(
                          label:
                              completed == 1
                                  ? '1 eseguita'
                                  : '$completed eseguite',
                          background: completedChipBackground,
                          foreground: completedChipForeground,
                          borderColor: completedChipBorderColor,
                        ),
                        _ChecklistStatChip(
                          label:
                              pending == 1 ? '1 da fare' : '$pending da fare',
                          background: pendingChipBackground,
                          foreground: pendingChipForeground,
                          borderColor: pendingChipBorderColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
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
  const _ChecklistCountBadge({
    required this.label,
    required this.background,
    required this.foreground,
    this.borderColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
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

class _ChecklistStatChip extends StatelessWidget {
  const _ChecklistStatChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.borderColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              borderColor ??
              theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CompactStaffLayout {
  const _CompactStaffLayout({
    required this.columnWidths,
    required this.flexes,
    required this.columnGap,
    required this.enforceMinWidth,
  });

  final List<double> columnWidths;
  final List<int> flexes;
  final double columnGap;
  final bool enforceMinWidth;
}

class _WeekCompactView extends StatelessWidget {
  const _WeekCompactView({
    required this.dayData,
    required this.staff,
    required this.hoverPreviewController,
    required this.roles,
    required this.clientsWithOutstandingPayments,
    required this.clientsById,
    required this.servicesById,
    required this.categoriesById,
    required this.categoriesByName,
    required this.roomsById,
    required this.salonsById,
    this.selectedSalonId,
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
    required this.readOnly,
    required this.showStaffHeader,
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
  final _AppointmentHoverPreviewController hoverPreviewController;
  final List<StaffRole> roles;
  final Set<String> clientsWithOutstandingPayments;
  final Map<String, Client> clientsById;
  final Map<String, Service> servicesById;
  final Map<String, ServiceCategory> categoriesById;
  final Map<String, ServiceCategory> categoriesByName;
  final Map<String, String> roomsById;
  final Map<String, Salon> salonsById;
  final String? selectedSalonId;
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
  final bool readOnly;
  final bool showStaffHeader;
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
  static const double _staffGap = 0;
  static const double _kDayHorizontalPadding = 8;
  static const double _kDayHeaderVerticalPadding = 8;
  static const double _kDayHeaderBottomPadding = 8;
  static const double _kDayBodyTopPadding = 0;
  static const double _kDayBodyBottomPadding = 8;
  static const double _kStaffHeaderHeight = 40;
  static const double _kMinStaffColumnWidth = 44;
  static const double _kScrollVerticalPadding = 12;

  @override
  Widget build(BuildContext context) {
    if (dayData.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final showSlotStartTimes = MediaQuery.of(context).size.width < 720;
    final rolesById = {for (final role in roles) role.id: role};
    final relevantSalonIds =
        staff.map((member) => member.salonId).whereType<String>().toSet();
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
        final double dayGridWidth = max(0.0, dayWidth);
        final bool hasStaff = staff.isNotEmpty;
        final _CompactStaffLayout? staffLayout =
            hasStaff ? _computeStaffLayout(dayGridWidth) : null;

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
              relevantSalonIds,
            ),
            if (staffLayout != null && showStaffHeader) ...[
              _buildOperatorHeaderRow(
                context,
                theme,
                contentWidth,
                dayWidth,
                staffLayout,
              ),
            ],
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
                                (_kDayBodyBottomPadding +
                                    _kScrollVerticalPadding),
                          )
                          : resolvedGridHeight;
                  final bool enableScroll =
                      !hasBoundedHeight ||
                      resolvedGridHeight > availableGridHeight + 0.5;

                  return SingleChildScrollView(
                    controller: verticalController,
                    physics:
                        enableScroll
                            ? const ClampingScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 0, bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
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
                              dayGridWidth,
                              resolvedGridHeight,
                              slotExtent,
                              staffLayout,
                              showSlotStartTimes,
                            ),
                          ),
                        ],
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
    Set<String> relevantSalonIds,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
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
                      relevantSalonIds,
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
    Set<String> relevantSalonIds,
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
    final closures = _closuresForDay(
      day: data.date,
      salonsById: salonsById,
      focusSalonId: selectedSalonId,
      relatedSalonIds: relevantSalonIds,
    );
    final showClosureSalonName =
        closures.map((closure) => closure.salonId).toSet().length > 1;

    final borderColor =
        isToday
            ? theme.colorScheme.primary.withValues(alpha: 0.72)
            : theme.colorScheme.outline.withValues(alpha: 0.72);

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
        border: Border.all(color: borderColor, width: _kDayColumnBorderWidth),
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
          if (closures.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < closures.length; i++) ...[
              if (i != 0) const SizedBox(height: 6),
              _ClosureBanner(
                info: closures[i],
                showSalonName: showClosureSalonName,
                compact: true,
              ),
            ],
          ],
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
    double dayGridWidth,
    double gridHeight,
    double slotExtent,
    _CompactStaffLayout? staffLayout,
    bool showSlotStartTimes,
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
              dayGridWidth,
              gridHeight,
              slotExtent,
              staffLayout,
              showSlotStartTimes,
            ),
          ),
          if (dayIndex != dayData.length - 1) const SizedBox(width: _dayGap),
        ],
      ],
    );
  }

  _CompactStaffLayout _computeStaffLayout(double dayInnerWidth) {
    final staffCount = staff.length;
    if (staffCount == 0) {
      return const _CompactStaffLayout(
        columnWidths: <double>[],
        flexes: <int>[],
        columnGap: 0,
        enforceMinWidth: false,
      );
    }
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
    final minRequiredWidth = _kMinStaffColumnWidth * staffCount;
    final enforceMinWidth =
        minRequiredWidth + gapsWidth <= dayInnerWidth && staffCount > 0;
    if (enforceMinWidth) {
      columnWidth = max(columnWidth, _kMinStaffColumnWidth);
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
        columnWidths[staffCount - 1] = max(0.0, columnWidths.last + remainder);
      }
    }
    final flexes = columnWidths
        .map((width) => max(1, (width * 1000).round()))
        .toList(growable: false);

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

    return _CompactStaffLayout(
      columnWidths: columnWidths,
      flexes: flexes,
      columnGap: effectiveGap,
      enforceMinWidth: enforceMinWidth,
    );
  }

  Widget _buildDayBody(
    BuildContext context,
    ThemeData theme,
    DateTime now,
    _WeekDayData data,
    Color background,
    double dayGridWidth,
    double gridHeight,
    double slotExtent,
    _CompactStaffLayout? staffLayout,
    bool showSlotStartTimes,
  ) {
    final isToday = DateUtils.isSameDay(data.date, now);
    final borderColor =
        isToday
            ? theme.colorScheme.primary.withValues(alpha: 0.72)
            : theme.colorScheme.outline.withValues(alpha: 0.72);
    assert(
      staff.isEmpty || staffLayout != null,
      'Staff layout is required when staff members are present.',
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color:
            isToday
                ? Color.alphaBlend(
                  theme.colorScheme.primary.withValues(alpha: 0.05),
                  background,
                )
                : background,
        border: Border.all(color: borderColor, width: _kDayColumnBorderWidth),
      ),
      padding: const EdgeInsets.fromLTRB(
        0,
        _kDayBodyTopPadding,
        0,
        _kDayBodyBottomPadding,
      ),
      child: _buildStaffColumns(
        context: context,
        theme: theme,
        data: data,
        dayGridWidth: dayGridWidth,
        layout: staffLayout,
        gridHeight: gridHeight,
        slotExtent: slotExtent,
        showSlotStartTimes: showSlotStartTimes,
      ),
    );
  }

  Widget _buildStaffColumns({
    required BuildContext context,
    required ThemeData theme,
    required _WeekDayData data,
    required double dayGridWidth,
    required _CompactStaffLayout? layout,
    required double gridHeight,
    required double slotExtent,
    required bool showSlotStartTimes,
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
    final enforceMinWidth = layout?.enforceMinWidth ?? false;
    final dividerColor = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.5,
    );

    Widget buildStaffColumn(int index) {
      final staffMember = staff[index];
      final width =
          layout != null && index < layout.columnWidths.length
              ? layout.columnWidths[index]
              : 0.0;
      final flex =
          layout != null && index < layout.flexes.length
              ? layout.flexes[index]
              : max(1, (width * 1000).round());
      final minWidthConstraint = enforceMinWidth ? _kMinStaffColumnWidth : 0.0;
      return Flexible(
        flex: flex,
        child: ConstrainedBox(
          constraints:
              minWidthConstraint > 0
                  ? BoxConstraints(minWidth: minWidthConstraint)
                  : const BoxConstraints(),
          child: SizedBox(
            height: gridHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border:
                    index == staffCount - 1
                        ? null
                        : Border(
                          right: BorderSide(color: dividerColor, width: 1),
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
                verticalController: verticalController,
                clientsWithOutstandingPayments: clientsWithOutstandingPayments,
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
                hoverPreviewController: hoverPreviewController,
                openStart: data.openStart,
                openEnd: data.openEnd,
                compact: true,
                showSlotStartTimes: showSlotStartTimes,
                readOnly: readOnly,
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: dayGridWidth,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            for (var index = 0; index < staffCount; index++)
              buildStaffColumn(index),
          ],
        ),
      ),
    );
  }

  Widget _buildOperatorHeaderRow(
    BuildContext context,
    ThemeData theme,
    double contentWidth,
    double dayWidth,
    _CompactStaffLayout layout,
  ) {
    if (staff.isEmpty) {
      return const SizedBox.shrink();
    }
    final headerBackground = theme.colorScheme.surfaceContainerHigh.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.65 : 0.85,
    );
    final borderColor = theme.colorScheme.outline.withValues(alpha: 0.72);

    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _WeekSchedule._timeScaleExtent,
            child: Align(
              alignment: Alignment.center,
              child: Text('Operatori', style: theme.textTheme.labelMedium),
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
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: headerBackground,
                        borderRadius: BorderRadius.circular(
                          _kDayHeaderBorderRadius,
                        ),
                        border: Border.all(
                          color: borderColor,
                          width: _kDayColumnBorderWidth,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: _buildStaffHeaderRow(
                        context,
                        theme,
                        dayData[dayIndex],
                        layout,
                      ),
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

  Widget _buildStaffHeaderRow(
    BuildContext context,
    ThemeData theme,
    _WeekDayData data,
    _CompactStaffLayout layout,
  ) {
    final staffCount = staff.length;
    if (staffCount == 0) {
      return const SizedBox.shrink();
    }
    final children = <Widget>[];
    for (var index = 0; index < staffCount; index++) {
      children.add(
        Flexible(
          flex: index < layout.flexes.length ? layout.flexes[index] : 1,
          child: _buildStaffHeaderCell(
            context,
            theme,
            data,
            staff[index],
            layout.enforceMinWidth,
            index != staffCount - 1,
          ),
        ),
      );
    }

    return SizedBox(
      height: _kStaffHeaderHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _buildStaffHeaderCell(
    BuildContext context,
    ThemeData theme,
    _WeekDayData data,
    StaffMember staffMember,
    bool enforceMinWidth,
    bool showTrailingDivider,
  ) {
    final minWidthConstraint = enforceMinWidth ? _kMinStaffColumnWidth : 0.0;
    final canManageDay =
        (onCreateShift != null ||
            onEditShift != null ||
            onDeleteShift != null) ||
        (onCreateAbsence != null ||
            onEditAbsence != null ||
            onDeleteAbsence != null);
    final manageCallback =
        !canManageDay
            ? null
            : () async {
              await _handleStaffDayManagement(
                context,
                staff: staffMember,
                day: data.date,
                shifts: data.shiftsByStaff[staffMember.id] ?? const <Shift>[],
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
            };

    final initialsValue = _staffInitials(staffMember.fullName).toUpperCase();
    final displayInitials = initialsValue.isEmpty ? '--' : initialsValue;
    final pillTextStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
      color: theme.colorScheme.primary,
    );
    final borderColor = theme.colorScheme.outline.withValues(alpha: 0.56);

    return ConstrainedBox(
      constraints:
          minWidthConstraint > 0
              ? BoxConstraints(minWidth: minWidthConstraint)
              : const BoxConstraints(),
      child: SizedBox(
        height: _kStaffHeaderHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border:
                showTrailingDivider
                    ? Border(right: BorderSide(color: borderColor, width: 1))
                    : null,
          ),
          child: _StaffHeaderButton(
            enabled: canManageDay,
            tooltip:
                'Gestisci turni e assenze per ${_formatCalendarDayLabel(data.date)}',
            onPressed: manageCallback,
            child: Center(
              child: Tooltip(
                message: staffMember.fullName,
                waitDuration: const Duration(milliseconds: 250),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: max(40, minWidthConstraint),
                    ),
                    child: Text(
                      displayInitials,
                      style: pillTextStyle,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
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
    required this.readOnly,
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
  final bool readOnly;

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
              readOnly: readOnly,
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
    required this.readOnly,
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
  final bool readOnly;

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
              if (!readOnly)
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
    final tileBorderRadius = BorderRadius.circular(14);
    final timeLabel =
        '${_timeFormat.format(appointment.start)} - ${_timeFormat.format(appointment.end)}';
    final serviceLabel =
        serviceNames.isNotEmpty ? serviceNames.join(', ') : null;
    final subtitleColor = theme.colorScheme.onSurfaceVariant;
    final issues =
        anomalies.toList()..sort((a, b) => a.index.compareTo(b.index));
    final isCancelled = appointment.status == AppointmentStatus.cancelled;
    final hasWarnings = issues.isNotEmpty;
    final baseTileColor =
        isPlaceholder
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : isCancelled
            ? Colors.transparent
            : theme.colorScheme.surfaceContainerHighest;
    final tileColor =
        hasWarnings
            ? Color.alphaBlend(
              theme.colorScheme.errorContainer.withValues(alpha: 0.38),
              baseTileColor,
            )
            : baseTileColor;
    final borderColor =
        hasWarnings
            ? theme.colorScheme.error.withValues(alpha: 0.55)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.24);

    return Material(
      color: tileColor,
      shape: RoundedRectangleBorder(
        borderRadius: tileBorderRadius,
        side: BorderSide(color: borderColor, width: hasWarnings ? 1.4 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: tileBorderRadius,
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

enum AppointmentInteractionPhase {
  idle,
  hover,
  dragging,
  conflict,
  accepting,
  cancelled,
}

class AppointmentInteractionState {
  const AppointmentInteractionState({
    this.phase = AppointmentInteractionPhase.idle,
    this.hoverStart,
    this.previewStart,
    this.previewDuration,
    this.dragAppointment,
    this.hasConflict = false,
    this.lastOffset,
  });

  static const Object _unset = Object();

  final AppointmentInteractionPhase phase;
  final DateTime? hoverStart;
  final DateTime? previewStart;
  final Duration? previewDuration;
  final Appointment? dragAppointment;
  final bool hasConflict;
  final Offset? lastOffset;

  bool get isDragging =>
      phase == AppointmentInteractionPhase.dragging ||
      phase == AppointmentInteractionPhase.conflict ||
      phase == AppointmentInteractionPhase.accepting;

  AppointmentInteractionState copyWith({
    AppointmentInteractionPhase? phase,
    Object? hoverStart = _unset,
    Object? previewStart = _unset,
    Object? previewDuration = _unset,
    Object? dragAppointment = _unset,
    bool? hasConflict,
    Object? lastOffset = _unset,
  }) {
    return AppointmentInteractionState(
      phase: phase ?? this.phase,
      hoverStart:
          identical(hoverStart, _unset)
              ? this.hoverStart
              : hoverStart as DateTime?,
      previewStart:
          identical(previewStart, _unset)
              ? this.previewStart
              : previewStart as DateTime?,
      previewDuration:
          identical(previewDuration, _unset)
              ? this.previewDuration
              : previewDuration as Duration?,
      dragAppointment:
          identical(dragAppointment, _unset)
              ? this.dragAppointment
              : dragAppointment as Appointment?,
      hasConflict: hasConflict ?? this.hasConflict,
      lastOffset:
          identical(lastOffset, _unset)
              ? this.lastOffset
              : lastOffset as Offset?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppointmentInteractionState &&
        other.phase == phase &&
        other.hoverStart == hoverStart &&
        other.previewStart == previewStart &&
        other.previewDuration == previewDuration &&
        other.dragAppointment == dragAppointment &&
        other.hasConflict == hasConflict &&
        other.lastOffset == lastOffset;
  }

  @override
  int get hashCode => Object.hash(
    phase,
    hoverStart,
    previewStart,
    previewDuration,
    dragAppointment,
    hasConflict,
    lastOffset,
  );
}

class AppointmentInteractionController extends ChangeNotifier {
  AppointmentInteractionController();
  AppointmentInteractionState _state = const AppointmentInteractionState();

  AppointmentInteractionState get state => _state;

  void setHover(DateTime? start) {
    if (_state.isDragging) {
      return;
    }
    final nextPhase =
        start == null
            ? AppointmentInteractionPhase.idle
            : AppointmentInteractionPhase.hover;
    _update(_state.copyWith(hoverStart: start, phase: nextPhase), 'hover');
  }

  void clearHover() => setHover(null);

  void startDrag(Appointment appointment) {
    _update(
      _state.copyWith(
        phase: AppointmentInteractionPhase.dragging,
        dragAppointment: appointment,
        previewDuration: appointment.duration,
        hoverStart: null,
      ),
      'start-drag',
    );
  }

  void updatePreview({
    required DateTime previewStart,
    required Duration duration,
    required bool hasConflict,
    Offset? localOffset,
  }) {
    if (_state.dragAppointment == null) {
      return;
    }
    final nextPhase =
        hasConflict
            ? AppointmentInteractionPhase.conflict
            : AppointmentInteractionPhase.dragging;
    _update(
      _state.copyWith(
        previewStart: previewStart,
        previewDuration: duration,
        hasConflict: hasConflict,
        lastOffset: localOffset,
        phase: nextPhase,
      ),
      'drag-update',
    );
  }

  void markAccepting() {
    if (!_state.isDragging) {
      return;
    }
    _update(
      _state.copyWith(phase: AppointmentInteractionPhase.accepting),
      'accepting',
    );
  }

  void finishDrag() {
    _resetToIdle(reason: 'finish');
  }

  void cancelDrag() {
    if (!_state.isDragging &&
        _state.phase != AppointmentInteractionPhase.accepting &&
        _state.phase != AppointmentInteractionPhase.hover) {
      return;
    }
    _update(
      const AppointmentInteractionState(
        phase: AppointmentInteractionPhase.cancelled,
      ),
      'cancel',
    );
    _resetToIdle(reason: 'cancel-reset');
  }

  void reset() {
    _resetToIdle(reason: 'reset');
  }

  void _resetToIdle({required String reason}) {
    if (_state == const AppointmentInteractionState()) {
      return;
    }
    _update(const AppointmentInteractionState(), reason);
  }

  void _update(AppointmentInteractionState next, String _reason) {
    if (_state == next) {
      return;
    }
    _state = next;
    notifyListeners();
  }
}

class _AppointmentAutoScrollDriver {
  _AppointmentAutoScrollDriver({required this.verticalController});

  final ScrollController verticalController;
  bool _isAutoScrolling = false;

  void handlePointer(Offset globalPosition) {
    if (!verticalController.hasClients) {
      return;
    }
    final position = verticalController.position;
    if (!position.hasPixels || !position.haveDimensions) {
      return;
    }
    if (position.maxScrollExtent <= 0) {
      return;
    }
    final scrollableContext = position.context.notificationContext;
    final renderBox = scrollableContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }

    final topLeft = renderBox.localToGlobal(Offset.zero);
    final bottom = topLeft.dy + renderBox.size.height;
    final edgeTop = topLeft.dy + _kAutoScrollEdgeExtent;
    final edgeBottom = bottom - _kAutoScrollEdgeExtent;

    double? targetOffset;
    if (globalPosition.dy < edgeTop && position.pixels > 0) {
      final distanceIntoEdge = (edgeTop - globalPosition.dy).clamp(
        0.0,
        _kAutoScrollEdgeExtent,
      );
      final t = distanceIntoEdge / _kAutoScrollEdgeExtent;
      final delta =
          _kAutoScrollMinStep + (_kAutoScrollMaxStep - _kAutoScrollMinStep) * t;
      targetOffset = max(0.0, position.pixels - delta);
    } else if (globalPosition.dy > edgeBottom &&
        position.pixels < position.maxScrollExtent) {
      final distanceIntoEdge = (globalPosition.dy - edgeBottom).clamp(
        0.0,
        _kAutoScrollEdgeExtent,
      );
      final t = distanceIntoEdge / _kAutoScrollEdgeExtent;
      final delta =
          _kAutoScrollMinStep + (_kAutoScrollMaxStep - _kAutoScrollMinStep) * t;
      targetOffset = min(position.maxScrollExtent, position.pixels + delta);
    }

    if (targetOffset != null &&
        (targetOffset - position.pixels).abs() >= 0.5 &&
        !_isAutoScrolling &&
        !position.outOfRange) {
      _isAutoScrolling = true;
      verticalController
          .animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 70),
            curve: Curves.linear,
          )
          .whenComplete(() => _isAutoScrolling = false);
    }
  }

  void stop() {
    _isAutoScrolling = false;
  }

  void dispose() {
    stop();
  }
}

class _AppointmentHoverPreviewRequest {
  const _AppointmentHoverPreviewRequest({
    required this.layerLink,
    required this.globalTargetRect,
    required this.appointment,
    required this.client,
    required this.service,
    required this.staff,
    required this.categoriesById,
    required this.categoriesByName,
    this.services = const <Service>[],
    this.roomName,
    this.anomalies = const <AppointmentAnomalyType>{},
    this.hasOutstandingPayments = false,
    this.lastMinuteSlot,
    this.visibleDurationMinutes,
  });

  final LayerLink layerLink;
  final Rect globalTargetRect;
  final Appointment appointment;
  final Client? client;
  final Service? service;
  final List<Service> services;
  final StaffMember staff;
  final String? roomName;
  final Map<String, ServiceCategory> categoriesById;
  final Map<String, ServiceCategory> categoriesByName;
  final Set<AppointmentAnomalyType> anomalies;
  final bool hasOutstandingPayments;
  final LastMinuteSlot? lastMinuteSlot;
  final int? visibleDurationMinutes;

  String get appointmentId => appointment.id;

  _AppointmentPreviewPresentation get presentation =>
      _AppointmentPreviewPresentation.fromContent(
        appointment: appointment,
        client: client,
        service: service,
        services: services,
        roomName: roomName,
        anomalies: anomalies,
        lastMinuteSlot: lastMinuteSlot,
        visibleDurationMinutes: visibleDurationMinutes,
        hasOutstandingPayments: hasOutstandingPayments,
        showNotes: true,
      );
}

class _AppointmentPreviewPresentation {
  const _AppointmentPreviewPresentation({
    required this.servicesToDisplay,
    required this.serviceLabel,
    required this.clientLabel,
    required this.contentDurationMinutes,
    required this.estimatedHeight,
    this.clientPhone,
    this.clientNumber,
    this.noteText,
    this.attentionText,
    this.roomName,
  });

  factory _AppointmentPreviewPresentation.fromContent({
    required Appointment appointment,
    required Client? client,
    required Service? service,
    required List<Service> services,
    required String? roomName,
    required Set<AppointmentAnomalyType> anomalies,
    required LastMinuteSlot? lastMinuteSlot,
    required int? visibleDurationMinutes,
    required bool hasOutstandingPayments,
    required bool showNotes,
  }) {
    final servicesToDisplay =
        services.isNotEmpty
            ? List<Service>.unmodifiable(services)
            : List<Service>.unmodifiable(<Service>[
              if (service != null) service,
            ]);
    final serviceLabel =
        servicesToDisplay.isNotEmpty
            ? servicesToDisplay.map((entry) => entry.name).join(' + ')
            : 'Appuntamento';
    final clientLabel = _appointmentHoverClientLabel(client);
    final trimmedClientPhone = client?.phone.trim();
    final clientPhone =
        trimmedClientPhone != null && trimmedClientPhone.isNotEmpty
            ? trimmedClientPhone
            : null;
    final trimmedClientNumber = client?.clientNumber?.trim();
    final clientNumber =
        trimmedClientNumber != null && trimmedClientNumber.isNotEmpty
            ? trimmedClientNumber
            : null;
    final trimmedNoteText = appointment.notes?.trim();
    final noteText =
        showNotes && trimmedNoteText != null && trimmedNoteText.isNotEmpty
            ? trimmedNoteText
            : null;
    final attentionText = _attentionText(
      isCancelled: appointment.status == AppointmentStatus.cancelled,
      anomalies: anomalies,
    );
    final trimmedRoomName = roomName?.trim();
    final normalizedRoomName =
        trimmedRoomName != null && trimmedRoomName.isNotEmpty
            ? trimmedRoomName
            : null;
    final contentDurationMinutes = max(
      1,
      visibleDurationMinutes ?? appointment.duration.inMinutes,
    );
    final categoryCount =
        servicesToDisplay
            .map(
              (entry) =>
                  entry.category.trim().isNotEmpty
                      ? entry.category.trim().toLowerCase()
                      : entry.name.trim().toLowerCase(),
            )
            .where((label) => label.isNotEmpty)
            .toSet()
            .length;
    final indicatorCount =
        anomalies.length +
        (hasOutstandingPayments ? 1 : 0) +
        (_appointmentHasActivePackage(appointment) ? 1 : 0) +
        (lastMinuteSlot != null ? 1 : 0);
    final visibleAttentionText = anomalies.isEmpty ? attentionText : null;
    return _AppointmentPreviewPresentation(
      servicesToDisplay: servicesToDisplay,
      serviceLabel: serviceLabel,
      clientLabel: clientLabel,
      clientPhone: clientPhone,
      clientNumber: clientNumber,
      noteText: noteText,
      attentionText: visibleAttentionText,
      roomName: normalizedRoomName,
      contentDurationMinutes: contentDurationMinutes,
      estimatedHeight: _estimateAppointmentFigmaPreviewHeight(
        serviceLabel: serviceLabel,
        clientLabel: clientLabel,
        categoryCount: categoryCount,
        indicatorCount: indicatorCount,
        hasPhone: clientPhone != null,
        hasClientNumber: clientNumber != null,
        hasRoom: normalizedRoomName != null,
        noteText: noteText,
        attentionText: visibleAttentionText,
      ),
    );
  }

  final List<Service> servicesToDisplay;
  final String serviceLabel;
  final String clientLabel;
  final String? clientPhone;
  final String? clientNumber;
  final String? noteText;
  final String? attentionText;
  final String? roomName;
  final int contentDurationMinutes;
  final double estimatedHeight;
}

class _AppointmentHoverAnchor {
  const _AppointmentHoverAnchor({
    required this.layerLink,
    required this.globalTargetRect,
  });

  final LayerLink layerLink;
  final Rect globalTargetRect;
}

class _AppointmentHoverPreviewController extends ChangeNotifier {
  _AppointmentHoverPreviewRequest? _activeRequest;

  _AppointmentHoverPreviewRequest? get activeRequest => _activeRequest;

  void show(_AppointmentHoverPreviewRequest request) {
    final current = _activeRequest;
    if (current != null &&
        current.appointmentId == request.appointmentId &&
        current.globalTargetRect == request.globalTargetRect &&
        identical(current.layerLink, request.layerLink)) {
      return;
    }
    _activeRequest = request;
    notifyListeners();
  }

  void dismiss({String? appointmentId}) {
    final current = _activeRequest;
    if (current == null) {
      return;
    }
    if (appointmentId != null && current.appointmentId != appointmentId) {
      return;
    }
    _activeRequest = null;
    notifyListeners();
  }
}

class _AppointmentHoverPreviewLayer extends StatelessWidget {
  const _AppointmentHoverPreviewLayer({required this.controller});

  final _AppointmentHoverPreviewController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final request = controller.activeRequest;
        if (request == null) {
          return const SizedBox.shrink();
        }
        final preview = request.presentation;
        final viewportSize = MediaQuery.sizeOf(context);
        final spaceLeft = request.globalTargetRect.left;
        final spaceRight = viewportSize.width - request.globalTargetRect.right;
        var placeRight = spaceRight >= spaceLeft;
        if (placeRight &&
            spaceRight < _kHoverPreviewWidth + _kHoverPreviewGap &&
            spaceLeft > spaceRight) {
          placeRight = false;
        } else if (!placeRight &&
            spaceLeft < _kHoverPreviewWidth + _kHoverPreviewGap &&
            spaceRight > spaceLeft) {
          placeRight = true;
        }
        final availableWidth =
            placeRight
                ? spaceRight - _kHoverPreviewGap
                : spaceLeft - _kHoverPreviewGap;
        final hoverWidth = min(_kHoverPreviewWidth, max(0.0, availableWidth));
        if (hoverWidth <= 0) {
          return const SizedBox.shrink();
        }
        final estimatedHeight = preview.estimatedHeight;
        final desiredTop = request.globalTargetRect.top;
        final maxTop = max(
          0.0,
          viewportSize.height - estimatedHeight - _kHoverPreviewGap,
        );
        final verticalOffset =
            estimatedHeight.isFinite && estimatedHeight > 0
                ? desiredTop.clamp(0.0, maxTop).toDouble() - desiredTop
                : 0.0;
        final horizontalOffset =
            placeRight
                ? request.globalTargetRect.width + _kHoverPreviewGap
                : -hoverWidth - _kHoverPreviewGap;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            CompositedTransformFollower(
              link: request.layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topLeft,
              offset: Offset(horizontalOffset, verticalOffset),
              child: SizedBox(
                key: _kAppointmentHoverPreviewKey,
                width: hoverWidth,
                child: Material(
                  color: Colors.transparent,
                  child: _AppointmentHoverPreviewCard(
                    appointment: request.appointment,
                    client: request.client,
                    service: request.service,
                    services: request.services,
                    roomName: request.roomName,
                    categoriesById: request.categoriesById,
                    categoriesByName: request.categoriesByName,
                    anomalies: request.anomalies,
                    hasOutstandingPayments: request.hasOutstandingPayments,
                    lastMinuteSlot: request.lastMinuteSlot,
                    visibleDurationMinutes: preview.contentDurationMinutes,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
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
    required this.verticalController,
    this.horizontalScrollController,
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
    required this.hoverPreviewController,
    this.openStart,
    this.openEnd,
    this.compact = false,
    this.showSlotStartTimes = false,
    required this.readOnly,
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
  final ScrollController verticalController;
  final ScrollController? horizontalScrollController;
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
  final _AppointmentHoverPreviewController hoverPreviewController;
  final DateTime? openStart;
  final DateTime? openEnd;
  final bool compact;
  final bool showSlotStartTimes;
  final bool readOnly;

  @override
  State<_StaffDayColumn> createState() => _StaffDayColumnState();
}

class _StaffDayColumnState extends State<_StaffDayColumn> {
  static final DateFormat _timeLabel = DateFormat('HH:mm', 'it_IT');

  late final AppointmentInteractionController _interactionController;
  late _AppointmentAutoScrollDriver _autoScrollDriver;
  DateTime? _lastDragUpdateAt;

  @override
  void initState() {
    super.initState();
    _interactionController = AppointmentInteractionController();
    _interactionController.addListener(_onInteractionChange);
    _autoScrollDriver = _AppointmentAutoScrollDriver(
      verticalController: widget.verticalController,
    );
    widget.verticalController.addListener(_handleScrollActivity);
    widget.horizontalScrollController?.addListener(_handleScrollActivity);
  }

  @override
  void didUpdateWidget(covariant _StaffDayColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verticalController != widget.verticalController) {
      oldWidget.verticalController.removeListener(_handleScrollActivity);
      _autoScrollDriver.dispose();
      _autoScrollDriver = _AppointmentAutoScrollDriver(
        verticalController: widget.verticalController,
      );
      widget.verticalController.addListener(_handleScrollActivity);
    }
    if (oldWidget.horizontalScrollController !=
        widget.horizontalScrollController) {
      oldWidget.horizontalScrollController?.removeListener(
        _handleScrollActivity,
      );
      widget.horizontalScrollController?.addListener(_handleScrollActivity);
    }
    if (widget.readOnly && !oldWidget.readOnly) {
      widget.hoverPreviewController.dismiss();
    }
  }

  @override
  void dispose() {
    widget.verticalController.removeListener(_handleScrollActivity);
    widget.horizontalScrollController?.removeListener(_handleScrollActivity);
    _interactionController.removeListener(_onInteractionChange);
    _interactionController.dispose();
    _autoScrollDriver.dispose();
    super.dispose();
  }

  double get _totalMinutes =>
      widget.timelineEnd.difference(widget.timelineStart).inMinutes.toDouble();

  bool _hasTimelineGridDuring(DateTime start, DateTime end) {
    for (final shift in widget.shifts) {
      if (_overlapsRange(shift.start, shift.end, start, end)) {
        return true;
      }
    }
    if (widget.shifts.isNotEmpty) {
      return false;
    }
    final openStart = widget.openStart;
    final openEnd = widget.openEnd;
    if (openStart != null && openEnd != null) {
      return _overlapsRange(openStart, openEnd, start, end);
    }
    return false;
  }

  List<_DateSegment> _buildNoShiftSegments() {
    final rangeStart = widget.openStart ?? widget.timelineStart;
    final rangeEnd = widget.openEnd ?? widget.timelineEnd;
    final visibleRange = _segmentWithinTimeline(
      rangeStart,
      rangeEnd,
      widget.timelineStart,
      widget.timelineEnd,
    );
    if (visibleRange == null) {
      return const <_DateSegment>[];
    }

    final activeSegments =
        widget.shifts
            .map(
              (shift) => _segmentWithinTimeline(
                shift.start,
                shift.end,
                visibleRange.start,
                visibleRange.end,
              ),
            )
            .whereType<_DateSegment>()
            .toList()
          ..sort((first, second) => first.start.compareTo(second.start));

    if (activeSegments.isEmpty) {
      return <_DateSegment>[
        _DateSegment(start: visibleRange.start, end: visibleRange.end),
      ];
    }

    final mergedSegments = <_DateSegment>[];
    for (final segment in activeSegments) {
      if (mergedSegments.isEmpty) {
        mergedSegments.add(segment);
        continue;
      }
      final previous = mergedSegments.last;
      if (!segment.start.isAfter(previous.end)) {
        mergedSegments[mergedSegments.length - 1] = _DateSegment(
          start: previous.start,
          end: segment.end.isAfter(previous.end) ? segment.end : previous.end,
        );
        continue;
      }
      mergedSegments.add(segment);
    }

    final noShiftSegments = <_DateSegment>[];
    var cursor = visibleRange.start;
    for (final segment in mergedSegments) {
      if (segment.start.isAfter(cursor)) {
        noShiftSegments.add(_DateSegment(start: cursor, end: segment.start));
      }
      if (segment.end.isAfter(cursor)) {
        cursor = segment.end;
      }
    }
    if (cursor.isBefore(visibleRange.end)) {
      noShiftSegments.add(_DateSegment(start: cursor, end: visibleRange.end));
    }
    return noShiftSegments;
  }

  Set<AppointmentAnomalyType> _anomaliesForPlacement(
    Appointment appointment, {
    required DateTime start,
    required DateTime end,
  }) {
    final previewed = appointment.copyWith(
      start: start,
      end: end,
      staffId: widget.staffMember.id,
      salonId:
          widget.staffMember.salonId.trim().isNotEmpty
              ? widget.staffMember.salonId.trim()
              : appointment.salonId,
    );
    return calculateAppointmentAnomalies(
      appointment: previewed,
      shifts: widget.shifts,
      absences: widget.absences,
      now: DateTime.now(),
    );
  }

  List<Widget> _buildSegmentSlotDividers({
    required DateTime segmentStart,
    required DateTime segmentEnd,
    required double pixelsPerMinute,
    required Color hourColor,
    required Color minorColor,
  }) {
    if (!segmentEnd.isAfter(segmentStart)) {
      return const <Widget>[];
    }

    final dividers = <Widget>[];
    var boundary = _ceilToSlot(segmentStart, widget.slotMinutes);
    if (!boundary.isAfter(segmentStart)) {
      boundary = boundary.add(Duration(minutes: widget.slotMinutes));
    }

    while (boundary.isBefore(segmentEnd)) {
      final isHourBoundary = boundary.minute == 0;
      final thickness = isHourBoundary ? 1.6 : 1.0;
      final top = boundary.difference(segmentStart).inMinutes * pixelsPerMinute;
      dividers.add(
        Positioned(
          top: max(0.0, top - (thickness / 2)),
          left: 0,
          right: 0,
          child: Container(
            height: thickness,
            color: isHourBoundary ? hourColor : minorColor,
          ),
        ),
      );
      boundary = boundary.add(Duration(minutes: widget.slotMinutes));
    }

    return dividers;
  }

  void _endDragAfterFrame({bool cancelled = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (cancelled) {
        _interactionController.cancelDrag();
      } else {
        _interactionController.finishDrag();
      }
      _autoScrollDriver.stop();
      _lastDragUpdateAt = null;
    });
  }

  void _onInteractionChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleScrollActivity() {
    widget.hoverPreviewController.dismiss();
  }

  void _handleHover(PointerHoverEvent event, double gridHeight) {
    if (widget.readOnly) {
      return;
    }
    final interaction = _interactionController.state;
    if (interaction.isDragging) {
      if (interaction.hoverStart != null) {
        _interactionController.clearHover();
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
    if (interaction.hoverStart != hoverStart) {
      _interactionController.setHover(hoverStart);
    }
  }

  void _clearHover(PointerExitEvent event) {
    if (_interactionController.state.hoverStart != null) {
      _interactionController.clearHover();
    }
    widget.hoverPreviewController.dismiss();
  }

  void _handleTap(TapUpDetails details, double gridHeight) {
    if (widget.readOnly) {
      return;
    }
    final interaction = _interactionController.state;
    if (interaction.isDragging) {
      return;
    }
    final totalMinutes = _totalMinutes;
    if (totalMinutes <= 0) {
      return;
    }
    if (interaction.hoverStart != null) {
      _interactionController.clearHover();
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

  Appointment? _appointmentAtTapOffset(
    Offset localPosition,
    double gridHeight,
  ) {
    final totalMinutes = _totalMinutes;
    if (totalMinutes <= 0) {
      return null;
    }
    final clampedDy = localPosition.dy.clamp(0.0, gridHeight);
    final minuteOffset = (clampedDy / gridHeight) * totalMinutes;

    Appointment? candidate;
    for (final appointment in widget.appointments) {
      final segment = _segmentWithinTimeline(
        appointment.start,
        appointment.end,
        widget.timelineStart,
        widget.timelineEnd,
      );
      if (segment == null) {
        continue;
      }
      final segmentStartMinutes =
          segment.start.difference(widget.timelineStart).inMinutes.toDouble();
      final segmentEndMinutes =
          segment.end.difference(widget.timelineStart).inMinutes.toDouble();
      final isWithinSegment =
          minuteOffset >= segmentStartMinutes &&
          minuteOffset < segmentEndMinutes;
      if (!isWithinSegment) {
        continue;
      }
      // If two cards overlap visually, prefer the one that starts later (topmost).
      if (candidate == null || appointment.start.isAfter(candidate.start)) {
        candidate = appointment;
      }
    }
    return candidate;
  }

  void _handleCalendarTap(TapUpDetails details, double gridHeight) {
    if (widget.readOnly) {
      return;
    }
    final tappedAppointment = _appointmentAtTapOffset(
      details.localPosition,
      gridHeight,
    );
    if (tappedAppointment != null) {
      widget.onEdit(tappedAppointment);
      return;
    }
    _handleTap(details, gridHeight);
  }

  String? _slotConflictMessage(
    DateTime start,
    DateTime end,
    Appointment movingAppointment,
    StaffMember targetStaff,
  ) {
    final serviceWindows =
        EquipmentAvailabilityChecker.serviceWindowsForAppointment(
          appointment: movingAppointment,
          servicesById: widget.servicesById,
          startOverride: start,
          endOverride: end,
        );

    final incompatibleService = serviceWindows.firstWhereOrNull((window) {
      final allowedRoles = window.service.staffRoles;
      if (allowedRoles.isEmpty) {
        return false;
      }
      return !_hasAllowedRole(targetStaff, allowedRoles);
    });
    if (incompatibleService != null) {
      final service = incompatibleService.service;
      return 'L\'operatore selezionato non può erogare "${service.name}". Scegli un altro operatore.';
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

    if (serviceWindows.isEmpty ||
        serviceWindows.every(
          (window) => window.service.requiredEquipmentIds.isEmpty,
        )) {
      return null;
    }
    final salon = widget.salonsById[movingAppointment.salonId];
    if (salon == null) {
      return null;
    }

    final blockingEquipment = <String>{};
    for (final window in serviceWindows) {
      final service = window.service;
      if (service.requiredEquipmentIds.isEmpty) {
        continue;
      }
      final result = EquipmentAvailabilityChecker.check(
        salon: salon,
        service: service,
        allServices: widget.servicesById.values,
        appointments: widget.allAppointments,
        start: window.start,
        end: window.end,
        excludeAppointmentId: movingAppointment.id,
      );
      if (result.hasConflicts) {
        blockingEquipment.addAll(result.blockingEquipment);
      }
    }
    if (blockingEquipment.isEmpty) {
      return null;
    }
    final equipmentLabel = blockingEquipment.join(', ');
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
    final interaction = _interactionController.state;
    final suppressShiftDecorations = widget.absences.isNotEmpty;
    final noShiftSegments = _buildNoShiftSegments();

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
          child: IgnorePointer(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
        );
      }
    }

    final noShiftOverlays = noShiftSegments
        .map((segment) {
          final top =
              segment.start.difference(widget.timelineStart).inMinutes *
              pixelsPerMinute;
          final height = max(
            widget.slotExtent,
            segment.end.difference(segment.start).inMinutes * pixelsPerMinute,
          );
          final showLabel = height >= 34;
          return Positioned(
            top: top,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Stack(
                children: [
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha:
                            theme.brightness == Brightness.dark ? 0.16 : 0.22,
                      ),
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.error.withValues(alpha: 0.3),
                        ),
                        bottom: BorderSide(
                          color: theme.colorScheme.error.withValues(
                            alpha: 0.22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showLabel)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withValues(
                            alpha: 0.96,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.38,
                            ),
                          ),
                        ),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Icon(
                            Icons.warning_amber_rounded,
                            key: const ValueKey<String>('no-shift-marker'),
                            size: 16,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        })
        .toList(growable: false);

    final dragStart = interaction.previewStart;
    final dragDuration =
        interaction.previewDuration ?? interaction.dragAppointment?.duration;
    final dragAppointment = interaction.dragAppointment;
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
        final previewed = dragAppointment.copyWith(
          start: dragStart,
          end: dragEnd,
        );
        final client = widget.clientsById[previewed.clientId];
        final anomalies = _anomaliesForPlacement(
          dragAppointment,
          start: dragStart,
          end: dragEnd,
        );
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
        final segmentMinutes = segment.end.difference(segment.start).inMinutes;
        final visibleMinutes = max(1, segmentMinutes);
        final previewHeight = max(
          widget.slotExtent,
          segmentMinutes * pixelsPerMinute,
        );
        dragOverlay = Positioned(
          top: top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: SizedBox(
              height: previewHeight,
              child: Opacity(
                opacity: interaction.hasConflict ? 0.65 : 1,
                child: _AppointmentCard(
                  appointment: previewed,
                  client: client,
                  service: previewService,
                  services: services,
                  staff: widget.staffMember,
                  roomName: roomName,
                  height: previewHeight,
                  visibleDurationMinutes: visibleMinutes,
                  anomalies: anomalies,
                  lockReason: null,
                  highlight: true,
                  categoriesById: widget.categoriesById,
                  categoriesByName: widget.categoriesByName,
                  hideContent: false,
                  hasOutstandingPayments: hasOutstandingPayments,
                  expandToContent: false,
                  showNotes: true,
                ),
              ),
            ),
          ),
        );
      }
    }

    final hoverStart = interaction.hoverStart;
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
                ? theme.colorScheme.errorContainer.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.32 : 0.48,
                )
                : theme.colorScheme.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.22 : 0.14,
                );
        final outlineColor =
            isBusy
                ? theme.colorScheme.error.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.74 : 0.58,
                )
                : theme.colorScheme.primary.withValues(alpha: 0.96);
        final labelTextColor =
            isBusy
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onPrimary;
        final labelBackground =
            isBusy
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.98)
                : theme.colorScheme.primary;
        final overlayBorderWidth = isBusy ? 1.8 : 2.6;
        final overlayShadowColor =
            isBusy
                ? theme.colorScheme.error.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.18 : 0.12,
                )
                : theme.colorScheme.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.28 : 0.16,
                );
        final labelBorderColor =
            isBusy ? outlineColor.withValues(alpha: 0.7) : outlineColor;
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
          child: IgnorePointer(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: hoverHeight,
                  decoration: BoxDecoration(
                    color: fillColor,
                    border: Border.all(
                      color: outlineColor,
                      width: overlayBorderWidth,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: overlayShadowColor,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: labelBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: labelBorderColor),
                      boxShadow: [
                        BoxShadow(
                          color: overlayShadowColor,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
          ),
        );
      }
    }

    return MouseRegion(
      onHover: (event) => _handleHover(event, gridHeight),
      onExit: _clearHover,
      child: SizedBox(
        height: gridHeight,
        child: Stack(
          children: [
            Listener(
              onPointerDown: (_) => widget.hoverPreviewController.dismiss(),
              onPointerUp: (_) => _endDragAfterFrame(),
              onPointerCancel: (_) => _endDragAfterFrame(cancelled: true),
              child: DragTarget<_AppointmentDragData>(
                onWillAcceptWithDetails:
                    widget.readOnly ? (_) => false : (_) => true,
                onMove: (details) {
                  if (widget.readOnly) {
                    return;
                  }
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox == null || !renderBox.hasSize) {
                    return;
                  }
                  if (renderBox.size.height <= 0) {
                    return;
                  }
                  final now = DateTime.now();
                  if (_lastDragUpdateAt != null &&
                      now.difference(_lastDragUpdateAt!) <
                          _kMinDragUpdateInterval) {
                    return;
                  }
                  final payload = details.data;
                  final interaction = _interactionController.state;
                  if (!interaction.isDragging ||
                      interaction.dragAppointment?.id !=
                          payload.appointment.id) {
                    _interactionController.startDrag(payload.appointment);
                  }
                  _autoScrollDriver.handlePointer(details.offset);
                  final localOffset = renderBox.globalToLocal(details.offset);
                  final clampedDy = localOffset.dy.clamp(
                    0.0,
                    renderBox.size.height,
                  );
                  final totalMinutes = _totalMinutes;
                  if (totalMinutes <= 0) {
                    return;
                  }
                  var minuteOffset =
                      (clampedDy / renderBox.size.height) * totalMinutes;
                  final durationMinutes = payload.duration.inMinutes.toDouble();
                  final maxStartMinutes = max(
                    0.0,
                    totalMinutes - durationMinutes,
                  );
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
                  _interactionController.updatePreview(
                    previewStart: previewStart,
                    duration: payload.duration,
                    hasConflict: hasConflict,
                    localOffset: localOffset,
                  );
                  _lastDragUpdateAt = now;
                },
                onLeave: (_) {
                  _endDragAfterFrame(cancelled: true);
                },
                builder: (context, candidateData, rejectedData) {
                  final columnBackground = theme.colorScheme.surface.withValues(
                    alpha: 0.96,
                  );
                  return ClipRect(
                    child: Container(
                      height: gridHeight,
                      color: columnBackground,
                      child: Stack(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp:
                                widget.readOnly
                                    ? null
                                    : (details) =>
                                        _handleCalendarTap(details, gridHeight),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double timeLabelWidth = min(
                                  constraints.maxWidth,
                                  _AppointmentCalendarViewState
                                      ._timeScaleExtent,
                                );
                                return Column(
                                  children: List.generate(totalSlots, (index) {
                                    final DateTime slotStart = widget
                                        .timelineStart
                                        .add(
                                          Duration(
                                            minutes: index * widget.slotMinutes,
                                          ),
                                        );
                                    final bool isHourBoundary =
                                        slotStart.minute == 0;
                                    final DateTime slotEnd = slotStart.add(
                                      Duration(minutes: widget.slotMinutes),
                                    );
                                    final bool hasTimelineGrid =
                                        _hasTimelineGridDuring(
                                          slotStart,
                                          slotEnd,
                                        ) &&
                                        !suppressShiftDecorations;
                                    BorderSide topBorder = BorderSide.none;
                                    BorderSide bottomBorder = BorderSide.none;
                                    if (hasTimelineGrid) {
                                      final bool isDark =
                                          theme.brightness == Brightness.dark;
                                      final double hourTopAlpha =
                                          isDark ? 0.45 : 0.32;
                                      final double hourBottomAlpha =
                                          isDark ? 0.34 : 0.24;
                                      final double minorTopAlpha =
                                          isDark ? 0.28 : 0.18;
                                      final double minorBottomAlpha =
                                          isDark ? 0.21 : 0.12;
                                      final Color baseHourColor = theme
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: hourTopAlpha);
                                      final Color baseMinorColor = theme
                                          .dividerColor
                                          .withValues(alpha: minorTopAlpha);
                                      final Color hourBottomColor =
                                          baseHourColor.withValues(
                                            alpha: hourBottomAlpha,
                                          );
                                      final Color minorBottomColor =
                                          baseMinorColor.withValues(
                                            alpha: minorBottomAlpha,
                                          );
                                      topBorder =
                                          isHourBoundary
                                              ? BorderSide(
                                                color: baseHourColor,
                                                width: 1,
                                              )
                                              : BorderSide(
                                                color: baseMinorColor,
                                                width: 0.75,
                                              );
                                      bottomBorder =
                                          isHourBoundary
                                              ? BorderSide(
                                                color: hourBottomColor,
                                                width: 1,
                                              )
                                              : BorderSide(
                                                color: minorBottomColor,
                                                width: 0.75,
                                              );
                                    }
                                    final showSlotLabel =
                                        widget.showSlotStartTimes;
                                    final String? slotLabel =
                                        showSlotLabel
                                            ? _timeLabel.format(slotStart)
                                            : null;
                                    final Widget? slotLabelWidget =
                                        slotLabel == null
                                            ? null
                                            : Align(
                                              alignment: Alignment.topCenter,
                                              child: SizedBox(
                                                width: timeLabelWidth,
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        4,
                                                        6,
                                                        4,
                                                        0,
                                                      ),
                                                  child: Text(
                                                    slotLabel,
                                                    textAlign: TextAlign.center,
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color:
                                                              theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            );
                                    return Container(
                                      height: widget.slotExtent,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: topBorder,
                                          bottom: bottomBorder,
                                        ),
                                      ),
                                      child: slotLabelWidget,
                                    );
                                  }),
                                );
                              },
                            ),
                          ),
                          if (openOverlay != null) openOverlay,
                          ...noShiftOverlays,
                          if (dragOverlay != null) dragOverlay,
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
                                        widget.readOnly ||
                                                widget.onTapLastMinuteSlot ==
                                                    null
                                            ? null
                                            : () => widget.onTapLastMinuteSlot!(
                                              slot,
                                            ),
                                    child: Container(
                                      height: height,
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.30),
                                        border: Border.all(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.50),
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
                                                color:
                                                    theme.colorScheme.primary,
                                              )
                                              : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.flash_on_rounded,
                                                    size: 14,
                                                    color:
                                                        theme
                                                            .colorScheme
                                                            .primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'last\nminute',
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color:
                                                              theme
                                                                  .colorScheme
                                                                  .primary,
                                                          fontWeight:
                                                              FontWeight.w600,
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
                            final description = StringBuffer(
                              absence.type.label,
                            );
                            if (!absence.isAllDay || !absence.isSingleDay) {
                              description.write(' • $timeLabel');
                            }
                            if (absence.notes != null &&
                                absence.notes!.isNotEmpty) {
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
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme.colorScheme.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    );

                            return [
                              Positioned(
                                top: top,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                  child: Container(
                                    height: height,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.errorContainer
                                          .withValues(alpha: 0.5),
                                      border: Border.all(
                                        color: theme.colorScheme.error
                                            .withValues(alpha: 0.6),
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
                              ),
                            ];
                          }),
                          if (!suppressShiftDecorations)
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

                              final baseShiftColor =
                                  theme.brightness == Brightness.dark
                                      ? theme.colorScheme.surfaceBright
                                      : Colors.white;
                              final shiftFillColor = baseShiftColor.withValues(
                                alpha:
                                    theme.brightness == Brightness.dark
                                        ? 0.22
                                        : 0.82,
                              );
                              final shiftBorderColor = theme
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(
                                    alpha:
                                        theme.brightness == Brightness.dark
                                            ? 0.48
                                            : 0.38,
                                  );
                              final shiftHourDividerColor = theme
                                  .colorScheme
                                  .onSurface
                                  .withValues(
                                    alpha:
                                        theme.brightness == Brightness.dark
                                            ? 0.42
                                            : 0.18,
                                  );
                              final shiftMinorDividerColor = theme
                                  .colorScheme
                                  .onSurface
                                  .withValues(
                                    alpha:
                                        theme.brightness == Brightness.dark
                                            ? 0.28
                                            : 0.1,
                                  );

                              final top =
                                  segment.start
                                      .difference(widget.timelineStart)
                                      .inMinutes /
                                  widget.slotMinutes *
                                  widget.slotExtent;
                              final height = max(
                                widget.slotExtent,
                                segment.end
                                        .difference(segment.start)
                                        .inMinutes /
                                    widget.slotMinutes *
                                    widget.slotExtent,
                              );

                              final widgets = <Widget>[
                                Positioned(
                                  top: top,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: SizedBox(
                                      height: height,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: shiftFillColor,
                                                border: Border.all(
                                                  color: shiftBorderColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                          ..._buildSegmentSlotDividers(
                                            segmentStart: segment.start,
                                            segmentEnd: segment.end,
                                            pixelsPerMinute: pixelsPerMinute,
                                            hourColor: shiftHourDividerColor,
                                            minorColor: shiftMinorDividerColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ];

                              if (shift.breakStart != null &&
                                  shift.breakEnd != null) {
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
                                      child: IgnorePointer(
                                        child: Container(
                                          height: breakHeight,
                                          decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme
                                                .errorContainer
                                                .withValues(alpha: 0.35),
                                            border: Border.all(
                                              color: theme.colorScheme.error
                                                  .withValues(alpha: 0.4),
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
                          if (hoverOverlay != null) hoverOverlay,
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
                                segment.end
                                    .difference(segment.start)
                                    .inMinutes /
                                widget.slotMinutes *
                                widget.slotExtent;
                            final visibleMinutes = max(
                              1,
                              segment.end.difference(segment.start).inMinutes,
                            );
                            final client =
                                widget.clientsById[appointment.clientId];
                            final services =
                                appointment.serviceIds
                                    .map((id) => widget.servicesById[id])
                                    .whereType<Service>()
                                    .toList();
                            final service =
                                services.isNotEmpty
                                    ? services.first
                                    : widget.servicesById[appointment
                                        .serviceId];
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
                              key: ValueKey<String>(
                                'appointment-card-${appointment.id}',
                              ),
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
                              onHoverOverlayShow:
                                  (
                                    anchor,
                                  ) => widget.hoverPreviewController.show(
                                    _AppointmentHoverPreviewRequest(
                                      layerLink: anchor.layerLink,
                                      globalTargetRect: anchor.globalTargetRect,
                                      appointment: appointment,
                                      client: client,
                                      service: service,
                                      services: services,
                                      staff: widget.staffMember,
                                      roomName: roomName,
                                      categoriesById: widget.categoriesById,
                                      categoriesByName: widget.categoriesByName,
                                      anomalies: issues,
                                      hasOutstandingPayments:
                                          hasOutstandingPayments,
                                      lastMinuteSlot: matchingSlot,
                                      visibleDurationMinutes: visibleMinutes,
                                    ),
                                  ),
                              onHoverOverlayHide:
                                  () => widget.hoverPreviewController.dismiss(
                                    appointmentId: appointment.id,
                                  ),
                            );
                            if (isLocked || widget.readOnly) {
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
                                data: _AppointmentDragData(
                                  appointment: appointment,
                                ),
                                maxSimultaneousDrags: 1,
                                dragAnchorStrategy: pointerDragAnchorStrategy,
                                onDragStarted: () {
                                  widget.hoverPreviewController.dismiss(
                                    appointmentId: appointment.id,
                                  );
                                  _interactionController.startDrag(appointment);
                                },
                                onDragCompleted: _endDragAfterFrame,
                                onDragEnd: (_) => _endDragAfterFrame(),
                                onDraggableCanceled:
                                    (_, __) =>
                                        _endDragAfterFrame(cancelled: true),
                                feedback: _DragFeedback(
                                  child: _DragPreviewCard(
                                    appointment: appointment,
                                    client: client,
                                    service: service,
                                    services: services,
                                    staff: widget.staffMember,
                                    roomName: roomName,
                                    height: height,
                                    anomalies:
                                        interaction.previewStart != null &&
                                                interaction
                                                        .dragAppointment
                                                        ?.id ==
                                                    appointment.id
                                            ? _anomaliesForPlacement(
                                              appointment,
                                              start: interaction.previewStart!,
                                              end: interaction.previewStart!
                                                  .add(
                                                    interaction
                                                            .previewDuration ??
                                                        appointment.duration,
                                                  ),
                                            )
                                            : issues,
                                    previewStart: interaction.previewStart,
                                    previewDuration:
                                        interaction.previewDuration ??
                                        appointment.duration,
                                    slotMinutes: widget.interactionSlotMinutes,
                                    lastMinuteSlot: matchingSlot,
                                    categoriesById: widget.categoriesById,
                                    categoriesByName: widget.categoriesByName,
                                    hasOutstandingPayments:
                                        hasOutstandingPayments,
                                    showDuration: true,
                                    expandToContent: true,
                                    showNotes: true,
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
                                    hasOutstandingPayments:
                                        hasOutstandingPayments,
                                  ),
                                ),
                                child: card,
                              ),
                            );
                          }),
                          if (candidateData.isNotEmpty)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color:
                                        interaction.hasConflict
                                            ? theme.colorScheme.error
                                                .withValues(alpha: 0.08)
                                            : theme.colorScheme.primary
                                                .withValues(alpha: 0.08),
                                    border: Border.all(
                                      color:
                                          interaction.hasConflict
                                              ? theme.colorScheme.error
                                                  .withValues(alpha: 0.2)
                                              : theme.colorScheme.primary
                                                  .withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                onAcceptWithDetails: (details) async {
                  if (widget.readOnly) {
                    _endDragAfterFrame(cancelled: true);
                    return;
                  }
                  final payload = details.data;
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox == null) {
                    return;
                  }
                  if (!renderBox.hasSize || renderBox.size.height <= 0) {
                    return;
                  }
                  final localOffset = renderBox.globalToLocal(details.offset);
                  final clampedDy = localOffset.dy.clamp(
                    0.0,
                    renderBox.size.height,
                  );
                  final totalMinutes =
                      widget.timelineEnd
                          .difference(widget.timelineStart)
                          .inMinutes
                          .toDouble();
                  final durationMinutes = payload.duration.inMinutes.toDouble();
                  var minuteOffset =
                      (clampedDy / renderBox.size.height) * totalMinutes;
                  final maxStartMinutes = max(
                    0.0,
                    totalMinutes - durationMinutes,
                  );
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
                    _endDragAfterFrame();
                    ScaffoldMessenger.of(
                      context,
                    ).showAppSnackBar(SnackBar(content: Text(conflictMessage)));
                    return;
                  }

                  final warningAnomalies = _anomaliesForPlacement(
                    payload.appointment,
                    start: newStart,
                    end: newEnd,
                  );
                  final confirmed =
                      await showAppointmentWarningConfirmationDialog(
                        context: context,
                        anomalies: warningAnomalies,
                      );
                  if (!confirmed) {
                    _endDragAfterFrame(cancelled: true);
                    return;
                  }

                  _interactionController.markAccepting();
                  await widget.onReschedule(
                    AppointmentRescheduleRequest(
                      appointment: payload.appointment,
                      newStart: newStart,
                      newEnd: newEnd,
                      newStaffId: widget.staffMember.id,
                      newRoomId: payload.appointment.roomId,
                    ),
                  );
                  _endDragAfterFrame();
                },
              ),
            ),
          ],
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

List<Color> _resolveCategoryColors(
  List<Service> services,
  Map<String, ServiceCategory> categoriesById,
  Map<String, ServiceCategory> categoriesByName,
  String? fallbackLabel,
  ThemeData theme,
) {
  final resolvedColors = <Color>[];
  final seenValues = <int>{};

  void addColor(Color? color) {
    if (color == null) {
      return;
    }
    if (seenValues.add(color.toARGB32())) {
      resolvedColors.add(color);
    }
  }

  for (final service in services) {
    final label =
        service.category.trim().isNotEmpty
            ? service.category.trim()
            : service.name.trim();
    addColor(
      _resolveCategoryColor(
        [service],
        categoriesById,
        categoriesByName,
        label,
        theme,
      ),
    );
  }

  if (resolvedColors.isEmpty) {
    addColor(
      _resolveCategoryColor(
        services,
        categoriesById,
        categoriesByName,
        fallbackLabel,
        theme,
      ),
    );
  }

  return resolvedColors;
}

Gradient? _segmentedVerticalGradient(List<Color> colors) {
  if (colors.length <= 1) {
    return null;
  }

  final gradientColors = <Color>[];
  final stops = <double>[];

  for (var index = 0; index < colors.length; index++) {
    final start = index / colors.length;
    final end = (index + 1) / colors.length;
    gradientColors.add(colors[index]);
    stops.add(start);
    gradientColors.add(colors[index]);
    stops.add(end);
  }

  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: gradientColors,
    stops: stops,
  );
}

class _AppointmentCard extends StatefulWidget {
  const _AppointmentCard({
    super.key,
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
    this.enableHoverOverlay = true,
    this.showDuration = true,
    this.expandToContent = false,
    this.showNotes = false,
    this.onHoverOverlayShow,
    this.onHoverOverlayHide,
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
  final bool enableHoverOverlay;
  final bool showDuration;
  final bool expandToContent;
  final bool showNotes;
  final ValueChanged<_AppointmentHoverAnchor>? onHoverOverlayShow;
  final VoidCallback? onHoverOverlayHide;

  @override
  State<_AppointmentCard> createState() => _AppointmentCardState();
}

List<String> _attentionMessages({
  required bool isCancelled,
  required Set<AppointmentAnomalyType> anomalies,
}) {
  final messages = <String>[];
  if (isCancelled) {
    messages.add('Appuntamento annullato');
  }
  if (anomalies.isNotEmpty) {
    messages.addAll(
      (anomalies.toList()..sort((a, b) => a.index.compareTo(b.index))).map(
        (issue) => issue.description,
      ),
    );
  }
  return messages;
}

String? _attentionText({
  required bool isCancelled,
  required Set<AppointmentAnomalyType> anomalies,
}) {
  final messages = _attentionMessages(
    isCancelled: isCancelled,
    anomalies: anomalies,
  );
  if (messages.isEmpty) {
    return null;
  }
  return messages.join('\n');
}

double _contentAwareHeight({
  required double baseHeight,
  required bool expandToContent,
  required bool highlight,
  required bool showDurationChip,
  required bool showServiceInfo,
  required bool showClientInfo,
  required bool showClientPhone,
  required bool showClientNumber,
  required bool hasPreviewNote,
  required String? attentionText,
  required bool hasOutstandingPayments,
  required String? serviceLabel,
  required String? clientName,
  required String? clientNumber,
  required String? clientPhone,
  required String? noteText,
  required String? roomName,
}) {
  var height =
      expandToContent ? max(baseHeight, _kBasePreviewHeight) : baseHeight;
  if (!expandToContent) {
    return height;
  }

  final int serviceLength =
      showServiceInfo ? (serviceLabel ?? '').trim().length : 0;
  final int clientNameLength =
      showClientInfo ? (clientName ?? '').trim().length : 0;
  final int clientNumberLength =
      showClientNumber ? (clientNumber ?? '').trim().length : 0;
  final int phoneLength =
      showClientPhone ? (clientPhone ?? '').trim().length : 0;
  final int noteLength = hasPreviewNote ? (noteText ?? '').length : 0;
  final normalizedAttentionText = attentionText?.trim() ?? '';
  final bool hasAttentionText = normalizedAttentionText.isNotEmpty;
  final int attentionLength = normalizedAttentionText.length;
  final int estimatedServiceLines =
      showServiceInfo ? max(1, (serviceLength / 26).ceil()) : 0;
  final int estimatedClientLines =
      showClientInfo ? max(1, (clientNameLength / 22).ceil()) : 0;
  final int estimatedPhoneLines =
      showClientPhone ? max(1, (phoneLength / 24).ceil()) : 0;
  final int estimatedClientNumberLines =
      showClientNumber ? max(1, (clientNumberLength / 22).ceil()) : 0;
  final int estimatedNoteLines =
      hasPreviewNote ? max(1, (noteLength / 28).ceil()) : 0;
  final int estimatedAttentionLines =
      hasAttentionText && expandToContent
          ? max(1, (attentionLength / 28).ceil())
          : 0;
  final int estimatedLines =
      1 +
      estimatedServiceLines +
      estimatedClientLines +
      estimatedClientNumberLines +
      estimatedPhoneLines +
      estimatedNoteLines +
      estimatedAttentionLines;
  final double lineHeight = highlight ? 26.0 : 21.0;
  final double gapUnit = highlight ? 10.0 : 8.0;
  final double gapHeight =
      estimatedLines > 1 ? (estimatedLines - 1) * gapUnit : 0;
  final bool bottomSectionLikely = roomName != null || showDurationChip;
  final double baseHeadroom = highlight ? 114 : 86;
  final double bottomAllowance =
      bottomSectionLikely ? (highlight ? 74 : 54) : (highlight ? 34 : 22);
  final double indicatorAllowance =
      hasOutstandingPayments ? (highlight ? 36 : 26) : 22;
  const double safetyBuffer = 28;
  return max(
    height,
    baseHeadroom +
        estimatedLines * lineHeight +
        gapHeight +
        indicatorAllowance +
        bottomAllowance +
        safetyBuffer,
  );
}

String _appointmentHoverClientLabel(Client? client) {
  final fullName = client?.fullName.trim();
  if (fullName != null && fullName.isNotEmpty) {
    return fullName;
  }
  return 'Cliente non assegnato';
}

double _estimateAppointmentFigmaPreviewHeight({
  required String serviceLabel,
  required String clientLabel,
  required int categoryCount,
  required int indicatorCount,
  required bool hasPhone,
  required bool hasClientNumber,
  required bool hasRoom,
  required String? noteText,
  required String? attentionText,
}) {
  final int titleLines = min(2, max(1, (serviceLabel.length / 24).ceil()));
  final int clientLines = max(1, (clientLabel.length / 24).ceil());
  final int categoryRows =
      categoryCount == 0 ? 0 : max(1, (categoryCount / 2).ceil());
  final int indicatorRows =
      indicatorCount == 0 ? 0 : max(1, (indicatorCount / 2).ceil());
  final int detailRows =
      1 + (hasPhone ? 1 : 0) + (hasClientNumber ? 1 : 0) + (hasRoom ? 1 : 0);
  final int noteLength = noteText?.trim().length ?? 0;
  final int noteLines =
      noteLength == 0 ? 0 : min(6, max(2, (noteLength / 34).ceil()));
  final int attentionLength = attentionText?.trim().length ?? 0;
  final int attentionLines =
      attentionLength == 0 ? 0 : min(3, max(1, (attentionLength / 34).ceil()));
  return max(
    360.0,
    178.0 +
        ((titleLines - 1) * 24.0) +
        ((clientLines - 1) * 18.0) +
        (categoryRows * 30.0) +
        (indicatorRows * 32.0) +
        (detailRows * 52.0) +
        (noteLines == 0 ? 0.0 : 34.0 + (noteLines * 18.0)) +
        (attentionLines == 0 ? 0.0 : 24.0 + (attentionLines * 18.0)),
  );
}

class _AppointmentHoverPreviewCard extends StatelessWidget {
  const _AppointmentHoverPreviewCard({
    required this.appointment,
    required this.client,
    required this.service,
    required this.categoriesById,
    required this.categoriesByName,
    required this.anomalies,
    this.hasOutstandingPayments = false,
    this.roomName,
    this.lastMinuteSlot,
    this.services = const <Service>[],
    this.visibleDurationMinutes,
  });

  final Appointment appointment;
  final Client? client;
  final Service? service;
  final Map<String, ServiceCategory> categoriesById;
  final Map<String, ServiceCategory> categoriesByName;
  final Set<AppointmentAnomalyType> anomalies;
  final bool hasOutstandingPayments;
  final String? roomName;
  final LastMinuteSlot? lastMinuteSlot;
  final List<Service> services;
  final int? visibleDurationMinutes;

  @override
  Widget build(BuildContext context) {
    return _DragFeedback(
      child: _AppointmentLegacyPreviewCard(
        appointment: appointment,
        client: client,
        service: service,
        services: services,
        roomName: roomName,
        height: _kBasePreviewHeight,
        visibleDurationMinutes: visibleDurationMinutes,
        anomalies: anomalies,
        lastMinuteSlot: lastMinuteSlot,
        categoriesById: categoriesById,
        categoriesByName: categoriesByName,
        hasOutstandingPayments: hasOutstandingPayments,
        showDuration: true,
        showNotes: true,
      ),
    );
  }
}

class _AppointmentLegacyPreviewCard extends StatelessWidget {
  const _AppointmentLegacyPreviewCard({
    required this.appointment,
    required this.client,
    required this.service,
    this.services = const <Service>[],
    required this.height,
    this.roomName,
    this.anomalies = const <AppointmentAnomalyType>{},
    this.lastMinuteSlot,
    required this.categoriesById,
    required this.categoriesByName,
    this.visibleDurationMinutes,
    this.hasOutstandingPayments = false,
    this.showDuration = true,
    this.showNotes = false,
  });

  static final DateFormat _timeFormat = DateFormat('HH:mm', 'it_IT');

  final Appointment appointment;
  final Client? client;
  final Service? service;
  final List<Service> services;
  final double height;
  final String? roomName;
  final Set<AppointmentAnomalyType> anomalies;
  final LastMinuteSlot? lastMinuteSlot;
  final Map<String, ServiceCategory> categoriesById;
  final Map<String, ServiceCategory> categoriesByName;
  final int? visibleDurationMinutes;
  final bool hasOutstandingPayments;
  final bool showDuration;
  final bool showNotes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final preview = _AppointmentPreviewPresentation.fromContent(
      appointment: appointment,
      client: client,
      service: service,
      services: services,
      roomName: roomName,
      anomalies: anomalies,
      lastMinuteSlot: lastMinuteSlot,
      visibleDurationMinutes: visibleDurationMinutes,
      hasOutstandingPayments: hasOutstandingPayments,
      showNotes: showNotes,
    );
    final servicesToDisplay = preview.servicesToDisplay;
    final serviceLabel = preview.serviceLabel;
    final clientLabel = preview.clientLabel;
    final status = appointment.status;
    final clientNumber = preview.clientNumber;
    final clientPhone = preview.clientPhone;
    final noteText = preview.noteText;
    final attentionText = preview.attentionText;
    final contentDurationMinutes = preview.contentDurationMinutes;
    final Color surfaceColor = isDark ? const Color(0xFF201C19) : Colors.white;
    final Color primaryContentColor =
        isDark ? const Color(0xFFF5F1EE) : const Color(0xFF151515);
    final Color secondaryContentColor =
        isDark ? const Color(0xFFC9C0BA) : const Color(0xFF6E6661);
    final Color dividerColor =
        isDark ? const Color(0xFF3C3530) : const Color(0xFFD0C8C3);
    final categoryLabel = _primaryCategoryLabel(servicesToDisplay, service);
    final categoryAccentColor =
        _resolveCategoryColor(
          servicesToDisplay,
          categoriesById,
          categoriesByName,
          categoryLabel,
          theme,
        ) ??
        theme.colorScheme.primary;
    final Color borderColor =
        isDark
            ? Color.alphaBlend(
              categoryAccentColor.withValues(alpha: 0.78),
              surfaceColor,
            )
            : categoryAccentColor.withValues(alpha: 0.9);

    String previewStatusLabel(AppointmentStatus value) {
      switch (value) {
        case AppointmentStatus.noShow:
          return 'No Show';
        default:
          return _appointmentStatusLabel(value);
      }
    }

    String previewAnomalyLabel(AppointmentAnomalyType issue) {
      switch (issue) {
        case AppointmentAnomalyType.outdatedStatus:
          return 'In ritardo';
        case AppointmentAnomalyType.noShift:
          return 'Fuori turno';
        case AppointmentAnomalyType.breakOverlap:
          return 'In pausa';
        case AppointmentAnomalyType.absenceOverlap:
          return 'Operatore assente';
      }
    }

    Color onChipColor(Color color) {
      final brightness = ThemeData.estimateBrightnessForColor(color);
      return brightness == Brightness.dark
          ? Colors.white
          : const Color(0xFF151515);
    }

    Widget buildStatusWidget() {
      final label = previewStatusLabel(status);
      if (status == AppointmentStatus.scheduled) {
        return Text(
          label,
          style:
              theme.textTheme.labelLarge?.copyWith(
                color: primaryContentColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ) ??
              TextStyle(
                color: primaryContentColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
        );
      }

      final Color background;
      final Color foreground;
      switch (status) {
        case AppointmentStatus.completed:
          background = const Color(0xFFDFF2E6);
          foreground = const Color(0xFF1E9C63);
          break;
        case AppointmentStatus.cancelled:
          background = const Color(0xFFE6E1DE);
          foreground = const Color(0xFF746E6A);
          break;
        case AppointmentStatus.noShow:
          background = const Color(0xFFF6D8DC);
          foreground = const Color(0xFFE24C5A);
          break;
        case AppointmentStatus.scheduled:
          background = Colors.transparent;
          foreground = primaryContentColor;
          break;
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_appointmentStatusIcon(status), size: 18, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style:
                  theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ) ??
                  TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      );
    }

    Widget buildCategoryChip({
      required String label,
      required Color color,
      required String tooltip,
    }) {
      final background = Color.alphaBlend(
        color.withValues(alpha: isDark ? 0.72 : 0.88),
        surfaceColor,
      );
      final foreground = onChipColor(background);
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 250),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style:
                theme.textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ) ??
                TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      );
    }

    Widget buildInfoBadge({
      required IconData icon,
      required String label,
      required Color background,
      required Color foreground,
      required String tooltip,
    }) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 250),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 4),
              Text(
                label,
                style:
                    theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ) ??
                    TextStyle(
                      color: foreground,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildInfoRow({
      required IconData icon,
      required Color iconColor,
      required Color iconBackground,
      required String title,
      required String subtitle,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style:
                      theme.textTheme.titleMedium?.copyWith(
                        color: primaryContentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.1,
                      ) ??
                      TextStyle(
                        color: primaryContentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(
                        color: secondaryContentColor,
                        fontSize: 14,
                        height: 1.15,
                      ) ??
                      TextStyle(color: secondaryContentColor, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final categoryChips = <Widget>[];
    final seenCategoryLabels = <String>{};
    for (final entry in servicesToDisplay) {
      final label =
          entry.category.trim().isNotEmpty
              ? entry.category.trim()
              : entry.name.trim();
      if (label.isEmpty) {
        continue;
      }
      final normalized = label.toLowerCase();
      if (!seenCategoryLabels.add(normalized)) {
        continue;
      }
      final color =
          _resolveCategoryColor(
            [entry],
            categoriesById,
            categoriesByName,
            label,
            theme,
          ) ??
          theme.colorScheme.primary;
      categoryChips.add(
        buildCategoryChip(
          label: label,
          color: color,
          tooltip: 'Categoria: $label',
        ),
      );
    }

    final sortedAnomalies =
        anomalies.toList()
          ..sort((first, second) => first.index.compareTo(second.index));
    final infoBadges = <Widget>[
      for (final issue in sortedAnomalies)
        buildInfoBadge(
          icon: Icons.warning_amber_rounded,
          label: previewAnomalyLabel(issue),
          background: const Color(0xFFF8D8DD),
          foreground: const Color(0xFFE24C5A),
          tooltip: issue.description,
        ),
      if (hasOutstandingPayments)
        buildInfoBadge(
          icon: Icons.payments_rounded,
          label: 'Prorogato',
          background: const Color(0xFFF9E1B7),
          foreground: const Color(0xFFEF9F12),
          tooltip: 'Cliente con saldi da pagare',
        ),
      if (_appointmentHasActivePackage(appointment))
        buildInfoBadge(
          icon: Icons.inventory_2_rounded,
          label: 'Pacchetti attivi',
          background: const Color(0xFFD7F0DE),
          foreground: const Color(0xFF1E9C63),
          tooltip: 'Pacchetto attivo',
        ),
      if (lastMinuteSlot != null)
        buildInfoBadge(
          icon: Icons.flash_on_rounded,
          label: 'Last-minute',
          background: const Color(0xFFD9E7FF),
          foreground: const Color(0xFF2B6BDA),
          tooltip:
              lastMinuteSlot!.isAvailable
                  ? 'Slot last-minute disponibile'
                  : 'Appuntamento last-minute',
        ),
    ];

    final hasClientPhone = clientPhone != null && clientPhone.isNotEmpty;
    final hasClientNumber = clientNumber != null && clientNumber.isNotEmpty;
    final trimmedRoomName = preview.roomName;
    final hasRoom = trimmedRoomName != null && trimmedRoomName.isNotEmpty;
    final hasNote = noteText != null && noteText.isNotEmpty;

    final detailRows = <Widget>[
      buildInfoRow(
        icon: Icons.person_outline_rounded,
        iconColor: const Color(0xFFC89A22),
        iconBackground: const Color(0xFFF3ECDD),
        title: clientLabel,
        subtitle: 'Cliente',
      ),
      if (hasClientPhone)
        buildInfoRow(
          icon: Icons.call_rounded,
          iconColor: const Color(0xFF29A756),
          iconBackground: const Color(0xFFDDF1E3),
          title: clientPhone,
          subtitle: 'Telefono',
        ),
      if (hasClientNumber)
        buildInfoRow(
          icon: Icons.tag_rounded,
          iconColor: const Color(0xFFED9D18),
          iconBackground: const Color(0xFFF7E4C6),
          title: 'N° $clientNumber',
          subtitle: 'Codice cliente',
        ),
      if (hasRoom)
        buildInfoRow(
          icon: Icons.room_outlined,
          iconColor: const Color(0xFF5A74D9),
          iconBackground: const Color(0xFFE2E8FB),
          title: trimmedRoomName,
          subtitle: 'Stanza',
        ),
    ];

    final scheduleValue =
        '${_timeFormat.format(appointment.start)} - ${_timeFormat.format(appointment.end)}';
    final durationValue = showDuration ? '($contentDurationMinutes min)' : '';
    final bool hasAttentionText =
        attentionText != null &&
        attentionText.isNotEmpty &&
        sortedAnomalies.isEmpty;

    return Container(
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    serviceLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        theme.textTheme.headlineSmall?.copyWith(
                          color: primaryContentColor,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.08,
                        ) ??
                        TextStyle(
                          color: primaryContentColor,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          height: 1.08,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                buildStatusWidget(),
              ],
            ),
            if (categoryChips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: categoryChips),
            ],
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 20,
                  color: secondaryContentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    scheduleValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        theme.textTheme.titleMedium?.copyWith(
                          color: primaryContentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          height: 1.2,
                        ) ??
                        TextStyle(
                          color: primaryContentColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                  ),
                ),
                if (showDuration)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      durationValue,
                      textAlign: TextAlign.right,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryContentColor,
                            fontSize: 14,
                            height: 1.2,
                          ) ??
                          TextStyle(
                            color: secondaryContentColor,
                            fontSize: 14,
                            height: 1.2,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, thickness: 1, color: dividerColor),
            const SizedBox(height: 10),
            for (var index = 0; index < detailRows.length; index++) ...[
              if (index != 0) const SizedBox(height: 10),
              detailRows[index],
            ],
            if (infoBadges.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: infoBadges),
            ],
            if (hasAttentionText) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE7EA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  attentionText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style:
                      theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFE24C5A),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.25,
                      ) ??
                      const TextStyle(
                        color: Color(0xFFE24C5A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                ),
              ),
            ],
            if (hasNote) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF2B2623)
                          : const Color(0xFFF7F4F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
                          size: 16,
                          color: secondaryContentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Note operative',
                          style:
                              theme.textTheme.labelMedium?.copyWith(
                                color: secondaryContentColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ) ??
                              TextStyle(
                                color: secondaryContentColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      noteText,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.textTheme.bodySmall?.copyWith(
                            color: primaryContentColor,
                            fontSize: 14,
                            height: 1.25,
                          ) ??
                          TextStyle(
                            color: primaryContentColor,
                            fontSize: 14,
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppointmentAccentStripePainter extends CustomPainter {
  const _AppointmentAccentStripePainter({
    required this.colors,
    required this.borderRadius,
    required this.stripeWidth,
    required this.bottomFadeExtent,
  });

  final List<Color> colors;
  final BorderRadius borderRadius;
  final double stripeWidth;
  final double bottomFadeExtent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || colors.isEmpty) {
      return;
    }

    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    final segmentHeight = size.height / colors.length;
    final paint = Paint();

    canvas.save();
    canvas.clipRRect(rrect);

    for (var index = 0; index < colors.length; index++) {
      final top = segmentHeight * index;
      final bottom =
          index == colors.length - 1
              ? size.height
              : segmentHeight * (index + 1);
      paint
        ..shader = null
        ..color = colors[index];
      canvas.drawRect(Rect.fromLTRB(0, top, stripeWidth, bottom), paint);
    }

    if (colors.length == 1) {
      final tailThickness = stripeWidth * 1.2;
      final tailTop = max(0.0, size.height - tailThickness - 0.5);
      final tailBottom = size.height;
      final tailPath =
          Path()
            ..moveTo(0, tailTop)
            ..lineTo(stripeWidth * 0.55, tailTop)
            ..cubicTo(
              stripeWidth * 1.05,
              tailTop,
              stripeWidth * 1.45,
              tailTop + tailThickness * 0.2,
              stripeWidth * 1.55,
              tailBottom - tailThickness * 0.25,
            )
            ..cubicTo(
              bottomFadeExtent * 0.42,
              tailBottom - tailThickness * 0.02,
              bottomFadeExtent * 0.8,
              tailBottom - tailThickness * 0.18,
              bottomFadeExtent,
              tailBottom - tailThickness * 0.52,
            )
            ..lineTo(bottomFadeExtent, tailBottom)
            ..lineTo(0, tailBottom)
            ..close();
      final fadeColor = colors.last;
      final fadeRect = Rect.fromLTWH(
        0,
        tailTop,
        bottomFadeExtent,
        tailThickness,
      );
      paint.shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          fadeColor,
          fadeColor.withValues(alpha: fadeColor.a * 0.82),
          fadeColor.withValues(alpha: fadeColor.a * 0.35),
          fadeColor.withValues(alpha: 0),
        ],
        stops: const [0, 0.32, 0.7, 1],
      ).createShader(fadeRect);
      canvas.drawPath(tailPath, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppointmentAccentStripePainter oldDelegate) {
    return !listEquals(oldDelegate.colors, colors) ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.stripeWidth != stripeWidth ||
        oldDelegate.bottomFadeExtent != bottomFadeExtent;
  }
}

class _AppointmentCardState extends State<_AppointmentCard> {
  static final DateFormat _timeFormat = DateFormat('HH:mm', 'it_IT');

  final LayerLink _hoverLayerLink = LayerLink();
  bool _isHovering = false;

  void _updateHovering(bool hovering) {
    if (_isHovering == hovering) {
      return;
    }
    setState(() {
      _isHovering = hovering;
    });
  }

  void _showHoverOverlay() {
    if (!widget.enableHoverOverlay) {
      return;
    }
    final target = context.findRenderObject() as RenderBox?;
    if (target == null || !target.hasSize) {
      return;
    }
    widget.onHoverOverlayShow?.call(
      _AppointmentHoverAnchor(
        layerLink: _hoverLayerLink,
        globalTargetRect: target.localToGlobal(Offset.zero) & target.size,
      ),
    );
  }

  void _hideHoverOverlay() {
    if (!widget.enableHoverOverlay) {
      return;
    }
    widget.onHoverOverlayHide?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final appointment = widget.appointment;
    final client = widget.client;
    final service = widget.service;
    final services = widget.services;
    var height = widget.height;
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
    final showDuration = widget.showDuration;
    final expandToContent = widget.expandToContent;
    final showNotes = widget.showNotes;
    final bool wantsDurationChip = showDuration && highlight;

    final status = appointment.status;
    final timeLabel = _timeFormat.format(appointment.start);
    final hasAnomalies = anomalies.isNotEmpty;
    final isLocked = lockReason != null;
    final servicesToDisplay =
        services.isNotEmpty
            ? services
            : [service].whereType<Service>().toList(growable: false);
    final serviceLabel =
        servicesToDisplay.isNotEmpty
            ? servicesToDisplay.map((service) => service.name).join(' + ')
            : null;
    final int contentDurationMinutes = max(
      1,
      visibleDurationMinutes ?? appointment.duration.inMinutes,
    );
    final bool isVeryShortAppointment = contentDurationMinutes <= 15;
    final bool showServiceInfo =
        expandToContent || contentDurationMinutes >= 60;
    final bool showClientInfo = !hideContent;
    final bool showClientNameInStandardCard =
        !expandToContent && !hideContent && !isVeryShortAppointment;
    final String? trimmedClientName = client?.fullName.trim();
    final String displayClientName =
        trimmedClientName != null && trimmedClientName.isNotEmpty
            ? trimmedClientName
            : 'Cliente';
    final String? trimmedClientNumber = client?.clientNumber?.trim();
    final String? clientNumber =
        trimmedClientNumber != null && trimmedClientNumber.isNotEmpty
            ? trimmedClientNumber
            : null;
    final String? trimmedClientPhone = client?.phone.trim();
    final String? clientPhone =
        trimmedClientPhone != null && trimmedClientPhone.isNotEmpty
            ? trimmedClientPhone
            : null;
    final bool showClientPhone =
        clientPhone != null && (highlight || expandToContent);
    final bool showClientNumber = clientNumber != null && expandToContent;
    final noteText = appointment.notes?.trim();
    final bool hasPreviewNote =
        showNotes && noteText != null && noteText.isNotEmpty;
    final bool isCancelled = status == AppointmentStatus.cancelled;
    final bool isCompleted = status == AppointmentStatus.completed;
    final bool hasActivePackage = _appointmentHasActivePackage(appointment);
    final attentionText = _attentionText(
      isCancelled: isCancelled,
      anomalies: anomalies,
    );
    final double baseHeight =
        expandToContent ? _kBasePreviewHeight : widget.height;
    height = _contentAwareHeight(
      baseHeight: baseHeight,
      expandToContent: expandToContent,
      highlight: highlight,
      showDurationChip: wantsDurationChip,
      showServiceInfo: showServiceInfo,
      showClientInfo: showClientInfo,
      showClientPhone: showClientPhone,
      showClientNumber: showClientNumber,
      hasPreviewNote: hasPreviewNote,
      attentionText: attentionText,
      hasOutstandingPayments: hasOutstandingPayments,
      serviceLabel: serviceLabel,
      clientName: trimmedClientName,
      clientNumber: clientNumber,
      clientPhone: showClientPhone ? clientPhone : null,
      noteText: noteText,
      roomName: roomName,
    );
    if (highlight && !expandToContent) {
      final bool isVeryShort = contentDurationMinutes <= 15;
      height = max(height, isVeryShort ? 210.0 : 190.0);
    }
    final categoryLabel = _primaryCategoryLabel(servicesToDisplay, service);
    final categoryColor = _resolveCategoryColor(
      servicesToDisplay,
      categoriesById,
      categoriesByName,
      categoryLabel,
      theme,
    );
    final categoryColors = _resolveCategoryColors(
      servicesToDisplay,
      categoriesById,
      categoriesByName,
      categoryLabel,
      theme,
    );
    final accentColor = categoryColor ?? const Color(0xFFC7C7C7);
    final warningAccentColor =
        hasAnomalies ? const Color(0xFFE24C5A) : accentColor;
    final borderColor = warningAccentColor;
    final borderWidth = hasAnomalies ? 2.8 : 1.5;
    final gradientBorder =
        hasAnomalies ? null : _segmentedVerticalGradient(categoryColors);
    final baseBackgroundColor = _appointmentCardBackgroundColor(theme, status);
    final categoryTintAlpha = switch (status) {
      AppointmentStatus.scheduled ||
      AppointmentStatus.completed => isDark ? 0.26 : 0.26,
      AppointmentStatus.cancelled => isDark ? 0.16 : 0.1,
      AppointmentStatus.noShow => isDark ? 0.12 : 0.08,
    };
    final categoryBackground = Color.alphaBlend(
      accentColor.withValues(alpha: categoryTintAlpha),
      baseBackgroundColor,
    );
    final backgroundColor =
        hasAnomalies
            ? Color.alphaBlend(
              const Color(0xFFE24C5A).withValues(alpha: isDark ? 0.22 : 0.16),
              categoryBackground,
            )
            : categoryBackground;
    final Color primaryContentColor =
        isDark ? const Color(0xFFF5F1EE) : const Color(0xFF141414);
    final Color secondaryContentColor =
        isDark ? const Color(0xFFD0C6C0) : const Color(0xFF4A4A4A);
    final Color tertiaryContentColor =
        isDark ? const Color(0xFFAA9F98) : const Color(0xFF747474);
    final bool showWarningFilm = hasAnomalies && !expandToContent;
    final bool showCompletedFilm =
        isCompleted && !expandToContent && !showWarningFilm;
    final Color completedFilmColor =
        isDark ? const Color(0xFF84CFA8) : const Color(0xFFCDEEDB);
    final Color completedFilmHighlight =
        isDark ? const Color(0xFFDFF6E8) : const Color(0xFFF8FFFB);
    final Color completedBadgeBackground =
        isDark ? const Color(0xFF54B783) : const Color(0xFF5FC28F);
    final Color completedBadgeBorderColor =
        isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.72);
    const Color completedBadgeForeground = Colors.white;
    final Color warningFilmColor =
        isDark ? const Color(0xFFE5909A) : const Color(0xFFF8CDD2);
    final Color warningFilmHighlight =
        isDark ? const Color(0xFFF7D5D9) : const Color(0xFFFFF7F8);
    final Color warningBadgeBackground =
        isDark ? const Color(0xFFD96172) : const Color(0xFFE16B7C);
    final Color warningBadgeBorderColor =
        isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.72);
    final Color infoPillBackgroundColor =
        isDark ? const Color(0xFF2B2623) : const Color(0xFFF4F4F4);
    final Color infoPillTextColor = primaryContentColor;
    final Color infoPillIconColor = primaryContentColor.withValues(alpha: 0.9);
    const double smallCornerRadius = 2.0;
    const double largeCornerRadius = 18.0;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(smallCornerRadius),
      topRight: const Radius.circular(largeCornerRadius),
      bottomRight: const Radius.circular(smallCornerRadius),
      bottomLeft: const Radius.circular(largeCornerRadius),
    );
    final innerBorderRadius = BorderRadius.only(
      topLeft: Radius.circular(max(0.0, smallCornerRadius - borderWidth)),
      topRight: Radius.circular(max(0.0, largeCornerRadius - borderWidth)),
      bottomRight: Radius.circular(max(0.0, smallCornerRadius - borderWidth)),
      bottomLeft: Radius.circular(max(0.0, largeCornerRadius - borderWidth)),
    );
    final stripeBorderRadius = BorderRadius.only(
      topLeft: innerBorderRadius.topLeft,
      bottomLeft: innerBorderRadius.bottomLeft,
    );
    const double stripeWidth = 6.0;
    const double stripeBottomFadeExtent = 28.0;
    final statusColor = _appointmentStatusColor(theme.colorScheme, status);
    final bool showStatusIcon =
        status != AppointmentStatus.scheduled &&
        !showCompletedFilm &&
        !showWarningFilm;
    final bool showRoomInfo = roomName != null && expandToContent;
    final bool showDurationChip = wantsDurationChip && expandToContent;
    final stripeColors =
        hasAnomalies
            ? <Color>[
              warningAccentColor,
              ...categoryColors.where((color) => color != warningAccentColor),
            ]
            : categoryColors.isNotEmpty
            ? categoryColors
            : <Color>[accentColor];
    final bool useShortStandardIcons =
        isVeryShortAppointment && !expandToContent;
    final double standardIndicatorIconSize = useShortStandardIcons ? 14 : 20;
    final double standardStatusIconSize = useShortStandardIcons ? 13 : 18;
    final sortedAnomalies =
        anomalies.toList()..sort((a, b) => a.index.compareTo(b.index));

    Widget buildIconIndicator({
      required IconData icon,
      required Color color,
      required String tooltip,
      double size = 20,
    }) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 250),
        child: Icon(icon, size: size, color: color),
      );
    }

    Widget buildStatusIcon({double size = 18}) {
      return buildIconIndicator(
        icon: _appointmentStatusIcon(status),
        color: statusColor,
        tooltip: 'Stato: ${_appointmentStatusLabel(status)}',
        size: size,
      );
    }

    Widget buildWarningMarker({required bool compact}) {
      final tooltip =
          _attentionText(isCancelled: false, anomalies: anomalies) ??
          'Avvertenze';
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 250),
        child: Container(
          width: compact ? 20 : 24,
          height: compact ? 20 : 24,
          decoration: BoxDecoration(
            color: const Color(0xFFE24C5A),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFE24C5A,
                ).withValues(alpha: isDark ? 0.22 : 0.18),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.warning_amber_rounded,
              size: compact ? 13 : 15,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    Widget buildCompletedCenterBadge({required bool compact}) {
      return Container(
        width: compact ? 28 : 32,
        height: compact ? 28 : 32,
        decoration: BoxDecoration(
          color: completedBadgeBackground,
          shape: BoxShape.circle,
          border: Border.all(color: completedBadgeBorderColor),
          boxShadow: [
            BoxShadow(
              color: completedBadgeBackground.withValues(
                alpha: isDark ? 0.16 : 0.12,
              ),
              blurRadius: compact ? 8 : 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.check_rounded,
            size: compact ? 16 : 18,
            color: completedBadgeForeground,
          ),
        ),
      );
    }

    Widget buildWarningCenterBadge({required bool compact}) {
      return Container(
        width: compact ? 28 : 32,
        height: compact ? 28 : 32,
        decoration: BoxDecoration(
          color: warningBadgeBackground,
          shape: BoxShape.circle,
          border: Border.all(color: warningBadgeBorderColor),
          boxShadow: [
            BoxShadow(
              color: warningBadgeBackground.withValues(
                alpha: isDark ? 0.18 : 0.14,
              ),
              blurRadius: compact ? 8 : 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.warning_amber_rounded,
            size: compact ? 15 : 17,
            color: Colors.white,
          ),
        ),
      );
    }

    final indicatorWidgets = <Widget>[
      if (hasAnomalies && !showWarningFilm)
        buildIconIndicator(
          icon: AppointmentAnomalyType.noShift.icon,
          color: const Color(0xFFE24C5A),
          tooltip: 'Avvertenze',
          size: standardIndicatorIconSize,
        ),
      if (hasOutstandingPayments)
        buildIconIndicator(
          icon: Icons.payments_rounded,
          color: const Color(0xFFC77F00),
          tooltip: 'Saldi da pagare',
          size: standardIndicatorIconSize,
        ),
      if (hasActivePackage)
        buildIconIndicator(
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF1E9C63),
          tooltip: 'Pacchetto attivo',
          size: standardIndicatorIconSize,
        ),
    ];

    final cardBody = DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: gradientBorder == null ? borderRadius : innerBorderRadius,
        border:
            gradientBorder == null
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
        boxShadow:
            hasAnomalies
                ? [
                  BoxShadow(
                    color: borderColor.withValues(alpha: isDark ? 0.28 : 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 5),
                  ),
                ]
                : null,
      ),
      child: ClipRRect(
        borderRadius: gradientBorder == null ? borderRadius : innerBorderRadius,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _AppointmentAccentStripePainter(
                      colors: stripeColors,
                      borderRadius: stripeBorderRadius,
                      stripeWidth: stripeWidth,
                      bottomFadeExtent: stripeBottomFadeExtent,
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: stripeWidth),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        10,
                        expandToContent
                            ? 10
                            : useShortStandardIcons
                            ? 6
                            : 8,
                        10,
                        expandToContent
                            ? 10
                            : useShortStandardIcons
                            ? 6
                            : 8,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availableHeight =
                              constraints.hasBoundedHeight
                                  ? constraints.maxHeight
                                  : double.infinity;
                          final availableWidth =
                              constraints.hasBoundedWidth
                                  ? constraints.maxWidth
                                  : double.infinity;
                          if (constraints.hasBoundedHeight &&
                              availableHeight <= 0) {
                            return const SizedBox.shrink();
                          }

                          final bool isUltraCompactStandardCard =
                              !expandToContent &&
                              (availableWidth < 76 || availableHeight < 58);
                          final bool showInlineWarningMarker =
                              hasAnomalies &&
                              !showWarningFilm &&
                              (expandToContent || availableWidth >= 74);
                          final bool showInlineStatusIcon =
                              showStatusIcon &&
                              (expandToContent ||
                                  availableWidth >=
                                      (showInlineWarningMarker ? 98 : 76));
                          final bool useDenseStandardLayout =
                              !expandToContent &&
                              (useShortStandardIcons ||
                                  availableHeight < 62 ||
                                  availableWidth < 96);
                          final bool hasStandardServiceLine =
                              serviceLabel != null &&
                              serviceLabel.trim().isNotEmpty;
                          final bool showStandardServiceLine =
                              hasStandardServiceLine &&
                              !isUltraCompactStandardCard &&
                              availableWidth >=
                                  (useDenseStandardLayout ? 68 : 80) &&
                              availableHeight >=
                                  (useDenseStandardLayout ? 30 : 44);
                          final bool showStandardClientLine =
                              !isUltraCompactStandardCard &&
                              (showClientNameInStandardCard ||
                                  availableHeight >=
                                      (useDenseStandardLayout ? 38 : 56)) &&
                              (!hasStandardServiceLine ||
                                  showStandardServiceLine);
                          final bool showStandardIndicators =
                              indicatorWidgets.isNotEmpty &&
                              availableHeight >=
                                  ((showStandardClientLine ||
                                          showStandardServiceLine)
                                      ? 52
                                      : 34);

                          if (hideContent) {
                            final bool showCompactFallback =
                                !showStatusIcon && indicatorWidgets.isEmpty;
                            return Stack(
                              children: [
                                if (showStatusIcon)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: buildStatusIcon(size: 18),
                                  ),
                                if (indicatorWidgets.isNotEmpty)
                                  Positioned(
                                    left: 0,
                                    bottom: 0,
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: indicatorWidgets,
                                    ),
                                  ),
                                if (showCompactFallback)
                                  Align(
                                    alignment: Alignment.center,
                                    child: buildIconIndicator(
                                      icon: Icons.schedule_rounded,
                                      color: tertiaryContentColor,
                                      tooltip: 'Appuntamento programmato',
                                      size: 22,
                                    ),
                                  ),
                              ],
                            );
                          }

                          final double timeFontSize =
                              expandToContent
                                  ? 22
                                  : highlight
                                  ? 17
                                  : useDenseStandardLayout
                                  ? 13
                                  : 15;
                          final double clientFontSize =
                              expandToContent
                                  ? 17
                                  : useDenseStandardLayout
                                  ? 11
                                  : 13;
                          final double serviceFontSize =
                              expandToContent
                                  ? 15
                                  : useDenseStandardLayout
                                  ? 9.5
                                  : 11.5;
                          final timeStyle =
                              theme.textTheme.titleSmall?.copyWith(
                                color: primaryContentColor,
                                fontSize: timeFontSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ) ??
                              TextStyle(
                                color: primaryContentColor,
                                fontSize: timeFontSize,
                                fontWeight: FontWeight.w800,
                              );
                          final clientStyle =
                              theme.textTheme.bodyMedium?.copyWith(
                                color: primaryContentColor,
                                fontSize: clientFontSize,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ) ??
                              TextStyle(
                                color: primaryContentColor,
                                fontSize: clientFontSize,
                                fontWeight: FontWeight.w600,
                              );
                          final detailStyle =
                              theme.textTheme.bodySmall?.copyWith(
                                color: secondaryContentColor,
                                fontSize: serviceFontSize,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ) ??
                              TextStyle(
                                color: secondaryContentColor,
                                fontSize: serviceFontSize,
                                fontWeight: FontWeight.w500,
                              );
                          final metaStyle = detailStyle.copyWith(
                            color: tertiaryContentColor,
                            fontWeight: FontWeight.w600,
                          );

                          final trailingTopWidgets = <Widget>[
                            if (showInlineWarningMarker)
                              buildWarningMarker(
                                compact: useShortStandardIcons,
                              ),
                            if (showInlineStatusIcon)
                              buildStatusIcon(
                                size:
                                    expandToContent
                                        ? 22
                                        : standardStatusIconSize,
                              ),
                          ];
                          final topRow =
                              expandToContent
                                  ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          timeLabel,
                                          style: timeStyle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (trailingTopWidgets.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (
                                              var index = 0;
                                              index < trailingTopWidgets.length;
                                              index++
                                            ) ...[
                                              if (index > 0)
                                                const SizedBox(width: 6),
                                              trailingTopWidgets[index],
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  )
                                  : SizedBox(
                                    height:
                                        useDenseStandardLayout
                                            ? 18
                                            : useShortStandardIcons
                                            ? 22
                                            : 24,
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right:
                                                  trailingTopWidgets.isNotEmpty
                                                      ? (showInlineWarningMarker
                                                              ? (useShortStandardIcons
                                                                  ? 24.0
                                                                  : 28.0)
                                                              : 0.0) +
                                                          (showInlineStatusIcon
                                                              ? standardStatusIconSize +
                                                                  (showInlineWarningMarker
                                                                      ? 10.0
                                                                      : 4.0)
                                                              : 0.0)
                                                      : 0.0,
                                            ),
                                            child: Align(
                                              alignment: Alignment.topLeft,
                                              child: Text(
                                                timeLabel,
                                                style: timeStyle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (trailingTopWidgets.isNotEmpty)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                for (
                                                  var index = 0;
                                                  index <
                                                      trailingTopWidgets.length;
                                                  index++
                                                ) ...[
                                                  if (index > 0)
                                                    const SizedBox(width: 6),
                                                  trailingTopWidgets[index],
                                                ],
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );

                          Widget buildInfoPill({
                            required IconData icon,
                            required String label,
                            required String tooltip,
                          }) {
                            return Tooltip(
                              message: tooltip,
                              waitDuration: const Duration(milliseconds: 250),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: infoPillBackgroundColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      icon,
                                      size: expandToContent ? 18 : 14,
                                      color: infoPillIconColor,
                                    ),
                                    if (label.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        label,
                                        style:
                                            theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: infoPillTextColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize:
                                                      expandToContent
                                                          ? 13.5
                                                          : 11,
                                                ) ??
                                            TextStyle(
                                              color: infoPillTextColor,
                                              fontSize:
                                                  expandToContent ? 13.5 : 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }

                          void addPreviewLine(
                            List<Widget> children,
                            String? value,
                            TextStyle style, {
                            double gap = 4,
                            int? maxLines = 2,
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
                                maxLines: maxLines,
                                overflow:
                                    maxLines == null
                                        ? null
                                        : TextOverflow.ellipsis,
                              ),
                            );
                          }

                          if (!expandToContent) {
                            final standardChildren = <Widget>[topRow];
                            if (showStandardServiceLine) {
                              standardChildren.add(
                                SizedBox(
                                  height: useDenseStandardLayout ? 1 : 4,
                                ),
                              );
                              standardChildren.add(
                                Text(
                                  serviceLabel,
                                  style: detailStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                            if (showStandardClientLine) {
                              standardChildren.add(
                                SizedBox(
                                  height: useDenseStandardLayout ? 2 : 6,
                                ),
                              );
                              standardChildren.add(
                                Text(
                                  displayClientName,
                                  style: clientStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                            if (showStandardIndicators) {
                              standardChildren.add(const Spacer());
                              standardChildren.add(
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: indicatorWidgets,
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: standardChildren,
                            );
                          }

                          final previewChildren = <Widget>[topRow];
                          addPreviewLine(
                            previewChildren,
                            trimmedClientName,
                            clientStyle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                            gap: 6,
                            maxLines: null,
                          );
                          if (serviceLabel != null &&
                              serviceLabel.trim().isNotEmpty) {
                            addPreviewLine(
                              previewChildren,
                              serviceLabel,
                              detailStyle.copyWith(fontSize: 15, height: 1.25),
                              gap: 4,
                              maxLines: null,
                            );
                          }
                          if (indicatorWidgets.isNotEmpty) {
                            previewChildren.add(const SizedBox(height: 8));
                            previewChildren.add(
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: indicatorWidgets,
                              ),
                            );
                          }
                          if (lastMinuteSlot != null) {
                            addPreviewLine(
                              previewChildren,
                              'Slot last-minute',
                              metaStyle.copyWith(fontSize: 14.5, height: 1.2),
                              gap: 8,
                              maxLines: null,
                            );
                          }
                          if (showClientNumber) {
                            addPreviewLine(
                              previewChildren,
                              'N° $clientNumber',
                              metaStyle.copyWith(fontSize: 14.5, height: 1.2),
                              gap: 8,
                              maxLines: null,
                            );
                          }
                          if (showClientPhone) {
                            addPreviewLine(
                              previewChildren,
                              clientPhone,
                              metaStyle.copyWith(fontSize: 14.5, height: 1.2),
                              gap: 4,
                              maxLines: null,
                            );
                          }
                          if (hasPreviewNote) {
                            addPreviewLine(
                              previewChildren,
                              'Note: $noteText',
                              detailStyle.copyWith(fontSize: 15, height: 1.25),
                              gap: 8,
                              maxLines: null,
                            );
                          }
                          if (attentionText != null) {
                            addPreviewLine(
                              previewChildren,
                              'Avvertenze: $attentionText',
                              detailStyle.copyWith(
                                color: const Color(0xFFE24C5A),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                height: 1.25,
                              ),
                              gap: 8,
                              maxLines: null,
                            );
                          }
                          if (isLocked) {
                            addPreviewLine(
                              previewChildren,
                              'Bloccato: ${lockReason.trim()}',
                              metaStyle.copyWith(fontSize: 14.5, height: 1.2),
                              gap: 8,
                              maxLines: null,
                            );
                          }

                          final bottomWidgets = <Widget>[];
                          if (showRoomInfo) {
                            bottomWidgets.add(
                              buildInfoPill(
                                icon: Icons.room_outlined,
                                label: roomName,
                                tooltip: 'Stanza: $roomName',
                              ),
                            );
                          }
                          if (showDurationChip) {
                            bottomWidgets.add(
                              buildInfoPill(
                                icon: Icons.access_time_rounded,
                                label: '$contentDurationMinutes min',
                                tooltip:
                                    'Durata appuntamento: $contentDurationMinutes minuti',
                              ),
                            );
                          }
                          if (bottomWidgets.isNotEmpty) {
                            previewChildren.add(const SizedBox(height: 10));
                            previewChildren.add(
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: bottomWidgets,
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: previewChildren,
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: borderWidth),
                ],
              ),
              if (showWarningFilm)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            warningFilmHighlight.withValues(
                              alpha: isDark ? 0.05 : 0.10,
                            ),
                            warningFilmColor.withValues(
                              alpha: isDark ? 0.10 : 0.18,
                            ),
                            warningFilmColor.withValues(
                              alpha: isDark ? 0.14 : 0.22,
                            ),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              if (showWarningFilm)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: useShortStandardIcons ? 10 : 14,
                  child: IgnorePointer(
                    child: Center(
                      child: buildWarningCenterBadge(
                        compact: useShortStandardIcons || height < 74,
                      ),
                    ),
                  ),
                ),
              if (showWarningFilm)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: warningFilmColor.withValues(
                            alpha: isDark ? 0.18 : 0.22,
                          ),
                          width: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              if (showCompletedFilm)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            completedFilmHighlight.withValues(
                              alpha: isDark ? 0.04 : 0.10,
                            ),
                            completedFilmColor.withValues(
                              alpha: isDark ? 0.10 : 0.18,
                            ),
                            completedFilmColor.withValues(
                              alpha: isDark ? 0.14 : 0.22,
                            ),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              if (showCompletedFilm)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: useShortStandardIcons ? 10 : 14,
                  child: IgnorePointer(
                    child: Center(
                      child: buildCompletedCenterBadge(
                        compact: useShortStandardIcons || height < 74,
                      ),
                    ),
                  ),
                ),
              if (showCompletedFilm)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: completedFilmColor.withValues(
                            alpha: isDark ? 0.18 : 0.22,
                          ),
                          width: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final card =
        gradientBorder == null
            ? cardBody
            : DecoratedBox(
              decoration: BoxDecoration(
                gradient: gradientBorder,
                borderRadius: borderRadius,
              ),
              child: Padding(
                padding: EdgeInsets.all(borderWidth),
                child: cardBody,
              ),
            );

    final bool enableScale = onTap != null;
    Widget interactiveCard = Listener(
      onPointerDown: (_) => _hideHoverOverlay(),
      child: MouseRegion(
        cursor: enableScale ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) {
          if (enableScale) {
            _updateHovering(true);
          }
          _showHoverOverlay();
        },
        onExit: (_) {
          if (enableScale) {
            _updateHovering(false);
          }
          _hideHoverOverlay();
        },
        child: AnimatedScale(
          scale: enableScale && _isHovering ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTapDown: (_) => _hideHoverOverlay(),
              onTap:
                  onTap != null
                      ? () {
                        _hideHoverOverlay();
                        onTap();
                      }
                      : null,
              borderRadius: borderRadius,
              child: card,
            ),
          ),
        ),
      ),
    );

    return CompositedTransformTarget(
      link: _hoverLayerLink,
      child: interactiveCard,
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({
    required this.child,
    this.minWidth = 220,
    this.maxWidth = 380,
  });

  final Widget child;
  final double minWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        child: child,
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
    this.enableHoverOverlay = false,
    this.showDuration = true,
    this.expandToContent = false,
    this.showNotes = false,
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
  final bool enableHoverOverlay;
  final bool showDuration;
  final bool expandToContent;
  final bool showNotes;

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
    final baseHeight = expandToContent ? _kBasePreviewHeight : height;
    if (expandToContent) {
      return _AppointmentLegacyPreviewCard(
        appointment: previewed,
        client: client,
        service: service,
        services: services,
        roomName: roomName,
        height: baseHeight,
        visibleDurationMinutes: visibleMinutes,
        anomalies: anomalies,
        lastMinuteSlot: lastMinuteSlot,
        categoriesById: categoriesById,
        categoriesByName: categoriesByName,
        hasOutstandingPayments: hasOutstandingPayments,
        showDuration: showDuration,
        showNotes: showNotes,
      );
    }
    return _AppointmentCard(
      appointment: previewed,
      client: client,
      service: service,
      services: services,
      staff: staff,
      roomName: roomName,
      height: baseHeight,
      visibleDurationMinutes: visibleMinutes,
      anomalies: anomalies,
      lockReason: null,
      highlight: true,
      lastMinuteSlot: lastMinuteSlot,
      categoriesById: categoriesById,
      categoriesByName: categoriesByName,
      hasOutstandingPayments: hasOutstandingPayments,
      enableHoverOverlay: enableHoverOverlay,
      showDuration: showDuration,
      expandToContent: expandToContent,
      showNotes: showNotes,
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
