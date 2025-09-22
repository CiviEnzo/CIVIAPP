import 'package:civiapp/app/providers.dart';
import 'package:civiapp/data/repositories/app_data_state.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/shift.dart';
import 'package:civiapp/domain/entities/staff_absence.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/appointment_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/modules/appointments/appointment_calendar_view.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

enum _AppointmentDisplayMode { calendar, list }

class AppointmentsModule extends ConsumerStatefulWidget {
  const AppointmentsModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<AppointmentsModule> createState() => _AppointmentsModuleState();
}

const List<MapEntry<int, String>> _weekdayOptions = <MapEntry<int, String>>[
  MapEntry(DateTime.monday, 'Lunedì'),
  MapEntry(DateTime.tuesday, 'Martedì'),
  MapEntry(DateTime.wednesday, 'Mercoledì'),
  MapEntry(DateTime.thursday, 'Giovedì'),
  MapEntry(DateTime.friday, 'Venerdì'),
  MapEntry(DateTime.saturday, 'Sabato'),
  MapEntry(DateTime.sunday, 'Domenica'),
];

class _AppointmentsModuleState extends ConsumerState<AppointmentsModule> {
  static final _dayLabel = DateFormat('EEEE dd MMMM yyyy', 'it_IT');
  static final _weekStartLabel = DateFormat('dd MMM', 'it_IT');
  static final _timeLabel = DateFormat('HH:mm', 'it_IT');

  _AppointmentDisplayMode _mode = _AppointmentDisplayMode.calendar;
  AppointmentCalendarScope _scope = AppointmentCalendarScope.day;
  late DateTime _anchorDate;
  String? _selectedStaffId;
  bool _isRescheduling = false;
  final Set<int> _visibleWeekdays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchorDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final salons = data.salons;
    final clients = data.clients;
    final staffMembers = data.staff
        .where(
          (member) =>
              widget.salonId == null || member.salonId == widget.salonId,
        )
        .sortedBy((member) => member.fullName.toLowerCase());
    final services = data.services;
    final selectedSalon =
        widget.salonId != null
            ? salons.firstWhereOrNull((salon) => salon.id == widget.salonId)
            : null;

    final currentStaff = staffMembers.firstWhereOrNull(
      (member) => member.id == _selectedStaffId,
    );
    if (currentStaff == null && _selectedStaffId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedStaffId = null);
      });
    }

    final visibleStaff = currentStaff != null ? [currentStaff] : staffMembers;
    final staffIds = visibleStaff.map((member) => member.id).toSet();

    final rangeStart = _rangeStart(_anchorDate, _scope);
    final rangeEnd = _rangeEnd(rangeStart, _scope);

    final appointments = data.appointments
        .where(
          (appointment) =>
              widget.salonId == null || appointment.salonId == widget.salonId,
        )
        .where(
          (appointment) =>
              staffIds.isEmpty || staffIds.contains(appointment.staffId),
        )
        .where(
          (appointment) => _dateRangesOverlap(
            appointment.start,
            appointment.end,
            rangeStart,
            rangeEnd,
          ),
        )
        .sortedBy((appointment) => appointment.start);
    final filteredAppointments =
        appointments
            .where(
              (appointment) => _isWeekdayVisible(appointment.start.weekday),
            )
            .toList();

    final List<Shift> shifts = data.shifts
        .where(
          (shift) => widget.salonId == null || shift.salonId == widget.salonId,
        )
        .where((shift) => staffIds.isEmpty || staffIds.contains(shift.staffId))
        .where(
          (shift) =>
              _dateRangesOverlap(shift.start, shift.end, rangeStart, rangeEnd),
        )
        .sortedBy((shift) => shift.start);
    final filteredShifts =
        shifts
            .where((shift) => _isWeekdayVisible(shift.start.weekday))
            .toList();
    final List<StaffAbsence> absences = data.staffAbsences
        .where(
          (absence) =>
              widget.salonId == null || absence.salonId == widget.salonId,
        )
        .where(
          (absence) => staffIds.isEmpty || staffIds.contains(absence.staffId),
        )
        .where(
          (absence) => _dateRangesOverlap(
            absence.start,
            absence.end,
            rangeStart,
            rangeEnd,
          ),
        )
        .sortedBy((absence) => absence.start);
    final filteredAbsences =
        absences
            .where((absence) => _isWeekdayVisible(absence.start.weekday))
            .toList();

    final roomsById = _buildRoomsIndex(salons, widget.salonId);
    final rangeLabel = _buildRangeLabel(rangeStart, rangeEnd, _scope);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildToolbar(
            context,
            salons: salons,
            clients: clients,
            staff: staffMembers,
            services: services,
            rangeLabel: rangeLabel,
            selectedSalon: selectedSalon,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child:
                _mode == _AppointmentDisplayMode.calendar
                    ? AppointmentCalendarView(
                      key: ValueKey(
                        'calendar-${_scope.name}-${_selectedStaffId ?? 'all'}-${rangeStart.toIso8601String()}',
                      ),
                      anchorDate: rangeStart,
                      scope: _scope,
                      appointments: filteredAppointments,
                      staff: visibleStaff,
                      clients: clients,
                      services: services,
                      shifts: filteredShifts,
                      absences: filteredAbsences,
                      roles: data.staffRoles,
                      schedule: selectedSalon?.schedule,
                      roomsById: roomsById,
                      visibleWeekdays: _visibleWeekdays,
                      statusColor: (status) => _colorForStatus(context, status),
                      onReschedule:
                          _isRescheduling ? (_) async {} : _onReschedule,
                      onEdit:
                          (appointment) => _openAppointmentForm(
                            context,
                            salons: salons,
                            clients: clients,
                            staff: staffMembers,
                            services: services,
                            existing: appointment,
                          ),
                      onCreate:
                          (selection) => _onSlotSelected(
                            context,
                            selection,
                            salons,
                            clients,
                            staffMembers,
                            services,
                          ),
                    )
                    : _ListAppointmentsView(
                      key: ValueKey(
                        'list-${_scope.name}-${_selectedStaffId ?? 'all'}-${rangeStart.toIso8601String()}',
                      ),
                      appointments: filteredAppointments,
                      data: data,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      onEdit:
                          (appointment) => _openAppointmentForm(
                            context,
                            salons: salons,
                            clients: clients,
                            staff: staffMembers,
                            services: services,
                            existing: appointment,
                          ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(
    BuildContext context, {
    required List<Salon> salons,
    required List<Client> clients,
    required List<StaffMember> staff,
    required List<Service> services,
    required String rangeLabel,
    Salon? selectedSalon,
  }) {
    final theme = Theme.of(context);
    final scopeSegments = <ButtonSegment<AppointmentCalendarScope>>[
      const ButtonSegment(
        value: AppointmentCalendarScope.day,
        label: Text('Giorno'),
        icon: Icon(Icons.calendar_view_day_rounded),
      ),
      const ButtonSegment(
        value: AppointmentCalendarScope.week,
        label: Text('Settimana'),
        icon: Icon(Icons.view_week_rounded),
      ),
    ];
    final modeSegments = <ButtonSegment<_AppointmentDisplayMode>>[
      const ButtonSegment(
        value: _AppointmentDisplayMode.calendar,
        label: Text('Calendario'),
        icon: Icon(Icons.calendar_month_rounded),
      ),
      const ButtonSegment(
        value: _AppointmentDisplayMode.list,
        label: Text('Lista'),
        icon: Icon(Icons.view_list_rounded),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed:
                  () => _openAppointmentForm(
                    context,
                    salons: salons,
                    clients: clients,
                    staff: staff,
                    services: services,
                  ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuovo appuntamento'),
            ),
            SegmentedButton<_AppointmentDisplayMode>(
              segments: modeSegments,
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() => _mode = selection.first);
              },
            ),
            SegmentedButton<AppointmentCalendarScope>(
              segments: scopeSegments,
              selected: {_scope},
              onSelectionChanged: (selection) => _updateScope(selection.first),
            ),
            _RangeNavigator(
              label: rangeLabel,
              onPrevious: () => _shiftAnchor(-1),
              onNext: () => _shiftAnchor(1),
            ),
            FilledButton.tonal(
              onPressed: _goToToday,
              child: const Text('Oggi'),
            ),
            FilledButton.tonalIcon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Vai a data'),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                value: _selectedStaffId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filtra per operatore',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tutto lo staff'),
                  ),
                  ...staff.map(
                    (member) => DropdownMenuItem<String?>(
                      value: member.id,
                      child: Text(member.fullName),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedStaffId = value),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _openWeekdayFilter(context, selectedSalon),
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(
                _visibleWeekdays.length == 7
                    ? 'Tutti i giorni'
                    : '${_visibleWeekdays.length} giorni',
              ),
            ),
          ],
        ),
        if (_mode == _AppointmentDisplayMode.calendar)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer.withValues(
                      alpha: 0.6,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Disponibilità staff (turni) evidenziata all’interno della griglia',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      setState(() {
        if (_scope == AppointmentCalendarScope.week) {
          _anchorDate = _startOfWeek(picked);
        } else {
          final desired = DateTime(picked.year, picked.month, picked.day);
          _anchorDate =
              _isWeekdayVisible(desired.weekday)
                  ? desired
                  : _findNextVisibleDay(desired, 1);
        }
      });
    }
  }

  void _updateScope(AppointmentCalendarScope scope) {
    if (scope == _scope) {
      return;
    }
    setState(() {
      _scope = scope;
      if (_scope == AppointmentCalendarScope.week) {
        _anchorDate = _startOfWeek(_anchorDate);
      } else {
        _anchorDate = _findNextVisibleDay(_anchorDate, 1);
      }
    });
  }

  void _shiftAnchor(int direction) {
    final deltaDays = _scope == AppointmentCalendarScope.day ? 1 : 7;
    setState(() {
      if (_scope == AppointmentCalendarScope.day) {
        var candidate = _anchorDate.add(Duration(days: direction));
        candidate = _findNextVisibleDay(candidate, direction);
        _anchorDate = candidate;
      } else {
        _anchorDate = _anchorDate.add(Duration(days: deltaDays * direction));
      }
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      final today = DateTime(now.year, now.month, now.day);
      _anchorDate =
          _scope == AppointmentCalendarScope.week
              ? _startOfWeek(today)
              : _findNextVisibleDay(today, 1);
    });
  }

  Future<void> _openWeekdayFilter(
    BuildContext context,
    Salon? selectedSalon,
  ) async {
    final allowedDays =
        selectedSalon == null || selectedSalon.schedule.isEmpty
            ? null
            : selectedSalon.schedule
                .where((entry) => entry.isOpen)
                .map((entry) => entry.weekday)
                .toSet();

    var options = _weekdayOptions;
    if (allowedDays != null && allowedDays.isNotEmpty) {
      final filtered =
          _weekdayOptions
              .where((option) => allowedDays.contains(option.key))
              .toList();
      if (filtered.isNotEmpty) {
        options = filtered;
      }
    }

    final tempSelection = Set<int>.from(
      _visibleWeekdays.where(
        (day) => allowedDays == null || allowedDays.contains(day),
      ),
    );
    if (tempSelection.isEmpty) {
      tempSelection.add(options.first.key);
    }

    final ferialiKeys =
        options
            .where(
              (entry) =>
                  entry.key != DateTime.saturday &&
                  entry.key != DateTime.sunday,
            )
            .map((entry) => entry.key)
            .toList();

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Giorni visibili',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (allowedDays != null && allowedDays.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sono disponibili solo i giorni in cui il salone è aperto.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ...options.map((option) {
                    final selected = tempSelection.contains(option.key);
                    return CheckboxListTile(
                      value: selected,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(option.value),
                      onChanged: (value) {
                        if (value == true) {
                          setModalState(() => tempSelection.add(option.key));
                        } else if (tempSelection.length > 1) {
                          setModalState(() => tempSelection.remove(option.key));
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed:
                            () => setModalState(() {
                              tempSelection
                                ..clear()
                                ..addAll(options.map((entry) => entry.key));
                            }),
                        child: const Text('Seleziona tutti'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed:
                            ferialiKeys.isEmpty
                                ? null
                                : () => setModalState(() {
                                  tempSelection
                                    ..clear()
                                    ..addAll(ferialiKeys);
                                }),
                        child: const Text('Solo feriali'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annulla'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed:
                            tempSelection.isEmpty
                                ? null
                                : () => Navigator.pop(
                                  context,
                                  Set<int>.from(tempSelection),
                                ),
                        child: const Text('Applica'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _visibleWeekdays
          ..clear()
          ..addAll(result);
        _ensureAnchorVisible();
      });
    }
  }

  bool _isWeekdayVisible(int weekday) => _visibleWeekdays.contains(weekday);

  DateTime _findNextVisibleDay(DateTime start, int direction) {
    var candidate = DateTime(start.year, start.month, start.day);
    for (var i = 0; i < 7; i++) {
      if (_isWeekdayVisible(candidate.weekday)) {
        return candidate;
      }
      candidate = candidate.add(Duration(days: direction >= 0 ? 1 : -1));
    }
    return DateTime(start.year, start.month, start.day);
  }

  void _ensureAnchorVisible() {
    if (_scope == AppointmentCalendarScope.day &&
        !_isWeekdayVisible(_anchorDate.weekday)) {
      _anchorDate = _findNextVisibleDay(_anchorDate, 1);
    }
  }

  void _onSlotSelected(
    BuildContext context,
    AppointmentSlotSelection selection,
    List<Salon> salons,
    List<Client> clients,
    List<StaffMember> staff,
    List<Service> services,
  ) {
    final staffMember = staff.firstWhereOrNull(
      (member) => member.id == selection.staffId,
    );
    final defaultSalonId =
        staffMember?.salonId ??
        widget.salonId ??
        (salons.isNotEmpty ? salons.first.id : null);
    _openAppointmentForm(
      context,
      salons: salons,
      clients: clients,
      staff: staff,
      services: services,
      initialStart: selection.start,
      initialEnd: selection.end,
      initialStaffId: staffMember?.id,
      initialSalonId: defaultSalonId,
    );
  }

  Future<void> _onReschedule(AppointmentRescheduleRequest request) async {
    final appointment = request.appointment;
    final newStaffId = request.newStaffId ?? appointment.staffId;
    final newRoomId = request.newRoomId ?? appointment.roomId;
    if (!mounted || _isRescheduling) {
      return;
    }
    if (appointment.start == request.newStart &&
        appointment.end == request.newEnd &&
        appointment.staffId == newStaffId &&
        appointment.roomId == newRoomId) {
      return;
    }
    setState(() => _isRescheduling = true);
    final updated = appointment.copyWith(
      staffId: newStaffId,
      start: request.newStart,
      end: request.newEnd,
      roomId: newRoomId,
    );
    try {
      await ref.read(appDataProvider.notifier).upsertAppointment(updated);
      if (!mounted) {
        return;
      }
      final label = DateFormat(
        'dd MMM HH:mm',
        'it_IT',
      ).format(request.newStart);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appuntamento spostato a $label.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante lo spostamento: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRescheduling = false);
      }
    }
  }

  void _openAppointmentForm(
    BuildContext context, {
    required List<Salon> salons,
    required List<Client> clients,
    required List<StaffMember> staff,
    required List<Service> services,
    Appointment? existing,
    DateTime? initialStart,
    DateTime? initialEnd,
    String? initialStaffId,
    String? initialSalonId,
  }) {
    _openForm(
      context,
      ref,
      salons: salons,
      clients: clients,
      staff: staff,
      services: services,
      defaultSalonId: initialSalonId ?? widget.salonId,
      existing: existing,
      initialStart: initialStart,
      initialEnd: initialEnd,
      initialStaffId: initialStaffId,
    );
  }

  static Map<String, String> _buildRoomsIndex(
    List<Salon> salons,
    String? salonFilter,
  ) {
    final index = <String, String>{};
    for (final salon in salons) {
      if (salonFilter != null && salon.id != salonFilter) {
        continue;
      }
      for (final room in salon.rooms) {
        index[room.id] = room.name;
      }
    }
    return index;
  }

  DateTime _rangeStart(DateTime anchor, AppointmentCalendarScope scope) {
    if (scope == AppointmentCalendarScope.day) {
      final date = DateTime(anchor.year, anchor.month, anchor.day);
      return _isWeekdayVisible(date.weekday)
          ? date
          : _findNextVisibleDay(date, 1);
    }
    return _startOfWeek(anchor);
  }

  static DateTime _rangeEnd(DateTime start, AppointmentCalendarScope scope) {
    return scope == AppointmentCalendarScope.day
        ? start.add(const Duration(days: 1))
        : start.add(const Duration(days: 7));
  }

  static String _buildRangeLabel(
    DateTime start,
    DateTime end,
    AppointmentCalendarScope scope,
  ) {
    if (scope == AppointmentCalendarScope.day) {
      return _dayLabel.format(start);
    }
    final endInclusive = end.subtract(const Duration(days: 1));
    final startLabel = _weekStartLabel.format(start);
    final endLabel = _weekStartLabel.format(endInclusive);
    return 'Settimana $startLabel → $endLabel';
  }

  static bool _dateRangesOverlap(
    DateTime start,
    DateTime end,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
  }

  static DateTime _startOfWeek(DateTime date) {
    final base = DateTime(date.year, date.month, date.day);
    final weekday = base.weekday; // Monday = 1
    return base.subtract(Duration(days: weekday - DateTime.monday));
  }

  Color _colorForStatus(BuildContext context, AppointmentStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case AppointmentStatus.scheduled:
        return scheme.primary;
      case AppointmentStatus.confirmed:
        return scheme.secondary;
      case AppointmentStatus.completed:
        return scheme.tertiary;
      case AppointmentStatus.cancelled:
        return scheme.error;
      case AppointmentStatus.noShow:
        return scheme.error.withAlpha(180);
    }
  }
}

class _RangeNavigator extends StatelessWidget {
  const _RangeNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Periodo precedente',
            onPressed: onPrevious,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: theme.textTheme.titleSmall),
          ),
          IconButton(
            tooltip: 'Periodo successivo',
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_ios_rounded),
          ),
        ],
      ),
    );
  }
}

class _ListAppointmentsView extends StatelessWidget {
  const _ListAppointmentsView({
    super.key,
    required this.appointments,
    required this.data,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onEdit,
  });

  final List<Appointment> appointments;
  final AppDataState data;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final ValueChanged<Appointment> onEdit;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return const Center(
        child: Text('Nessun appuntamento pianificato per questo periodo.'),
      );
    }

    final grouped = groupBy<Appointment, DateTime>(
      appointments,
      (appointment) => DateUtils.dateOnly(appointment.start),
    );
    final orderedDates = grouped.keys.toList()..sort((a, b) => a.compareTo(b));
    final dateFormat = DateFormat('EEEE dd MMMM', 'it_IT');

    return ListView(
      padding: const EdgeInsets.all(16),
      children:
          orderedDates
              .map(
                (day) => Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    initiallyExpanded: DateUtils.isSameDay(day, DateTime.now()),
                    title: Text(
                      dateFormat.format(day),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    children:
                        grouped[day]!
                            .map(
                              (appointment) => ListTile(
                                leading: Icon(
                                  Icons.spa_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(_buildTitle(appointment, data)),
                                subtitle: Text(
                                  _buildSubtitle(appointment, data),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${_AppointmentsModuleState._timeLabel.format(appointment.start)} - ${_AppointmentsModuleState._timeLabel.format(appointment.end)}',
                                    ),
                                    const SizedBox(height: 4),
                                    _StatusPill(status: appointment.status),
                                  ],
                                ),
                                onTap: () => onEdit(appointment),
                              ),
                            )
                            .toList(),
                  ),
                ),
              )
              .toList(),
    );
  }

  String _buildTitle(Appointment appointment, AppDataState data) {
    final client =
        data.clients
            .firstWhereOrNull((client) => client.id == appointment.clientId)
            ?.fullName ??
        'Cliente';
    final service =
        data.services
            .firstWhereOrNull((service) => service.id == appointment.serviceId)
            ?.name ??
        'Servizio';
    return '$client • $service';
  }

  String _buildSubtitle(Appointment appointment, AppDataState data) {
    final staff =
        data.staff
            .firstWhereOrNull((member) => member.id == appointment.staffId)
            ?.fullName ??
        'Staff';
    final room =
        data.salons
            .firstWhereOrNull((salon) => salon.id == appointment.salonId)
            ?.rooms
            .firstWhereOrNull((room) => room.id == appointment.roomId)
            ?.name;
    final buffer = StringBuffer(staff);
    if (room != null) {
      buffer.write(' · $room');
    }
    if (appointment.notes != null && appointment.notes!.isNotEmpty) {
      buffer.write('\n${appointment.notes}');
    }
    return buffer.toString();
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  required List<Salon> salons,
  required List<Client> clients,
  required List<StaffMember> staff,
  required List<Service> services,
  String? defaultSalonId,
  Appointment? existing,
  DateTime? initialStart,
  DateTime? initialEnd,
  String? initialStaffId,
}) async {
  if (salons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crea un salone prima di pianificare appuntamenti.'),
      ),
    );
    return;
  }
  final result = await showAppModalSheet<Appointment>(
    context: context,
    builder:
        (ctx) => AppointmentFormSheet(
          salons: salons,
          clients: clients,
          staff: staff,
          services: services,
          defaultSalonId: defaultSalonId,
          initial: existing,
          suggestedStart: initialStart,
          suggestedEnd: initialEnd,
          suggestedStaffId: initialStaffId,
        ),
  );
  if (result != null) {
    final existingAppointments = ref.read(appDataProvider).appointments;
    final hasOverlap = existingAppointments.any((appointment) {
      if (appointment.id == result.id) {
        return false;
      }
      if (appointment.staffId != result.staffId) {
        return false;
      }
      return appointment.start.isBefore(result.end) &&
          appointment.end.isAfter(result.start);
    });
    if (hasOverlap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile salvare: operatore già occupato in quel periodo',
          ),
        ),
      );
      return;
    }
    await ref.read(appDataProvider.notifier).upsertAppointment(result);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color background;
    Color foreground;
    String label;
    switch (status) {
      case AppointmentStatus.scheduled:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        label = 'Programmato';
        break;
      case AppointmentStatus.confirmed:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        label = 'Confermato';
        break;
      case AppointmentStatus.completed:
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        label = 'Completato';
        break;
      case AppointmentStatus.cancelled:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        label = 'Annullato';
        break;
      case AppointmentStatus.noShow:
        background = scheme.error.withValues(alpha: 0.15);
        foreground = scheme.error;
        label = 'No-show';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
