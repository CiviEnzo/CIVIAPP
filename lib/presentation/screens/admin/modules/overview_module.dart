import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/presentation/common/app_version_badge.dart';
import 'package:you_book/presentation/screens/admin/modules/client_detail_page.dart';
import 'package:you_book/presentation/shared/client_package_purchase.dart';
import 'package:you_book/widgets/shared/dashboard/kpi_card.dart' show Trend;

const int _clientBillingTabIndex = 6;
const int _clientPackagesTabIndex = 4;

class AdminOverviewModule extends ConsumerStatefulWidget {
  const AdminOverviewModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<AdminOverviewModule> createState() =>
      _AdminOverviewModuleState();
}

class _AdminOverviewModuleState extends ConsumerState<AdminOverviewModule> {
  _OverviewPeriodScope _selectedScope = _OverviewPeriodScope.month;

  @override
  Widget build(BuildContext context) {
    final store = ref.read(appDataProvider.notifier);
    final data = ref.watch(appDataProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final numberFormat = NumberFormat.decimalPattern('it_IT');
    final comparison = _buildComparisonWindow(now, _selectedScope);
    final todayComparison = _buildTodayComparisonWindow(now);

    final appointments = [
      ...store.reportingAppointments(salonId: widget.salonId),
    ]..sort((a, b) => a.start.compareTo(b.start));
    final appointmentsTodayCount =
        appointments
            .where(
              (appointment) =>
                  appointment.status != AppointmentStatus.cancelled &&
                  todayComparison.current.contains(appointment.start),
            )
            .length;
    final previousAppointmentsTodayCount =
        appointments
            .where(
              (appointment) =>
                  appointment.status != AppointmentStatus.cancelled &&
                  todayComparison.previous.contains(appointment.start),
            )
            .length;

    final clients = store.reportingClients(salonId: widget.salonId);
    final clientsById = {for (final client in clients) client.id: client};

    final services = data.services
        .where(
          (service) =>
              widget.salonId == null || service.salonId == widget.salonId,
        )
        .toList(growable: false);
    final packages = data.packages
        .where(
          (package) =>
              widget.salonId == null || package.salonId == widget.salonId,
        )
        .toList(growable: false);

    final sales = [...store.reportingSales(salonId: widget.salonId)]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final salesInPeriod = sales
        .where((sale) => comparison.current.contains(sale.createdAt))
        .toList(growable: false);
    final previousSales = sales
        .where((sale) => comparison.previous.contains(sale.createdAt))
        .toList(growable: false);
    final revenueBreakdown = _RevenueBreakdown.fromSales(salesInPeriod);
    final previousRevenueBreakdown = _RevenueBreakdown.fromSales(previousSales);
    final activePackageEntries = _buildActivePackageEntries(
      clients: clients,
      sales: sales,
      packages: packages,
      appointments: appointments,
      services: services,
      salonId: widget.salonId,
      asOf: comparison.current.end,
    );
    final activePackageCount = activePackageEntries.fold<int>(
      0,
      (total, entry) => total + entry.activePurchases.length,
    );
    final previousActivePackageCount = _countActivePackagePurchasesAt(
      clients: clients,
      sales: sales,
      packages: packages,
      appointments: appointments,
      services: services,
      salonId: widget.salonId,
      asOf: comparison.previous.end,
    );

    final posticipatedSales = sales
        .where(
          (sale) =>
              (sale.paymentStatus == SalePaymentStatus.posticipated ||
                  sale.paymentStatus == SalePaymentStatus.deposit) &&
              sale.outstandingAmount > 0.009,
        )
        .toList(growable: false);
    final posticipatedRevenue = posticipatedSales.fold<double>(
      0,
      (total, sale) => total + sale.outstandingAmount,
    );
    final posticipatedClientEntries = _buildPosticipatedEntries(
      sales: posticipatedSales,
      clientsById: clientsById,
    );

    final earnedPoints = sales.fold<int>(
      0,
      (total, sale) => total + sale.loyalty.resolvedEarnedPoints,
    );
    final redeemedPoints = sales.fold<int>(
      0,
      (total, sale) => total + sale.loyalty.redeemedPoints,
    );
    final spendableLoyaltyPoints = _countSpendableLoyaltyPointsAt(
      clients: clients,
      sales: sales,
      asOf: comparison.current.end,
    );
    final previousSpendableLoyaltyPoints = _countSpendableLoyaltyPointsAt(
      clients: clients,
      sales: sales,
      asOf: comparison.previous.end,
    );
    final periodLabel =
        _selectedScope == _OverviewPeriodScope.year ? 'Anno' : 'Mese';
    final selector = SegmentedButton<_OverviewPeriodScope>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment<_OverviewPeriodScope>(
          value: _OverviewPeriodScope.year,
          label: Text('Anno'),
        ),
        ButtonSegment<_OverviewPeriodScope>(
          value: _OverviewPeriodScope.month,
          label: Text('Mese'),
        ),
      ],
      selected: {_selectedScope},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) {
          return;
        }
        setState(() => _selectedScope = selection.first);
      },
    );

    final topCards = <Widget>[
      _OverviewMetricCard(
        title: 'Appuntamenti Oggi',
        value: numberFormat.format(appointmentsTodayCount),
        subtitle: 'Agenda del giorno',
        icon: Icons.calendar_today_rounded,
        accentColor: theme.colorScheme.primary,
        trend: _buildTrend(
          appointmentsTodayCount.toDouble(),
          previousAppointmentsTodayCount.toDouble(),
        ),
      ),
      _OverviewMetricCard(
        title: 'Pacchetti Attivi',
        value: numberFormat.format(activePackageCount),
        subtitle: 'Ancora utilizzabili',
        icon: Icons.inventory_2_outlined,
        accentColor: theme.colorScheme.secondary,
        onTap:
            activePackageEntries.isEmpty
                ? null
                : () => _showActivePackageClientsModal(
                  context,
                  entries: activePackageEntries,
                  activePackageCount: activePackageCount,
                ),
        trend: _buildTrend(
          activePackageCount.toDouble(),
          previousActivePackageCount.toDouble(),
        ),
      ),
      _OverviewMetricCard(
        title: 'Scontrini ($periodLabel)',
        value: numberFormat.format(salesInPeriod.length),
        subtitle: 'Registrati nel periodo',
        icon: Icons.shopping_cart_outlined,
        accentColor: theme.colorScheme.tertiary,
        trend: _buildTrend(
          salesInPeriod.length.toDouble(),
          previousSales.length.toDouble(),
        ),
      ),
      _OverviewMetricCard(
        title: 'Incasso $periodLabel',
        value: currency.format(revenueBreakdown.totalRevenue),
        subtitle: 'Servizi + Pacchetti',
        icon: Icons.euro_rounded,
        accentColor: theme.colorScheme.primary,
        trend: _buildTrend(
          revenueBreakdown.totalRevenue,
          previousRevenueBreakdown.totalRevenue,
        ),
      ),
    ];

    final bottomCards = <Widget>[
      _OverviewMetricCard(
        title: 'Incasso Posticipato',
        value: currency.format(posticipatedRevenue),
        subtitle:
            '${posticipatedClientEntries.length} clienti con saldo aperto',
        icon: Icons.schedule_rounded,
        accentColor: theme.colorScheme.tertiary,
        onTap:
            posticipatedClientEntries.isEmpty
                ? null
                : () => _showPosticipatedClientsModal(
                  context,
                  entries: posticipatedClientEntries,
                  totalOutstanding: posticipatedRevenue,
                ),
      ),
      _OverviewMetricCard(
        title: 'Punti Fedeltà Totali',
        value: numberFormat.format(spendableLoyaltyPoints),
        subtitle:
            'Assegnati: ${numberFormat.format(earnedPoints)} | Usati: ${numberFormat.format(redeemedPoints)}',
        icon: Icons.stars_rounded,
        accentColor: theme.colorScheme.primary,
        trend: _buildTrend(
          spendableLoyaltyPoints.toDouble(),
          previousSpendableLoyaltyPoints.toDouble(),
        ),
      ),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 720) {
                      return selector;
                    }
                    return Row(
                      children: [
                        Text(
                          'Confronto KPI',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        selector,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _OverviewCardGrid(topCards: topCards, bottomCards: bottomCards),
              ],
            ),
          ),
        ),
        const AppVersionBadge(),
      ],
    );
  }

  void _showPosticipatedClientsModal(
    BuildContext context, {
    required List<_ClientPosticipatedEntry> entries,
    required double totalOutstanding,
  }) {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    _showClientListModal(
      context,
      title: 'Clienti con importi da saldare',
      subtitle:
          '${entries.length} clienti • Da incassare ${currency.format(totalOutstanding)}',
      itemCount: entries.length,
      itemBuilder: (sheetContext, index) {
        final entry = entries[index];
        final latestDate = entry.sales.first.createdAt;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            child: Text(
              entry.client.firstName.characters.firstOrNull?.toUpperCase() ??
                  '?',
            ),
          ),
          title: _ClientNameLink(
            parentContext: context,
            modalContext: sheetContext,
            client: entry.client,
            initialTabIndex: _clientBillingTabIndex,
          ),
          subtitle: Text(
            '${entry.sales.length} vendite da saldare • Ultimo movimento ${DateFormat('dd/MM/yyyy', 'it_IT').format(latestDate)}',
          ),
          trailing: Text(
            currency.format(entry.outstandingAmount),
            style: Theme.of(
              sheetContext,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }

  void _showActivePackageClientsModal(
    BuildContext context, {
    required List<_ClientActivePackageEntry> entries,
    required int activePackageCount,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'it_IT');
    _showClientListModal(
      context,
      title: 'Clienti con pacchetti attivi',
      subtitle:
          '${entries.length} clienti • $activePackageCount pacchetti attivi',
      itemCount: entries.length,
      itemBuilder: (sheetContext, index) {
        final entry = entries[index];
        final nearestExpiration = entry.nearestExpirationDate;
        final packageNames = entry.packageNames;
        final visiblePackageNames = packageNames.take(2).join(', ');
        final additionalPackages =
            packageNames.length > 2 ? ' +${packageNames.length - 2}' : '';
        final subtitleParts = <String>[
          '${entry.activePurchases.length} pacchetti attivi',
          if (nearestExpiration != null)
            'Prima scadenza ${dateFormat.format(nearestExpiration)}',
        ];

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: CircleAvatar(
            child: Text(
              entry.client.firstName.characters.firstOrNull?.toUpperCase() ??
                  '?',
            ),
          ),
          title: _ClientNameLink(
            parentContext: context,
            modalContext: sheetContext,
            client: entry.client,
            initialTabIndex: _clientPackagesTabIndex,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(subtitleParts.join(' • ')),
              if (visiblePackageNames.isNotEmpty)
                Text(
                  '$visiblePackageNames$additionalPackages',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${entry.totalRemainingSessions}',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'sedute',
                style: Theme.of(sheetContext).textTheme.labelSmall,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showClientListModal(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int itemCount,
    required Widget Function(BuildContext sheetContext, int index) itemBuilder,
  }) {
    showDialog<void>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final media = MediaQuery.of(sheetContext);
        final maxHeight = media.size.height * 0.78;
        final dialogWidth =
            media.size.width < 720 ? media.size.width * 0.94 : 680.0;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight: maxHeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Chiudi',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child:
                      itemCount == 0
                          ? Center(
                            child: Text(
                              'Nessun elemento disponibile',
                              style: theme.textTheme.bodyLarge,
                            ),
                          )
                          : ListView.separated(
                            itemCount: itemCount,
                            itemBuilder: itemBuilder,
                            separatorBuilder:
                                (_, __) => const Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _OverviewPeriodScope { year, month }

class _OverviewCardGrid extends StatelessWidget {
  const _OverviewCardGrid({required this.topCards, required this.bottomCards});

  final List<Widget> topCards;
  final List<Widget> bottomCards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= 1180) {
          return Column(
            children: [
              _buildRow(topCards),
              const SizedBox(height: 16),
              _buildRow(bottomCards),
            ],
          );
        }
        if (width >= 720) {
          return Column(
            children: [
              _buildRow(topCards.take(2).toList(growable: false)),
              const SizedBox(height: 16),
              _buildRow(topCards.skip(2).toList(growable: false)),
              const SizedBox(height: 16),
              _buildRow(bottomCards),
            ],
          );
        }
        return Column(
          children: [
            for (final card in [...topCards, ...bottomCards]) ...[
              card,
              const SizedBox(height: 16),
            ],
          ]..removeLast(),
        );
      },
    );
  }

  Widget _buildRow(List<Widget> cards) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          Expanded(child: cards[index]),
          if (index < cards.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _OverviewMetricCard extends StatefulWidget {
  const _OverviewMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.accentColor,
    this.trend,
    this.onTap,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? accentColor;
  final Trend? trend;
  final VoidCallback? onTap;

  @override
  State<_OverviewMetricCard> createState() => _OverviewMetricCardState();
}

class _OverviewMetricCardState extends State<_OverviewMetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.accentColor ?? theme.colorScheme.primary;
    final borderColor =
        _isHovered
            ? accentColor.withValues(alpha: 0.5)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.9);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: accentColor, size: 18),
              ),
              const Spacer(),
              if (widget.trend != null)
                _OverviewTrendChip(trend: widget.trend!),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            widget.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child:
          widget.onTap == null
              ? card
              : InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: widget.onTap,
                child: card,
              ),
    );
  }
}

class _OverviewTrendChip extends StatelessWidget {
  const _OverviewTrendChip({required this.trend});

  final Trend trend;

  @override
  Widget build(BuildContext context) {
    final isPositive = trend.isPositive;
    final color =
        isPositive ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
    final background =
        isPositive ? const Color(0x1A22C55E) : const Color(0x1AEF4444);
    final icon =
        trend.isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded;
    final sign = trend.value >= 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$sign${trend.value}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientNameLink extends StatelessWidget {
  const _ClientNameLink({
    required this.parentContext,
    required this.modalContext,
    required this.client,
    this.initialTabIndex = 0,
  });

  final BuildContext parentContext;
  final BuildContext modalContext;
  final Client client;
  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () {
          Navigator.of(modalContext).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            openClientDetailPage(
              parentContext,
              clientId: client.id,
              initialTabIndex: initialTabIndex,
            );
          });
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          alignment: Alignment.centerLeft,
          foregroundColor: theme.colorScheme.primary,
        ),
        child: Text(
          client.fullName,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

class _ComparisonWindow {
  const _ComparisonWindow({required this.current, required this.previous});

  final _TimeWindow current;
  final _TimeWindow previous;
}

class _TimeWindow {
  const _TimeWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) {
    return !value.isBefore(start) && !value.isAfter(end);
  }
}

class _RevenueBreakdown {
  const _RevenueBreakdown({
    required this.totalRevenue,
    required this.servicesRevenue,
    required this.packagesRevenue,
  });

  final double totalRevenue;
  final double servicesRevenue;
  final double packagesRevenue;

  factory _RevenueBreakdown.fromSales(List<Sale> sales) {
    var servicesRevenue = 0.0;
    var packagesRevenue = 0.0;
    final totalRevenue = sales.fold<double>(
      0,
      (total, sale) => total + sale.total,
    );
    for (final sale in sales) {
      final serviceGross = sale.items
          .where((item) => item.referenceType == SaleReferenceType.service)
          .fold<double>(0, (sum, item) => sum + item.amount);
      final packageGross = sale.items
          .where((item) => item.referenceType == SaleReferenceType.package)
          .fold<double>(0, (sum, item) => sum + item.amount);
      final saleItemsGross = sale.items.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );
      final loyaltyDiscount =
          sale.loyalty.redeemedValue <= 0
              ? 0.0
              : sale.loyalty.redeemedValue > saleItemsGross
              ? saleItemsGross
              : sale.loyalty.redeemedValue;
      final serviceLoyaltyShare =
          saleItemsGross <= 0 || loyaltyDiscount <= 0
              ? 0.0
              : loyaltyDiscount * (serviceGross / saleItemsGross);
      final packageLoyaltyShare =
          saleItemsGross <= 0 || loyaltyDiscount <= 0
              ? 0.0
              : loyaltyDiscount * (packageGross / saleItemsGross);
      servicesRevenue += serviceGross - serviceLoyaltyShare;
      packagesRevenue += packageGross - packageLoyaltyShare;
    }
    return _RevenueBreakdown(
      totalRevenue: double.parse(totalRevenue.toStringAsFixed(2)),
      servicesRevenue: double.parse(servicesRevenue.toStringAsFixed(2)),
      packagesRevenue: double.parse(packagesRevenue.toStringAsFixed(2)),
    );
  }
}

class _ClientPosticipatedEntry {
  const _ClientPosticipatedEntry({
    required this.client,
    required this.sales,
    required this.outstandingAmount,
  });

  final Client client;
  final List<Sale> sales;
  final double outstandingAmount;
}

class _ClientActivePackageEntry {
  const _ClientActivePackageEntry({
    required this.client,
    required this.activePurchases,
  });

  final Client client;
  final List<ClientPackagePurchase> activePurchases;

  int get totalRemainingSessions => activePurchases.fold<int>(
    0,
    (total, purchase) => total + purchase.effectiveRemainingSessions,
  );

  DateTime? get nearestExpirationDate {
    DateTime? nearest;
    for (final purchase in activePurchases) {
      final expiration = purchase.expirationDate;
      if (expiration == null) {
        continue;
      }
      if (nearest == null || expiration.isBefore(nearest)) {
        nearest = expiration;
      }
    }
    return nearest;
  }

  List<String> get packageNames => activePurchases
      .map((purchase) => purchase.displayName.trim())
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

_ComparisonWindow _buildComparisonWindow(
  DateTime now,
  _OverviewPeriodScope scope,
) {
  switch (scope) {
    case _OverviewPeriodScope.year:
      final previousEnd = _copyWithClampedDay(
        source: now,
        year: now.year - 1,
        month: now.month,
      );
      return _ComparisonWindow(
        current: _TimeWindow(start: DateTime(now.year, 1, 1), end: now),
        previous: _TimeWindow(
          start: DateTime(now.year - 1, 1, 1),
          end: previousEnd,
        ),
      );
    case _OverviewPeriodScope.month:
      final previousEnd = _addMonthsClamped(now, -1);
      return _ComparisonWindow(
        current: _TimeWindow(start: DateTime(now.year, now.month, 1), end: now),
        previous: _TimeWindow(
          start: DateTime(previousEnd.year, previousEnd.month, 1),
          end: previousEnd,
        ),
      );
  }
}

_ComparisonWindow _buildTodayComparisonWindow(DateTime now) {
  final currentStart = DateTime(now.year, now.month, now.day);
  final currentEnd = currentStart
      .add(const Duration(days: 1))
      .subtract(const Duration(microseconds: 1));
  final previousStart = currentStart.subtract(const Duration(days: 7));
  final previousEnd = previousStart
      .add(const Duration(days: 1))
      .subtract(const Duration(microseconds: 1));
  return _ComparisonWindow(
    current: _TimeWindow(start: currentStart, end: currentEnd),
    previous: _TimeWindow(start: previousStart, end: previousEnd),
  );
}

DateTime _addMonthsClamped(DateTime source, int deltaMonths) {
  final totalMonths = source.year * 12 + source.month - 1 + deltaMonths;
  final year = totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  return _copyWithClampedDay(source: source, year: year, month: month);
}

DateTime _copyWithClampedDay({
  required DateTime source,
  required int year,
  required int month,
}) {
  final lastDay = DateUtils.getDaysInMonth(year, month);
  final day = source.day.clamp(1, lastDay);
  return DateTime(
    year,
    month,
    day,
    source.hour,
    source.minute,
    source.second,
    source.millisecond,
    source.microsecond,
  );
}

Trend? _buildTrend(
  double currentValue,
  double previousValue, {
  bool higherIsBetter = true,
}) {
  if (previousValue <= 0) {
    return null;
  }
  final deltaPercent = ((currentValue - previousValue) / previousValue) * 100;
  final roundedPercent = deltaPercent.round();
  if (roundedPercent == 0) {
    return null;
  }
  return Trend(
    value: roundedPercent,
    isPositive: higherIsBetter ? deltaPercent >= 0 : deltaPercent <= 0,
    isUp: deltaPercent >= 0,
  );
}

int _countActivePackagePurchasesAt({
  required List<Client> clients,
  required List<Sale> sales,
  required List<ServicePackage> packages,
  required List<Appointment> appointments,
  required List<Service> services,
  required DateTime asOf,
  String? salonId,
}) {
  if (clients.isEmpty || sales.isEmpty) {
    return 0;
  }
  final relevantSales = sales
      .where((sale) => !sale.createdAt.isAfter(asOf))
      .toList(growable: false);
  final relevantAppointments = appointments
      .where((appointment) => !appointment.start.isAfter(asOf))
      .toList(growable: false);
  final salesByClient = groupBy(relevantSales, (Sale sale) => sale.clientId);
  final appointmentsByClient = groupBy(
    relevantAppointments,
    (Appointment appointment) => appointment.clientId,
  );
  var total = 0;
  for (final client in clients) {
    final clientSales = salesByClient[client.id];
    if (clientSales == null || clientSales.isEmpty) {
      continue;
    }
    final purchases = resolveClientPackagePurchases(
      sales: clientSales,
      packages: packages,
      appointments: appointmentsByClient[client.id] ?? const <Appointment>[],
      services: services,
      clientId: client.id,
      salonId: salonId,
    );
    total +=
        purchases
            .where(
              (purchase) =>
                  purchase.isActive &&
                  (purchase.expirationDate == null ||
                      !purchase.expirationDate!.isBefore(asOf)),
            )
            .length;
  }
  return total;
}

List<_ClientActivePackageEntry> _buildActivePackageEntries({
  required List<Client> clients,
  required List<Sale> sales,
  required List<ServicePackage> packages,
  required List<Appointment> appointments,
  required List<Service> services,
  required DateTime asOf,
  String? salonId,
}) {
  if (clients.isEmpty || sales.isEmpty) {
    return const <_ClientActivePackageEntry>[];
  }
  final relevantSales = sales
      .where((sale) => !sale.createdAt.isAfter(asOf))
      .toList(growable: false);
  final relevantAppointments = appointments
      .where((appointment) => !appointment.start.isAfter(asOf))
      .toList(growable: false);
  final salesByClient = groupBy(relevantSales, (Sale sale) => sale.clientId);
  final appointmentsByClient = groupBy(
    relevantAppointments,
    (Appointment appointment) => appointment.clientId,
  );

  return clients
      .map((client) {
        final clientSales = salesByClient[client.id];
        if (clientSales == null || clientSales.isEmpty) {
          return null;
        }
        final purchases = resolveClientPackagePurchases(
          sales: clientSales,
          packages: packages,
          appointments:
              appointmentsByClient[client.id] ?? const <Appointment>[],
          services: services,
          clientId: client.id,
          salonId: salonId,
        );
        final activePurchases = purchases
            .where(
              (purchase) =>
                  purchase.isActive &&
                  (purchase.expirationDate == null ||
                      !purchase.expirationDate!.isBefore(asOf)),
            )
            .toList(growable: false);
        if (activePurchases.isEmpty) {
          return null;
        }
        return _ClientActivePackageEntry(
          client: client,
          activePurchases: List.unmodifiable(activePurchases),
        );
      })
      .whereType<_ClientActivePackageEntry>()
      .sorted((a, b) {
        final byCount = b.activePurchases.length.compareTo(
          a.activePurchases.length,
        );
        if (byCount != 0) {
          return byCount;
        }
        final byRemaining = b.totalRemainingSessions.compareTo(
          a.totalRemainingSessions,
        );
        if (byRemaining != 0) {
          return byRemaining;
        }
        return a.client.fullName.toLowerCase().compareTo(
          b.client.fullName.toLowerCase(),
        );
      });
}

int _countSpendableLoyaltyPointsAt({
  required List<Client> clients,
  required List<Sale> sales,
  required DateTime asOf,
}) {
  final filteredSales = sales
      .where((sale) => !sale.createdAt.isAfter(asOf))
      .toList(growable: false);
  final salesByClient = groupBy(filteredSales, (Sale sale) => sale.clientId);
  var total = 0;
  for (final client in clients) {
    final anchor = _resolveClientAnchor(client);
    if (anchor != null && anchor.isAfter(asOf)) {
      continue;
    }
    final clientSales = salesByClient[client.id] ?? const <Sale>[];
    final earned = clientSales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.resolvedEarnedPoints,
    );
    final redeemed = clientSales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.redeemedPoints,
    );
    final balance = (client.loyaltyInitialPoints + earned - redeemed).clamp(
      0,
      1 << 31,
    );
    total += balance;
  }
  return total;
}

DateTime? _resolveClientAnchor(Client client) {
  final directAnchor =
      client.createdAt ??
      client.onboardingCompletedAt ??
      client.firstLoginAt ??
      client.invitationSentAt;
  if (directAnchor != null) {
    return directAnchor;
  }
  final rawClientNumber = client.clientNumber;
  if (rawClientNumber == null || rawClientNumber.length != 12) {
    return null;
  }
  final year = int.tryParse(rawClientNumber.substring(0, 4));
  final month = int.tryParse(rawClientNumber.substring(4, 6));
  final day = int.tryParse(rawClientNumber.substring(6, 8));
  final hour = int.tryParse(rawClientNumber.substring(8, 10));
  final minute = int.tryParse(rawClientNumber.substring(10, 12));
  if (year == null ||
      month == null ||
      day == null ||
      hour == null ||
      minute == null) {
    return null;
  }
  if (month < 1 || month > 12) {
    return null;
  }
  final lastDay = DateUtils.getDaysInMonth(year, month);
  if (day < 1 || day > lastDay) {
    return null;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return DateTime(year, month, day, hour, minute);
}

List<_ClientPosticipatedEntry> _buildPosticipatedEntries({
  required List<Sale> sales,
  required Map<String, Client> clientsById,
}) {
  return groupBy(sales, (Sale sale) => sale.clientId).entries
      .map((entry) {
        final client = clientsById[entry.key];
        if (client == null) {
          return null;
        }
        final clientSales = [...entry.value]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final outstandingAmount = clientSales.fold<double>(
          0,
          (total, sale) => total + sale.outstandingAmount,
        );
        return _ClientPosticipatedEntry(
          client: client,
          sales: List.unmodifiable(clientSales),
          outstandingAmount: outstandingAmount,
        );
      })
      .whereType<_ClientPosticipatedEntry>()
      .sorted((a, b) {
        final byAmount = b.outstandingAmount.compareTo(a.outstandingAmount);
        if (byAmount != 0) {
          return byAmount;
        }
        return a.client.fullName.toLowerCase().compareTo(
          b.client.fullName.toLowerCase(),
        );
      });
}
