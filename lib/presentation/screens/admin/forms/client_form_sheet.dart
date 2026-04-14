import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:you_book/presentation/common/app_notice.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const Color kClientFormSheetAccent = Color(0xFFD4AF37);
const Color _kClientSheetBackground = Color(0xFFF7F5F1);
const Color _kClientSheetCardBackground = Color(0xFFF8F7F4);
const Color _kClientSheetInputBackground = Color(0xFFFFFFFF);
const Color _kClientSheetBorder = Color(0xFFD7D3CB);
const Color _kClientSheetHint = Color(0xFF98948B);

class _ClientFormPalette {
  const _ClientFormPalette({
    required this.background,
    required this.cardBackground,
    required this.inputBackground,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.hint,
    required this.danger,
    required this.accentSoft,
    required this.cancelBackground,
  });

  factory _ClientFormPalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return _ClientFormPalette(
      background: isDark ? scheme.surface : _kClientSheetBackground,
      cardBackground:
          isDark ? scheme.surfaceContainerLow : _kClientSheetCardBackground,
      inputBackground:
          isDark ? scheme.surfaceContainerHigh : _kClientSheetInputBackground,
      border:
          isDark
              ? scheme.outlineVariant.withValues(alpha: 0.82)
              : _kClientSheetBorder,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      hint:
          isDark
              ? scheme.onSurfaceVariant.withValues(alpha: 0.72)
              : _kClientSheetHint,
      danger: scheme.error,
      accentSoft:
          isDark
              ? kClientFormSheetAccent.withValues(alpha: 0.18)
              : kClientFormSheetAccent.withValues(alpha: 0.16),
      cancelBackground:
          isDark
              ? scheme.surfaceContainerHigh
              : Colors.white.withValues(alpha: 0.75),
    );
  }

  final Color background;
  final Color cardBackground;
  final Color inputBackground;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color hint;
  final Color danger;
  final Color accentSoft;
  final Color cancelBackground;
}

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
  late TextEditingController _loyaltyInitialPoints;
  late TextEditingController _loyaltyPoints;
  late TextEditingController _clientNumber;
  late TextEditingController _address;
  late TextEditingController _city;
  late TextEditingController _profession;
  late TextEditingController _notes;
  String? _referralSource;
  late TextEditingController _dateOfBirthDisplay;
  DateTime? _dateOfBirth;
  String? _gender;
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
  bool _isSubmitting = false;

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
    final initialAddress = initial?.address ?? '';
    final initialCity =
        initial?.city ?? (initialAddress.isNotEmpty ? initialAddress : '');
    _address = TextEditingController(text: initialAddress);
    _city = TextEditingController(text: initialCity);
    _profession = TextEditingController(text: initial?.profession ?? '');
    _notes = TextEditingController(text: initial?.notes ?? '');
    _referralSource = initial?.referralSource;
    _gender = initial?.gender;
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
    _loyaltyInitialPoints.dispose();
    _loyaltyPoints.dispose();
    _clientNumber.dispose();
    _address.dispose();
    _city.dispose();
    _profession.dispose();
    _notes.dispose();
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
      _dateOfBirth = null;
      return null;
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
    final theme = Theme.of(context);
    final palette = _ClientFormPalette.fromTheme(theme);
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: palette.border),
    );

    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: palette.inputBackground,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(color: palette.hint),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          border: baseBorder,
          enabledBorder: baseBorder,
          disabledBorder: baseBorder,
          focusedBorder: baseBorder.copyWith(
            borderSide: BorderSide(color: kClientFormSheetAccent, width: 1.2),
          ),
          errorBorder: baseBorder.copyWith(
            borderSide: BorderSide(color: palette.danger),
          ),
          focusedErrorBorder: baseBorder.copyWith(
            borderSide: BorderSide(color: palette.danger, width: 1.2),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 860;
          final bool isCompactHeader = constraints.maxWidth < 680;
          final bool isPhoneLayout = isAppSheetPhoneLayout(context);

          final anagraficaSection = _FormSection(
            icon: Icons.badge_rounded,
            title: 'Anagrafica',
            subtitle: 'Imposta i dati principali del cliente',
            children: [
              _buildTextField(
                controller: _firstName,
                label: 'Nome',
                hint: 'Inserisci nome',
                required: true,
                autofocus: !_isEditing,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Inserisci il nome'
                            : null,
              ),
              _buildTextField(
                controller: _lastName,
                label: 'Cognome',
                hint: 'Inserisci cognome',
                required: true,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Inserisci il cognome'
                            : null,
              ),
              _buildTextField(
                controller: _dateOfBirthDisplay,
                label: 'Data di nascita',
                hint: 'gg/mm/aaaa',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10),
                  _SlashDateTextInputFormatter(),
                ],
                onChanged: (_) => _updateDateOfBirthFromText(),
                validator: _validateDateOfBirth,
              ),
              _buildDropdownField<String>(
                label: 'Sesso',
                hint: 'Seleziona',
                value: _gender,
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Uomo')),
                  DropdownMenuItem(value: 'female', child: Text('Donna')),
                  DropdownMenuItem(
                    value: 'other',
                    child: Text('Altro/Non specificato'),
                  ),
                ],
                onChanged: (value) => setState(() => _gender = value),
              ),
            ],
          );

          final contattiSection = _FormSection(
            icon: Icons.contact_phone_rounded,
            title: 'Contatti',
            subtitle: 'Recapiti, indirizzo e provenienza',
            children: [
              _buildTextField(
                controller: _phone,
                label: 'Telefono',
                hint: '+39',
                required: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Inserisci un numero di telefono'
                            : null,
              ),
              _buildTextField(
                controller: _email,
                label: 'Email',
                hint: 'esempio@email.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: _validateEmail,
              ),
              _buildTextField(
                controller: _city,
                label: 'Città di residenza',
                hint: 'Milano',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              _buildTextField(
                controller: _profession,
                label: 'Professione',
                hint: 'Es: Insegnante',
                textInputAction: TextInputAction.next,
              ),
              _buildDropdownField<String>(
                label: 'Come ci ha conosciuto?',
                hint: 'Seleziona un\'opzione',
                labelColor: kClientFormSheetAccent,
                value: _referralSource,
                items:
                    _buildReferralOptions()
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                onChanged:
                    (value) => setState(() => _referralSource = value?.trim()),
              ),
            ],
          );

          final notesSection = _FormSection(
            icon: Icons.sticky_note_2_rounded,
            title: 'Note',
            subtitle: 'Annotazioni interne sul cliente',
            children: [
              _buildTextField(
                controller: _notes,
                label: '',
                hint: 'Note cliente',
                keyboardType: TextInputType.multiline,
                minLines: 6,
                maxLines: 6,
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
                onChanged:
                    (value) => _updatePreference(() => _prefPush = value),
                title: const Text('Push (app mobile)'),
                subtitle: const Text(
                  'Notifiche gratuite tramite installazione dell\'app.',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _prefEmail,
                onChanged:
                    (value) => _updatePreference(() => _prefEmail = value),
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
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          );

          final loyaltySection = _FormSection(
            icon: Icons.stars_rounded,
            title: 'Programma fedeltà',
            subtitle: 'Configura saldo iniziale e punti attuali',
            children: [
              _buildTextField(
                controller: _loyaltyInitialPoints,
                label: 'Punti iniziali',
                hint: '0',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                helperText: 'Saldo assegnato al momento della creazione.',
              ),
              _buildTextField(
                controller: _loyaltyPoints,
                label: 'Saldo punti attuale',
                hint: '0',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                helperText:
                    'Se lasci invariato, sarà ricalcolato con il nuovo saldo iniziale.',
              ),
            ],
          );

          final formSections = <Widget>[
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: anagraficaSection),
                  const SizedBox(width: 18),
                  Expanded(child: contattiSection),
                ],
              )
            else ...[
              anagraficaSection,
              const SizedBox(height: 18),
              contattiSection,
            ],
            const SizedBox(height: 18),
            notesSection,
            if (_isEditing) ...[
              const SizedBox(height: 18),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: preferenzeSection),
                    const SizedBox(width: 18),
                    Expanded(child: loyaltySection),
                  ],
                )
              else ...[
                preferenzeSection,
                const SizedBox(height: 18),
                loyaltySection,
              ],
            ],
          ];

          if (isPhoneLayout) {
            return AppMobileSheetPageScaffold(
              title: _isEditing ? 'Modifica cliente' : 'Nuovo cliente',
              subtitle: 'Anagrafica, contatti e preferenze del cliente.',
              backgroundColor: palette.background,
              actions: [
                TextButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Attendi...' : 'Salva'),
                ),
              ],
              body: Form(
                key: _formKey,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _ClientNumberBadge(number: numberDisplay),
                    const SizedBox(height: 16),
                    ...formSections,
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          }

          return ColoredBox(
            color: palette.background,
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 128),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(
                          context,
                          numberDisplay: numberDisplay,
                          isCompact: isCompactHeader,
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: palette.border),
                        const SizedBox(height: 20),
                        ...formSections,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
                      decoration: BoxDecoration(
                        color: palette.background,
                        border: Border(top: BorderSide(color: palette.border)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton(
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () => Navigator.of(context).maybePop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette.textPrimary,
                              backgroundColor: palette.cancelBackground,
                              side: BorderSide(color: palette.border),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Annulla'),
                          ),
                          FilledButton(
                            onPressed: _isSubmitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: kClientFormSheetAccent,
                              foregroundColor: palette.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(_isSubmitting ? 'Attendi...' : 'Salva'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_salonId == null) {
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(const SnackBar(content: Text('Seleziona un salone')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final existing = widget.initial;
      final salonId = _salonId!;
      final trimmedFirstName = _firstName.text.trim();
      final trimmedLastName = _lastName.text.trim();
      final trimmedPhone = _phone.text.trim();
      final trimmedEmail = _email.text.trim();
      final trimmedAddress = _address.text.trim();
      final trimmedCity = _city.text.trim();
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
            address: trimmedAddress,
            city: trimmedCity,
            profession: trimmedProfession,
            notes: trimmedNotes,
            referralSource: referral,
            dateOfBirth: _dateOfBirth,
            gender: _gender,
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

      final normalizedCity =
          trimmedCity.isNotEmpty
              ? trimmedCity
              : () {
                final existingCity = existing?.city?.trim();
                if (existingCity != null && existingCity.isNotEmpty) {
                  return existingCity;
                }
                final existingAddress = existing?.address?.trim();
                if (existingAddress != null && existingAddress.isNotEmpty) {
                  return existingAddress;
                }
                if (trimmedAddress.isNotEmpty) {
                  return trimmedAddress;
                }
                return null;
              }();

      final client = Client(
        id: existing?.id ?? _uuid.v4(),
        salonId: salonId,
        firstName: trimmedFirstName,
        lastName: trimmedLastName,
        phone: trimmedPhone,
        gender: _gender,
        dateOfBirth: _dateOfBirth,
        address: trimmedAddress.isEmpty ? null : trimmedAddress,
        city: normalizedCity,
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            'Impossibile completare il salvataggio del cliente: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
    required String notes,
    required String? referralSource,
    required DateTime? dateOfBirth,
    required String? gender,
  }) {
    final sanitizedAddress = address.trim();
    final sanitizedCity = city.trim();
    final sanitizedNotes = notes.trim();

    return existing.copyWith(
      firstName: firstName.isNotEmpty ? firstName : existing.firstName,
      lastName: lastName.isNotEmpty ? lastName : existing.lastName,
      phone: phone.isNotEmpty ? phone : existing.phone,
      email: email.isNotEmpty ? email : existing.email,
      address:
          sanitizedAddress.isNotEmpty ? sanitizedAddress : existing.address,
      city:
          sanitizedCity.isNotEmpty
              ? sanitizedCity
              : () {
                final existingCity = existing.city?.trim();
                if (existingCity != null && existingCity.isNotEmpty) {
                  return existingCity;
                }
                final existingAddress = existing.address?.trim();
                if (existingAddress != null && existingAddress.isNotEmpty) {
                  return existingAddress;
                }
                if (sanitizedAddress.isNotEmpty) {
                  return sanitizedAddress;
                }
                return existing.city;
              }(),
      profession: profession.isNotEmpty ? profession : existing.profession,
      notes: sanitizedNotes.isNotEmpty ? sanitizedNotes : existing.notes,
      referralSource:
          referralSource != null && referralSource.isNotEmpty
              ? referralSource
              : existing.referralSource,
      dateOfBirth: dateOfBirth ?? existing.dateOfBirth,
      gender: gender ?? existing.gender,
    );
  }

  String _normalizePhoneForComparison(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Widget _buildHeader(
    BuildContext context, {
    required String numberDisplay,
    required bool isCompact,
  }) {
    final theme = Theme.of(context);
    final palette = _ClientFormPalette.fromTheme(theme);
    final titleBlock = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: palette.accentSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 22,
            color: kClientFormSheetAccent,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            _isEditing ? 'Modifica cliente' : 'Nuovo cliente',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              if (isCompact) ...[
                const SizedBox(height: 12),
                _ClientNumberBadge(number: numberDisplay),
              ],
            ],
          ),
        ),
        if (!isCompact) ...[
          const SizedBox(width: 16),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _ClientNumberBadge(number: numberDisplay),
          ),
        ],
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Chiudi',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.close_rounded, color: palette.textPrimary),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    bool autofocus = false,
    TextInputAction? textInputAction,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    FormFieldValidator<String>? validator,
    ValueChanged<String>? onChanged,
    String? helperText,
    int? minLines,
    int maxLines = 1,
  }) {
    final field = TextFormField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      decoration: _inputDecoration(hint: hint, helperText: helperText),
    );
    if (label.isEmpty) {
      return field;
    }
    return _FieldBlock(label: label, required: required, child: field);
  }

  Widget _buildDropdownField<T>({
    required String label,
    required String hint,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool required = false,
    Color? labelColor,
  }) {
    return _FieldBlock(
      label: label,
      required: required,
      labelColor: labelColor,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        hint: Text(hint),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _ClientFormPalette.fromTheme(Theme.of(context)).textSecondary,
        ),
        decoration: _inputDecoration(hint: hint),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, String? helperText}) {
    return InputDecoration(
      hintText: hint,
      helperText: helperText,
      isDense: true,
    );
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
      return null;
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
    final palette = _ClientFormPalette.fromTheme(theme);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        color: palette.cardBackground,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: kClientFormSheetAccent),
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
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _withSpacing(children),
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
    final palette = _ClientFormPalette.fromTheme(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: palette.inputBackground.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        'N° $number',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({
    required this.label,
    required this.child,
    this.required = false,
    this.labelColor,
  });

  final String label;
  final Widget child;
  final bool required;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ClientFormPalette.fromTheme(theme);
    final resolvedLabelColor = labelColor ?? palette.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: resolvedLabelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (required)
                TextSpan(
                  text: ' *',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
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
