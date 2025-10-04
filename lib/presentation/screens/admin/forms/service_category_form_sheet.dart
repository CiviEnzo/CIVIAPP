import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service_category.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ServiceCategoryFormSheet extends StatefulWidget {
  const ServiceCategoryFormSheet({
    super.key,
    required this.salons,
    this.initial,
    this.initialSalonId,
    this.initialSortOrder,
  });

  final List<Salon> salons;
  final ServiceCategory? initial;
  final String? initialSalonId;
  final int? initialSortOrder;

  @override
  State<ServiceCategoryFormSheet> createState() =>
      _ServiceCategoryFormSheetState();
}

class _ServiceCategoryFormSheetState extends State<ServiceCategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _name;
  late TextEditingController _description;
  late TextEditingController _sortOrder;
  String? _salonId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _description = TextEditingController(text: initial?.description ?? '');
    final defaultSortOrder =
        initial?.sortOrder ?? widget.initialSortOrder ?? 100;
    _sortOrder = TextEditingController(text: defaultSortOrder.toString());
    _salonId =
        initial?.salonId ??
        widget.initialSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canChangeSalon = widget.initial == null && widget.salons.length > 1;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initial == null
                    ? 'Nuova categoria'
                    : 'Modifica categoria',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (widget.salons.length > 1)
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
                      canChangeSalon
                          ? (value) => setState(() => _salonId = value)
                          : null,
                )
              else
                TextFormField(
                  enabled: false,
                  initialValue:
                      widget.salons.isNotEmpty
                          ? widget.salons.first.name
                          : 'Nessun salone',
                  decoration: const InputDecoration(labelText: 'Salone'),
                ),
              if (widget.salons.isNotEmpty) const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Inserisci il nome della categoria'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Descrizione (opzionale)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sortOrder,
                decoration: const InputDecoration(
                  labelText: 'Ordine di visualizzazione',
                  helperText:
                      'Numeri più bassi mostrano la categoria più in alto.',
                ),
                keyboardType: TextInputType.number,
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
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_salonId == null || _salonId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleziona un salone.')));
      return;
    }

    final category = ServiceCategory(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      name: _name.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      sortOrder: _parseSortOrder(_sortOrder.text.trim()),
    );

    Navigator.of(context).pop(category);
  }

  int _parseSortOrder(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      return widget.initial?.sortOrder ?? 100;
    }
    return parsed;
  }
}
