import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/quote.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/package_form_sheet.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class QuoteFormSheet extends StatefulWidget {
  const QuoteFormSheet({
    super.key,
    required this.client,
    required this.salon,
    required this.existingQuotes,
    required this.services,
    required this.packages,
    required this.inventoryItems,
    required this.salons,
    this.initial,
  });

  final Client client;
  final Salon salon;
  final List<Quote> existingQuotes;
  final List<Service> services;
  final List<ServicePackage> packages;
  final List<InventoryItem> inventoryItems;
  final List<Salon> salons;
  final Quote? initial;

  @override
  State<QuoteFormSheet> createState() => _QuoteFormSheetState();
}

class _QuoteFormSheetState extends State<QuoteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _numberFormat = NumberFormat.simpleCurrency(locale: 'it_IT');
  final _uuid = const Uuid();

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final String _quoteNumber;
  DateTime? _validUntil;
  bool _saving = false;

  final List<_QuoteLineDraft> _lines = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _validUntil = initial?.validUntil;
    _quoteNumber = initial?.number ?? nextQuoteNumber(widget.existingQuotes);

    final items = initial?.items ?? const <QuoteItem>[];
    if (items.isEmpty) {
      return;
    }
    for (final item in items) {
      final line = _lineFromQuoteItem(item);
      _registerInitialLine(line);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double _computeTotal() {
    return _lines.fold<double>(0, (sum, line) => sum + _lineTotal(line));
  }

  double _lineTotal(_QuoteLineDraft line) {
    final quantity = _parseAmount(line.quantityController.text) ?? 0;
    final unitPrice = _parseAmount(line.unitPriceController.text) ?? 0;
    final total = quantity * unitPrice;
    if (total <= 0) {
      return 0;
    }
    return double.parse(total.toStringAsFixed(2));
  }

  double? _parseAmount(String? value) {
    if (value == null) {
      return null;
    }
    final sanitized = value.replaceAll(',', '.').trim();
    if (sanitized.isEmpty) {
      return null;
    }
    return double.tryParse(sanitized);
  }

  String _formatQuantity(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final initialDate = _validUntil ?? now.add(const Duration(days: 30));
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

  void _handleLineChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _attachLineListeners(_QuoteLineDraft line) {
    line.quantityController.addListener(_handleLineChanged);
    line.unitPriceController.addListener(_handleLineChanged);
  }

  void _registerInitialLine(_QuoteLineDraft line) {
    _attachLineListeners(line);
    _lines.add(line);
  }

  void _addLine(_QuoteLineDraft line) {
    _attachLineListeners(line);
    setState(() {
      _lines.add(line);
    });
  }

  void _removeLine(String id) {
    final index = _lines.indexWhere((line) => line.id == id);
    if (index == -1) {
      return;
    }
    final removed = _lines.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  _QuoteLineDraft _buildLineDraft({
    required String id,
    required QuoteItemReferenceType type,
    String? referenceId,
    required String description,
    double quantity = 1,
    double unitPrice = 0,
    String? catalogLabel,
  }) {
    return _QuoteLineDraft(
      id: id,
      referenceType: type,
      referenceId: referenceId,
      catalogLabel: catalogLabel,
      descriptionController: TextEditingController(text: description),
      quantityController: TextEditingController(
        text: _formatQuantity(quantity),
      ),
      unitPriceController: TextEditingController(
        text: unitPrice.toStringAsFixed(2),
      ),
    );
  }

  _QuoteLineDraft _lineFromQuoteItem(QuoteItem item) {
    var type = item.referenceType;
    final packageId = item.packageId;
    final serviceId = item.serviceId;
    final inventoryId = item.inventoryItemId;

    if (type == QuoteItemReferenceType.manual) {
      if (packageId != null && packageId.isNotEmpty) {
        type = QuoteItemReferenceType.package;
      } else if (serviceId != null && serviceId.isNotEmpty) {
        type = QuoteItemReferenceType.service;
      } else if (inventoryId != null && inventoryId.isNotEmpty) {
        type = QuoteItemReferenceType.product;
      }
    }

    String? referenceId;
    String? catalogLabel;

    if (type == QuoteItemReferenceType.package &&
        packageId != null &&
        packageId.isNotEmpty) {
      referenceId = packageId;
      final pkg = widget.packages.firstWhereOrNull(
        (element) => element.id == packageId,
      );
      final pkgDescription = pkg?.description;
      if (pkgDescription != null && pkgDescription.isNotEmpty) {
        catalogLabel = pkgDescription;
      }
    } else if (type == QuoteItemReferenceType.service &&
        serviceId != null &&
        serviceId.isNotEmpty) {
      referenceId = serviceId;
      final service = widget.services.firstWhereOrNull(
        (element) => element.id == serviceId,
      );
      final serviceCategory = service?.category;
      if (serviceCategory != null && serviceCategory.isNotEmpty) {
        catalogLabel = serviceCategory;
      }
    } else if (type == QuoteItemReferenceType.product &&
        inventoryId != null &&
        inventoryId.isNotEmpty) {
      referenceId = inventoryId;
      final inventory = widget.inventoryItems.firstWhereOrNull(
        (element) => element.id == inventoryId,
      );
      final inventoryCategory = inventory?.category;
      if (inventoryCategory != null && inventoryCategory.isNotEmpty) {
        catalogLabel = inventoryCategory;
      }
    } else {
      type = QuoteItemReferenceType.manual;
    }

    return _buildLineDraft(
      id: item.id,
      type: type,
      referenceId: referenceId,
      description: item.description,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      catalogLabel: catalogLabel,
    );
  }

  Future<void> _onAddService() async {
    if (widget.services.isEmpty) {
      _showSnackBar('Non sono disponibili servizi per questo salone.');
      return;
    }
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final selected = await _pickFromCatalog<Service>(
      title: 'Scegli un servizio',
      items: widget.services,
      labelBuilder: (service) => service.name,
      subtitleBuilder:
          (service) =>
              '${service.category} • ${currency.format(service.price)}',
    );
    if (selected == null) {
      return;
    }
    final line = _buildLineDraft(
      id: _uuid.v4(),
      type: QuoteItemReferenceType.service,
      referenceId: selected.id,
      description: selected.name,
      quantity: 1,
      unitPrice: selected.price,
      catalogLabel: selected.category,
    );
    _addLine(line);
  }

  Future<void> _onAddPackage() async {
    if (widget.packages.isEmpty) {
      _showSnackBar('Non sono disponibili pacchetti per questo salone.');
      return;
    }
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final selected = await _pickFromCatalog<ServicePackage>(
      title: 'Scegli un pacchetto',
      items: widget.packages,
      labelBuilder: (pkg) => pkg.name,
      subtitleBuilder:
          (pkg) =>
              'Listino ${currency.format(pkg.fullPrice)} • Prezzo ${currency.format(pkg.price)}',
    );
    if (selected == null) {
      return;
    }
    final description = selected.name.isNotEmpty ? selected.name : 'Pacchetto';
    final catalogLabel =
        selected.description != null && selected.description!.isNotEmpty
            ? selected.description
            : null;
    final line = _buildLineDraft(
      id: _uuid.v4(),
      type: QuoteItemReferenceType.package,
      referenceId: selected.id,
      description: description,
      quantity: 1,
      unitPrice: selected.price,
      catalogLabel: catalogLabel,
    );
    _addLine(line);
  }

  Future<void> _onAddCustomPackage() async {
    final salons =
        widget.salons.isNotEmpty ? widget.salons : <Salon>[widget.salon];
    if (salons.isEmpty || widget.services.isEmpty) {
      _showSnackBar(
        'Impossibile creare un pacchetto personalizzato senza saloni e servizi.',
      );
      return;
    }
    final customPackage = await showAppModalSheet<ServicePackage>(
      context: context,
      builder:
          (ctx) => PackageFormSheet(
            salons: salons,
            services: widget.services,
            defaultSalonId: widget.salon.id,
          ),
    );
    if (!mounted || customPackage == null) {
      return;
    }
    final description =
        customPackage.name.isNotEmpty
            ? customPackage.name
            : 'Pacchetto personalizzato';
    final line = _buildLineDraft(
      id: _uuid.v4(),
      type: QuoteItemReferenceType.manual,
      description: description,
      quantity: 1,
      unitPrice: customPackage.price,
      catalogLabel: 'Pacchetto personalizzato',
    );
    _addLine(line);
  }

  Future<void> _onAddProduct() async {
    if (widget.inventoryItems.isEmpty) {
      _showSnackBar('Nessun prodotto disponibile per questo salone.');
      return;
    }
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final selected = await _pickFromCatalog<InventoryItem>(
      title: 'Scegli un prodotto',
      items: widget.inventoryItems,
      labelBuilder: (item) => item.name,
      subtitleBuilder:
          (item) =>
              '${item.category} • ${currency.format(item.sellingPrice > 0 ? item.sellingPrice : item.cost)}',
    );
    if (selected == null) {
      return;
    }
    final price =
        selected.sellingPrice > 0 ? selected.sellingPrice : selected.cost;
    final line = _buildLineDraft(
      id: _uuid.v4(),
      type: QuoteItemReferenceType.product,
      referenceId: selected.id,
      description: selected.name,
      quantity: 1,
      unitPrice: price,
      catalogLabel: selected.category,
    );
    _addLine(line);
  }

  void _onAddManualItem() {
    final line = _buildLineDraft(
      id: _uuid.v4(),
      type: QuoteItemReferenceType.manual,
      description: 'Voce manuale',
      quantity: 1,
      unitPrice: 0,
    );
    _addLine(line);
  }

  Future<T?> _pickFromCatalog<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelBuilder,
    String Function(T)? subtitleBuilder,
  }) {
    return showAppModalSheet<T>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(title, style: theme.textTheme.titleMedium),
                trailing: IconButton(
                  tooltip: 'Chiudi',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).maybePop(),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final item = items[index];
                    final subtitle =
                        subtitleBuilder != null ? subtitleBuilder(item) : null;
                    return ListTile(
                      title: Text(labelBuilder(item)),
                      subtitle: subtitle != null ? Text(subtitle) : null,
                      onTap: () => Navigator.of(ctx).pop(item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _lineTypeLabel(QuoteItemReferenceType type) {
    switch (type) {
      case QuoteItemReferenceType.service:
        return 'Servizio';
      case QuoteItemReferenceType.package:
        return 'Pacchetto';
      case QuoteItemReferenceType.product:
        return 'Prodotto';
      case QuoteItemReferenceType.manual:
        return 'Voce manuale';
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currency = _numberFormat;

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
                          _saving
                              ? null
                              : () => Navigator.of(context).maybePop(),
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
                  enabled: !_saving,
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
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Note interne',
                    hintText: 'Dettagli aggiuntivi o accordi con il cliente',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Voci preventivo', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _saving ? null : _onAddService,
                      icon: const Icon(Icons.design_services_rounded),
                      label: const Text('Aggiungi servizio'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _saving ? null : _onAddPackage,
                      icon: const Icon(Icons.card_giftcard_rounded),
                      label: const Text('Aggiungi pacchetto'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _saving ? null : _onAddCustomPackage,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text('Pacchetto personalizzato'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _saving ? null : _onAddProduct,
                      icon: const Icon(Icons.inventory_2_rounded),
                      label: const Text('Aggiungi prodotto'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _saving ? null : _onAddManualItem,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Voce manuale'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_lines.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Aggiungi almeno un elemento per salvare il preventivo.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < _lines.length; i++) ...[
                        _buildLineCard(_lines[i], i, currency),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                const SizedBox(height: 16),
                Text(
                  'Totale preventivo: ${currency.format(_computeTotal())}',
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
                          _saving
                              ? null
                              : () => Navigator.of(context).maybePop(),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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

  Widget _buildLineCard(
    _QuoteLineDraft line,
    int index,
    NumberFormat currency,
  ) {
    final theme = Theme.of(context);
    final lineTotal = _lineTotal(line);
    final typeLabel = _lineTypeLabel(line.referenceType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$typeLabel • Riga ${index + 1}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Rimuovi voce',
                  onPressed: _saving ? null : () => _removeLine(line.id),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            if (line.catalogLabel != null && line.catalogLabel!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line.catalogLabel!,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            TextFormField(
              controller: line.descriptionController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci la descrizione'
                          : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.quantityController,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Quantità'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final parsed = _parseAmount(value);
                      if (parsed == null || parsed <= 0) {
                        return 'Quantità non valida';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: line.unitPriceController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Prezzo unitario',
                      prefixText: '€ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final parsed = _parseAmount(value);
                      if (parsed == null || parsed < 0) {
                        return 'Prezzo non valido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Totale voce: ${currency.format(lineTotal)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
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
    if (_lines.isEmpty) {
      _showSnackBar('Aggiungi almeno una voce al preventivo.');
      return;
    }

    final items = <QuoteItem>[];
    for (final line in _lines) {
      final description = line.descriptionController.text.trim();
      if (description.isEmpty) {
        _showSnackBar('Completa la descrizione di tutte le voci.');
        return;
      }
      final quantityValue = _parseAmount(line.quantityController.text) ?? 0;
      final unitPriceValue = _parseAmount(line.unitPriceController.text) ?? 0;
      if (quantityValue <= 0) {
        _showSnackBar('La quantità deve essere maggiore di zero.');
        return;
      }
      if (unitPriceValue < 0) {
        _showSnackBar('Il prezzo unitario non può essere negativo.');
        return;
      }
      final normalizedQuantity = double.parse(quantityValue.toStringAsFixed(2));
      final normalizedPrice = double.parse(unitPriceValue.toStringAsFixed(2));

      var type = line.referenceType;
      String? serviceId;
      String? packageId;
      String? inventoryId;

      switch (type) {
        case QuoteItemReferenceType.service:
          if (line.referenceId != null && line.referenceId!.isNotEmpty) {
            serviceId = line.referenceId;
          } else {
            type = QuoteItemReferenceType.manual;
          }
          break;
        case QuoteItemReferenceType.package:
          if (line.referenceId != null && line.referenceId!.isNotEmpty) {
            packageId = line.referenceId;
          } else {
            type = QuoteItemReferenceType.manual;
          }
          break;
        case QuoteItemReferenceType.product:
          if (line.referenceId != null && line.referenceId!.isNotEmpty) {
            inventoryId = line.referenceId;
          } else {
            type = QuoteItemReferenceType.manual;
          }
          break;
        case QuoteItemReferenceType.manual:
          break;
      }

      items.add(
        QuoteItem(
          id: line.id,
          description: description,
          quantity: normalizedQuantity,
          unitPrice: normalizedPrice,
          referenceType: type,
          serviceId: serviceId,
          packageId: packageId,
          inventoryItemId: inventoryId,
        ),
      );
    }

    if (items.isEmpty) {
      _showSnackBar('Aggiungi almeno una voce valida.');
      return;
    }

    setState(() => _saving = true);
    final initial = widget.initial;
    final now = DateTime.now();
    final quote = Quote(
      id: initial?.id ?? _uuid.v4(),
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
      saleId: initial?.saleId,
      stripePaymentIntentId: initial?.stripePaymentIntentId,
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(quote);
  }
}

class _QuoteLineDraft {
  _QuoteLineDraft({
    required this.id,
    required this.referenceType,
    this.referenceId,
    this.catalogLabel,
    required this.descriptionController,
    required this.quantityController,
    required this.unitPriceController,
  });

  final String id;
  QuoteItemReferenceType referenceType;
  String? referenceId;
  final String? catalogLabel;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
  }
}
