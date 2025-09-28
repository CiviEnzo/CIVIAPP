import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_role.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ServiceFormSheet extends StatefulWidget {
  const ServiceFormSheet({
    super.key,
    required this.salons,
    required this.roles,
    this.initial,
    this.defaultSalonId,
  });

  final List<Salon> salons;
  final List<StaffRole> roles;
  final Service? initial;
  final String? defaultSalonId;

  @override
  State<ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _name;
  late TextEditingController _category;
  late TextEditingController _description;
  late TextEditingController _price;
  late TextEditingController _duration;
  late TextEditingController _extraDuration;
  List<String> _roles = [];
  List<String> _requiredEquipment = [];
  String? _salonId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _category = TextEditingController(text: initial?.category ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _price = TextEditingController(text: initial?.price.toString() ?? '0');
    _duration = TextEditingController(
      text: initial?.duration.inMinutes.toString() ?? '60',
    );
    _extraDuration = TextEditingController(
      text: initial?.extraDuration.inMinutes.toString() ?? '0',
    );
    _roles = List<String>.from(initial?.staffRoles ?? []);
    final availableRoleIds = widget.roles.map((role) => role.id).toSet();
    _roles.retainWhere(availableRoleIds.contains);
    _requiredEquipment = List<String>.from(initial?.requiredEquipmentIds ?? []);
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _retainValidEquipment();
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    _price.dispose();
    _duration.dispose();
    _extraDuration.dispose();
    super.dispose();
  }

  List<SalonEquipment> _equipmentForSalon(String? salonId) {
    if (salonId == null) {
      return const <SalonEquipment>[];
    }
    return widget.salons
            .firstWhereOrNull((salon) => salon.id == salonId)
            ?.equipment ??
        const <SalonEquipment>[];
  }

  void _retainValidEquipment() {
    final availableIds =
        _equipmentForSalon(_salonId).map((equipment) => equipment.id).toSet();
    _requiredEquipment.retainWhere(availableIds.contains);
  }

  @override
  Widget build(BuildContext context) {
    final sortedRoles = widget.roles.sorted((a, b) {
      final priority = a.sortPriority.compareTo(b.sortPriority);
      if (priority != 0) {
        return priority;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    final hasRoles = sortedRoles.isNotEmpty;
    final equipmentOptions = _equipmentForSalon(_salonId);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null ? 'Nuovo servizio' : 'Modifica servizio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il nome del servizio'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _salonId,
              decoration: const InputDecoration(labelText: 'Salone'),
              items:
                  widget.salons
                      .map(
                        (salon) => DropdownMenuItem(
                          value: salon.id,
                          child: Text(salon.name),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(() {
                    _salonId = value;
                    _retainValidEquipment();
                  }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Prezzo (€)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _duration,
              decoration: const InputDecoration(labelText: 'Durata (minuti)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _extraDuration,
              decoration: const InputDecoration(
                labelText: 'Tempo extra post-servizio (minuti)',
                helperText: 'Minuti da riservare per sistemazione o pulizia',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            if (hasRoles)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    sortedRoles
                        .map(
                          (role) => FilterChip(
                            label: Text(role.displayName),
                            selected: _roles.contains(role.id),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  if (!_roles.contains(role.id)) {
                                    _roles.add(role.id);
                                  }
                                } else {
                                  _roles.remove(role.id);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
              )
            else
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nessuna mansione disponibile. Aggiungi ruoli per assegnare gli operatori al servizio.',
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Macchinari richiesti',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (equipmentOptions.isEmpty)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nessun macchinario configurato per il salone selezionato. Aggiungili dalla sezione Saloni.',
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    equipmentOptions
                        .map(
                          (equipment) => FilterChip(
                            label: Text(equipment.name),
                            selected: _requiredEquipment.contains(equipment.id),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  if (!_requiredEquipment.contains(
                                    equipment.id,
                                  )) {
                                    _requiredEquipment.add(equipment.id);
                                  }
                                } else {
                                  _requiredEquipment.remove(equipment.id);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
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
    if (_salonId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleziona un salone')));
      return;
    }

    final service = Service(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      name: _name.text.trim(),
      category:
          _category.text.trim().isEmpty ? 'Generale' : _category.text.trim(),
      duration: Duration(minutes: int.tryParse(_duration.text.trim()) ?? 60),
      extraDuration: Duration(
        minutes: _parseNonNegativeInt(_extraDuration.text.trim()),
      ),
      price: double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      staffRoles: List<String>.unmodifiable(_roles),
      requiredEquipmentIds: List<String>.unmodifiable(_requiredEquipment),
    );

    Navigator.of(context).pop(service);
  }

  int _parseNonNegativeInt(String value) {
    final parsed = int.tryParse(value) ?? 0;
    return parsed < 0 ? 0 : parsed;
  }
}
