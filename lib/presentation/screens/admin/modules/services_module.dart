import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_role.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/service_form_sheet.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ServicesModule extends ConsumerWidget {
  const ServicesModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final salons = data.salons;
    final staffRoles = data.staffRoles;
    final services =
        data.services
            .where((service) => salonId == null || service.salonId == salonId)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final packages =
        data.packages
            .where((pkg) => salonId == null || pkg.salonId == salonId)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Servizi',
            subtitle: '${services.length} trattamenti attivi',
            actionLabel: 'Nuovo servizio',
            onActionPressed:
                () => _openServiceForm(
                  context,
                  ref,
                  salons: salons,
                  roles: staffRoles,
                  defaultSalonId: salonId,
                ),
          ),
          const SizedBox(height: 12),
          if (services.isEmpty)
            const Card(
              child: ListTile(title: Text('Nessun servizio disponibile')),
            )
          else
            _ServicesList(
              services: services,
              salons: salons,
              onEdit:
                  (service) => _openServiceForm(
                    context,
                    ref,
                    salons: salons,
                    roles: staffRoles,
                    defaultSalonId: salonId,
                    existing: service,
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
                  services: services,
                  defaultSalonId: salonId,
                ),
          ),
          const SizedBox(height: 12),
          if (packages.isEmpty)
            const Card(
              child: ListTile(title: Text('Nessun pacchetto configurato')),
            )
          else
            _PackagesList(
              packages: packages,
              services: data.services,
              onEdit:
                  (pkg) => _openPackageForm(
                    context,
                    ref,
                    salons: salons,
                    services: data.services,
                    defaultSalonId: salonId,
                    existing: pkg,
                  ),
            ),
        ],
      ),
    );
  }

  Future<void> _openServiceForm(
    BuildContext context,
    WidgetRef ref, {
    required List<Salon> salons,
    required List<StaffRole> roles,
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
            defaultSalonId: defaultSalonId,
            initial: existing,
          ),
    );
    if (result != null) {
      await ref.read(appDataProvider.notifier).upsertService(result);
    }
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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onActionPressed,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onActionPressed;

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
        FilledButton.icon(
          onPressed: onActionPressed,
          icon: const Icon(Icons.add_rounded),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _ServicesList extends StatelessWidget {
  const _ServicesList({
    required this.services,
    required this.salons,
    required this.onEdit,
  });

  final List<Service> services;
  final List<Salon> salons;
  final ValueChanged<Service> onEdit;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final service = services[index];
        final salon = salons.firstWhereOrNull(
          (item) => item.id == service.salonId,
        );
        final equipmentNames =
            service.requiredEquipmentIds
                .map(
                  (id) =>
                      salon?.equipment
                          .firstWhereOrNull((eq) => eq.id == id)
                          ?.name ??
                      id,
                )
                .toList();
        return Card(
          child: ListTile(
            title: Text(service.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.description ?? 'Nessuna descrizione'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.category_rounded,
                      label: service.category,
                    ),
                    _InfoChip(
                      icon: Icons.timer_rounded,
                      label: '${service.duration.inMinutes} min',
                    ),
                    _InfoChip(
                      icon: Icons.euro_rounded,
                      label: currency.format(service.price),
                    ),
                  ],
                ),
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
            trailing: IconButton(
              onPressed: () => onEdit(service),
              icon: const Icon(Icons.edit_rounded),
            ),
          ),
        );
      },
    );
  }
}

class _PackagesList extends StatelessWidget {
  const _PackagesList({
    required this.packages,
    required this.services,
    required this.onEdit,
  });

  final List<ServicePackage> packages;
  final List<Service> services;
  final ValueChanged<ServicePackage> onEdit;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: packages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final pkg = packages[index];
        final discount = _effectiveDiscount(pkg);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pkg.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (pkg.description != null) ...[
                            const SizedBox(height: 4),
                            Text(pkg.description!),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => onEdit(pkg),
                      icon: const Icon(Icons.edit_rounded),
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
                            (id) => Chip(
                              label: Text(
                                services
                                        .firstWhereOrNull((s) => s.id == id)
                                        ?.name ??
                                    id,
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
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
    final icon = hasDiscount ? Icons.local_offer_rounded : Icons.euro_rounded;
    final label =
        hasDiscount
            ? Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: currency.format(package.price),
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
            )
            : Text(currency.format(package.price));
    return Chip(avatar: Icon(icon, size: 18), label: label);
  }
}
