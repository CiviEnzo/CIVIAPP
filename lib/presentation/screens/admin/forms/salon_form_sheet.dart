import 'package:civiapp/domain/entities/salon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class SalonFormSheet extends StatefulWidget {
  const SalonFormSheet({super.key, this.initial});

  final Salon? initial;

  @override
  State<SalonFormSheet> createState() => _SalonFormSheetState();
}

class _SalonFormSheetState extends State<SalonFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _name;
  late TextEditingController _address;
  late TextEditingController _city;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _description;
  late List<_RoomFormData> _rooms;
  late List<_ScheduleEntry> _schedule;

  static const int _minutesInDay = 24 * 60;
  static const int _defaultOpeningMinutes = 9 * 60;
  static const int _defaultClosingMinutes = 19 * 60;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _address = TextEditingController(text: initial?.address ?? '');
    _city = TextEditingController(text: initial?.city ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '');
    _email = TextEditingController(text: initial?.email ?? '');
    _description = TextEditingController(text: initial?.description ?? '');

    final roomList = initial?.rooms ?? const <SalonRoom>[];
    _rooms =
        roomList
            .map(
              (room) => _RoomFormData.fromRoom(
                room,
                servicesLabel: room.services.join(', '),
              ),
            )
            .toList();
    if (_rooms.isEmpty) {
      _rooms = [_RoomFormData(id: _uuid.v4())];
    }

    final scheduleMap = {
      for (final entry in initial?.schedule ?? const <SalonDailySchedule>[])
        entry.weekday: entry,
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
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _phone.dispose();
    _email.dispose();
    _description.dispose();
    for (final room in _rooms) {
      room.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null ? 'Nuovo salone' : 'Modifica salone',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il nome del salone'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Indirizzo'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Città'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Telefono'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Orari di apertura',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
            Text(
              'Cabine e stanze',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_rooms.isEmpty)
              Text(
                'Nessuna cabina configurata. Aggiungine una per iniziare.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ..._rooms.map(
              (room) => _RoomCard(
                data: room,
                onRemove: _rooms.length <= 1 ? null : () => _removeRoom(room),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addRoom,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Aggiungi cabina'),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Salva'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final parsedRooms = <SalonRoom>[];
    for (final room in _rooms) {
      final name = room.name.text.trim();
      if (name.isEmpty) {
        _showError('Specifica il nome per ogni cabina.');
        return;
      }
      final capacityText = room.capacity.text.trim();
      final capacity = capacityText.isEmpty ? 1 : int.tryParse(capacityText);
      if (capacity == null || capacity <= 0) {
        _showError('La capienza deve essere un numero positivo.');
        return;
      }
      final services =
          room.services.text
              .split(',')
              .map((service) => service.trim())
              .where((service) => service.isNotEmpty)
              .toList();
      parsedRooms.add(
        SalonRoom(
          id: room.id,
          name: name,
          capacity: capacity,
          services: services,
        ),
      );
    }

    if (parsedRooms.isEmpty) {
      _showError('Aggiungi almeno una cabina al salone.');
      return;
    }

    final schedule = <SalonDailySchedule>[];
    for (final entry in _schedule) {
      final openMinutes = _timeOfDayToMinutes(entry.open);
      final closeMinutes = _timeOfDayToMinutes(entry.close);
      if (entry.isOpen && closeMinutes <= openMinutes) {
        _showError(
          'L\'orario di chiusura deve essere successivo a quello di apertura per ${_weekdayName(entry.weekday)}.',
        );
        return;
      }
      schedule.add(
        SalonDailySchedule(
          weekday: entry.weekday,
          isOpen: entry.isOpen,
          openMinuteOfDay: entry.isOpen ? openMinutes : null,
          closeMinuteOfDay: entry.isOpen ? closeMinutes : null,
        ),
      );
    }

    final salonName = _name.text.trim();
    final salonId = widget.initial?.id ?? _generateSalonId(salonName);

    final salon = Salon(
      id: salonId,
      name: _name.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      rooms: parsedRooms,
      schedule: schedule,
    );

    Navigator.of(context).pop(salon);
  }

  String _generateSalonId(String name) {
    var base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (base.isEmpty) {
      base = 'salon';
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${base}_$timestamp';
  }

  void _addRoom() {
    setState(() {
      _rooms.add(_RoomFormData(id: _uuid.v4()));
    });
  }

  void _removeRoom(_RoomFormData room) {
    setState(() {
      _rooms.remove(room);
    });
    room.dispose();
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

class _RoomFormData {
  _RoomFormData({
    required this.id,
    String? name,
    int? capacity,
    String? servicesLabel,
  }) : name = TextEditingController(text: name ?? ''),
       capacity = TextEditingController(text: capacity?.toString() ?? '1'),
       services = TextEditingController(text: servicesLabel ?? '');

  factory _RoomFormData.fromRoom(
    SalonRoom room, {
    required String servicesLabel,
  }) {
    return _RoomFormData(
      id: room.id,
      name: room.name,
      capacity: room.capacity,
      servicesLabel: servicesLabel,
    );
  }

  final String id;
  final TextEditingController name;
  final TextEditingController capacity;
  final TextEditingController services;

  void dispose() {
    name.dispose();
    capacity.dispose();
    services.dispose();
  }
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

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.data, required this.onRemove});

  final _RoomFormData data;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Cabina', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Rimuovi cabina',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            TextFormField(
              controller: data.name,
              decoration: const InputDecoration(labelText: 'Nome cabina'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.capacity,
              decoration: const InputDecoration(labelText: 'Capienza'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.services,
              decoration: const InputDecoration(
                labelText: 'Servizi offerti',
                helperText: 'Separa i servizi con una virgola',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
