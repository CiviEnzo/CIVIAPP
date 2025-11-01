import 'dart:math' as math;

import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class PackageSaleFormSheet extends StatefulWidget {
  const PackageSaleFormSheet({
    super.key,
    required this.client,
    required this.packages,
  });

  final Client client;
  final List<ServicePackage> packages;

  @override
  State<PackageSaleFormSheet> createState() => _PackageSaleFormSheetState();
}

class _PackageSaleFormSheetState extends State<PackageSaleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _notesController = TextEditingController();
  final _remainingSessionsController = TextEditingController();
  final _depositController = TextEditingController();
  PaymentMethod? _paymentMethod;
  PackagePurchaseStatus _packageStatus = PackagePurchaseStatus.active;
  PackagePaymentStatus? _packagePaymentStatus;
  late ServicePackage _selectedPackage;
  DateTime _saleDate = DateTime.now();
  DateTime? _expirationDate;
  int? _totalSessions;
  bool _remainingEdited = false;
  bool _isUpdatingRemaining = false;
  bool _expirationEdited = false;
  bool _depositEdited = false;
  bool _isUpdatingDeposit = false;

  @override
  void initState() {
    super.initState();
    _selectedPackage = widget.packages.first;
    _priceController.text = _selectedPackage.price.toStringAsFixed(2);
    _totalSessions = _computeTotalSessions();
    if (_totalSessions != null) {
      _remainingSessionsController.text = _totalSessions.toString();
    }
    _expirationDate = _computeDefaultExpiration();
    _quantityController.addListener(_handleQuantityChange);
    _remainingSessionsController.addListener(_handleRemainingChanged);
    _priceController.addListener(_handlePriceChanged);
    _depositController.addListener(_handleDepositChanged);
  }

  @override
  void dispose() {
    _quantityController.removeListener(_handleQuantityChange);
    _remainingSessionsController.removeListener(_handleRemainingChanged);
    _depositController.removeListener(_handleDepositChanged);
    _priceController.removeListener(_handlePriceChanged);
    _quantityController.dispose();
    _priceController.dispose();
    _invoiceController.dispose();
    _notesController.dispose();
    _remainingSessionsController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final fullPrice = _selectedPackage.fullPrice;
    final finalPrice = _selectedPackage.price;
    final hasDiscount = fullPrice > 0 && finalPrice < fullPrice - 0.01;
    final discountPercentage =
        hasDiscount ? ((fullPrice - finalPrice) / fullPrice) * 100 : 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Registra pacchetto', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<ServicePackage>(
              value: _selectedPackage,
              decoration: const InputDecoration(labelText: 'Pacchetto'),
              items:
                  widget.packages
                      .map(
                        (pkg) =>
                            DropdownMenuItem(value: pkg, child: Text(pkg.name)),
                      )
                      .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedPackage = value;
                  _priceController.text = value.price.toStringAsFixed(2);
                  _remainingEdited = false;
                  _expirationEdited = false;
                });
                _applyDerivedDefaults(resetUserInput: true);
              },
            ),
            const SizedBox(height: 8),
            Text(
              hasDiscount
                  ? 'Prezzo pieno catalogo: ${currency.format(fullPrice)}  •  Sconto ${discountPercentage.toStringAsFixed(discountPercentage.abs() < 10 ? 1 : 0)}%'
                  : 'Prezzo pieno catalogo: ${currency.format(fullPrice)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Quantità'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final qty = double.tryParse(value?.replaceAll(',', '.') ?? '');
                if (qty == null || qty <= 0) {
                  return 'Inserisci una quantità valida';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Prezzo unitario (€)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final price = double.tryParse(
                  value?.replaceAll(',', '.') ?? '',
                );
                if (price == null || price <= 0) {
                  return 'Inserisci un prezzo valido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              value: _paymentMethod,
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
              onChanged: (value) => setState(() => _paymentMethod = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PackagePaymentStatus>(
              value: _packagePaymentStatus,
              decoration: const InputDecoration(labelText: 'Stato pagamento'),
              items:
                  PackagePaymentStatus.values
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
                  _packagePaymentStatus = value;
                  if (value != PackagePaymentStatus.deposit) {
                    _isUpdatingDeposit = true;
                    _depositController.clear();
                    _isUpdatingDeposit = false;
                    _depositEdited = false;
                  } else {
                    _depositEdited = false;
                  }
                });
                if (value != null) {
                  _applyDerivedDefaults(resetUserInput: false);
                }
              },
            ),
            const SizedBox(height: 12),
            if (_packagePaymentStatus == PackagePaymentStatus.deposit) ...[
              TextFormField(
                controller: _depositController,
                decoration: const InputDecoration(
                  labelText: 'Importo acconto (€)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (_packagePaymentStatus != PackagePaymentStatus.deposit) {
                    return null;
                  }
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Inserisci l\'importo dell\'acconto';
                  }
                  final deposit = double.tryParse(text.replaceAll(',', '.'));
                  if (deposit == null || deposit <= 0) {
                    return 'Importo non valido';
                  }
                  final total = _saleTotal();
                  if (deposit > total) {
                    return 'L\'acconto supera il totale';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              _AmountSummary(
                total: _saleTotal(),
                deposit: _parseDepositAmount() ?? 0,
                currency: NumberFormat.simpleCurrency(locale: 'it_IT'),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<PackagePurchaseStatus>(
              value: _packageStatus,
              decoration: const InputDecoration(labelText: 'Stato pacchetto'),
              items:
                  PackagePurchaseStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(
                    () =>
                        _packageStatus = value ?? PackagePurchaseStatus.active,
                  ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data e ora vendita'),
              subtitle: Text(dateFormat.format(_saleDate)),
              trailing: const Icon(Icons.calendar_month_rounded),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Scadenza pacchetto'),
              subtitle: Text(
                _expirationDate == null
                    ? 'Nessuna scadenza'
                    : DateFormat('dd/MM/yyyy').format(_expirationDate!),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_expirationDate != null)
                    IconButton(
                      tooltip: 'Rimuovi scadenza',
                      onPressed: _clearExpiration,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  IconButton(
                    tooltip: 'Modifica scadenza',
                    onPressed: _pickExpirationDate,
                    icon: const Icon(Icons.edit_calendar_rounded),
                  ),
                ],
              ),
            ),
            if (_totalSessions != null) ...[
              const SizedBox(height: 12),
              Text('Totale sessioni previste: $_totalSessions'),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _remainingSessionsController,
              decoration: const InputDecoration(
                labelText: 'Sessioni rimanenti',
                hintText: 'Lascia vuoto per non impostare',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }
                final remaining = int.tryParse(value.trim());
                if (remaining == null || remaining < 0) {
                  return 'Inserisci un numero valido';
                }
                if (_totalSessions != null && remaining > _totalSessions!) {
                  return 'Valore maggiore delle sessioni totali';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _invoiceController,
              decoration: const InputDecoration(
                labelText: 'Numero fattura / scontrino',
              ),
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

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime.now().subtract(const Duration(days: 120)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_saleDate),
    );
    if (time == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _saleDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
    _applyDerivedDefaults(resetUserInput: false);
  }

  Future<void> _pickExpirationDate() async {
    final initialDate =
        _expirationDate ?? _computeDefaultExpiration() ?? _saleDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _saleDate,
      lastDate: _saleDate.add(const Duration(days: 720)),
    );
    if (selected == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _expirationDate = selected;
      _expirationEdited = true;
    });
  }

  void _clearExpiration() {
    setState(() {
      _expirationDate = null;
      _expirationEdited = true;
    });
  }

  void _handleQuantityChange() {
    _applyDerivedDefaults(resetUserInput: false);
  }

  void _handlePriceChanged() {
    setState(() {});
  }

  void _handleRemainingChanged() {
    if (_isUpdatingRemaining) {
      return;
    }
    _remainingEdited = true;
  }

  void _handleDepositChanged() {
    if (_isUpdatingDeposit) {
      return;
    }
    _depositEdited = true;
    setState(() {});
  }

  void _applyDerivedDefaults({required bool resetUserInput}) {
    final totalSessions = _computeTotalSessions();
    final shouldResetRemaining = resetUserInput || !_remainingEdited;
    final defaultExpiration = _computeDefaultExpiration();
    final shouldResetExpiration = resetUserInput || !_expirationEdited;
    final shouldResetDeposit =
        resetUserInput ||
        !_depositEdited ||
        _packagePaymentStatus != PackagePaymentStatus.deposit;

    setState(() {
      _totalSessions = totalSessions;
      if (shouldResetRemaining) {
        _isUpdatingRemaining = true;
        if (totalSessions != null) {
          _remainingSessionsController.text = totalSessions.toString();
        } else {
          _remainingSessionsController.clear();
        }
        _isUpdatingRemaining = false;
        _remainingEdited = false;
      }
      if (shouldResetExpiration) {
        _expirationDate = defaultExpiration;
        _expirationEdited = false;
      }
      if (shouldResetDeposit) {
        _isUpdatingDeposit = true;
        _depositController.clear();
        _isUpdatingDeposit = false;
        _depositEdited = false;
      } else if (_packagePaymentStatus == PackagePaymentStatus.deposit) {
        final total = _saleTotal();
        final currentDeposit = _parseDepositAmount() ?? 0;
        if (currentDeposit > total) {
          _isUpdatingDeposit = true;
          _depositController.text = total.toStringAsFixed(2);
          _isUpdatingDeposit = false;
        }
      }
    });
  }

  int? _computeTotalSessions() {
    final quantity = double.tryParse(
      _quantityController.text.replaceAll(',', '.'),
    );
    if (quantity == null) {
      return _selectedPackage.totalConfiguredSessions;
    }
    return _calculateTotalSessions(quantity);
  }

  int? _calculateTotalSessions(double quantity) {
    final sessionsPerPackage = _selectedPackage.totalConfiguredSessions;
    if (sessionsPerPackage == null) {
      return null;
    }
    return (sessionsPerPackage * quantity).round();
  }

  DateTime? _computeDefaultExpiration() {
    final validityDays = _selectedPackage.validDays;
    if (validityDays == null) {
      return null;
    }
    return _saleDate.add(Duration(days: validityDays));
  }

  double _saleTotal() {
    final quantity = double.tryParse(
      _quantityController.text.replaceAll(',', '.'),
    );
    final price = double.tryParse(_priceController.text.replaceAll(',', '.'));
    if (quantity == null || price == null) {
      return 0;
    }
    return double.parse((quantity * price).toStringAsFixed(2));
  }

  double? _parseDepositAmount() {
    if (_packagePaymentStatus != PackagePaymentStatus.deposit) {
      return null;
    }
    final text = _depositController.text.trim();
    if (text.isEmpty) {
      return null;
    }
    return double.tryParse(text.replaceAll(',', '.'));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final paymentMethod = _paymentMethod;
    if (paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona il metodo di pagamento.')),
      );
      return;
    }
    final packagePaymentStatus = _packagePaymentStatus;
    if (packagePaymentStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona lo stato del pagamento.')),
      );
      return;
    }

    final quantity = double.parse(
      _quantityController.text.replaceAll(',', '.'),
    );
    final price = double.parse(_priceController.text.replaceAll(',', '.'));
    final total = double.parse((quantity * price).toStringAsFixed(2));
    final totalSessions = _calculateTotalSessions(quantity);
    final remainingText = _remainingSessionsController.text.trim();
    int? remainingSessions;
    if (remainingText.isNotEmpty) {
      remainingSessions = int.tryParse(remainingText);
      if (remainingSessions != null && remainingSessions < 0) {
        remainingSessions = 0;
      }
      if (remainingSessions != null &&
          totalSessions != null &&
          remainingSessions > totalSessions) {
        remainingSessions = totalSessions;
      }
    }
    final expirationDate = _expirationDate;
    double? depositAmount;
    var deposits = <PackageDeposit>[];
    if (packagePaymentStatus == PackagePaymentStatus.deposit) {
      depositAmount = _parseDepositAmount();
      if (depositAmount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inserisci un importo per l\'acconto')),
        );
        return;
      }
      depositAmount = double.parse(depositAmount.toStringAsFixed(2));
      if (depositAmount > total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('L\'acconto supera il totale.')),
        );
        return;
      }
      deposits = [
        PackageDeposit(
          id: _uuid.v4(),
          amount: depositAmount,
          date: _saleDate,
          paymentMethod: paymentMethod,
          note: 'Acconto iniziale',
        ),
      ];
    } else if (packagePaymentStatus == PackagePaymentStatus.paid) {
      depositAmount = total;
      deposits = [
        PackageDeposit(
          id: _uuid.v4(),
          amount: total,
          date: _saleDate,
          paymentMethod: paymentMethod,
          note: 'Saldato',
        ),
      ];
    }

    var paymentStatus = packagePaymentStatus;
    if (paymentStatus == PackagePaymentStatus.deposit) {
      final outstanding = double.parse(
        (total - (depositAmount ?? 0)).toStringAsFixed(2),
      );
      if (outstanding <= 0) {
        paymentStatus = PackagePaymentStatus.paid;
      }
    }

    if (paymentStatus == PackagePaymentStatus.paid && deposits.isNotEmpty) {
      final lastDeposit = deposits.last;
      if (lastDeposit.note != 'Saldato') {
        deposits[deposits.length - 1] = lastDeposit.copyWith(note: 'Saldato');
      }
    }

    final salePaymentStatus =
        paymentStatus == PackagePaymentStatus.deposit
            ? SalePaymentStatus.deposit
            : SalePaymentStatus.paid;
    final salePaidAmount =
        salePaymentStatus == SalePaymentStatus.deposit
            ? (depositAmount ?? 0)
            : total;

    final salePaymentMovements = <SalePaymentMovement>[];
    if (salePaidAmount > 0) {
      final movementType =
          salePaymentStatus == SalePaymentStatus.paid
              ? SalePaymentType.settlement
              : SalePaymentType.deposit;
      salePaymentMovements.add(
        SalePaymentMovement(
          id: _uuid.v4(),
          amount: salePaidAmount,
          type: movementType,
          date: _saleDate,
          paymentMethod: paymentMethod,
          note:
              movementType == SalePaymentType.deposit
                  ? 'Acconto iniziale'
                  : 'Saldo iniziale',
        ),
      );
    }

    final sale = Sale(
      id: _uuid.v4(),
      salonId: widget.client.salonId,
      clientId: widget.client.id,
      items: [
        SaleItem(
          referenceId: _selectedPackage.id,
          referenceType: SaleReferenceType.package,
          description: _selectedPackage.name,
          quantity: quantity,
          unitPrice: price,
          totalSessions: totalSessions,
          remainingSessions: remainingSessions,
          expirationDate: expirationDate,
          packageStatus: _packageStatus,
          packagePaymentStatus: paymentStatus,
          deposits: deposits,
          packageServiceSessions: _selectedPackage.serviceSessionCounts,
        ),
      ],
      total: total,
      createdAt: _saleDate,
      paymentMethod: paymentMethod,
      paymentStatus: salePaymentStatus,
      paidAmount: salePaidAmount,
      invoiceNumber:
          _invoiceController.text.trim().isEmpty
              ? null
              : _invoiceController.text.trim(),
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      paymentHistory: salePaymentMovements,
      metadata: const {'source': 'backoffice'},
    );

    Navigator.of(context).pop(sale);
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
}

class _AmountSummary extends StatelessWidget {
  const _AmountSummary({
    required this.total,
    required this.deposit,
    required this.currency,
  });

  final double total;
  final double deposit;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final remaining = math.max(total - deposit, 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Totale pacchetto: ${currency.format(total)}'),
        const SizedBox(height: 4),
        Text('Rimanenza da saldare: ${currency.format(remaining)}'),
      ],
    );
  }
}
