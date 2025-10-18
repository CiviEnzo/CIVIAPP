import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/promotion.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:civiapp/presentation/screens/client/client_theme.dart';

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

class _PromotionEditorDialogState extends ConsumerState<PromotionEditorDialog> {
  static const int _maxImageBytes = 6 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _detailsScrollController = ScrollController();
  final _contentScrollController = ScrollController();

  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _taglineController;
  late final TextEditingController _discountController;
  late final TextEditingController _priorityController;
  late final TextEditingController _ctaLabelController;
  late final TextEditingController _ctaCustomUrlController;
  late final TextEditingController _ctaPhoneController;
  late final TextEditingController _ctaWhatsappMessageController;

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

  @override
  void initState() {
    super.initState();
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
    _startsAt = initial?.startsAt;
    _endsAt = initial?.endsAt;
    _coverImageUrl = initial?.coverImageUrl;
    _coverImagePath = initial?.coverImagePath;
    _initializeStatus(initial);
    _initializeCta(initial);
    _initializeSections(initial);
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
            initialText: section.text ?? '',
            layout: section.layout,
            visible: section.visible,
          );
          break;
        case PromotionSectionType.image:
          editable = _EditablePromotionSection.image(
            id: section.id.isEmpty ? const Uuid().v4() : section.id,
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

  @override
  void dispose() {
    _detailsScrollController.dispose();
    _contentScrollController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _taglineController.dispose();
    _discountController.dispose();
    _priorityController.dispose();
    _ctaLabelController.dispose();
    _ctaCustomUrlController.dispose();
    _ctaPhoneController.dispose();
    _ctaWhatsappMessageController.dispose();
    for (final section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: min(MediaQuery.of(context).size.width * 0.9, 960),
        height: min(MediaQuery.of(context).size.height * 0.9, 720),
        child: DefaultTabController(
          length: 3,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.initialPromotion == null
                              ? 'Nuova promozione'
                              : 'Modifica promozione',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Chiudi',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Dettagli'),
                    Tab(text: 'Contenuto'),
                    Tab(text: 'Anteprima'),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildDetailsStep(theme),
                      _buildContentStep(theme),
                      _buildPreviewStep(theme),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annulla'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _submit,
                        child: Text(
                          widget.initialPromotion == null ? 'Crea' : 'Salva',
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

  Widget _buildDetailsStep(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Scrollbar(
      controller: _detailsScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _detailsScrollController,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titolo promozione',
                hintText: 'Es. Promo primavera',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Inserisci un titolo';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subtitleController,
              decoration: const InputDecoration(
                labelText: 'Sottotitolo (opzionale)',
                hintText: 'Es. Solo fino al 12 maggio',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _taglineController,
              decoration: const InputDecoration(
                labelText: 'Tagline breve (opzionale)',
                hintText: 'Es. Gift card inclusa',
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
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
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _DatePickerField(
                    label: 'Inizio promo',
                    value: _startsAt,
                    onChanged: (value) => setState(() => _startsAt = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerField(
                    label: 'Fine promo',
                    value: _endsAt,
                    onChanged: (value) => setState(() => _endsAt = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Call to action',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Scegli cosa succede quando il cliente tocca “Contatta”.',
              ),
              children: [
                const SizedBox(height: 12),
                DropdownButtonFormField<PromotionCtaType>(
                  value: _ctaType,
                  items: _buildCtaTypeItems(),
                  decoration: const InputDecoration(labelText: 'Tipo azione'),
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
                if (_ctaType != PromotionCtaType.none) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ctaLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Testo pulsante',
                      hintText: 'Es. Prenota ora',
                    ),
                  ),
                ],
                if (_ctaType == PromotionCtaType.link ||
                    _ctaType == PromotionCtaType.booking) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ctaCustomUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL destinazione',
                      hintText: 'https://',
                    ),
                    validator: _validateCustomUrl,
                  ),
                ],
                if (_ctaType == PromotionCtaType.phone ||
                    _ctaType == PromotionCtaType.whatsapp) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ctaPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Numero di telefono',
                      hintText: '+39...',
                    ),
                    validator: _validatePhoneNumber,
                  ),
                ],
                if (_ctaType == PromotionCtaType.whatsapp) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ctaWhatsappMessageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Messaggio precompilato',
                      helperText:
                          'Personalizza il testo che apparirà in WhatsApp.',
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                'Impostazioni avanzate',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _discountController,
                        decoration: const InputDecoration(
                          labelText: 'Sconto (%)',
                          hintText: '0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priorityController,
                        decoration: const InputDecoration(
                          labelText: 'Priorità elenco',
                          hintText: '0',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_previewCtaUrl() != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _previewCtaUrl()!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentStep(ThemeData theme) {
    return Scrollbar(
      controller: _contentScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _contentScrollController,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Immagine di copertina',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
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
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Sezioni contenuto',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  label: Text('${_sections.length} elementi'),
                  avatar: const Icon(Icons.view_day_outlined),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _addSection(PromotionSectionType.text),
                  icon: const Icon(Icons.short_text_rounded),
                  label: const Text('Aggiungi testo'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _addSection(PromotionSectionType.image),
                  icon: const Icon(Icons.image_rounded),
                  label: const Text('Aggiungi immagine'),
                ),
              ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewStep(ThemeData baseTheme) {
    final promotion = _buildPromotionForPreview();
    final themed = ClientTheme.resolve(baseTheme);
    return Theme(
      data: themed,
      child: Builder(
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 640;
                final preview = _PromotionPreview(promotion: promotion);
                final detail = _PromotionDetailPreview(promotion: promotion);
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: preview),
                      const SizedBox(width: 24),
                      Expanded(child: detail),
                    ],
                  );
                }
                return ListView(
                  children: [
                    SizedBox(height: 300, child: preview),
                    const SizedBox(height: 24),
                    detail,
                  ],
                );
              },
            ),
          );
        },
      ),
    );
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
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
      withReadStream: true,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.first;
    if (file.size > _maxImageBytes) {
      final maxMb = (_maxImageBytes / (1024 * 1024)).toStringAsFixed(1);
      setState(() {
        _coverUploadError = 'L\'immagine supera il limite di $maxMb MB.';
        _coverUploadInfo = null;
      });
      return;
    }
    final bytes = await _resolveBytes(file);
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
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
      withReadStream: true,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.first;
    if (file.size > _maxImageBytes) {
      final maxMb = (_maxImageBytes / (1024 * 1024)).toStringAsFixed(1);
      setState(() {
        _sectionUploadErrors[section.id] =
            'L\'immagine supera il limite di $maxMb MB.';
      });
      return;
    }
    final bytes = await _resolveBytes(file);
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

  Future<Uint8List?> _resolveBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes;
    }
    final stream = file.readStream;
    if (stream == null) {
      return null;
    }
    final builder = BytesBuilder();
    try {
      await for (final chunk in stream) {
        builder.add(chunk);
        if (builder.length > _maxImageBytes) {
          return null;
        }
      }
      final data = builder.takeBytes();
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
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }
    PromotionCta? promotionCta;
    try {
      promotionCta = _buildPromotionCta();
    } on FormatException catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (_ctaType != PromotionCtaType.none && promotionCta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
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
    final isSelected = status == groupValue;
    return FilterChip(
      selected: isSelected,
      onSelected: (_) => onChanged(status),
      label: Text(_labelForStatus(status)),
      avatar: Icon(
        _iconForStatus(status),
        color: isSelected ? theme.colorScheme.onPrimary : null,
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
        return Icons.edit_note_rounded;
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
    final display =
        value == null
            ? 'Non impostata'
            : DateFormat('dd/MM/yyyy HH:mm', 'it_IT').format(value!);
    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final initialDate = value ?? now;
        final date = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 2),
        );
        if (date == null) {
          onChanged(null);
          return;
        }
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initialDate),
        );
        if (time == null) {
          onChanged(DateTime(date.year, date.month, date.day));
          return;
        }
        final result = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        onChanged(result);
      },
      icon: const Icon(Icons.calendar_today_rounded),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(display),
          ],
        ),
      ),
      style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                                  Container(color: scheme.surfaceVariant),
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Center(
                  child: Text(
                    'Nessuna immagine caricata',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
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
            if (info != null) ...[
              const SizedBox(height: 8),
              Text(
                info!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditablePromotionSection {
  _EditablePromotionSection.text({
    required this.id,
    String initialText = '',
    PromotionSectionLayout layout = PromotionSectionLayout.full,
    bool visible = true,
  }) : type = PromotionSectionType.text,
       textController = TextEditingController(text: initialText),
       altTextController = null,
       captionController = null,
       layout = layout,
       visible = visible,
       imageUrl = null,
       imagePath = null;

  _EditablePromotionSection.image({
    required this.id,
    String? imageUrl,
    String? imagePath,
    String altText = '',
    String caption = '',
    PromotionSectionLayout layout = PromotionSectionLayout.full,
    bool visible = true,
  }) : type = PromotionSectionType.image,
       textController = null,
       altTextController = TextEditingController(text: altText),
       captionController = TextEditingController(text: caption),
       layout = layout,
       visible = visible,
       imageUrl = imageUrl,
       imagePath = imagePath;

  final String id;
  final PromotionSectionType type;
  final TextEditingController? textController;
  final TextEditingController? altTextController;
  final TextEditingController? captionController;
  PromotionSectionLayout layout;
  bool visible;
  String? imageUrl;
  String? imagePath;
  bool isUploading = false;

  bool get isEffectivelyEmpty {
    switch (type) {
      case PromotionSectionType.text:
        return textController?.text.trim().isEmpty ?? true;
      case PromotionSectionType.image:
        return imageUrl == null || imageUrl!.isEmpty;
    }
  }

  _EditablePromotionSection duplicate() {
    switch (type) {
      case PromotionSectionType.text:
        return _EditablePromotionSection.text(
          id: const Uuid().v4(),
          initialText: textController?.text ?? '',
          layout: layout,
          visible: visible,
        );
      case PromotionSectionType.image:
        return _EditablePromotionSection.image(
          id: const Uuid().v4(),
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
    switch (type) {
      case PromotionSectionType.text:
        return PromotionSection(
          id: id,
          type: type,
          order: order,
          text: textController?.text.trim(),
          layout: layout,
          visible: visible,
        );
      case PromotionSectionType.image:
        return PromotionSection(
          id: id,
          type: type,
          order: order,
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
    final subtitleText =
        widget.section.type == PromotionSectionType.text
            ? (widget.section.textController?.text.trim() ?? '')
            : (widget.section.imageUrl == null
                ? 'Nessuna immagine caricata'
                : 'Immagine caricata');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(
              widget.section.type == PromotionSectionType.text
                  ? 'Sezione testo'
                  : 'Sezione immagine',
            ),
            subtitle: Text(
              subtitleText.isEmpty
                  ? 'Tocca per aggiungere contenuto'
                  : subtitleText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            leading: ReorderableDragStartListener(
              index: widget.index,
              child: const Icon(Icons.drag_handle_rounded),
            ),
            trailing: Wrap(
              spacing: 6,
              children: [
                IconButton(
                  tooltip: _isExpanded ? 'Comprimi' : 'Espandi',
                  onPressed: _toggleExpanded,
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ),
                IconButton(
                  tooltip: 'Duplica',
                  onPressed: widget.onDuplicate,
                  icon: const Icon(Icons.copy_rounded),
                ),
                IconButton(
                  tooltip: 'Rimuovi',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            onTap: _toggleExpanded,
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
                          DropdownButton<PromotionSectionLayout>(
                            value: widget.section.layout,
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
                          const SizedBox(width: 12),
                          FilterChip(
                            selected: widget.section.visible,
                            onSelected: (value) {
                              setState(() {
                                widget.section.visible = value;
                              });
                              widget.onChanged();
                            },
                            label: Text(
                              widget.section.visible ? 'Visibile' : 'Nascosto',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.section.type == PromotionSectionType.text)
                        TextFormField(
                          controller: widget.section.textController,
                          maxLines: 6,
                          minLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Testo',
                            alignLabelWithHint: true,
                            hintText:
                                'Racconta i dettagli della promozione con paragrafi brevi.',
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
                    (_, __, ___) => Container(color: scheme.surfaceVariant),
              ),
            ),
          )
        else
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('Nessuna immagine caricata')),
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
          decoration: const InputDecoration(
            labelText: 'Testo alternativo',
            hintText: "Descrivi l'immagine per accessibilità",
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: section.captionController,
          decoration: const InputDecoration(
            labelText: 'Didascalia (opzionale)',
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
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
    final endsAt = promotion.endsAt;
    final dateLabel =
        endsAt == null
            ? 'Senza scadenza'
            : DateFormat('dd MMM', 'it_IT').format(endsAt);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (promotion.coverImageUrl != null)
            Positioned.fill(
              child: Image.network(
                promotion.coverImageUrl!,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.35),
                colorBlendMode: BlendMode.darken,
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primaryContainer, scheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(
                      dateLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimary,
                      ),
                    ),
                    backgroundColor: scheme.primary.withOpacity(0.75),
                  ),
                  const Spacer(),
                  Text(
                    promotion.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (promotion.subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      promotion.subtitle!,
                      style: theme.textTheme.titleMedium?.copyWith(
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

class _PromotionDetailPreview extends StatelessWidget {
  const _PromotionDetailPreview({required this.promotion});

  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (promotion.coverImageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(promotion.coverImageUrl!, fit: BoxFit.cover),
            )
          else
            Container(
              height: 180,
              color: scheme.surfaceVariant,
              child: const Center(
                child: Icon(Icons.image_not_supported_outlined, size: 48),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promotion.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (promotion.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(promotion.subtitle!, style: theme.textTheme.titleMedium),
                ],
                const SizedBox(height: 16),
                ...promotion.sections.map((section) {
                  switch (section.type) {
                    case PromotionSectionType.text:
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          section.text ?? '',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      );
                    case PromotionSectionType.image:
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (section.imageUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  section.imageUrl!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (section.caption != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                section.caption!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                  }
                }),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(promotion.cta?.label ?? 'Contatta il salone'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
