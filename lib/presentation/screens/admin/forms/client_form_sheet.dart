import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const String _pendingClientNumberDisplay = 'Assegnato al salvataggio';
  static const String _duplicateDialogCancel = '_duplicate_cancel';
  static const String _duplicateDialogCreateNew = '_duplicate_create_new';
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _notes;
  late TextEditingController _loyaltyInitialPoints;
  late TextEditingController _loyaltyPoints;
  late TextEditingController _clientNumber;
  late TextEditingController _address;
  late TextEditingController _profession;
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
  bool _loyaltyDirty = false;
  bool _updatingLoyaltyField = false;

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
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
    final defaultInitial =
        initial?.loyaltyInitialPoints ?? _initialBalanceForSalon(_salonId);
    _loyaltyInitialPoints = TextEditingController(
      text: defaultInitial.toString(),
    );
    final startingLoyalty = initial?.loyaltyPoints ?? defaultInitial;
    _loyaltyPoints = TextEditingController(text: startingLoyalty.toString());
    _loyaltyPoints.addListener(() {
      if (_updatingLoyaltyField) {
        return;
      }
      _loyaltyDirty = true;
    });
    _loyaltyDirty = initial != null;
    _applyInitialLoyaltyForSalon(_salonId);
    _clientNumber = TextEditingController(
      text: _resolveInitialClientNumber(initial),
    );
    if (!_hasPersistedClientNumber && _clientNumber.text.isEmpty) {
      _clientNumber.text = _pendingClientNumberDisplay;
    }
    _refreshClientNumberForSalon(_salonId);
    _address = TextEditingController(
      text: initial?.city ?? initial?.address ?? '',
    );
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
    _loyaltyInitialPoints.dispose();
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
    return '';
  }

  int _initialBalanceForSalon(String? salonId) {
    final salon = widget.salons.firstWhereOrNull(
      (element) => element.id == salonId,
    );
    if (salon == null) {
      return 0;
    }
    final settings = salon.loyaltySettings;
    if (!settings.enabled) {
      return 0;
    }
    return settings.initialBalance;
  }

  void _setLoyaltyPoints(int value) {
    final text = value.toString();
    if (_loyaltyPoints.text == text) {
      return;
    }
    _updatingLoyaltyField = true;
    _loyaltyPoints.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _updatingLoyaltyField = false;
  }

  void _applyInitialLoyaltyForSalon(String? salonId) {
    if (_isEditing || _loyaltyDirty) {
      return;
    }
    final balance = _initialBalanceForSalon(salonId);
    _loyaltyInitialPoints.text = balance.toString();
    _setLoyaltyPoints(balance);
  }

  void _refreshClientNumberForSalon(String? salonId) {
    if (_hasPersistedClientNumber) {
      return;
    }
    _clientNumber.text = _pendingClientNumberDisplay;
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

  void _updateDateOfBirthFromText() {
    final trimmed = _dateOfBirthDisplay.text.trim();
    _dateOfBirth = _parseDate(trimmed);
  }

  DateTime? _parseDate(String value) {
    if (value.length != 10) {
      return null;
    }
    try {
      return _dateFormat.parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  String? _validateDateOfBirth(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Inserisci la data di nascita';
    }
    final parsed = _parseDate(trimmed);
    if (parsed == null) {
      return 'Formato data non valido (gg/mm/aaaa)';
    }
    _dateOfBirth = parsed;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final numberDisplay =
        _clientNumber.text.isEmpty
            ? _pendingClientNumberDisplay
            : _clientNumber.text;

    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final bool isWide = constraints.maxWidth >= 900;

        double sidebarWidth = constraints.maxWidth * 0.36;
        if (sidebarWidth < 320) {
          sidebarWidth = 320;
        } else if (sidebarWidth > 420) {
          sidebarWidth = 420;
        }

        final header = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _isEditing ? 'Modifica cliente' : 'Nuovo cliente',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 12),
            _ClientNumberBadge(number: numberDisplay),
          ],
        );

        final anagraficaSection = _FormSection(
          icon: Icons.badge_rounded,
          title: 'Anagrafica',
          subtitle: 'Imposta i dati principali del cliente',
          children: [
            TextFormField(
              controller: _firstName,
              autofocus: !_isEditing,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il nome'
                          : null,
            ),
            TextFormField(
              controller: _lastName,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Cognome'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il cognome'
                          : null,
            ),
            TextFormField(
              controller: _dateOfBirthDisplay,
              keyboardType: TextInputType.number,
              inputFormatters: [
                LengthLimitingTextInputFormatter(10),
                _SlashDateTextInputFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Data di nascita',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today_rounded),
                  onPressed: _pickDateOfBirth,
                ),
              ),
              onChanged: (_) => _updateDateOfBirthFromText(),
              validator: _validateDateOfBirth,
            ),
          ],
        );

        final contattiSection = _FormSection(
          icon: Icons.contact_phone_rounded,
          title: 'Contatti',
          subtitle: 'Recapiti, indirizzo e provenienza',
          children: [
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Telefono'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci un numero di telefono'
                          : null,
            ),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
            ),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Città di residenza',
              ),
              textInputAction: TextInputAction.next,
            ),
            TextFormField(
              controller: _profession,
              decoration: const InputDecoration(labelText: 'Professione'),
              textInputAction: TextInputAction.next,
            ),
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
          ],
        );

        final preferenzeSection = _FormSection(
          icon: Icons.forum_rounded,
          title: 'Preferenze di contatto',
          subtitle: 'Scegli i canali di comunicazione consentiti',
          children: [
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
            Text(
              _preferencesDirty || widget.initial == null
                  ? 'Le modifiche saranno registrate al salvataggio.'
                  : _channelPrefsUpdatedAt != null
                  ? 'Ultimo aggiornamento: ${_dateTimeFormat.format(_channelPrefsUpdatedAt!)}'
                  : 'Preferenze non ancora registrate.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );

        final loyaltySection = _FormSection(
          icon: Icons.stars_rounded,
          title: 'Programma fedeltà',
          subtitle: 'Configura saldo iniziale e punti attuali',
          children: [
            TextFormField(
              controller: _loyaltyInitialPoints,
              decoration: const InputDecoration(
                labelText: 'Punti iniziali',
                helperText: 'Saldo assegnato al momento della creazione.',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            TextFormField(
              controller: _loyaltyPoints,
              decoration: const InputDecoration(
                labelText: 'Saldo punti attuale',
                helperText:
                    'Se lasci invariato, sarà ricalcolato con il nuovo saldo iniziale.',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        );

        final noteSection = _FormSection(
          icon: Icons.sticky_note_2_rounded,
          title: 'Note',
          subtitle: 'Annotazioni visibili allo staff',
          children: [
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Note interne'),
              maxLines: 4,
            ),
          ],
        );

        final saveButton = Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _submit, child: const Text('Salva')),
        );

        final narrowChildren = <Widget>[
          header,
          const SizedBox(height: 24),
          anagraficaSection,
          contattiSection,
          preferenzeSection,
          loyaltySection,
          noteSection,
          const SizedBox(height: 12),
          saveButton,
        ];

        final wideLayout = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            header,
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      anagraficaSection,
                      contattiSection,
                      loyaltySection,
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: sidebarWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      preferenzeSection,
                      noteSection,
                      const SizedBox(height: 12),
                      saveButton,
                    ],
                  ),
                ),
              ],
            ),
          ],
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child:
                isWide
                    ? wideLayout
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: narrowChildren,
                    ),
          ),
        );
      },
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_salonId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleziona un salone')));
      return;
    }

    final existing = widget.initial;
    final salonId = _salonId!;
    final trimmedFirstName = _firstName.text.trim();
    final trimmedLastName = _lastName.text.trim();
    final trimmedPhone = _phone.text.trim();
    final trimmedEmail = _email.text.trim();
    final trimmedCity = _address.text.trim();
    final trimmedProfession = _profession.text.trim();
    final trimmedNotes = _notes.text.trim();
    final referral = _referralSource?.trim();

    _updateDateOfBirthFromText();

    final duplicates = _findPotentialDuplicates(
      salonId: salonId,
      phone: trimmedPhone,
      email: trimmedEmail,
    );

    if (duplicates.isNotEmpty) {
      final decision = await _promptDuplicateResolution(duplicates);
      if (!mounted) {
        return;
      }
      if (decision == _duplicateDialogCancel || decision == null) {
        return;
      }
      if (decision is Client) {
        final mergedClient = _mergeExistingClientWithForm(
          decision,
          firstName: trimmedFirstName,
          lastName: trimmedLastName,
          phone: trimmedPhone,
          email: trimmedEmail,
          address: trimmedCity,
          city: trimmedCity,
          profession: trimmedProfession,
          referralSource: referral,
          notes: trimmedNotes,
          dateOfBirth: _dateOfBirth,
        );
        Navigator.of(context).pop(mergedClient);
        return;
      }
    }

    var initialPoints = int.tryParse(_loyaltyInitialPoints.text.trim()) ?? 0;
    if (initialPoints < 0) {
      initialPoints = 0;
    }

    var loyaltyPoints = int.tryParse(_loyaltyPoints.text.trim()) ?? 0;
    final previousInitial = existing?.loyaltyInitialPoints ?? 0;
    final previousBalance = existing?.loyaltyPoints ?? 0;
    final historicNet = previousBalance - previousInitial;

    final balanceFieldChanged =
        existing == null
            ? _loyaltyPoints.text.trim().isNotEmpty
            : int.tryParse(_loyaltyPoints.text.trim()) != previousBalance;

    if (!balanceFieldChanged) {
      loyaltyPoints = initialPoints + historicNet;
    }
    if (existing == null && _loyaltyPoints.text.trim().isEmpty) {
      loyaltyPoints = initialPoints;
    }
    if (loyaltyPoints < 0) {
      loyaltyPoints = 0;
    }

    final bool isNewClient = existing == null;
    DateTime? loyaltyUpdatedAt = existing?.loyaltyUpdatedAt;
    if (loyaltyUpdatedAt == null &&
        (loyaltyPoints != previousBalance || isNewClient)) {
      loyaltyUpdatedAt = loyaltyPoints == 0 ? null : DateTime.now();
    }

    final int loyaltyTotalEarned = existing?.loyaltyTotalEarned ?? 0;
    final int loyaltyTotalRedeemed = existing?.loyaltyTotalRedeemed ?? 0;

    final client = Client(
      id: existing?.id ?? _uuid.v4(),
      salonId: salonId,
      firstName: trimmedFirstName,
      lastName: trimmedLastName,
      phone: trimmedPhone,
      dateOfBirth: _dateOfBirth,
      address: trimmedCity.isEmpty ? null : trimmedCity,
      city:
          trimmedCity.isNotEmpty
              ? trimmedCity
              : (existing?.city ?? existing?.address),
      profession: trimmedProfession.isEmpty ? null : trimmedProfession,
      referralSource: referral == null || referral.isEmpty ? null : referral,
      email: trimmedEmail,
      notes: trimmedNotes.isEmpty ? null : trimmedNotes,
      loyaltyInitialPoints: initialPoints,
      loyaltyPoints: loyaltyPoints,
      loyaltyUpdatedAt: loyaltyUpdatedAt,
      loyaltyTotalEarned: loyaltyTotalEarned,
      loyaltyTotalRedeemed: loyaltyTotalRedeemed,
      marketedConsents: widget.initial?.marketedConsents ?? const [],
      onboardingStatus:
          widget.initial?.onboardingStatus ?? ClientOnboardingStatus.notSent,
      invitationSentAt: widget.initial?.invitationSentAt,
      firstLoginAt: widget.initial?.firstLoginAt,
      onboardingCompletedAt: widget.initial?.onboardingCompletedAt,
      clientNumber:
          existing?.clientNumber != null && existing!.clientNumber!.isNotEmpty
              ? existing.clientNumber
              : null,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    Navigator.of(context).pop(client);
  }

  List<Client> _findPotentialDuplicates({
    required String salonId,
    required String phone,
    required String email,
  }) {
    final normalizedPhone = _normalizePhoneForComparison(phone);
    final normalizedEmail = email.trim().toLowerCase();

    return widget.clients.where((client) {
      if (client.id == widget.initial?.id) {
        return false;
      }
      if (client.salonId != salonId) {
        return false;
      }
      final clientPhone = _normalizePhoneForComparison(client.phone);
      final phoneMatch =
          normalizedPhone.isNotEmpty && clientPhone == normalizedPhone;
      final clientEmail = client.email?.trim().toLowerCase() ?? '';
      final emailMatch =
          normalizedEmail.isNotEmpty && clientEmail == normalizedEmail;
      return phoneMatch || emailMatch;
    }).toList();
  }

  Future<Object?> _promptDuplicateResolution(List<Client> duplicates) {
    return showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Possibile duplicato'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      duplicates.length == 1
                          ? 'È stato trovato un cliente con gli stessi contatti.'
                          : 'Sono stati trovati ${duplicates.length} clienti con gli stessi contatti.',
                    ),
                    const SizedBox(height: 12),
                    ...duplicates.map(
                      (client) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline_rounded),
                        title: Text(client.fullName),
                        subtitle: Text(_buildDuplicateSubtitle(client)),
                        onTap: () => Navigator.of(ctx).pop(client),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_duplicateDialogCancel),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(ctx).pop(_duplicateDialogCreateNew),
                child: const Text('Crea nuovo comunque'),
              ),
            ],
          ),
    );
  }

  String _buildDuplicateSubtitle(Client client) {
    final details = <String>[
      if (client.phone.isNotEmpty) client.phone,
      if (client.email != null && client.email!.isNotEmpty) client.email!,
    ];
    return details.join(' • ');
  }

  Client _mergeExistingClientWithForm(
    Client existing, {
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String address,
    required String city,
    required String profession,
    required String? referralSource,
    required String notes,
    required DateTime? dateOfBirth,
  }) {
    final mergedNotes = <String>[];
    final existingNotes = existing.notes?.trim();
    if (existingNotes != null && existingNotes.isNotEmpty) {
      mergedNotes.add(existingNotes);
    }
    if (notes.trim().isNotEmpty) {
      mergedNotes.add(notes.trim());
    }

    return existing.copyWith(
      firstName: firstName.isNotEmpty ? firstName : existing.firstName,
      lastName: lastName.isNotEmpty ? lastName : existing.lastName,
      phone: phone.isNotEmpty ? phone : existing.phone,
      email: email.isNotEmpty ? email : existing.email,
      address: address.isNotEmpty ? address : existing.address,
      city: city.isNotEmpty ? city : (existing.city ?? existing.address),
      profession: profession.isNotEmpty ? profession : existing.profession,
      referralSource:
          referralSource != null && referralSource.isNotEmpty
              ? referralSource
              : existing.referralSource,
      notes:
          mergedNotes.isEmpty
              ? existing.notes
              : mergedNotes.toSet().toList().join('\n'),
      dateOfBirth: dateOfBirth ?? existing.dateOfBirth,
    );
  }

  String _normalizePhoneForComparison(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _updatePreference(VoidCallback updater) {
    setState(() {
      updater();
      _preferencesDirty = _didPreferencesChange();
    });
  }

  String? _validateEmail(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return "Inserisci un indirizzo email";
    }
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(raw)) {
      return "Email non valida";
    }
    return null;
  }

  bool _didPreferencesChange() {
    return _prefPush != _initialChannelPreferences.push ||
        _prefEmail != _initialChannelPreferences.email ||
        _prefWhatsapp != _initialChannelPreferences.whatsapp ||
        _prefSms != _initialChannelPreferences.sms;
  }

  List<String> _buildReferralOptions() {
    final options = List<String>.from(kClientReferralSourceOptions);
    if (_referralSource != null &&
        _referralSource!.isNotEmpty &&
        !options.contains(_referralSource)) {
      options.add(_referralSource!);
    }
    return options;
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.children,
    this.icon,
    this.subtitle,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerColor = theme.colorScheme.secondaryContainer;
    final borderColor = theme.colorScheme.outlineVariant;
    final onHeaderColor = theme.colorScheme.onSecondaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: onHeaderColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Icon(icon, size: 20, color: onHeaderColor),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: onHeaderColor,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onHeaderColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _withSpacing(children),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> items) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i != items.length - 1) {
        result.add(const SizedBox(height: 12));
      }
    }
    return result;
  }
}

class _ClientNumberBadge extends StatelessWidget {
  const _ClientNumberBadge({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        'N° $number',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _SlashDateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
