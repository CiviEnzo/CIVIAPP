import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/public_salon.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/services/clients/web_client_request_service.dart';

class WebClientRegistrationScreen extends StatefulWidget {
  const WebClientRegistrationScreen({
    super.key,
    required this.salonId,
    this.embedded = false,
  });

  final String salonId;
  final bool embedded;

  @override
  State<WebClientRegistrationScreen> createState() =>
      _WebClientRegistrationScreenState();
}

class _WebClientRegistrationScreenState
    extends State<WebClientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _professionController = TextEditingController();
  final _referralController = TextEditingController();
  final _notesController = TextEditingController();
  final _websiteController = TextEditingController();
  final _service = WebClientRequestService();

  DateTime? _dateOfBirth;
  String? _gender;
  bool _privacyAccepted = false;
  bool _marketingAccepted = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _professionController.dispose();
    _referralController.dispose();
    _notesController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('it', 'IT'),
    );
    if (selected != null) setState(() => _dateOfBirth = selected);
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Campo obbligatorio' : null;
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Inserisci un indirizzo email valido';
    }
    return null;
  }

  Future<void> _submit(PublicSalon salon) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_phoneController.text.trim().isEmpty &&
        _emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Inserisci almeno telefono o email.');
      return;
    }
    if (!_privacyAccepted) {
      setState(
        () => _errorMessage = 'Accetta l’informativa privacy per continuare.',
      );
      return;
    }

    final extras = <String, dynamic>{};
    final enabled = salon.clientRegistration.extraFields.toSet();
    if (enabled.contains(ClientRegistrationExtraField.address)) {
      extras['address'] = _addressController.text;
    }
    if (enabled.contains(ClientRegistrationExtraField.profession)) {
      extras['profession'] = _professionController.text;
    }
    if (enabled.contains(ClientRegistrationExtraField.referralSource)) {
      extras['referralSource'] = _referralController.text;
    }
    if (enabled.contains(ClientRegistrationExtraField.notes)) {
      extras['notes'] = _notesController.text;
    }
    if (enabled.contains(ClientRegistrationExtraField.gender)) {
      extras['gender'] = _gender;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final uri = Uri.base;
      await _service.submit(
        salonId: salon.id,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        privacyAccepted: _privacyAccepted,
        marketingAccepted: _marketingAccepted,
        dateOfBirth: _dateOfBirth,
        extraData: extras,
        sourceUrl: uri.toString(),
        utmSource: uri.queryParameters['utm_source'],
        utmMedium: uri.queryParameters['utm_medium'],
        utmCampaign: uri.queryParameters['utm_campaign'],
        website: _websiteController.text,
      );
      if (mounted) setState(() => _submitted = true);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = switch (error.code) {
          'resource-exhausted' =>
            'Attendi un minuto prima di inviare nuovamente.',
          'failed-precondition' =>
            'Il modulo non è disponibile o manca il consenso privacy.',
          _ => 'Non è stato possibile inviare i dati. Riprova.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _errorMessage = 'Non è stato possibile inviare i dati. Riprova.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('public_salons')
              .doc(widget.salonId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _PublicFormShell(
            embedded: widget.embedded,
            child: const _MessageState(
              icon: Icons.error_outline_rounded,
              title: 'Modulo non disponibile',
              message: 'Riprova più tardi o contatta direttamente il salone.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return _PublicFormShell(
            embedded: widget.embedded,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final document = snapshot.data!;
        if (!document.exists) {
          return _PublicFormShell(
            embedded: widget.embedded,
            child: const _MessageState(
              icon: Icons.link_off_rounded,
              title: 'Modulo non trovato',
              message:
                  'Il collegamento non è valido o il salone non è pubblicato.',
            ),
          );
        }
        final salon = PublicSalon.fromMap(document.id, document.data()!);
        if (!salon.clientRegistration.webFormEnabled ||
            salon.status != SalonStatus.active) {
          return _PublicFormShell(
            embedded: widget.embedded,
            child: const _MessageState(
              icon: Icons.pause_circle_outline_rounded,
              title: 'Modulo non attivo',
              message:
                  'Al momento il salone non accetta registrazioni dal sito.',
            ),
          );
        }
        return Theme(
          data: _webFormTheme(salon.clientRegistration),
          child: _PublicFormShell(
            embedded: widget.embedded,
            child: Builder(
              builder:
                  (themedContext) =>
                      _submitted
                          ? _MessageState(
                            icon: Icons.check_circle_outline_rounded,
                            title: 'Dati inviati',
                            message:
                                salon
                                    .clientRegistration
                                    .webFormConfirmationMessage,
                          )
                          : _buildForm(salon, themedContext),
            ),
          ),
        );
      },
    );
  }

  ThemeData _webFormTheme(ClientRegistrationSettings registration) {
    // Il modulo pubblico deve essere graficamente indipendente dal tema
    // dell'utente YouBook che apre l'anteprima. In particolare, l'iframe non
    // deve diventare scuro quando l'amministratore usa la dark mode.
    final base = ThemeData.light(useMaterial3: true);
    final rawHex = registration.webThemeColor.replaceFirst('#', '');
    final parsed = int.tryParse(rawHex, radix: 16);
    final seedColor =
        parsed == null ? const Color(0xFF6750A4) : Color(0xFF000000 | parsed);
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    var themed = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      textTheme: base.textTheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
    );
    if (registration.webFontFamily == 'playfairDmSans') {
      final sansTextTheme = GoogleFonts.dmSansTextTheme(themed.textTheme);
      themed = themed.copyWith(
        textTheme: sansTextTheme.copyWith(
          displayLarge: GoogleFonts.playfairDisplay(
            textStyle: sansTextTheme.displayLarge,
          ),
          displayMedium: GoogleFonts.playfairDisplay(
            textStyle: sansTextTheme.displayMedium,
          ),
          displaySmall: GoogleFonts.playfairDisplay(
            textStyle: sansTextTheme.displaySmall,
          ),
          headlineLarge: GoogleFonts.playfairDisplay(
            textStyle: sansTextTheme.headlineLarge,
          ),
          headlineMedium: GoogleFonts.playfairDisplay(
            textStyle: sansTextTheme.headlineMedium,
          ),
          headlineSmall: GoogleFonts.playfairDisplay(
            textStyle: sansTextTheme.headlineSmall,
          ),
        ),
        primaryTextTheme: GoogleFonts.dmSansTextTheme(themed.primaryTextTheme),
      );
    } else if (registration.webFontFamily != 'system') {
      themed = themed.copyWith(
        textTheme: GoogleFonts.getTextTheme(
          registration.webFontFamily,
          themed.textTheme,
        ),
        primaryTextTheme: GoogleFonts.getTextTheme(
          registration.webFontFamily,
          themed.primaryTextTheme,
        ),
      );
    }
    return themed;
  }

  Widget _buildForm(PublicSalon salon, BuildContext themedContext) {
    final registration = salon.clientRegistration;
    final extras = registration.extraFields.toSet();
    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.embedded ? 16 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            elevation: widget.embedded ? 0 : 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (salon.logoImageUrl != null) ...[
                      Center(
                        child: Image.network(
                          salon.logoImageUrl!,
                          height: 72,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      registration.webFormTitle,
                      style: Theme.of(themedContext).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      salon.name,
                      style: Theme.of(themedContext).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (registration.webFormDescription?.isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 12),
                      Text(
                        registration.webFormDescription!,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    _twoColumns(
                      TextFormField(
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.givenName],
                        validator: _required,
                        decoration: const InputDecoration(labelText: 'Nome *'),
                      ),
                      TextFormField(
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.familyName],
                        validator: _required,
                        decoration: const InputDecoration(
                          labelText: 'Cognome *',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _twoColumns(
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          labelText: 'Telefono',
                        ),
                      ),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: _emailValidator,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.cake_outlined),
                      label: Text(
                        _dateOfBirth == null
                            ? 'Data di nascita (facoltativa)'
                            : DateFormat('dd/MM/yyyy').format(_dateOfBirth!),
                      ),
                    ),
                    if (extras.contains(
                      ClientRegistrationExtraField.address,
                    )) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        validator: _required,
                        decoration: const InputDecoration(
                          labelText: 'Città di residenza *',
                        ),
                      ),
                    ],
                    if (extras.contains(
                      ClientRegistrationExtraField.profession,
                    )) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _professionController,
                        validator: _required,
                        decoration: const InputDecoration(
                          labelText: 'Professione *',
                        ),
                      ),
                    ],
                    if (extras.contains(
                      ClientRegistrationExtraField.referralSource,
                    )) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _referralController.text.isEmpty
                                ? null
                                : _referralController.text,
                        validator: _required,
                        decoration: const InputDecoration(
                          labelText: 'Come ci hai conosciuto? *',
                        ),
                        items: kClientReferralSourceOptions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            (value) => _referralController.text = value ?? '',
                      ),
                    ],
                    if (extras.contains(
                      ClientRegistrationExtraField.gender,
                    )) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        validator: _required,
                        decoration: const InputDecoration(labelText: 'Sesso *'),
                        items: const [
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Donna'),
                          ),
                          DropdownMenuItem(value: 'male', child: Text('Uomo')),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Altro / non specificato'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _gender = value),
                      ),
                    ],
                    if (extras.contains(
                      ClientRegistrationExtraField.notes,
                    )) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        validator: _required,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(labelText: 'Note *'),
                      ),
                    ],
                    Offstage(
                      offstage: true,
                      child: TextField(
                        controller: _websiteController,
                        keyboardType: TextInputType.url,
                        autofillHints: const [AutofillHints.url],
                      ),
                    ),
                    const SizedBox(height: 20),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _privacyAccepted,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged:
                          (value) =>
                              setState(() => _privacyAccepted = value ?? false),
                      title: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Ho letto e accetto l’informativa privacy *',
                          ),
                          if (registration.privacyPolicyUrl?.isNotEmpty == true)
                            TextButton(
                              onPressed:
                                  () => launchUrl(
                                    Uri.parse(registration.privacyPolicyUrl!),
                                    mode: LaunchMode.externalApplication,
                                  ),
                              child: const Text('Apri'),
                            ),
                        ],
                      ),
                    ),
                    if (registration.marketingConsentEnabled)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _marketingAccepted,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged:
                            (value) => setState(
                              () => _marketingAccepted = value ?? false,
                            ),
                        title: const Text(
                          'Acconsento a ricevere comunicazioni promozionali (facoltativo)',
                        ),
                      ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(themedContext).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _submitting ? null : () => _submit(salon),
                      icon:
                          _submitting
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.send_rounded),
                      label: Text(
                        _submitting ? 'Invio in corso…' : 'Invia i dati',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _twoColumns(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [first, const SizedBox(height: 16), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _PublicFormShell extends StatelessWidget {
  const _PublicFormShell({required this.embedded, required this.child});

  final bool embedded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inheritedTheme = Theme.of(context);
    final effectiveTheme =
        inheritedTheme.brightness == Brightness.light
            ? inheritedTheme
            : ThemeData.light(useMaterial3: true);
    return Theme(
      data: effectiveTheme,
      child: Builder(
        builder: (lightContext) {
          final content = ColoredBox(
            color:
                embedded
                    ? Theme.of(lightContext).colorScheme.surface
                    : const Color(0xFFF7F4EA),
            child: SafeArea(child: child),
          );
          return Scaffold(body: content);
        },
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
