import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/quote.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class QuoteFormSheet extends StatefulWidget {
  const QuoteFormSheet({
    super.key,
    required this.client,
    required this.existingQuotes,
    required this.services,
    required this.packages,
    this.initial,
  });

  final Client client;
  final List<Quote> existingQuotes;
  final List<Service> services;
  final List<ServicePackage> packages;
  final Quote? initial;

  @override
  State<QuoteFormSheet> createState() => _QuoteFormSheetState();
}

class _QuoteFormSheetState extends State<QuoteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _numberFormat = NumberFormat.simpleCurrency(locale: 'it_IT');
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final List<_QuoteItemFormData> _items;
  late final String _quoteNumber;
  DateTime? _validUntil;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _validUntil = initial?.validUntil;
    _quoteNumber =
        initial?.number ?? nextQuoteNumber(widget.existingQuotes);
    _items =
        (initial?.items ?? const <QuoteItem>[])
            .map(_QuoteItemFormData.fromQuoteItem)
            .toList(growable: true);
    if (_items.isEmpty) {
      _items.add(_QuoteItemFormData.empty());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double _computeTotal() {
    return _items.fold<double>(
      0,
      (sum, item) => sum + item.estimateTotal,
    );
  }

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final initialDate =
        _validUntil ?? now.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Seleziona la data di scadenza',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
    );
    if (picked != null) {
      setState(() {
        _validUntil = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _addItem() {
    setState(() {
      _items.add(_QuoteItemFormData.empty());
    });
  }

  void _removeItem(int index) {
    if (_items.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Il preventivo deve avere almeno una voce.'),
        ),
      );
      return;
    }
    final removed = _items.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    if (_saving) {
      return;
    }
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final items =
        _items.map((item) => item.toQuoteItem()).whereType<QuoteItem>().toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aggiungi almeno una voce.')),
      );
      return;
    }

    setState(() => _saving = true);
    final initial = widget.initial;
    final now = DateTime.now();
    final quote = Quote(
      id: initial?.id ?? const Uuid().v4(),
      salonId: widget.client.salonId,
      clientId: widget.client.id,
      items: items,
      number: initial?.number ?? _quoteNumber,
      title:
          _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      status: initial?.status ?? QuoteStatus.draft,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
      validUntil: _validUntil,
      sentAt: initial?.sentAt,
      acceptedAt: initial?.acceptedAt,
      declinedAt: initial?.declinedAt,
      ticketId: initial?.ticketId,
      sentChannels: initial?.sentChannels,
      pdfStoragePath: initial?.pdfStoragePath,
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(quote);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.initial == null
                            ? 'Nuovo preventivo'
                            : 'Modifica preventivo',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chiudi',
                      onPressed:
                          _saving ? null : () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (_quoteNumber.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Numero preventivo: $_quoteNumber',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Titolo',
                    hintText: 'Es. Percorso remise en forme',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: Text(
                    _validUntil == null
                        ? 'Scadenza preventivo'
                        : 'Valido fino al '
                            '${DateFormat('dd/MM/yyyy').format(_validUntil!)}',
                  ),
                  subtitle: const Text(
                    'Opzionale: definisce la validità economica dell\'offerta.',
                  ),
                  trailing: IconButton(
                    tooltip: 'Rimuovi data',
                    onPressed:
                        _validUntil == null || _saving
                            ? null
                            : () => setState(() => _validUntil = null),
                    icon: const Icon(Icons.clear_rounded),
                  ),
                  onTap: _saving ? null : _pickValidUntil,
                ),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Note interne',
                    hintText: 'Dettagli aggiuntivi o accordi con il cliente',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Voci preventivo',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < _items.length; index += 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _QuoteItemCard(
                        data: _items[index],
                        index: index,
                        services: widget.services,
                        packages: widget.packages,
                        onChanged: () => setState(() {}),
                        onRemove: _saving ? null : () => _removeItem(index),
                        currency: _numberFormat,
                      ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _addItem,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Aggiungi voce'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Totale preventivo: ${_numberFormat.format(_computeTotal())}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).maybePop(),
                      child: const Text('Annulla'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child:
                          _saving
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                              : const Text('Salva'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuoteItemCard extends StatelessWidget {
  const _QuoteItemCard({
    required this.data,
    required this.index,
    required this.services,
    required this.packages,
    required this.onChanged,
    required this.currency,
    this.onRemove,
  });

  final _QuoteItemFormData data;
  final int index;
  final List<Service> services;
  final List<ServicePackage> packages;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeServices =
        services.where((service) => service.isActive).toList(growable: false);
    final availablePackages = packages.toList(growable: false);

    final dropdownItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Voce personalizzata'),
      ),
      if (activeServices.isNotEmpty)
        ...activeServices.map(
          (service) => DropdownMenuItem<String?>(
            value: 'service|${service.id}',
            child: Text('Servizio • ${service.name}'),
          ),
        ),
      if (availablePackages.isNotEmpty)
        ...availablePackages.map(
          (pkg) => DropdownMenuItem<String?>(
            value: 'package|${pkg.id}',
            child: Text('Pacchetto • ${pkg.name}'),
          ),
        ),
    ];

    String? selectedValue;
    if (data.serviceId != null) {
      selectedValue = 'service|${data.serviceId}';
    } else if (data.packageId != null) {
      selectedValue = 'package|${data.packageId}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Voce ${index + 1}',
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Rimuovi voce',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            if (dropdownItems.length > 1) ...[
              DropdownButtonFormField<String?>(
                value: selectedValue,
                decoration: const InputDecoration(
                  labelText: 'Associa voce esistente',
                ),
                items: dropdownItems,
                onChanged: (value) {
                  data.serviceId = null;
                  data.packageId = null;
                  if (value != null && value.contains('|')) {
                    final parts = value.split('|');
                    if (parts.length == 2) {
                      final type = parts.first;
                      final id = parts.last;
                      if (type == 'service') {
                        data.serviceId = id;
                        final matched = activeServices.firstWhereOrNull(
                          (service) => service.id == id,
                        );
                        if (matched != null) {
                          data.descriptionController.text = matched.name;
                          data.unitPriceController.text =
                              matched.price.toStringAsFixed(2);
                        }
                      } else if (type == 'package') {
                        data.packageId = id;
                        final matched = availablePackages.firstWhereOrNull(
                          (pkg) => pkg.id == id,
                        );
                        if (matched != null) {
                          data.descriptionController.text = matched.name;
                          data.unitPriceController.text =
                              matched.price.toStringAsFixed(2);
                        }
                      }
                    }
                  }
                  if (value == null) {
                    data.descriptionController.clear();
                    data.packageId = null;
                    data.serviceId = null;
                  }
                  onChanged();
                },
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: data.descriptionController,
              decoration: InputDecoration(
                labelText: 'Descrizione',
                hintText: 'Dettaglio della voce ${index + 1}',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci una descrizione';
                }
                return null;
              },
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: data.quantityController,
                    decoration: const InputDecoration(labelText: 'Quantità'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final parsed = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      if (parsed == null || parsed <= 0) {
                        return 'Valore non valido';
                      }
                      return null;
                    },
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: data.unitPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Prezzo unitario',
                      prefixText: '€ ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final parsed = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      if (parsed == null || parsed < 0) {
                        return 'Valore non valido';
                      }
                      return null;
                    },
                    onChanged: (_) => onChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Totale voce: ${currency.format(data.estimateTotal)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteItemFormData {
  _QuoteItemFormData._({
    required this.id,
    required this.descriptionController,
    required this.quantityController,
    required this.unitPriceController,
    this.serviceId,
    this.packageId,
  });

  factory _QuoteItemFormData.fromQuoteItem(QuoteItem item) {
    return _QuoteItemFormData._(
      id: item.id,
      descriptionController: TextEditingController(text: item.description),
      quantityController: TextEditingController(
        text:
            item.quantity == item.quantity.roundToDouble()
                ? item.quantity.toInt().toString()
                : item.quantity.toStringAsFixed(2),
      ),
      unitPriceController: TextEditingController(
        text: item.unitPrice.toStringAsFixed(2),
      ),
      serviceId: item.serviceId,
      packageId: item.packageId,
    );
  }

  factory _QuoteItemFormData.empty() {
    return _QuoteItemFormData._(
      id: const Uuid().v4(),
      descriptionController: TextEditingController(),
      quantityController: TextEditingController(text: '1'),
      unitPriceController: TextEditingController(),
    );
  }

  final String id;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  String? serviceId;
  String? packageId;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
  }

  QuoteItem? toQuoteItem() {
    final description = descriptionController.text.trim();
    if (description.isEmpty) {
      return null;
    }
    final quantity = double.tryParse(
          quantityController.text.replaceAll(',', '.'),
        ) ??
        0;
    final unitPrice = double.tryParse(
          unitPriceController.text.replaceAll(',', '.'),
        ) ??
        0;
    if (quantity <= 0) {
      return null;
    }
    return QuoteItem(
      id: id,
      description: description,
      quantity: double.parse(quantity.toStringAsFixed(2)),
      unitPrice: double.parse(unitPrice.toStringAsFixed(2)),
      serviceId: serviceId?.isNotEmpty == true ? serviceId : null,
      packageId: packageId?.isNotEmpty == true ? packageId : null,
    );
  }

  double get estimateTotal {
    final quantity =
        double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 0;
    final unitPrice =
        double.tryParse(unitPriceController.text.replaceAll(',', '.')) ?? 0;
    return quantity * unitPrice;
  }
}
