import 'dart:async';

import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/salon_setup_progress.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_profile_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_operations_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_client_registration_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_setup_checklist_sheet.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_aggregator.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_models.dart';
import 'package:you_book/presentation/screens/admin/widgets/admin_responsive_helpers.dart';
import 'package:you_book/services/whatsapp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SalonManagementModule extends ConsumerStatefulWidget {
  const SalonManagementModule({super.key, this.selectedSalonId});

  final String? selectedSalonId;

  @override
  ConsumerState<SalonManagementModule> createState() =>
      _SalonManagementModuleState();
}

class _SalonManagementModuleState extends ConsumerState<SalonManagementModule> {
  String? _pendingSalonId;
  String? _pendingSalonName;
  Timer? _pendingClearTimer;

  @override
  void dispose() {
    _pendingClearTimer?.cancel();
    super.dispose();
  }

  void _handleSalonSelected(Salon salon) {
    final currentSalonId = ref.read(sessionControllerProvider).selectedSalonId;
    if (currentSalonId == salon.id && _pendingSalonId == null) {
      return;
    }

    _pendingClearTimer?.cancel();
    setState(() {
      _pendingSalonId = salon.id;
      _pendingSalonName = salon.name;
    });
    ref.read(sessionControllerProvider.notifier).setSalon(salon.id);

    _pendingClearTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      final selected = ref.read(sessionControllerProvider).selectedSalonId;
      if (selected != salon.id || _pendingSalonId != salon.id) {
        return;
      }
      setState(() {
        _pendingSalonId = null;
        _pendingSalonName = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final data = ref.watch(appDataProvider);
    final theme = Theme.of(context);
    final allSalons = data.salons;
    final rawSalonIds = session.availableSalonIds;
    final rawSalonIdSet = rawSalonIds.toSet();
    final normalizedSalonIds = <String>{};
    for (final id in rawSalonIds) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty) {
        normalizedSalonIds.add(trimmed);
      }
    }
    final shouldFilterBySalonIds = normalizedSalonIds.isNotEmpty;
    final salons =
        shouldFilterBySalonIds
            ? allSalons
                .where((salon) {
                  if (rawSalonIdSet.contains(salon.id)) {
                    return true;
                  }
                  final trimmedId = salon.id.trim();
                  return trimmedId.isNotEmpty &&
                      normalizedSalonIds.contains(trimmedId);
                })
                .toList(growable: false)
            : allSalons;

    if (salons.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nessun salone configurato',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    Salon? findSalonById(String? id) {
      if (id == null) {
        return null;
      }
      final trimmedId = id.trim();
      for (final salon in salons) {
        if (salon.id == id) {
          return salon;
        }
        if (trimmedId.isNotEmpty && salon.id.trim() == trimmedId) {
          return salon;
        }
      }
      return null;
    }

    bool hasSalonAccess(String salonId) {
      final trimmed = salonId.trim();
      return !shouldFilterBySalonIds ||
          rawSalonIdSet.contains(salonId) ||
          (trimmed.isNotEmpty && normalizedSalonIds.contains(trimmed));
    }

    final activePendingSalonId =
        _pendingSalonId == null ||
                session.selectedSalonId == null ||
                session.selectedSalonId == _pendingSalonId
            ? _pendingSalonId
            : null;
    final requestedSalonId =
        activePendingSalonId ??
        session.selectedSalonId ??
        widget.selectedSalonId;
    final matchingSalon = findSalonById(requestedSalonId);
    final shouldWaitForRequested =
        requestedSalonId != null &&
        matchingSalon == null &&
        hasSalonAccess(requestedSalonId);
    final effectiveSalonId =
        matchingSalon?.id ??
        (shouldWaitForRequested ? requestedSalonId : salons.first.id);
    final selected =
        matchingSalon != null
            ? <Salon>[matchingSalon]
            : shouldWaitForRequested
            ? const <Salon>[]
            : salons.where((salon) => salon.id == effectiveSalonId).toList();
    final isSwitchingSalon =
        activePendingSalonId != null || shouldWaitForRequested;
    final switchingSalonName =
        _pendingSalonName ?? matchingSalon?.name ?? requestedSalonId;

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactLayout = screenWidth < 720;
    final horizontalPadding = isCompactLayout ? 16.0 : 24.0;
    final topPadding = isCompactLayout ? 16.0 : 24.0;
    final bottomPadding = isCompactLayout ? 24.0 : 32.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      children: [
        const _SalonModuleHeader(),
        SizedBox(height: isCompactLayout ? 18 : 24),
        _SalonTabsBar(
          salons: salons,
          selectedSalonId: effectiveSalonId,
          pendingSalonId: isSwitchingSalon ? effectiveSalonId : null,
          onSelected: _handleSalonSelected,
        ),
        if (isSwitchingSalon) ...[
          const SizedBox(height: 12),
          _SalonSwitchingNotice(salonName: switchingSalonName),
        ],
        SizedBox(height: isCompactLayout ? 16 : 20),
        for (final salon in selected) ...[
          _SalonDashboard(salon: salon),
          const SizedBox(height: 32),
        ],
      ],
    );
  }
}

class _SalonModuleHeader extends StatelessWidget {
  const _SalonModuleHeader();

  @override
  Widget build(BuildContext context) {
    return const AdminResponsiveHeader(
      title: 'Saloni',
      subtitle: 'Gestione e configurazione saloni',
    );
  }
}

class _SalonDashboard extends ConsumerWidget {
  const _SalonDashboard({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(salonSetupProgressProvider(salon.id));
    final progressItems = progress?.items ?? const <SetupChecklistItem>[];
    final filteredProgressItems = progressItems
        .where((item) => SetupChecklistKeys.defaults.contains(item.key))
        .toList(growable: false);
    final completedItems =
        filteredProgressItems.isNotEmpty
            ? filteredProgressItems
                .where((item) => item.status == SetupChecklistStatus.completed)
                .length
            : salon.setupChecklist.values
                .where((status) => status == SetupChecklistStatus.completed)
                .length;
    final totalItems =
        filteredProgressItems.isNotEmpty
            ? filteredProgressItems.length
            : (salon.setupChecklist.isNotEmpty
                ? salon.setupChecklist.length
                : SetupChecklistKeys.defaults.length);
    final setupSummary = _SalonSetupSummary(
      completed: completedItems,
      total: totalItems,
      highlighted:
          (progress?.pendingReminder ?? false) || completedItems < totalItems,
    );

    Future<void> openChecklist() async {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => SalonSetupChecklistDialog(salonId: salon.id),
      );
    }

    Future<void> handleProfileEdit() async {
      final store = ref.read(appDataProvider.notifier);
      if (!context.mounted) {
        return;
      }
      final updated = await showAppModalSheet<Salon>(
        context: context,
        includeCloseButton: false,
        builder: (ctx) => SalonProfileSheet(salon: salon),
      );
      if (updated != null) {
        final merged = await store.updateSalonProfileSection(
          salonId: salon.id,
          source: updated,
        );
        await store.markSalonSetupItemCompleted(
          salonId: salon.id,
          itemKey: SetupChecklistKeys.profile,
          metadata: {
            'hasAddress': merged.address.trim().isNotEmpty,
            'hasDescription': (merged.description ?? '').trim().isNotEmpty,
          },
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResponsiveCardWrap(
          items: [
            _ResponsiveCardItem(
              child: _SalonOverviewCard(
                salon: salon,
                onEdit: handleProfileEdit,
              ),
            ),
            _ResponsiveCardItem(child: _StripeConnectCard(salon: salon)),
            _ResponsiveCardItem(
              child: _WhatsAppSettingsCard(salonId: salon.id),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SalonOperationsOverviewCard(
          salon: salon,
          setupSummary: setupSummary,
          onOpenChecklist: openChecklist,
        ),
      ],
    );
  }
}

class _SalonTabsBar extends StatelessWidget {
  const _SalonTabsBar({
    required this.salons,
    required this.selectedSalonId,
    required this.pendingSalonId,
    required this.onSelected,
  });

  final List<Salon> salons;
  final String? selectedSalonId;
  final String? pendingSalonId;
  final ValueChanged<Salon> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children:
            salons.map((salon) {
              final isSelected = selectedSalonId == salon.id;
              final isPending = pendingSalonId == salon.id;
              final foreground =
                  isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface;
              return InkWell(
                key: ValueKey('salon_tab_${salon.id}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(salon),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        isSelected
                            ? null
                            : Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: theme.shadowColor.withValues(
                                  alpha: 0.10,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ]
                            : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPending) ...[
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: foreground,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        Icons.storefront_rounded,
                        size: 16,
                        color: foreground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        salon.name,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _SalonSwitchingNotice extends StatelessWidget {
  const _SalonSwitchingNotice({this.salonName});

  final String? salonName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = salonName?.trim();
    final targetLabel =
        name == null || name.isEmpty ? 'il salone selezionato' : name;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cambio salone in corso',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sto caricando $targetLabel.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: scheme.primary,
                backgroundColor: scheme.primary.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalonSetupSummary {
  const _SalonSetupSummary({
    required this.completed,
    required this.total,
    required this.highlighted,
  });

  final int completed;
  final int total;
  final bool highlighted;

  bool get hasRemainingItems => total > 0 && completed < total;

  String get label =>
      hasRemainingItems
          ? 'Setup $completed/$total'
          : 'Configurazione completata';
}

class _SalonDashboardMetrics {
  _SalonDashboardMetrics({
    required this.staffActive,
    required this.staffTotal,
    required this.clientsTotal,
    required this.newClientsThisMonth,
    required this.appointmentsToday,
    required this.openDaysConfigured,
    required this.activeEquipmentQuantity,
    required this.activeServices,
    required this.inventoryItems,
    required this.packages,
    required this.monthOccupancy,
    required this.monthOccupancyEstimated,
    required this.monthRevenue,
    required this.openingHoursSummary,
    required this.registrationAccessLabel,
    required this.registrationExtrasLabel,
    required this.upcomingClosures,
  });

  factory _SalonDashboardMetrics.fromData({
    required Salon salon,
    required AppDataState data,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final monthSnapshot = ReportsAggregator.build(
      data: data,
      filters: ReportFilters(
        salonId: salon.id,
        range: DateTimeRange(start: monthStart, end: monthEnd),
      ),
    );

    final salonStaff = data.staff
        .where((member) => member.salonId == salon.id && !member.isEquipment)
        .toList(growable: false);
    final staffActive = salonStaff.where((member) => member.isActive).length;
    final salonClients = data.clients
        .where((client) => client.salonId == salon.id)
        .toList(growable: false);
    final newClientsThisMonth =
        salonClients.where((client) {
          final createdAt = client.createdAt;
          if (createdAt == null) {
            return false;
          }
          return !createdAt.isBefore(monthStart) &&
              !createdAt.isAfter(monthEnd);
        }).length;
    final appointmentsToday =
        data.appointments.where((appointment) {
          if (appointment.salonId != salon.id ||
              appointment.status == AppointmentStatus.cancelled) {
            return false;
          }
          final start = appointment.start;
          return start.year == today.year &&
              start.month == today.month &&
              start.day == today.day;
        }).length;
    final openDaysConfigured =
        salon.schedule.where((entry) => entry.isOpen).length;
    final activeEquipmentQuantity = salon.equipment
        .where((item) => item.status == SalonEquipmentStatus.operational)
        .fold<int>(0, (sum, item) => sum + item.quantity);
    final activeServices =
        data.services
            .where((service) => service.salonId == salon.id && service.isActive)
            .length;
    final inventoryItems =
        data.inventoryItems.where((item) => item.salonId == salon.id).length;
    final packages =
        data.packages.where((pkg) => pkg.salonId == salon.id).length;
    final openingHoursSummary = _buildOpeningHoursSummary(salon.schedule);
    final upcomingClosures = salon.closures
        .where((closure) => !closure.end.isBefore(today))
        .toList(growable: false)
      ..sort((left, right) => left.start.compareTo(right.start));

    return _SalonDashboardMetrics(
      staffActive: staffActive,
      staffTotal: salonStaff.length,
      clientsTotal: salonClients.length,
      newClientsThisMonth: newClientsThisMonth,
      appointmentsToday: appointmentsToday,
      openDaysConfigured: openDaysConfigured,
      activeEquipmentQuantity: activeEquipmentQuantity,
      activeServices: activeServices,
      inventoryItems: inventoryItems,
      packages: packages,
      monthOccupancy: monthSnapshot.current.occupancy.ratio,
      monthOccupancyEstimated: monthSnapshot.current.occupancy.estimated,
      monthRevenue: monthSnapshot.current.totalRevenue,
      openingHoursSummary: openingHoursSummary,
      registrationAccessLabel: _registrationAccessLabel(
        salon.clientRegistration.accessMode,
      ),
      registrationExtrasLabel: _registrationExtrasLabel(
        salon.clientRegistration.extraFields,
      ),
      upcomingClosures: upcomingClosures,
    );
  }

  final int staffActive;
  final int staffTotal;
  final int clientsTotal;
  final int newClientsThisMonth;
  final int appointmentsToday;
  final int openDaysConfigured;
  final int activeEquipmentQuantity;
  final int activeServices;
  final int inventoryItems;
  final int packages;
  final double? monthOccupancy;
  final bool monthOccupancyEstimated;
  final double monthRevenue;
  final List<String> openingHoursSummary;
  final String registrationAccessLabel;
  final String registrationExtrasLabel;
  final List<SalonClosure> upcomingClosures;
}

class _SalonOverviewCard extends StatelessWidget {
  const _SalonOverviewCard({required this.salon, required this.onEdit});

  final Salon salon;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = [
      salon.address.trim(),
      salon.city.trim(),
    ].where((part) => part.isNotEmpty).join(', ');

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionIconBadge(
                icon: Icons.store_mall_directory_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Info Salone',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusChip(status: salon.status),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Nome',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            salon.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (location.isNotEmpty) ...[
            Text(
              'Indirizzo',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(location, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 14),
          ],
          _InlineMetaRow(
            icon: Icons.call_outlined,
            label: salon.phone.isEmpty ? 'Telefono non impostato' : salon.phone,
          ),
          const SizedBox(height: 10),
          _InlineMetaRow(
            icon: Icons.mail_outline_rounded,
            label: salon.email.isEmpty ? 'Email non impostata' : salon.email,
          ),
          if (salon.bookingLink != null && salon.bookingLink!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InlineMetaRow(
              icon: Icons.link_rounded,
              label: 'Prenotazioni online attive',
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Modifica'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalonOperationsOverviewCard extends ConsumerWidget {
  const _SalonOperationsOverviewCard({
    required this.salon,
    required this.setupSummary,
    this.onOpenChecklist,
  });

  final Salon salon;
  final _SalonSetupSummary setupSummary;
  final VoidCallback? onOpenChecklist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final metrics = _SalonDashboardMetrics.fromData(
      salon: salon,
      data: ref.watch(appDataProvider),
    );

    Future<void> editOperationsAsync() async {
      final store = ref.read(appDataProvider.notifier);
      final updated = await showAppModalSheet<Salon>(
        context: context,
        includeCloseButton: false,
        builder: (ctx) => SalonOperationsSheet(salon: salon),
      );
      if (updated == null) {
        return;
      }
      final merged = await store.updateSalonOperationsSection(
        salonId: salon.id,
        source: updated,
      );
      await store.markSalonSetupItemCompleted(
        salonId: salon.id,
        itemKey: SetupChecklistKeys.operations,
        metadata: {
          'hasSchedule': merged.schedule.any((entry) => entry.isOpen),
          'status': merged.status.name,
        },
        markRequiredCompleted: true,
      );
    }

    Future<void> editRegistrationAsync() async {
      final store = ref.read(appDataProvider.notifier);
      final updated = await showAppModalSheet<Salon>(
        context: context,
        includeCloseButton: false,
        builder: (ctx) => SalonClientRegistrationSheet(salon: salon),
      );
      if (updated == null) {
        return;
      }
      await store.updateSalonClientRegistrationSection(
        salonId: salon.id,
        source: updated,
      );
    }

    final occupancyValue =
        metrics.monthOccupancy == null
            ? '—'
            : '${(metrics.monthOccupancy! * 100).toStringAsFixed(0)}%';
    final occupancySubtitle =
        metrics.monthOccupancy == null
            ? 'capacità non disponibile'
            : metrics.monthOccupancyEstimated
            ? 'stima mese corrente'
            : 'mese corrente';

    final currencyFormatter = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
      decimalDigits:
          metrics.monthRevenue == metrics.monthRevenue.roundToDouble() ? 0 : 2,
    );

    final metricCards = <Widget>[
      _MetricTile(
        icon: Icons.groups_2_rounded,
        label: 'Staff attivo',
        value: metrics.staffActive.toString(),
        caption: 'su ${metrics.staffTotal} totali',
        tone: _MetricTone.highlight,
      ),
      _MetricTile(
        icon: Icons.person_outline_rounded,
        label: 'Clienti',
        value: metrics.clientsTotal.toString(),
        caption:
            metrics.newClientsThisMonth > 0
                ? '+${metrics.newClientsThisMonth} questo mese'
                : 'nessun nuovo cliente',
        tone:
            metrics.newClientsThisMonth > 0
                ? _MetricTone.highlight
                : _MetricTone.neutral,
      ),
      _MetricTile(
        icon: Icons.calendar_today_rounded,
        label: 'Appuntamenti',
        value: metrics.appointmentsToday.toString(),
        caption: 'oggi',
      ),
      _MetricTile(
        icon: Icons.schedule_rounded,
        label: 'Slot orari',
        value: metrics.openDaysConfigured.toString(),
        caption: 'giorni configurati',
      ),
      _MetricTile(
        icon: Icons.precision_manufacturing_rounded,
        label: 'Macchinari',
        value: metrics.activeEquipmentQuantity.toString(),
        caption: 'attivi',
      ),
      _MetricTile(
        icon: Icons.content_cut_rounded,
        label: 'Servizi',
        value: metrics.activeServices.toString(),
        caption: 'attivi',
      ),
      _MetricTile(
        icon: Icons.inventory_2_outlined,
        label: 'Prodotti',
        value: metrics.inventoryItems.toString(),
        caption: 'a magazzino',
      ),
      _MetricTile(
        icon: Icons.widgets_outlined,
        label: 'Pacchetti',
        value: metrics.packages.toString(),
        caption: 'disponibili',
      ),
      _MetricTile(
        icon: Icons.percent_rounded,
        label: 'Occupazione',
        value: occupancyValue,
        caption: occupancySubtitle,
        tone: _MetricTone.warm,
      ),
      _MetricTile(
        icon: Icons.euro_rounded,
        label: 'Fatturato',
        value: currencyFormatter.format(metrics.monthRevenue),
        caption: 'questo mese',
        tone: _MetricTone.highlight,
      ),
    ];

    final footerCards = <Widget>[
      _FooterInfoCard(
        title: 'Orari di Apertura',
        icon: Icons.access_time_rounded,
        lines:
            metrics.openingHoursSummary.isEmpty
                ? const ['Nessun orario configurato']
                : metrics.openingHoursSummary,
        onEdit: () => unawaited(editOperationsAsync()),
      ),
      _FooterInfoCard(
        title: 'Registrazione Clienti',
        icon: Icons.how_to_reg_rounded,
        lines: [
          'Accesso: ${metrics.registrationAccessLabel}',
          'Campi: ${metrics.registrationExtrasLabel}',
        ],
        onEdit: () => unawaited(editRegistrationAsync()),
      ),
      _FooterStatusCard(
        status: salon.status,
        onEdit: () => unawaited(editOperationsAsync()),
      ),
      if (metrics.upcomingClosures.isNotEmpty)
        _FooterInfoCard(
          title: 'Chiusure programmate',
          icon: Icons.event_busy_rounded,
          lines: _formatClosureLines(metrics.upcomingClosures),
        ),
    ];

    return _DashboardCard(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminResponsiveHeader(
            title: 'Operatività e risorse',
            subtitle: 'KPI, stato e capacità operative',
            leading: _SectionIconBadge(
              icon: Icons.dashboard_customize_rounded,
              color: theme.colorScheme.primary,
              soft: true,
            ),
            stackBreakpoint: 860,
            trailingFullWidthOnStack: true,
            trailing: _SetupProgressPill(
              summary: setupSummary,
              onTap: onOpenChecklist,
            ),
          ),
          const SizedBox(height: 20),
          _AdaptiveGrid(
            minTileWidth: 170,
            largeColumns: 5,
            mediumColumns: 3,
            smallColumns: 2,
            spacing: 14,
            children: metricCards,
          ),
          const SizedBox(height: 16),
          _AdaptiveGrid(
            minTileWidth: 230,
            largeColumns: 3,
            mediumColumns: 2,
            smallColumns: 1,
            spacing: 14,
            children: footerCards,
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.9),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SectionIconBadge extends StatelessWidget {
  const _SectionIconBadge({
    required this.icon,
    required this.color,
    this.soft = false,
  });

  final IconData icon;
  final Color color;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        soft
            ? Color.alphaBlend(
              color.withValues(alpha: 0.10),
              theme.colorScheme.surfaceContainerLowest,
            )
            : Color.alphaBlend(
              color.withValues(alpha: 0.14),
              theme.colorScheme.primaryContainer,
            );
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _WhatsAppLogoBadge extends StatelessWidget {
  const _WhatsAppLogoBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Image.asset(
        'assets/social_logo/whatsapp.PNG',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _InlineMetaRow extends StatelessWidget {
  const _InlineMetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _SetupProgressPill extends StatelessWidget {
  const _SetupProgressPill({required this.summary, this.onTap});

  final _SalonSetupSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        summary.highlighted
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 16, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              summary.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return child;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: child,
    );
  }
}

class _AdaptiveGrid extends StatelessWidget {
  const _AdaptiveGrid({
    required this.children,
    required this.minTileWidth,
    required this.largeColumns,
    required this.mediumColumns,
    required this.smallColumns,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int largeColumns;
  final int mediumColumns;
  final int smallColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns =
            maxWidth >= largeColumns * minTileWidth
                ? largeColumns
                : maxWidth >= mediumColumns * minTileWidth
                ? mediumColumns
                : maxWidth >= smallColumns * minTileWidth
                ? smallColumns
                : 1;
        final tileWidth =
            columns == 1
                ? maxWidth
                : (maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              children
                  .map((child) => SizedBox(width: tileWidth, child: child))
                  .toList(),
        );
      },
    );
  }
}

enum _MetricTone { neutral, highlight, warm }

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.tone = _MetricTone.neutral,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final _MetricTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    late final Color background;
    late final Color borderColor;
    late final Color iconColor;
    switch (tone) {
      case _MetricTone.highlight:
        background = Color.alphaBlend(
          theme.colorScheme.primary.withValues(alpha: 0.08),
          theme.colorScheme.surfaceContainerLowest,
        );
        borderColor = theme.colorScheme.primary.withValues(alpha: 0.22);
        iconColor = theme.colorScheme.primary;
      case _MetricTone.warm:
        background = Color.alphaBlend(
          const Color(0xFFE7B95A).withValues(alpha: 0.10),
          theme.colorScheme.surfaceContainerLowest,
        );
        borderColor = const Color(0xFFE7B95A).withValues(alpha: 0.32);
        iconColor = const Color(0xFFB88315);
      case _MetricTone.neutral:
        background = theme.colorScheme.surfaceContainerLowest;
        borderColor = theme.colorScheme.outlineVariant;
        iconColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterInfoCard extends StatelessWidget {
  const _FooterInfoCard({
    required this.title,
    required this.icon,
    required this.lines,
    this.onEdit,
  });

  final String title;
  final IconData icon;
  final List<String> lines;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Modifica',
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterStatusCard extends StatelessWidget {
  const _FooterStatusCard({required this.status, this.onEdit});

  final SalonStatus status;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          _statusColor(context, status).withValues(alpha: 0.08),
          theme.colorScheme.surfaceContainerLowest,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _statusColor(context, status).withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: _statusColor(context, status),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Stato',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Modifica stato',
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _StatusChip(status: status),
        ],
      ),
    );
  }
}

List<String> _buildOpeningHoursSummary(List<SalonDailySchedule> schedule) {
  final openEntries =
      schedule.where((entry) => entry.isOpen).toList()
        ..sort((left, right) => left.weekday.compareTo(right.weekday));
  if (openEntries.isEmpty) {
    return const <String>[];
  }

  final groups = <List<SalonDailySchedule>>[];
  for (final entry in openEntries) {
    if (groups.isEmpty) {
      groups.add(<SalonDailySchedule>[entry]);
      continue;
    }
    final currentGroup = groups.last;
    final previous = currentGroup.last;
    final sameTime =
        previous.openMinuteOfDay == entry.openMinuteOfDay &&
        previous.closeMinuteOfDay == entry.closeMinuteOfDay;
    final consecutiveDay = entry.weekday == previous.weekday + 1;
    if (sameTime && consecutiveDay) {
      currentGroup.add(entry);
    } else {
      groups.add(<SalonDailySchedule>[entry]);
    }
  }

  return groups
      .map((group) {
        final first = group.first;
        final last = group.last;
        final dayLabel =
            first.weekday == last.weekday
                ? _weekdayShortLabel(first.weekday)
                : '${_weekdayShortLabel(first.weekday)}-${_weekdayShortLabel(last.weekday)}';
        final openLabel = _formatMinuteOfDay(first.openMinuteOfDay);
        final closeLabel = _formatMinuteOfDay(first.closeMinuteOfDay);
        return '$dayLabel $openLabel - $closeLabel';
      })
      .toList(growable: false);
}

String _registrationAccessLabel(ClientRegistrationAccessMode mode) {
  switch (mode) {
    case ClientRegistrationAccessMode.open:
      return 'Accesso immediato';
    case ClientRegistrationAccessMode.approval:
      return 'Richiede approvazione';
  }
}

String _registrationExtrasLabel(List<ClientRegistrationExtraField> extras) {
  if (extras.isEmpty) {
    return 'Nessuno';
  }
  return extras
      .map((extra) {
        switch (extra) {
          case ClientRegistrationExtraField.address:
            return 'Città';
          case ClientRegistrationExtraField.profession:
            return 'Professione';
          case ClientRegistrationExtraField.referralSource:
            return 'Provenienza';
          case ClientRegistrationExtraField.notes:
            return 'Note';
          case ClientRegistrationExtraField.gender:
            return 'Sesso';
        }
      })
      .join(', ');
}

List<String> _formatClosureLines(List<SalonClosure> closures) {
  final formatter = DateFormat('dd MMM yyyy', 'it');
  final visible = closures
      .take(3)
      .map((closure) {
        final period =
            closure.isSingleDay
                ? formatter.format(closure.start)
                : '${formatter.format(closure.start)} - ${formatter.format(closure.end)}';
        if (closure.reason == null || closure.reason!.trim().isEmpty) {
          return period;
        }
        return '$period · ${closure.reason!.trim()}';
      })
      .toList(growable: false);
  final remaining = closures.length - visible.length;
  if (remaining > 0) {
    visible.add('+$remaining altre chiusure');
  }
  return visible;
}

String _weekdayShortLabel(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Lun';
    case DateTime.tuesday:
      return 'Mar';
    case DateTime.wednesday:
      return 'Mer';
    case DateTime.thursday:
      return 'Gio';
    case DateTime.friday:
      return 'Ven';
    case DateTime.saturday:
      return 'Sab';
    case DateTime.sunday:
      return 'Dom';
    default:
      return '—';
  }
}

String _formatMinuteOfDay(int? minutes) {
  if (minutes == null) {
    return '--:--';
  }
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _ResponsiveCardWrap extends StatelessWidget {
  const _ResponsiveCardWrap({required this.items});

  final List<_ResponsiveCardItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    const spacing = 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = _resolveColumnCount(maxWidth);
        final columnWidth =
            columns == 1
                ? maxWidth
                : (maxWidth - spacing * (columns - 1)) / columns;

        final children =
            items.map((item) {
              final width = columns == 1 ? maxWidth : columnWidth;
              return SizedBox(width: width, child: item.child);
            }).toList();

        return Wrap(spacing: spacing, runSpacing: spacing, children: children);
      },
    );
  }
}

class _ResponsiveCardItem {
  const _ResponsiveCardItem({required this.child});

  final Widget child;
}

int _resolveColumnCount(double maxWidth) {
  if (maxWidth >= 1280) return 3;
  if (maxWidth >= 920) return 2;
  return 1;
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label, this.palette});

  final IconData icon;
  final String label;
  final _ChipPalette? palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedPalette =
        palette ??
        const _ChipPalette(
          foreground: Color(0xFF6B7280),
          background: Color(0xFFF3F4F6),
          border: Color(0xFFD9DDE3),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: resolvedPalette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resolvedPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: resolvedPalette.foreground),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: resolvedPalette.foreground,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripeConnectCard extends ConsumerStatefulWidget {
  const _StripeConnectCard({required this.salon});

  final Salon salon;

  @override
  ConsumerState<_StripeConnectCard> createState() => _StripeConnectCardState();
}

class _StripeConnectAccountDraft {
  const _StripeConnectAccountDraft({
    required this.email,
    required this.businessType,
  });

  final String email;
  final String businessType;

  bool get isCompany => businessType == 'company';
}

class _StripeConnectCardState extends ConsumerState<_StripeConnectCard> {
  bool _isCreatingAccount = false;
  bool _isGeneratingLink = false;
  bool _isUpdatingClientOnlinePayments = false;

  static const _defaultReturnUrl = String.fromEnvironment(
    'STRIPE_ONBOARDING_RETURN_URL',
    defaultValue: 'https://youbook.civiapp.it/stripe-success',
  );
  static const _defaultRefreshUrl = String.fromEnvironment(
    'STRIPE_ONBOARDING_REFRESH_URL',
    defaultValue: 'https://youbook.civiapp.it/stripe/onboarding/retry',
  );

  @override
  Widget build(BuildContext context) {
    final salon = widget.salon;
    final theme = Theme.of(context);
    final accountId = salon.stripeAccountId;
    final accountSnapshot = salon.stripeAccount;
    final clientOnlinePaymentsEnabled = salon.featureFlags.clientOnlinePayments;
    final chargesEnabled = accountSnapshot.chargesEnabled;
    final payoutsEnabled = accountSnapshot.payoutsEnabled;
    final detailsSubmitted = accountSnapshot.detailsSubmitted;
    final canOpenDashboard = accountId != null && detailsSubmitted;

    final statusText =
        accountId == null
            ? 'Account non collegato'
            : !clientOnlinePaymentsEnabled
            ? 'Pagamenti disattivati dall\'admin'
            : salon.canAcceptOnlinePayments
            ? 'Pagamenti attivi'
            : 'In attesa di verifica';

    final statusPalette = _stripeChipPalette(
      context: context,
      hasAccount: accountId != null,
      onlinePaymentsEnabled: clientOnlinePaymentsEnabled,
      readyForPayments: salon.canAcceptOnlinePayments,
    );
    final stripeInfoPalette =
        accountId == null
            ? _softErrorChipPalette(context)
            : _infoBlueChipPalette(context);

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionIconBadge(
                icon: Icons.euro_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Stripe',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(
                label: Text(statusText),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                side: BorderSide(color: statusPalette.border),
                backgroundColor: statusPalette.background,
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  color: statusPalette.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Account ID',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              accountId ?? 'Account non collegato',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Pagamenti online',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: clientOnlinePaymentsEnabled,
                  onChanged:
                      _isUpdatingClientOnlinePayments
                          ? null
                          : (enabled) => _handleClientOnlinePaymentsToggle(
                            context,
                            enabled,
                          ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoBadge(
                icon:
                    chargesEnabled
                        ? Icons.check_circle_outline_rounded
                        : Icons.remove_circle_outline_rounded,
                label: 'Transazioni',
                palette: stripeInfoPalette,
              ),
              _InfoBadge(
                icon:
                    payoutsEnabled
                        ? Icons.check_circle_outline_rounded
                        : Icons.remove_circle_outline_rounded,
                label: 'Bonifici',
                palette: stripeInfoPalette,
              ),
              _InfoBadge(
                icon:
                    detailsSubmitted
                        ? Icons.check_circle_outline_rounded
                        : Icons.remove_circle_outline_rounded,
                label: 'Dati fiscali',
                palette: stripeInfoPalette,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  accountId == null
                      ? (_isCreatingAccount
                          ? null
                          : () => _handleCreateAccount(context))
                      : (_isGeneratingLink
                          ? null
                          : () => _handleStripeAccountLink(context)),
              icon:
                  (accountId == null ? _isCreatingAccount : _isGeneratingLink)
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Icon(
                        accountId == null
                            ? Icons.add_link_rounded
                            : Icons.send_rounded,
                        size: 18,
                      ),
              label: Text(
                accountId == null
                    ? (_isCreatingAccount ? 'Creazione...' : 'Configura')
                    : (_isGeneratingLink
                        ? 'Apertura...'
                        : canOpenDashboard
                        ? 'Dashboard'
                        : 'Completa onboarding'),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (accountId != null)
                OutlinedButton.icon(
                  onPressed: () => _copyToClipboard(context, accountId),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copia ID'),
                ),
              TextButton.icon(
                onPressed:
                    () => launchUrl(
                      Uri.parse(
                        'https://support.stripe.com/questions/express-dashboard-overview',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: const Text('Guida'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCreateAccount(BuildContext context) async {
    final salon = widget.salon;
    final messenger = ScaffoldMessenger.of(context);
    final draft = await _promptForConnectAccount(context, salon.email);
    if (!mounted) {
      return;
    }
    if (draft == null) {
      return;
    }
    setState(() => _isCreatingAccount = true);
    try {
      final service = ref.read(stripeConnectServiceProvider);
      await service.createAccount(
        email: draft.email,
        salonId: salon.id,
        businessType: draft.businessType,
      );
      if (!mounted || !context.mounted) return;
      context.showAppNotice(
        'Account Stripe creato (${draft.isCompany ? 'azienda' : 'persona fisica'}) per ${draft.email}. Continua con l\'onboarding per abilitare i pagamenti.',
        tone: AppNoticeTone.warning,
        duration: const Duration(seconds: 6),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showAppSnackBar(
        SnackBar(
          content: Text('Errore durante la creazione dell\'account: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingAccount = false);
      }
    }
  }

  Future<void> _handleStripeAccountLink(BuildContext context) async {
    final salon = widget.salon;
    final accountId = salon.stripeAccountId;
    if (accountId == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Nessun account Stripe collegato.')),
      );
      return;
    }
    setState(() => _isGeneratingLink = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(stripeConnectServiceProvider);
      final Uri url;
      if (salon.stripeAccount.detailsSubmitted) {
        url = await service.createDashboardLoginLink(
          salonId: salon.id,
          accountId: accountId,
        );
      } else {
        url = await service.createOnboardingLink(
          salonId: salon.id,
          accountId: accountId,
          returnUrl: _defaultReturnUrl,
          refreshUrl: _defaultRefreshUrl,
        );
      }
      if (!mounted) return;
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!launched) {
        messenger.showAppSnackBar(
          const SnackBar(content: Text('Impossibile aprire il link Stripe.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showAppSnackBar(
        SnackBar(
          content: Text('Errore durante la generazione del link: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingLink = false);
      }
    }
  }

  Future<void> _handleClientOnlinePaymentsToggle(
    BuildContext context,
    bool enabled,
  ) async {
    final salon = widget.salon;
    if (salon.featureFlags.clientOnlinePayments == enabled) {
      return;
    }

    setState(() => _isUpdatingClientOnlinePayments = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final store = ref.read(appDataProvider.notifier);
      final updatedFeatureFlags = salon.featureFlags.copyWith(
        clientOnlinePayments: enabled,
      );
      await store.updateSalonFeatureFlags(salon.id, updatedFeatureFlags);
      if (!mounted) {
        return;
      }
      messenger.showAppSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Pagamenti online clienti abilitati.'
                : 'Pagamenti online clienti disabilitati. I last-minute potranno essere prenotati con pagamento in centro.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showAppSnackBar(
        SnackBar(
          content: Text(
            'Impossibile aggiornare i pagamenti online del salone: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingClientOnlinePayments = false);
      }
    }
  }

  Future<_StripeConnectAccountDraft?> _promptForConnectAccount(
    BuildContext context,
    String? defaultEmail,
  ) async {
    final controller = TextEditingController(text: defaultEmail);
    var selectedBusinessType = 'individual';
    return showDialog<_StripeConnectAccountDraft>(
      context: context,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                title: const Text('Collega Stripe Connect'),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Email a cui intestare l\'account Stripe',
                        ),
                        autofocus: true,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Inserisci un indirizzo email valido';
                          }
                          final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          if (!emailRegex.hasMatch(text)) {
                            return 'Formato email non valido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedBusinessType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo soggetto',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'individual',
                            child: Text('Persona fisica'),
                          ),
                          DropdownMenuItem(
                            value: 'company',
                            child: Text('Azienda / ditta'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() => selectedBusinessType = value);
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Annulla'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        Navigator.of(dialogContext).pop(
                          _StripeConnectAccountDraft(
                            email: controller.text.trim(),
                            businessType: selectedBusinessType,
                          ),
                        );
                      }
                    },
                    child: const Text('Continua'),
                  ),
                ],
              ),
        );
      },
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    messenger.showAppSnackBar(
      const SnackBar(content: Text('ID account copiato negli appunti')),
    );
  }
}

class _WhatsAppSettingsCard extends ConsumerStatefulWidget {
  const _WhatsAppSettingsCard({required this.salonId});

  final String salonId;

  @override
  ConsumerState<_WhatsAppSettingsCard> createState() =>
      _WhatsAppSettingsCardState();
}

class _WhatsAppSettingsCardState extends ConsumerState<_WhatsAppSettingsCard> {
  bool _isDisconnecting = false;

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(whatsappConfigProvider(widget.salonId));

    return configAsync.when(
      data: (config) => _buildConfiguredCard(context, config),
      loading: () => _buildLoadingCard(context),
      error: (error, stack) => _buildErrorCard(context, error),
    );
  }

  Widget _buildConfiguredCard(BuildContext context, WhatsAppConfig? config) {
    final theme = Theme.of(context);
    final isConfigured = config?.isConfigured ?? false;
    final statusPalette = _connectionChipPalette(context, isConfigured);
    final infoBluePalette = _infoBlueChipPalette(context);
    final updatedAt = config?.updatedAt?.toLocal();
    final updatedAtLabel =
        updatedAt != null
            ? DateFormat('dd MMM yyyy HH:mm', 'it').format(updatedAt)
            : 'Mai aggiornato';
    final onboardingStatusLabel = _formatWhatsappOnboardingStatus(
      config?.onboardingStatus,
    );

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _WhatsAppLogoBadge(),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'WhatsApp',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(
                label: Text(isConfigured ? 'Collegato' : 'Da configurare'),
                visualDensity: const VisualDensity(
                  horizontal: -2,
                  vertical: -2,
                ),
                side: BorderSide(color: statusPalette.border),
                backgroundColor: statusPalette.background,
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  color: statusPalette.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final useTwoColumns = constraints.maxWidth >= 520;
              final tileWidth =
                  useTwoColumns
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _WhatsAppDetailRow(
                      icon: Icons.phone_iphone_rounded,
                      label: 'Numero',
                      value: config?.displayPhoneNumber ?? 'Non collegato',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _WhatsAppDetailRow(
                      icon: Icons.settings_rounded,
                      label: 'Modalità',
                      value: config?.mode ?? '—',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _WhatsAppDetailRow(
                      icon: Icons.sync_rounded,
                      label: 'Stato sync',
                      value: onboardingStatusLabel,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _WhatsAppDetailRow(
                      icon: Icons.history_rounded,
                      label: 'Ultimo aggiornamento',
                      value: updatedAtLabel,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (isConfigured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: infoBluePalette.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: infoBluePalette.border),
              ),
              child: Text(
                config?.needsVerification == true
                    ? 'Numero collegato ma ancora da verificare e registrare.'
                    : config?.needsReconnect == true
                    ? 'Connessione legacy disattivata. Apri il modulo WhatsApp e riconnetti con Embedded Signup.'
                    : 'Sincronizzato e pronto per la gestione dal modulo WhatsApp.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: infoBluePalette.foreground,
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openWhatsAppDetails,
              icon: Icon(
                isConfigured ? Icons.visibility_outlined : Icons.bolt_rounded,
                size: 18,
              ),
              label: Text(isConfigured ? 'Dettagli' : 'Configura'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (isConfigured) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _isDisconnecting
                          ? null
                          : () => _handleDisconnect(context),
                  icon:
                      _isDisconnecting
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.link_off_rounded, size: 18),
                  label: Text(
                    _isDisconnecting ? 'Disconnessione...' : 'Disconnetti',
                  ),
                ),
                TextButton.icon(
                  onPressed: _openWhatsAppDetails,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Apri modulo'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return _DashboardCard(
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Caricamento impostazioni WhatsApp...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, Object error) {
    final theme = Theme.of(context);
    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WhatsApp',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Impossibile recuperare la configurazione: $error',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed:
                () => ref.invalidate(whatsappConfigProvider(widget.salonId)),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  void _openWhatsAppDetails() {
    ref
        .read(adminDashboardIntentProvider.notifier)
        .state = const AdminDashboardIntent(moduleId: 'whatsapp');
  }

  String _formatWhatsappOnboardingStatus(String? status) {
    switch ((status ?? '').trim().toLowerCase()) {
      case 'ready':
        return 'Pronto';
      case 'awaiting_verification':
        return 'In attesa OTP';
      case 'registering':
        return 'Registrazione';
      case 'reconnect_required':
        return 'Da ricollegare';
      case 'error':
        return 'Errore';
      case 'disconnected':
        return 'Disconnesso';
      default:
        return 'Non configurato';
    }
  }

  Future<void> _handleDisconnect(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Disconnetti WhatsApp'),
            content: const Text(
              'Il numero collegato verrà scollegato. Continuare?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Disconnetti'),
              ),
            ],
          ),
    );

    if (confirm != true || !mounted) {
      return;
    }
    setState(() => _isDisconnecting = true);
    try {
      await ref.read(whatsappServiceProvider).disconnect(widget.salonId);
      if (!mounted) return;
      messenger.showAppSnackBar(
        const SnackBar(content: Text('Account WhatsApp scollegato.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showAppSnackBar(
        SnackBar(content: Text('Errore durante la disconnessione: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDisconnecting = false);
      }
    }
  }
}

class _WhatsAppDetailRow extends StatelessWidget {
  const _WhatsAppDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipPalette {
  const _ChipPalette({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SalonStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = _salonStatusChipPalette(context, status);
    return Chip(
      avatar: Icon(_statusIcon(status), size: 16, color: palette.foreground),
      label: Text(
        status.label,
        style: TextStyle(
          color: palette.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
      side: BorderSide(color: palette.border),
      backgroundColor: palette.background,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );
  }
}

Color _statusColor(BuildContext context, SalonStatus status) {
  final palette = _salonStatusChipPalette(context, status);
  return palette.foreground;
}

_ChipPalette _salonStatusChipPalette(BuildContext context, SalonStatus status) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  switch (status) {
    case SalonStatus.active:
      return isDark
          ? const _ChipPalette(
            foreground: Color(0xFF86EFAC),
            background: Color(0xFF10301D),
            border: Color(0xFF1F6F3D),
          )
          : const _ChipPalette(
            foreground: Color(0xFF22C55E),
            background: Color(0xFFE4F7EA),
            border: Color(0xFFB8E8C8),
          );
    case SalonStatus.suspended:
      return isDark
          ? const _ChipPalette(
            foreground: Color(0xFFFCD34D),
            background: Color(0xFF3A2A07),
            border: Color(0xFF7C5A12),
          )
          : const _ChipPalette(
            foreground: Color(0xFFB88315),
            background: Color(0xFFFAEFCF),
            border: Color(0xFFEBCB7B),
          );
    case SalonStatus.archived:
      return isDark
          ? const _ChipPalette(
            foreground: Color(0xFFD1D5DB),
            background: Color(0xFF262B33),
            border: Color(0xFF3F4752),
          )
          : const _ChipPalette(
            foreground: Color(0xFF6B7280),
            background: Color(0xFFF3F4F6),
            border: Color(0xFFD9DDE3),
          );
  }
}

_ChipPalette _connectionChipPalette(BuildContext context, bool connected) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (connected) {
    return isDark
        ? const _ChipPalette(
          foreground: Color(0xFF86EFAC),
          background: Color(0xFF10301D),
          border: Color(0xFF1F6F3D),
        )
        : const _ChipPalette(
          foreground: Color(0xFF22C55E),
          background: Color(0xFFE4F7EA),
          border: Color(0xFFB8E8C8),
        );
  }
  return isDark
      ? const _ChipPalette(
        foreground: Color(0xFFD1D5DB),
        background: Color(0xFF262B33),
        border: Color(0xFF3F4752),
      )
      : const _ChipPalette(
        foreground: Color(0xFF6B7280),
        background: Color(0xFFF3F4F6),
        border: Color(0xFFD9DDE3),
      );
}

_ChipPalette _infoBlueChipPalette(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? const _ChipPalette(
        foreground: Color(0xFF93C5FD),
        background: Color(0xFF0E2A47),
        border: Color(0xFF24507E),
      )
      : const _ChipPalette(
        foreground: Color(0xFF3B82F6),
        background: Color(0xFFEAF2FF),
        border: Color(0xFFC9DCFF),
      );
}

_ChipPalette _softErrorChipPalette(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? const _ChipPalette(
        foreground: Color(0xFFFCA5A5),
        background: Color(0xFF451315),
        border: Color(0xFF7F1D1D),
      )
      : const _ChipPalette(
        foreground: Color(0xFFDC2626),
        background: Color(0xFFFDEAEA),
        border: Color(0xFFF5C2C2),
      );
}

_ChipPalette _stripeChipPalette({
  required BuildContext context,
  required bool hasAccount,
  required bool onlinePaymentsEnabled,
  required bool readyForPayments,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (!hasAccount) {
    return isDark
        ? const _ChipPalette(
          foreground: Color(0xFFD1D5DB),
          background: Color(0xFF262B33),
          border: Color(0xFF3F4752),
        )
        : const _ChipPalette(
          foreground: Color(0xFF6B7280),
          background: Color(0xFFF3F4F6),
          border: Color(0xFFD9DDE3),
        );
  }
  if (!onlinePaymentsEnabled || !readyForPayments) {
    return isDark
        ? const _ChipPalette(
          foreground: Color(0xFFFCD34D),
          background: Color(0xFF3A2A07),
          border: Color(0xFF7C5A12),
        )
        : const _ChipPalette(
          foreground: Color(0xFFB88315),
          background: Color(0xFFFAEFCF),
          border: Color(0xFFEBCB7B),
        );
  }
  return isDark
      ? const _ChipPalette(
        foreground: Color(0xFF86EFAC),
        background: Color(0xFF10301D),
        border: Color(0xFF1F6F3D),
      )
      : const _ChipPalette(
        foreground: Color(0xFF22C55E),
        background: Color(0xFFE4F7EA),
        border: Color(0xFFB8E8C8),
      );
}

IconData _statusIcon(SalonStatus status) {
  switch (status) {
    case SalonStatus.active:
      return Icons.check_circle_rounded;
    case SalonStatus.suspended:
      return Icons.pause_circle_filled_rounded;
    case SalonStatus.archived:
      return Icons.inventory_2_rounded;
  }
}
