import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/inventory_item.dart';
import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/client_search_sheet.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class SaleFormSheet extends StatefulWidget {
  const SaleFormSheet({
    super.key,
    required this.salons,
    required this.clients,
    required this.staff,
    required this.services,
    required this.packages,
    required this.inventoryItems,
    this.defaultSalonId,
    this.initialClientId,
    this.initialItems,
    this.initialPaymentMethod,
    this.initialPaymentStatus,
    this.initialPaidAmount,
    this.initialDiscountAmount,
    this.initialInvoiceNumber,
    this.initialNotes,
    this.initialDate,
    this.initialStaffId,
    this.initialSaleId,
  });

  final List<Salon> salons;
  final List<Client> clients;
  final List<StaffMember> staff;
  final List<Service> services;
  final List<ServicePackage> packages;
  final List<InventoryItem> inventoryItems;
  final String? defaultSalonId;
  final String? initialClientId;
  final List<SaleItem>? initialItems;
  final PaymentMethod? initialPaymentMethod;
  final SalePaymentStatus? initialPaymentStatus;
  final double? initialPaidAmount;
  final double? initialDiscountAmount;
  final String? initialInvoiceNumber;
  final String? initialNotes;
  final DateTime? initialDate;
  final String? initialStaffId;
  final String? initialSaleId;

  @override
  State<SaleFormSheet> createState() => _SaleFormSheetState();
}

class _SaleFormSheetState extends State<SaleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _clientFieldKey = GlobalKey<FormFieldState<String>>();
  final _uuid = const Uuid();
  final List<_SaleLineDraft> _lines = [];

  late final TextEditingController _invoiceController;
  late final TextEditingController _notesController;
  late final TextEditingController _discountAmountController;
  late final TextEditingController _discountPercentController;
  late final TextEditingController _manualTotalController;
  late final TextEditingController _paidAmountController;

  PaymentMethod? _payment;
  SalePaymentStatus? _paymentStatus;
  String? _salonId;
  String? _clientId;
  String? _staffId;
  DateTime _date = DateTime.now();
  bool _manualTotalEnabled = false;
  bool _programmaticDiscountUpdate = false;
  bool _programmaticPaidUpdate = false;

  @override
  void initState() {
    super.initState();
    _invoiceController = TextEditingController(
      text: widget.initialInvoiceNumber ?? '',
    );
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
    _discountAmountController = TextEditingController(
      text: (widget.initialDiscountAmount ?? 0).toStringAsFixed(2),
    );
    _discountPercentController = TextEditingController();
    _manualTotalController = TextEditingController();
    _paidAmountController = TextEditingController();
    _payment = widget.initialPaymentMethod;
    _paymentStatus = widget.initialPaymentStatus;
    _date = widget.initialDate ?? DateTime.now();
    _salonId =
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _staffId = widget.initialStaffId;

    if (widget.initialClientId != null) {
      final initialClient = widget.clients.firstWhereOrNull(
        (client) => client.id == widget.initialClientId,
      );
      if (initialClient != null) {
        _clientId = initialClient.id;
        _salonId ??= initialClient.salonId;
      }
    }

    if (_staffId != null) {
      final matchesSalon = widget.staff.any(
        (member) => member.id == _staffId && member.salonId == _salonId,
      );
      if (!matchesSalon) {
        _staffId = null;
      }
    }

    _discountAmountController.addListener(_handleDiscountAmountChanged);
    _discountPercentController.addListener(_handleDiscountPercentChanged);
    _manualTotalController.addListener(_handleManualTotalChanged);
    _paidAmountController.addListener(_handlePaidAmountChanged);

    final initialItems = widget.initialItems;
    if (initialItems != null && initialItems.isNotEmpty) {
      for (final item in initialItems) {
        final draft = _lineFromSaleItem(item);
        _attachLineListeners(draft);
        _lines.add(draft);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncDiscountControllers(force: true);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncDiscountControllers(force: true);
      });
    }

    final initialPaid = widget.initialPaidAmount;
    if (initialPaid != null && initialPaid > 0) {
      _paidAmountController.text = initialPaid.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _discountAmountController.removeListener(_handleDiscountAmountChanged);
    _discountPercentController.removeListener(_handleDiscountPercentChanged);
    _manualTotalController.removeListener(_handleManualTotalChanged);
    _paidAmountController.removeListener(_handlePaidAmountChanged);
    _discountAmountController.dispose();
    _discountPercentController.dispose();
    _manualTotalController.dispose();
    _paidAmountController.dispose();
    _invoiceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final subtotal = _computeSubtotal();
    final discount = _currentDiscount(subtotal);
    final total = _currentTotal(subtotal, discount);
    _syncPaidAmountWithTotal(total);

    final clients =
        widget.clients
            .where((client) => _salonId == null || client.salonId == _salonId)
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final staff =
        widget.staff
            .where((member) => _salonId == null || member.salonId == _salonId)
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Registra vendita', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
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
              onChanged: (value) {
                if (value == _salonId) {
                  return;
                }
                setState(() {
                  _salonId = value;
                  _clientId = null;
                  _staffId = null;
                  _resetLines();
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _clientFieldKey.currentState?.didChange(_clientId);
                });
                _syncDiscountControllers(force: true);
              },
            ),
            const SizedBox(height: 12),
            FormField<String>(
              key: _clientFieldKey,
              validator:
                  (_) => _clientId == null ? 'Seleziona un cliente' : null,
              builder: (state) {
                final selectedClient = widget.clients.firstWhereOrNull(
                  (client) => client.id == _clientId,
                );
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _selectClient(clients),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Cliente',
                      errorText: state.errorText,
                      suffixIcon: const Icon(Icons.search_rounded, size: 20),
                    ),
                    isEmpty: selectedClient == null,
                    child: Text(
                      selectedClient?.fullName ?? 'Seleziona cliente',
                      style:
                          selectedClient == null
                              ? Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Theme.of(context).hintColor)
                              : Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _staffId,
              decoration: const InputDecoration(
                labelText: 'Staff che ha effettuato la vendita',
              ),
              items:
                  staff
                      .map(
                        (member) => DropdownMenuItem(
                          value: member.id,
                          child: Text(member.fullName),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _staffId = value),
            ),
            const SizedBox(height: 20),
            Text('Elementi vendita', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _onAddService,
                  icon: const Icon(Icons.design_services_rounded),
                  label: const Text('Aggiungi servizio'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _onAddPackage,
                  icon: const Icon(Icons.card_giftcard_rounded),
                  label: const Text('Aggiungi pacchetto'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _onAddCustomPackage,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Personalizza pacchetto'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _onAddInventoryItem,
                  icon: const Icon(Icons.inventory_2_rounded),
                  label: const Text('Aggiungi prodotto'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _onAddManualItem,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Voce manuale'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_lines.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Aggiungi almeno un servizio, pacchetto o prodotto per registrare la vendita.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < _lines.length; i++) ...[
                    _buildLineCard(_lines[i], i, currency),
                    if (i < _lines.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            const SizedBox(height: 16),
            _buildSummarySection(currency, subtotal, discount, total),
            const SizedBox(height: 20),
            DropdownButtonFormField<PaymentMethod>(
              value: _payment,
              decoration: const InputDecoration(
                labelText: 'Metodo di pagamento',
              ),
              items:
                  PaymentMethod.values
                      .map(
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(_paymentLabel(method)),
                        ),
                      )
                      .toList(),
              validator:
                  (value) =>
                      value == null ? 'Seleziona il metodo di pagamento' : null,
              onChanged: (value) => setState(() => _payment = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SalePaymentStatus>(
              value: _paymentStatus,
              decoration: const InputDecoration(labelText: 'Stato pagamento'),
              items:
                  SalePaymentStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
              validator:
                  (value) =>
                      value == null ? 'Seleziona lo stato del pagamento' : null,
              onChanged: (value) {
                setState(() {
                  _paymentStatus = value;
                });
                if (value != SalePaymentStatus.deposit) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }
                    _setPaidAmountText('');
                  });
                }
              },
            ),
            if (_paymentStatus == SalePaymentStatus.deposit) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _paidAmountController,
                decoration: const InputDecoration(
                  labelText: 'Importo incassato (€)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (_paymentStatus != SalePaymentStatus.deposit) {
                    return null;
                  }
                  final amount = _parseAmount(value);
                  if (amount == null || amount <= 0) {
                    return 'Inserisci un importo valido';
                  }
                  if (amount > total + 0.01) {
                    return 'L\'acconto supera il totale';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Residuo da incassare: ${currency.format(_remainingBalance(total))}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data e ora vendita'),
              subtitle: Text(dateFormat.format(_date)),
              trailing: const Icon(Icons.calendar_month_rounded),
              onTap: _pickDateTime,
            ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 3,
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

  Widget _buildLineCard(_SaleLineDraft line, int index, NumberFormat currency) {
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
                  onPressed: () => _removeLine(line.id),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            if (line.catalogLabel != null && line.catalogLabel!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line.catalogLabel!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            TextFormField(
              controller: line.descriptionController,
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
                    decoration: const InputDecoration(labelText: 'Quantità'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final quantity = _parseAmount(value);
                      if (quantity == null || quantity <= 0) {
                        return 'Quantità non valida';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: line.priceController,
                    decoration: const InputDecoration(
                      labelText: 'Prezzo unitario (€)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final price = _parseAmount(value);
                      if (price == null || price <= 0) {
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
                'Totale riga: ${currency.format(lineTotal)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(
    NumberFormat currency,
    double subtotal,
    double discount,
    double total,
  ) {
    final theme = Theme.of(context);
    final discountPercent = subtotal <= 0 ? 0 : (discount / subtotal) * 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotale'),
                Text(currency.format(subtotal)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _discountAmountController,
                    enabled: !_manualTotalEnabled,
                    decoration: const InputDecoration(labelText: 'Sconto (€)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (_manualTotalEnabled) {
                        return null;
                      }
                      final amount = _parseAmount(value) ?? 0;
                      if (amount < 0) {
                        return 'Valore non valido';
                      }
                      final currentSubtotal = _computeSubtotal();
                      if (amount > currentSubtotal + 0.01) {
                        return 'Sconto superiore al totale';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _discountPercentController,
                    enabled: !_manualTotalEnabled,
                    decoration: const InputDecoration(labelText: 'Sconto (%)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (_manualTotalEnabled ||
                          value == null ||
                          value.trim().isEmpty) {
                        return null;
                      }
                      final percent = _parseAmount(value);
                      if (percent == null) {
                        return 'Valore non valido';
                      }
                      if (percent < 0) {
                        return 'Valore non valido';
                      }
                      if (percent > 100) {
                        return 'Oltre 100%';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sconto applicato: ${currency.format(discount)} (${discountPercent.toStringAsFixed(discountPercent.abs() < 10 ? 1 : 0)}%)',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Imposta manualmente l\'importo finale'),
              value: _manualTotalEnabled,
              onChanged:
                  (value) => _toggleManualTotal(value, subtotal, discount),
            ),
            if (_manualTotalEnabled) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _manualTotalController,
                decoration: const InputDecoration(
                  labelText: 'Totale finale (€)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (!_manualTotalEnabled) {
                    return null;
                  }
                  final manual = _parseAmount(value);
                  if (manual == null) {
                    return 'Inserisci il totale finale';
                  }
                  if (manual < 0) {
                    return 'Valore non valido';
                  }
                  final currentSubtotal = _computeSubtotal();
                  if (manual > currentSubtotal + 0.01) {
                    return 'Supera il totale degli articoli';
                  }
                  if (manual == 0) {
                    return 'Il totale deve essere positivo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Totale da incassare'),
                Text(
                  currency.format(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _attachLineListeners(_SaleLineDraft line) {
    line.quantityController.addListener(_handleLineChanged);
    line.priceController.addListener(_handleLineChanged);
  }

  void _registerLine(_SaleLineDraft line) {
    _attachLineListeners(line);
    setState(() {
      _lines.add(line);
    });
    _syncDiscountControllers(force: true);
  }

  void _removeLine(String id) {
    final index = _lines.indexWhere((line) => line.id == id);
    if (index == -1) {
      return;
    }
    final line = _lines[index];
    setState(() {
      _lines.removeAt(index);
      if (_lines.isEmpty) {
        _manualTotalEnabled = false;
        _manualTotalController.clear();
      }
    });
    line.dispose();
    _syncDiscountControllers(force: true);
  }

  void _resetLines() {
    for (final line in _lines) {
      line.dispose();
    }
    _lines.clear();
    _manualTotalEnabled = false;
    _manualTotalController.clear();
    _discountAmountController.text = '0';
    _discountPercentController.clear();
  }

  Future<void> _selectClient(List<Client> clients) async {
    final selected = await showAppModalSheet<Client>(
      context: context,
      builder: (ctx) => ClientSearchSheet(clients: clients),
    );

    if (selected != null) {
      setState(() {
        _clientId = selected.id;
      });
      _clientFieldKey.currentState?.didChange(selected.id);
    }
  }

  Future<void> _onAddService() async {
    final salonId = _salonId;
    if (salonId == null) {
      _showSnackBar('Seleziona prima un salone.');
      return;
    }
    final services = _servicesForSalon(salonId);
    if (services.isEmpty) {
      _showSnackBar('Nessun servizio disponibile per il salone selezionato.');
      return;
    }
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final selected = await _pickFromCatalog<Service>(
      title: 'Scegli un servizio',
      items: services,
      labelBuilder: (service) => service.name,
      subtitleBuilder:
          (service) =>
              '${service.category} • ${currency.format(service.price)}',
    );
    if (selected == null) {
      return;
    }
    final line = _createLineDraft(
      referenceType: SaleReferenceType.service,
      referenceId: selected.id,
      description: selected.name,
      quantity: 1,
      unitPrice: selected.price,
      catalogLabel: selected.category,
    );
    _registerLine(line);
  }

  Future<void> _onAddPackage() async {
    final salonId = _salonId;
    if (salonId == null) {
      _showSnackBar('Seleziona prima un salone.');
      return;
    }
    final packages = _packagesForSalon(salonId);
    if (packages.isEmpty) {
      _showSnackBar('Nessun pacchetto disponibile per il salone selezionato.');
      return;
    }
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final selected = await _pickFromCatalog<ServicePackage>(
      title: 'Scegli un pacchetto',
      items: packages,
      labelBuilder: (pkg) => pkg.name,
      subtitleBuilder:
          (pkg) =>
              'Catalogo ${currency.format(pkg.fullPrice)} • Prezzo ${currency.format(pkg.price)}',
    );
    if (selected == null) {
      return;
    }
    _registerPackageLine(selected);
  }

  Future<void> _onAddInventoryItem() async {
    final salonId = _salonId;
    if (salonId == null) {
      _showSnackBar('Seleziona prima un salone.');
      return;
    }
    final items = _inventoryForSalon(salonId);
    if (items.isEmpty) {
      _showSnackBar('Nessun prodotto disponibile per il salone selezionato.');
      return;
    }
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final selected = await _pickFromCatalog<InventoryItem>(
      title: 'Scegli un prodotto',
      items: items,
      labelBuilder: (item) => item.name,
      subtitleBuilder:
          (item) => '${item.category} • ${currency.format(item.sellingPrice)}',
    );
    if (selected == null) {
      return;
    }
    final line = _createLineDraft(
      referenceType: SaleReferenceType.product,
      referenceId: selected.id,
      description: selected.name,
      quantity: 1,
      unitPrice:
          selected.sellingPrice > 0 ? selected.sellingPrice : selected.cost,
      catalogLabel: selected.category,
    );
    _registerLine(line);
  }

  void _onAddManualItem() {
    final line = _createLineDraft(
      referenceType: SaleReferenceType.product,
      description: 'Voce manuale',
      quantity: 1,
      unitPrice: 0,
    );
    _registerLine(line);
  }

  Future<void> _onAddCustomPackage() async {
    final salonId = _salonId;
    if (salonId == null) {
      _showSnackBar('Seleziona prima un salone.');
      return;
    }

    var salons = widget.salons.where((salon) => salon.id == salonId).toList();
    if (salons.isEmpty) {
      salons = widget.salons;
    }

    var services =
        widget.services.where((service) => service.salonId == salonId).toList();
    if (services.isEmpty) {
      services = widget.services;
    }

    if (salons.isEmpty || services.isEmpty) {
      _showSnackBar(
        'Nessun salone o servizio disponibile per creare un pacchetto personalizzato.',
      );
      return;
    }

    final customPackage = await showAppModalSheet<ServicePackage>(
      context: context,
      builder:
          (ctx) => PackageFormSheet(
            salons: salons,
            services: services,
            defaultSalonId: salonId,
          ),
    );

    if (!mounted || customPackage == null) {
      return;
    }

    _registerPackageLine(customPackage, isCustom: true);
  }

  void _registerPackageLine(ServicePackage pkg, {bool isCustom = false}) {
    final metadata = _PackageMetadata(
      isCustom: isCustom,
      sessionCount: pkg.totalConfiguredSessions,
      serviceSessions: Map<String, int>.from(pkg.serviceSessionCounts),
      validDays: pkg.validDays,
      status: PackagePurchaseStatus.active,
    );
    final description = pkg.name;
    final catalogLabel =
        pkg.description != null && pkg.description!.isNotEmpty
            ? pkg.description
            : null;
    final line = _createLineDraft(
      referenceType: SaleReferenceType.package,
      referenceId: pkg.id,
      description: description,
      quantity: 1,
      unitPrice: pkg.price,
      catalogLabel: catalogLabel,
      packageMetadata: metadata,
    );
    _registerLine(line);
  }

  Future<T?> _pickFromCatalog<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelBuilder,
    String Function(T)? subtitleBuilder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, index) {
              if (index == 0) {
                return ListTile(
                  title: Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                );
              }
              final item = items[index - 1];
              final subtitle = subtitleBuilder?.call(item);
              return ListTile(
                title: Text(labelBuilder(item)),
                subtitle:
                    subtitle == null || subtitle.isEmpty
                        ? null
                        : Text(subtitle),
                onTap: () => Navigator.of(ctx).pop(item),
              );
            },
          ),
        );
      },
    );
  }

  List<Service> _servicesForSalon(String salonId) {
    return widget.services
        .where((service) => service.salonId == salonId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<ServicePackage> _packagesForSalon(String salonId) {
    return widget.packages.where((pkg) => pkg.salonId == salonId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<InventoryItem> _inventoryForSalon(String salonId) {
    return widget.inventoryItems
        .where((item) => item.salonId == salonId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  _SaleLineDraft _createLineDraft({
    required SaleReferenceType referenceType,
    String? referenceId,
    required String description,
    double quantity = 1,
    double unitPrice = 0,
    String? catalogLabel,
    _PackageMetadata? packageMetadata,
  }) {
    String formatQuantity(double value) {
      if (value % 1 == 0) {
        return value.toStringAsFixed(0);
      }
      return value.toStringAsFixed(2);
    }

    return _SaleLineDraft(
      id: _uuid.v4(),
      referenceType: referenceType,
      referenceId: referenceId,
      catalogLabel: catalogLabel,
      descriptionController: TextEditingController(text: description),
      quantityController: TextEditingController(text: formatQuantity(quantity)),
      priceController: TextEditingController(
        text: unitPrice.toStringAsFixed(2),
      ),
      packageMetadata: packageMetadata,
    );
  }

  _SaleLineDraft _lineFromSaleItem(SaleItem item) {
    _PackageMetadata? metadata;
    if (item.referenceType == SaleReferenceType.package) {
      final package = widget.packages.firstWhereOrNull(
        (pkg) => pkg.id == item.referenceId,
      );
      final packageSessions =
          item.packageServiceSessions.isNotEmpty
              ? Map<String, int>.from(item.packageServiceSessions)
              : package != null
              ? Map<String, int>.from(package.serviceSessionCounts)
              : <String, int>{};
      int? sessionCount;
      if (packageSessions.isEmpty) {
        if (package?.totalConfiguredSessions != null) {
          sessionCount = package!.totalConfiguredSessions;
        } else if (item.totalSessions != null && item.quantity > 0) {
          sessionCount = (item.totalSessions! / item.quantity).round();
        }
      } else {
        sessionCount = packageSessions.values.fold<int>(
          0,
          (sum, value) => sum + value,
        );
      }
      metadata = _PackageMetadata(
        isCustom: package == null,
        sessionCount: sessionCount,
        serviceSessions: packageSessions,
        validDays: package?.validDays,
        status: item.packageStatus ?? PackagePurchaseStatus.active,
        remainingSessions: item.remainingSessions,
        expirationDate: item.expirationDate,
      );
    }

    return _createLineDraft(
      referenceType: item.referenceType,
      referenceId: item.referenceId,
      description: item.description,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      packageMetadata: metadata,
    );
  }

  void _handleLineChanged() {
    if (_manualTotalEnabled) {
      setState(() {});
      return;
    }
    _syncDiscountControllers();
  }

  void _handleDiscountAmountChanged() {
    if (_manualTotalEnabled || _programmaticDiscountUpdate) {
      return;
    }
    final subtotal = _computeSubtotal();
    _programmaticDiscountUpdate = true;
    var amount = _parseAmount(_discountAmountController.text) ?? 0;
    if (subtotal <= 0) {
      amount = 0;
      _discountAmountController.text = '0';
      _discountPercentController.clear();
    } else {
      if (amount < 0) {
        amount = 0;
        _discountAmountController.text = '0';
      }
      if (amount > subtotal) {
        amount = subtotal;
        _discountAmountController.text = subtotal.toStringAsFixed(2);
      }
      if (amount == 0) {
        _discountPercentController.clear();
      } else {
        final percent = (amount / subtotal) * 100;
        _discountPercentController.text = percent.toStringAsFixed(
          percent.abs() < 10 ? 1 : 0,
        );
      }
    }
    _programmaticDiscountUpdate = false;
    setState(() {});
  }

  void _handleDiscountPercentChanged() {
    if (_manualTotalEnabled || _programmaticDiscountUpdate) {
      return;
    }
    final subtotal = _computeSubtotal();
    _programmaticDiscountUpdate = true;
    final rawText = _discountPercentController.text;
    final hasInput = rawText.trim().isNotEmpty;
    var percent = hasInput ? (_parseAmount(rawText) ?? 0) : 0;

    void updatePercentText(String value) {
      _discountPercentController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }

    if (!hasInput) {
      percent = 0;
    } else if (percent < 0) {
      percent = 0;
      updatePercentText('0');
    } else if (percent > 100) {
      percent = 100;
      updatePercentText('100');
    }

    if (subtotal <= 0) {
      if (_discountPercentController.text.isNotEmpty) {
        _discountPercentController.clear();
      }
      _discountAmountController.text = '0';
      _programmaticDiscountUpdate = false;
      setState(() {});
      return;
    }

    final amount = subtotal * percent / 100;
    _discountAmountController.text =
        amount == 0 ? '0' : amount.toStringAsFixed(2);
    _programmaticDiscountUpdate = false;
    setState(() {});
  }

  void _handleManualTotalChanged() {
    if (_manualTotalEnabled) {
      setState(() {});
    }
  }

  void _handlePaidAmountChanged() {
    if (_programmaticPaidUpdate) {
      return;
    }
    setState(() {});
  }

  void _syncPaidAmountWithTotal(double total) {
    if (_paymentStatus != SalePaymentStatus.deposit) {
      if (_paidAmountController.text.isEmpty) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _setPaidAmountText('');
      });
      return;
    }

    final amount = _parseAmount(_paidAmountController.text);
    if (amount == null) {
      if (_paidAmountController.text.isEmpty || total > 0) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _setPaidAmountText('');
      });
      return;
    }

    var clamped = amount;
    if (clamped < 0) {
      clamped = 0;
    }
    if (clamped > total) {
      clamped = total;
    }
    if ((clamped - amount).abs() > 0.01) {
      final next = clamped == 0 ? '' : clamped.toStringAsFixed(2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _setPaidAmountText(next);
      });
    }
  }

  void _setPaidAmountText(String value) {
    if (_paidAmountController.text == value) {
      return;
    }
    _programmaticPaidUpdate = true;
    _paidAmountController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _programmaticPaidUpdate = false;
    setState(() {});
  }

  double _remainingBalance(double total) {
    final paid = _parseAmount(_paidAmountController.text) ?? 0;
    final remaining = total - paid;
    if (remaining <= 0) {
      return 0;
    }
    return double.parse(remaining.toStringAsFixed(2));
  }

  void _syncDiscountControllers({bool force = false}) {
    if (_manualTotalEnabled) {
      setState(() {});
      return;
    }
    if (!force && _programmaticDiscountUpdate) {
      return;
    }
    final subtotal = _computeSubtotal();
    _programmaticDiscountUpdate = true;
    if (subtotal <= 0) {
      _discountAmountController.text = '0';
      _discountPercentController.clear();
    } else {
      var amount = _parseAmount(_discountAmountController.text) ?? 0;
      if (amount < 0) {
        amount = 0;
      }
      if (amount > subtotal) {
        amount = subtotal;
      }
      _discountAmountController.text = amount.toStringAsFixed(2);
      if (amount == 0) {
        _discountPercentController.clear();
      } else {
        final percent = (amount / subtotal) * 100;
        _discountPercentController.text = percent.toStringAsFixed(
          percent.abs() < 10 ? 1 : 0,
        );
      }
    }
    _programmaticDiscountUpdate = false;
    setState(() {});
  }

  void _toggleManualTotal(bool enabled, double subtotal, double discount) {
    if (_manualTotalEnabled == enabled) {
      return;
    }
    setState(() {
      _manualTotalEnabled = enabled;
      if (enabled) {
        final current = subtotal - discount;
        final base = current > 0 ? current : subtotal;
        _manualTotalController.text = base > 0 ? base.toStringAsFixed(2) : '';
      } else {
        _manualTotalController.clear();
        _syncDiscountControllers(force: true);
      }
    });
  }

  double _computeSubtotal() {
    var total = 0.0;
    for (final line in _lines) {
      final quantity = _parseAmount(line.quantityController.text) ?? 0;
      final price = _parseAmount(line.priceController.text) ?? 0;
      total += (quantity * price);
    }
    return double.parse(total.toStringAsFixed(2));
  }

  double _currentDiscount(double subtotal) {
    if (subtotal <= 0) {
      return 0;
    }
    if (_manualTotalEnabled) {
      final manual = _parseAmount(_manualTotalController.text) ?? subtotal;
      final clamped = manual.clamp(0, subtotal);
      final discount = subtotal - clamped;
      return double.parse(discount.toStringAsFixed(2));
    }
    var amount = _parseAmount(_discountAmountController.text) ?? 0;
    if (amount < 0) {
      amount = 0;
    }
    if (amount > subtotal) {
      amount = subtotal;
    }
    return double.parse(amount.toStringAsFixed(2));
  }

  double _currentTotal(double subtotal, double discount) {
    if (_manualTotalEnabled) {
      final manual = _parseAmount(_manualTotalController.text) ?? subtotal;
      final clamped = manual.clamp(0, subtotal);
      return double.parse(clamped.toStringAsFixed(2));
    }
    final total = subtotal - discount;
    if (total <= 0) {
      return 0;
    }
    return double.parse(total.toStringAsFixed(2));
  }

  double _lineTotal(_SaleLineDraft line) {
    final quantity = _parseAmount(line.quantityController.text) ?? 0;
    final price = _parseAmount(line.priceController.text) ?? 0;
    final total = quantity * price;
    return total <= 0 ? 0 : double.parse(total.toStringAsFixed(2));
  }

  void _pickDateTime() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 120)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (selectedDate == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (selectedTime == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _date = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_salonId == null) {
      _showSnackBar('Seleziona il salone della vendita.');
      return;
    }
    if (_clientId == null) {
      _showSnackBar('Seleziona il cliente.');
      return;
    }
    if (_lines.isEmpty) {
      _showSnackBar('Aggiungi almeno un elemento alla vendita.');
      return;
    }

    final items = <SaleItem>[];
    for (final line in _lines) {
      final description = line.descriptionController.text.trim();
      final quantityValue = _parseAmount(line.quantityController.text) ?? 0;
      final unitPriceValue = _parseAmount(line.priceController.text) ?? 0;
      final quantity = double.parse(quantityValue.toStringAsFixed(2));
      final unitPrice = double.parse(unitPriceValue.toStringAsFixed(2));
      if (description.isEmpty || quantity <= 0 || unitPrice <= 0) {
        _showSnackBar('Controlla le voci inserite: valori non validi.');
        return;
      }
      final referenceId = line.referenceId ?? 'manual-${line.id}';
      final metadata = line.packageMetadata;
      final saleItem =
          line.referenceType == SaleReferenceType.package
              ? SaleItem(
                referenceId: referenceId,
                referenceType: line.referenceType,
                description: description,
                quantity: quantity,
                unitPrice: unitPrice,
                totalSessions: metadata?.totalSessions(quantity),
                remainingSessions: metadata?.remainingSessionsValue(quantity),
                expirationDate: metadata?.expiration(_date),
                packageStatus: metadata?.status,
                packageServiceSessions:
                    metadata?.serviceSessions ?? const <String, int>{},
              )
              : SaleItem(
                referenceId: referenceId,
                referenceType: line.referenceType,
                description: description,
                quantity: quantity,
                unitPrice: unitPrice,
              );
      items.add(saleItem);
    }

    final subtotal = _computeSubtotal();
    if (subtotal <= 0) {
      _showSnackBar('Inserisci importi validi per la vendita.');
      return;
    }
    final discount = _currentDiscount(subtotal);
    final total = _currentTotal(subtotal, discount);
    if (total <= 0) {
      _showSnackBar('Il totale della vendita deve essere positivo.');
      return;
    }

    final invoice = _invoiceController.text.trim();
    final notes = _notesController.text.trim();

    final paymentMethod = _payment;
    if (paymentMethod == null) {
      _showSnackBar('Seleziona il metodo di pagamento.');
      return;
    }
    final selectedStatus = _paymentStatus;
    if (selectedStatus == null) {
      _showSnackBar('Seleziona lo stato del pagamento.');
      return;
    }

    var paymentStatus = selectedStatus;
    double paidAmount;
    if (paymentStatus == SalePaymentStatus.deposit) {
      final amount = _parseAmount(_paidAmountController.text) ?? 0;
      if (amount <= 0) {
        _showSnackBar('Inserisci un importo valido per l\'acconto.');
        return;
      }
      if (amount > total + 0.01) {
        _showSnackBar('L\'acconto supera il totale della vendita.');
        return;
      }
      if ((total - amount).abs() < 0.01) {
        paymentStatus = SalePaymentStatus.paid;
        paidAmount = total;
      } else {
        paidAmount = double.parse(amount.toStringAsFixed(2));
      }
    } else {
      paidAmount = total;
    }

    final adjustedItems = _applyPackagePayments(
      items,
      paymentStatus,
      paidAmount,
      paymentMethod,
    );

    final recordedByName =
        widget.staff
            .firstWhereOrNull((member) => member.id == _staffId)
            ?.fullName;
    final paymentMovements = <SalePaymentMovement>[];
    if (paidAmount > 0) {
      final movementType =
          paymentStatus == SalePaymentStatus.paid
              ? SalePaymentType.settlement
              : SalePaymentType.deposit;
      paymentMovements.add(
        SalePaymentMovement(
          id: _uuid.v4(),
          amount: paidAmount,
          type: movementType,
          date: _date,
          paymentMethod: paymentMethod,
          recordedBy: recordedByName,
          note:
              movementType == SalePaymentType.deposit
                  ? 'Acconto iniziale'
                  : 'Saldo iniziale',
        ),
      );
    }

    final sale = Sale(
      id: widget.initialSaleId ?? _uuid.v4(),
      salonId: _salonId!,
      clientId: _clientId!,
      items: adjustedItems,
      total: double.parse(total.toStringAsFixed(2)),
      createdAt: _date,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      paidAmount: paidAmount,
      invoiceNumber: invoice.isEmpty ? null : invoice,
      notes: notes.isEmpty ? null : notes,
      discountAmount: double.parse(discount.toStringAsFixed(2)),
      staffId: _staffId,
      paymentHistory: paymentMovements,
    );

    Navigator.of(context).pop(sale);
  }

  List<SaleItem> _applyPackagePayments(
    List<SaleItem> items,
    SalePaymentStatus paymentStatus,
    double paidAmount,
    PaymentMethod paymentMethod,
  ) {
    if (!items.any((item) => item.referenceType == SaleReferenceType.package)) {
      return items;
    }
    final updated = <SaleItem>[];
    if (paymentStatus == SalePaymentStatus.deposit) {
      var remaining = paidAmount;
      for (final item in items) {
        if (item.referenceType == SaleReferenceType.package) {
          final lineTotal = item.amount;
          final applied = _normalizeCurrency(
            remaining <= 0
                ? 0
                : remaining >= lineTotal
                ? lineTotal
                : remaining,
          );
          remaining = _normalizeCurrency(remaining - applied);
          final status =
              applied >= lineTotal - 0.009
                  ? PackagePaymentStatus.paid
                  : PackagePaymentStatus.deposit;
          List<PackageDeposit> deposits = item.deposits;
          if (deposits.isEmpty && applied > 0.009) {
            deposits = [
              PackageDeposit(
                id: _uuid.v4(),
                amount: applied,
                date: _date,
                note: 'Acconto iniziale',
                paymentMethod: paymentMethod,
              ),
            ];
          }
          updated.add(
            item.copyWith(
              depositAmount: applied,
              packagePaymentStatus: status,
              deposits: deposits,
            ),
          );
        } else {
          updated.add(item);
        }
      }
    } else {
      for (final item in items) {
        if (item.referenceType == SaleReferenceType.package) {
          updated.add(
            item.copyWith(
              depositAmount: _normalizeCurrency(item.amount),
              packagePaymentStatus: PackagePaymentStatus.paid,
            ),
          );
        } else {
          updated.add(item);
        }
      }
    }
    return updated;
  }

  double _normalizeCurrency(double value) {
    if (value <= 0) {
      return 0;
    }
    return double.parse(value.toStringAsFixed(2));
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

  String _lineTypeLabel(SaleReferenceType type) {
    switch (type) {
      case SaleReferenceType.service:
        return 'Servizio';
      case SaleReferenceType.package:
        return 'Pacchetto';
      case SaleReferenceType.product:
        return 'Prodotto';
    }
  }

  String _paymentLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Contanti';
      case PaymentMethod.pos:
        return 'POS';
      case PaymentMethod.transfer:
        return 'Bonifico';
      case PaymentMethod.giftCard:
        return 'Gift card';
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
}

class _PackageMetadata {
  _PackageMetadata({
    required this.isCustom,
    this.sessionCount,
    Map<String, int>? serviceSessions,
    this.validDays,
    this.status = PackagePurchaseStatus.active,
    this.remainingSessions,
    this.expirationDate,
  }) : serviceSessions =
           serviceSessions == null
               ? const <String, int>{}
               : Map.unmodifiable(serviceSessions);

  final bool isCustom;
  final int? sessionCount;
  final Map<String, int> serviceSessions;
  final int? validDays;
  final PackagePurchaseStatus status;
  final int? remainingSessions;
  final DateTime? expirationDate;

  int? _perPackageSessions() {
    if (serviceSessions.isNotEmpty) {
      return serviceSessions.values.fold<int>(0, (sum, value) => sum + value);
    }
    return sessionCount;
  }

  int? totalSessions(double quantity) {
    final perPackage = _perPackageSessions();
    if (perPackage == null) {
      return null;
    }
    final total = perPackage * quantity;
    return total.isFinite ? total.round() : null;
  }

  int? remainingSessionsValue(double quantity) {
    if (remainingSessions != null) {
      return remainingSessions;
    }
    return totalSessions(quantity);
  }

  DateTime? expiration(DateTime saleDate) {
    if (expirationDate != null) {
      return expirationDate;
    }
    if (validDays == null) {
      return null;
    }
    return saleDate.add(Duration(days: validDays!));
  }
}

class _SaleLineDraft {
  _SaleLineDraft({
    required this.id,
    required this.referenceType,
    this.referenceId,
    this.catalogLabel,
    required this.descriptionController,
    required this.quantityController,
    required this.priceController,
    this.packageMetadata,
  });

  final String id;
  final SaleReferenceType referenceType;
  final String? referenceId;
  final String? catalogLabel;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController priceController;
  final _PackageMetadata? packageMetadata;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}
