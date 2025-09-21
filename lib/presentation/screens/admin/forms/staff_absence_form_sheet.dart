import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/staff_absence.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class StaffAbsenceFormSheet extends StatefulWidget {
  const StaffAbsenceFormSheet({
    super.key,
    required this.salons,
    required this.staff,
    this.initial,
    this.defaultSalonId,
    this.defaultStaffId,
  });

  final List<Salon> salons;
  final List<StaffMember> staff;
  final StaffAbsence? initial;
  final String? defaultSalonId;
  final String? defaultStaffId;

  @override
  State<StaffAbsenceFormSheet> createState() => _StaffAbsenceFormSheetState();
}

class _StaffAbsenceFormSheetState extends State<StaffAbsenceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _uuid = const Uuid();

  String? _salonId;
  String? _staffId;
  StaffAbsenceType _type = StaffAbsenceType.sickLeave;
  late DateTime _start;
  late DateTime _end;
  bool _isAllDay = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _staffId = initial?.staffId ?? widget.defaultStaffId;
    _type = initial?.type ?? StaffAbsenceType.sickLeave;
    final today = DateTime.now();
    _start = initial?.start ?? DateTime(today.year, today.month, today.day);
    _end = initial?.end ?? DateTime(today.year, today.month, today.day, 23, 59);
    _notes.text = initial?.notes ?? '';
    _isAllDay = initial?.isAllDay ?? true;
    if (_isAllDay) {
      _start = DateTime(_start.year, _start.month, _start.day);
      _end = DateTime(_end.year, _end.month, _end.day, 23, 59);
    } else if (!_end.isAfter(_start)) {
      _end = _start.add(const Duration(hours: 2));
    }

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
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    final filteredStaff =
        widget.staff
            .where((member) => _salonId == null || member.salonId == _salonId)
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null ? 'Nuova assenza' : 'Modifica assenza',
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
            DropdownButtonFormField<StaffAbsenceType>(
              value: _type,
              items:
                  StaffAbsenceType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
              decoration: const InputDecoration(labelText: 'Motivo'),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dal'),
              subtitle: Text(dateFormat.format(_start)),
              trailing: const Icon(Icons.event_available_rounded),
              onTap: _pickStart,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Al'),
              subtitle: Text(dateFormat.format(_end)),
              trailing: const Icon(Icons.event_busy_rounded),
              onTap: _pickEnd,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isAllDay,
              title: const Text('Assenza per l\'intera giornata'),
              subtitle: const Text(
                'Disattiva per impostare un orario specifico',
              ),
              onChanged: _toggleAllDay,
            ),
            if (!_isAllDay) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ora di inizio'),
                subtitle: Text(timeFormat.format(_start)),
                trailing: const Icon(Icons.schedule_rounded),
                onTap: _pickStartTime,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ora di fine'),
                subtitle: Text(timeFormat.format(_end)),
                trailing: const Icon(Icons.schedule),
                onTap: _pickEndTime,
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
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Salva assenza'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      setState(() {
        if (_isAllDay) {
          _start = DateTime(picked.year, picked.month, picked.day);
          if (_end.isBefore(_start)) {
            _end = DateTime(picked.year, picked.month, picked.day, 23, 59);
          }
        } else {
          final candidateStart = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _start.hour,
            _start.minute,
          );
          _start = candidateStart;
          final candidateEnd = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _end.hour,
            _end.minute,
          );
          _end =
              candidateEnd.isAfter(_start)
                  ? candidateEnd
                  : _start.add(const Duration(hours: 1));
        }
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('it', 'IT'),
    );
    if (picked == null) {
      return;
    }
    if (_isAllDay) {
      setState(() {
        _end = DateTime(picked.year, picked.month, picked.day, 23, 59);
      });
      return;
    }

    final candidate = DateTime(
      picked.year,
      picked.month,
      picked.day,
      _end.hour,
      _end.minute,
    );
    if (!candidate.isAfter(_start)) {
      _showError('La fine deve essere successiva all\'inizio.');
      return;
    }
    setState(() {
      _end = candidate;
    });
  }

  void _toggleAllDay(bool value) {
    setState(() {
      _isAllDay = value;
      if (_isAllDay) {
        _start = DateTime(_start.year, _start.month, _start.day);
        _end = DateTime(_end.year, _end.month, _end.day, 23, 59);
      } else {
        final base = DateTime(_start.year, _start.month, _start.day, 9, 0);
        _start = base;
        _end = base.add(const Duration(hours: 2));
      }
    });
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _start = DateTime(
        _start.year,
        _start.month,
        _start.day,
        time.hour,
        time.minute,
      );
      if (!_end.isAfter(_start)) {
        _end = _start.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _end.isAfter(_start) ? _end : _start.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) {
      return;
    }
    final candidate = DateTime(
      _end.year,
      _end.month,
      _end.day,
      time.hour,
      time.minute,
    );
    if (!candidate.isAfter(_start)) {
      _showError(
        'L\'orario di fine deve essere successivo a quello di inizio.',
      );
      return;
    }
    setState(() {
      _end = candidate;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final salonId = _salonId;
    final staffId = _staffId;
    if (salonId == null || staffId == null) {
      _showError('Completa tutti i campi obbligatori.');
      return;
    }
    if (_end.isBefore(_start)) {
      _showError('La data di fine deve essere successiva a quella di inizio.');
      return;
    }

    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final absence = StaffAbsence(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: salonId,
      staffId: staffId,
      type: _type,
      start: _start,
      end: _end,
      notes: notes,
    );
    Navigator.of(context).pop(absence);
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
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
