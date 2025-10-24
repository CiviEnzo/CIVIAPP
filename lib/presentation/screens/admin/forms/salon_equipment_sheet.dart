import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class SalonEquipmentSheet extends StatefulWidget {
  const SalonEquipmentSheet({super.key, required this.initialEquipment});

  final List<SalonEquipment> initialEquipment;

  @override
  State<SalonEquipmentSheet> createState() => _SalonEquipmentSheetState();
}

class _SalonEquipmentSheetState extends State<SalonEquipmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late List<_EditableEquipment> _equipment;

  @override
  void initState() {
    super.initState();
    _equipment =
        widget.initialEquipment.map(_EditableEquipment.fromEquipment).toList();
  }

  @override
  void dispose() {
    for (final item in _equipment) {
      item.dispose();
    }
    super.dispose();
  }

  void _addEquipment() {
    setState(() {
      _equipment.add(_EditableEquipment(id: _uuid.v4()));
    });
  }

  void _removeEquipment(_EditableEquipment equipment) {
    var removed = false;
    setState(() {
      removed = _equipment.remove(equipment);
    });
    if (removed) {
      equipment.dispose();
    }
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (!(formState?.validate() ?? true)) {
      return;
    }

    if (_equipment.isEmpty) {
      Navigator.of(context).pop(const <SalonEquipment>[]);
      return;
    }

    final parsed = <SalonEquipment>[];
    for (final item in _equipment) {
      final quantity = int.tryParse(item.quantity.text.trim());
      if (quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imposta una quantità valida maggiore di 0.'),
          ),
        );
        return;
      }
      parsed.add(
        SalonEquipment(
          id: item.id,
          name: item.name.text.trim(),
          quantity: quantity,
          status: item.status,
          notes: item.notes.text.trim().isEmpty ? null : item.notes.text.trim(),
        ),
      );
    }

    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DialogActionLayout(
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gestione macchinari', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_equipment.isEmpty)
              Text(
                'Nessun macchinario configurato. Aggiungi una voce per iniziare.',
                style: theme.textTheme.bodyMedium,
              ),
            ..._equipment.map(
              (item) => _EquipmentCard(
                data: item,
                onStatusChanged: (value) {
                  setState(() => item.status = value);
                },
                onRemove: () => _removeEquipment(item),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addEquipment,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Aggiungi macchinario'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: _submit, child: const Text('Salva'))],
    );
  }
}

class _EditableEquipment {
  _EditableEquipment({
    required this.id,
    String? name,
    int? quantity,
    SalonEquipmentStatus? status,
    String? notes,
  }) : name = TextEditingController(text: name ?? ''),
       quantity = TextEditingController(text: quantity?.toString() ?? '1'),
       notes = TextEditingController(text: notes ?? ''),
       status = status ?? SalonEquipmentStatus.operational;

  factory _EditableEquipment.fromEquipment(SalonEquipment equipment) {
    return _EditableEquipment(
      id: equipment.id,
      name: equipment.name,
      quantity: equipment.quantity,
      status: equipment.status,
      notes: equipment.notes,
    );
  }

  final String id;
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController notes;
  SalonEquipmentStatus status;

  void dispose() {
    name.dispose();
    quantity.dispose();
    notes.dispose();
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.data,
    required this.onStatusChanged,
    required this.onRemove,
  });

  final _EditableEquipment data;
  final ValueChanged<SalonEquipmentStatus> onStatusChanged;
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
                Text('Macchinario', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Rimuovi macchinario',
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
              ],
            ),
            TextFormField(
              controller: data.name,
              decoration: const InputDecoration(labelText: 'Nome macchinario'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci un nome per il macchinario';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SalonEquipmentStatus>(
              value: data.status,
              decoration: const InputDecoration(labelText: 'Stato operativo'),
              items:
                  SalonEquipmentStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  onStatusChanged(value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.quantity,
              decoration: const InputDecoration(
                labelText: 'Quantità disponibile',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final parsed = int.tryParse((value ?? '').trim());
                if (parsed == null || parsed <= 0) {
                  return 'Inserisci una quantità valida';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: data.notes,
              decoration: const InputDecoration(
                labelText: 'Note o istruzioni',
                helperText:
                    'Visibili solo allo staff (manutenzione, uso, ecc.)',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
