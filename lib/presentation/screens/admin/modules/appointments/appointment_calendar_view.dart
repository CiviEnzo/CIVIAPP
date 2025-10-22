import 'dart:math';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/availability/appointment_conflicts.dart';
import 'package:civiapp/domain/availability/equipment_availability.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/appointment_day_checklist.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/last_minute_slot.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/service_category.dart';
import 'package:civiapp/domain/entities/shift.dart';
import 'package:civiapp/domain/entities/staff_absence.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/staff_role.dart';
import 'package:civiapp/presentation/screens/admin/modules/appointments/appointment_anomaly.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

const double _kStaffColumnWidth = 220.0;
const double _kStaffHeaderHeight = 48.0;

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
    this.onTapLastMinuteSlot,
    required this.lastMinuteSlots,
    this.onAddChecklistItem,
    this.onToggleChecklistItem,
    this.onRenameChecklistItem,
    this.onDeleteChecklistItem,
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

  @override
  State<AppointmentCalendarView> createState() =>
      _AppointmentCalendarViewState();
}

class _AppointmentCalendarViewState extends State<AppointmentCalendarView> {
  static const _slotExtent = 52.0;
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
          onAddChecklistItem: widget.onAddChecklistItem,
          onToggleChecklistItem: widget.onToggleChecklistItem,
          onRenameChecklistItem: widget.onRenameChecklistItem,
          onDeleteChecklistItem: widget.onDeleteChecklistItem,
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
          onAddChecklistItem: widget.onAddChecklistItem,
          onToggleChecklistItem: widget.onToggleChecklistItem,
          onRenameChecklistItem: widget.onRenameChecklistItem,
          onDeleteChecklistItem: widget.onDeleteChecklistItem,
          autoScrollTargetDate: _initialScrollDate,
          autoScrollPending: !_didAutoScrollToInitialDay,
          layout: widget.weekLayout,
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
    this.onAddChecklistItem,
    this.onToggleChecklistItem,
    this.onRenameChecklistItem,
    this.onDeleteChecklistItem,
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

    final dateLabel = DateFormat('EEEE dd MMMM', 'it_IT').format(dayStart);
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
                                Padding(
                                  padding: EdgeInsets.only(
                                    right:
                                        staffIndex == staff.length - 1 ? 0 : 16,
                                  ),
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
                                      borderRadius: BorderRadius.circular(14),
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
                                            staff[staffIndex].fullName,
                                          ),
                                          style: theme.textTheme.titleSmall,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
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
                                                slotExtent: _slotExtent,
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
    this.onAddChecklistItem,
    this.onToggleChecklistItem,
    this.onRenameChecklistItem,
    this.onDeleteChecklistItem,
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
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: foreground ?? theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground ?? theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
    if (tooltip != null && tooltip.isNotEmpty) {
      return Tooltip(
        message: tooltip,
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
    const double compactSlotExtent = 40.0;
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
      final gridHeight = slotCount * compactSlotExtent;
      return _WeekCompactView(
        dayData: dayData,
        staff: staff,
        roles: roles,
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
        gridHeight: gridHeight,
        minMinute: minMinute!,
        maxMinute: maxMinute!,
        verticalController: verticalController,
        onAddChecklistItem: onAddChecklistItem,
        onToggleChecklistItem: onToggleChecklistItem,
        onRenameChecklistItem: onRenameChecklistItem,
        onDeleteChecklistItem: onDeleteChecklistItem,
      );
    }

    final gridHeight = slotCount * detailedSlotExtent;
    final dayLabelFormat = DateFormat('EEE dd MMM', 'it_IT');
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
                                        vertical: 10,
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
                                                    Flexible(
                                                      fit: FlexFit.loose,
                                                      child: Text(
                                                        dayLabelFormat.format(
                                                          data.date,
                                                        ),
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
                                                        dateLabel:
                                                            dayLabelFormat
                                                                .format(
                                                                  data.date,
                                                                ),
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
                                                const SizedBox(height: 6),
                                                if (summaryChips
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  ScrollConfiguration(
                                                    behavior:
                                                        const _CompactMacScrollBehavior(),
                                                    child: SingleChildScrollView(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
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
                                                ],
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
                                Padding(
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: dayHorizontalPadding,
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
                                                Container(
                                                  width: staffColumnWidth,
                                                  margin: EdgeInsets.only(
                                                    right:
                                                        staffIndex ==
                                                                staff.length - 1
                                                            ? 0
                                                            : staffGap,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10,
                                                      ),
                                                  constraints: BoxConstraints(
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
                                                              alpha: 0.78,
                                                            ),
                                                        theme
                                                            .colorScheme
                                                            .surface,
                                                      ],
                                                      begin:
                                                          Alignment.topCenter,
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
                                                        blurRadius: 18,
                                                        offset: const Offset(
                                                          0,
                                                          10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    _firstNameOnly(
                                                      staff[staffIndex]
                                                          .fullName,
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
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
                                                  slotExtent: _slotExtent,
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
    required this.gridHeight,
    required this.minMinute,
    required this.maxMinute,
    required this.verticalController,
    this.onAddChecklistItem,
    this.onToggleChecklistItem,
    this.onRenameChecklistItem,
    this.onDeleteChecklistItem,
  });

  final List<_WeekDayData> dayData;
  final List<StaffMember> staff;
  final List<StaffRole> roles;
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
  final double gridHeight;
  final int minMinute;
  final int maxMinute;
  final ScrollController verticalController;
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
  static const double _kMaxDayWidth = 320;
  static const double _kMinStaffColumnWidth = 44;
  static const double _kScrollVerticalPadding = 20;
  static const double _kMinSlotExtent = 14;

  @override
  Widget build(BuildContext context) {
    if (dayData.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dayLabelFormat = DateFormat('EEE dd MMM', 'it_IT');
    final timeFormat = DateFormat('HH:mm');
    final rolesById = {for (final role in roles) role.id: role};
    final staffById = {for (final member in staff) member.id: member};
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
              dayLabelFormat,
              dayHeaderColor,
              staffById,
              contentWidth,
              dayWidth,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, expandedConstraints) {
                  final bool hasBoundedHeight =
                      expandedConstraints.maxHeight.isFinite;
                  final double availableGridHeight =
                      hasBoundedHeight
                          ? max(
                            0.0,
                            expandedConstraints.maxHeight -
                                (_kStaffGridTopInset +
                                    _kDayBodyBottomPadding +
                                    _kScrollVerticalPadding),
                          )
                          : this.gridHeight;
                  final double effectiveSlotExtent =
                      hasBoundedHeight
                          ? _computeEffectiveSlotExtent(
                            slotCount: slotCount,
                            baseSlotExtent: slotExtent,
                            availableGridHeight: availableGridHeight,
                          )
                          : slotExtent;
                  final double resolvedGridHeight =
                      hasBoundedHeight
                          ? slotCount * effectiveSlotExtent
                          : this.gridHeight;
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
                                effectiveSlotExtent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: contentWidth,
                              child: _buildDayColumns(
                                theme,
                                now,
                                dayBodyColor,
                                dayWidth,
                                dayInnerWidth,
                                resolvedGridHeight,
                                effectiveSlotExtent,
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
    return min(width, _kMaxDayWidth);
  }

  static double _computeEffectiveSlotExtent({
    required int slotCount,
    required double baseSlotExtent,
    required double availableGridHeight,
  }) {
    if (slotCount <= 0) {
      return baseSlotExtent;
    }
    if (!availableGridHeight.isFinite || availableGridHeight <= 0) {
      return baseSlotExtent;
    }
    final double fittedExtent = availableGridHeight / slotCount;
    final double clamped = fittedExtent.clamp(_kMinSlotExtent, baseSlotExtent);
    return clamped;
  }

  Widget _buildHeaderRow(
    BuildContext context,
    ThemeData theme,
    DateTime now,
    DateFormat dayLabelFormat,
    Color dayHeaderColor,
    Map<String, StaffMember> staffById,
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
                      dayLabelFormat,
                      dayData[dayIndex],
                      dayHeaderColor,
                      staffById,
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
    DateFormat dayLabelFormat,
    _WeekDayData data,
    Color background,
    Map<String, StaffMember> staffById,
  ) {
    final normalizedDate = DateUtils.dateOnly(data.date);
    final isToday = DateUtils.isSameDay(normalizedDate, now);
    final totalAppointments = data.appointmentsByStaff.values.fold<int>(
      0,
      (running, list) => running + list.length,
    );
    final totalDurationMinutes = data.appointmentsByStaff.values
        .expand((list) => list)
        .fold<int>(
          0,
          (running, appointment) =>
              running + appointment.end.difference(appointment.start).inMinutes,
        );
    final scheduledStaffIds = data.shiftsByStaff.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList(growable: false);
    final absenceStaffIds = data.absencesByStaff.entries
        .where((entry) => entry.value.isNotEmpty)
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

    final summaryChips = <Widget>[
      _WeekSchedule._summaryChip(
        theme: theme,
        icon: Icons.event_available_rounded,
        label: '$totalAppointments appuntamenti',
        background: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6),
        foreground: theme.colorScheme.onTertiaryContainer,
      ),
    ];

    if (totalDurationMinutes >= slotMinutes) {
      final totalHours = totalDurationMinutes / 60;
      final durationLabel =
          totalHours >= 5
              ? '${totalHours.round()}h prenotate'
              : '${totalHours.toStringAsFixed(1)}h prenotate';
      summaryChips.add(
        _WeekSchedule._summaryChip(
          theme: theme,
          icon: Icons.schedule_rounded,
          label: durationLabel,
        ),
      );
    }

    if (scheduledNames.isNotEmpty) {
      summaryChips.add(
        _WeekSchedule._summaryChip(
          theme: theme,
          icon: Icons.badge_rounded,
          label: '${scheduledNames.length} in servizio',
          tooltip: scheduledNames.join('\n'),
        ),
      );
    }

    if (absenceNames.isNotEmpty) {
      summaryChips.add(
        _WeekSchedule._summaryChip(
          theme: theme,
          icon: Icons.event_busy_rounded,
          label: '${absenceNames.length} assenze',
          background: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
          foreground: theme.colorScheme.onErrorContainer,
          tooltip: absenceNames.join('\n'),
        ),
      );
    }

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
                child: Text(
                  dayLabelFormat.format(data.date),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (showChecklistLauncher) ...[
                const SizedBox(width: 8),
                _ChecklistDialogLauncher(
                  day: data.date,
                  dateLabel: dayLabelFormat.format(data.date),
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
          if (summaryChips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: summaryChips),
          ],
        ],
      ),
    );
  }

  Widget _buildDayColumns(
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
              SizedBox(
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
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    displayInitials,
                                    style: theme.textTheme.titleSmall?.copyWith(
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
                    slotExtent: slotExtent,
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
  static final DateFormat _dayHeaderFormat = DateFormat('EEE dd MMM', 'it_IT');
  static final DateFormat _dayLabelFormat = DateFormat('EEEE dd MMMM', 'it_IT');
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
        for (var index = 0; index < dayData.length; index++) ...[
          SizedBox(
            width: dayWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _dayHeaderFormat.format(dayData[index].date),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          if (index != dayData.length - 1) const SizedBox(width: _kDayGap),
        ],
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

  static final DateFormat _dayLabelFormat =
      _WeekOperatorBoardView._dayLabelFormat;
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
                      _dayLabelFormat.format(day.date),
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

    return Material(
      color:
          isPlaceholder
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
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
    required this.slotExtent,
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
  final double slotExtent;
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
    final slotDuration = widget.slotMinutes.toDouble();
    if (totalMinutes > slotDuration) {
      minuteOffset = minuteOffset.clamp(0.0, totalMinutes - slotDuration);
    }
    final snappedMinutes =
        (minuteOffset / widget.slotMinutes).round() * widget.slotMinutes;
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
    final slotDuration = widget.slotMinutes.toDouble();
    if (totalMinutes > slotDuration) {
      minuteOffset = minuteOffset.clamp(0.0, totalMinutes - slotDuration);
    }
    final snappedMinutes =
        (minuteOffset / widget.slotMinutes).round() * widget.slotMinutes;
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
    final newEnd = newStart.add(Duration(minutes: widget.slotMinutes));
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
            segment.start.difference(widget.timelineStart).inMinutes /
            widget.slotMinutes *
            widget.slotExtent;
        final height = max(
          widget.slotExtent,
          segment.end.difference(segment.start).inMinutes /
              widget.slotMinutes *
              widget.slotExtent,
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
            segment.start.difference(widget.timelineStart).inMinutes /
            widget.slotMinutes *
            widget.slotExtent;
        final height = max(
          widget.slotExtent,
          segment.end.difference(segment.start).inMinutes /
              widget.slotMinutes *
              widget.slotExtent,
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
                statusColor: widget.statusColor,
                height: height,
                anomalies: anomalies,
                lockReason: null,
                highlight: true,
                categoriesById: widget.categoriesById,
                categoriesByName: widget.categoriesByName,
                hideContent: widget.compact,
              ),
            ),
          ),
        );
      }
    }

    final hoverStart = _hoverStart;
    Widget? hoverOverlay;
    if (hoverStart != null) {
      final hoverEnd = hoverStart.add(Duration(minutes: widget.slotMinutes));
      final segment = _segmentWithinTimeline(
        hoverStart,
        hoverEnd,
        widget.timelineStart,
        widget.timelineEnd,
      );
      if (segment != null) {
        final top =
            segment.start.difference(widget.timelineStart).inMinutes /
            widget.slotMinutes *
            widget.slotExtent;
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
        final slotLabel =
            widget.compact
                ? _timeLabel.format(hoverStart)
                : '${_timeLabel.format(hoverStart)} - ${_timeLabel.format(hoverEnd)}';
        hoverOverlay = Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: widget.slotExtent,
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
            final slotMinutes = widget.slotMinutes;
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
                      children: List.generate(
                        totalSlots,
                        (index) => Container(
                          height: widget.slotExtent,
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color:
                                    index.isOdd
                                        ? theme.dividerColor.withValues(
                                          alpha: 0.05,
                                        )
                                        : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                      ),
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
                                              'Slot last-minute (prenotabile)',
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
                      final height = max(
                        widget.slotExtent * 0.75,
                        segment.end.difference(segment.start).inMinutes /
                            widget.slotMinutes *
                            widget.slotExtent,
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
                      final card = _AppointmentCard(
                        appointment: appointment,
                        client: client,
                        service: service,
                        services: services,
                        staff: widget.staffMember,
                        roomName: roomName,
                        statusColor: widget.statusColor,
                        onTap: () => widget.onEdit(appointment),
                        height: height,
                        anomalies: issues,
                        lockReason: lockReason,
                        lastMinuteSlot: matchingSlot,
                        categoriesById: widget.categoriesById,
                        categoriesByName: widget.categoriesByName,
                        hideContent: widget.compact,
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
                              statusColor: widget.statusColor,
                              height: height,
                              anomalies: issues,
                              previewStart: _dragPreviewStart,
                              previewDuration: _dragPreviewDuration,
                              slotMinutes: widget.slotMinutes,
                              lastMinuteSlot: matchingSlot,
                              categoriesById: widget.categoriesById,
                              categoriesByName: widget.categoriesByName,
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
                              statusColor: widget.statusColor,
                              height: height,
                              anomalies: issues,
                              lockReason: lockReason,
                              lastMinuteSlot: matchingSlot,
                              categoriesById: widget.categoriesById,
                              categoriesByName: widget.categoriesByName,
                              hideContent: widget.compact,
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
            final slotMinutes = widget.slotMinutes;
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

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.client,
    required this.service,
    this.services = const <Service>[],
    required this.staff,
    required this.statusColor,
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
  });

  final Appointment appointment;
  final Client? client;
  final Service? service;
  final List<Service> services;
  final StaffMember staff;
  final Color Function(AppointmentStatus status) statusColor;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = appointment.status;
    final startTimeLabel = DateFormat('HH:mm').format(appointment.start);
    final endTimeLabel = DateFormat('HH:mm').format(appointment.end);
    final timeLabel = '$startTimeLabel - $endTimeLabel';
    final statusColorValue = statusColor(status);
    final hasAnomalies = anomalies.isNotEmpty;
    final isLocked = lockReason != null;
    final servicesToDisplay =
        services.isNotEmpty ? services : [if (service != null) service!];
    final serviceLabel =
        servicesToDisplay.isNotEmpty
            ? servicesToDisplay.map((service) => service.name).join(' + ')
            : null;
    final isLastMinute = lastMinuteSlot != null;
    final categoryLabel = _primaryCategoryLabel(servicesToDisplay, service);
    final categoryColor = _resolveCategoryColor(
      servicesToDisplay,
      categoriesById,
      categoriesByName,
      categoryLabel,
      theme,
    );
    final baseColor = categoryColor ?? theme.colorScheme.primary;
    Color gradientStart = baseColor;
    Color gradientEnd = Colors.white.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.2 : 0.95,
    );
    final needsAttention = hasAnomalies;
    if (needsAttention) {
      final double startAlpha =
          theme.brightness == Brightness.dark ? 0.45 : 0.25;
      final double endAlpha = theme.brightness == Brightness.dark ? 0.3 : 0.12;
      gradientStart = Color.alphaBlend(
        theme.colorScheme.error.withValues(alpha: startAlpha),
        gradientStart,
      );
      gradientEnd = Color.alphaBlend(
        theme.colorScheme.error.withValues(alpha: endAlpha),
        gradientEnd,
      );
    }

    final baseBorder = Color.alphaBlend(
      baseColor.withValues(alpha: 0.35),
      gradientEnd,
    );
    final borderColor =
        hasAnomalies
            ? theme.colorScheme.error.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.85 : 0.75,
            )
            : isLocked
            ? theme.colorScheme.outline.withValues(alpha: 0.8)
            : isLastMinute
            ? theme.colorScheme.primary.withValues(alpha: 0.45)
            : baseBorder;
    final borderWidth =
        hasAnomalies
            ? 2.0
            : isLocked
            ? 1.5
            : 1.0;
    final anomaliesTooltip =
        hasAnomalies
            ? (anomalies.toList()..sort((a, b) => a.index.compareTo(b.index)))
                .map((issue) => issue.description)
                .join('\n')
            : null;
    final double verticalPadding;
    if (height < 56) {
      verticalPadding = 4;
    } else if (height < 88) {
      verticalPadding = 8;
    } else {
      verticalPadding = 12;
    }
    final padding = EdgeInsets.symmetric(
      horizontal: 12,
      vertical: verticalPadding,
    );
    final card = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (highlight)
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          if (availableHeight <= 0) {
            return const SizedBox.shrink();
          }

          if (hideContent) {
            return const SizedBox.shrink();
          }

          if (availableHeight < 36) {
            final compactLabel =
                '$timeLabel · ${client?.fullName ?? 'Cliente'}';
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    compactLabel,
                    style: theme.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.circle, size: 8, color: statusColorValue),
              ],
            );
          }

          if (availableHeight < 72) {
            final serviceLabelShouldShow =
                serviceLabel != null && availableHeight >= 64;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        timeLabel,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.circle, size: 10, color: statusColorValue),
                  ],
                ),
                SizedBox(height: availableHeight < 52 ? 2 : 4),
                Text(
                  client?.fullName ?? 'Cliente',
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (serviceLabelShouldShow) ...[
                  SizedBox(height: availableHeight < 68 ? 2 : 4),
                  Text(
                    serviceLabel,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            );
          }

          final showService =
              serviceLabel != null &&
              serviceLabel.isNotEmpty &&
              availableHeight >= 96;
          final showRoom = roomName != null && availableHeight >= 120;
          final hasBottomSection = showRoom;

          final children = <Widget>[
            Row(
              children: [
                Expanded(
                  child: Text(timeLabel, style: theme.textTheme.labelLarge),
                ),
                Icon(Icons.circle, size: 12, color: statusColorValue),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              client?.fullName ?? 'Cliente',
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ];

          if (showService) {
            children
              ..add(const SizedBox(height: 4))
              ..add(
                Text(
                  serviceLabel,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
          }

          if (hasBottomSection) {
            if (availableHeight >= 88) {
              children
                ..add(const Spacer())
                ..add(const SizedBox(height: 4));
            } else {
              children.add(SizedBox(height: availableHeight >= 76 ? 4 : 2));
            }
          }

          if (showRoom) {
            children
              ..add(const SizedBox(height: 2))
              ..add(
                Text(
                  'Stanza: $roomName',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        },
      ),
    );

    final overlayWidgets = <Widget>[];
    if (!hideContent) {
      if (hasAnomalies) {
        overlayWidgets.add(
          Positioned(
            top: 8,
            right: 8,
            child: Tooltip(
              message: anomaliesTooltip ?? 'Appuntamento da gestire',
              waitDuration: const Duration(milliseconds: 250),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.error.withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    AppointmentAnomalyType.noShift.icon,
                    color: theme.colorScheme.onError,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        );
      }
      if (isLocked) {
        overlayWidgets.add(
          Positioned(
            top: 8,
            left: 8,
            child: Tooltip(
              message: lockReason ?? 'Appuntamento non modificabile',
              waitDuration: const Duration(milliseconds: 250),
              child: Icon(
                Icons.lock_rounded,
                color: theme.colorScheme.outline,
                size: 18,
              ),
            ),
          ),
        );
      }
      if (isLastMinute) {
        final slot = lastMinuteSlot;
        if (slot != null) {
          overlayWidgets.add(
            Positioned(
              bottom: 8,
              right: 8,
              child: Tooltip(
                message:
                    slot.isAvailable
                        ? 'Slot last-minute disponibile'
                        : 'Appuntamento last-minute',
                waitDuration: const Duration(milliseconds: 250),
                child: Container(
                  padding:
                      hideContent
                          ? const EdgeInsets.all(6)
                          : const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
              ),
            ),
          );
        }
      }
    }

    Widget decoratedCard =
        overlayWidgets.isEmpty
            ? card
            : Stack(children: [card, ...overlayWidgets]);

    final hoverLines = <String>[];
    hoverLines
      ..add('Inizio: $startTimeLabel')
      ..add('Fine: $endTimeLabel');
    final clientName = client?.fullName;
    final normalizedClientName = clientName?.trim();
    final normalizedServiceName = serviceLabel?.trim();
    final notes = appointment.notes?.trim();
    if (normalizedClientName != null && normalizedClientName.isNotEmpty) {
      hoverLines.add('Cliente: $normalizedClientName');
    }
    if (normalizedServiceName != null && normalizedServiceName.isNotEmpty) {
      hoverLines.add('Servizio: $normalizedServiceName');
    }
    if (appointment.packageId != null) {
      hoverLines.add('Scalato da sessione');
    }
    if (notes != null && notes.isNotEmpty) {
      hoverLines.add('Note: $notes');
    }
    final hoverTooltip = hoverLines.isEmpty ? null : hoverLines.join('\n');

    Widget interactiveCard = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: decoratedCard,
      ),
    );

    if (hoverTooltip != null) {
      interactiveCard = Tooltip(
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

class _DragPreviewCard extends StatelessWidget {
  const _DragPreviewCard({
    required this.appointment,
    required this.client,
    required this.service,
    this.services = const <Service>[],
    required this.staff,
    required this.statusColor,
    required this.height,
    this.roomName,
    this.anomalies = const <AppointmentAnomalyType>{},
    this.previewStart,
    this.previewDuration,
    required this.slotMinutes,
    this.lastMinuteSlot,
    required this.categoriesById,
    required this.categoriesByName,
  });

  final Appointment appointment;
  final Client? client;
  final Service? service;
  final List<Service> services;
  final StaffMember staff;
  final Color Function(AppointmentStatus status) statusColor;
  final double height;
  final String? roomName;
  final Set<AppointmentAnomalyType> anomalies;
  final DateTime? previewStart;
  final Duration? previewDuration;
  final int slotMinutes;
  final LastMinuteSlot? lastMinuteSlot;
  final Map<String, ServiceCategory> categoriesById;
  final Map<String, ServiceCategory> categoriesByName;

  @override
  Widget build(BuildContext context) {
    final start = previewStart ?? appointment.start;
    final end =
        previewDuration != null ? start.add(previewDuration!) : appointment.end;
    final normalizedEnd =
        end.isBefore(start) ? start.add(Duration(minutes: slotMinutes)) : end;
    final previewed = appointment.copyWith(start: start, end: normalizedEnd);
    return _AppointmentCard(
      appointment: previewed,
      client: client,
      service: service,
      services: services,
      staff: staff,
      roomName: roomName,
      statusColor: statusColor,
      height: height,
      anomalies: anomalies,
      lockReason: null,
      highlight: true,
      lastMinuteSlot: lastMinuteSlot,
      categoriesById: categoriesById,
      categoriesByName: categoriesByName,
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
