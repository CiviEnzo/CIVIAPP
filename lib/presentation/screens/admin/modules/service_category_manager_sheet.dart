import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/service_category.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/service_category_form_sheet.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServiceCategoryManagerSheet extends ConsumerStatefulWidget {
  const ServiceCategoryManagerSheet({
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
      builder:
          (ctx) => ServiceCategoryManagerSheet(
            salons: salons,
            selectedSalonId: selectedSalonId,
          ),
    );
  }

  @override
  ConsumerState<ServiceCategoryManagerSheet> createState() =>
      _ServiceCategoryManagerSheetState();
}

class _ServiceCategoryManagerSheetState
    extends ConsumerState<ServiceCategoryManagerSheet> {
  String? _selectedSalonId;

  @override
  void initState() {
    super.initState();
    _selectedSalonId =
        widget.selectedSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final categories =
        data.serviceCategories
            .where(
              (category) =>
                  _selectedSalonId == null ||
                  category.salonId == _selectedSalonId,
            )
            .sortedByDisplayOrder();
    final servicesForSalon =
        data.services
            .where(
              (service) =>
                  _selectedSalonId == null ||
                  service.salonId == _selectedSalonId,
            )
            .toList();
    final serviceCountByCategoryId = _countServicesByCategory(
      servicesForSalon,
      categories,
    );

    final salonName =
        widget.salons
            .firstWhereOrNull((salon) => salon.id == _selectedSalonId)
            ?.name;

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
                    'Gestione categorie',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Chiudi',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedSalonId == null || salonName == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Nessun salone associato. Apri questa schermata dal salone che vuoi gestire.',
                ),
              )
            else if (categories.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Nessuna categoria configurata per questo salone.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final serviceCount =
                        serviceCountByCategoryId[category.id] ?? 0;
                    return Card(
                      child: ListTile(
                        leading:
                            category.color != null
                                ? _CategoryColorDot(colorValue: category.color!)
                                : null,
                        title: Text(category.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceCount == 1
                                  ? '1 servizio collegato'
                                  : '$serviceCount servizi collegati',
                            ),
                            if (category.description != null &&
                                category.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(category.description!),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Modifica categoria',
                              onPressed: () => _editCategory(category),
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              tooltip: 'Elimina categoria',
                              onPressed:
                                  serviceCount == 0
                                      ? () => _deleteCategory(category)
                                      : null,
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _selectedSalonId == null ? null : _createCategory,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuova categoria'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _countServicesByCategory(
    List<Service> services,
    List<ServiceCategory> categories,
  ) {
    final Map<String, int> counts = {};
    final categoriesBySalonAndName = {
      for (final category in categories)
        '${category.salonId}::${category.name.toLowerCase()}': category.id,
    };
    for (final service in services) {
      String? categoryId = service.categoryId;
      if (categoryId == null || categoryId.isEmpty) {
        final key = '${service.salonId}::${service.category.toLowerCase()}';
        categoryId = categoriesBySalonAndName[key];
      }
      if (categoryId != null) {
        counts[categoryId] = (counts[categoryId] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _createCategory() async {
    final salons = widget.salons;
    if (salons.isEmpty) {
      return;
    }
    final existing =
        ref
            .read(appDataProvider)
            .serviceCategories
            .where((category) => category.salonId == _selectedSalonId)
            .sortedByDisplayOrder();
    final nextSortOrder = existing.isEmpty ? 100 : existing.last.sortOrder + 10;
    final category = await showAppModalSheet<ServiceCategory?>(
      context: context,
      builder:
          (ctx) => ServiceCategoryFormSheet(
            salons: salons,
            initialSalonId: _selectedSalonId,
            initialSortOrder: nextSortOrder,
          ),
    );
    if (category == null) {
      return;
    }
    try {
      await ref.read(appDataProvider.notifier).upsertServiceCategory(category);
    } on StateError catch (error) {
      if (!mounted) return;
      final message =
          error.message == 'permission-denied'
              ? 'Non hai i permessi per creare categorie in questo salone.'
              : 'Errore durante il salvataggio della categoria: ${error.message}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Categoria "${category.name}" salvata.')),
    );
  }

  Future<void> _editCategory(ServiceCategory category) async {
    final salons = widget.salons;
    final updated = await showAppModalSheet<ServiceCategory?>(
      context: context,
      builder:
          (ctx) => ServiceCategoryFormSheet(
            salons: salons,
            initial: category,
            initialSalonId: category.salonId,
            initialSortOrder: category.sortOrder,
          ),
    );
    if (updated == null) {
      return;
    }
    try {
      await ref.read(appDataProvider.notifier).upsertServiceCategory(updated);
    } on StateError catch (error) {
      if (!mounted) return;
      final message =
          error.message == 'permission-denied'
              ? 'Non hai i permessi per modificare questa categoria.'
              : 'Errore durante il salvataggio della categoria: ${error.message}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Categoria "${updated.name}" aggiornata.')),
    );
  }

  Future<void> _deleteCategory(ServiceCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Elimina categoria'),
            content: Text(
              'Vuoi eliminare "${category.name}"? Questa operazione non può essere annullata.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Elimina'),
              ),
            ],
          ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(appDataProvider.notifier)
          .deleteServiceCategory(category.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Categoria "${category.name}" eliminata.')),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      String message;
      if (error.message == 'category-in-use') {
        message =
            'Impossibile eliminare la categoria perché ci sono servizi collegati.';
      } else if (error.message == 'permission-denied') {
        message = 'Non hai i permessi per eliminare questa categoria.';
      } else {
        message = 'Errore durante l\'eliminazione della categoria.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _CategoryColorDot extends StatelessWidget {
  const _CategoryColorDot({required this.colorValue});

  final int colorValue;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    );
  }
}
