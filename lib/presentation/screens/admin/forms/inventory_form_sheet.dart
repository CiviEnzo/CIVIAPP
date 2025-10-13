import 'package:civiapp/domain/entities/inventory_item.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class InventoryFormSheet extends StatefulWidget {
  const InventoryFormSheet({
    super.key,
    required this.salons,
    this.initial,
    this.defaultSalonId,
  });

  final List<Salon> salons;
  final InventoryItem? initial;
  final String? defaultSalonId;

  @override
  State<InventoryFormSheet> createState() => _InventoryFormSheetState();
}

class _InventoryFormSheetState extends State<InventoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _name;
  late TextEditingController _category;
  late TextEditingController _quantity;
  late TextEditingController _unit;
  late TextEditingController _threshold;
  late TextEditingController _cost;
  late TextEditingController _price;
  String? _salonId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _category = TextEditingController(text: initial?.category ?? '');
    _quantity = TextEditingController(
      text: initial?.quantity.toString() ?? '0',
    );
    _unit = TextEditingController(text: initial?.unit ?? 'pz');
    _threshold = TextEditingController(
      text: initial?.threshold.toString() ?? '0',
    );
    _cost = TextEditingController(text: initial?.cost.toString() ?? '0');
    _price = TextEditingController(
      text: initial?.sellingPrice.toString() ?? '0',
    );
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _quantity.dispose();
    _unit.dispose();
    _threshold.dispose();
    _cost.dispose();
    _price.dispose();
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
              widget.initial == null ? 'Nuovo articolo' : 'Modifica articolo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il nome'
                          : null,
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
              onChanged: (value) => setState(() => _salonId = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantity,
              decoration: const InputDecoration(labelText: 'Quantità'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unit,
              decoration: const InputDecoration(labelText: 'Unità di misura'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _threshold,
              decoration: const InputDecoration(labelText: 'Soglia minima'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cost,
              decoration: const InputDecoration(
                labelText: 'Costo unitario (€)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(
                labelText: 'Prezzo vendita (€)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
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
    if (_salonId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleziona un salone')));
      return;
    }

    final item = InventoryItem(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      name: _name.text.trim(),
      category:
          _category.text.trim().isEmpty ? 'Magazzino' : _category.text.trim(),
      quantity: double.tryParse(_quantity.text.replaceAll(',', '.')) ?? 0,
      unit: _unit.text.trim().isEmpty ? 'pz' : _unit.text.trim(),
      threshold: double.tryParse(_threshold.text.replaceAll(',', '.')) ?? 0,
      cost: double.tryParse(_cost.text.replaceAll(',', '.')) ?? 0,
      sellingPrice: double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(item);
  }
}
