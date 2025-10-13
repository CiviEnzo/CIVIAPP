import 'package:civiapp/domain/entities/salon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class SalonRoomsSheet extends StatefulWidget {
  const SalonRoomsSheet({super.key, required this.initialRooms});

  final List<SalonRoom> initialRooms;

  @override
  State<SalonRoomsSheet> createState() => _SalonRoomsSheetState();
}

class _SalonRoomsSheetState extends State<SalonRoomsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late List<_EditableRoom> _rooms;

  @override
  void initState() {
    super.initState();
    _rooms = widget.initialRooms.map(_EditableRoom.fromRoom).toList();
    if (_rooms.isEmpty) {
      _rooms = [_EditableRoom(id: _uuid.v4())];
    }
  }

  @override
  void dispose() {
    for (final room in _rooms) {
      room.dispose();
    }
    super.dispose();
  }

  void _addRoom() {
    setState(() {
      _rooms.add(_EditableRoom(id: _uuid.v4()));
    });
  }

  void _removeRoom(_EditableRoom room) {
    if (_rooms.length == 1) {
      return;
    }
    var removed = false;
    setState(() {
      removed = _rooms.remove(room);
    });
    if (removed) {
      room.dispose();
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final parsed = <SalonRoom>[];
    for (final room in _rooms) {
      final capacity = int.tryParse(room.capacity.text.trim()) ?? 0;
      if (capacity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La capienza deve essere maggiore di 0.'),
          ),
        );
        return;
      }
      final services =
          room.services.text
              .split(',')
              .map((service) => service.trim())
              .where((service) => service.isNotEmpty)
              .toList();
      parsed.add(
        SalonRoom(
          id: room.id,
          name: room.name.text.trim(),
          capacity: capacity,
          category:
              room.category.text.trim().isEmpty
                  ? null
                  : room.category.text.trim(),
          services: services,
        ),
      );
    }

    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gestione cabine e stanze', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_rooms.isEmpty)
              Text(
                'Nessuna cabina configurata. Aggiungi una cabina per iniziare.',
                style: theme.textTheme.bodyMedium,
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
}

class _EditableRoom {
  _EditableRoom({
    required this.id,
    String? name,
    int? capacity,
    String? category,
    List<String>? services,
  }) : name = TextEditingController(text: name ?? ''),
       capacity = TextEditingController(text: capacity?.toString() ?? '1'),
       category = TextEditingController(text: category ?? ''),
       services = TextEditingController(
         text: (services ?? const <String>[]).join(', '),
       );

  factory _EditableRoom.fromRoom(SalonRoom room) {
    return _EditableRoom(
      id: room.id,
      name: room.name,
      capacity: room.capacity,
      category: room.category,
      services: room.services,
    );
  }

  final String id;
  final TextEditingController name;
  final TextEditingController capacity;
  final TextEditingController category;
  final TextEditingController services;

  void dispose() {
    name.dispose();
    capacity.dispose();
    category.dispose();
    services.dispose();
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.data, required this.onRemove});

  final _EditableRoom data;
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci un nome per la cabina';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.category,
              decoration: const InputDecoration(
                labelText: 'Categoria postazione',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.capacity,
              decoration: const InputDecoration(labelText: 'Capienza'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final parsed = int.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) {
                  return 'Inserisci una capienza valida';
                }
                return null;
              },
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
