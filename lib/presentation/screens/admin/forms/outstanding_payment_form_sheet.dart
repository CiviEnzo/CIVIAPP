import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OutstandingPaymentFormSheet extends StatefulWidget {
  OutstandingPaymentFormSheet({
    super.key,
    required this.outstandingAmount,
    this.initialMethod,
    this.initialAmount,
    this.title = 'Registra incasso',
    this.subtitle,
    this.staff = const [],
    this.initialStaffId,
    this.staffName,
    NumberFormat? currency,
  }) : currency = currency ?? NumberFormat.simpleCurrency(locale: 'it_IT');

  final double outstandingAmount;
  final double? initialAmount;
  final PaymentMethod? initialMethod;
  final String title;
  final String? subtitle;
  final List<StaffMember> staff;
  final String? initialStaffId;
  final String? staffName;
  final NumberFormat currency;

  @override
  State<OutstandingPaymentFormSheet> createState() =>
      _OutstandingPaymentFormSheetState();
}

class _OutstandingPaymentFormSheetState
    extends State<OutstandingPaymentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  PaymentMethod? _method;
  String? _staffId;

  @override
  void initState() {
    super.initState();
    _method = widget.initialMethod;
    _staffId = widget.initialStaffId;
    final initial =
        widget.initialAmount ??
        (widget.outstandingAmount.isFinite && widget.outstandingAmount > 0
            ? widget.outstandingAmount
            : null);
    _amountController = TextEditingController(
      text: initial == null ? '' : initial.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxDescription =
        widget.outstandingAmount.isFinite && widget.outstandingAmount > 0
            ? 'Residuo disponibile: ${widget.currency.format(widget.outstandingAmount)}'
            : null;
    final staffOptions =
        widget.staff
            .where((member) => !member.isEquipment)
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final selectedStaffId =
        staffOptions.any((member) => member.id == _staffId) ? _staffId : null;
    final staffName = widget.staffName?.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle!, style: theme.textTheme.bodyMedium),
            ],
            if (maxDescription != null) ...[
              const SizedBox(height: 4),
              Text(maxDescription, style: theme.textTheme.bodySmall),
            ],
            if (staffOptions.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStaffId,
                decoration: const InputDecoration(
                  labelText: 'Operatore vendita',
                ),
                items:
                    staffOptions
                        .map(
                          (member) => DropdownMenuItem(
                            value: member.id,
                            child: Text(member.fullName),
                          ),
                        )
                        .toList(),
                validator:
                    (value) => value == null ? 'Seleziona l\'operatore' : null,
                onChanged: (value) => setState(() => _staffId = value),
              ),
            ] else if (staffName != null && staffName.isNotEmpty) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Staff vendita'),
                child: Text(staffName),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Importo da incassare (€)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final amount = _parseAmount(value);
                if (amount == null || amount <= 0) {
                  return 'Inserisci un importo valido';
                }
                if (widget.outstandingAmount.isFinite &&
                    widget.outstandingAmount > 0 &&
                    amount - widget.outstandingAmount > 0.009) {
                  return 'Supera il residuo disponibile';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed:
                      widget.outstandingAmount.isFinite &&
                              widget.outstandingAmount > 0
                          ? () => _setAmount(widget.outstandingAmount)
                          : null,
                  child: const Text('Saldo residuo'),
                ),
                TextButton(
                  onPressed: _clearAmount,
                  child: const Text('Pulisci campo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PaymentMethod>(
              value: _method,
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
              onChanged: (value) => setState(() => _method = value),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Registra'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setAmount(double value) {
    final next = value <= 0 ? '' : value.toStringAsFixed(2);
    _amountController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _clearAmount() {
    _amountController.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_method == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona il metodo di pagamento.')),
      );
      return;
    }
    final amount = _parseAmount(_amountController.text)!;
    Navigator.of(context).pop(
      OutstandingPaymentResult(
        amount: amount,
        method: _method!,
        staffId: _staffId,
      ),
    );
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
      case PaymentMethod.posticipated:
        return 'Posticipato';
    }
  }
}

class OutstandingPaymentResult {
  const OutstandingPaymentResult({
    required this.amount,
    required this.method,
    this.staffId,
  });

  final double amount;
  final PaymentMethod method;
  final String? staffId;
}
