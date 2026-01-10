import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/staff_absence.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class StaffAbsenceRequestFormSheet extends ConsumerStatefulWidget {
  const StaffAbsenceRequestFormSheet({
    super.key,
    required this.staff,
    required this.salonId,
  });

  final StaffMember staff;
  final String salonId;

  @override
  ConsumerState<StaffAbsenceRequestFormSheet> createState() =>
      _StaffAbsenceRequestFormSheetState();
}

class _StaffAbsenceRequestFormSheetState
    extends ConsumerState<StaffAbsenceRequestFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _attachmentController = TextEditingController();

  StaffAbsenceType _type = StaffAbsenceType.vacation;
  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  bool _isAllDay = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day);
    _endDate = DateTime(today.year, today.month, today.day);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy', 'it_IT');
    final timeFormat = DateFormat('HH:mm', 'it_IT');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nuova richiesta', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Staff: ${widget.staff.fullName}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
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
              decoration: const InputDecoration(labelText: 'Tipo richiesta'),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateSelectionTile(
                    label: 'Dal',
                    value: dateFormat.format(_startDate),
                    icon: Icons.event_available_rounded,
                    onTap: _pickStartDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateSelectionTile(
                    label: 'Al',
                    value: dateFormat.format(_endDate),
                    icon: Icons.event_busy_rounded,
                    onTap: _pickEndDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _isAllDay,
              title: const Text('Intera giornata'),
              subtitle: const Text(
                'Disattiva per indicare orario di inizio e fine',
              ),
              onChanged: (value) {
                setState(() {
                  _isAllDay = value;
                  _ensureValidTimes();
                });
              },
            ),
            if (!_isAllDay) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateSelectionTile(
                      label: 'Ora inizio',
                      value: timeFormat.format(
                        DateTime(
                          2000,
                          1,
                          1,
                          _startTime.hour,
                          _startTime.minute,
                        ),
                      ),
                      icon: Icons.access_time_rounded,
                      onTap: _pickStartTime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateSelectionTile(
                      label: 'Ora fine',
                      value: timeFormat.format(
                        DateTime(
                          2000,
                          1,
                          1,
                          _endTime.hour,
                          _endTime.minute,
                        ),
                      ),
                      icon: Icons.more_time_rounded,
                      onTap: _pickEndTime,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Note (opzionale)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _attachmentController,
              decoration: const InputDecoration(
                labelText: 'Allegato (URL opzionale)',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Invia richiesta'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await _pickDate(_startDate);
    if (picked == null) {
      return;
    }
    setState(() {
      _startDate = picked;
      if (_endDate.isBefore(_startDate)) {
        _endDate = picked;
      }
      _ensureValidTimes();
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await _pickDate(_endDate);
    if (picked == null) {
      return;
    }
    setState(() {
      _endDate = picked;
      if (_endDate.isBefore(_startDate)) {
        _startDate = picked;
      }
      _ensureValidTimes();
    });
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    ).then(
      (picked) =>
          picked == null
              ? null
              : DateTime(picked.year, picked.month, picked.day),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _startTime = picked;
      _ensureValidTimes();
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _endTime = picked;
      _ensureValidTimes();
    });
  }

  void _ensureValidTimes() {
    if (_isAllDay) {
      return;
    }
    if (!_isSameDay(_startDate, _endDate)) {
      return;
    }
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (endMinutes <= startMinutes) {
      final adjusted = (startMinutes + 120).clamp(0, 23 * 60 + 59);
      _endTime = TimeOfDay(
        hour: adjusted ~/ 60,
        minute: adjusted % 60,
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final start = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _isAllDay ? 0 : _startTime.hour,
        _isAllDay ? 0 : _startTime.minute,
      );
      final end = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _isAllDay ? 23 : _endTime.hour,
        _isAllDay ? 59 : _endTime.minute,
      );
      if (end.isBefore(start)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La data/ora di fine deve essere successiva.'),
          ),
        );
        return;
      }
      await ref.read(appDataProvider.notifier).submitStaffAbsenceRequest(
            salonId: widget.salonId,
            staffId: widget.staff.id,
            type: _type,
            start: start,
            end: end,
            notes: _notesController.text,
            attachmentUrl: _attachmentController.text,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Richiesta inviata.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'invio: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}

class _DateSelectionTile extends StatelessWidget {
  const _DateSelectionTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
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
