import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/common/hybrid_image_picker.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:you_book/presentation/screens/client/client_theme.dart';
import 'package:you_book/presentation/shared/promotion_palette.dart';

class PromotionEditorDialog extends ConsumerStatefulWidget {
  const PromotionEditorDialog({
    required this.salonId,
    this.salon,
    this.initialPromotion,
    super.key,
  });

  final String salonId;
  final Salon? salon;
  final Promotion? initialPromotion;

  @override
  ConsumerState<PromotionEditorDialog> createState() =>
      _PromotionEditorDialogState();
}

class _PromotionEditorDialogState extends ConsumerState<PromotionEditorDialog>
    with SingleTickerProviderStateMixin {
  static const int _maxImageBytes = 6 * 1024 * 1024;
  static const List<Color> _accentPalette = <Color>[
    Color(0xFF921625),
    Color(0xFF6A1B9A),
    Color(0xFF2F5BFF),
    Color(0xFF0E7C7B),
    Color(0xFF1E8E3E),
    Color(0xFFFF7043),
    Color(0xFFD81B60),
    Color(0xFF546E7A),
  ];

  final _formKey = GlobalKey<FormState>();
  final _detailsScrollController = ScrollController();
  final _contentScrollController = ScrollController();
  final _previewTabScrollController = ScrollController();
  final _previewRailScrollController = ScrollController();
  final _previewPageScrollController = ScrollController();
  late final TabController _tabController;

  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _taglineController;
  late final TextEditingController _discountController;
  late final TextEditingController _priorityController;
  late final TextEditingController _ctaLabelController;
  late final TextEditingController _ctaCustomUrlController;
  late final TextEditingController _ctaPhoneController;
  late final TextEditingController _ctaWhatsappMessageController;
  late final TextEditingController _accentHexController;
  String? _accentHexError;

  late final String _promotionId;
  PromotionStatus _status = PromotionStatus.draft;
  DateTime? _startsAt;
  DateTime? _endsAt;
  String? _coverImageUrl;
  String? _coverImagePath;
  bool _isUploadingCover = false;
  String? _coverUploadError;
  String? _coverUploadInfo;

  final List<_EditablePromotionSection> _sections =
      <_EditablePromotionSection>[];
  final _sectionUploadErrors = <String, String?>{};
  final _SectionExpansionState _expansionState = _SectionExpansionState();

  PromotionCtaType _ctaType = PromotionCtaType.none;
  bool _ctaEnabled = true;
  Color? _accentColor;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_handleTabChanged);
    final initial = widget.initialPromotion;
    _promotionId = initial?.id ?? const Uuid().v4();
    _titleController = TextEditingController(text: initial?.title ?? '');
    _subtitleController = TextEditingController(text: initial?.subtitle ?? '');
    _taglineController = TextEditingController(text: initial?.tagline ?? '');
    _discountController = TextEditingController(
      text: initial?.discountPercentage.toString() ?? '0',
    );
    _priorityController = TextEditingController(
      text: initial?.priority.toString() ?? '0',
    );
    _ctaLabelController = TextEditingController(
      text: initial?.cta?.label ?? 'Contatta il salone',
    );
    _ctaCustomUrlController = TextEditingController();
    _ctaPhoneController = TextEditingController();
    _ctaWhatsappMessageController = TextEditingController();
    final initialThemeColor = initial?.themeColor;
    _accentColor = initialThemeColor != null ? Color(initialThemeColor) : null;
    _accentHexController = TextEditingController(
      text: initialThemeColor != null ? _colorToHex(initialThemeColor) : '',
    );
    _startsAt = initial?.startsAt;
    _endsAt = initial?.endsAt;
    _coverImageUrl = initial?.coverImageUrl;
    _coverImagePath = initial?.coverImagePath;
    _initializeStatus(initial);
    _initializeCta(initial);
    _initializeSections(initial);
  }

  void _handleTabChanged() {
    if (!mounted) {
      return;
    }
    if (_activeTabIndex != _tabController.index) {
      setState(() {
        _activeTabIndex = _tabController.index;
      });
    }
  }

  void _initializeStatus(Promotion? initial) {
    if (initial?.status != null) {
      _status = initial!.status;
      return;
    }
    if (initial?.isActive == true) {
      _status = PromotionStatus.published;
    } else {
      _status = PromotionStatus.draft;
    }
  }

  void _initializeSections(Promotion? initial) {
    final sections = initial?.sections ?? const <PromotionSection>[];
    if (sections.isEmpty && widget.initialPromotion == null) {
      final section = _EditablePromotionSection.text(
        id: const Uuid().v4(),
        initialText: '',
      );
      _sections.add(section);
      _expansionState.expand(section.id);
      return;
    }
    final sorted = sections.toList()..sort((a, b) => a.order - b.order);
    for (final section in sorted) {
      late final _EditablePromotionSection editable;
      switch (section.type) {
        case PromotionSectionType.text:
          editable = _EditablePromotionSection.text(
            id: section.id.isEmpty ? const Uuid().v4() : section.id,
            initialTitle: section.title ?? '',
            initialText: section.text ?? '',
            layout: section.layout,
            visible: section.visible,
          );
          break;
        case PromotionSectionType.image:
          editable = _EditablePromotionSection.image(
            id: section.id.isEmpty ? const Uuid().v4() : section.id,
            initialTitle: section.title ?? '',
            imageUrl: section.imageUrl,
            imagePath: section.imagePath,
            altText: section.altText ?? '',
            caption: section.caption ?? '',
            layout: section.layout,
            visible: section.visible,
          );
          break;
      }
      _sections.add(editable);
      _expansionState.expand(editable.id);
    }
  }

  void _initializeCta(Promotion? initial) {
    final salon = widget.salon;
    final cta = initial?.cta;
    final ctaUrl = initial?.ctaUrl ?? cta?.url;
    var resolvedType = _inferInitialCtaType(
      cta: cta,
      ctaUrl: ctaUrl,
      salon: salon,
    );
    final hasBookingLink = salon?.bookingLink?.trim().isNotEmpty == true;
    if (resolvedType == PromotionCtaType.booking && !hasBookingLink) {
      resolvedType = PromotionCtaType.link;
    }
    _ctaType = resolvedType;
    _ctaEnabled = cta?.enabled ?? true;
    final defaultPhone = salon?.phone ?? '';
    final phoneForEditing = _displayPhoneForEditing(
      cta?.phoneNumber,
      defaultPhone,
      resolvedType,
    );
    _ctaPhoneController.text = phoneForEditing;
    if (resolvedType == PromotionCtaType.link) {
      _ctaCustomUrlController.text = ctaUrl ?? '';
    } else if (resolvedType == PromotionCtaType.booking &&
        salon?.bookingLink != null) {
      _ctaCustomUrlController.text = salon!.bookingLink!;
    } else {
      _ctaCustomUrlController.text = '';
    }
    if (resolvedType == PromotionCtaType.whatsapp) {
      final message =
          cta?.messageTemplate ?? _defaultWhatsappMessage(initial?.title);
      _ctaWhatsappMessageController.text = message;
    } else {
      _ctaWhatsappMessageController.text = _defaultWhatsappMessage(
        initial?.title,
      );
    }
  }

  String _colorToHex(int value) {
    final hex = value.toRadixString(16).padLeft(8, '0');
    return hex.substring(2).toUpperCase();
  }

  void _setAccentColor(Color? color, {bool updateField = true}) {
    setState(() {
      _accentColor = color;
      _accentHexError = null;
      if (updateField) {
        final text = color != null ? _colorToHex(color.toARGB32()) : '';
        _accentHexController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    });
  }

  void _handleAccentHexChanged(String rawValue) {
    final sanitized = rawValue.replaceAll('#', '').toUpperCase();
    if (sanitized != rawValue) {
      _accentHexController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }
    setState(() {
      if (sanitized.isEmpty) {
        _accentColor = null;
        _accentHexError = null;
        return;
      }
      if (sanitized.length == 6) {
        final parsed = int.tryParse('0xFF$sanitized');
        if (parsed != null) {
          _accentColor = Color(parsed);
          _accentHexError = null;
        } else {
          _accentHexError = 'Valore non valido';
        }
      } else {
        _accentHexError = 'Usa 6 caratteri esadecimali';
      }
    });
  }

  InputDecoration _modalFieldDecoration(
    ThemeData theme, {
    String? hintText,
    String? helperText,
    String? errorText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
    String? prefixText,
    bool dense = false,
  }) {
    final scheme = theme.colorScheme;
    return InputDecoration(
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixText: prefixText,
      isDense: dense,
      filled: true,
      fillColor:
          theme.brightness == Brightness.dark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.9),
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.4),
      ),
    );
  }

  Widget _buildFieldGroup(
    ThemeData theme, {
    required String label,
    required Widget child,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardPanel(
    ThemeData theme, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color:
            theme.brightness == Brightness.dark
                ? scheme.surface.withValues(alpha: 0.98)
                : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _buildStatusSelector(ThemeData theme) {
    return _buildFieldGroup(
      theme,
      label: 'STATO',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _StatusChip(
            status: PromotionStatus.draft,
            groupValue: _status,
            onChanged: (value) => setState(() => _status = value),
          ),
          _StatusChip(
            status: PromotionStatus.scheduled,
            groupValue: _status,
            onChanged: (value) => setState(() => _status = value),
          ),
          _StatusChip(
            status: PromotionStatus.published,
            groupValue: _status,
            onChanged: (value) => setState(() => _status = value),
          ),
        ],
      ),
    );
  }

  Widget _buildValidityPanel(ThemeData theme, {required bool stacked}) {
    return _buildCardPanel(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Periodo di validita',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          if (stacked)
            Column(
              children: [
                _DatePickerField(
                  label: 'INIZIO PROMO',
                  value: _startsAt,
                  onChanged: (value) => setState(() => _startsAt = value),
                ),
                const SizedBox(height: 12),
                _DatePickerField(
                  label: 'FINE PROMO',
                  value: _endsAt,
                  onChanged: (value) => setState(() => _endsAt = value),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _DatePickerField(
                    label: 'INIZIO PROMO',
                    value: _startsAt,
                    onChanged: (value) => setState(() => _startsAt = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerField(
                    label: 'FINE PROMO',
                    value: _endsAt,
                    onChanged: (value) => setState(() => _endsAt = value),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCtaPanel(ThemeData theme) {
    return _PromotionExpandablePanel(
      title: 'Call to action',
      subtitle: 'Scegli cosa succede quando il cliente tocca "Contatta"',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<PromotionCtaType>(
            isExpanded: true,
            initialValue: _ctaType,
            decoration: _modalFieldDecoration(
              theme,
              hintText: 'Seleziona un\'azione',
            ),
            items: _buildCtaTypeItems(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _ctaType = value;
              });
            },
          ),
          if (_ctaType != PromotionCtaType.none) ...[
            const SizedBox(height: 12),
            _buildFieldGroup(
              theme,
              label: 'TESTO BOTTONE',
              child: TextFormField(
                controller: _ctaLabelController,
                decoration: _modalFieldDecoration(
                  theme,
                  hintText: 'Es. Prenota ora',
                ),
              ),
            ),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pulsante CTA attivo'),
              subtitle: const Text(
                'Disattiva temporaneamente l’azione senza eliminarla.',
              ),
              value: _ctaEnabled,
              onChanged: (value) => setState(() => _ctaEnabled = value),
            ),
          ],
          if (_ctaType == PromotionCtaType.link ||
              _ctaType == PromotionCtaType.booking) ...[
            const SizedBox(height: 12),
            _buildFieldGroup(
              theme,
              label: 'URL DESTINAZIONE',
              child: TextFormField(
                controller: _ctaCustomUrlController,
                decoration: _modalFieldDecoration(theme, hintText: 'https://'),
                validator: _validateCustomUrl,
              ),
            ),
          ],
          if (_ctaType == PromotionCtaType.phone ||
              _ctaType == PromotionCtaType.whatsapp) ...[
            const SizedBox(height: 12),
            _buildFieldGroup(
              theme,
              label: 'NUMERO DI TELEFONO',
              child: TextFormField(
                controller: _ctaPhoneController,
                decoration: _modalFieldDecoration(theme, hintText: '+39...'),
                validator: _validatePhoneNumber,
              ),
            ),
          ],
          if (_ctaType == PromotionCtaType.whatsapp) ...[
            const SizedBox(height: 12),
            _buildFieldGroup(
              theme,
              label: 'MESSAGGIO PRECOMPILATO',
              child: TextFormField(
                controller: _ctaWhatsappMessageController,
                maxLines: 3,
                decoration: _modalFieldDecoration(
                  theme,
                  hintText: 'Messaggio WhatsApp',
                  helperText: 'Personalizza il testo che apparira in WhatsApp.',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedPanel(ThemeData theme) {
    return _PromotionExpandablePanel(
      title: 'Impostazioni avanzate',
      subtitle: 'Configura opzioni avanzate',
      collapsedAccentText: 'Configura opzioni avanzate',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildFieldGroup(
                  theme,
                  label: 'SCONTO (%)',
                  child: TextFormField(
                    controller: _discountController,
                    decoration: _modalFieldDecoration(theme, hintText: '0'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFieldGroup(
                  theme,
                  label: 'PRIORITA ELENCO',
                  child: TextFormField(
                    controller: _priorityController,
                    decoration: _modalFieldDecoration(theme, hintText: '0'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
            ],
          ),
          if (_previewCtaUrl() != null) ...[
            const SizedBox(height: 12),
            _buildCardPanel(
              theme,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _previewCtaUrl()!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _detailsScrollController.dispose();
    _contentScrollController.dispose();
    _previewTabScrollController.dispose();
    _previewRailScrollController.dispose();
    _previewPageScrollController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _taglineController.dispose();
    _discountController.dispose();
    _priorityController.dispose();
    _ctaLabelController.dispose();
    _ctaCustomUrlController.dispose();
    _ctaPhoneController.dispose();
    _ctaWhatsappMessageController.dispose();
    _accentHexController.dispose();
    for (final section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mediaSize = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1280,
          maxHeight: mediaSize.height * 0.96,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                theme.brightness == Brightness.dark
                    ? scheme.surface
                    : const Color(0xFFF7F7F5),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.initialPromotion == null
                              ? 'Nuova promozione'
                              : 'Modifica promozione',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Chiudi',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: scheme.primary,
                    unselectedLabelColor: scheme.onSurfaceVariant,
                    labelStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    indicatorColor: scheme.primary,
                    indicatorWeight: 2,
                    dividerColor: Colors.transparent,
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    tabs: const [
                      Tab(text: 'Dettagli'),
                      Tab(text: 'Contenuto'),
                      Tab(text: 'Anteprima'),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                Flexible(
                  fit: FlexFit.loose,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(
                      key: ValueKey(_activeTabIndex),
                      child: _buildTabContent(theme),
                    ),
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 16, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.primary,
                        ),
                        child: const Text('Annulla'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(156, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          widget.initialPromotion == null
                              ? 'Crea promozione'
                              : 'Salva promozione',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ThemeData theme) {
    switch (_activeTabIndex) {
      case 0:
        return _buildDetailsStep(theme);
      case 1:
        return _buildContentStep(theme);
      case 2:
        return _buildPreviewStep(theme);
    }
    return _buildDetailsStep(theme);
  }

  Widget _buildTabViewport({required double maxWidth, required Widget child}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  Widget _buildDetailsStep(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _detailsScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _detailsScrollController,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            child: _buildTabViewport(
              maxWidth: 1120,
              child: LayoutBuilder(
                builder: (context, innerConstraints) {
                  final isWide = innerConstraints.maxWidth >= 1040;
                  final detailsColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldGroup(
                        theme,
                        label: 'TITOLO PROMOZIONE *',
                        child: TextFormField(
                          controller: _titleController,
                          decoration: _modalFieldDecoration(
                            theme,
                            hintText: 'Inserisci il titolo',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Inserisci un titolo';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildFieldGroup(
                        theme,
                        label: 'SOTTOTITOLO (OPZIONALE)',
                        child: TextFormField(
                          controller: _subtitleController,
                          decoration: _modalFieldDecoration(
                            theme,
                            hintText: 'Inserisci il sottotitolo',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildFieldGroup(
                        theme,
                        label: 'TAGLINE BREVE (OPZIONALE)',
                        child: TextFormField(
                          controller: _taglineController,
                          decoration: _modalFieldDecoration(
                            theme,
                            hintText: 'Inserisci una tagline',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildStatusSelector(theme),
                    ],
                  );
                  final settingsColumn = Column(
                    children: [
                      _buildValidityPanel(theme, stacked: false),
                      const SizedBox(height: 16),
                      _buildCtaPanel(theme),
                      const SizedBox(height: 16),
                      _buildAdvancedPanel(theme),
                    ],
                  );
                  if (!isWide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        detailsColumn,
                        const SizedBox(height: 16),
                        _buildValidityPanel(theme, stacked: true),
                        const SizedBox(height: 16),
                        _buildCtaPanel(theme),
                        const SizedBox(height: 16),
                        _buildAdvancedPanel(theme),
                      ],
                    );
                  }
                  final leftWidth = 560.0;
                  final rightWidth = math.min(
                    460.0,
                    innerConstraints.maxWidth - leftWidth - 18,
                  );
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: leftWidth + 18 + rightWidth,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: leftWidth, child: detailsColumn),
                          const SizedBox(width: 18),
                          SizedBox(width: rightWidth, child: settingsColumn),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppearanceSection(ThemeData theme) {
    final selected = _accentColor;
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;
    return _buildCardPanel(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aspetto grafico',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Scegli il colore usato da badge, bottoni e sfumature della promo.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in _accentPalette)
                _AccentColorSwatch(
                  color: color,
                  selected: selected?.toARGB32() == color.toARGB32(),
                  onTap: () => _setAccentColor(color),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: selected ?? scheme.primary,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: scheme.outlineVariant),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _accentHexController,
                  maxLength: 6,
                  decoration: _modalFieldDecoration(
                    theme,
                    hintText: 'C6A052',
                    helperText:
                        'Esempio FF6F61. Lascia vuoto per usare il tema del cliente.',
                    errorText: _accentHexError,
                    prefixText: '#',
                    suffixIcon:
                        selected != null
                            ? IconButton(
                              tooltip: 'Rimuovi colore personalizzato',
                              onPressed: () => _setAccentColor(null),
                              icon: const Icon(Icons.clear_rounded),
                            )
                            : null,
                  ).copyWith(counterText: ''),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: _handleAccentHexChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _setAccentColor(null),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: selected == null,
                  onChanged: (value) {
                    if (value == true) {
                      _setAccentColor(null);
                    }
                  },
                  visualDensity: VisualDensity.compact,
                ),
                const Text('Usa colori del cliente'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentStep(ThemeData theme) {
    final countLabel =
        _sections.length == 1 ? '1 elemento' : '${_sections.length} elementi';
    return Scrollbar(
      controller: _contentScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _contentScrollController,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTabViewport(
              maxWidth: 1160,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1140;
                  if (!isWide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildContentCoverColumn(theme),
                        const SizedBox(height: 20),
                        _buildContentSectionsColumn(theme, countLabel),
                      ],
                    );
                  }
                  const coverWidth = 392.0;
                  final sectionsWidth = math.min(
                    730.0,
                    constraints.maxWidth - coverWidth - 24,
                  );
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: coverWidth + 24 + sectionsWidth,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: coverWidth,
                            child: _buildContentCoverColumn(theme),
                          ),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: sectionsWidth,
                            child: _buildContentSectionsColumn(
                              theme,
                              countLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentCoverColumn(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Immagine di copertina',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _CoverImagePicker(
          imageUrl: _coverImageUrl,
          isUploading: _isUploadingCover,
          error: _coverUploadError,
          info: _coverUploadInfo,
          onPick: _pickPromotionImage,
          onRemove: () {
            setState(() {
              _coverImageUrl = null;
              _coverImagePath = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildContentSectionsColumn(ThemeData theme, String countLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final heading = Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  'Sezioni contenuto',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    countLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _addSection(PromotionSectionType.text),
                  icon: const Icon(Icons.short_text_rounded, size: 18),
                  label: const Text('Aggiungi testo'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _addSection(PromotionSectionType.image),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('Aggiungi immagine'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 12), actions],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: heading),
                const SizedBox(width: 12),
                actions,
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        ReorderableListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          buildDefaultDragHandles: false,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) {
                newIndex -= 1;
              }
              final item = _sections.removeAt(oldIndex);
              _sections.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            final section = _sections[index];
            final error = _sectionUploadErrors[section.id];
            return _SectionEditorCard(
              key: ValueKey(section.id),
              index: index,
              section: section,
              error: error,
              onRemove: () => _removeSection(section),
              onDuplicate: () => _duplicateSection(section),
              onUploadImage:
                  section.type == PromotionSectionType.image
                      ? () => _pickSectionImage(section)
                      : null,
              onChanged: () => setState(() {}),
              expansionState: _expansionState,
            );
          },
          itemCount: _sections.length,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _showAddSectionPicker,
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Aggiungi nuova sezione'),
        ),
      ],
    );
  }

  Widget _buildPreviewStep(ThemeData baseTheme) {
    final promotion = _buildPromotionForPreview();
    final themed = ClientTheme.resolve(baseTheme);
    return Theme(
      data: themed,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            controller: _previewTabScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _previewTabScrollController,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
              child: _buildTabViewport(
                maxWidth: 1096,
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final isWide = innerConstraints.maxWidth >= 960;
                    final previewRail = Scrollbar(
                      controller: _previewRailScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _previewRailScrollController,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PreviewRailItem(
                              label: 'Home / card',
                              child: _PromotionListPreviewFrame(
                                promotion: promotion,
                              ),
                            ),
                            const SizedBox(width: 18),
                            _PreviewRailItem(
                              label: 'Dettaglio promo',
                              child: _PromotionDetailPreviewFrame(
                                promotion: promotion,
                                scrollController: _previewPageScrollController,
                                width: 316,
                                viewportHeight: 640,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    final previewCaption = Text(
                      'Le card mostrano come apparira la promozione nell\'app cliente.',
                      style: baseTheme.textTheme.bodySmall?.copyWith(
                        color: baseTheme.colorScheme.onSurfaceVariant,
                      ),
                    );
                    final previewColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anteprima',
                          style: baseTheme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Scorri orizzontalmente per vedere come la promozione appare nell\'esperienza mobile del cliente.',
                          style: baseTheme.textTheme.bodyMedium?.copyWith(
                            color: baseTheme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width:
                              isWide
                                  ? double.infinity
                                  : math.min(innerConstraints.maxWidth, 640.0),
                          child: previewRail,
                        ),
                        const SizedBox(height: 12),
                        previewCaption,
                      ],
                    );
                    if (!isWide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAppearanceSection(baseTheme),
                          const SizedBox(height: 18),
                          previewColumn,
                        ],
                      );
                    }
                    const appearanceWidth = 312.0;
                    final previewWidth = math.min(
                      752.0,
                      innerConstraints.maxWidth - appearanceWidth - 18,
                    );
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: appearanceWidth + 18 + previewWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: appearanceWidth,
                              child: _buildAppearanceSection(baseTheme),
                            ),
                            const SizedBox(width: 18),
                            SizedBox(width: previewWidth, child: previewColumn),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddSectionPicker() async {
    final selected = await showAppModalSheet<PromotionSectionType>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.short_text_rounded),
                  title: const Text('Sezione di testo'),
                  subtitle: const Text('Per paragrafi e descrizioni'),
                  onTap: () => Navigator.of(ctx).pop(PromotionSectionType.text),
                ),
                ListTile(
                  leading: const Icon(Icons.image_rounded),
                  title: const Text('Sezione immagine'),
                  subtitle: const Text('Per foto con didascalia'),
                  onTap:
                      () => Navigator.of(ctx).pop(PromotionSectionType.image),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
    if (!mounted || selected == null) {
      return;
    }
    _addSection(selected);
  }

  void _addSection(PromotionSectionType type) {
    setState(() {
      late final _EditablePromotionSection newSection;
      switch (type) {
        case PromotionSectionType.text:
          newSection = _EditablePromotionSection.text(
            id: const Uuid().v4(),
            initialText: '',
          );
          break;
        case PromotionSectionType.image:
          newSection = _EditablePromotionSection.image(id: const Uuid().v4());
          break;
      }
      _sections.add(newSection);
      _expansionState.expand(newSection.id);
    });
  }

  void _removeSection(_EditablePromotionSection section) {
    setState(() {
      _sections.remove(section);
      _sectionUploadErrors.remove(section.id);
      _expansionState.collapse(section.id);
      section.dispose();
    });
  }

  void _duplicateSection(_EditablePromotionSection section) {
    setState(() {
      final copy = section.duplicate();
      _sections.insert(_sections.indexOf(section) + 1, copy);
      _expansionState.expand(copy.id);
    });
  }

  Future<void> _pickPromotionImage() async {
    final file = await pickSingleImageFile(confirmButtonText: 'Seleziona');
    if (!mounted || file == null) {
      return;
    }
    final fileSize = await _resolveXFileLength(file);
    if (fileSize > _maxImageBytes) {
      final maxMb = (_maxImageBytes / (1024 * 1024)).toStringAsFixed(1);
      setState(() {
        _coverUploadError = 'L\'immagine supera il limite di $maxMb MB.';
        _coverUploadInfo = null;
      });
      return;
    }
    final bytes = await _resolveXFileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _coverUploadError = 'Impossibile leggere il file selezionato.';
        _coverUploadInfo = null;
      });
      return;
    }
    setState(() {
      _isUploadingCover = true;
      _coverUploadError = null;
      _coverUploadInfo = null;
    });
    final storage = ref.read(firebaseStorageServiceProvider);
    final session = ref.read(sessionControllerProvider);
    final uploaderId = session.uid ?? 'unknown';
    final previousPath = _coverImagePath;
    try {
      final upload = await storage.uploadPromotionImage(
        salonId: widget.salonId,
        promotionId: _promotionId,
        data: bytes,
        fileName: file.name,
        uploaderId: uploaderId,
      );
      if (!mounted) return;
      setState(() {
        _coverImageUrl = upload.downloadUrl;
        _coverImagePath = upload.storagePath;
        _coverUploadInfo = 'Immagine caricata correttamente.';
      });
      if (previousPath != null && previousPath.isNotEmpty) {
        unawaited(
          ref.read(firebaseStorageServiceProvider).deleteFile(previousPath),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _coverUploadError = 'Impossibile caricare l\'immagine: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingCover = false);
      }
    }
  }

  Future<void> _pickSectionImage(_EditablePromotionSection section) async {
    final file = await pickSingleImageFile(confirmButtonText: 'Seleziona');
    if (!mounted || file == null) {
      return;
    }
    final fileSize = await _resolveXFileLength(file);
    if (fileSize > _maxImageBytes) {
      final maxMb = (_maxImageBytes / (1024 * 1024)).toStringAsFixed(1);
      setState(() {
        _sectionUploadErrors[section.id] =
            'L\'immagine supera il limite di $maxMb MB.';
      });
      return;
    }
    final bytes = await _resolveXFileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _sectionUploadErrors[section.id] =
            'Impossibile leggere il file selezionato.';
      });
      return;
    }
    setState(() {
      _sectionUploadErrors[section.id] = null;
      section.isUploading = true;
    });
    final storage = ref.read(firebaseStorageServiceProvider);
    final session = ref.read(sessionControllerProvider);
    final uploaderId = session.uid ?? 'unknown';
    final previousPath = section.imagePath;
    try {
      final upload = await storage.uploadPromotionSectionImage(
        salonId: widget.salonId,
        promotionId: _promotionId,
        sectionId: section.id,
        data: bytes,
        fileName: file.name,
        uploaderId: uploaderId,
      );
      if (!mounted) return;
      setState(() {
        section.imageUrl = upload.downloadUrl;
        section.imagePath = upload.storagePath;
      });
      if (previousPath != null && previousPath.isNotEmpty) {
        unawaited(
          ref.read(firebaseStorageServiceProvider).deleteFile(previousPath),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sectionUploadErrors[section.id] =
            'Impossibile caricare l\'immagine: $error';
      });
    } finally {
      if (mounted) {
        setState(() => section.isUploading = false);
      }
    }
  }

  Future<int> _resolveXFileLength(XFile file) async {
    try {
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  Future<Uint8List?> _resolveXFileBytes(XFile file) async {
    try {
      final data = await file.readAsBytes();
      if (data.length > _maxImageBytes) {
        return null;
      }
      return data.isEmpty ? null : data;
    } catch (_) {
      return null;
    }
  }

  Promotion _buildPromotionForPreview() {
    final sections = <PromotionSection>[];
    for (var index = 0; index < _sections.length; index += 1) {
      final section = _sections[index];
      if (section.isEffectivelyEmpty) {
        continue;
      }
      sections.add(section.toSection(index));
    }
    final discount =
        double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0.0;
    final priority = int.tryParse(_priorityController.text) ?? 0;
    return Promotion(
      id: _promotionId,
      salonId: widget.salonId,
      title: _titleController.text.trim(),
      subtitle:
          _subtitleController.text.trim().isEmpty
              ? null
              : _subtitleController.text.trim(),
      tagline:
          _taglineController.text.trim().isEmpty
              ? null
              : _taglineController.text.trim(),
      coverImageUrl: _coverImageUrl,
      coverImagePath: _coverImagePath,
      themeColor: _accentColor?.toARGB32(),
      cta: _buildPromotionCta(allowInvalid: true),
      sections: sections,
      startsAt: _startsAt,
      endsAt: _endsAt,
      discountPercentage: discount,
      priority: priority,
      status: _status,
      isActive: _status == PromotionStatus.published,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final sections = <PromotionSection>[];
    for (var index = 0; index < _sections.length; index += 1) {
      final section = _sections[index];
      if (section.isEffectivelyEmpty) {
        continue;
      }
      sections.add(section.toSection(index));
    }
    if (sections.isEmpty) {
      final snackBar = const SnackBar(
        content: Text('Aggiungi almeno una sezione alla promozione.'),
      );
      ScaffoldMessenger.of(context).showAppSnackBar(snackBar);
      return;
    }
    PromotionCta? promotionCta;
    try {
      promotionCta = _buildPromotionCta();
    } on FormatException catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (_ctaType != PromotionCtaType.none && promotionCta == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text(
            'Configura una call to action valida prima di salvare.',
          ),
        ),
      );
      return;
    }
    final discount =
        double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0.0;
    final priority = int.tryParse(_priorityController.text) ?? 0;
    final promotion = (widget.initialPromotion ??
            Promotion(
              id: _promotionId,
              salonId: widget.salonId,
              title: _titleController.text.trim(),
              sections: sections,
              discountPercentage: discount,
              priority: priority,
              status: _status,
              isActive: _status == PromotionStatus.published,
              themeColor: _accentColor?.toARGB32(),
            ))
        .copyWith(
          id: _promotionId,
          salonId: widget.salonId,
          title: _titleController.text.trim(),
          subtitle:
              _subtitleController.text.trim().isEmpty
                  ? null
                  : _subtitleController.text.trim(),
          tagline:
              _taglineController.text.trim().isEmpty
                  ? null
                  : _taglineController.text.trim(),
          coverImageUrl: _coverImageUrl,
          coverImagePath: _coverImagePath,
          cta: promotionCta,
          sections: sections,
          discountPercentage: discount,
          priority: priority,
          startsAt: _startsAt,
          endsAt: _endsAt,
          status: _status,
          isActive: _status == PromotionStatus.published,
          themeColor: _accentColor?.toARGB32(),
        );
    if (!mounted) return;
    Navigator.of(context).pop(promotion);
  }

  String? _previewCtaUrl() {
    try {
      final cta = _buildPromotionCta(allowInvalid: true);
      return cta?.url;
    } catch (_) {
      return null;
    }
  }

  PromotionCta? _buildPromotionCta({bool allowInvalid = false}) {
    if (_ctaType == PromotionCtaType.none) {
      return null;
    }
    switch (_ctaType) {
      case PromotionCtaType.none:
        return null;
      case PromotionCtaType.link:
        final normalized = _normalizeUrl(_ctaCustomUrlController.text);
        if (normalized == null) {
          if (allowInvalid) return null;
          throw const FormatException('Inserisci un URL valido.');
        }
        return PromotionCta(
          type: PromotionCtaType.link,
          label:
              _ctaLabelController.text.trim().isEmpty
                  ? _defaultCtaLabel(PromotionCtaType.link)
                  : _ctaLabelController.text.trim(),
          url: normalized,
          enabled: _ctaEnabled,
        );
      case PromotionCtaType.booking:
        final salon = widget.salon;
        final normalized = _normalizeUrl(
          _ctaCustomUrlController.text.isEmpty && salon?.bookingLink != null
              ? salon!.bookingLink!
              : _ctaCustomUrlController.text,
        );
        if (normalized == null) {
          if (allowInvalid) return null;
          throw const FormatException('Inserisci un URL valido.');
        }
        return PromotionCta(
          type: PromotionCtaType.booking,
          label:
              _ctaLabelController.text.trim().isEmpty
                  ? _defaultCtaLabel(PromotionCtaType.booking)
                  : _ctaLabelController.text.trim(),
          url: normalized,
          bookingUrl: normalized,
          enabled: _ctaEnabled,
        );
      case PromotionCtaType.phone:
        final sanitized = _sanitizePhoneForTel(_ctaPhoneController.text.trim());
        if (sanitized == null) {
          if (allowInvalid) return null;
          throw const FormatException('Numero di telefono non valido.');
        }
        final displayNumber =
            sanitized.startsWith('+') ? sanitized : '+$sanitized';
        return PromotionCta(
          type: PromotionCtaType.phone,
          label:
              _ctaLabelController.text.trim().isEmpty
                  ? _defaultCtaLabel(PromotionCtaType.phone)
                  : _ctaLabelController.text.trim(),
          url: 'tel:$sanitized',
          phoneNumber: displayNumber,
          enabled: _ctaEnabled,
        );
      case PromotionCtaType.whatsapp:
        final sanitized = _sanitizePhoneForWhatsapp(
          _ctaPhoneController.text.trim(),
        );
        if (sanitized == null) {
          if (allowInvalid) return null;
          throw const FormatException('Numero WhatsApp non valido.');
        }
        final message = _ctaWhatsappMessageController.text.trim();
        final encodedMessage =
            message.isEmpty ? null : Uri.encodeComponent(message);
        final url =
            encodedMessage == null
                ? 'https://wa.me/$sanitized'
                : 'https://wa.me/$sanitized?text=$encodedMessage';
        return PromotionCta(
          type: PromotionCtaType.whatsapp,
          label:
              _ctaLabelController.text.trim().isEmpty
                  ? _defaultCtaLabel(PromotionCtaType.whatsapp)
                  : _ctaLabelController.text.trim(),
          url: url,
          phoneNumber: sanitized,
          messageTemplate: message.isEmpty ? null : message,
          enabled: _ctaEnabled,
        );
      case PromotionCtaType.custom:
        return PromotionCta(
          type: PromotionCtaType.custom,
          label:
              _ctaLabelController.text.trim().isEmpty
                  ? 'Azione personalizzata'
                  : _ctaLabelController.text.trim(),
          enabled: _ctaEnabled,
        );
    }
  }

  List<DropdownMenuItem<PromotionCtaType>> _buildCtaTypeItems() {
    final items = <DropdownMenuItem<PromotionCtaType>>[
      const DropdownMenuItem(
        value: PromotionCtaType.none,
        child: Text('Nessuna azione'),
      ),
      const DropdownMenuItem(
        value: PromotionCtaType.link,
        child: Text('Link personalizzato'),
      ),
      const DropdownMenuItem(
        value: PromotionCtaType.whatsapp,
        child: Text('Apri WhatsApp'),
      ),
      const DropdownMenuItem(
        value: PromotionCtaType.phone,
        child: Text('Chiama il salone'),
      ),
    ];
    if (widget.salon?.bookingLink?.trim().isNotEmpty == true) {
      items.add(
        const DropdownMenuItem(
          value: PromotionCtaType.booking,
          child: Text('Apri link prenotazione'),
        ),
      );
    }
    items.add(
      const DropdownMenuItem(
        value: PromotionCtaType.custom,
        child: Text('Gestita dall\'app'),
      ),
    );
    return items;
  }

  PromotionCtaType _inferInitialCtaType({
    PromotionCta? cta,
    String? ctaUrl,
    Salon? salon,
  }) {
    if (cta != null) {
      return cta.type;
    }
    final raw = ctaUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return PromotionCtaType.none;
    }
    final lower = raw.toLowerCase();
    if (raw.startsWith('tel:')) {
      return PromotionCtaType.phone;
    }
    if (lower.contains('wa.me') || lower.contains('whatsapp')) {
      return PromotionCtaType.whatsapp;
    }
    if (salon?.bookingLink != null && raw == salon!.bookingLink) {
      return PromotionCtaType.booking;
    }
    return PromotionCtaType.link;
  }

  String _defaultCtaLabel(PromotionCtaType type) {
    switch (type) {
      case PromotionCtaType.none:
        return 'Contatta';
      case PromotionCtaType.link:
        return 'Scopri di più';
      case PromotionCtaType.whatsapp:
        return 'Scrivi su WhatsApp';
      case PromotionCtaType.phone:
        return 'Chiama ora';
      case PromotionCtaType.booking:
        return 'Prenota subito';
      case PromotionCtaType.custom:
        return 'Apri';
    }
  }

  String _defaultWhatsappMessage(String? promotionTitle) {
    final title = promotionTitle?.trim();
    if (title == null || title.isEmpty) {
      return 'Ciao! Vorrei avere maggiori informazioni sulla promozione attiva.';
    }
    return 'Ciao! Mi interessa la promozione "$title". Potete darmi maggiori dettagli?';
  }

  String _displayPhoneForEditing(
    String? ctaPhone,
    String fallbackPhone,
    PromotionCtaType type,
  ) {
    final candidate = ctaPhone?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      if (type == PromotionCtaType.whatsapp && !candidate.startsWith('+')) {
        return '+$candidate';
      }
      return candidate;
    }
    return fallbackPhone;
  }

  String? _validateCustomUrl(String? value) {
    if (_ctaType != PromotionCtaType.link &&
        _ctaType != PromotionCtaType.booking) {
      return null;
    }
    final normalized = _normalizeUrl(value);
    if (normalized == null) {
      return 'Inserisci un URL valido (es. https://promo.example)';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    if (_ctaType != PromotionCtaType.whatsapp &&
        _ctaType != PromotionCtaType.phone) {
      return null;
    }
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Inserisci un numero di telefono';
    }
    final sanitized =
        _ctaType == PromotionCtaType.whatsapp
            ? _sanitizePhoneForWhatsapp(trimmed)
            : _sanitizePhoneForTel(trimmed);
    if (sanitized == null) {
      return 'Numero non valido. Usa anche il prefisso internazionale.';
    }
    return null;
  }

  String? _normalizeUrl(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final hasScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    final candidate = hasScheme ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasAuthority) {
      return null;
    }
    return candidate;
  }

  String? _sanitizePhoneForTel(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.startsWith('+')) {
      final normalized =
          '+${digits.substring(1).replaceAll(RegExp(r'[^0-9]'), '')}';
      return normalized.length > 1 ? normalized : null;
    }
    final numbersOnly = digits.replaceAll(RegExp(r'[^0-9]'), '');
    return numbersOnly.isEmpty ? null : numbersOnly;
  }

  String? _sanitizePhoneForWhatsapp(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('00') && digits.length > 2) {
      digits = digits.substring(2);
    }
    if (trimmed.startsWith('+')) {
      digits = trimmed.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
    }
    return digits;
  }
}

class _PromotionExpandablePanel extends StatelessWidget {
  const _PromotionExpandablePanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.collapsedAccentText,
  });

  final String title;
  final String subtitle;
  final String? collapsedAccentText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color:
              theme.brightness == Brightness.dark
                  ? scheme.surface.withValues(alpha: 0.98)
                  : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle:
              collapsedAccentText == null
                  ? Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                  : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      collapsedAccentText!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          children: [child],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.groupValue,
    required this.onChanged,
  });

  final PromotionStatus status;
  final PromotionStatus groupValue;
  final ValueChanged<PromotionStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelected = status == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onChanged(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? scheme.primary : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(_iconForStatus(status), size: 18, color: scheme.onPrimary),
              const SizedBox(width: 8),
            ],
            Text(
              _labelForStatus(status),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelForStatus(PromotionStatus status) {
    switch (status) {
      case PromotionStatus.draft:
        return 'Bozza';
      case PromotionStatus.scheduled:
        return 'Programmato';
      case PromotionStatus.published:
        return 'Pubblicato';
      case PromotionStatus.expired:
        return 'Scaduto';
    }
  }

  IconData _iconForStatus(PromotionStatus status) {
    switch (status) {
      case PromotionStatus.draft:
        return Icons.check_rounded;
      case PromotionStatus.scheduled:
        return Icons.schedule_rounded;
      case PromotionStatus.published:
        return Icons.check_circle_rounded;
      case PromotionStatus.expired:
        return Icons.history_toggle_off_rounded;
    }
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final display =
        value == null
            ? DateFormat('dd/MM/yyyy').format(DateTime.now())
            : DateFormat('dd/MM/yyyy HH:mm', 'it_IT').format(value!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final now = DateTime.now();
            final initialDate = value ?? now;
            final date = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 2),
            );
            if (date == null) {
              return;
            }
            if (!context.mounted) {
              return;
            }
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initialDate),
            );
            if (!context.mounted) {
              return;
            }
            if (time == null) {
              onChanged(DateTime(date.year, date.month, date.day));
              return;
            }
            onChanged(
              DateTime(date.year, date.month, date.day, time.hour, time.minute),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(display, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value == null ? 'Non impostata' : 'Impostata',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CoverImagePicker extends StatelessWidget {
  const _CoverImagePicker({
    required this.imageUrl,
    required this.isUploading,
    required this.onPick,
    required this.onRemove,
    this.error,
    this.info,
  });

  final String? imageUrl;
  final bool isUploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final String? error;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        color: Colors.white.withValues(alpha: 0.42),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              color: scheme.surfaceContainerHighest,
                            ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Rimuovi'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    size: 34,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nessuna immagine caricata',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: isUploading ? null : onPick,
                    icon:
                        isUploading
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.upload_rounded),
                    label: Text(
                      isUploading ? 'Caricamento...' : 'Carica immagine',
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (imageUrl != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isUploading ? null : onPick,
              icon:
                  isUploading
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.upload_rounded),
              label: Text(
                isUploading ? 'Caricamento...' : 'Sostituisci immagine',
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
          if (info != null) ...[
            const SizedBox(height: 8),
            Text(
              info!,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditablePromotionSection {
  _EditablePromotionSection.text({
    required this.id,
    String initialTitle = '',
    String initialText = '',
    this.layout = PromotionSectionLayout.full,
    this.visible = true,
  }) : type = PromotionSectionType.text,
       titleController = TextEditingController(text: initialTitle),
       textController = TextEditingController(text: initialText),
       altTextController = null,
       captionController = null,
       imageUrl = null,
       imagePath = null;

  _EditablePromotionSection.image({
    required this.id,
    String initialTitle = '',
    this.imageUrl,
    this.imagePath,
    String altText = '',
    String caption = '',
    this.layout = PromotionSectionLayout.full,
    this.visible = true,
  }) : type = PromotionSectionType.image,
       titleController = TextEditingController(text: initialTitle),
       textController = null,
       altTextController = TextEditingController(text: altText),
       captionController = TextEditingController(text: caption);

  final String id;
  final PromotionSectionType type;
  final TextEditingController titleController;
  final TextEditingController? textController;
  final TextEditingController? altTextController;
  final TextEditingController? captionController;
  PromotionSectionLayout layout;
  bool visible;
  String? imageUrl;
  String? imagePath;
  bool isUploading = false;

  bool get isEffectivelyEmpty {
    final titleEmpty = titleController.text.trim().isEmpty;
    switch (type) {
      case PromotionSectionType.text:
        final textEmpty = textController?.text.trim().isEmpty ?? true;
        return titleEmpty && textEmpty;
      case PromotionSectionType.image:
        return imageUrl == null || imageUrl!.isEmpty;
    }
  }

  _EditablePromotionSection duplicate() {
    switch (type) {
      case PromotionSectionType.text:
        return _EditablePromotionSection.text(
          id: const Uuid().v4(),
          initialTitle: titleController.text,
          initialText: textController?.text ?? '',
          layout: layout,
          visible: visible,
        );
      case PromotionSectionType.image:
        return _EditablePromotionSection.image(
          id: const Uuid().v4(),
          initialTitle: titleController.text,
          imageUrl: imageUrl,
          imagePath: imagePath,
          altText: altTextController?.text ?? '',
          caption: captionController?.text ?? '',
          layout: layout,
          visible: visible,
        );
    }
  }

  PromotionSection toSection(int order) {
    final trimmedTitle = titleController.text.trim();
    final title = trimmedTitle.isEmpty ? null : trimmedTitle;
    switch (type) {
      case PromotionSectionType.text:
        return PromotionSection(
          id: id,
          type: type,
          order: order,
          title: title,
          text: textController?.text.trim(),
          layout: layout,
          visible: visible,
        );
      case PromotionSectionType.image:
        return PromotionSection(
          id: id,
          type: type,
          order: order,
          title: title,
          imageUrl: imageUrl,
          imagePath: imagePath,
          altText:
              altTextController?.text.trim().isEmpty == true
                  ? null
                  : altTextController!.text.trim(),
          caption:
              captionController?.text.trim().isEmpty == true
                  ? null
                  : captionController!.text.trim(),
          layout: layout,
          visible: visible,
        );
    }
  }

  void dispose() {
    titleController.dispose();
    textController?.dispose();
    altTextController?.dispose();
    captionController?.dispose();
  }
}

String _layoutDisplayLabel(
  PromotionSectionLayout layout,
  PromotionSectionType type,
) {
  switch (layout) {
    case PromotionSectionLayout.full:
      return type == PromotionSectionType.text
          ? 'Layout semplice'
          : 'Layout standard';
    case PromotionSectionLayout.split:
      return 'Layout card';
    case PromotionSectionLayout.quote:
      return 'Layout citazione';
  }
}

class _SectionExpansionState {
  final Set<String> _expanded = <String>{};

  bool isExpanded(String id) => _expanded.contains(id);

  void toggle(String id) {
    if (!_expanded.remove(id)) {
      _expanded.add(id);
    }
  }

  void expand(String id) => _expanded.add(id);

  void collapse(String id) => _expanded.remove(id);
}

class _SectionEditorCard extends StatefulWidget {
  const _SectionEditorCard({
    super.key,
    required this.index,
    required this.section,
    required this.onRemove,
    required this.onDuplicate,
    this.onUploadImage,
    this.error,
    required this.onChanged,
    required this.expansionState,
  });

  final int index;
  final _EditablePromotionSection section;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback? onUploadImage;
  final String? error;
  final VoidCallback onChanged;
  final _SectionExpansionState expansionState;

  @override
  State<_SectionEditorCard> createState() => _SectionEditorCardState();
}

class _SectionEditorCardState extends State<_SectionEditorCard>
    with AutomaticKeepAliveClientMixin {
  bool get _isExpanded => widget.expansionState.isExpanded(widget.section.id);

  void _toggleExpanded() {
    setState(() {
      widget.expansionState.toggle(widget.section.id);
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titlePreview = widget.section.titleController.text.trim();
    final subtitleText =
        titlePreview.isNotEmpty
            ? titlePreview
            : widget.section.type == PromotionSectionType.text
            ? (widget.section.textController?.text.trim() ?? '')
            : (widget.section.imageUrl == null
                ? 'Nessuna immagine caricata'
                : 'Immagine caricata');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.section.type == PromotionSectionType.text
                              ? 'Sezione testo'
                              : 'Sezione immagine',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText.isEmpty
                              ? 'Tocca per aggiungere contenuto'
                              : subtitleText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Duplica',
                    onPressed: widget.onDuplicate,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Rimuovi',
                    onPressed: widget.onRemove,
                    color: scheme.error,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
                  IconButton(
                    tooltip: _isExpanded ? 'Comprimi' : 'Espandi',
                    onPressed: _toggleExpanded,
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
                _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<
                              PromotionSectionLayout
                            >(
                              isExpanded: true,
                              initialValue: widget.section.layout,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.9),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: scheme.outlineVariant,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: scheme.primary),
                                ),
                              ),
                              items:
                                  PromotionSectionLayout.values
                                      .map(
                                        (layout) => DropdownMenuItem(
                                          value: layout,
                                          child: Text(
                                            _layoutDisplayLabel(
                                              layout,
                                              widget.section.type,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  widget.section.layout = value;
                                });
                                widget.onChanged();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              setState(() {
                                widget.section.visible =
                                    !widget.section.visible;
                              });
                              widget.onChanged();
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.section.visible
                                      ? Icons.check_rounded
                                      : Icons.remove_rounded,
                                  size: 16,
                                  color:
                                      widget.section.visible
                                          ? const Color(0xFF16A34A)
                                          : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.section.visible
                                      ? 'Visibile'
                                      : 'Nascosta',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: widget.section.titleController,
                        decoration: InputDecoration(
                          hintText: 'Titolo sezione (opzionale)',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.9),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: scheme.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: scheme.primary),
                          ),
                        ),
                        onChanged: (_) => widget.onChanged(),
                      ),
                      const SizedBox(height: 12),
                      if (widget.section.type == PromotionSectionType.text)
                        TextFormField(
                          controller: widget.section.textController,
                          maxLines: 6,
                          minLines: 3,
                          decoration: InputDecoration(
                            hintText:
                                'Racconta i dettagli della promozione con paragrafi brevi.',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.9),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: scheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: scheme.primary),
                            ),
                          ),
                          onChanged: (_) => widget.onChanged(),
                        )
                      else
                        _ImageSectionEditor(
                          section: widget.section,
                          onChanged: widget.onChanged,
                          onPickImage: widget.onUploadImage,
                          onRemoveImage: () {
                            setState(() {
                              widget.section.imageUrl = null;
                              widget.section.imagePath = null;
                            });
                            widget.onChanged();
                          },
                          error: widget.error,
                          scheme: scheme,
                          theme: theme,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSectionEditor extends StatelessWidget {
  const _ImageSectionEditor({
    required this.section,
    required this.onChanged,
    this.onPickImage,
    required this.onRemoveImage,
    this.error,
    required this.scheme,
    required this.theme,
  });

  final _EditablePromotionSection section;
  final VoidCallback onChanged;
  final VoidCallback? onPickImage;
  final VoidCallback onRemoveImage;
  final String? error;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                section.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) =>
                        Container(color: scheme.surfaceContainerHighest),
              ),
            ),
          )
        else
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 34,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                Text(
                  'Nessuna immagine caricata',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: section.isUploading ? null : onPickImage,
              icon:
                  section.isUploading
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.upload_rounded),
              label: Text(
                section.isUploading
                    ? 'Caricamento...'
                    : (section.imageUrl == null
                        ? 'Carica immagine'
                        : 'Sostituisci immagine'),
              ),
            ),
            if (section.imageUrl != null)
              OutlinedButton.icon(
                onPressed: onRemoveImage,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Rimuovi'),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: section.altTextController,
          decoration: InputDecoration(
            hintText: "Descrivi l'immagine per accessibilita",
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.9),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.primary),
            ),
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: section.captionController,
          decoration: InputDecoration(
            hintText: 'Didascalia (opzionale)',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.9),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: scheme.primary),
            ),
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

class _PreviewRailItem extends StatelessWidget {
  const _PreviewRailItem({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _PromotionMobileFrame extends StatelessWidget {
  const _PromotionMobileFrame({
    required this.child,
    required this.width,
    required this.viewportHeight,
  });

  final Widget child;
  final double width;
  final double viewportHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              Container(
                height: 24,
                color: theme.colorScheme.surface,
                alignment: Alignment.center,
                child: Container(
                  width: 72,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(height: viewportHeight, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromotionPreview extends StatelessWidget {
  const _PromotionPreview({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = resolvePromotionPalette(promotion, scheme);
    final endsAt = promotion.endsAt;
    final dateLabel =
        endsAt == null
            ? 'Senza scadenza'
            : DateFormat('dd MMM', 'it_IT').format(endsAt);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (promotion.coverImageUrl != null)
            Positioned.fill(
              child: Image.network(promotion.coverImageUrl!, fit: BoxFit.cover),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      palette.fallbackGradientStart,
                      palette.fallbackGradientEnd,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.overlayGradientStart,
                    palette.overlayGradientEnd,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      dateLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color:
                            palette.hasCustomAccent
                                ? palette.onAccent
                                : scheme.onPrimary,
                      ),
                    ),
                    backgroundColor:
                        palette.hasCustomAccent
                            ? palette.accent.withValues(alpha: 0.85)
                            : scheme.primary.withValues(alpha: 0.75),
                  ),
                  const Spacer(),
                  Text(
                    promotion.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (promotion.subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      promotion.subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionListPreviewFrame extends StatelessWidget {
  const _PromotionListPreviewFrame({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    return _PromotionMobileFrame(
      width: 296,
      viewportHeight: 640,
      child: _PromotionListPreviewBody(promotion: promotion),
    );
  }
}

class _PromotionListPreviewBody extends StatelessWidget {
  const _PromotionListPreviewBody({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anteprima',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Promozioni',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(height: 220, child: _PromotionPreview(promotion: promotion)),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'La promozione appare nel feed cliente con badge, immagine e contenuti principali.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionDetailPreviewFrame extends StatelessWidget {
  const _PromotionDetailPreviewFrame({
    required this.promotion,
    required this.scrollController,
    this.width = 340,
    this.viewportHeight = 620,
  });

  final Promotion promotion;
  final ScrollController scrollController;
  final double width;
  final double viewportHeight;

  @override
  Widget build(BuildContext context) {
    return _PromotionMobileFrame(
      width: width,
      viewportHeight: viewportHeight,
      child: _PromotionDetailPreviewBody(
        promotion: promotion,
        scrollController: scrollController,
      ),
    );
  }
}

class _PromotionDetailPreviewBody extends StatelessWidget {
  const _PromotionDetailPreviewBody({
    required this.promotion,
    required this.scrollController,
  });

  final Promotion promotion;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = resolvePromotionPalette(promotion, scheme);
    final visibleSections =
        promotion.sections.where((section) => section.visible).toList();
    final subtitle = promotion.subtitle?.trim();
    final tagline = promotion.tagline?.trim();
    final title =
        promotion.title.trim().isEmpty ? 'Titolo promozione' : promotion.title;
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PromotionDetailPreviewHero(
                    promotion: promotion,
                    palette: palette,
                    title: title,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          Text(
                            subtitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (tagline != null && tagline.isNotEmpty) ...[
                          Text(
                            tagline,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (promotion.startsAt != null ||
                            promotion.endsAt != null) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (promotion.startsAt != null)
                                _PromotionPreviewInfoChip(
                                  icon: Icons.play_arrow_rounded,
                                  label:
                                      'Dal ${DateFormat('dd MMM', 'it_IT').format(promotion.startsAt!)}',
                                  backgroundColor: palette.accentContainer,
                                  foregroundColor: palette.onAccentContainer,
                                  borderColor: palette.accent.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              if (promotion.endsAt != null)
                                _PromotionPreviewInfoChip(
                                  icon: Icons.event_available_rounded,
                                  label:
                                      'Fino al ${DateFormat('dd MMM', 'it_IT').format(promotion.endsAt!)}',
                                  backgroundColor: palette.accentContainer,
                                  foregroundColor: palette.onAccentContainer,
                                  borderColor: palette.accent.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (promotion.discountPercentage > 0) ...[
                          _PromotionPreviewInfoChip(
                            icon: Icons.percent_rounded,
                            label:
                                '-${promotion.discountPercentage.toStringAsFixed(0)}%',
                            backgroundColor: palette.highlightContainer,
                            foregroundColor: palette.onHighlightContainer,
                            borderColor: Colors.transparent,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (visibleSections.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'Le sezioni che compili nel tab Contenuto compariranno qui.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          )
                        else
                          ...visibleSections.map(
                            (section) => Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: _PromotionPreviewSectionContent(
                                section: section,
                                palette: palette,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (promotion.cta != null && promotion.cta!.enabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: palette.accent,
                foregroundColor: palette.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                (promotion.cta!.label ?? 'Contatta il salone').trim().isEmpty
                    ? 'Contatta il salone'
                    : promotion.cta!.label!.trim(),
              ),
            ),
          ),
      ],
    );
  }
}

class _PromotionDetailPreviewHero extends StatelessWidget {
  const _PromotionDetailPreviewHero({
    required this.promotion,
    required this.palette,
    required this.title,
  });

  final Promotion promotion;
  final PromotionPalette palette;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 228,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (promotion.coverImageUrl != null &&
              promotion.coverImageUrl!.isNotEmpty)
            Image.network(
              promotion.coverImageUrl!,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          palette.fallbackGradientStart,
                          palette.fallbackGradientEnd,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.fallbackGradientStart,
                    palette.fallbackGradientEnd,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.overlayGradientStart,
                  palette.overlayGradientEnd,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (promotion.endsAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          palette.hasCustomAccent
                              ? palette.accent.withValues(alpha: 0.88)
                              : Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      DateFormat('dd MMM', 'it_IT').format(promotion.endsAt!),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: palette.onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionPreviewInfoChip extends StatelessWidget {
  const _PromotionPreviewInfoChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromotionPreviewSectionContent extends StatelessWidget {
  const _PromotionPreviewSectionContent({
    required this.section,
    required this.palette,
  });

  final PromotionSection section;
  final PromotionPalette palette;

  @override
  Widget build(BuildContext context) {
    switch (section.type) {
      case PromotionSectionType.text:
        return _PromotionPreviewTextSection(section: section, palette: palette);
      case PromotionSectionType.image:
        return _PromotionPreviewImageSection(
          section: section,
          palette: palette,
        );
    }
  }
}

class _PromotionPreviewTextSection extends StatelessWidget {
  const _PromotionPreviewTextSection({
    required this.section,
    required this.palette,
  });

  final PromotionSection section;
  final PromotionPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTitle = section.title?.trim().isNotEmpty == true;
    final body = section.text?.trim() ?? '';
    switch (section.layout) {
      case PromotionSectionLayout.full:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasTitle) ...[
              Text(
                section.title!.trim(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        );
      case PromotionSectionLayout.split:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.accentContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasTitle) ...[
                Text(
                  section.title!.trim(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.onAccentContainer,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: palette.onAccentContainer,
                ),
              ),
            ],
          ),
        );
      case PromotionSectionLayout.quote:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.highlightContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 28,
                color: palette.highlight,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasTitle) ...[
                      Text(
                        section.title!.trim(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: palette.highlight,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        color: palette.onHighlightContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _PromotionPreviewImageSection extends StatelessWidget {
  const _PromotionPreviewImageSection({
    required this.section,
    required this.palette,
  });

  final PromotionSection section;
  final PromotionPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (section.imageUrl == null || section.imageUrl!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final hasTitle = section.title?.trim().isNotEmpty == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTitle) ...[
          Text(
            section.title!.trim(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            section.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) => Container(
                  height: 190,
                  color: scheme.surfaceContainerHighest,
                ),
          ),
        ),
        if (section.caption?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            section.caption!.trim(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _AccentColorSwatch extends StatelessWidget {
  const _AccentColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checkColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : const Color(0xFF1C1B1F);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected
                      ? scheme.onSurface
                      : scheme.outlineVariant.withValues(alpha: 0.6),
              width: selected ? 3 : 1,
            ),
            boxShadow:
                selected
                    ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                    : const <BoxShadow>[],
          ),
          child: selected ? Icon(Icons.check_rounded, color: checkColor) : null,
        ),
      ),
    );
  }
}
