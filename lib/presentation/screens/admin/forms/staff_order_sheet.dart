import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StaffOrderSheet extends ConsumerStatefulWidget {
  const StaffOrderSheet({
    super.key,
    required this.salons,
    this.selectedSalonId,
  });

  final List<Salon> salons;
  final String? selectedSalonId;

  static Future<void> show(
    BuildContext context, {
    required List<Salon> salons,
    String? selectedSalonId,
  }) {
    return showAppModalSheet<void>(
      context: context,
      includeCloseButton: false,
      builder:
          (ctx) =>
              StaffOrderSheet(salons: salons, selectedSalonId: selectedSalonId),
    );
  }

  @override
  ConsumerState<StaffOrderSheet> createState() => _StaffOrderSheetState();
}

class _StaffOrderSheetState extends ConsumerState<StaffOrderSheet> {
  String? _selectedSalonId;
  String? _lastLoadedSalonId;
  List<StaffMember> _orderedStaff = const [];
  bool _hasLocalChanges = false;
  bool _isSaving = false;
  ProviderSubscription<AppDataState>? _appDataSubscription;

  @override
  void initState() {
    super.initState();
    final providedSalonId = widget.selectedSalonId;
    String? initialSalonId;
    if (providedSalonId != null &&
        widget.salons.any((salon) => salon.id == providedSalonId)) {
      initialSalonId = providedSalonId;
    } else {
      initialSalonId = widget.salons.firstOrNull?.id;
    }
    _selectedSalonId = initialSalonId;
    _initializeFromState(ref.read(appDataProvider));
    _appDataSubscription = ref.listenManual<AppDataState>(
      appDataProvider,
      (_, next) => _initializeFromState(next),
    );
  }

  @override
  void dispose() {
    _appDataSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = ref.watch(appDataProvider);
    final rolesById = {for (final role in data.staffRoles) role.id: role};
    final salons = widget.salons;
    final selectedSalon = salons.firstWhereOrNull(
      (salon) => salon.id == _selectedSalonId,
    );

    final hasSalonSelection = selectedSalon != null;
    final canSave = _hasLocalChanges && _orderedStaff.isNotEmpty && !_isSaving;
    final listHeight = (_orderedStaff.length * 68).clamp(220, 480).toDouble();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ordine dello staff',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Chiudi',
                  onPressed:
                      _isSaving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasSalonSelection)
              Card(
                color: _blendSurfaceTowardsWhite(context, 0.92),
                elevation: 1.5,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Non è possibile ordinare il team finché non è associato un salone.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else if (_orderedStaff.isEmpty)
              Card(
                color: _blendSurfaceTowardsWhite(context, 0.92),
                elevation: 1.5,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Non ci sono membri dello staff da ordinare per questo salone.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Card(
                color: _blendSurfaceTowardsWhite(context, 0.9),
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: listHeight,
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: _orderedStaff.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final member = _orderedStaff[index];
                      final roleName =
                          rolesById[member.primaryRoleId]?.name ??
                          'Ruolo non assegnato';
                      final initials =
                          member.fullName.isNotEmpty
                              ? member.fullName
                                  .trim()
                                  .split(RegExp(r'\s+'))
                                  .map(
                                    (part) => part.characters.firstOrNull ?? '',
                                  )
                                  .take(2)
                                  .join()
                                  .toUpperCase()
                              : '?';
                      return Card(
                        key: ValueKey(member.id),
                        color: _blendSurfaceTowardsWhite(context, 0.96),
                        elevation: 1,
                        shadowColor: Colors.black.withValues(alpha: 0.06),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(child: Text(initials)),
                          title: Text(member.fullName),
                          subtitle: Text(roleName),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annulla'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: canSave ? _saveOrder : null,
                  child:
                      _isSaving
                          ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Salva ordine'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _initializeFromState(AppDataState data, {bool force = false}) {
    final selectedSalonId = _selectedSalonId;
    if (selectedSalonId == null) {
      if (_orderedStaff.isNotEmpty || _lastLoadedSalonId != null) {
        setState(() {
          _orderedStaff = const [];
          _lastLoadedSalonId = null;
          _hasLocalChanges = false;
        });
      }
      return;
    }
    if (_hasLocalChanges && !force) {
      return;
    }
    final updatedStaff =
        data.staff
            .where((member) => member.salonId == selectedSalonId)
            .sortedByDisplayOrder();
    final currentIds = _orderedStaff.map((member) => member.id).toList();
    final newIds = updatedStaff.map((member) => member.id).toList();
    if (!force &&
        _lastLoadedSalonId == selectedSalonId &&
        listEquals(currentIds, newIds)) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _orderedStaff = updatedStaff;
      _lastLoadedSalonId = selectedSalonId;
      _hasLocalChanges = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (_isSaving) {
      return;
    }
    setState(() {
      var targetIndex = newIndex;
      if (targetIndex > oldIndex) {
        targetIndex -= 1;
      }
      final moved = _orderedStaff.removeAt(oldIndex);
      _orderedStaff.insert(targetIndex, moved);
      _hasLocalChanges = true;
    });
  }

  Future<void> _saveOrder() async {
    final salonId = _selectedSalonId;
    if (salonId == null || _orderedStaff.isEmpty) {
      return;
    }
    setState(() => _isSaving = true);
    final ids = _orderedStaff.map((member) => member.id).toList();
    try {
      await ref
          .read(appDataProvider.notifier)
          .reorderStaff(salonId: salonId, orderedIds: ids);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile salvare l\'ordine dello staff. Riprova.'),
        ),
      );
    }
  }
}

Color _blendSurfaceTowardsWhite(BuildContext context, double whiteOpacity) {
  final normalized = whiteOpacity.clamp(0.0, 1.0);
  final scheme = Theme.of(context).colorScheme;
  return Color.alphaBlend(
    Colors.white.withValues(alpha: normalized),
    scheme.surface,
  );
}
