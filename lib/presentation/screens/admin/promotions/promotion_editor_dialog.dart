import 'dart:async';
import 'dart:math' as math;
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/common/hybrid_image_picker.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:you_book/presentation/screens/client/client_theme.dart';
import 'package:you_book/presentation/shared/promotion_palette.dart';
import 'package:you_book/services/salons/promotion_landing_link_service.dart';

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
  final _landingScrollController = ScrollController();
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
  late final TextEditingController _landingSlugController;
  late final TextEditingController _landingEyebrowController;
  late final TextEditingController _landingFormTitleController;
  late final TextEditingController _landingFormDescriptionController;
  late final TextEditingController _landingSubmitLabelController;
  late final TextEditingController _landingInterestOptionsController;
  late final TextEditingController _landingOfferPriceController;
  late final TextEditingController _landingOriginalPriceController;
  String? _accentHexError;
  bool _landingEnabled = false;
  String _landingFontFamily = 'playfairDmSans';
  String _landingTemplateId = PromotionLandingTemplates.editorialBeauty;

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
    _tabController = TabController(length: 4, vsync: this)
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
    final landing = initial?.webLanding ?? const PromotionWebLanding();
    _landingEnabled = landing.enabled;
    _landingFontFamily = landing.fontFamily;
    _landingTemplateId = PromotionLandingTemplates.normalize(
      landing.templateId,
    );
    _landingSlugController = TextEditingController(text: landing.slug);
    _landingEyebrowController = TextEditingController(text: landing.eyebrow);
    _landingFormTitleController = TextEditingController(
      text: landing.formTitle,
    );
    _landingFormDescriptionController = TextEditingController(
      text: landing.formDescription,
    );
    _landingSubmitLabelController = TextEditingController(
      text: landing.submitLabel,
    );
    _landingInterestOptionsController = TextEditingController(
      text: landing.interestOptions.join('\n'),
    );
    _landingOfferPriceController = TextEditingController(
      text: landing.offerPrice ?? '',
    );
    _landingOriginalPriceController = TextEditingController(
      text: landing.originalPrice ?? '',
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
      if (_tabController.index == 3 &&
          _landingSlugController.text.trim().isEmpty) {
        _landingSlugController.text = PromotionLandingLinkService.slugify(
          _titleController.text,
        );
      }
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
    _landingScrollController.dispose();
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
    _landingSlugController.dispose();
    _landingEyebrowController.dispose();
    _landingFormTitleController.dispose();
    _landingFormDescriptionController.dispose();
    _landingSubmitLabelController.dispose();
    _landingInterestOptionsController.dispose();
    _landingOfferPriceController.dispose();
    _landingOriginalPriceController.dispose();
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
                      Tab(text: 'Landing web'),
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
      case 3:
        return _buildLandingStep(theme);
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

  Widget _buildLandingTemplatePreview(ThemeData theme) {
    final promotion = _buildPromotionForPreview();
    final landing = _buildWebLanding();
    final scheme = theme.colorScheme;
    return _buildCardPanel(
      theme,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final title = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Template landing',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'APPROVATO',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'La preview si aggiorna mentre modifichi testi, colori, font e offerta.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
                final selector = SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'landing-template-selector-$_landingTemplateId',
                    ),
                    initialValue: _landingTemplateId,
                    isExpanded: true,
                    decoration: _modalFieldDecoration(theme, dense: true),
                    items: [
                      for (final templateId in PromotionLandingTemplates.values)
                        DropdownMenuItem(
                          value: templateId,
                          child: Text(
                            PromotionLandingTemplates.label(templateId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _landingTemplateId = value);
                      }
                    },
                  ),
                );
                if (constraints.maxWidth < 620) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 14), selector],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 16),
                    selector,
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          SizedBox(
            height: 540,
            child: _LandingTemplatePreview(
              promotion: promotion,
              landing: landing,
              salonName: widget.salon?.name ?? 'Nome salone',
              salonPhone: widget.salon?.phone ?? '',
              salonEmail: widget.salon?.email ?? '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandingStep(ThemeData theme) {
    final scheme = theme.colorScheme;
    final landingUrl = _promotionLandingUrl();
    final iframeCode = _promotionIframeCode();
    return Scrollbar(
      controller: _landingScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _landingScrollController,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        child: _buildTabViewport(
          maxWidth: 940,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Landing page della promozione',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pubblica una pagina dedicata su youbook.civiapp.it e, se il salone ha già un sito, incorporala con l’iframe.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              _buildLandingTemplatePreview(theme),
              const SizedBox(height: 16),
              _buildCardPanel(
                theme,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pubblica landing web'),
                      subtitle: const Text(
                        'La pagina è visibile quando anche la promozione è nello stato Pubblicata.',
                      ),
                      value: _landingEnabled,
                      onChanged:
                          (value) => setState(() => _landingEnabled = value),
                    ),
                    const SizedBox(height: 8),
                    _buildFieldGroup(
                      theme,
                      label: 'INDIRIZZO DELLA PROMOZIONE',
                      helper:
                          'Usa solo lettere minuscole, numeri e trattini. Il nome del salone viene aggiunto automaticamente.',
                      child: TextFormField(
                        controller: _landingSlugController,
                        autocorrect: false,
                        decoration: _modalFieldDecoration(
                          theme,
                          hintText: 'es. beauty-reset',
                          prefixIcon: const Icon(Icons.link_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildCardPanel(
                theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Testi e modulo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldGroup(
                      theme,
                      label: 'SOPRATITOLO',
                      child: TextFormField(
                        controller: _landingEyebrowController,
                        decoration: _modalFieldDecoration(
                          theme,
                          hintText: 'Es. Il tuo primo passo',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildFieldGroup(
                      theme,
                      label: 'TITOLO DEL MODULO',
                      child: TextFormField(
                        controller: _landingFormTitleController,
                        decoration: _modalFieldDecoration(
                          theme,
                          hintText: 'Es. Prenota la tua consulenza',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildFieldGroup(
                      theme,
                      label: 'DESCRIZIONE DEL MODULO',
                      child: TextFormField(
                        controller: _landingFormDescriptionController,
                        maxLines: 3,
                        decoration: _modalFieldDecoration(
                          theme,
                          hintText: 'Spiega cosa succede dopo l’invio.',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildFieldGroup(
                      theme,
                      label: 'TESTO DEL PULSANTE',
                      child: TextFormField(
                        controller: _landingSubmitLabelController,
                        decoration: _modalFieldDecoration(
                          theme,
                          hintText: 'Es. Richiedi la promozione',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildFieldGroup(
                      theme,
                      label: 'OPZIONI DI INTERESSE',
                      helper:
                          'Una voce per riga. Se lasci vuoto, il modulo non mostra questa domanda.',
                      child: TextFormField(
                        controller: _landingInterestOptionsController,
                        minLines: 3,
                        maxLines: 7,
                        decoration: _modalFieldDecoration(
                          theme,
                          hintText: 'Viso\nCorpo\nVorrei un consiglio',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildCardPanel(
                theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aspetto e offerta',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldGroup(
                      theme,
                      label: 'FONT',
                      child: DropdownButtonFormField<String>(
                        initialValue: _landingFontFamily,
                        decoration: _modalFieldDecoration(theme),
                        items: const [
                          DropdownMenuItem(
                            value: 'playfairDmSans',
                            child: Text('Playfair Display + DM Sans'),
                          ),
                          DropdownMenuItem(
                            value: 'DM Sans',
                            child: Text('DM Sans'),
                          ),
                          DropdownMenuItem(
                            value: 'Montserrat',
                            child: Text('Montserrat'),
                          ),
                          DropdownMenuItem(value: 'Lato', child: Text('Lato')),
                          DropdownMenuItem(
                            value: 'Poppins',
                            child: Text('Poppins'),
                          ),
                          DropdownMenuItem(
                            value: 'system',
                            child: Text('Font di sistema'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _landingFontFamily = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildFieldGroup(
                            theme,
                            label: 'PREZZO OFFERTA',
                            child: TextFormField(
                              controller: _landingOfferPriceController,
                              decoration: _modalFieldDecoration(
                                theme,
                                hintText: 'Es. 79 €',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFieldGroup(
                            theme,
                            label: 'PREZZO ORIGINALE',
                            child: TextFormField(
                              controller: _landingOriginalPriceController,
                              decoration: _modalFieldDecoration(
                                theme,
                                hintText: 'Es. 120 €',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Il colore principale è quello scelto nella scheda Anteprima. Titolo, immagini e sezioni arrivano dal contenuto della promozione.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildCardPanel(
                theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link pronti da usare',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Salva la promozione prima di aprire o incollare questi collegamenti.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LandingCopyField(
                      label: 'URL LANDING PAGE',
                      value: landingUrl,
                      onCopy:
                          () => _copyLandingValue(landingUrl, 'URL copiato'),
                    ),
                    const SizedBox(height: 14),
                    _LandingCopyField(
                      label: 'CODICE IFRAME',
                      value: iframeCode,
                      multiline: true,
                      onCopy:
                          () => _copyLandingValue(
                            iframeCode,
                            'Codice iframe copiato',
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PromotionWebLanding _buildWebLanding() {
    String? optional(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final slug = PromotionLandingLinkService.slugify(
      _landingSlugController.text.trim().isEmpty
          ? _titleController.text
          : _landingSlugController.text,
    );
    final options = _landingInterestOptionsController.text
        .split(RegExp(r'[\r\n]+'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(12)
        .toList(growable: false);
    return PromotionWebLanding(
      enabled: _landingEnabled,
      slug: slug,
      eyebrow:
          _landingEyebrowController.text.trim().isEmpty
              ? 'Offerta esclusiva'
              : _landingEyebrowController.text.trim(),
      formTitle:
          _landingFormTitleController.text.trim().isEmpty
              ? 'Richiedi informazioni'
              : _landingFormTitleController.text.trim(),
      formDescription:
          _landingFormDescriptionController.text.trim().isEmpty
              ? 'Compila il modulo: il salone ti ricontatterà per fornirti tutti i dettagli.'
              : _landingFormDescriptionController.text.trim(),
      submitLabel:
          _landingSubmitLabelController.text.trim().isEmpty
              ? 'Richiedi informazioni'
              : _landingSubmitLabelController.text.trim(),
      interestOptions: options,
      offerPrice: optional(_landingOfferPriceController.text),
      originalPrice: optional(_landingOriginalPriceController.text),
      fontFamily: _landingFontFamily,
      templateId: _landingTemplateId,
    );
  }

  String _promotionLandingUrl() {
    return PromotionLandingLinkService.landingUrl(
      origin: PromotionLandingLinkService.productionOrigin,
      salonSlug: PromotionLandingLinkService.salonSlug(
        salonName: widget.salon?.name ?? 'Salone',
        salonId: widget.salonId,
      ),
      promotionSlug: _buildWebLanding().slug,
    );
  }

  String _promotionIframeCode() {
    return PromotionLandingLinkService.iframeCode(
      origin: PromotionLandingLinkService.productionOrigin,
      salonSlug: PromotionLandingLinkService.salonSlug(
        salonName: widget.salon?.name ?? 'Salone',
        salonId: widget.salonId,
      ),
      promotionSlug: _buildWebLanding().slug,
      title:
          _titleController.text.trim().isEmpty
              ? 'Promozione del salone'
              : _titleController.text.trim(),
    );
  }

  Future<void> _copyLandingValue(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(SnackBar(content: Text(message)));
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
      webLanding: _buildWebLanding(),
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
    final webLanding = _buildWebLanding();
    if (_titleController.text.trim().isEmpty) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Inserisci il titolo della promozione.')),
      );
      return;
    }
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
              webLanding: webLanding,
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
          webLanding: webLanding,
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

class _LandingCopyField extends StatelessWidget {
  const _LandingCopyField({
    required this.label,
    required this.value,
    required this.onCopy,
    this.multiline = false,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment:
                multiline
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  maxLines: multiline ? 8 : 2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    height: 1.45,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copia',
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        ),
      ],
    );
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
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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
              child: Image.network(
                promotion.coverImageUrl!,
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              ),
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
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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

class _LandingTemplatePreview extends StatelessWidget {
  const _LandingTemplatePreview({
    required this.promotion,
    required this.landing,
    required this.salonName,
    required this.salonPhone,
    required this.salonEmail,
  });

  final Promotion promotion;
  final PromotionWebLanding landing;
  final String salonName;
  final String salonPhone;
  final String salonEmail;

  Color get _brown => Color((promotion.themeColor ?? 0xFF6D3D32) | 0xFF000000);
  Color get _terracotta => Color.lerp(_brown, const Color(0xFFA75F4A), 0.64)!;
  Color get _gold => Color.lerp(_brown, const Color(0xFFEFAE73), 0.78)!;
  static const Color _cream = Color(0xFFFAF6F3);
  static const Color _paper = Color(0xFFF7F3EF);
  static const Color _ink = Color(0xFF281D19);
  static const Color _line = Color(0xFFDDD0C8);

  TextStyle _headingStyle({
    required double size,
    Color color = _ink,
    double height = 1.05,
    FontStyle? fontStyle,
  }) {
    final base = TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w500,
      fontStyle: fontStyle,
    );
    if (landing.fontFamily == 'playfairDmSans') {
      return GoogleFonts.playfairDisplay(textStyle: base);
    }
    if (landing.fontFamily == 'system') return base;
    return base.copyWith(fontFamily: landing.fontFamily);
  }

  TextStyle _bodyStyle({
    double size = 11,
    Color color = _ink,
    double height = 1.5,
    FontWeight? weight,
    double? letterSpacing,
  }) {
    final base = TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );
    if (landing.fontFamily == 'playfairDmSans') {
      return GoogleFonts.dmSans(textStyle: base);
    }
    if (landing.fontFamily == 'system') return base;
    return base.copyWith(fontFamily: landing.fontFamily);
  }

  @override
  Widget build(BuildContext context) {
    final templateId = PromotionLandingTemplates.normalize(landing.templateId);
    late final Widget preview;
    switch (templateId) {
      case PromotionLandingTemplates.minimalGlow:
        preview = _buildMinimalGlow();
        break;
      case PromotionLandingTemplates.studioPop:
        preview = _buildStudioPop();
        break;
      case PromotionLandingTemplates.botanicalRitual:
        preview = _buildBotanicalRitual();
        break;
      case PromotionLandingTemplates.editorialBeauty:
        preview = _buildEditorialBeauty();
        break;
      default:
        preview = _buildEditorialBeauty();
        break;
    }
    return KeyedSubtree(
      key: ValueKey<String>('landing-preview-$templateId'),
      child: preview,
    );
  }

  Widget _buildEditorialBeauty() {
    return ColoredBox(
      color: const Color(0xFFE9E7E3),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFFF3F3F1),
            child: Row(
              children: [
                for (final color in const [
                  Color(0xFFFF6B60),
                  Color(0xFFFFBE3E),
                  Color(0xFF2DCC55),
                ]) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'youbook.civiapp.it/s/.../promozioni/${landing.slug}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _previewHero(),
                  for (final section in promotion.sections.take(2))
                    _previewSection(section),
                  if (landing.offerPrice?.trim().isNotEmpty == true ||
                      promotion.discountPercentage > 0)
                    _previewOffer(),
                  _previewBooking(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    color: _ink,
                    child: Text(
                      salonName.toUpperCase(),
                      style: _headingStyle(
                        size: 11,
                        color: Colors.white,
                      ).copyWith(letterSpacing: 2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewHero() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 260),
      color: _brown,
      child: Stack(
        children: [
          if (promotion.coverImageUrl?.trim().isNotEmpty == true) ...[
            Positioned.fill(
              child: Image.network(
                promotion.coverImageUrl!,
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(color: _brown.withValues(alpha: 0.62)),
            ),
          ],
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.65, -0.2),
                  radius: 0.95,
                  colors: [
                    _terracotta.withValues(alpha: 0.58),
                    _brown.withValues(alpha: 0.16),
                    _ink.withValues(alpha: 0.58),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -30,
            top: 30,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        salonName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _headingStyle(
                          size: 10,
                          color: Colors.white,
                        ).copyWith(letterSpacing: 2),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: _gold),
                      ),
                      child: Text(
                        'RICHIEDI ORA',
                        style: _bodyStyle(
                          size: 7,
                          color: Colors.white,
                          weight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 47),
                Row(
                  children: [
                    Container(width: 22, height: 1, color: _gold),
                    const SizedBox(width: 9),
                    Text(
                      landing.eyebrow.toUpperCase(),
                      style: _bodyStyle(
                        size: 7,
                        color: Colors.white.withValues(alpha: 0.82),
                        weight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 510),
                  child: Text(
                    promotion.title.trim().isEmpty
                        ? 'Titolo della promozione'
                        : promotion.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: _headingStyle(size: 39, color: Colors.white),
                  ),
                ),
                if (promotion.subtitle?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    promotion.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _headingStyle(
                      size: 17,
                      color: _gold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewSection(PromotionSection section) {
    if (section.layout == PromotionSectionLayout.quote) {
      return Container(
        width: double.infinity,
        color: _terracotta,
        padding: const EdgeInsets.symmetric(horizontal: 58, vertical: 32),
        child: Column(
          children: [
            if (section.title?.trim().isNotEmpty == true)
              Text(
                section.title!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _headingStyle(size: 23, color: Colors.white),
              ),
            if (section.text?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                section.text!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _bodyStyle(
                  size: 9,
                  color: Colors.white.withValues(alpha: 0.84),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      color: section.order.isEven ? _cream : _paper,
      padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 36),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              section.title?.trim().isNotEmpty == true
                  ? section.title!
                  : 'Sezione della promozione',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _headingStyle(size: 22, color: _brown),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 6,
            child: Text(
              section.text?.trim().isNotEmpty == true
                  ? section.text!
                  : 'Il contenuto configurato apparirà in questa sezione della landing page.',
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(
                size: 9,
                color: _ink.withValues(alpha: 0.68),
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewOffer() {
    final price =
        landing.offerPrice?.trim().isNotEmpty == true
            ? landing.offerPrice!
            : '-${promotion.discountPercentage.round()}%';
    return Container(
      width: double.infinity,
      color: _brown,
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 34),
      child: Column(
        children: [
          Text(
            'LA TUA OCCASIONE',
            style: _bodyStyle(
              size: 7,
              color: _gold,
              weight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(price, style: _headingStyle(size: 42, color: _gold)),
        ],
      ),
    );
  }

  Widget _previewBooking() {
    return Container(
      width: double.infinity,
      color: _cream,
      padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 42),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                landing.eyebrow.toUpperCase(),
                style: _bodyStyle(
                  size: 7,
                  color: _terracotta,
                  weight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                landing.formTitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _headingStyle(size: 30, color: _brown),
              ),
              const SizedBox(height: 12),
              Text(
                landing.formDescription,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(
                  size: 9,
                  color: _ink.withValues(alpha: 0.66),
                  height: 1.6,
                ),
              ),
              if (salonPhone.isNotEmpty || salonEmail.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  [
                    salonPhone,
                    salonEmail,
                  ].where((value) => value.isNotEmpty).join('  ·  '),
                  style: _bodyStyle(size: 8, color: _brown),
                ),
              ],
            ],
          );
          final form = Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _gold, width: 2)),
              boxShadow: [
                BoxShadow(
                  color: _brown.withValues(alpha: 0.09),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final label in const [
                  'NOME E COGNOME',
                  'NUMERO DI TELEFONO',
                  'EMAIL (FACOLTATIVA)',
                ]) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: _bodyStyle(
                        size: 6,
                        color: _ink.withValues(alpha: 0.48),
                        weight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(height: 1, color: _line),
                  const SizedBox(height: 14),
                ],
                if (landing.interestOptions.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SONO INTERESSATA/O A:',
                      style: _bodyStyle(
                        size: 6,
                        color: _ink.withValues(alpha: 0.48),
                        weight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final option in landing.interestOptions.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(
                        children: [
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _ink.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              option,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _bodyStyle(size: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 7),
                Container(
                  width: double.infinity,
                  height: 30,
                  alignment: Alignment.center,
                  color: _brown,
                  child: Text(
                    landing.submitLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(
                      size: 7,
                      color: Colors.white,
                      weight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          );
          if (constraints.maxWidth < 560) {
            return Column(children: [copy, const SizedBox(height: 24), form]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 45),
              Expanded(child: form),
            ],
          );
        },
      ),
    );
  }

  String get _previewTitle =>
      promotion.title.trim().isEmpty
          ? 'Titolo della promozione'
          : promotion.title.trim();

  String get _previewOfferPrice {
    final configured = landing.offerPrice?.trim();
    if (configured?.isNotEmpty == true) return configured!;
    if (promotion.discountPercentage > 0) {
      return '-${promotion.discountPercentage.round()}%';
    }
    return 'OFFERTA SPECIALE';
  }

  String _sectionPreviewTitle(PromotionSection section) {
    final title = section.title?.trim();
    return title?.isNotEmpty == true ? title! : 'Il tuo momento di bellezza';
  }

  String _sectionPreviewBody(PromotionSection section) {
    final text = section.text?.trim();
    if (text?.isNotEmpty == true) return text!;
    final caption = section.caption?.trim();
    if (caption?.isNotEmpty == true) return caption!;
    return 'Scopri tutti i dettagli della promozione e lasciati guidare dal salone.';
  }

  Color _templateSeed(int fallback) =>
      Color((promotion.themeColor ?? fallback) | 0xFF000000);

  Color _onColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? Colors.white
          : const Color(0xFF171717);

  Widget _templateFrame({
    required Color chromeColor,
    required Color canvasColor,
    required Widget child,
  }) {
    return ColoredBox(
      color: canvasColor,
      child: Column(
        children: [
          _templateBrowserBar(color: chromeColor),
          Expanded(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }

  Widget _templateBrowserBar({required Color color}) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: color,
      child: Row(
        children: [
          for (final dotColor in const <Color>[
            Color(0xFFFF6B60),
            Color(0xFFFFBE3E),
            Color(0xFF2DCC55),
          ]) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                'youbook.civiapp.it/s/.../promozioni/${landing.slug}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF777777), fontSize: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _templateImage({
    required String? imageUrl,
    required double height,
    required BorderRadius borderRadius,
    required List<Color> fallbackColors,
    required Color iconColor,
  }) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child:
            imageUrl?.trim().isNotEmpty == true
                ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder:
                      (_, __, ___) => _templateImageFallback(
                        colors: fallbackColors,
                        iconColor: iconColor,
                      ),
                )
                : _templateImageFallback(
                  colors: fallbackColors,
                  iconColor: iconColor,
                ),
      ),
    );
  }

  Widget _templateImageFallback({
    required List<Color> colors,
    required Color iconColor,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -24,
            top: -30,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withValues(alpha: 0.2)),
              ),
            ),
          ),
          Icon(
            Icons.spa_outlined,
            color: iconColor.withValues(alpha: 0.72),
            size: 40,
          ),
        ],
      ),
    );
  }

  Widget _templateForm({
    required Color surface,
    required Color ink,
    required Color line,
    required Color button,
    required Color onButton,
    required Color accent,
    required double radius,
    bool boxedFields = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: ink.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final label in const <String>[
            'NOME E COGNOME',
            'NUMERO DI TELEFONO',
            'EMAIL (FACOLTATIVA)',
          ]) ...[
            Text(
              label,
              style: _bodyStyle(
                size: 6,
                color: ink.withValues(alpha: 0.56),
                weight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 9),
            Container(
              height: boxedFields ? 26 : 1,
              decoration: BoxDecoration(
                color: boxedFields ? line.withValues(alpha: 0.35) : line,
                borderRadius:
                    boxedFields ? BorderRadius.circular(8) : BorderRadius.zero,
                border: boxedFields ? Border.all(color: line) : null,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (landing.interestOptions.isNotEmpty) ...[
            Text(
              'SONO INTERESSATA/O A:',
              style: _bodyStyle(
                size: 6,
                color: ink.withValues(alpha: 0.56),
                weight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option in landing.interestOptions.take(3))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(radius > 0 ? 99 : 0),
                      border: Border.all(color: accent.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      option,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle(size: 7, color: ink),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: button,
              borderRadius: BorderRadius.circular(radius > 0 ? 99 : 0),
            ),
            child: Text(
              landing.submitLabel.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(
                size: 7,
                color: onButton,
                weight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalGlow() {
    const background = Color(0xFFF7F8F5);
    const surface = Colors.white;
    const ink = Color(0xFF17201D);
    const softSage = Color(0xFFDCE6DF);
    const line = Color(0xFFD8DEDA);
    final primary = _templateSeed(0xFF48675D);
    final onPrimary = _onColor(primary);
    final accent = Color.lerp(primary, const Color(0xFF95AA9F), 0.62)!;
    return _templateFrame(
      chromeColor: const Color(0xFFF0F2EE),
      canvasColor: background,
      child: Column(
        children: [
          _minimalNavigation(primary: primary, ink: ink, line: line),
          _minimalHero(
            background: background,
            surface: surface,
            ink: ink,
            primary: primary,
            onPrimary: onPrimary,
            accent: accent,
          ),
          for (final indexed in promotion.sections.take(2).indexed)
            _minimalSection(
              section: indexed.$2,
              index: indexed.$1,
              background: background,
              surface: surface,
              ink: ink,
              primary: primary,
              softSage: softSage,
              line: line,
            ),
          _minimalOffer(
            background: background,
            surface: surface,
            ink: ink,
            primary: primary,
            onPrimary: onPrimary,
            accent: accent,
            line: line,
          ),
          _minimalBooking(
            surface: surface,
            ink: ink,
            primary: primary,
            onPrimary: onPrimary,
            accent: accent,
            softSage: softSage,
            line: line,
          ),
          _minimalFooter(primary: primary, ink: ink, line: line),
        ],
      ),
    );
  }

  Widget _minimalNavigation({
    required Color primary,
    required Color ink,
    required Color line,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              salonName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(
                size: 9,
                color: ink,
                weight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
          ),
          Text(
            'RICHIEDI',
            style: _bodyStyle(
              size: 7,
              color: primary,
              weight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _minimalHero({
    required Color background,
    required Color surface,
    required Color ink,
    required Color primary,
    required Color onPrimary,
    required Color accent,
  }) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 38),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                landing.eyebrow.toUpperCase(),
                style: _bodyStyle(
                  size: 7,
                  color: primary,
                  weight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _previewTitle,
                maxLines: compact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: _headingStyle(
                  size: compact ? 34 : 44,
                  color: ink,
                  height: 0.98,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
              ),
              if (promotion.subtitle?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 13),
                Text(
                  promotion.subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    size: 12,
                    color: ink.withValues(alpha: 0.66),
                    height: 1.45,
                  ),
                ),
              ],
              if (promotion.tagline?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 9),
                Text(
                  promotion.tagline!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    size: 9,
                    color: ink.withValues(alpha: 0.58),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  landing.submitLabel.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    size: 7,
                    color: onPrimary,
                    weight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          );
          final image = DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: _templateImage(
              imageUrl: promotion.coverImageUrl,
              height: compact ? 190 : 270,
              borderRadius: BorderRadius.circular(26),
              fallbackColors: [
                accent.withValues(alpha: 0.35),
                primary.withValues(alpha: 0.82),
              ],
              iconColor: onPrimary,
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 24), image],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 9, child: copy),
              const SizedBox(width: 34),
              Expanded(flex: 11, child: image),
            ],
          );
        },
      ),
    );
  }

  Widget _minimalSection({
    required PromotionSection section,
    required int index,
    required Color background,
    required Color surface,
    required Color ink,
    required Color primary,
    required Color softSage,
    required Color line,
  }) {
    if (section.layout == PromotionSectionLayout.quote) {
      return Container(
        width: double.infinity,
        color: softSage,
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 34),
        child: Column(
          children: [
            Icon(Icons.format_quote_rounded, color: primary, size: 28),
            const SizedBox(height: 8),
            Text(
              _sectionPreviewTitle(section),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _headingStyle(
                size: 24,
                color: ink,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _sectionPreviewBody(section),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _bodyStyle(size: 9, color: ink.withValues(alpha: 0.66)),
            ),
          ],
        ),
      );
    }
    final hasImage =
        section.type == PromotionSectionType.image &&
        section.imageUrl?.trim().isNotEmpty == true;
    return Container(
      color: index.isEven ? surface : background,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 34, height: 2, color: primary),
              const SizedBox(height: 14),
              Text(
                _sectionPreviewTitle(section),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _headingStyle(
                  size: 24,
                  color: ink,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 11),
              Text(
                _sectionPreviewBody(section),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(
                  size: 9,
                  color: ink.withValues(alpha: 0.66),
                  height: 1.65,
                ),
              ),
            ],
          );
          if (!hasImage) return copy;
          final image = _templateImage(
            imageUrl: section.imageUrl,
            height: compact ? 150 : 178,
            borderRadius: BorderRadius.circular(20),
            fallbackColors: [softSage, line],
            iconColor: primary,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [image, const SizedBox(height: 22), copy],
            );
          }
          final imageFirst = index.isEven;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: imageFirst ? image : copy),
              const SizedBox(width: 30),
              Expanded(child: imageFirst ? copy : image),
            ],
          );
        },
      ),
    );
  }

  Widget _minimalOffer({
    required Color background,
    required Color surface,
    required Color ink,
    required Color primary,
    required Color onPrimary,
    required Color accent,
    required Color line,
  }) {
    return Container(
      color: background,
      padding: const EdgeInsets.all(28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: line),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 500;
            final copy = Column(
              crossAxisAlignment:
                  compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
              children: [
                Text(
                  'UN’OCCASIONE PER TE',
                  style: _bodyStyle(
                    size: 7,
                    color: accent,
                    weight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _previewTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: _headingStyle(
                    size: 20,
                    color: ink,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            );
            final price = Text(
              _previewOfferPrice,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _headingStyle(
                size: _previewOfferPrice.length > 12 ? 20 : 34,
                color: primary,
              ).copyWith(fontWeight: FontWeight.w800),
            );
            final button = Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'RICHIEDI',
                style: _bodyStyle(
                  size: 7,
                  color: onPrimary,
                  weight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            );
            if (compact) {
              return Column(
                children: [
                  copy,
                  const SizedBox(height: 14),
                  price,
                  const SizedBox(height: 14),
                  button,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 5, child: copy),
                const SizedBox(width: 18),
                Expanded(flex: 3, child: price),
                const SizedBox(width: 18),
                button,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _minimalBooking({
    required Color surface,
    required Color ink,
    required Color primary,
    required Color onPrimary,
    required Color accent,
    required Color softSage,
    required Color line,
  }) {
    return Container(
      color: softSage,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 38),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                landing.eyebrow.toUpperCase(),
                style: _bodyStyle(
                  size: 7,
                  color: primary,
                  weight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                landing.formTitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _headingStyle(
                  size: 28,
                  color: ink,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                landing.formDescription,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(
                  size: 9,
                  color: ink.withValues(alpha: 0.66),
                  height: 1.6,
                ),
              ),
              if (salonPhone.isNotEmpty || salonEmail.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  <String>[
                    salonPhone,
                    salonEmail,
                  ].where((value) => value.isNotEmpty).join('  ·  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(size: 8, color: primary),
                ),
              ],
            ],
          );
          final form = _templateForm(
            surface: surface,
            ink: ink,
            line: line,
            button: primary,
            onButton: onPrimary,
            accent: accent,
            radius: 18,
            boxedFields: true,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 24), form],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 36),
              Expanded(child: form),
            ],
          );
        },
      ),
    );
  }

  Widget _minimalFooter({
    required Color primary,
    required Color ink,
    required Color line,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: line)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        runSpacing: 8,
        children: [
          Text(
            salonName.toUpperCase(),
            style: _bodyStyle(
              size: 8,
              color: ink,
              weight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          Text(
            <String>[
              salonPhone,
              salonEmail,
            ].where((value) => value.isNotEmpty).join('  ·  '),
            style: _bodyStyle(size: 7, color: primary),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioPop() {
    const background = Color(0xFFFFF3E8);
    const surface = Colors.white;
    const ink = Color(0xFF171717);
    const yellow = Color(0xFFFFC857);
    const navy = Color(0xFF22304A);
    const line = Color(0xFFE9D9CB);
    final primary = _templateSeed(0xFFE8513D);
    final onPrimary = _onColor(primary);
    return _templateFrame(
      chromeColor: const Color(0xFFF4E6DA),
      canvasColor: background,
      child: Column(
        children: [
          _studioNavigation(navy: navy, yellow: yellow),
          _studioHero(
            primary: primary,
            onPrimary: onPrimary,
            yellow: yellow,
            navy: navy,
            ink: ink,
          ),
          for (final indexed in promotion.sections.take(2).indexed)
            _studioSection(
              section: indexed.$2,
              index: indexed.$1,
              background: background,
              surface: surface,
              ink: ink,
              primary: primary,
              onPrimary: onPrimary,
              yellow: yellow,
              navy: navy,
              line: line,
            ),
          _studioOffer(
            primary: primary,
            onPrimary: onPrimary,
            yellow: yellow,
            navy: navy,
          ),
          _studioBooking(
            background: background,
            surface: surface,
            ink: ink,
            primary: primary,
            onPrimary: onPrimary,
            yellow: yellow,
            navy: navy,
            line: line,
          ),
          _studioFooter(navy: navy, yellow: yellow),
        ],
      ),
    );
  }

  Widget _studioNavigation({required Color navy, required Color yellow}) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: navy,
      child: Row(
        children: [
          Container(width: 14, height: 14, color: yellow),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              salonName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(
                size: 9,
                color: Colors.white,
                weight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            color: yellow,
            child: Text(
              'LET’S GLOW',
              style: _bodyStyle(
                size: 7,
                color: navy,
                weight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studioHero({
    required Color primary,
    required Color onPrimary,
    required Color yellow,
    required Color navy,
    required Color ink,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return Container(
          color: primary,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: compact ? -46 : 26,
                top: compact ? 34 : -38,
                child: Transform.rotate(
                  angle: -0.12,
                  child: Container(
                    width: compact ? 110 : 178,
                    height: compact ? 110 : 178,
                    color: yellow.withValues(alpha: 0.92),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 30, 28, 34),
                child:
                    compact
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _studioHeroCopy(
                              primary: primary,
                              onPrimary: onPrimary,
                              yellow: yellow,
                              navy: navy,
                              compact: true,
                            ),
                            const SizedBox(height: 24),
                            _studioHeroImage(
                              primary: primary,
                              onPrimary: onPrimary,
                              yellow: yellow,
                              navy: navy,
                              height: 185,
                            ),
                          ],
                        )
                        : Row(
                          children: [
                            Expanded(
                              flex: 11,
                              child: _studioHeroCopy(
                                primary: primary,
                                onPrimary: onPrimary,
                                yellow: yellow,
                                navy: navy,
                                compact: false,
                              ),
                            ),
                            const SizedBox(width: 26),
                            Expanded(
                              flex: 9,
                              child: _studioHeroImage(
                                primary: primary,
                                onPrimary: onPrimary,
                                yellow: yellow,
                                navy: navy,
                                height: 260,
                              ),
                            ),
                          ],
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _studioHeroCopy({
    required Color primary,
    required Color onPrimary,
    required Color yellow,
    required Color navy,
    required bool compact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          color: navy,
          child: Text(
            landing.eyebrow.toUpperCase(),
            style: _bodyStyle(
              size: 7,
              color: Colors.white,
              weight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _previewTitle.toUpperCase(),
          maxLines: compact ? 3 : 4,
          overflow: TextOverflow.ellipsis,
          style: _bodyStyle(
            size: compact ? 34 : 43,
            color: onPrimary,
            height: 0.9,
            weight: FontWeight.w900,
            letterSpacing: -1.4,
          ),
        ),
        if (promotion.subtitle?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 13),
          Text(
            promotion.subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(
              size: 11,
              color: onPrimary.withValues(alpha: 0.84),
              weight: FontWeight.w600,
            ),
          ),
        ],
        if (promotion.tagline?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            promotion.tagline!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(
              size: 8,
              color: onPrimary.withValues(alpha: 0.72),
            ),
          ),
        ],
        const SizedBox(height: 19),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          color: yellow,
          child: Text(
            '${landing.submitLabel.toUpperCase()}  →',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyStyle(
              size: 7,
              color: navy,
              weight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _studioHeroImage({
    required Color primary,
    required Color onPrimary,
    required Color yellow,
    required Color navy,
    required double height,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 10),
          child: Container(height: height, color: navy),
        ),
        _templateImage(
          imageUrl: promotion.coverImageUrl,
          height: height,
          borderRadius: BorderRadius.zero,
          fallbackColors: [yellow, primary],
          iconColor: onPrimary,
        ),
        Positioned(
          right: -8,
          bottom: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            color: yellow,
            child: Text(
              'NEW',
              style: _bodyStyle(
                size: 7,
                color: navy,
                weight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _studioSection({
    required PromotionSection section,
    required int index,
    required Color background,
    required Color surface,
    required Color ink,
    required Color primary,
    required Color onPrimary,
    required Color yellow,
    required Color navy,
    required Color line,
  }) {
    if (section.layout == PromotionSectionLayout.quote) {
      return Container(
        width: double.infinity,
        color: navy,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: -12,
              child: Text('“', style: _headingStyle(size: 74, color: yellow)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    _sectionPreviewTitle(section).toUpperCase(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: _bodyStyle(
                      size: 24,
                      color: Colors.white,
                      height: 1,
                      weight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _sectionPreviewBody(section),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: _bodyStyle(
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.74),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final hasImage =
        section.type == PromotionSectionType.image &&
        section.imageUrl?.trim().isNotEmpty == true;
    return Container(
      color: index.isEven ? background : surface,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final copy = Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surface,
              border: Border(
                top: BorderSide(
                  color: index.isEven ? primary : yellow,
                  width: 5,
                ),
                right: BorderSide(color: line),
                bottom: BorderSide(color: line),
                left: BorderSide(color: line),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '0${index + 1} / FEATURE',
                  style: _bodyStyle(
                    size: 7,
                    color: primary,
                    weight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  _sectionPreviewTitle(section).toUpperCase(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    size: 22,
                    color: ink,
                    height: 1,
                    weight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _sectionPreviewBody(section),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    size: 9,
                    color: ink.withValues(alpha: 0.65),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          );
          if (!hasImage) return copy;
          final image = _templateImage(
            imageUrl: section.imageUrl,
            height: compact ? 158 : 200,
            borderRadius: BorderRadius.zero,
            fallbackColors: [yellow, primary],
            iconColor: navy,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [image, const SizedBox(height: 14), copy],
            );
          }
          final imageFirst = index.isOdd;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: imageFirst ? image : copy),
              const SizedBox(width: 16),
              Expanded(child: imageFirst ? copy : image),
            ],
          );
        },
      ),
    );
  }

  Widget _studioOffer({
    required Color primary,
    required Color onPrimary,
    required Color yellow,
    required Color navy,
  }) {
    return Container(
      width: double.infinity,
      color: yellow,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;
          final label = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: navy,
            child: Text(
              'DROP SPECIALE',
              style: _bodyStyle(
                size: 7,
                color: Colors.white,
                weight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          );
          final title = Text(
            _previewTitle.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: _bodyStyle(
              size: 19,
              color: navy,
              height: 1,
              weight: FontWeight.w900,
            ),
          );
          final price = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: primary,
            child: Text(
              _previewOfferPrice,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _bodyStyle(
                size: _previewOfferPrice.length > 12 ? 18 : 30,
                color: onPrimary,
                height: 1,
                weight: FontWeight.w900,
              ),
            ),
          );
          if (compact) {
            return Column(
              children: [
                label,
                const SizedBox(height: 12),
                title,
                const SizedBox(height: 14),
                price,
              ],
            );
          }
          return Row(
            children: [
              label,
              const SizedBox(width: 16),
              Expanded(child: title),
              const SizedBox(width: 18),
              price,
            ],
          );
        },
      ),
    );
  }

  Widget _studioBooking({
    required Color background,
    required Color surface,
    required Color ink,
    required Color primary,
    required Color onPrimary,
    required Color yellow,
    required Color navy,
    required Color line,
  }) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 38),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: primary,
                child: Text(
                  landing.eyebrow.toUpperCase(),
                  style: _bodyStyle(
                    size: 7,
                    color: onPrimary,
                    weight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Text(
                landing.formTitle.toUpperCase(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(
                  size: 28,
                  color: navy,
                  height: 0.98,
                  weight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                landing.formDescription,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(
                  size: 9,
                  color: ink.withValues(alpha: 0.68),
                  height: 1.55,
                ),
              ),
              if (salonPhone.isNotEmpty || salonEmail.isNotEmpty) ...[
                const SizedBox(height: 15),
                Text(
                  <String>[
                    salonPhone,
                    salonEmail,
                  ].where((value) => value.isNotEmpty).join('  /  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    size: 8,
                    color: primary,
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          );
          final form = Container(
            decoration: BoxDecoration(
              color: navy,
              boxShadow: [
                BoxShadow(
                  color: navy.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(7, 9),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    color: yellow,
                    child: Text(
                      'YOUR MOVE',
                      style: _bodyStyle(
                        size: 6,
                        color: navy,
                        weight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _templateForm(
                  surface: surface,
                  ink: ink,
                  line: line,
                  button: primary,
                  onButton: onPrimary,
                  accent: yellow,
                  radius: 0,
                  boxedFields: true,
                ),
              ],
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 24), form],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 32),
              Expanded(child: form),
            ],
          );
        },
      ),
    );
  }

  Widget _studioFooter({required Color navy, required Color yellow}) {
    return Container(
      width: double.infinity,
      color: navy,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        runSpacing: 8,
        children: [
          Text(
            salonName.toUpperCase(),
            style: _bodyStyle(
              size: 9,
              color: Colors.white,
              weight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          Text(
            <String>[
              salonPhone,
              salonEmail,
            ].where((value) => value.isNotEmpty).join('  /  '),
            style: _bodyStyle(size: 7, color: yellow, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildBotanicalRitual() {
    const background = Color(0xFFF3F0E7);
    const paper = Color(0xFFE6EBDD);
    const ink = Color(0xFF1D2B25);
    const sage = Color(0xFF9DAF98);
    const copper = Color(0xFFB97B55);
    const line = Color(0xFFD2D6C9);
    final forest = _templateSeed(0xFF315B4A);
    final onForest = _onColor(forest);
    return _templateFrame(
      chromeColor: const Color(0xFFE8E7E0),
      canvasColor: background,
      child: Column(
        children: [
          _botanicalNavigation(forest: forest, copper: copper),
          _botanicalHero(
            forest: forest,
            onForest: onForest,
            sage: sage,
            copper: copper,
          ),
          for (final indexed in promotion.sections.take(2).indexed)
            _botanicalSection(
              section: indexed.$2,
              index: indexed.$1,
              background: background,
              paper: paper,
              ink: ink,
              forest: forest,
              sage: sage,
              copper: copper,
              line: line,
            ),
          _botanicalOffer(
            background: background,
            ink: ink,
            forest: forest,
            onForest: onForest,
            copper: copper,
            line: line,
          ),
          _botanicalBooking(
            background: background,
            paper: paper,
            ink: ink,
            forest: forest,
            onForest: onForest,
            sage: sage,
            copper: copper,
            line: line,
          ),
          _botanicalFooter(forest: forest, onForest: onForest, copper: copper),
        ],
      ),
    );
  }

  Widget _botanicalNavigation({required Color forest, required Color copper}) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      color: const Color(0xFFF3F0E7),
      child: Row(
        children: [
          Icon(Icons.eco_outlined, size: 17, color: copper),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              salonName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _headingStyle(
                size: 10,
                color: forest,
              ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 2),
            ),
          ),
          Container(width: 34, height: 1, color: copper),
          const SizedBox(width: 9),
          Text(
            'RITUALE',
            style: _bodyStyle(
              size: 7,
              color: forest,
              weight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botanicalHero({
    required Color forest,
    required Color onForest,
    required Color sage,
    required Color copper,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final height = compact ? 360.0 : 330.0;
        return SizedBox(
          width: double.infinity,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _templateImage(
                imageUrl: promotion.coverImageUrl,
                height: height,
                borderRadius: BorderRadius.zero,
                fallbackColors: [sage, forest],
                iconColor: onForest,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      forest.withValues(alpha: 0.12),
                      forest.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: compact ? -74 : 30,
                top: compact ? 34 : 38,
                child: Container(
                  width: compact ? 150 : 190,
                  height: compact ? 150 : 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 34, 30, 34),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: compact ? constraints.maxWidth - 60 : 510,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 28, height: 1, color: copper),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                landing.eyebrow.toUpperCase(),
                                maxLines: 2,
                                style: _bodyStyle(
                                  size: 7,
                                  color: Colors.white.withValues(alpha: 0.88),
                                  weight: FontWeight.w700,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _previewTitle,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: _headingStyle(
                            size: compact ? 36 : 45,
                            color: Colors.white,
                            height: 0.98,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                        if (promotion.subtitle?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 11),
                          Text(
                            promotion.subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _headingStyle(
                              size: 15,
                              color: const Color(0xFFE9DDCE),
                              height: 1.2,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (promotion.tagline?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(
                            promotion.tagline!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _bodyStyle(
                              size: 8,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _botanicalSection({
    required PromotionSection section,
    required int index,
    required Color background,
    required Color paper,
    required Color ink,
    required Color forest,
    required Color sage,
    required Color copper,
    required Color line,
  }) {
    if (section.layout == PromotionSectionLayout.quote) {
      return Container(
        width: double.infinity,
        color: copper,
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 38),
        child: Column(
          children: [
            Icon(
              Icons.local_florist_outlined,
              color: Colors.white.withValues(alpha: 0.72),
              size: 24,
            ),
            const SizedBox(height: 12),
            Text(
              _sectionPreviewTitle(section),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _headingStyle(size: 25, color: Colors.white),
            ),
            const SizedBox(height: 9),
            Text(
              _sectionPreviewBody(section),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _bodyStyle(
                size: 9,
                color: Colors.white.withValues(alpha: 0.84),
              ),
            ),
          ],
        ),
      );
    }
    final hasImage =
        section.type == PromotionSectionType.image &&
        section.imageUrl?.trim().isNotEmpty == true;
    return Container(
      color: index.isEven ? background : paper,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 38),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'RITUALE 0${index + 1}',
                style: _bodyStyle(
                  size: 7,
                  color: copper,
                  weight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                _sectionPreviewTitle(section),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: _headingStyle(size: 26, color: forest),
              ),
              const SizedBox(height: 11),
              Text(
                _sectionPreviewBody(section),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(
                  size: 9,
                  color: ink.withValues(alpha: 0.66),
                  height: 1.65,
                ),
              ),
            ],
          );
          if (!hasImage) return copy;
          final image = Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(30),
            ),
            child: _templateImage(
              imageUrl: section.imageUrl,
              height: compact ? 160 : 206,
              borderRadius: BorderRadius.circular(24),
              fallbackColors: [paper, sage],
              iconColor: forest,
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [image, const SizedBox(height: 24), copy],
            );
          }
          final imageFirst = index.isEven;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: imageFirst ? image : copy),
              const SizedBox(width: 34),
              Expanded(child: imageFirst ? copy : image),
            ],
          );
        },
      ),
    );
  }

  Widget _botanicalOffer({
    required Color background,
    required Color ink,
    required Color forest,
    required Color onForest,
    required Color copper,
    required Color line,
  }) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 24),
        decoration: BoxDecoration(
          color: forest,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: line.withValues(alpha: 0.35)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 500;
            final copy = Column(
              crossAxisAlignment:
                  compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
              children: [
                Text(
                  'IL TUO RITUALE',
                  style: _bodyStyle(
                    size: 7,
                    color: copper,
                    weight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _previewTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: _headingStyle(size: 21, color: onForest),
                ),
              ],
            );
            final price = Text(
              _previewOfferPrice,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _headingStyle(
                size: _previewOfferPrice.length > 12 ? 19 : 35,
                color: const Color(0xFFE9DDCE),
              ).copyWith(fontWeight: FontWeight.w600),
            );
            if (compact) {
              return Column(
                children: [copy, const SizedBox(height: 15), price],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 24),
                price,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _botanicalBooking({
    required Color background,
    required Color paper,
    required Color ink,
    required Color forest,
    required Color onForest,
    required Color sage,
    required Color copper,
    required Color line,
  }) {
    return Container(
      color: paper,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: line),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.eco_outlined, color: copper, size: 22),
                const SizedBox(height: 12),
                Text(
                  landing.formTitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _headingStyle(size: 28, color: forest),
                ),
                const SizedBox(height: 10),
                Text(
                  landing.formDescription,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(
                    size: 9,
                    color: ink.withValues(alpha: 0.66),
                    height: 1.6,
                  ),
                ),
                if (salonPhone.isNotEmpty || salonEmail.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Text(
                    <String>[
                      salonPhone,
                      salonEmail,
                    ].where((value) => value.isNotEmpty).join('  ·  '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(size: 8, color: copper),
                  ),
                ],
              ],
            );
            final form = _templateForm(
              surface: Colors.white,
              ink: ink,
              line: line,
              button: forest,
              onButton: onForest,
              accent: sage,
              radius: 20,
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 24), form],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 34),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _botanicalFooter({
    required Color forest,
    required Color onForest,
    required Color copper,
  }) {
    return Container(
      width: double.infinity,
      color: forest,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.eco_outlined, size: 14, color: copper),
              const SizedBox(width: 8),
              Text(
                salonName.toUpperCase(),
                style: _headingStyle(
                  size: 9,
                  color: onForest,
                ).copyWith(letterSpacing: 1.6),
              ),
            ],
          ),
          Text(
            <String>[
              salonPhone,
              salonEmail,
            ].where((value) => value.isNotEmpty).join('  ·  '),
            style: _bodyStyle(size: 7, color: onForest.withValues(alpha: 0.7)),
          ),
        ],
      ),
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
