import 'dart:math';

import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/shift.dart';
import 'package:civiapp/domain/entities/staff_absence.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/staff_role.dart';
import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum AppointmentCalendarScope { day, week }

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
    required this.staff,
    required this.clients,
    required this.services,
    required this.shifts,
    required this.absences,
    required this.roles,
    this.schedule,
    required this.visibleWeekdays,
    required this.roomsById,
    required this.onReschedule,
    required this.onEdit,
    required this.onCreate,
    required this.statusColor,
  });

  final DateTime anchorDate;
  final AppointmentCalendarScope scope;
  final List<Appointment> appointments;
  final List<StaffMember> staff;
  final List<StaffRole> roles;
  final List<Client> clients;
  final List<Service> services;
  final List<Shift> shifts;
  final List<StaffAbsence> absences;
  final List<SalonDailySchedule>? schedule;
  final Set<int> visibleWeekdays;
  final Map<String, String> roomsById;
  final AppointmentRescheduleCallback onReschedule;
  final AppointmentTapCallback onEdit;
  final AppointmentSlotSelectionCallback onCreate;
  final Color Function(AppointmentStatus status) statusColor;

  @override
  State<AppointmentCalendarView> createState() =>
      _AppointmentCalendarViewState();
}

class _AppointmentCalendarViewState extends State<AppointmentCalendarView> {
  static const _slotMinutes = 30;
  static const _slotExtent = 52.0;
  static const _timeScaleExtent = 74.0;

  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  bool _isSynchronizing = false;

  @override
  void initState() {
    super.initState();
    _horizontalHeaderController.addListener(_syncFromHeader);
    _horizontalBodyController.addListener(_syncFromBody);
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
    switch (widget.scope) {
      case AppointmentCalendarScope.day:
        return _DaySchedule(
          anchorDate: widget.anchorDate,
          appointments: widget.appointments,
          shifts: widget.shifts,
          absences: widget.absences,
          schedule: widget.schedule,
          staff: widget.staff,
          roles: widget.roles,
          clientsById: clientsById,
          servicesById: servicesById,
          roomsById: widget.roomsById,
          statusColor: widget.statusColor,
          onReschedule: widget.onReschedule,
          onEdit: widget.onEdit,
          onCreate: widget.onCreate,
          horizontalHeaderController: _horizontalHeaderController,
          horizontalBodyController: _horizontalBodyController,
          verticalController: _verticalController,
        );
      case AppointmentCalendarScope.week:
        return _WeekSchedule(
          anchorDate: widget.anchorDate,
          appointments: widget.appointments,
          shifts: widget.shifts,
          absences: widget.absences,
          schedule: widget.schedule,
          visibleWeekdays: widget.visibleWeekdays,
          staff: widget.staff,
          roles: widget.roles,
          clientsById: clientsById,
          servicesById: servicesById,
          roomsById: widget.roomsById,
          statusColor: widget.statusColor,
          onReschedule: widget.onReschedule,
          onEdit: widget.onEdit,
          onCreate: widget.onCreate,
          horizontalHeaderController: _horizontalHeaderController,
          horizontalBodyController: _horizontalBodyController,
          verticalController: _verticalController,
        );
    }
  }
}

class _DaySchedule extends StatelessWidget {
  const _DaySchedule({
    required this.anchorDate,
    required this.appointments,
    required this.shifts,
    required this.absences,
    required this.schedule,
    required this.staff,
    required this.roles,
    required this.clientsById,
    required this.servicesById,
    required this.roomsById,
    required this.statusColor,
    required this.onReschedule,
    required this.onEdit,
    required this.onCreate,
    required this.horizontalHeaderController,
    required this.horizontalBodyController,
    required this.verticalController,
  });

  final DateTime anchorDate;
  final List<Appointment> appointments;
  final List<Shift> shifts;
  final List<StaffAbsence> absences;
  final List<SalonDailySchedule>? schedule;
  final List<StaffMember> staff;
  final List<StaffRole> roles;
  final Map<String, Client> clientsById;
  final Map<String, Service> servicesById;
  final Map<String, String> roomsById;
  final Color Function(AppointmentStatus status) statusColor;
  final AppointmentRescheduleCallback onReschedule;
  final AppointmentTapCallback onEdit;
  final AppointmentSlotSelectionCallback onCreate;
  final ScrollController horizontalHeaderController;
  final ScrollController horizontalBodyController;
  final ScrollController verticalController;

  static const _slotMinutes = _AppointmentCalendarViewState._slotMinutes;
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
    );
    final totalMinutes = bounds.end.difference(bounds.start).inMinutes;
    final slotCount = max(1, (totalMinutes / _slotMinutes).ceil());
    final gridHeight = slotCount * _slotExtent;
    final timeSlots = List.generate(
      slotCount + 1,
      (index) => bounds.start.add(Duration(minutes: index * _slotMinutes)),
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
    final rolesById = {for (final role in roles) role.id: role};

    final dateLabel = DateFormat('EEEE dd MMMM', 'it_IT').format(dayStart);

    final theme = Theme.of(context);
    final headerColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.55,
    );
    final timelineColor = theme.colorScheme.surfaceContainerLowest.withValues(
      alpha: 0.45,
    );
    final timeFormat = DateFormat('HH:mm');
    String openingInfo;
    if (scheduleEntry == null) {
      openingInfo = 'Orario non impostato';
    } else if (!scheduleEntry.isOpen) {
      openingInfo = 'Salone chiuso';
    } else if (scheduleEntry.openMinuteOfDay != null &&
        scheduleEntry.closeMinuteOfDay != null) {
      final openLabel = timeFormat.format(
        dayStart.add(Duration(minutes: scheduleEntry.openMinuteOfDay!)),
      );
      final closeLabel = timeFormat.format(
        dayStart.add(Duration(minutes: scheduleEntry.closeMinuteOfDay!)),
      );
      openingInfo = 'Orario salone: $openLabel - $closeLabel';
    } else {
      openingInfo = 'Orario non impostato';
    }

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
                      Text(
                        dateLabel,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        openingInfo,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],
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
              child: Scrollbar(
                controller: horizontalBodyController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: horizontalBodyController,
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                              color: theme.dividerColor.withValues(alpha: 0.35),
                            ),
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
                        for (
                          var staffIndex = 0;
                          staffIndex < staff.length;
                          staffIndex++
                        ) ...[
                          Padding(
                            padding: EdgeInsets.only(
                              right: staffIndex == staff.length - 1 ? 0 : 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 220,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.dividerColor.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        staff[staffIndex].fullName,
                                        style: theme.textTheme.titleSmall,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        rolesById[staff[staffIndex].roleId]
                                                ?.displayName ??
                                            'Mansione',
                                        style: theme.textTheme.bodySmall,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.dividerColor.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: SizedBox(
                                    width: 220,
                                    height: gridHeight,
                                    child: _StaffDayColumn(
                                      staffMember: staff[staffIndex],
                                      appointments:
                                          appointmentsByStaff[staff[staffIndex]
                                              .id] ??
                                          const [],
                                      shifts:
                                          shiftsByStaff[staff[staffIndex].id] ??
                                          const [],
                                      absences:
                                          absencesByStaff[staff[staffIndex]
                                              .id] ??
                                          const [],
                                      timelineStart: bounds.start,
                                      timelineEnd: bounds.end,
                                      slotMinutes: _slotMinutes,
                                      slotExtent: _slotExtent,
                                      clientsById: clientsById,
                                      servicesById: servicesById,
                                      roomsById: roomsById,
                                      statusColor: statusColor,
                                      onReschedule: onReschedule,
                                      onEdit: onEdit,
                                      onCreate: onCreate,
                                      openStart: openingStart,
                                      openEnd: closingEnd,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
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

    DateTime fallbackStart = dayStart.add(const Duration(hours: 8));
    if (openingStart != null) {
      final candidate = openingStart.subtract(const Duration(minutes: 30));
      fallbackStart = candidate.isBefore(dayStart) ? dayStart : candidate;
    }
    DateTime fallbackEnd = dayStart.add(const Duration(hours: 20));
    if (closingEnd != null) {
      final candidate = closingEnd.add(const Duration(minutes: 30));
      fallbackEnd = candidate.isAfter(dayEnd) ? dayEnd : candidate;
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

    start = _floorToSlot(start.subtract(const Duration(minutes: 15)));
    end = _ceilToSlot(end.add(const Duration(minutes: 15)));

    return _TimelineBounds(start: start, end: end);
  }
}

class _WeekSchedule extends StatelessWidget {
  const _WeekSchedule({
    required this.anchorDate,
    required this.appointments,
    required this.shifts,
    required this.absences,
    required this.schedule,
    required this.visibleWeekdays,
    required this.staff,
    required this.roles,
    required this.clientsById,
    required this.servicesById,
    required this.roomsById,
    required this.statusColor,
    required this.onReschedule,
    required this.onEdit,
    required this.onCreate,
    required this.horizontalHeaderController,
    required this.horizontalBodyController,
    required this.verticalController,
  });

  final DateTime anchorDate;
  final List<Appointment> appointments;
  final List<Shift> shifts;
  final List<StaffAbsence> absences;
  final List<SalonDailySchedule>? schedule;
  final Set<int> visibleWeekdays;
  final List<StaffMember> staff;
  final List<StaffRole> roles;
  final Map<String, Client> clientsById;
  final Map<String, Service> servicesById;
  final Map<String, String> roomsById;
  final Color Function(AppointmentStatus status) statusColor;
  final AppointmentRescheduleCallback onReschedule;
  final AppointmentTapCallback onEdit;
  final AppointmentSlotSelectionCallback onCreate;
  final ScrollController horizontalHeaderController;
  final ScrollController horizontalBodyController;
  final ScrollController verticalController;

  static const _slotMinutes = _AppointmentCalendarViewState._slotMinutes;
  static const _slotExtent = _AppointmentCalendarViewState._slotExtent;
  static const _timeScaleExtent =
      _AppointmentCalendarViewState._timeScaleExtent;

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
    final slotCount = max(1, (totalMinutes / _slotMinutes).ceil());
    final gridHeight = slotCount * _slotExtent;
    final referenceDate = dayData.first.date;
    final referenceTimelineStart = referenceDate.add(
      Duration(minutes: minMinute),
    );
    final timeSlots = List.generate(
      slotCount + 1,
      (index) =>
          referenceTimelineStart.add(Duration(minutes: index * _slotMinutes)),
    );

    final dayLabelFormat = DateFormat('EEE dd MMM', 'it_IT');
    final timeFormat = DateFormat('HH:mm');

    final dayHeaderColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.55,
    );
    final dayBodyColor = theme.colorScheme.surfaceContainerLowest.withValues(
      alpha: 0.45,
    );
    final rolesById = {for (final role in roles) role.id: role};

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
                child: Scrollbar(
                  controller: horizontalHeaderController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: horizontalHeaderController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        for (
                          var dayIndex = 0;
                          dayIndex < dayData.length;
                          dayIndex++
                        ) ...[
                          Container(
                            margin: EdgeInsets.only(
                              right: dayIndex == dayData.length - 1 ? 0 : 16,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: dayHeaderColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.dividerColor.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dayLabelFormat.format(dayData[dayIndex].date),
                                  style: theme.textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _openingLabel(dayData[dayIndex], timeFormat),
                                  style: theme.textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (
                                      var columnIndex = 0;
                                      columnIndex < staff.length;
                                      columnIndex++
                                    ) ...[
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: columnIndex == 0 ? 0 : 8,
                                          right:
                                              columnIndex == staff.length - 1
                                                  ? 0
                                                  : 8,
                                        ),
                                        child: SizedBox(
                                          width: 220,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                staff[columnIndex].fullName,
                                                style:
                                                    theme.textTheme.titleSmall,
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                rolesById[staff[columnIndex]
                                                            .roleId]
                                                        ?.displayName ??
                                                    'Mansione',
                                                style:
                                                    theme.textTheme.bodySmall,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
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
        Expanded(
          child: Scrollbar(
            controller: verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: verticalController,
              child: Scrollbar(
                controller: horizontalBodyController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: horizontalBodyController,
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                            color: dayHeaderColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.35),
                            ),
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
                        for (
                          var dayIndex = 0;
                          dayIndex < dayData.length;
                          dayIndex++
                        ) ...[
                          Container(
                            margin: EdgeInsets.only(
                              right: dayIndex == dayData.length - 1 ? 0 : 16,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: dayBodyColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.dividerColor.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
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
                                      left: staffIndex == 0 ? 12 : 8,
                                      right:
                                          staffIndex == staff.length - 1
                                              ? 12
                                              : 8,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.dividerColor.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                      child: SizedBox(
                                        width: 220,
                                        height: gridHeight,
                                        child: _StaffDayColumn(
                                          staffMember: staff[staffIndex],
                                          appointments:
                                              dayData[dayIndex]
                                                  .appointmentsByStaff[staff[staffIndex]
                                                  .id] ??
                                              const [],
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
                                          timelineStart: dayData[dayIndex].date
                                              .add(
                                                Duration(minutes: minMinute),
                                              ),
                                          timelineEnd: dayData[dayIndex].date
                                              .add(
                                                Duration(minutes: maxMinute),
                                              ),
                                          slotMinutes: _slotMinutes,
                                          slotExtent: _slotExtent,
                                          clientsById: clientsById,
                                          servicesById: servicesById,
                                          roomsById: roomsById,
                                          statusColor: statusColor,
                                          onReschedule: onReschedule,
                                          onEdit: onEdit,
                                          onCreate: onCreate,
                                          openStart:
                                              dayData[dayIndex].openStart,
                                          openEnd: dayData[dayIndex].openEnd,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _openingLabel(_WeekDayData data, DateFormat timeFormat) {
    final entry = data.scheduleEntry;
    if (entry == null) {
      return 'Orario non impostato';
    }
    if (!entry.isOpen) {
      return 'Salone chiuso';
    }
    if (data.openStart == null || data.openEnd == null) {
      return 'Orario non impostato';
    }
    final open = timeFormat.format(data.openStart!);
    final close = timeFormat.format(data.openEnd!);
    return 'Orario salone: $open - $close';
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
    required this.shifts,
    required this.absences,
    required this.timelineStart,
    required this.timelineEnd,
    required this.slotMinutes,
    required this.slotExtent,
    required this.clientsById,
    required this.servicesById,
    required this.roomsById,
    required this.statusColor,
    required this.onReschedule,
    required this.onEdit,
    required this.onCreate,
    this.openStart,
    this.openEnd,
  });

  final StaffMember staffMember;
  final List<Appointment> appointments;
  final List<Shift> shifts;
  final List<StaffAbsence> absences;
  final DateTime timelineStart;
  final DateTime timelineEnd;
  final int slotMinutes;
  final double slotExtent;
  final Map<String, Client> clientsById;
  final Map<String, Service> servicesById;
  final Map<String, String> roomsById;
  final Color Function(AppointmentStatus status) statusColor;
  final AppointmentRescheduleCallback onReschedule;
  final AppointmentTapCallback onEdit;
  final AppointmentSlotSelectionCallback onCreate;
  final DateTime? openStart;
  final DateTime? openEnd;

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

  bool _hasOverlap(
    DateTime start,
    DateTime end,
    Appointment movingAppointment,
  ) {
    return widget.appointments.any((appointment) {
      if (appointment.id == movingAppointment.id) {
        return false;
      }
      return appointment.start.isBefore(end) && appointment.end.isAfter(start);
    });
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
    Widget? dragOverlay;
    if (dragStart != null && dragDuration != null) {
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
        final fillColor =
            _dragPreviewHasConflict
                ? theme.colorScheme.error.withValues(alpha: 0.08)
                : theme.colorScheme.primary.withValues(alpha: 0.12);
        final outlineColor =
            _dragPreviewHasConflict
                ? theme.colorScheme.error.withValues(alpha: 0.45)
                : theme.colorScheme.primary.withValues(alpha: 0.35);
        dragOverlay = Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: outlineColor, width: 2),
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
        final isBusy = widget.appointments.any(
          (appointment) =>
              appointment.start.isBefore(hoverEnd) &&
              appointment.end.isAfter(hoverStart),
        );
        final fillColor =
            isBusy
                ? theme.colorScheme.error.withValues(alpha: 0.08)
                : theme.colorScheme.primary.withValues(alpha: 0.08);
        final outlineColor =
            isBusy
                ? theme.colorScheme.error.withValues(alpha: 0.35)
                : theme.colorScheme.primary.withValues(alpha: 0.25);
        hoverOverlay = Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Container(
            height: widget.slotExtent,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: outlineColor, width: 1.5),
            ),
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
            final hasConflict = _hasOverlap(
              previewStart,
              previewEnd,
              payload.appointment,
            );
            if (_dragPreviewStart != previewStart ||
                _dragPreviewDuration != payload.duration ||
                _dragPreviewHasConflict != hasConflict) {
              setState(() {
                _dragPreviewStart = previewStart;
                _dragPreviewDuration = payload.duration;
                _dragPreviewHasConflict = hasConflict;
              });
            }
          },
          onLeave: (_) {
            _setDragging(false);
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              height: gridHeight,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                  ),
                ),
              ),
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

                    return [
                      Positioned(
                        top: top,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.all(6),
                          alignment: Alignment.topLeft,
                          child: Text(
                            description.toString(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                    final service = widget.servicesById[appointment.serviceId];
                    final roomName =
                        appointment.roomId != null
                            ? widget.roomsById[appointment.roomId!]
                            : null;
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
                          child: _AppointmentCard(
                            appointment: appointment,
                            client: client,
                            service: service,
                            staff: widget.staffMember,
                            roomName: roomName,
                            statusColor: widget.statusColor,
                            isPreview: true,
                            height: height,
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.4,
                          child: _AppointmentCard(
                            appointment: appointment,
                            client: client,
                            service: service,
                            staff: widget.staffMember,
                            roomName: roomName,
                            statusColor: widget.statusColor,
                            height: height,
                          ),
                        ),
                        child: _AppointmentCard(
                          appointment: appointment,
                          client: client,
                          service: service,
                          staff: widget.staffMember,
                          roomName: roomName,
                          statusColor: widget.statusColor,
                          onTap: () => widget.onEdit(appointment),
                          height: height,
                        ),
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

            if (_hasOverlap(newStart, newEnd, payload.appointment)) {
              _setDragging(false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Impossibile riprogrammare: slot già occupato'),
                ),
              );
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

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.client,
    required this.service,
    required this.staff,
    required this.statusColor,
    required this.height,
    this.roomName,
    this.onTap,
    this.isPreview = false,
  });

  final Appointment appointment;
  final Client? client;
  final Service? service;
  final StaffMember staff;
  final Color Function(AppointmentStatus status) statusColor;
  final double height;
  final String? roomName;
  final VoidCallback? onTap;
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = appointment.status;
    final timeLabel =
        '${DateFormat('HH:mm').format(appointment.start)} - ${DateFormat('HH:mm').format(appointment.end)}';
    final color = statusColor(status);
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isPreview)
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          if (availableHeight <= 0) {
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
                Icon(Icons.circle, size: 8, color: color),
              ],
            );
          }

          if (availableHeight < 72) {
            final serviceLabelShouldShow =
                service != null && availableHeight >= 64;
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
                    Icon(Icons.circle, size: 9, color: color),
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
                    service!.name,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            );
          }

          final showService = service != null && availableHeight >= 96;
          final showStaff = availableHeight >= 64;
          final showRoom = roomName != null && availableHeight >= 120;
          final hasBottomSection = showStaff || showRoom;

          final children = <Widget>[
            Row(
              children: [
                Expanded(
                  child: Text(timeLabel, style: theme.textTheme.labelLarge),
                ),
                Icon(Icons.circle, size: 10, color: color),
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
                  service!.name,
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

          if (showStaff) {
            children.add(
              Text(
                staff.fullName,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
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

    if (isPreview) {
      return Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      ),
    );
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

DateTime _floorToSlot(DateTime value) {
  const minutes = _AppointmentCalendarViewState._slotMinutes;
  final remainder = value.minute % minutes;
  return DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute - remainder,
  );
}

DateTime _ceilToSlot(DateTime value) {
  const minutes = _AppointmentCalendarViewState._slotMinutes;
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
