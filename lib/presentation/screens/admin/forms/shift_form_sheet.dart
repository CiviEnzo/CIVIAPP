import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/shift.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class ShiftFormResult {
  const ShiftFormResult({required this.shifts});

  final List<Shift> shifts;

  bool get isSeries => shifts.length > 1;
}

class ShiftFormSheet extends StatefulWidget {
  const ShiftFormSheet({
    super.key,
    required this.salons,
    required this.staff,
    this.initial,
    this.defaultSalonId,
    this.defaultStaffId,
  });

  final List<Salon> salons;
  final List<StaffMember> staff;
  final Shift? initial;
  final String? defaultSalonId;
  final String? defaultStaffId;

  @override
  State<ShiftFormSheet> createState() => _ShiftFormSheetState();
}

class _ShiftFormSheetState extends State<ShiftFormSheet> {
  static const List<int> _weekdayOrder = <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];
  static final DateFormat _weekdayFormatter = DateFormat('EEE', 'it_IT');
  static const List<ShiftRecurrenceFrequency> _availableFrequencies =
      <ShiftRecurrenceFrequency>[
        ShiftRecurrenceFrequency.daily,
        ShiftRecurrenceFrequency.weekly,
      ];

  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _notes = TextEditingController();

  late DateTime _start;
  late DateTime _end;
  String? _salonId;
  String? _staffId;
  String? _roomId;

  bool _hasBreak = false;
  DateTime? _breakStart;
  DateTime? _breakEnd;

  ShiftRecurrenceFrequency? _recurrenceFrequency;
  int _recurrenceInterval = 1;
  int _recurrenceMonths = 1;
  late Set<int> _recurrenceWeekdays;
  int _weeklyActiveWeeks = 1;
  int _weeklyBreakWeeks = 0;

  bool get _isEditing => widget.initial != null;
  bool get _canConfigureRecurrence => !_isEditing;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _staffId = initial?.staffId ?? widget.defaultStaffId;
    final now = DateTime.now();
    _start = initial?.start ?? DateTime(now.year, now.month, now.day, 9, 0);
    _end = initial?.end ?? _start.add(const Duration(hours: 6));
    _roomId = initial?.roomId;
    _notes.text = initial?.notes ?? '';

    final recurrence = initial?.recurrence;
    final existingWeekdays = recurrence?.weekdays;
    if (existingWeekdays != null && existingWeekdays.isNotEmpty) {
      _recurrenceWeekdays = existingWeekdays.toSet();
    } else {
      _recurrenceWeekdays = {_start.weekday};
    }

    if (initial?.breakStart != null && initial?.breakEnd != null) {
      _hasBreak = true;
      _breakStart = initial!.breakStart;
      _breakEnd = initial.breakEnd;
    }

    if (recurrence != null) {
      _recurrenceFrequency = recurrence.frequency;
      if (recurrence.frequency == ShiftRecurrenceFrequency.weekly) {
        _weeklyActiveWeeks = _clampWeekCount(
          recurrence.activeWeeks ?? 1,
          min: 1,
        );
        final computedBreak =
            recurrence.inactiveWeeks ??
            (recurrence.interval - _weeklyActiveWeeks);
        _weeklyBreakWeeks = _clampWeekCount(computedBreak);
        _recurrenceInterval = _clampWeekCount(
          _weeklyActiveWeeks + _weeklyBreakWeeks,
          min: 1,
        );
      } else {
        _recurrenceInterval = recurrence.interval;
      }
    }

    _ensureWeekdaySelection();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDefaults();
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('dd MMM yyyy HH:mm', 'it_IT');
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    final filteredStaff =
        widget.staff
            .where((member) => _salonId == null || member.salonId == _salonId)
            .toList();
    final rooms = _availableRooms();

    final recurrenceItems = <DropdownMenuItem<ShiftRecurrenceFrequency?>>[
      const DropdownMenuItem<ShiftRecurrenceFrequency?>(
        value: null,
        child: Text('Nessuna ripetizione'),
      ),
      ..._availableFrequencies.map(
        (frequency) => DropdownMenuItem<ShiftRecurrenceFrequency?>(
          value: frequency,
          child: Text(_labelForFrequency(frequency)),
        ),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing ? 'Modifica turno' : 'Nuovo turno',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _salonId,
              items:
                  widget.salons
                      .map(
                        (salon) => DropdownMenuItem(
                          value: salon.id,
                          child: Text(salon.name),
                        ),
                      )
                      .toList(),
              decoration: const InputDecoration(labelText: 'Salone'),
              onChanged: (value) {
                setState(() {
                  _salonId = value;
                  _staffId = null;
                  _roomId = null;
                  _ensureWeekdaySelection();
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _staffId,
              items:
                  filteredStaff
                      .map(
                        (member) => DropdownMenuItem(
                          value: member.id,
                          child: Text(member.fullName),
                        ),
                      )
                      .toList(),
              decoration: const InputDecoration(labelText: 'Operatore'),
              validator:
                  (value) => value == null ? 'Seleziona un operatore' : null,
              onChanged: (value) => setState(() => _staffId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _roomId,
              items:
                  rooms
                      .map(
                        (room) => DropdownMenuItem(
                          value: room.id,
                          child: Text(room.name),
                        ),
                      )
                      .toList(),
              decoration: const InputDecoration(labelText: 'Cabina / stanza'),
              validator:
                  (value) => value == null ? 'Seleziona una stanza' : null,
              onChanged: (value) => setState(() => _roomId = value),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data di inizio'),
              subtitle: Text(dateFormat.format(_start)),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: _pickStartDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ora di inizio'),
              subtitle: Text(timeFormat.format(_start)),
              trailing: const Icon(Icons.schedule_rounded),
              onTap: _pickStartTime,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data di fine'),
              subtitle: Text(dateFormat.format(_end)),
              trailing: const Icon(Icons.event),
              onTap: _pickEndDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ora di fine'),
              subtitle: Text(timeFormat.format(_end)),
              trailing: const Icon(Icons.schedule),
              onTap: _pickEndTime,
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _hasBreak,
              title: const Text('Pausa programmata'),
              subtitle: const Text(
                'Specifica un intervallo di pausa durante il turno',
              ),
              onChanged: (value) {
                setState(() {
                  _hasBreak = value;
                  if (value) {
                    _setDefaultBreak();
                  } else {
                    _breakStart = null;
                    _breakEnd = null;
                  }
                });
              },
            ),
            if (_hasBreak) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Inizio pausa'),
                subtitle: Text(
                  _breakStart != null
                      ? timeFormat.format(_breakStart!)
                      : 'Seleziona orario',
                ),
                trailing: const Icon(Icons.free_breakfast),
                onTap: _pickBreakStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fine pausa'),
                subtitle: Text(
                  _breakEnd != null
                      ? timeFormat.format(_breakEnd!)
                      : 'Seleziona orario',
                ),
                trailing: const Icon(Icons.emoji_food_beverage),
                onTap: _pickBreakEnd,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (facoltative)',
              ),
            ),
            if (_canConfigureRecurrence) ...[
              const SizedBox(height: 24),
              Text(
                'Ripetizione',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ShiftRecurrenceFrequency?>(
                value: _recurrenceFrequency,
                items: recurrenceItems,
                decoration: const InputDecoration(labelText: 'Frequenza'),
                onChanged: (value) {
                  setState(() {
                    _recurrenceFrequency = value;
                    if (value == null) {
                      _recurrenceInterval = 1;
                      _recurrenceMonths = 1;
                      return;
                    }
                    if (value != ShiftRecurrenceFrequency.weekly) {
                      _recurrenceInterval = 1;
                      _weeklyActiveWeeks = 1;
                      _weeklyBreakWeeks = 0;
                    }
                    if (value == ShiftRecurrenceFrequency.weekly) {
                      _recurrenceInterval = _clampWeekCount(
                        _weeklyActiveWeeks + _weeklyBreakWeeks,
                        min: 1,
                      );
                      _ensureWeekdaySelection();
                    }
                  });
                },
              ),
              if (_recurrenceFrequency == ShiftRecurrenceFrequency.weekly) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _weeklyActiveWeeks,
                        decoration: const InputDecoration(
                          labelText: 'Settimane attive',
                        ),
                        items: List<DropdownMenuItem<int>>.generate(6, (index) {
                          final value = index + 1;
                          return DropdownMenuItem(
                            value: value,
                            child: Text('$value'),
                          );
                        }),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _weeklyActiveWeeks = value;
                            _recurrenceInterval = _clampWeekCount(
                              _weeklyActiveWeeks + _weeklyBreakWeeks,
                              min: 1,
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _weeklyBreakWeeks,
                        decoration: const InputDecoration(
                          labelText: 'Settimane di pausa',
                        ),
                        items: List<DropdownMenuItem<int>>.generate(
                          6,
                          (index) => DropdownMenuItem(
                            value: index,
                            child: Text(index == 0 ? 'Nessuna' : '$index'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _weeklyBreakWeeks = value;
                            _recurrenceInterval = _clampWeekCount(
                              _weeklyActiveWeeks + _weeklyBreakWeeks,
                              min: 1,
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Giorni della settimana',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final allowedWeekdays = _allowedWeekdays();
                    final selectableWeekdays =
                        _weekdayOrder
                            .where(
                              (weekday) =>
                                  allowedWeekdays.contains(weekday) ||
                                  _recurrenceWeekdays.contains(weekday),
                            )
                            .toList();
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          selectableWeekdays.map((weekday) {
                            final label = _weekdayLabel(weekday);
                            final isSelected = _recurrenceWeekdays.contains(
                              weekday,
                            );
                            final isAllowed = allowedWeekdays.contains(weekday);
                            final canToggle = isAllowed || isSelected;
                            return FilterChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected:
                                  canToggle
                                      ? (selected) {
                                        setState(() {
                                          if (selected && isAllowed) {
                                            _recurrenceWeekdays.add(weekday);
                                          } else {
                                            _recurrenceWeekdays.remove(weekday);
                                          }
                                        });
                                      }
                                      : null,
                            );
                          }).toList(),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Seleziona i giorni in cui il turno verrà ripetuto. '
                    'Puoi scegliere solo i giorni in cui il centro è aperto.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          _recurrenceWeekdays.isEmpty
                              ? Theme.of(context).colorScheme.error
                              : null,
                    ),
                  ),
                ),
              ],
              if (_recurrenceFrequency != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _recurrenceMonths,
                  decoration: const InputDecoration(
                    labelText: 'Durata ripetizione (mesi)',
                  ),
                  items: List<DropdownMenuItem<int>>.generate(12, (index) {
                    final value = index + 1;
                    final label = value == 1 ? '1 mese' : '$value mesi';
                    return DropdownMenuItem(value: value, child: Text(label));
                  }),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _recurrenceMonths = _clampMonthCount(value);
                    });
                  },
                ),
                Text(
                  'I turni saranno generati per il numero di mesi selezionato.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Salva modifiche' : 'Salva turno'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final initialDate = DateTime(_start.year, _start.month, _start.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('it', 'IT'),
    );
    if (picked == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final updated = DateTime(
      picked.year,
      picked.month,
      picked.day,
      _start.hour,
      _start.minute,
    );
    _updateStart(updated);
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final updated = DateTime(
      _start.year,
      _start.month,
      _start.day,
      time.hour,
      time.minute,
    );
    _updateStart(updated);
  }

  Future<void> _pickEndDate() async {
    final initialDate = DateTime(_end.year, _end.month, _end.day);
    final firstDate = DateTime(_start.year, _start.month, _start.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('it', 'IT'),
    );
    if (picked == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final updated = DateTime(
      picked.year,
      picked.month,
      picked.day,
      _end.hour,
      _end.minute,
    );
    _updateEnd(updated);
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end),
    );
    if (time == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final updated = DateTime(
      _end.year,
      _end.month,
      _end.day,
      time.hour,
      time.minute,
    );
    _updateEnd(updated);
  }

  Future<void> _pickBreakStart() async {
    final initial = _breakStart ?? _start.add(const Duration(hours: 3));
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }
    final candidate = DateTime(
      _start.year,
      _start.month,
      _start.day,
      time.hour,
      time.minute,
    );
    if (!candidate.isAfter(_start) || !candidate.isBefore(_end)) {
      _showError('La pausa deve essere all\'interno del turno.');
      return;
    }
    setState(() {
      _breakStart = candidate;
      if (_breakEnd == null || !_breakEnd!.isAfter(_breakStart!)) {
        _breakEnd = _breakStart!.add(const Duration(minutes: 30));
      }
      _ensureBreakWithinShift();
    });
  }

  Future<void> _pickBreakEnd() async {
    final fallback =
        _breakEnd ??
        (_breakStart ?? _start.add(const Duration(hours: 3))).add(
          const Duration(minutes: 30),
        );
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(fallback),
    );
    if (time == null) {
      return;
    }
    final candidate = DateTime(
      _start.year,
      _start.month,
      _start.day,
      time.hour,
      time.minute,
    );
    if (_breakStart == null ||
        !candidate.isAfter(_breakStart!) ||
        !candidate.isBefore(_end)) {
      _showError(
        'La fine della pausa deve essere successiva al suo inizio e prima della fine turno.',
      );
      return;
    }
    setState(() {
      _breakEnd = candidate;
      _ensureBreakWithinShift();
    });
  }

  void _updateStart(DateTime newStart) {
    setState(() {
      final previousStart = _start;
      _start = newStart;
      if (!_end.isAfter(_start)) {
        _end = _start.add(const Duration(hours: 4));
      }
      _adjustBreakForNewStart(previousStart: previousStart);
      _ensureBreakWithinShift();
      _ensureWeekdaySelection();
    });
  }

  void _updateEnd(DateTime newEnd) {
    setState(() {
      _end =
          newEnd.isAfter(_start)
              ? newEnd
              : _start.add(const Duration(hours: 2));
      _ensureBreakWithinShift();
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final salonId = _salonId;
    final staffId = _staffId;
    final roomId = _roomId;
    if (salonId == null || staffId == null || roomId == null) {
      _showError('Completa tutti i campi obbligatori.');
      return;
    }

    final shiftDuration = _end.difference(_start);
    if (shiftDuration.inMinutes <= 0) {
      _showError('L\'orario di fine deve essere successivo all\'inizio.');
      return;
    }

    DateTime? breakStart = _hasBreak ? _breakStart : null;
    DateTime? breakEnd = _hasBreak ? _breakEnd : null;
    if (_hasBreak) {
      if (breakStart == null || breakEnd == null) {
        _showError('Imposta inizio e fine della pausa.');
        return;
      }
      if (!breakStart.isAfter(_start) ||
          !breakEnd.isAfter(breakStart) ||
          !breakEnd.isBefore(_end)) {
        _showError(
          'La pausa deve essere compresa nel turno e avere durata positiva.',
        );
        return;
      }
    }

    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();

    if (_recurrenceFrequency == ShiftRecurrenceFrequency.weekly) {
      _ensureWeekdaySelection(rebuildIfChanged: true);
      if (_recurrenceWeekdays.isEmpty) {
        _showError(
          'Seleziona almeno un giorno della settimana in cui il centro è aperto.',
        );
        return;
      }
    }

    if (_isEditing) {
      final initial = widget.initial!;
      final updated = Shift(
        id: initial.id,
        salonId: salonId,
        staffId: staffId,
        start: _start,
        end: _end,
        roomId: roomId,
        notes: notes,
        breakStart: breakStart,
        breakEnd: breakEnd,
        seriesId: initial.seriesId,
        recurrence: initial.recurrence,
      );
      Navigator.of(context).pop(ShiftFormResult(shifts: [updated]));
      return;
    }

    ShiftRecurrence? recurrence;
    String? seriesId;
    if (_recurrenceFrequency != null) {
      final normalizedUntil = _computeRecurrenceUntil();
      if (!normalizedUntil.isAfter(_start)) {
        _showError(
          'Il periodo di ripetizione deve essere successivo all\'inizio del turno.',
        );
        return;
      }
      final isWeekly = _recurrenceFrequency == ShiftRecurrenceFrequency.weekly;
      final interval =
          isWeekly
              ? _clampWeekCount(_weeklyActiveWeeks + _weeklyBreakWeeks, min: 1)
              : _recurrenceInterval;
      final selectedWeekdays =
          isWeekly ? (_recurrenceWeekdays.toList()..sort()) : null;
      recurrence = ShiftRecurrence(
        frequency: _recurrenceFrequency!,
        interval: interval,
        until: normalizedUntil,
        weekdays:
            selectedWeekdays != null
                ? List<int>.unmodifiable(selectedWeekdays)
                : null,
        activeWeeks: isWeekly ? _weeklyActiveWeeks : null,
        inactiveWeeks: isWeekly ? _weeklyBreakWeeks : null,
      );
      seriesId = _uuid.v4();
    }

    final breakStartOffset = breakStart?.difference(_start);
    final breakEndOffset = breakEnd?.difference(_start);

    final shifts = _generateOccurrences(
      salonId: salonId,
      staffId: staffId,
      roomId: roomId,
      notes: notes,
      duration: shiftDuration,
      breakStartOffset: breakStartOffset,
      breakEndOffset: breakEndOffset,
      recurrence: recurrence,
      seriesId: seriesId,
    );

    Navigator.of(context).pop(ShiftFormResult(shifts: shifts));
  }

  List<Shift> _generateOccurrences({
    required String salonId,
    required String staffId,
    required String roomId,
    required Duration duration,
    required Duration? breakStartOffset,
    required Duration? breakEndOffset,
    required ShiftRecurrence? recurrence,
    required String? seriesId,
    String? notes,
  }) {
    if (recurrence != null &&
        recurrence.frequency == ShiftRecurrenceFrequency.weekly &&
        (recurrence.weekdays?.isNotEmpty ?? false)) {
      return _generateWeeklyOccurrences(
        salonId: salonId,
        staffId: staffId,
        roomId: roomId,
        duration: duration,
        breakStartOffset: breakStartOffset,
        breakEndOffset: breakEndOffset,
        recurrence: recurrence,
        weekdays: recurrence.weekdays!,
        seriesId: seriesId,
        notes: notes,
      );
    }

    final occurrences = <Shift>[];
    var currentStart = _start;
    final until = recurrence?.until;

    while (true) {
      final currentEnd = currentStart.add(duration);
      final currentBreakStart =
          breakStartOffset != null ? currentStart.add(breakStartOffset) : null;
      final currentBreakEnd =
          breakEndOffset != null ? currentStart.add(breakEndOffset) : null;

      final isDailyRecurrence =
          recurrence?.frequency == ShiftRecurrenceFrequency.daily;
      final isSalonOpen =
          !isDailyRecurrence || _isSalonOpenOn(currentStart.weekday);

      if (isSalonOpen) {
        occurrences.add(
          Shift(
            id: _uuid.v4(),
            salonId: salonId,
            staffId: staffId,
            start: currentStart,
            end: currentEnd,
            roomId: roomId,
            notes: notes,
            breakStart: currentBreakStart,
            breakEnd: currentBreakEnd,
            seriesId: seriesId,
            recurrence: recurrence,
          ),
        );
      }

      if (recurrence == null) {
        break;
      }
      final nextStart = _advanceDate(currentStart, recurrence);
      if (until != null && nextStart.isAfter(until)) {
        break;
      }
      currentStart = nextStart;
    }

    return occurrences;
  }

  bool _isSalonOpenOn(int weekday) {
    final allowed = _allowedWeekdays();
    return allowed.contains(weekday);
  }

  List<Shift> _generateWeeklyOccurrences({
    required String salonId,
    required String staffId,
    required String roomId,
    required Duration duration,
    required Duration? breakStartOffset,
    required Duration? breakEndOffset,
    required ShiftRecurrence recurrence,
    required List<int> weekdays,
    required String? seriesId,
    String? notes,
  }) {
    final occurrences = <Shift>[];
    final sortedWeekdays = weekdays.toSet().toList()..sort();
    final until = recurrence.until;
    final activeWeeks = _clampWeekCount(recurrence.activeWeeks ?? 1, min: 1);
    final breakWeeks = _clampWeekCount(
      recurrence.inactiveWeeks ?? (recurrence.interval - activeWeeks),
    );
    final cycleWeeks = _clampWeekCount(activeWeeks + breakWeeks, min: 1);
    var cycleWeekStart = _startOfWeek(_start);

    while (!cycleWeekStart.isAfter(until)) {
      for (var weekOffset = 0; weekOffset < activeWeeks; weekOffset++) {
        final weekStart = _addDays(cycleWeekStart, 7 * weekOffset);
        if (weekStart.isAfter(until)) {
          return occurrences;
        }
        for (final weekday in sortedWeekdays) {
          final candidateDay = _addDays(weekStart, weekday - DateTime.monday);
          final candidateStart = DateTime(
            candidateDay.year,
            candidateDay.month,
            candidateDay.day,
            _start.hour,
            _start.minute,
          );
          if (candidateStart.isBefore(_start)) {
            continue;
          }
          if (candidateStart.isAfter(until)) {
            return occurrences;
          }
          final candidateEnd = candidateStart.add(duration);
          final candidateBreakStart =
              breakStartOffset != null
                  ? candidateStart.add(breakStartOffset)
                  : null;
          final candidateBreakEnd =
              breakEndOffset != null
                  ? candidateStart.add(breakEndOffset)
                  : null;

          occurrences.add(
            Shift(
              id: _uuid.v4(),
              salonId: salonId,
              staffId: staffId,
              start: candidateStart,
              end: candidateEnd,
              roomId: roomId,
              notes: notes,
              breakStart: candidateBreakStart,
              breakEnd: candidateBreakEnd,
              seriesId: seriesId,
              recurrence: recurrence,
            ),
          );
        }
      }
      cycleWeekStart = _addDays(cycleWeekStart, 7 * cycleWeeks);
    }

    return occurrences;
  }

  DateTime _advanceDate(DateTime date, ShiftRecurrence recurrence) {
    switch (recurrence.frequency) {
      case ShiftRecurrenceFrequency.daily:
        return DateTime(
          date.year,
          date.month,
          date.day + recurrence.interval,
          date.hour,
          date.minute,
          date.second,
          date.millisecond,
          date.microsecond,
        );
      case ShiftRecurrenceFrequency.weekly:
        return DateTime(
          date.year,
          date.month,
          date.day + 7 * recurrence.interval,
          date.hour,
          date.minute,
          date.second,
          date.millisecond,
          date.microsecond,
        );
      case ShiftRecurrenceFrequency.monthly:
        return DateTime(
          date.year,
          date.month + recurrence.interval,
          date.day,
          date.hour,
          date.minute,
        );
      case ShiftRecurrenceFrequency.yearly:
        return DateTime(
          date.year + recurrence.interval,
          date.month,
          date.day,
          date.hour,
          date.minute,
        );
    }
  }

  DateTime _startOfWeek(DateTime date) {
    final difference = date.weekday - DateTime.monday;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: difference < 0 ? 0 : difference));
  }

  DateTime _addDays(DateTime date, int days) {
    // Build a new instance from date components to avoid DST drift when adding days.
    return DateTime(date.year, date.month, date.day + days);
  }

  String _weekdayLabel(int weekday) {
    final reference = DateTime(
      2024,
      1,
      1,
    ).add(Duration(days: weekday - DateTime.monday));
    final label = _weekdayFormatter.format(reference);
    if (label.isEmpty) {
      return label;
    }
    return label[0].toUpperCase() + label.substring(1);
  }

  List<SalonRoom> _availableRooms() {
    final selectedSalon = widget.salons.firstWhereOrNull(
      (salon) => salon.id == _salonId,
    );
    return selectedSalon?.rooms ?? const [];
  }

  Set<int> _allowedWeekdays() {
    final selectedSalon = widget.salons.firstWhereOrNull(
      (salon) => salon.id == _salonId,
    );
    final schedule = selectedSalon?.schedule;
    if (schedule == null || schedule.isEmpty) {
      return _weekdayOrder.toSet();
    }
    final openDays =
        schedule
            .where((daily) => daily.isOpen)
            .map((daily) => daily.weekday)
            .where(
              (weekday) =>
                  weekday >= DateTime.monday && weekday <= DateTime.sunday,
            )
            .toSet();
    return openDays.isEmpty ? _weekdayOrder.toSet() : openDays;
  }

  void _ensureDefaults() {
    final filteredStaff =
        widget.staff
            .where((member) => _salonId == null || member.salonId == _salonId)
            .toList();
    if (_staffId == null && filteredStaff.isNotEmpty) {
      setState(() {
        _staffId = filteredStaff.first.id;
      });
    }
    final rooms = _availableRooms();
    if (_roomId == null && rooms.isNotEmpty) {
      setState(() {
        _roomId = rooms.first.id;
      });
    }
    _ensureWeekdaySelection(rebuildIfChanged: true);
  }

  void _ensureWeekdaySelection({bool rebuildIfChanged = false}) {
    final allowed = _allowedWeekdays();
    final previous = Set<int>.from(_recurrenceWeekdays);
    _recurrenceWeekdays.removeWhere((weekday) => !allowed.contains(weekday));
    if (_recurrenceWeekdays.isEmpty && allowed.isNotEmpty) {
      final fallback =
          allowed.contains(_start.weekday)
              ? _start.weekday
              : _weekdayOrder.firstWhere(
                allowed.contains,
                orElse: () => allowed.first,
              );
      _recurrenceWeekdays.add(fallback);
    }
    final hasChanged =
        !const SetEquality<int>().equals(previous, _recurrenceWeekdays);
    if (hasChanged && rebuildIfChanged && mounted) {
      setState(() {});
    }
  }

  void _adjustBreakForNewStart({required DateTime previousStart}) {
    if (!_hasBreak || _breakStart == null || _breakEnd == null) {
      return;
    }
    final startOffset = _breakStart!.difference(previousStart);
    final endOffset = _breakEnd!.difference(previousStart);
    _breakStart = _start.add(startOffset);
    _breakEnd = _start.add(endOffset);
  }

  void _ensureBreakWithinShift() {
    if (!_hasBreak || _breakStart == null || _breakEnd == null) {
      return;
    }
    if (!_breakStart!.isAfter(_start)) {
      _breakStart = _start.add(const Duration(hours: 1));
    }
    if (!_breakEnd!.isAfter(_breakStart!)) {
      _breakEnd = _breakStart!.add(const Duration(minutes: 30));
    }
    if (!_breakEnd!.isBefore(_end)) {
      _breakEnd = _end.subtract(const Duration(minutes: 30));
    }
    if (!_breakEnd!.isAfter(_breakStart!)) {
      final midPoint = _start.add(_end.difference(_start) ~/ 2);
      _breakStart = midPoint.subtract(const Duration(minutes: 15));
      _breakEnd = midPoint.add(const Duration(minutes: 15));
    }
  }

  void _setDefaultBreak() {
    final duration = _end.difference(_start);
    final midPoint = _start.add(duration ~/ 2);
    _breakStart = midPoint.subtract(const Duration(minutes: 20));
    _breakEnd = midPoint.add(const Duration(minutes: 20));
    _ensureBreakWithinShift();
  }

  DateTime _computeRecurrenceUntil() {
    final months = _clampMonthCount(_recurrenceMonths);
    return DateTime(
      _start.year,
      _start.month + months,
      _start.day,
      _start.hour,
      _start.minute,
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int _clampWeekCount(int value, {int min = 0, int max = 52}) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  int _clampMonthCount(int value, {int min = 1, int max = 12}) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  static String _labelForFrequency(ShiftRecurrenceFrequency frequency) {
    switch (frequency) {
      case ShiftRecurrenceFrequency.daily:
        return 'Giornaliera';
      case ShiftRecurrenceFrequency.weekly:
        return 'Settimanale';
      case ShiftRecurrenceFrequency.monthly:
        return 'Mensile';
      case ShiftRecurrenceFrequency.yearly:
        return 'Annuale';
    }
  }
}
