import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ServiceFormSheet extends StatefulWidget {
  const ServiceFormSheet({
    super.key,
    required this.salons,
    this.initial,
    this.defaultSalonId,
  });

  final List<Salon> salons;
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
  List<String> _roles = [];
  String? _salonId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _category = TextEditingController(text: initial?.category ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    _price = TextEditingController(text: initial?.price.toString() ?? '0');
    _duration = TextEditingController(text: initial?.duration.inMinutes.toString() ?? '60');
    _roles = List<String>.from(initial?.staffRoles ?? []);
    _salonId = initial?.salonId ?? widget.defaultSalonId ?? (widget.salons.isNotEmpty ? widget.salons.first.id : null);
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    _price.dispose();
    _duration.dispose();
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
              widget.initial == null ? 'Nuovo servizio' : 'Modifica servizio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Inserisci il nome del servizio' : null,
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
              items: widget.salons
                  .map(
                    (salon) => DropdownMenuItem(
                      value: salon.id,
                      child: Text(salon.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _salonId = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Prezzo (€)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _duration,
              decoration: const InputDecoration(labelText: 'Durata (minuti)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: StaffRole.values
                  .map(
                    (role) => FilterChip(
                      label: Text(role.label),
                      selected: _roles.contains(role.name),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _roles.add(role.name);
                          } else {
                            _roles.remove(role.name);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un salone')), 
      );
      return;
    }

    final service = Service(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      name: _name.text.trim(),
      category: _category.text.trim().isEmpty ? 'Generale' : _category.text.trim(),
      duration: Duration(minutes: int.tryParse(_duration.text.trim()) ?? 60),
      price: double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      staffRoles: _roles,
    );

    Navigator.of(context).pop(service);
  }
}
