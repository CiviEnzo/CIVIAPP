import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class SaleFormSheet extends StatefulWidget {
  const SaleFormSheet({
    super.key,
    required this.salons,
    required this.clients,
    this.defaultSalonId,
    this.initialClientId,
  });

  final List<Salon> salons;
  final List<Client> clients;
  final String? defaultSalonId;
  final String? initialClientId;

  @override
  State<SaleFormSheet> createState() => _SaleFormSheetState();
}

class _SaleFormSheetState extends State<SaleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _amount;
  late TextEditingController _invoice;
  late TextEditingController _notes;
  PaymentMethod _payment = PaymentMethod.pos;
  String? _salonId;
  String? _clientId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: '0');
    _invoice = TextEditingController();
    _notes = TextEditingController();
    _salonId =
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    if (widget.initialClientId != null) {
      final initialClient = widget.clients.firstWhereOrNull(
        (client) => client.id == widget.initialClientId,
      );
      if (initialClient != null) {
        _clientId = initialClient.id;
        _salonId ??= initialClient.salonId;
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _invoice.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients =
        widget.clients
            .where((client) => _salonId == null || client.salonId == _salonId)
            .toList();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Registra vendita',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
              onChanged:
                  (value) => setState(() {
                    _salonId = value;
                    _clientId = null;
                  }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _clientId,
              decoration: const InputDecoration(labelText: 'Cliente'),
              items:
                  clients
                      .map(
                        (client) => DropdownMenuItem(
                          value: client.id,
                          child: Text(client.fullName),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _clientId = value),
              validator:
                  (value) => value == null ? 'Seleziona un cliente' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: 'Importo totale (€)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator:
                  (value) =>
                      (double.tryParse(value?.replaceAll(',', '.') ?? '') ??
                                  0) <=
                              0
                          ? 'Importo non valido'
                          : null,
            ),
            const SizedBox(height: 12),
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
              onChanged:
                  (value) =>
                      setState(() => _payment = value ?? PaymentMethod.pos),
            ),
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
              controller: _invoice,
              decoration: const InputDecoration(
                labelText: 'Numero fattura / scontrino',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
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
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 120)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time == null) return;
    if (!mounted) return;
    setState(() {
      _date = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
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

    final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    final sale = Sale(
      id: _uuid.v4(),
      salonId: _salonId!,
      clientId: _clientId!,
      items: [
        SaleItem(
          referenceId: 'manual-entry',
          referenceType: SaleReferenceType.service,
          description: 'Vendita registrata manualmente',
          quantity: 1,
          unitPrice: amount,
        ),
      ],
      total: amount,
      createdAt: _date,
      paymentMethod: _payment,
      invoiceNumber: _invoice.text.trim().isEmpty ? null : _invoice.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
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
