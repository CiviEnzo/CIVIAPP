import 'dart:math' as math;

import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PackagePurchaseEditSheet extends StatefulWidget {
  const PackagePurchaseEditSheet({
    super.key,
    required this.initialItem,
    required this.purchaseDate,
    this.package,
  });

  final SaleItem initialItem;
  final DateTime purchaseDate;
  final ServicePackage? package;

  @override
  State<PackagePurchaseEditSheet> createState() =>
      _PackagePurchaseEditSheetState();
}

class _PackagePurchaseEditSheetState extends State<PackagePurchaseEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late PackagePurchaseStatus _status;
  late PackagePaymentStatus _paymentStatus;
  late TextEditingController _totalSessionsController;
  late TextEditingController _remainingSessionsController;
  DateTime? _expirationDate;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _status = item.packageStatus ?? _defaultStatus(item);
    _paymentStatus =
        item.packagePaymentStatus ??
        (item.depositAmount > 0
            ? PackagePaymentStatus.deposit
            : PackagePaymentStatus.paid);
    final initialTotalSessions =
        item.totalSessions ?? _defaultTotalSessions(item);
    final initialRemaining = item.remainingSessions ?? initialTotalSessions;
    _totalSessionsController = TextEditingController(
      text: initialTotalSessions?.toString() ?? '',
    );
    _remainingSessionsController = TextEditingController(
      text: initialRemaining?.toString() ?? '',
    );
    _expirationDate = item.expirationDate ?? _defaultExpiration();
  }

  @override
  void dispose() {
    _totalSessionsController.dispose();
    _remainingSessionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Modifica pacchetto', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<PackagePurchaseStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Stato'),
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
                  (value) => setState(() {
                    _status = value ?? _status;
                  }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PackagePaymentStatus>(
              value: _paymentStatus,
              decoration: const InputDecoration(labelText: 'Pagamento'),
              items:
                  PackagePaymentStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(() {
                    _paymentStatus = value ?? _paymentStatus;
                  }),
            ),
            const SizedBox(height: 12),
            Text(
              'Acconti registrati: ${currency.format(widget.initialItem.depositAmount)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (_outstandingAmount() > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Rimanenza da saldare: ${currency.format(_outstandingAmount())}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Scadenza'),
              subtitle: Text(
                _expirationDate == null
                    ? 'Nessuna scadenza'
                    : dateFormat.format(_expirationDate!),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _totalSessionsController,
              decoration: const InputDecoration(
                labelText: 'Sessioni totali',
                hintText: 'Lascia vuoto per calcolare automaticamente',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }
                final total = int.tryParse(value.trim());
                if (total == null || total <= 0) {
                  return 'Inserisci un numero valido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _remainingSessionsController,
              decoration: const InputDecoration(
                labelText: 'Sessioni rimanenti',
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
                final totalText = _totalSessionsController.text.trim();
                final total = int.tryParse(totalText);
                if (total != null && remaining > total) {
                  return 'Maggiore delle sessioni totali';
                }
                return null;
              },
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

    final totalText = _totalSessionsController.text.trim();
    final remainingText = _remainingSessionsController.text.trim();
    final totalSessions = totalText.isEmpty ? null : int.parse(totalText);
    int? remainingSessions =
        remainingText.isEmpty ? null : int.parse(remainingText);

    if (totalSessions != null &&
        remainingSessions != null &&
        remainingSessions > totalSessions) {
      remainingSessions = totalSessions;
    }

    final updatedItem = widget.initialItem.copyWith(
      packageStatus: _status,
      packagePaymentStatus: _paymentStatus,
      totalSessions: totalSessions,
      remainingSessions: remainingSessions,
      expirationDate: _expirationDate,
    );

    Navigator.of(context).pop(updatedItem);
  }

  Future<void> _pickExpirationDate() async {
    final baseDate =
        _expirationDate ?? _defaultExpiration() ?? widget.purchaseDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: baseDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _expirationDate = selected;
    });
  }

  void _clearExpiration() {
    setState(() {
      _expirationDate = null;
    });
  }

  int? _defaultTotalSessions(SaleItem item) {
    final sessionsPerPackage =
        widget.package?.totalConfiguredSessions ??
        (item.packageServiceSessions.isNotEmpty
            ? item.packageServiceSessions.values.fold<int>(
              0,
              (sum, value) => sum + value,
            )
            : null);
    if (sessionsPerPackage == null) {
      return null;
    }
    return (sessionsPerPackage * item.quantity).round();
  }

  DateTime? _defaultExpiration() {
    final validityDays = widget.package?.validDays;
    if (validityDays == null) {
      return null;
    }
    return widget.purchaseDate.add(Duration(days: validityDays));
  }

  PackagePurchaseStatus _defaultStatus(SaleItem item) {
    final remaining = item.remainingSessions ?? _defaultTotalSessions(item);
    if (remaining != null && remaining <= 0) {
      return PackagePurchaseStatus.completed;
    }
    return PackagePurchaseStatus.active;
  }

  double _totalAmount() => widget.initialItem.amount;

  double _outstandingAmount() {
    final outstanding = _totalAmount() - widget.initialItem.depositAmount;
    return math.max(double.parse(outstanding.toStringAsFixed(2)), 0);
  }
}
