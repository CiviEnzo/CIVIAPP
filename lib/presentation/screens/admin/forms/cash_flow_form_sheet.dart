import 'package:civiapp/domain/entities/cash_flow_entry.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class CashFlowFormSheet extends StatefulWidget {
  const CashFlowFormSheet({
    super.key,
    required this.salons,
    required this.staff,
    this.defaultSalonId,
  });

  final List<Salon> salons;
  final List<StaffMember> staff;
  final String? defaultSalonId;

  @override
  State<CashFlowFormSheet> createState() => _CashFlowFormSheetState();
}

class _CashFlowFormSheetState extends State<CashFlowFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  CashFlowType _type = CashFlowType.income;
  late TextEditingController _amount;
  late TextEditingController _description;
  late TextEditingController _category;
  String? _salonId;
  String? _staffId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: '0');
    _description = TextEditingController();
    _category = TextEditingController();
    _salonId =
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staff =
        widget.staff
            .where((member) => _salonId == null || member.salonId == _salonId)
            .toList();
    if (_staffId != null && staff.every((member) => member.id != _staffId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() => _staffId = null);
      });
    }
    final dateFormat = DateFormat('dd/MM/yyyy');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Movimento di cassa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<CashFlowType>(
                    value: CashFlowType.income,
                    groupValue: _type,
                    title: const Text('Entrata'),
                    onChanged:
                        (value) => setState(
                          () => _type = value ?? CashFlowType.income,
                        ),
                  ),
                ),
                Expanded(
                  child: RadioListTile<CashFlowType>(
                    value: CashFlowType.expense,
                    groupValue: _type,
                    title: const Text('Uscita'),
                    onChanged:
                        (value) => setState(
                          () => _type = value ?? CashFlowType.expense,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(labelText: 'Importo (€)'),
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
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descrizione'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci una descrizione'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _staffId,
              decoration: const InputDecoration(
                labelText: 'Operatore (opzionale)',
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
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data movimento'),
              subtitle: Text(dateFormat.format(_date)),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: _pickDate,
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

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date != null) {
      setState(() {
        _date = date;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_salonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nessun salone disponibile. Verifica la configurazione.',
          ),
        ),
      );
      return;
    }

    final entry = CashFlowEntry(
      id: _uuid.v4(),
      salonId: _salonId!,
      type: _type,
      amount: double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0,
      date: _date,
      createdAt: DateTime.now(),
      description: _description.text.trim(),
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      staffId: _staffId,
    );

    Navigator.of(context).pop(entry);
  }
}
