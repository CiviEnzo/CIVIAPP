import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class ClientFormSheet extends StatefulWidget {
  const ClientFormSheet({
    super.key,
    required this.salons,
    this.initial,
    this.defaultSalonId,
  });

  final List<Salon> salons;
  final Client? initial;
  final String? defaultSalonId;

  @override
  State<ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<ClientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _notes;
  late TextEditingController _loyaltyPoints;
  late TextEditingController _clientNumber;
  late TextEditingController _address;
  late TextEditingController _profession;
  late TextEditingController _referralSource;
  late TextEditingController _dateOfBirthDisplay;
  DateTime? _dateOfBirth;
  String? _salonId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _firstName = TextEditingController(text: initial?.firstName ?? '');
    _lastName = TextEditingController(text: initial?.lastName ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '');
    _email = TextEditingController(text: initial?.email ?? '');
    _notes = TextEditingController(text: initial?.notes ?? '');
    _loyaltyPoints = TextEditingController(
      text: initial?.loyaltyPoints.toString() ?? '0',
    );
    _clientNumber = TextEditingController(
      text: initial?.clientNumber ?? _generateClientNumber(),
    );
    _address = TextEditingController(text: initial?.address ?? '');
    _profession = TextEditingController(text: initial?.profession ?? '');
    _referralSource = TextEditingController(
      text: initial?.referralSource ?? '',
    );
    _dateOfBirth = initial?.dateOfBirth;
    _dateOfBirthDisplay = TextEditingController(
      text:
          initial?.dateOfBirth == null
              ? ''
              : _dateFormat.format(initial!.dateOfBirth!),
    );
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    _loyaltyPoints.dispose();
    _clientNumber.dispose();
    _address.dispose();
    _profession.dispose();
    _referralSource.dispose();
    _dateOfBirthDisplay.dispose();
    super.dispose();
  }

  String _generateClientNumber() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _pickDateOfBirth() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final initialDate =
        _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('it', 'IT'),
    );
    if (selected == null) {
      return;
    }
    setState(() {
      _dateOfBirth = selected;
      _dateOfBirthDisplay.text = _dateFormat.format(selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null ? 'Nuovo cliente' : 'Modifica cliente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il nome'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Cognome'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il cognome'
                          : null,
            ),
            const SizedBox(height: 12),
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
              onChanged: (value) => setState(() => _salonId = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientNumber,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Numero cliente',
                helperText: 'Generato automaticamente sulla base del timestamp',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Telefono'),
              keyboardType: TextInputType.phone,
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci un numero di telefono'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateOfBirthDisplay,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Data di nascita',
                suffixIcon: Icon(Icons.calendar_today_rounded),
              ),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Seleziona la data di nascita'
                          : null,
              onTap: _pickDateOfBirth,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Indirizzo di residenza',
              ),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci l\'indirizzo di residenza'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _profession,
              decoration: const InputDecoration(labelText: 'Professione'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci la professione'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _referralSource,
              decoration: const InputDecoration(
                labelText: 'Come ci ha conosciuto?',
              ),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Indica come il cliente ha conosciuto il salone'
                          : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _loyaltyPoints,
              decoration: const InputDecoration(labelText: 'Punti fedeltà'),
              keyboardType: TextInputType.number,
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

    final client = Client(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      phone: _phone.text.trim(),
      clientNumber:
          _clientNumber.text.trim().isEmpty ? null : _clientNumber.text.trim(),
      dateOfBirth: _dateOfBirth,
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
      profession:
          _profession.text.trim().isEmpty ? null : _profession.text.trim(),
      referralSource:
          _referralSource.text.trim().isEmpty
              ? null
              : _referralSource.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      loyaltyPoints: int.tryParse(_loyaltyPoints.text.trim()) ?? 0,
      marketedConsents: widget.initial?.marketedConsents ?? const [],
      onboardingStatus:
          widget.initial?.onboardingStatus ?? ClientOnboardingStatus.notSent,
      invitationSentAt: widget.initial?.invitationSentAt,
      firstLoginAt: widget.initial?.firstLoginAt,
      onboardingCompletedAt: widget.initial?.onboardingCompletedAt,
    );

    Navigator.of(context).pop(client);
  }
}
