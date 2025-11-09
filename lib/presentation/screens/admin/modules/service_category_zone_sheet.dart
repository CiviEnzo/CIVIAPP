import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/body_zone.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ServiceCategoryZoneSheet extends ConsumerStatefulWidget {
  const ServiceCategoryZoneSheet({
    super.key,
    required this.category,
    required this.services,
  });

  final ServiceCategory category;
  final List<Service> services;

  static Future<void> show(
    BuildContext context, {
    required ServiceCategory category,
    required List<Service> services,
  }) {
    return showAppModalSheet<void>(
      context: context,
      builder:
          (ctx) =>
              ServiceCategoryZoneSheet(category: category, services: services),
    );
  }

  @override
  ConsumerState<ServiceCategoryZoneSheet> createState() =>
      _ServiceCategoryZoneSheetState();
}

class _ServiceCategoryZoneSheetState
    extends ConsumerState<ServiceCategoryZoneSheet> {
  late Map<String, String> _assignments;
  late List<Service> _categoryServices;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _assignments = Map<String, String>.from(widget.category.zoneServiceIds);
    _categoryServices = _servicesForCategory(widget.category, widget.services);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final frontZones =
        bodyZoneDefinitions.where((zone) => zone.isFront).toList();
    final backZones = bodyZoneDefinitions.where((zone) => zone.isBack).toList();
    final hasServices = _categoryServices.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zone corpo per ${widget.category.name}',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Associa un servizio della categoria ad ogni zona selezionabile.',
                        style: textTheme.bodyMedium,
                      ),
                    ],
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
            const SizedBox(height: 16),
            if (!hasServices)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Crea almeno un servizio per questa categoria prima di associare le zone.',
                    style: textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BodyZoneGroup(
                        title: 'Fronte',
                        zones: frontZones,
                        assignments: _assignments,
                        services: _categoryServices,
                        onAssignmentChanged: _setAssignment,
                      ),
                      const SizedBox(height: 16),
                      _BodyZoneGroup(
                        title: 'Retro',
                        zones: backZones,
                        assignments: _assignments,
                        services: _categoryServices,
                        onAssignmentChanged: _setAssignment,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed:
                      _assignments.isEmpty || _isSaving
                          ? null
                          : () => setState(() {
                            _assignments.clear();
                          }),
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('Pulisci associazioni'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed:
                      hasServices && !_isSaving ? _saveAssignments : null,
                  icon:
                      _isSaving
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save_rounded),
                  label: Text(_isSaving ? 'Salvataggio...' : 'Salva'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _setAssignment(String zoneId, String? serviceId) {
    setState(() {
      if (serviceId == null || serviceId.isEmpty) {
        _assignments.remove(zoneId);
      } else {
        _assignments[zoneId] = serviceId;
      }
    });
  }

  Future<void> _saveAssignments() async {
    setState(() {
      _isSaving = true;
    });
    try {
      final updated = widget.category.copyWith(
        zoneServiceIds: Map<String, String>.from(_assignments),
      );
      await ref.read(appDataProvider.notifier).upsertServiceCategory(updated);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<Service> _servicesForCategory(
    ServiceCategory category,
    List<Service> services,
  ) {
    final filtered =
        services.where((service) {
          if (service.salonId != category.salonId) {
            return false;
          }
          if (service.categoryId != null) {
            return service.categoryId == category.id;
          }
          return service.category.trim().toLowerCase() ==
              category.name.trim().toLowerCase();
        }).toList();
    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
  }
}

class _BodyZoneGroup extends StatelessWidget {
  const _BodyZoneGroup({
    required this.title,
    required this.zones,
    required this.assignments,
    required this.services,
    required this.onAssignmentChanged,
  });

  final String title;
  final List<BodyZoneDefinition> zones;
  final Map<String, String> assignments;
  final List<Service> services;
  final void Function(String zoneId, String? serviceId) onAssignmentChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    if (zones.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...zones.map(
          (zone) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(zone.label, style: textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: assignments[zone.id],
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Servizio associato',
                    ),
                    items: _buildServiceItems(services, assignments[zone.id]),
                    onChanged:
                        services.isEmpty
                            ? null
                            : (value) => onAssignmentChanged(zone.id, value),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String?>> _buildServiceItems(
    List<Service> services,
    String? currentValue,
  ) {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Nessun servizio'),
      ),
    ];
    for (final service in services) {
      items.add(
        DropdownMenuItem<String?>(value: service.id, child: Text(service.name)),
      );
    }
    if (currentValue != null &&
        currentValue.isNotEmpty &&
        services.every((service) => service.id != currentValue)) {
      items.add(
        DropdownMenuItem<String?>(
          value: currentValue,
          child: Text('Servizio non disponibile ($currentValue)'),
        ),
      );
    }
    return items;
  }
}
