import 'package:civiapp/app/providers.dart';
import 'package:civiapp/data/branding/branding_model.dart';
import 'package:civiapp/domain/branding/branding_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kHexPattern = r'^#?[0-9A-Fa-f]{6}$';
final RegExp _kHexRegex = RegExp(_kHexPattern);

const List<String> _kQuickBrandingColors = [
  '#6750A4',
  '#93328E',
  '#4F378B',
  '#1E88E5',
  '#43A047',
  '#F4511E',
];

const List<String> _kExtendedBrandingColors = [
  '#6750A4',
  '#7D5260',
  '#93328E',
  '#4F378B',
  '#1E88E5',
  '#2196F3',
  '#43A047',
  '#00897B',
  '#F4511E',
  '#FF9800',
  '#FFB300',
  '#F06292',
  '#5E35B1',
  '#546E7A',
  '#263238',
  '#F4B400',
];

bool _isValidHexValue(String value) => _kHexRegex.hasMatch(value.trim());

String _normalizeHexValue(String value) {
  final trimmed = value.trim();
  final hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  return '#${hex.toUpperCase()}';
}

Color? _tryParseHexColor(String value) {
  if (!_isValidHexValue(value)) {
    return null;
  }
  final normalized = _normalizeHexValue(value);
  return Color(int.parse('FF${normalized.substring(1)}', radix: 16));
}

class BrandingAdminPage extends ConsumerStatefulWidget {
  const BrandingAdminPage({super.key});

  @override
  ConsumerState<BrandingAdminPage> createState() => _BrandingAdminPageState();
}

class _BrandingAdminPageState extends ConsumerState<BrandingAdminPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _primaryColorController;
  late final TextEditingController _accentColorController;

  bool _autoValidate = false;
  bool _updatingControllers = false;
  bool _hasLocalChanges = false;
  bool _isSaving = false;

  String _selectedThemeMode = 'system';
  String? _selectedAppBarStyle;

  BrandingModel? _currentBranding;
  Uint8List? _logoBytes;
  String? _logoUrl;
  String? _selectedLogoName;

  ProviderSubscription<AsyncValue<BrandingModel>>? _brandingSubscription;

  @override
  void initState() {
    super.initState();
    _primaryColorController = TextEditingController();
    _accentColorController = TextEditingController();
    _primaryColorController.addListener(_handleFieldChange);
    _accentColorController.addListener(_handleFieldChange);

    _brandingSubscription = ref.listenManual<AsyncValue<BrandingModel>>(
      salonBrandingProvider,
      (previous, next) => next.whenData(_syncFromBranding),
    );

    ref.read(salonBrandingProvider).whenData(_syncFromBranding);
  }

  @override
  void dispose() {
    _brandingSubscription?.close();

    _primaryColorController
      ..removeListener(_handleFieldChange)
      ..dispose();
    _accentColorController
      ..removeListener(_handleFieldChange)
      ..dispose();
    super.dispose();
  }

  void _handleFieldChange() {
    if (_updatingControllers) {
      return;
    }
    setState(() {
      _hasLocalChanges = true;
    });
  }

  void _syncFromBranding(BrandingModel branding) {
    _currentBranding = branding;
    if (!mounted) {
      return;
    }

    if (!_hasLocalChanges) {
      _updatingControllers = true;
      _primaryColorController.text = branding.primaryColor;
      _accentColorController.text = branding.accentColor;
      _selectedThemeMode = branding.themeMode;
      _selectedAppBarStyle = branding.appBarStyle;
      _logoUrl = branding.logoUrl;
      _logoBytes = null;
      _selectedLogoName = null;
      _updatingControllers = false;
      setState(() {});
    } else {
      setState(() {
        _logoUrl = branding.logoUrl ?? _logoUrl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final salonId = ref.watch(currentSalonIdProvider);
    final brandingAsync = ref.watch(salonBrandingProvider);
    final theme = Theme.of(context);
    final canSave = !_isSaving && _hasLocalChanges;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Chiudi',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Personalizzazione branding'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(
              onPressed: canSave ? _saveBranding : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child:
                  _isSaving
                      ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Salvataggio...'),
                        ],
                      )
                      : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.save_rounded),
                          SizedBox(width: 8),
                          Text('Salva'),
                        ],
                      ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child:
            salonId == null
                ? const Center(
                  child: Text(
                    'Seleziona un salone per configurare il branding',
                  ),
                )
                : brandingAsync.when(
                  data: (_) => _buildContent(context),
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (error, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Impossibile caricare il branding: $error',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;
        final preview = Expanded(
          flex: isWide ? 3 : 0,
          child: _BrandingPreviewCard(
            colorScheme: _buildPreviewScheme(context),
            logoBytes: _logoBytes,
            logoUrl: _logoUrl,
            themeMode: _selectedThemeMode,
            appBarStyle: _selectedAppBarStyle,
            fileName:
                _selectedLogoName ?? (_logoUrl != null ? 'Logo attuale' : null),
          ),
        );
        final form = Expanded(flex: 4, child: _buildFormCard(context));

        final children =
            isWide
                ? [preview, const SizedBox(width: 24), form]
                : [preview, const SizedBox(height: 24), form];

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child:
                  isWide
                      ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      )
                      : Column(children: children),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode:
              _autoValidate
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Personalizzazione tema', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Colori', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _ColorField(
                controller: _primaryColorController,
                label: 'Colore primario',
                helper: 'Formato #RRGGBB',
                validator: _validateColor,
              ),
              const SizedBox(height: 16),
              _ColorField(
                controller: _accentColorController,
                label: 'Colore secondario',
                helper: 'Formato #RRGGBB',
                validator: _validateColor,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedThemeMode,
                decoration: const InputDecoration(
                  labelText: 'Tema predefinito',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text('Segui sistema'),
                  ),
                  DropdownMenuItem(value: 'light', child: Text('Chiaro')),
                  DropdownMenuItem(value: 'dark', child: Text('Scuro')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedThemeMode = value;
                    _hasLocalChanges = true;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: _selectedAppBarStyle,
                decoration: const InputDecoration(labelText: 'Stile AppBar'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Standard')),
                  DropdownMenuItem(
                    value: 'elevated',
                    child: Text('Elevata (ombra)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedAppBarStyle = value;
                    _hasLocalChanges = true;
                  });
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text('Logo del salone', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Immagine PNG, JPG, WEBP o SVG. Dimensione massima 5MB.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _pickLogo,
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('Carica logo'),
                  ),
                  if ((_logoBytes != null || _logoUrl != null) && !_isSaving)
                    TextButton.icon(
                      onPressed: _removeLogo,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Rimuovi logo'),
                    ),
                  if (_selectedLogoName != null)
                    Text(_selectedLogoName!, style: theme.textTheme.bodySmall)
                  else if (_logoUrl != null)
                    Text('Logo corrente', style: theme.textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 32),
              if (_hasLocalChanges)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Premi "Salva" in alto a destra per applicare le modifiche.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              if (_hasLocalChanges) const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      !_isSaving && _hasLocalChanges ? _resetToBranding : null,
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Annulla modifiche'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ColorScheme _buildPreviewScheme(BuildContext context) {
    final fallback = Theme.of(context).colorScheme;
    final primary = _primaryColorController.text.trim();
    final accent = _accentColorController.text.trim();
    if (!_isValidHex(primary) || !_isValidHex(accent)) {
      return _currentBranding?.toColorScheme(Brightness.light) ?? fallback;
    }

    try {
      final model = BrandingModel(
        primaryColor: _normalizeColor(primary),
        accentColor: _normalizeColor(accent),
        themeMode: _selectedThemeMode,
        logoUrl: _logoUrl,
        appBarStyle: _selectedAppBarStyle,
      );
      return model.toColorScheme(Brightness.light);
    } catch (_) {
      return _currentBranding?.toColorScheme(Brightness.light) ?? fallback;
    }
  }

  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'svg'],
        withData: true,
      );
      if (result == null) {
        return;
      }
      final file = result.files.single;
      if (file.size > 5 * 1024 * 1024) {
        _showSnackBar('Il file selezionato supera i 5MB consentiti.');
        return;
      }
      final bytes = file.bytes;
      if (bytes == null) {
        _showSnackBar('Impossibile leggere il file selezionato.');
        return;
      }
      setState(() {
        _logoBytes = bytes;
        _selectedLogoName = file.name;
        _hasLocalChanges = true;
      });
    } on PlatformException catch (error) {
      _showSnackBar('Errore durante la selezione del file: ${error.message}');
    }
  }

  void _removeLogo() {
    setState(() {
      _logoBytes = null;
      _logoUrl = null;
      _selectedLogoName = null;
      _hasLocalChanges = true;
    });
  }

  Future<void> _saveBranding() async {
    final form = _formKey.currentState;
    if (form == null) {
      return;
    }

    if (!form.validate()) {
      setState(() {
        _autoValidate = true;
      });
      return;
    }

    final salonId = ref.read(currentSalonIdProvider);
    if (salonId == null) {
      _showSnackBar('Nessun salone selezionato.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      String? downloadUrl = _logoUrl;
      if (_logoBytes != null) {
        downloadUrl = await ref
            .read(firebaseStorageServiceProvider)
            .uploadSalonLogo(
              salonId: salonId,
              data: _logoBytes!,
              fileName: _selectedLogoName,
            );
      }

      final branding = BrandingModel(
        primaryColor: _normalizeColor(_primaryColorController.text),
        accentColor: _normalizeColor(_accentColorController.text),
        themeMode: _selectedThemeMode,
        logoUrl: downloadUrl,
        appBarStyle: _selectedAppBarStyle,
      );

      await ref
          .read(brandingRepositoryProvider)
          .saveSalonBranding(salonId: salonId, data: branding);

      await ref.read(brandingCacheProvider).save(salonId, branding);

      setState(() {
        _isSaving = false;
        _hasLocalChanges = false;
        _autoValidate = false;
        _logoBytes = null;
        _selectedLogoName = null;
        _logoUrl = downloadUrl;
      });
      _showSnackBar('Branding aggiornato con successo.');
    } catch (error) {
      setState(() {
        _isSaving = false;
      });
      _showSnackBar('Errore durante il salvataggio: $error');
    }
  }

  void _resetToBranding() {
    final branding = _currentBranding;
    if (branding == null) {
      return;
    }
    _updatingControllers = true;
    _primaryColorController.text = branding.primaryColor;
    _accentColorController.text = branding.accentColor;
    _updatingControllers = false;
    setState(() {
      _selectedThemeMode = branding.themeMode;
      _selectedAppBarStyle = branding.appBarStyle;
      _logoUrl = branding.logoUrl;
      _logoBytes = null;
      _selectedLogoName = null;
      _hasLocalChanges = false;
      _autoValidate = false;
    });
  }

  bool _isValidHex(String value) => _isValidHexValue(value);

  String _normalizeColor(String value) => _normalizeHexValue(value);

  String? _validateColor(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Inserisci un colore esadecimale.';
    }
    if (!_isValidHex(text)) {
      return 'Formato non valido (usa #RRGGBB).';
    }
    return null;
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ColorField extends StatelessWidget {
  const _ColorField({
    required this.controller,
    required this.label,
    required this.helper,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String helper;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Future<void> openPalette() async {
      final current = controller.text;
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder:
            (context) => _ColorPaletteSheet(
              selectedColor:
                  _isValidHexValue(current)
                      ? _normalizeHexValue(current)
                      : null,
            ),
      );
      if (selected != null) {
        controller.text = selected;
      }
    }

    final normalizedValue =
        _isValidHexValue(controller.text)
            ? _normalizeHexValue(controller.text)
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            prefixIcon: _ColorPreviewDot(controller: controller),
            suffixIcon: IconButton(
              tooltip: 'Apri selettore colori',
              icon: const Icon(Icons.palette_outlined),
              onPressed: openPalette,
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f#]')),
            _UppercaseTextFormatter(),
          ],
          validator: validator,
        ),
        const SizedBox(height: 8),
        Text('Palette rapida', style: theme.textTheme.labelSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in _kQuickBrandingColors)
              _ColorSwatchButton(
                hexValue: hex,
                isSelected: normalizedValue == hex,
                onTap: () => controller.text = hex,
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.hexValue,
    required this.isSelected,
    required this.onTap,
  });

  final String hexValue;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _tryParseHexColor(hexValue) ?? Colors.transparent;
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  isSelected
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                    : null,
          ),
          alignment: Alignment.center,
          child:
              isSelected
                  ? Icon(Icons.check_rounded, size: 18, color: onColor)
                  : null,
        ),
      ),
    );
  }
}

class _ColorPaletteSheet extends StatelessWidget {
  const _ColorPaletteSheet({required this.selectedColor});

  final String? selectedColor;

  @override
  Widget build(BuildContext context) {
    final normalized =
        selectedColor != null && _isValidHexValue(selectedColor!)
            ? _normalizeHexValue(selectedColor!)
            : null;

    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seleziona un colore', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final hex in _kExtendedBrandingColors)
                  _ColorSwatchButton(
                    hexValue: hex,
                    isSelected: normalized == hex,
                    onTap: () => Navigator.of(context).pop(hex),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Suggerimento: incolla un codice esadecimale personalizzato nel campo per un colore su misura.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPreviewDot extends StatefulWidget {
  const _ColorPreviewDot({required this.controller});

  final TextEditingController controller;

  @override
  State<_ColorPreviewDot> createState() => _ColorPreviewDotState();
}

class _ColorPreviewDotState extends State<_ColorPreviewDot> {
  late final VoidCallback _listener;
  Color _color = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _listener =
        () => setState(() {
          _color = _parseColor(widget.controller.text);
        });
    widget.controller.addListener(_listener);
    _color = _parseColor(widget.controller.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: CircleAvatar(radius: 10, backgroundColor: _color),
    );
  }

  Color _parseColor(String value) {
    final parsed = _tryParseHexColor(value.trim());
    return parsed ?? Colors.transparent;
  }
}

class _UppercaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _BrandingPreviewCard extends StatelessWidget {
  const _BrandingPreviewCard({
    required this.colorScheme,
    required this.logoBytes,
    required this.logoUrl,
    required this.themeMode,
    required this.appBarStyle,
    required this.fileName,
  });

  final ColorScheme colorScheme;
  final Uint8List? logoBytes;
  final String? logoUrl;
  final String themeMode;
  final String? appBarStyle;
  final String? fileName;

  static const Map<String, String> _themeLabels = {
    'system': 'Segue sistema',
    'light': 'Chiaro',
    'dark': 'Scuro',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 180,
            padding: const EdgeInsets.all(24),
            color: colorScheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LogoPreview(logoBytes: logoBytes, logoUrl: logoUrl),
                const Spacer(),
                Text(
                  'Anteprima',
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _themeLabels[themeMode] ?? 'Tema personalizzato',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Palette', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ColorBadge(
                      label: 'Primario',
                      backgroundColor: colorScheme.primary,
                      textColor: colorScheme.onPrimary,
                    ),
                    _ColorBadge(
                      label: 'Secondario',
                      backgroundColor: colorScheme.secondary,
                      textColor: colorScheme.onSecondary,
                    ),
                    _ColorBadge(
                      label: 'Superficie',
                      backgroundColor: colorScheme.surface,
                      textColor: colorScheme.onSurface,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('AppBar', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    appBarStyle == 'elevated'
                        ? Icons.view_agenda_outlined
                        : Icons.web_asset,
                  ),
                  title: Text(
                    appBarStyle == 'elevated'
                        ? 'Elevata con ombra'
                        : 'Standard senza ombra',
                  ),
                  subtitle: fileName != null ? Text(fileName!) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({this.logoBytes, this.logoUrl});

  final Uint8List? logoBytes;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.apartment_rounded,
      size: 48,
      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
    );

    Widget? logoWidget;
    if (logoBytes != null) {
      logoWidget = Image.memory(logoBytes!, height: 64, fit: BoxFit.contain);
    } else if (logoUrl != null && logoUrl!.isNotEmpty) {
      logoWidget = Image.network(
        logoUrl!,
        height: 64,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return Container(
      height: 72,
      width: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: logoWidget ?? placeholder,
    );
  }
}

class _ColorBadge extends StatelessWidget {
  const _ColorBadge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: backgroundColor,
      label: Text(label, style: TextStyle(color: textColor)),
    );
  }
}
