import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_photo.dart';
import 'package:you_book/domain/entities/client_photo_collage.dart';

class CollageEditorDialog extends ConsumerStatefulWidget {
  const CollageEditorDialog({
    required this.client,
    this.initialNote,
    super.key,
  });

  final Client client;
  final String? initialNote;

  @override
  ConsumerState<CollageEditorDialog> createState() =>
      _CollageEditorDialogState();
}

enum CollageSelectionSlot { primary, secondary }

class _CollageImageController {
  ClientPhoto? photo;
  Offset offset = Offset.zero;
  double scale = 1;
  double rotation = 0;

  void resetTransform() {
    offset = Offset.zero;
    scale = 1;
    rotation = 0;
  }
}

class _CollageEditorDialogState extends ConsumerState<CollageEditorDialog> {
  static const double _minScale = 0.5;
  static const double _maxScale = 3.0;

  final _canvasKey = GlobalKey();
  final _noteController = TextEditingController();
  final _primaryController = _CollageImageController();
  final _secondaryController = _CollageImageController();
  final Uuid _uuid = const Uuid();

  CollageSelectionSlot _activeSlot = CollageSelectionSlot.primary;
  ClientPhotoCollageOrientation _orientation =
      ClientPhotoCollageOrientation.horizontal;
  bool _showGuides = true;
  bool _isSaving = false;

  double? _primaryScaleBase;
  double? _secondaryScaleBase;
  double? _primaryRotationBase;
  double? _secondaryRotationBase;

  @override
  void initState() {
    super.initState();
    if (widget.initialNote != null) {
      _noteController.text = widget.initialNote!;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(clientPhotosProvider(widget.client.id));
    final grouped = _groupPhotosBySet(photos);
    final otherPhotos = photos
        .where((photo) => photo.setType == null)
        .toList(growable: false);
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width >= 1100;
    final canSave =
        _primaryController.photo != null && _secondaryController.photo != null;
    final hasNote = _noteController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Chiudi',
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text('Crea collage'),
        actions: [
          IconButton(
            tooltip:
                hasNote ? 'Modifica nota collage' : 'Aggiungi nota collage',
            icon: Icon(
              hasNote ? Icons.sticky_note_2_outlined : Icons.note_add_outlined,
            ),
            onPressed: _isSaving ? null : _openNoteDialog,
          ),
          TextButton.icon(
            onPressed: !canSave || _isSaving ? null : _saveCollage,
            icon:
                _isSaving
                    ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Salvataggio…' : 'Salva collage'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              isWide
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: _buildCanvasSection(theme)),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: _buildSelectionSection(
                          theme: theme,
                          grouped: grouped,
                          otherPhotos: otherPhotos,
                        ),
                      ),
                    ],
                  )
                  : Column(
                    children: [
                      Expanded(child: _buildCanvasSection(theme)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: mediaQuery.size.height * 0.4,
                        child: _buildSelectionSection(
                          theme: theme,
                          grouped: grouped,
                          otherPhotos: otherPhotos,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Map<ClientPhotoSetType, List<ClientPhoto>> _groupPhotosBySet(
    List<ClientPhoto> photos,
  ) {
    final Map<ClientPhotoSetType, List<ClientPhoto>> result =
        <ClientPhotoSetType, List<ClientPhoto>>{};
    for (final type in _orderedSets) {
      result[type] = photos
          .where((photo) => photo.setType == type)
          .toList(growable: false);
    }
    return result;
  }

  Widget _buildCanvasSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Anteprima collage', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Expanded(
          child: RepaintBoundary(
            key: _canvasKey,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: _buildCollageCanvas(theme),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 290,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Orientamento', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SegmentedButton<ClientPhotoCollageOrientation>(
                        segments: const [
                          ButtonSegment<ClientPhotoCollageOrientation>(
                            value: ClientPhotoCollageOrientation.horizontal,
                            label: Text('Orizzontale'),
                            icon: Icon(Icons.view_week),
                          ),
                          ButtonSegment<ClientPhotoCollageOrientation>(
                            value: ClientPhotoCollageOrientation.vertical,
                            label: Text('Verticale'),
                            icon: Icon(Icons.view_day),
                          ),
                        ],
                        selected: <ClientPhotoCollageOrientation>{_orientation},
                        onSelectionChanged: (selection) {
                          setState(() => _orientation = selection.first);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch.adaptive(
                            value: _showGuides,
                            onChanged:
                                (value) => setState(() => _showGuides = value),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Mostra griglie di riferimento',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSlotControls(
                  theme,
                  context: context,
                  title: 'Foto A',
                  controller: _primaryController,
                  slot: CollageSelectionSlot.primary,
                ),
                const SizedBox(height: 12),
                _buildSlotControls(
                  theme,
                  context: context,
                  title: 'Foto B',
                  controller: _secondaryController,
                  slot: CollageSelectionSlot.secondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollageCanvas(ThemeData theme) {
    final isVertical = _orientation == ClientPhotoCollageOrientation.vertical;
    final divider = Container(
      color: theme.colorScheme.surfaceVariant,
      width: isVertical ? double.infinity : 12,
      height: isVertical ? 12 : double.infinity,
    );

    final primarySlot = _buildCanvasSlot(
      theme,
      controller: _primaryController,
      slot: CollageSelectionSlot.primary,
      label: 'Foto A',
    );
    final secondarySlot = _buildCanvasSlot(
      theme,
      controller: _secondaryController,
      slot: CollageSelectionSlot.secondary,
      label: 'Foto B',
    );

    return isVertical
        ? Column(
          children: [
            Expanded(child: primarySlot),
            divider,
            Expanded(child: secondarySlot),
          ],
        )
        : Row(
          children: [
            Expanded(child: primarySlot),
            divider,
            Expanded(child: secondarySlot),
          ],
        );
  }

  Widget _buildCanvasSlot(
    ThemeData theme, {
    required _CollageImageController controller,
    required CollageSelectionSlot slot,
    required String label,
  }) {
    final isActive = _activeSlot == slot;
    final borderColor =
        isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    final photo = controller.photo;

    return GestureDetector(
      onTap: () => setState(() => _activeSlot = slot),
      onScaleStart:
          photo == null ? null : (details) => _handleScaleStart(slot, details),
      onScaleUpdate:
          photo == null ? null : (details) => _handleScaleUpdate(slot, details),
      onScaleEnd: photo == null ? null : (_) => _handleScaleEnd(slot),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: theme.colorScheme.surfaceVariant),
              if (photo != null)
                Transform.translate(
                  offset: controller.offset,
                  child: Transform.rotate(
                    angle: controller.rotation * math.pi / 180,
                    child: Transform.scale(
                      scale: controller.scale,
                      child: Image.network(
                        photo.downloadUrl,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                )
              else
                Center(
                  child: Text(
                    'Seleziona $label',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              Positioned(
                top: 8,
                left: 8,
                child: _slotBadge(theme, label: label, isActive: isActive),
              ),
              if (_showGuides)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CollageGuidesPainter(
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotBadge(
    ThemeData theme, {
    required String label,
    required bool isActive,
  }) {
    final color =
        isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceTint.withOpacity(0.6);
    final onColor = theme.colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: onColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSlotControls(
    ThemeData theme, {
    required BuildContext context,
    required String title,
    required _CollageImageController controller,
    required CollageSelectionSlot slot,
  }) {
    final isSelected = controller.photo != null;
    final isActiveSlot = _activeSlot == slot;
    final showControls = isActiveSlot && isSelected;
    final clampedScale =
        controller.scale.clamp(_minScale, _maxScale).toDouble();
    final fileName =
        controller.photo?.fileName?.isNotEmpty ?? false
            ? controller.photo!.fileName!
            : controller.photo?.id;

    final sliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 3,
      overlayShape: SliderComponentShape.noOverlay,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    );
    final compactButtonStyle = OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      textStyle: theme.textTheme.labelSmall,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _activeSlot = slot),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActiveSlot
                    ? Icons.radio_button_checked
                    : Icons.circle_outlined,
                size: 18,
                color:
                    isActiveSlot
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
            ],
          ),
          if (showControls) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCompactSlider(
                    theme: theme,
                    sliderTheme: sliderTheme,
                    label: 'Zoom',
                    valueLabel: '${controller.scale.toStringAsFixed(2)}x',
                    value: clampedScale,
                    min: _minScale,
                    max: _maxScale,
                    onChanged:
                        (value) => setState(() => controller.scale = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCompactSlider(
                    theme: theme,
                    sliderTheme: sliderTheme,
                    label: 'Rotazione',
                    valueLabel: '${controller.rotation.toStringAsFixed(0)}°',
                    value: controller.rotation,
                    min: -180,
                    max: 180,
                    onChanged:
                        (value) => setState(
                          () => controller.rotation = _normalizeAngle(value),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  style: compactButtonStyle,
                  onPressed: () => _snapRotation(slot, 0),
                  child: const Text('0°'),
                ),
                OutlinedButton(
                  style: compactButtonStyle,
                  onPressed: () => _snapRotation(slot, 90),
                  child: const Text('90°'),
                ),
                OutlinedButton(
                  style: compactButtonStyle,
                  onPressed: () => _snapRotation(slot, 180),
                  child: const Text('180°'),
                ),
                OutlinedButton(
                  style: compactButtonStyle,
                  onPressed: () => _snapRotation(slot, -90),
                  child: const Text('-90°'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () => _resetTransform(slot),
                  icon: const Icon(Icons.refresh_outlined, size: 16),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactSlider({
    required ThemeData theme,
    required SliderThemeData sliderTheme,
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const Spacer(),
            Text(
              valueLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: sliderTheme,
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Future<void> _openNoteDialog() async {
    final dialogController = TextEditingController(text: _noteController.text);
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Nota collage'),
            content: TextField(
              controller: dialogController,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Aggiungi una nota opzionale per questo collage',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Salva'),
              ),
            ],
          );
        },
      );
      if (result == true && mounted) {
        setState(() {
          _noteController.text = dialogController.text;
        });
      }
    } finally {
      dialogController.dispose();
    }
  }

  Widget _buildSelectionSection({
    required ThemeData theme,
    required Map<ClientPhotoSetType, List<ClientPhoto>> grouped,
    required List<ClientPhoto> otherPhotos,
  }) {
    final tabs = <Tab>[const Tab(text: 'Tutte')];
    final tabPhotos = <List<ClientPhoto>>[];
    for (final type in _orderedSets) {
      final photos = grouped[type] ?? const <ClientPhoto>[];
      tabs.add(Tab(text: _setLabel(type)));
      tabPhotos.add(photos);
    }
    if (otherPhotos.isNotEmpty) {
      tabs.add(const Tab(text: 'Altre'));
      tabPhotos.add(otherPhotos);
    }

    final allPhotos = ref.watch(clientPhotosProvider(widget.client.id));

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seleziona foto', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<CollageSelectionSlot>(
            segments: const [
              ButtonSegment(
                value: CollageSelectionSlot.primary,
                label: Text('Foto A'),
                icon: Icon(Icons.filter_1),
              ),
              ButtonSegment(
                value: CollageSelectionSlot.secondary,
                label: Text('Foto B'),
                icon: Icon(Icons.filter_2),
              ),
            ],
            selected: <CollageSelectionSlot>{_activeSlot},
            onSelectionChanged: (selection) {
              setState(() => _activeSlot = selection.first);
            },
          ),
          const SizedBox(height: 12),
          TabBar(
            isScrollable: true,
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: tabs,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _buildPhotoGrid(theme, photos: allPhotos),
                for (final photos in tabPhotos)
                  _buildPhotoGrid(theme, photos: photos),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(ThemeData theme, {required List<ClientPhoto> photos}) {
    final ordered = photos.toList(growable: false)
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    if (ordered.isEmpty) {
      return Center(
        child: Text(
          'Nessuna foto disponibile',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    final mediaQuery = MediaQuery.of(context);
    final crossAxisCount = mediaQuery.size.width >= 900 ? 3 : 2;

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 3 / 4,
      ),
      itemCount: ordered.length,
      itemBuilder: (context, index) {
        final photo = ordered[index];
        final isPrimary = _primaryController.photo?.id == photo.id;
        final isSecondary = _secondaryController.photo?.id == photo.id;
        final isSelected = isPrimary || isSecondary;

        final borderColor =
            isPrimary
                ? theme.colorScheme.primary
                : isSecondary
                ? theme.colorScheme.tertiary
                : Colors.transparent;
        final badgeLabel = isPrimary ? 'A' : 'B';
        final badgeColor =
            isPrimary ? theme.colorScheme.primary : theme.colorScheme.tertiary;

        final uploadedLabel = DateFormat(
          'dd/MM/yyyy HH:mm',
        ).format(photo.uploadedAt.toLocal());
        return GestureDetector(
          onTap: () => _selectPhoto(photo),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: theme.colorScheme.surfaceVariant,
                        child: Center(
                          child: Image.network(
                            photo.downloadUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor,
                          width: isSelected ? 3 : 0,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                uploadedLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectPhoto(ClientPhoto photo) {
    setState(() {
      final controller =
          _activeSlot == CollageSelectionSlot.primary
              ? _primaryController
              : _secondaryController;
      controller
        ..photo = photo
        ..resetTransform();
    });
  }

  void _handleScaleStart(CollageSelectionSlot slot, ScaleStartDetails details) {
    final controller =
        slot == CollageSelectionSlot.primary
            ? _primaryController
            : _secondaryController;
    if (controller.photo == null) {
      return;
    }
    if (slot == CollageSelectionSlot.primary) {
      _primaryScaleBase = controller.scale;
      _primaryRotationBase = controller.rotation;
    } else {
      _secondaryScaleBase = controller.scale;
      _secondaryRotationBase = controller.rotation;
    }
  }

  void _handleScaleUpdate(
    CollageSelectionSlot slot,
    ScaleUpdateDetails details,
  ) {
    final controller =
        slot == CollageSelectionSlot.primary
            ? _primaryController
            : _secondaryController;
    if (controller.photo == null) {
      return;
    }
    final baseScale =
        slot == CollageSelectionSlot.primary
            ? _primaryScaleBase ?? controller.scale
            : _secondaryScaleBase ?? controller.scale;
    final baseRotation =
        slot == CollageSelectionSlot.primary
            ? _primaryRotationBase ?? controller.rotation
            : _secondaryRotationBase ?? controller.rotation;

    setState(() {
      controller.offset += details.focalPointDelta;
      controller.scale = (baseScale * details.scale).clamp(
        _minScale,
        _maxScale,
      );
      controller.rotation = _normalizeAngle(
        baseRotation + _radiansToDegrees(details.rotation),
      );
    });
  }

  void _handleScaleEnd(CollageSelectionSlot slot) {
    if (slot == CollageSelectionSlot.primary) {
      _primaryScaleBase = null;
      _primaryRotationBase = null;
    } else {
      _secondaryScaleBase = null;
      _secondaryRotationBase = null;
    }
  }

  void _snapRotation(CollageSelectionSlot slot, double target) {
    setState(() {
      final controller =
          slot == CollageSelectionSlot.primary
              ? _primaryController
              : _secondaryController;
      controller.rotation = target;
    });
  }

  void _resetTransform(CollageSelectionSlot slot) {
    setState(() {
      final controller =
          slot == CollageSelectionSlot.primary
              ? _primaryController
              : _secondaryController;
      controller.resetTransform();
    });
  }

  double _radiansToDegrees(double radians) {
    return radians * 180 / math.pi;
  }

  double _normalizeAngle(double angle) {
    var normalized = angle % 360;
    if (normalized > 180) {
      normalized -= 360;
    }
    if (normalized < -180) {
      normalized += 360;
    }
    return normalized;
  }

  Future<void> _saveCollage() async {
    final primaryPhoto = _primaryController.photo;
    final secondaryPhoto = _secondaryController.photo;
    if (primaryPhoto == null || secondaryPhoto == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona due foto prima di salvare il collage.'),
        ),
      );
      return;
    }

    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anteprima collage non pronta per il salvataggio.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      final ui.Image image = await boundary.toImage(
        pixelRatio: devicePixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Impossibile serializzare il collage.');
      }
      final bytes = byteData.buffer.asUint8List();

      final storage = ref.read(firebaseStorageServiceProvider);
      final dataStore = ref.read(appDataProvider.notifier);
      final session = ref.read(sessionControllerProvider);
      final uploaderId = session.uid ?? 'unknown';
      final collageId = _uuid.v4();
      final upload = await storage.uploadClientCollage(
        salonId: widget.client.salonId,
        clientId: widget.client.id,
        collageId: collageId,
        uploaderId: uploaderId,
        data: bytes,
      );

      final note = _noteController.text.trim();
      final collage = ClientPhotoCollage(
        id: collageId,
        clientId: widget.client.id,
        salonId: widget.client.salonId,
        createdAt: upload.uploadedAt,
        createdBy: uploaderId,
        orientation: _orientation,
        primaryPlacement: ClientPhotoCollagePlacement(
          photoId: primaryPhoto.id,
          offsetX: _primaryController.offset.dx,
          offsetY: _primaryController.offset.dy,
          scale: _primaryController.scale,
          rotationDegrees: _primaryController.rotation,
        ),
        secondaryPlacement: ClientPhotoCollagePlacement(
          photoId: secondaryPhoto.id,
          offsetX: _secondaryController.offset.dx,
          offsetY: _secondaryController.offset.dy,
          scale: _secondaryController.scale,
          rotationDegrees: _secondaryController.rotation,
        ),
        storagePath: upload.storagePath,
        downloadUrl: upload.downloadUrl,
        thumbnailUrl: upload.downloadUrl,
        notes: note.isEmpty ? null : note,
      );

      await dataStore.upsertClientPhotoCollage(collage);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop('Collage salvato correttamente.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvataggio collage non riuscito: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  static const List<ClientPhotoSetType> _orderedSets = <ClientPhotoSetType>[
    ClientPhotoSetType.front,
    ClientPhotoSetType.back,
    ClientPhotoSetType.right,
    ClientPhotoSetType.left,
  ];

  String _setLabel(ClientPhotoSetType type) {
    switch (type) {
      case ClientPhotoSetType.front:
        return 'Frontale';
      case ClientPhotoSetType.back:
        return 'Dietro';
      case ClientPhotoSetType.right:
        return 'Destra';
      case ClientPhotoSetType.left:
        return 'Sinistra';
    }
  }
}

class _CollageGuidesPainter extends CustomPainter {
  _CollageGuidesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 1;

    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CollageGuidesPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
