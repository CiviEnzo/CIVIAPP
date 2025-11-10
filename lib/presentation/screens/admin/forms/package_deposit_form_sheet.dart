import 'package:you_book/domain/entities/sale.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class PackageDepositFormSheet extends StatefulWidget {
  const PackageDepositFormSheet({super.key, required this.maxAmount});

  final double maxAmount;

  @override
  State<PackageDepositFormSheet> createState() =>
      _PackageDepositFormSheetState();
}

class _PackageDepositFormSheetState extends State<PackageDepositFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  PaymentMethod? _paymentMethod;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nuovo acconto (max ${currency.format(widget.maxAmount)})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Importo (€)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'Inserisci l\'importo dell\'acconto';
                }
                final amount = double.tryParse(text.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  return 'Importo non valido';
                }
                if (amount > widget.maxAmount + 0.009) {
                  return 'Supera la rimanenza (${currency.format(widget.maxAmount)})';
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
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Nota (facoltativa)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data acconto'),
              subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(_date)),
              trailing: const Icon(Icons.calendar_month_rounded),
              onTap: _pickDateTime,
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

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_paymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona il metodo di pagamento.')),
      );
      return;
    }

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final normalized = double.parse(amount.toStringAsFixed(2));
    final deposit = PackageDeposit(
      id: const Uuid().v4(),
      amount: normalized,
      date: _date,
      paymentMethod: _paymentMethod!,
      note:
          _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
    );
    Navigator.of(context).pop(deposit);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
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
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _date = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }
}
