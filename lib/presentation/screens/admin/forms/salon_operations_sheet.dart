import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class SalonOperationsSheet extends StatefulWidget {
  const SalonOperationsSheet({super.key, required this.salon});

  final Salon salon;

  @override
  State<SalonOperationsSheet> createState() => _SalonOperationsSheetState();
}

class _SalonOperationsSheetState extends State<SalonOperationsSheet> {
  static const int _minutesInDay = 24 * 60;
  static const int _defaultOpeningMinutes = 9 * 60;
  static const int _defaultClosingMinutes = 19 * 60;

  final _uuid = const Uuid();
  late SalonStatus _status;
  late List<_ScheduleEntry> _schedule;
  late List<_ClosureFormData> _closures;
  late bool _isPublished;

  @override
  void initState() {
    super.initState();
    _status = widget.salon.status;
    _isPublished = widget.salon.isPublished;

    final scheduleMap = {
      for (final entry in widget.salon.schedule) entry.weekday: entry,
    };
    _schedule = List<_ScheduleEntry>.generate(7, (index) {
      final weekday = DateTime.monday + index;
      final current = scheduleMap[weekday];
      if (current != null && current.isOpen) {
        return _ScheduleEntry(
          weekday: weekday,
          isOpen: true,
          open: _minutesToTimeOfDay(
            current.openMinuteOfDay ?? _defaultOpeningMinutes,
          ),
          close: _minutesToTimeOfDay(
            current.closeMinuteOfDay ?? _defaultClosingMinutes,
          ),
        );
      }
      return _ScheduleEntry(
        weekday: weekday,
        isOpen: false,
        open: const TimeOfDay(hour: 9, minute: 0),
        close: const TimeOfDay(hour: 19, minute: 0),
      );
    });

    _closures = widget.salon.closures
        .map(_ClosureFormData.fromClosure)
        .toList(growable: true);
  }

  @override
  void dispose() {
    for (final closure in _closures) {
      closure.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final schedule = <SalonDailySchedule>[];
    for (final entry in _schedule) {
      final opening = _timeOfDayToMinutes(entry.open);
      final closing = _timeOfDayToMinutes(entry.close);
      if (entry.isOpen && closing <= opening) {
        _showError(
          'L\'orario di chiusura deve essere successivo a quello di apertura per ${_weekdayName(entry.weekday)}.',
        );
        return;
      }
      schedule.add(
        SalonDailySchedule(
          weekday: entry.weekday,
          isOpen: entry.isOpen,
          openMinuteOfDay: entry.isOpen ? opening : null,
          closeMinuteOfDay: entry.isOpen ? closing : null,
        ),
      );
    }

    final closures = <SalonClosure>[];
    for (final closure in _closures) {
      if (closure.end.isBefore(closure.start)) {
        _showError('Le chiusure devono terminare dopo la data di inizio.');
        return;
      }
      closures.add(
        SalonClosure(
          id: closure.id,
          start: closure.start,
          end: closure.end,
          reason:
              closure.reason.text.trim().isEmpty
                  ? null
                  : closure.reason.text.trim(),
        ),
      );
    }

    final updated = widget.salon.copyWith(
      status: _status,
      isPublished: _isPublished,
      schedule: schedule,
      closures: closures,
    );
    Navigator.of(context).pop(updated);
  }

  void _addClosure() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    setState(() {
      _closures.add(_ClosureFormData(id: _uuid.v4(), start: start, end: start));
    });
  }

  void _removeClosure(_ClosureFormData closure) {
    setState(() {
      _closures.remove(closure);
    });
    closure.dispose();
  }

  Future<void> _pickClosureRange(_ClosureFormData closure) async {
    final initialRange = DateTimeRange(start: closure.start, end: closure.end);
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3),
      helpText: 'Seleziona periodo di chiusura',
      saveText: 'Conferma',
    );
    if (result == null) {
      return;
    }

    setState(() {
      closure
        ..start = DateTime(
          result.start.year,
          result.start.month,
          result.start.day,
        )
        ..end = DateTime(
          result.end.year,
          result.end.month,
          result.end.day,
          23,
          59,
          59,
        );
    });
  }

  void _toggleScheduleEntry(_ScheduleEntry entry, bool isOpen) {
    setState(() {
      entry.isOpen = isOpen;
      if (isOpen &&
          _timeOfDayToMinutes(entry.close) <= _timeOfDayToMinutes(entry.open)) {
        final nextMinutes = _clampMinutes(
          _timeOfDayToMinutes(entry.open) + 8 * 60,
        );
        entry.close = _minutesToTimeOfDay(nextMinutes);
      }
    });
  }

  Future<void> _pickScheduleTime(
    _ScheduleEntry entry, {
    required bool isOpening,
  }) async {
    final initial = isOpening ? entry.open : entry.close;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) {
      return;
    }

    if (!isOpening &&
        _timeOfDayToMinutes(picked) <= _timeOfDayToMinutes(entry.open)) {
      _showError(
        'L\'orario di chiusura deve essere successivo a quello di apertura.',
      );
      return;
    }

    setState(() {
      if (isOpening) {
        entry.open = picked;
        if (_timeOfDayToMinutes(entry.close) <=
            _timeOfDayToMinutes(entry.open)) {
          final nextMinutes = _clampMinutes(
            _timeOfDayToMinutes(entry.open) + 60,
          );
          entry.close = _minutesToTimeOfDay(nextMinutes);
        }
      } else {
        entry.close = picked;
      }
    });
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static TimeOfDay _minutesToTimeOfDay(int minutes) {
    final value = _clampMinutes(minutes);
    return TimeOfDay(hour: value ~/ 60, minute: value % 60);
  }

  static int _timeOfDayToMinutes(TimeOfDay time) =>
      time.hour * 60 + time.minute;

  static int _clampMinutes(int minutes) {
    if (minutes < 0) {
      return 0;
    }
    if (minutes >= _minutesInDay) {
      return _minutesInDay - 1;
    }
    return minutes;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyMedium = theme.textTheme.bodyMedium;

    return DialogActionLayout(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Stato operativo', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'Aggiorna lo stato del salone, gestisci i giorni di apertura e pianifica le chiusure straordinarie.',
            style: bodyMedium,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<SalonStatus>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Stato del salone'),
            items:
                SalonStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _status = value);
              }
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _isPublished,
            title: const Text('Pubblica salone'),
            subtitle: const Text(
              'Rendi visibili ai clienti le informazioni principali di questo salone.',
            ),
            onChanged: (value) => setState(() => _isPublished = value),
          ),
          const SizedBox(height: 24),
          Text('Giorni di apertura', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Column(
            children:
                _schedule
                    .map(
                      (entry) => _ScheduleCard(
                        entry: entry,
                        onChanged:
                            (value) => _toggleScheduleEntry(entry, value),
                        onPickOpening:
                            () => _pickScheduleTime(entry, isOpening: true),
                        onPickClosing:
                            () => _pickScheduleTime(entry, isOpening: false),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 24),
          Text('Chiusure straordinarie', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_closures.isEmpty)
            Text(
              'Nessuna chiusura programmata. Aggiungi periodi di chiusura per aggiornare automaticamente disponibilità e prenotazioni.',
              style: bodyMedium,
            ),
          ..._closures.map(
            (closure) => _ClosureCard(
              data: closure,
              onPickRange: () => _pickClosureRange(closure),
              onRemove: () => _removeClosure(closure),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addClosure,
              icon: const Icon(Icons.event_busy_rounded),
              label: const Text('Aggiungi chiusura'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salva')),
      ],
    );
  }
}

const List<String> _weekdayLabels = <String>[
  'Lunedì',
  'Martedì',
  'Mercoledì',
  'Giovedì',
  'Venerdì',
  'Sabato',
  'Domenica',
];

String _weekdayName(int weekday) {
  final index = (weekday - DateTime.monday) % 7;
  final normalized = index < 0 ? index + 7 : index;
  return _weekdayLabels[normalized];
}

class _ScheduleEntry {
  _ScheduleEntry({
    required this.weekday,
    required this.isOpen,
    required this.open,
    required this.close,
  });

  final int weekday;
  bool isOpen;
  TimeOfDay open;
  TimeOfDay close;
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.entry,
    required this.onChanged,
    required this.onPickOpening,
    required this.onPickClosing,
  });

  final _ScheduleEntry entry;
  final ValueChanged<bool> onChanged;
  final VoidCallback onPickOpening;
  final VoidCallback onPickClosing;

  @override
  Widget build(BuildContext context) {
    final timeFormatter = MaterialLocalizations.of(context);
    final openingLabel = timeFormatter.formatTimeOfDay(
      entry.open,
      alwaysUse24HourFormat: true,
    );
    final closingLabel = timeFormatter.formatTimeOfDay(
      entry.close,
      alwaysUse24HourFormat: true,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              value: entry.isOpen,
              onChanged: onChanged,
              title: Text(_weekdayName(entry.weekday)),
              subtitle: Text(
                entry.isOpen
                    ? 'Aperto $openingLabel - $closingLabel'
                    : 'Chiuso',
              ),
            ),
            if (entry.isOpen)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPickOpening,
                        icon: const Icon(Icons.login_rounded),
                        label: Text('Apre alle $openingLabel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPickClosing,
                        icon: const Icon(Icons.logout_rounded),
                        label: Text('Chiude alle $closingLabel'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClosureFormData {
  _ClosureFormData({
    required this.id,
    required this.start,
    required this.end,
    String? reason,
  }) : reason = TextEditingController(text: reason ?? '');

  factory _ClosureFormData.fromClosure(SalonClosure closure) {
    return _ClosureFormData(
      id: closure.id,
      start: closure.start,
      end: closure.end,
      reason: closure.reason,
    );
  }

  final String id;
  DateTime start;
  DateTime end;
  final TextEditingController reason;

  void dispose() {
    reason.dispose();
  }
}

class _ClosureCard extends StatelessWidget {
  const _ClosureCard({
    required this.data,
    required this.onPickRange,
    required this.onRemove,
  });

  final _ClosureFormData data;
  final VoidCallback onPickRange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('dd/MM/yyyy');
    final startLabel = formatter.format(data.start);
    final endLabel = formatter.format(data.end);
    final rangeLabel =
        data.start.year == data.end.year &&
                data.start.month == data.end.month &&
                data.start.day == data.end.day
            ? startLabel
            : '$startLabel → $endLabel';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Periodo di chiusura', style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  tooltip: 'Rimuovi chiusura',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: onPickRange,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(rangeLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.reason,
              decoration: const InputDecoration(
                labelText: 'Motivo della chiusura',
                helperText:
                    'Facoltativo, aiuta a comunicare allo staff le ragioni.',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
