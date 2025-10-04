import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class ClientFormSheet extends StatefulWidget {
  const ClientFormSheet({
    super.key,
    required this.salons,
    required this.clients,
    this.initial,
    this.defaultSalonId,
  });

  final List<Salon> salons;
  final List<Client> clients;
  final Client? initial;
  final String? defaultSalonId;

  @override
  State<ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<ClientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _notes;
  late TextEditingController _loyaltyPoints;
  late TextEditingController _clientNumber;
  late TextEditingController _address;
  late TextEditingController _profession;
  static const List<String> _referralOptions = [
    'Instagram',
    'Facebook',
    'Tik tok',
    'Amico titolare',
    'Amico dipendente',
    'Passaparola',
    'Passando davanti il centro',
    'Cliente passato',
    'Campagna lead',
    'Buono regalo',
    'Tramite App',
  ];

  String? _referralSource;
  late TextEditingController _dateOfBirthDisplay;
  DateTime? _dateOfBirth;
  String? _salonId;
  late ChannelPreferences _initialChannelPreferences;
  late bool _prefPush;
  late bool _prefEmail;
  late bool _prefWhatsapp;
  late bool _prefSms;
  DateTime? _channelPrefsUpdatedAt;
  bool _preferencesDirty = false;

  bool get _isEditing => widget.initial != null;

  bool get _hasPersistedClientNumber =>
      widget.initial?.clientNumber != null &&
      widget.initial!.clientNumber!.isNotEmpty;

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
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    _clientNumber = TextEditingController(
      text: _resolveInitialClientNumber(initial),
    );
    _address = TextEditingController(text: initial?.address ?? '');
    _profession = TextEditingController(text: initial?.profession ?? '');
    _referralSource = initial?.referralSource;
    _dateOfBirth = initial?.dateOfBirth;
    _dateOfBirthDisplay = TextEditingController(
      text:
          initial?.dateOfBirth == null
              ? ''
              : _dateFormat.format(initial!.dateOfBirth!),
    );
    _initialChannelPreferences =
        initial?.channelPreferences ?? const ChannelPreferences();
    _prefPush = _initialChannelPreferences.push;
    _prefEmail = _initialChannelPreferences.email;
    _prefWhatsapp = _initialChannelPreferences.whatsapp;
    _prefSms = _initialChannelPreferences.sms;
    _channelPrefsUpdatedAt = _initialChannelPreferences.updatedAt;
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
    _dateOfBirthDisplay.dispose();
    super.dispose();
  }

  String _resolveInitialClientNumber(Client? initial) {
    final clientNumber = initial?.clientNumber;
    if (clientNumber != null && clientNumber.isNotEmpty) {
      return clientNumber;
    }
    return _generateSequentialClientNumber(_salonId);
  }

  List<Client> _clientsForSalon(String? salonId) {
    return widget.clients.where((client) {
      if (_isEditing &&
          widget.initial != null &&
          client.id == widget.initial!.id) {
        return false;
      }
      if (salonId == null) {
        return true;
      }
      return client.salonId == salonId;
    }).toList();
  }

  String _generateSequentialClientNumber(String? salonId) {
    final relevantClients = _clientsForSalon(salonId);
    final usedNumbers = <int>{};
    for (final client in relevantClients) {
      final number = int.tryParse(client.clientNumber ?? '');
      if (number == null || number <= 0 || number >= 1000000) {
        // Ignore non-numeric or legacy timestamp-based codes.
        continue;
      }
      usedNumbers.add(number);
    }
    var candidate = 1;
    // Pick the first available progressive number.
    while (usedNumbers.contains(candidate)) {
      candidate += 1;
    }
    return candidate.toString();
  }

  void _refreshClientNumberForSalon(String? salonId) {
    if (_hasPersistedClientNumber) {
      return;
    }
    _clientNumber.text = _generateSequentialClientNumber(salonId);
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
              onChanged: (value) {
                setState(() {
                  _salonId = value;
                  _refreshClientNumberForSalon(value);
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientNumber,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Numero cliente',
                helperText: 'Generato automaticamente in ordine progressivo',
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
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _profession,
              decoration: const InputDecoration(labelText: 'Professione'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _referralSource,
              decoration: const InputDecoration(
                labelText: 'Come ci ha conosciuto?',
              ),
              hint: const Text('Seleziona un\'opzione'),
              items:
                  _buildReferralOptions()
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        ),
                      )
                      .toList(),
              isExpanded: true,
              onChanged:
                  (value) => setState(() => _referralSource = value?.trim()),
              validator:
                  (value) =>
                      _referralSource == null || _referralSource!.isEmpty
                          ? 'Indica come il cliente ha conosciuto il salone'
                          : null,
            ),
            const SizedBox(height: 12),
            Text(
              'Preferenze di contatto',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _prefPush,
              onChanged: (value) => _updatePreference(() => _prefPush = value),
              title: const Text('Push (app mobile)'),
              subtitle: const Text(
                'Notifiche gratuite tramite installazione dell\'app.',
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _prefEmail,
              onChanged: (value) => _updatePreference(() => _prefEmail = value),
              title: const Text('Email'),
              subtitle: const Text('Promo e reminder via posta elettronica.'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _prefWhatsapp,
              onChanged:
                  (value) => _updatePreference(() => _prefWhatsapp = value),
              title: const Text('WhatsApp'),
              subtitle: const Text(
                'Richiede numero Business e template approvati.',
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _prefSms,
              onChanged: (value) => _updatePreference(() => _prefSms = value),
              title: const Text('SMS'),
              subtitle: const Text(
                'Canale a pagamento, usarlo solo per comunicazioni urgenti.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _preferencesDirty || widget.initial == null
                    ? 'Le modifiche saranno registrate al salvataggio.'
                    : _channelPrefsUpdatedAt != null
                    ? 'Ultimo aggiornamento: ${_dateTimeFormat.format(_channelPrefsUpdatedAt!)}'
                    : 'Preferenze non ancora registrate.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
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
          _referralSource == null || _referralSource!.trim().isEmpty
              ? null
              : _referralSource!.trim(),
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

  void _updatePreference(VoidCallback updater) {
    setState(() {
      updater();
      _preferencesDirty = _didPreferencesChange();
    });
  }

  bool _didPreferencesChange() {
    return _prefPush != _initialChannelPreferences.push ||
        _prefEmail != _initialChannelPreferences.email ||
        _prefWhatsapp != _initialChannelPreferences.whatsapp ||
        _prefSms != _initialChannelPreferences.sms;
  }

  List<String> _buildReferralOptions() {
    final options = List<String>.from(_referralOptions);
    if (_referralSource != null &&
        _referralSource!.isNotEmpty &&
        !options.contains(_referralSource)) {
      options.add(_referralSource!);
    }
    return options;
  }
}
