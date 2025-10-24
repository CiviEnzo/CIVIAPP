import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShiftBulkDeleteSheet extends StatefulWidget {
  const ShiftBulkDeleteSheet({
    super.key,
    required this.shifts,
    required this.staff,
    required this.roomNames,
  });

  final List<Shift> shifts;
  final StaffMember staff;
  final Map<String, String> roomNames;

  @override
  State<ShiftBulkDeleteSheet> createState() => _ShiftBulkDeleteSheetState();
}

class _ShiftBulkDeleteSheetState extends State<ShiftBulkDeleteSheet> {
  static final DateFormat _dayLabel = DateFormat('EEE dd MMM', 'it_IT');
  static final DateFormat _timeLabel = DateFormat('HH:mm', 'it_IT');
  late final List<Shift> _sortedShifts;
  late Set<String> _selectedIds;
  bool _selectAll = true;

  @override
  void initState() {
    super.initState();
    _sortedShifts = widget.shifts.sorted((a, b) => a.start.compareTo(b.start));
    _selectedIds = _sortedShifts.map((shift) => shift.id).toSet();
  }

  void _toggleAll(bool value) {
    setState(() {
      _selectAll = value;
      if (value) {
        _selectedIds = _sortedShifts.map((shift) => shift.id).toSet();
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleShift(String id, bool value) {
    setState(() {
      if (value) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
      _selectAll = _selectedIds.length == _sortedShifts.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Elimina turni di ${widget.staff.fullName}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Seleziona uno o più turni da eliminare. L\'operazione non può essere annullata.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selectAll,
              onChanged: (value) => _toggleAll(value ?? false),
              title: const Text('Seleziona tutti'),
            ),
            const Divider(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sortedShifts.length,
                itemBuilder: (context, index) {
                  final shift = _sortedShifts[index];
                  final selected = _selectedIds.contains(shift.id);
                  final roomName = widget.roomNames[shift.roomId];
                  final label =
                      '${_dayLabel.format(shift.start)} · '
                      '${_timeLabel.format(shift.start)} - ${_timeLabel.format(shift.end)}';
                  return CheckboxListTile(
                    value: selected,
                    onChanged:
                        (value) => _toggleShift(shift.id, value ?? false),
                    title: Text(label),
                    subtitle: roomName != null ? Text(roomName) : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed:
                      _selectedIds.isEmpty
                          ? null
                          : () =>
                              Navigator.of(context).pop(_selectedIds.toList()),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: Text(
                    _selectedIds.length > 1
                        ? 'Elimina ${_selectedIds.length} turni'
                        : 'Elimina turno',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
