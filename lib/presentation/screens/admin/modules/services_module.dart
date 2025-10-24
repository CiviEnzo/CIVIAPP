import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/staff_role.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/package_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/service_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/modules/service_category_manager_sheet.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

Color _layerColor(ThemeData theme, int depth) {
  final scheme = theme.colorScheme;
  switch (depth) {
    case 0:
      return scheme.surfaceContainerLowest;
    case 1:
      return scheme.surfaceContainerLow;
    case 2:
      return scheme.surfaceContainer;
    case 3:
      return scheme.surfaceContainerHigh;
    default:
      return scheme.surfaceContainerHighest;
  }
}

double _baseCardElevation(ThemeData theme) {
  final brightness = theme.brightness;
  return theme.cardTheme.elevation ?? (brightness == Brightness.dark ? 6 : 2);
}

Color _shadowColor(
  ThemeData theme, {
  required double lightOpacity,
  required double darkOpacity,
}) {
  final isDark = theme.brightness == Brightness.dark;
  return Colors.black.withOpacity(isDark ? darkOpacity : lightOpacity);
}

class ServicesModule extends ConsumerWidget {
  const ServicesModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final session = ref.watch(sessionControllerProvider);
    final salons = data.salons;
    final staffRoles = data.staffRoles;
    final services =
        data.services
            .where((service) => salonId == null || service.salonId == salonId)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final filteredCategories =
        (salonId == null
                ? data.serviceCategories
                : data.serviceCategories.where(
                  (category) => category.salonId == salonId,
                ))
            .sortedByDisplayOrder();
    final activeServices = services
        .where((service) => service.isActive)
        .toList(growable: false);
    final inactiveServices = services
        .where((service) => !service.isActive)
        .toList(growable: false);
    final isAdmin = session.role == UserRole.admin;
    final categoriesAction =
        isAdmin && salons.isNotEmpty
            ? OutlinedButton.icon(
              onPressed:
                  () => _openCategoriesManager(
                    context,
                    ref,
                    salons: salons,
                    selectedSalonId: salonId ?? session.salonId,
                  ),
              icon: const Icon(Icons.category_rounded),
              label: const Text('Gestione categorie'),
            )
            : null;
    final packages =
        data.packages
            .where((pkg) => salonId == null || pkg.salonId == salonId)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = colorScheme.secondary;
    final moduleBackground = colorScheme.surfaceContainerLowest;
    final sectionBackground = _layerColor(theme, 1);
    final groupCardBackground = _layerColor(theme, 2);
    final serviceCardBackground = _layerColor(theme, 2);
    final packageCardBackground = _layerColor(theme, 2);
    final strongShadowColor = _shadowColor(
      theme,
      lightOpacity: 0.12,
      darkOpacity: 0.65,
    );
    final mediumShadowColor = _shadowColor(
      theme,
      lightOpacity: 0.08,
      darkOpacity: 0.48,
    );
    final sectionShadowColor = mediumShadowColor;
    final groupShadowColor = mediumShadowColor;
    final serviceShadowColor = mediumShadowColor;
    final packageShadowColor = strongShadowColor;
    final baseElevation = _baseCardElevation(theme);
    final double tabElevation = baseElevation;
    final double sectionElevation = baseElevation;
    final double groupElevation = baseElevation + 2;
    final double serviceElevation = baseElevation + (isDark ? 0 : 1);
    final double packageElevation = baseElevation + (isDark ? 8 : 4);

    return DefaultTabController(
      length: 2,
      child: Container(
        color: moduleBackground,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Servizi',
              subtitle: '${activeServices.length} servizi attivi',
              actionLabel: 'Nuovo servizio',
              onActionPressed:
                  () => _openServiceForm(
                    context,
                    ref,
                    salons: salons,
                    roles: staffRoles,
                    categories: data.serviceCategories,
                    defaultSalonId: salonId,
                  ),
              secondaryAction: categoriesAction,
            ),
            const SizedBox(height: 12),
            Material(
              color: sectionBackground,
              elevation: tabElevation,
              shadowColor: sectionShadowColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: accentColor.withOpacity(0.18)),
              ),
              clipBehavior: Clip.antiAlias,
              child: TabBar(
                labelColor: accentColor,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant
                    .withOpacity(0.7),
                indicatorColor: accentColor,
                tabs: [
                  Tab(text: 'Attivi (${activeServices.length})'),
                  Tab(text: 'Disattivati (${inactiveServices.length})'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (activeServices.isEmpty)
                        Card(
                          color: sectionBackground,
                          elevation: sectionElevation,
                          shadowColor: sectionShadowColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const ListTile(
                            title: Text('Nessun servizio attivo disponibile'),
                          ),
                        )
                      else
                        _ServicesList(
                          services: activeServices,
                          salons: salons,
                          categories: filteredCategories,
                          selectedSalonId: salonId,
                          groupCardColor: groupCardBackground,
                          groupCardElevation: groupElevation,
                          groupShadowColor: groupShadowColor,
                          serviceCardColor: serviceCardBackground,
                          serviceCardElevation: serviceElevation,
                          serviceShadowColor: serviceShadowColor,
                          onEdit:
                              (service) => _openServiceForm(
                                context,
                                ref,
                                salons: salons,
                                roles: staffRoles,
                                categories: data.serviceCategories,
                                defaultSalonId: salonId,
                                existing: service,
                              ),
                          onDelete:
                              (service) =>
                                  _confirmDeleteService(context, ref, service),
                          onToggleActive:
                              (service, next) => _toggleServiceActivation(
                                context,
                                ref,
                                service: service,
                                isActive: next,
                              ),
                        ),
                      const SizedBox(height: 24),
                      _SectionHeader(
                        title: 'Pacchetti',
                        subtitle: '${packages.length} pacchetti attivi',
                        actionLabel: 'Nuovo pacchetto',
                        onActionPressed:
                            () => _openPackageForm(
                              context,
                              ref,
                              salons: salons,
                              services: data.services,
                              defaultSalonId: salonId,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (packages.isEmpty)
                        Card(
                          color: sectionBackground,
                          elevation: sectionElevation,
                          shadowColor: sectionShadowColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const ListTile(
                            title: Text('Nessun pacchetto configurato'),
                          ),
                        )
                      else
                        _PackagesList(
                          packages: packages,
                          services: data.services,
                          salons: salons,
                          selectedSalonId: salonId,
                          cardColor: packageCardBackground,
                          cardElevation: packageElevation,
                          shadowColor: packageShadowColor,
                          onEdit:
                              (pkg) => _openPackageForm(
                                context,
                                ref,
                                salons: salons,
                                services: data.services,
                                defaultSalonId: salonId,
                                existing: pkg,
                              ),
                          onDelete:
                              (pkg) => _confirmDeletePackage(context, ref, pkg),
                        ),
                    ],
                  ),
                  ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (inactiveServices.isEmpty)
                        Card(
                          color: sectionBackground,
                          elevation: sectionElevation,
                          shadowColor: sectionShadowColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            title: const Text('Nessun servizio disattivato'),
                            subtitle: const Text(
                              'Disattiva un servizio attivo per trovarlo qui.',
                            ),
                            trailing: const Icon(Icons.info_outline_rounded),
                          ),
                        )
                      else
                        _ServicesList(
                          services: inactiveServices,
                          salons: salons,
                          categories: filteredCategories,
                          selectedSalonId: salonId,
                          groupCardColor: groupCardBackground,
                          groupCardElevation: groupElevation,
                          groupShadowColor: groupShadowColor,
                          serviceCardColor: serviceCardBackground,
                          serviceCardElevation: serviceElevation,
                          serviceShadowColor: serviceShadowColor,
                          onEdit:
                              (service) => _openServiceForm(
                                context,
                                ref,
                                salons: salons,
                                roles: staffRoles,
                                categories: data.serviceCategories,
                                defaultSalonId: salonId,
                                existing: service,
                              ),
                          onDelete:
                              (service) =>
                                  _confirmDeleteService(context, ref, service),
                          onToggleActive:
                              (service, next) => _toggleServiceActivation(
                                context,
                                ref,
                                service: service,
                                isActive: next,
                              ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleServiceActivation(
    BuildContext context,
    WidgetRef ref, {
    required Service service,
    required bool isActive,
  }) async {
    final updated = service.copyWith(isActive: isActive);
    await ref.read(appDataProvider.notifier).upsertService(updated);
    if (!context.mounted) {
      return;
    }
    final label =
        isActive ? 'Servizio riattivato.' : 'Servizio disattivato e nascosto.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }

  Future<void> _confirmDeleteService(
    BuildContext context,
    WidgetRef ref,
    Service service,
  ) async {
    final appData = ref.read(appDataProvider);
    final blockingAppointments = appData.appointments
        .where((appointment) => appointment.serviceIds.contains(service.id))
        .toList(growable: false);
    if (blockingAppointments.isNotEmpty) {
      final count = blockingAppointments.length;
      final label =
          count == 1
              ? '1 appuntamento pianificato o registrato.'
              : '$count appuntamenti pianificati o registrati.';
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Eliminazione non consentita'),
              content: Text(
                '"${service.name}" è ancora collegato a $label\n'
                'Disattiva il servizio per impedirne la prenotazione, oppure riassegna gli appuntamenti ad altri trattamenti.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }
    final blockingPackages = appData.packages
        .where((pkg) => pkg.serviceIds.contains(service.id))
        .toList(growable: false);
    if (blockingPackages.isNotEmpty) {
      final packageNames = blockingPackages.map((pkg) => pkg.name).toList();
      final displayedNames = packageNames.take(3).join(', ');
      final remainingCount = packageNames.length - 3;
      final messageBuffer = StringBuffer(
        'Non è possibile eliminare "${service.name}" perché è incluso ',
      );
      messageBuffer.write(
        packageNames.length == 1
            ? 'nel pacchetto "$displayedNames".'
            : 'nei pacchetti "$displayedNames"',
      );
      if (remainingCount > 0) {
        messageBuffer.write(' e in altri $remainingCount.');
      } else {
        messageBuffer.write('.');
      }

      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Eliminazione non consentita'),
              content: Text(messageBuffer.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Elimina servizio'),
            content: Text(
              'Vuoi eliminare "${service.name}"?\n'
              'Il servizio verrà rimosso dai pacchetti esistenti e gli appuntamenti collegati saranno eliminati.',
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
      await ref.read(appDataProvider.notifier).deleteService(service.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${service.name} eliminato.')));
      }
    } on StateError catch (error) {
      if (!context.mounted) return;
      var friendly = 'Eliminazione non consentita: ${error.message}';
      if (error.message == 'service-in-appointments') {
        friendly =
            'Impossibile eliminare il servizio: è ancora collegato ad alcuni appuntamenti.';
      } else if (error.message == 'service-in-packages') {
        friendly =
            'Impossibile eliminare il servizio perché è incluso in uno o più pacchetti.';
      } else if (error.message == 'permission-denied') {
        friendly =
            'Non hai i permessi per eliminare questo servizio. Contatta un amministratore.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendly)));
    }
  }

  Future<void> _openServiceForm(
    BuildContext context,
    WidgetRef ref, {
    required List<Salon> salons,
    required List<StaffRole> roles,
    required List<ServiceCategory> categories,
    String? defaultSalonId,
    Service? existing,
  }) async {
    if (salons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crea un salone prima di configurare i servizi.'),
        ),
      );
      return;
    }
    final result = await showAppModalSheet<Service>(
      context: context,
      builder:
          (ctx) => ServiceFormSheet(
            salons: salons,
            roles: roles,
            categories: categories,
            defaultSalonId: defaultSalonId,
            initial: existing,
          ),
    );
    if (result != null) {
      await ref.read(appDataProvider.notifier).upsertService(result);
    }
  }

  Future<void> _openCategoriesManager(
    BuildContext context,
    WidgetRef ref, {
    required List<Salon> salons,
    String? selectedSalonId,
  }) async {
    if (salons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crea un salone prima di gestire le categorie.'),
        ),
      );
      return;
    }

    await ServiceCategoryManagerSheet.show(
      context,
      salons: salons,
      selectedSalonId: selectedSalonId,
    );
  }

  Future<void> _openPackageForm(
    BuildContext context,
    WidgetRef ref, {
    required List<Salon> salons,
    required List<Service> services,
    String? defaultSalonId,
    ServicePackage? existing,
  }) async {
    if (salons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crea un salone prima di configurare i pacchetti.'),
        ),
      );
      return;
    }
    final result = await showAppModalSheet<ServicePackage>(
      context: context,
      builder:
          (ctx) => PackageFormSheet(
            salons: salons,
            services: services,
            defaultSalonId: defaultSalonId,
            initial: existing,
          ),
    );
    if (result != null) {
      await ref.read(appDataProvider.notifier).upsertPackage(result);
    }
  }

  Future<void> _confirmDeletePackage(
    BuildContext context,
    WidgetRef ref,
    ServicePackage package,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Elimina pacchetto'),
            content: Text(
              'Vuoi eliminare "${package.name}"?\nIl pacchetto non sarà più disponibile per la vendita.',
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

    await ref.read(appDataProvider.notifier).deletePackage(package.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${package.name} eliminato.')));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onActionPressed,
    this.secondaryAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onActionPressed;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
        if (secondaryAction != null) ...[
          secondaryAction!,
          const SizedBox(width: 12),
        ],
        FilledButton.icon(
          onPressed: onActionPressed,
          icon: const Icon(Icons.add_rounded),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _ServicesList extends StatefulWidget {
  const _ServicesList({
    required this.services,
    required this.salons,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.groupCardColor,
    required this.groupCardElevation,
    required this.groupShadowColor,
    required this.serviceCardColor,
    required this.serviceCardElevation,
    required this.serviceShadowColor,
    this.selectedSalonId,
  });

  final List<Service> services;
  final List<Salon> salons;
  final List<ServiceCategory> categories;
  final ValueChanged<Service> onEdit;
  final ValueChanged<Service> onDelete;
  final void Function(Service service, bool isActive) onToggleActive;
  final Color groupCardColor;
  final double groupCardElevation;
  final Color groupShadowColor;
  final Color serviceCardColor;
  final double serviceCardElevation;
  final Color serviceShadowColor;
  final String? selectedSalonId;

  @override
  State<_ServicesList> createState() => _ServicesListState();
}

class _ServicesListState extends State<_ServicesList> {
  final Set<String> _expandedGroupIds = <String>{};
  String? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.secondary;
    final groups = _buildGroups();
    final groupIds = groups.map((group) => group.id).toSet();
    _expandedGroupIds.retainAll(groupIds);
    if (_selectedGroupId != null && !groupIds.contains(_selectedGroupId)) {
      _selectedGroupId = null;
    }

    final serviceSalonIds =
        widget.services.map((service) => service.salonId).toSet();
    final bool showSalonChip =
        widget.selectedSalonId == null && serviceSalonIds.length > 1;
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final selectedGroupId = _selectedGroupId;
    final visibleGroups =
        selectedGroupId == null
            ? groups
            : groups.where((group) => group.id == selectedGroupId).toList();
    final showFilterCard = groups.length > 1;

    final children = <Widget>[];
    if (showFilterCard) {
      children.add(_buildCategoryFilterCard(context, groups, accentColor));
      children.add(const SizedBox(height: 12));
    }

    if (visibleGroups.isEmpty) {
      children.add(
        Card(
          color: _layerColor(theme, 1),
          elevation: widget.groupCardElevation,
          shadowColor: widget.groupShadowColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accentColor.withOpacity(0.12)),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nessun servizio disponibile per questa categoria.'),
          ),
        ),
      );
    } else {
      for (var i = 0; i < visibleGroups.length; i++) {
        final group = visibleGroups[i];
        final isExpanded = _expandedGroupIds.contains(group.id);
        final serviceCountLabel =
            group.services.isEmpty
                ? 'Nessun servizio'
                : group.services.length == 1
                ? '1 servizio'
                : '${group.services.length} servizi';
        final tileChildren = <Widget>[];
        if (group.services.isEmpty) {
          tileChildren.add(
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('Nessun servizio in questa categoria.'),
            ),
          );
        } else {
          for (var j = 0; j < group.services.length; j++) {
            final service = group.services[j];
            tileChildren.add(
              _buildServiceCard(
                context,
                service,
                group.salon,
                currency,
                showSalonChip,
              ),
            );
            if (j < group.services.length - 1) {
              tileChildren.add(const SizedBox(height: 12));
            }
          }
        }

        children.add(
          Card(
            color: widget.groupCardColor,
            elevation: widget.groupCardElevation,
            shadowColor: widget.groupShadowColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: accentColor.withOpacity(0.16)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey(group.id),
                leading: Icon(
                  group.category != null
                      ? Icons.category_rounded
                      : Icons.label_outline_rounded,
                  color: accentColor,
                ),
                maintainState: true,
                initiallyExpanded: isExpanded,
                title: Text(group.title),
                subtitle: Text(serviceCountLabel),
                onExpansionChanged: (expanded) {
                  setState(() {
                    if (expanded) {
                      _expandedGroupIds.add(group.id);
                    } else {
                      _expandedGroupIds.remove(group.id);
                    }
                  });
                },
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: tileChildren,
              ),
            ),
          ),
        );
        if (i < visibleGroups.length - 1) {
          children.add(const SizedBox(height: 12));
        }
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildCategoryFilterCard(
    BuildContext context,
    List<_ServiceGroup> groups,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final descriptionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final chips = _buildCategoryFilterChips(context, groups, accentColor);

    return Card(
      color: _layerColor(theme, 1),
      elevation: widget.groupCardElevation,
      shadowColor: widget.groupShadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard_customize_rounded, color: accentColor),
                const SizedBox(width: 8),
                Text('Categorie', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Seleziona una categoria per filtrare rapidamente l\'elenco.',
              style: descriptionStyle,
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategoryFilterChips(
    BuildContext context,
    List<_ServiceGroup> groups,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final baseOpacity = brightness == Brightness.dark ? 0.22 : 0.08;
    final selectedOpacity = brightness == Brightness.dark ? 0.36 : 0.2;

    final entries = <({String? id, String label, int count, IconData icon})>[
      (
        id: null,
        label: 'Tutti i servizi',
        count: widget.services.length,
        icon: Icons.grid_view_rounded,
      ),
      ...groups.map(
        (group) => (
          id: group.id,
          label: group.title,
          count: group.services.length,
          icon:
              group.category != null
                  ? Icons.category_rounded
                  : Icons.label_outline_rounded,
        ),
      ),
    ];

    return entries.map((entry) {
      final isSelected =
          entry.id == null
              ? _selectedGroupId == null
              : _selectedGroupId == entry.id;
      final label =
          entry.count == 0 ? entry.label : '${entry.label} (${entry.count})';
      final textColor =
          isSelected
              ? theme.colorScheme.onSecondaryContainer
              : theme.colorScheme.onSurface;

      return FilterChip(
        selected: isSelected,
        onSelected: (selected) => _handleGroupSelection(entry.id, selected),
        showCheckmark: false,
        backgroundColor: accentColor.withOpacity(baseOpacity),
        selectedColor: accentColor.withOpacity(selectedOpacity),
        side: BorderSide(
          color: accentColor.withOpacity(isSelected ? 0.5 : 0.18),
        ),
        avatar: Icon(entry.icon, size: 18, color: accentColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: const StadiumBorder(),
        label: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      );
    }).toList();
  }

  void _handleGroupSelection(String? groupId, bool isSelected) {
    setState(() {
      if (groupId == null) {
        _selectedGroupId = null;
        _expandedGroupIds.clear();
        return;
      }
      if (isSelected) {
        _selectedGroupId = groupId;
        _expandedGroupIds
          ..clear()
          ..add(groupId);
      } else {
        _selectedGroupId = null;
        _expandedGroupIds.clear();
      }
    });
  }

  List<_ServiceGroup> _buildGroups() {
    final salonsById = {for (final salon in widget.salons) salon.id: salon};
    final categoriesById = {
      for (final category in widget.categories) category.id: category,
    };

    final Map<String, List<Service>> servicesByCategory = {};
    final Map<String, List<Service>> uncategorizedBySalon = {};

    for (final service in widget.services) {
      ServiceCategory? category;
      final categoryId = service.categoryId;
      if (categoryId != null) {
        category = categoriesById[categoryId];
      }
      category ??= widget.categories.firstWhereOrNull(
        (candidate) =>
            candidate.salonId == service.salonId &&
            candidate.name.toLowerCase() == service.category.toLowerCase(),
      );
      if (category != null) {
        servicesByCategory
            .putIfAbsent(category.id, () => <Service>[])
            .add(service);
      } else {
        final key = 'uncategorized-${service.salonId}';
        uncategorizedBySalon.putIfAbsent(key, () => <Service>[]).add(service);
      }
    }

    final bool multiSalonContext =
        widget.selectedSalonId == null &&
        widget.services.map((service) => service.salonId).toSet().length > 1;

    final groups = <_ServiceGroup>[];
    final sortedCategories = widget.categories.sortedByDisplayOrder();
    for (final category in sortedCategories) {
      final services = List<Service>.from(
        servicesByCategory[category.id] ?? const <Service>[],
      )..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (services.isEmpty) {
        continue;
      }
      final salon = salonsById[category.salonId];
      final title =
          multiSalonContext && salon != null
              ? '${category.name} • ${salon.name}'
              : category.name;
      groups.add(
        _ServiceGroup(
          id: category.id,
          title: title,
          services: services,
          salonId: category.salonId,
          category: category,
          salon: salon,
        ),
      );
    }

    final uncategorizedKeys = uncategorizedBySalon.keys.toList()..sort();
    for (final key in uncategorizedKeys) {
      final services = List<Service>.from(uncategorizedBySalon[key]!)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final salonId = key.replaceFirst('uncategorized-', '');
      final salon = salonsById[salonId];
      final title =
          multiSalonContext && salon != null
              ? 'Senza categoria • ${salon.name}'
              : 'Senza categoria';
      groups.add(
        _ServiceGroup(
          id: key,
          title: title,
          services: services,
          salonId: salonId.isEmpty ? null : salonId,
          salon: salon,
        ),
      );
    }

    return groups;
  }

  Widget _buildServiceCard(
    BuildContext context,
    Service service,
    Salon? salon,
    NumberFormat currency,
    bool showSalonChip,
  ) {
    final equipmentNames =
        service.requiredEquipmentIds.map((id) {
          final match = salon?.equipment.firstWhereOrNull(
            (equipment) => equipment.id == id,
          );
          return match?.name ?? id;
        }).toList();

    final chips = <Widget>[];
    if (showSalonChip && salon != null) {
      chips.add(_InfoChip(icon: Icons.storefront_rounded, label: salon.name));
    }
    chips.addAll([
      _InfoChip(icon: Icons.category_rounded, label: service.category),
      _InfoChip(
        icon: Icons.timer_rounded,
        label: 'Totale ${service.totalDuration.inMinutes} min',
      ),
      if (service.extraDuration > Duration.zero)
        _InfoChip(
          icon: Icons.hourglass_bottom_rounded,
          label: '+${service.extraDuration.inMinutes} min extra',
        ),
      _InfoChip(
        icon: Icons.euro_rounded,
        label: currency.format(service.price),
      ),
    ]);

    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.secondary;

    return Card(
      color: widget.serviceCardColor,
      elevation: widget.serviceCardElevation,
      shadowColor: widget.serviceShadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accentColor.withOpacity(0.12)),
      ),
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        title: Text(service.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service.description ?? 'Nessuna descrizione'),
            const SizedBox(height: 6),
            Wrap(spacing: 12, runSpacing: 6, children: chips),
            if (equipmentNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    equipmentNames
                        .map(
                          (name) => Chip(
                            avatar: const Icon(
                              Icons.precision_manufacturing_rounded,
                              size: 18,
                            ),
                            label: Text(name),
                          ),
                        )
                        .toList(),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Modifica servizio',
              onPressed: () => widget.onEdit(service),
              icon: Icon(Icons.edit_rounded, color: accentColor),
            ),
            IconButton(
              tooltip:
                  service.isActive ? 'Disattiva servizio' : 'Riattiva servizio',
              onPressed:
                  () => widget.onToggleActive(service, !service.isActive),
              icon: Icon(
                service.isActive
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: accentColor,
              ),
            ),
            IconButton(
              tooltip: 'Elimina servizio',
              onPressed: () => widget.onDelete(service),
              icon: Icon(Icons.delete_outline_rounded, color: accentColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceGroup {
  const _ServiceGroup({
    required this.id,
    required this.title,
    required this.services,
    required this.salonId,
    this.category,
    this.salon,
  });

  final String id;
  final String title;
  final List<Service> services;
  final String? salonId;
  final ServiceCategory? category;
  final Salon? salon;
}

class _PackagesList extends StatefulWidget {
  const _PackagesList({
    required this.packages,
    required this.services,
    required this.salons,
    this.selectedSalonId,
    required this.onEdit,
    required this.onDelete,
    required this.cardColor,
    required this.cardElevation,
    required this.shadowColor,
  });

  final List<ServicePackage> packages;
  final List<Service> services;
  final List<Salon> salons;
  final String? selectedSalonId;
  final ValueChanged<ServicePackage> onEdit;
  final ValueChanged<ServicePackage> onDelete;
  final Color cardColor;
  final double cardElevation;
  final Color shadowColor;

  @override
  State<_PackagesList> createState() => _PackagesListState();
}

class _PackagesListState extends State<_PackagesList> {
  String? _salonFilter;
  bool _onlyDiscounted = false;

  @override
  void initState() {
    super.initState();
    _salonFilter = widget.selectedSalonId;
  }

  @override
  void didUpdateWidget(covariant _PackagesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSalonId != oldWidget.selectedSalonId &&
        widget.selectedSalonId != _salonFilter) {
      _salonFilter = widget.selectedSalonId;
    }
    if (_salonFilter != null &&
        !widget.packages.any((pkg) => pkg.salonId == _salonFilter)) {
      _salonFilter = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.secondary;
    final salonsById = {for (final salon in widget.salons) salon.id: salon};
    final salonIdsInPackages =
        widget.packages.map((pkg) => pkg.salonId).toSet();
    final hasMultipleSalons = salonIdsInPackages.length > 1;
    final hasDiscountedPackages = widget.packages.any(
      (pkg) => _effectiveDiscount(pkg) != null,
    );
    final filteredPackages = _applyFilters();

    final filterCard = _buildFilterCard(
      context,
      accentColor,
      salonsById,
      salonIdsInPackages,
      hasMultipleSalons,
      hasDiscountedPackages,
    );

    final children = <Widget>[];
    if (filterCard != null) {
      children.add(filterCard);
      children.add(const SizedBox(height: 12));
    }

    if (filteredPackages.isEmpty) {
      children.add(
        Card(
          color: _layerColor(theme, 1),
          elevation: widget.cardElevation,
          shadowColor: widget.shadowColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accentColor.withOpacity(0.12)),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nessun pacchetto corrisponde ai filtri selezionati.'),
          ),
        ),
      );
    } else {
      children.add(
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth =
                constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.of(context).size.width;
            const spacing = 16.0;
            const desiredTileWidth = 360.0;
            var columns =
                (availableWidth / (desiredTileWidth + spacing)).floor();
            if (columns < 1) {
              columns = 1;
            } else if (columns > 4) {
              columns = 4;
            }
            final effectiveWidth =
                columns == 1
                    ? availableWidth
                    : (availableWidth - spacing * (columns - 1)) / columns;
            final showSalonBadge = hasMultipleSalons;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children:
                  filteredPackages.map((pkg) {
                    final discount = _effectiveDiscount(pkg);
                    final salon = salonsById[pkg.salonId];
                    final salonName = salon?.name;
                    return SizedBox(
                      width: effectiveWidth,
                      child: Card(
                        color: widget.cardColor,
                        elevation: widget.cardElevation,
                        shadowColor: widget.shadowColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: accentColor.withOpacity(0.16),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pkg.name,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                        ),
                                        if (pkg.description != null) ...[
                                          const SizedBox(height: 4),
                                          Text(pkg.description!),
                                        ],
                                        if (showSalonBadge && salonName != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: _InfoChip(
                                              icon: Icons.storefront_rounded,
                                              label: salonName,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Modifica pacchetto',
                                        onPressed: () => widget.onEdit(pkg),
                                        icon: Icon(
                                          Icons.edit_rounded,
                                          color: accentColor,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Elimina pacchetto',
                                        onPressed: () => widget.onDelete(pkg),
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          color: accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  _PriceInfoChip(
                                    package: pkg,
                                    currency: currency,
                                    discountPercentage: discount,
                                  ),
                                  if (discount != null)
                                    _InfoChip(
                                      icon: Icons.percent_rounded,
                                      label: '-${_formatDiscount(discount)}%',
                                    ),
                                  if (pkg.sessionCount != null)
                                    _InfoChip(
                                      icon: Icons.event_repeat,
                                      label: '${pkg.sessionCount} sessioni',
                                    ),
                                  if (pkg.validDays != null)
                                    _InfoChip(
                                      icon: Icons.calendar_month_rounded,
                                      label: 'Validità ${pkg.validDays} gg',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Servizi inclusi',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    pkg.serviceIds
                                        .map(
                                          (id) => _InfoChip(
                                            icon:
                                                Icons
                                                    .check_circle_outline_rounded,
                                            label:
                                                widget.services
                                                    .firstWhereOrNull(
                                                      (s) => s.id == id,
                                                    )
                                                    ?.name ??
                                                id,
                                          ),
                                        )
                                        .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            );
          },
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget? _buildFilterCard(
    BuildContext context,
    Color accentColor,
    Map<String, Salon> salonsById,
    Set<String> salonIdsInPackages,
    bool hasMultipleSalons,
    bool hasDiscountedPackages,
  ) {
    if (!hasMultipleSalons && !hasDiscountedPackages) {
      return null;
    }

    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final baseOpacity = brightness == Brightness.dark ? 0.22 : 0.08;
    final selectedOpacity = brightness == Brightness.dark ? 0.36 : 0.2;

    final chips = <Widget>[];

    void addSalonChip({
      required String? salonId,
      required String label,
      required IconData icon,
    }) {
      final isSelected =
          salonId == null ? _salonFilter == null : _salonFilter == salonId;
      chips.add(
        FilterChip(
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (salonId == null) {
                _salonFilter = null;
              } else {
                _salonFilter = selected ? salonId : null;
              }
            });
          },
          showCheckmark: false,
          backgroundColor: accentColor.withOpacity(baseOpacity),
          selectedColor: accentColor.withOpacity(selectedOpacity),
          side: BorderSide(
            color: accentColor.withOpacity(isSelected ? 0.5 : 0.18),
          ),
          avatar: Icon(icon, size: 18, color: accentColor),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: const StadiumBorder(),
          label: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  isSelected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    if (hasMultipleSalons) {
      addSalonChip(
        salonId: null,
        label: 'Tutti i saloni',
        icon: Icons.grid_view_rounded,
      );

      final sortedSalonIds =
          salonIdsInPackages.toList()..sort((a, b) {
            final nameA = salonsById[a]?.name ?? a;
            final nameB = salonsById[b]?.name ?? b;
            return nameA.toLowerCase().compareTo(nameB.toLowerCase());
          });
      for (final id in sortedSalonIds) {
        final label = salonsById[id]?.name ?? id;
        addSalonChip(salonId: id, label: label, icon: Icons.storefront_rounded);
      }
    }

    if (hasDiscountedPackages) {
      final isSelected = _onlyDiscounted;
      chips.add(
        FilterChip(
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _onlyDiscounted = selected;
            });
          },
          showCheckmark: false,
          backgroundColor: accentColor.withOpacity(baseOpacity),
          selectedColor: accentColor.withOpacity(selectedOpacity),
          side: BorderSide(
            color: accentColor.withOpacity(isSelected ? 0.5 : 0.18),
          ),
          avatar: Icon(Icons.local_offer_rounded, size: 18, color: accentColor),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: const StadiumBorder(),
          label: Text(
            'Solo promozioni',
            style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  isSelected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Card(
      color: _layerColor(theme, 1),
      elevation: widget.cardElevation,
      shadowColor: widget.shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list_rounded, color: accentColor),
                const SizedBox(width: 8),
                Text('Filtri pacchetti', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Affina l\'elenco per salone o mostra solo le promozioni attive.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ),
      ),
    );
  }

  List<ServicePackage> _applyFilters() {
    return widget.packages.where((pkg) {
      if (_salonFilter != null && pkg.salonId != _salonFilter) {
        return false;
      }
      if (_onlyDiscounted && _effectiveDiscount(pkg) == null) {
        return false;
      }
      return true;
    }).toList();
  }

  double? _effectiveDiscount(ServicePackage pkg) {
    if (pkg.fullPrice <= 0 || pkg.price >= pkg.fullPrice - 0.01) {
      return null;
    }
    final stored = pkg.discountPercentage;
    if (stored != null && stored > 0) {
      return stored;
    }
    final computed = ((pkg.fullPrice - pkg.price) / pkg.fullPrice) * 100;
    return computed > 0 ? computed : null;
  }

  String _formatDiscount(double value) {
    final normalized = value.clamp(0, 100);
    if ((normalized - normalized.roundToDouble()).abs() < 0.01) {
      return normalized.toStringAsFixed(0);
    }
    return normalized.toStringAsFixed(1);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = colorScheme.secondary;
    return Chip(
      backgroundColor: accentColor.withOpacity(
        theme.brightness == Brightness.dark ? 0.28 : 0.14,
      ),
      side: BorderSide(color: accentColor.withOpacity(0.16)),
      avatar: Icon(icon, size: 18, color: accentColor),
      label: Text(
        label,
        style: TextStyle(color: colorScheme.onSecondaryContainer),
      ),
    );
  }
}

class _PriceInfoChip extends StatelessWidget {
  const _PriceInfoChip({
    required this.package,
    required this.currency,
    this.discountPercentage,
  });

  final ServicePackage package;
  final NumberFormat currency;
  final double? discountPercentage;

  bool get _hasDiscount {
    if (package.fullPrice <= 0) {
      return false;
    }
    if (package.price >= package.fullPrice - 0.01) {
      return false;
    }
    if (discountPercentage != null) {
      return discountPercentage! > 0;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = _hasDiscount;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = colorScheme.secondary;
    final labelStyle = TextStyle(
      color: colorScheme.onSecondaryContainer,
      fontWeight: FontWeight.w600,
    );
    final icon = hasDiscount ? Icons.local_offer_rounded : Icons.euro_rounded;
    final Widget label =
        hasDiscount
            ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: currency.format(package.price),
                    style: labelStyle,
                  ),
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: currency.format(package.fullPrice),
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              style: labelStyle,
            )
            : Text(currency.format(package.price), style: labelStyle);
    return Chip(
      backgroundColor: accentColor.withOpacity(
        Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.14,
      ),
      side: BorderSide(color: accentColor.withOpacity(0.16)),
      avatar: Icon(icon, size: 18, color: accentColor),
      label: label,
    );
  }
}
