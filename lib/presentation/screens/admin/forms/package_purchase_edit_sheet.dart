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
  late TextEditingController _remainingSessionsController;
  int? _initialTotalSessions;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _status = item.packageStatus ?? _defaultStatus(item);
    _initialTotalSessions = item.totalSessions ?? _defaultTotalSessions(item);
    final initialRemaining = item.remainingSessions ?? _initialTotalSessions;
    _remainingSessionsController = TextEditingController(
      text: initialRemaining?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _remainingSessionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Text(
              _initialTotalSessions == null
                  ? 'Sessioni totali registrate: non definite'
                  : 'Sessioni totali registrate: $_initialTotalSessions',
              style: theme.textTheme.bodyMedium,
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
                final total = _initialTotalSessions;
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

    final remainingText = _remainingSessionsController.text.trim();
    int? remainingSessions =
        remainingText.isEmpty ? null : int.parse(remainingText);

    if (_initialTotalSessions != null &&
        remainingSessions != null &&
        remainingSessions > _initialTotalSessions!) {
      remainingSessions = _initialTotalSessions;
    }

    final updatedItem = widget.initialItem.copyWith(
      packageStatus: _status,
      remainingSessions: remainingSessions,
    );

    Navigator.of(context).pop(updatedItem);
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
