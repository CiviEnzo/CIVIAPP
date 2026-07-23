import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:you_book/services/salons/salon_embed_code_service.dart';

class SalonClientRegistrationSheet extends StatefulWidget {
  const SalonClientRegistrationSheet({super.key, required this.salon});

  final Salon salon;

  @override
  State<SalonClientRegistrationSheet> createState() =>
      _SalonClientRegistrationSheetState();
}

class _SalonClientRegistrationSheetState
    extends State<SalonClientRegistrationSheet> {
  late ClientRegistrationAccessMode _accessMode;
  late Set<ClientRegistrationExtraField> _extraFields;
  late bool _webFormEnabled;
  late bool _marketingConsentEnabled;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _confirmationController;
  late final TextEditingController _privacyUrlController;
  late final TextEditingController _privacyVersionController;
  late final TextEditingController _themeColorController;
  late String _webFontFamily;

  static const _fontOptions = <String, String>{
    'system': 'Font del dispositivo',
    'DM Sans': 'DM Sans',
    'Inter': 'Inter',
    'Lato': 'Lato',
    'Montserrat': 'Montserrat',
    'Playfair Display': 'Playfair Display',
    'playfairDmSans': 'Playfair Display + DM Sans',
    'Poppins': 'Poppins',
  };

  static const _colorPresets = <String>[
    '#6750A4',
    '#8A493A',
    '#C18C5D',
    '#2F6B5F',
    '#1F5D8F',
    '#222222',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.salon.clientRegistration;
    _accessMode = initial.accessMode;
    _extraFields = initial.extraFields.toSet();
    _webFormEnabled = initial.webFormEnabled;
    _marketingConsentEnabled = initial.marketingConsentEnabled;
    _titleController = TextEditingController(text: initial.webFormTitle);
    _descriptionController = TextEditingController(
      text: initial.webFormDescription,
    );
    _confirmationController = TextEditingController(
      text: initial.webFormConfirmationMessage,
    );
    _privacyUrlController = TextEditingController(
      text: initial.privacyPolicyUrl,
    );
    _privacyVersionController = TextEditingController(
      text: initial.privacyVersion,
    );
    _themeColorController = TextEditingController(text: initial.webThemeColor);
    _webFontFamily =
        _fontOptions.containsKey(initial.webFontFamily)
            ? initial.webFontFamily
            : 'system';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _confirmationController.dispose();
    _privacyUrlController.dispose();
    _privacyVersionController.dispose();
    _themeColorController.dispose();
    super.dispose();
  }

  String get _publicOrigin =>
      kIsWeb && Uri.base.hasAuthority
          ? Uri.base.origin
          : SalonEmbedCodeService.productionOrigin;

  String get _publicFormUrl => SalonEmbedCodeService.publicFormUrl(
    origin: _publicOrigin,
    salonId: widget.salon.id,
  );

  String get _iframeCode => SalonEmbedCodeService.iframeCode(
    origin: _publicOrigin,
    salonId: widget.salon.id,
    salonName: widget.salon.name,
  );

  void _toggleExtra(ClientRegistrationExtraField field, bool enabled) {
    setState(() {
      if (enabled) {
        _extraFields.add(field);
      } else {
        _extraFields.remove(field);
      }
    });
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    final title = _titleController.text.trim();
    final confirmation = _confirmationController.text.trim();
    final privacyVersion = _privacyVersionController.text.trim();
    final themeColor = _themeColorController.text.trim().toUpperCase();
    if (_webFormEnabled &&
        (title.isEmpty || confirmation.isEmpty || privacyVersion.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa i testi obbligatori del modulo web.'),
        ),
      );
      return;
    }
    if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(themeColor)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un colore valido nel formato #RRGGBB.'),
        ),
      );
      return;
    }
    final updated = widget.salon.copyWith(
      clientRegistration: ClientRegistrationSettings(
        accessMode: _accessMode,
        extraFields: _extraFields.toList(growable: false),
        webFormEnabled: _webFormEnabled,
        webFormTitle: title.isEmpty ? 'Registrati al salone' : title,
        webFormDescription:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        webFormConfirmationMessage:
            confirmation.isEmpty
                ? 'Grazie, i tuoi dati sono stati inviati al salone.'
                : confirmation,
        privacyPolicyUrl:
            _privacyUrlController.text.trim().isEmpty
                ? null
                : _privacyUrlController.text.trim(),
        privacyVersion: privacyVersion.isEmpty ? '1' : privacyVersion,
        marketingConsentEnabled: _marketingConsentEnabled,
        webThemeColor: themeColor,
        webFontFamily: _webFontFamily,
      ),
    );
    Navigator.of(context).pop(updated);
  }

  String _accessModeLabel(ClientRegistrationAccessMode mode) {
    switch (mode) {
      case ClientRegistrationAccessMode.open:
        return 'Accesso immediato (salone aperto)';
      case ClientRegistrationAccessMode.approval:
        return 'Solo previa approvazione';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extraOptions = <ClientRegistrationExtraField, String>{
      ClientRegistrationExtraField.address: 'Richiedi città di residenza',
      ClientRegistrationExtraField.profession: 'Richiedi professione',
      ClientRegistrationExtraField.referralSource:
          'Richiedi "Come ci ha conosciuto?"',
      ClientRegistrationExtraField.notes: 'Richiedi note aggiuntive',
      ClientRegistrationExtraField.gender: 'Richiedi sesso',
    };

    return DialogActionLayout(
      title: 'Registrazione clienti',
      subtitle:
          'Configura le richieste dall’app e il modulo anagrafico per il sito web.',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Richieste dall’app', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<ClientRegistrationAccessMode>(
            isExpanded: true,
            initialValue: _accessMode,
            decoration: const InputDecoration(labelText: 'Modalità di accesso'),
            items: ClientRegistrationAccessMode.values
                .map(
                  (mode) => DropdownMenuItem(
                    value: mode,
                    child: Text(_accessModeLabel(mode)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _accessMode = value);
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _webFormEnabled,
            onChanged: (value) => setState(() => _webFormEnabled = value),
            title: const Text('Modulo anagrafico web'),
            subtitle: const Text(
              'Ricevi i dati nel tab Clienti > Arrivi dal web.',
            ),
          ),
          if (_webFormEnabled) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Titolo del modulo'),
            ),
            TextFormField(
              controller: _descriptionController,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Testo introduttivo (facoltativo)',
              ),
            ),
            TextFormField(
              controller: _confirmationController,
              maxLength: 300,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Messaggio dopo l’invio',
              ),
            ),
            TextFormField(
              controller: _privacyUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL informativa privacy (facoltativo)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _privacyVersionController,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Versione informativa privacy',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _marketingConsentEnabled,
              onChanged:
                  (value) => setState(() => _marketingConsentEnabled = value),
              title: const Text('Mostra consenso marketing facoltativo'),
            ),
            const SizedBox(height: 16),
            Text('Aspetto iframe', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Personalizza il modulo per abbinarlo allo stile del sito.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colorPresets
                  .map((hex) {
                    final color = Color(
                      int.parse(hex.substring(1), radix: 16) | 0xFF000000,
                    );
                    final selected =
                        _themeColorController.text.trim().toUpperCase() == hex;
                    return InkWell(
                      onTap: () {
                        setState(() => _themeColorController.text = hex);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                selected
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.outlineVariant,
                            width: selected ? 3 : 1,
                          ),
                        ),
                        child:
                            selected
                                ? Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color:
                                      ThemeData.estimateBrightnessForColor(
                                                color,
                                              ) ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                )
                                : null,
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _themeColorController,
              decoration: const InputDecoration(
                labelText: 'Colore principale',
                hintText: '#6750A4',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                LengthLimitingTextInputFormatter(7),
              ],
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _webFontFamily,
              decoration: const InputDecoration(labelText: 'Font del modulo'),
              items: _fontOptions.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _webFontFamily = value);
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Campi aggiuntivi obbligatori',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...extraOptions.entries.map((entry) {
              final isSelected = _extraFields.contains(entry.key);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: isSelected,
                onChanged: (value) => _toggleExtra(entry.key, value ?? false),
                title: Text(entry.value),
              );
            }),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collegamento al sito',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(_publicFormUrl),
                    const SizedBox(height: 12),
                    Text('Codice iframe', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _iframeCode,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Incolla questo codice in un blocco HTML del sito.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              () => _copy(_publicFormUrl, 'Link copiato.'),
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('Copia link'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              () =>
                                  _copy(_iframeCode, 'Codice iframe copiato.'),
                          icon: const Icon(Icons.code_rounded),
                          label: const Text('Copia iframe'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Campi aggiuntivi per le richieste dall’app',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...extraOptions.entries.map((entry) {
              final isSelected = _extraFields.contains(entry.key);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: isSelected,
                onChanged: (value) => _toggleExtra(entry.key, value ?? false),
                title: Text(entry.value),
              );
            }),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salva')),
      ],
    );
  }
}
