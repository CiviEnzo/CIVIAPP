import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/app/reporting_config.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_aggregator.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_export_service.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_models.dart';
import 'package:you_book/presentation/screens/admin/widgets/admin_responsive_helpers.dart';

class ReportsModule extends ConsumerStatefulWidget {
  const ReportsModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<ReportsModule> createState() => _ReportsModuleState();
}

class _ReportsModuleState extends ConsumerState<ReportsModule> {
  late ReportFilters _filters;
  var _activeTab = ReportsTab.dashboard;
  var _previewMetric = ReportPreviewMetric.sales;
  var _selectedSection = ReportAnalyticsSection.sales;
  final _analyticsScrollController = ScrollController();
  final _exportService = const ReportExportService();
  final _sectionKeys = {
    for (final section in ReportAnalyticsSection.values) section: GlobalKey(),
  };
  bool _restoredFromQuery = false;
  String? _lastReportQuerySignature;
  bool _isExportingPdf = false;
  final Set<ReportExportDataset> _exportingDatasets = <ReportExportDataset>{};
  bool _exportingAllCsv = false;

  @override
  void initState() {
    super.initState();
    _filters = ReportFilters.initial(defaultSalonId: widget.salonId);
  }

  @override
  void dispose() {
    _analyticsScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routerState = GoRouterState.of(context);
    final reportQuerySignature = _reportQuerySignature(routerState.uri);
    final restoredFilters = ReportFilters.fromUri(
      routerState.uri,
      defaultSalonId: widget.salonId ?? _filters.salonId,
    );
    final restoredTab = ReportsTabX.fromQuery(
      routerState.uri.queryParameters[ReportsQueryKeys.tab],
    );

    if (!_restoredFromQuery) {
      _filters = restoredFilters;
      _activeTab = restoredTab;
      _restoredFromQuery = true;
      _lastReportQuerySignature = reportQuerySignature;
      return;
    }

    if (_lastReportQuerySignature == reportQuerySignature) {
      return;
    }
    _lastReportQuerySignature = reportQuerySignature;

    if (_filters != restoredFilters || _activeTab != restoredTab) {
      setState(() {
        _filters = restoredFilters;
        _activeTab = restoredTab;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ReportsModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.salonId != widget.salonId) {
      final nextSalon = widget.salonId;
      if (nextSalon != null &&
          (_filters.salonId == null || _filters.salonId == oldWidget.salonId)) {
        _updateFilters(
          _filters.copyWith(salonId: nextSalon),
          persistQuery: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final snapshot = ReportsAggregator.build(data: data, filters: _filters);
    final theme = Theme.of(context);
    final isMobileLayout =
        MediaQuery.sizeOf(context).width < kAdminStackBreakpoint;
    final currency = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
      decimalDigits: 2,
    );
    final periodFormatter = DateFormat('dd/MM/yyyy');
    final activeSalonId = _filters.salonId;
    final selectedCategoryId = _filters.categoryIds.singleOrNull;
    final staffMembers = data.staff
        .where(
          (member) =>
              (activeSalonId == null || member.salonId == activeSalonId) &&
              member.isActive &&
              !member.isEquipment,
        )
        .toList(growable: false);
    final categories = data.serviceCategories
        .where(
          (category) =>
              activeSalonId == null || category.salonId == activeSalonId,
        )
        .sortedBy((category) => category.name.toLowerCase())
        .toList(growable: false);
    final services = data.services
        .where(
          (service) =>
              activeSalonId == null || service.salonId == activeSalonId,
        )
        .toList(growable: false);
    final serviceOptions =
        selectedCategoryId == null
            ? services
            : services
                .where((service) => service.categoryId == selectedCategoryId)
                .toList(growable: false);
    final bookingChannels =
        data.appointments
            .where(
              (appointment) =>
                  activeSalonId == null || appointment.salonId == activeSalonId,
            )
            .map((appointment) => appointment.bookingChannel?.trim())
            .whereType<String>()
            .where((channel) => channel.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final body = switch (_activeTab) {
      ReportsTab.dashboard => _buildDashboardTab(
        context: context,
        snapshot: snapshot,
        currency: currency,
      ),
      ReportsTab.analytics => _buildAnalyticsTab(
        context: context,
        snapshot: snapshot,
        currency: currency,
      ),
      ReportsTab.export => _buildExportTab(
        context: context,
        snapshot: snapshot,
        currency: currency,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobileLayout ? 16 : 20,
              vertical: isMobileLayout ? 16 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReportsFiltersBar(
                  range: _filters.range,
                  dateFormatter: periodFormatter,
                  onRangeChanged: (range) {
                    _updateFilters(
                      _filters.copyWith(
                        range: ReportComparisonWindow.normalizeRange(range),
                      ),
                    );
                  },
                  staffMembers: staffMembers,
                  selectedOperatorId: _filters.operatorIds.singleOrNull,
                  onOperatorChanged: (operatorId) {
                    _updateFilters(
                      _filters.copyWith(
                        operatorIds:
                            operatorId == null || operatorId.isEmpty
                                ? <String>{}
                                : <String>{operatorId},
                      ),
                    );
                  },
                  categories: categories,
                  selectedCategoryId: selectedCategoryId,
                  onCategoryChanged: (categoryId) {
                    _updateFilters(
                      _filters.copyWith(
                        categoryIds:
                            categoryId == null || categoryId.isEmpty
                                ? <String>{}
                                : <String>{categoryId},
                        serviceIds: <String>{},
                      ),
                    );
                  },
                  services: serviceOptions,
                  selectedServiceId: _filters.serviceIds.singleOrNull,
                  onServiceChanged: (serviceId) {
                    _updateFilters(
                      _filters.copyWith(
                        serviceIds:
                            serviceId == null || serviceId.isEmpty
                                ? <String>{}
                                : <String>{serviceId},
                      ),
                    );
                  },
                  bookingChannels: bookingChannels,
                  selectedBookingChannel: _filters.bookingChannels.singleOrNull,
                  onBookingChannelChanged: (bookingChannel) {
                    _updateFilters(
                      _filters.copyWith(
                        bookingChannels:
                            bookingChannel == null || bookingChannel.isEmpty
                                ? <String>{}
                                : <String>{bookingChannel},
                      ),
                    );
                  },
                  compact: isMobileLayout,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isMobileLayout ? 6 : 8),
        Card(
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobileLayout ? 12 : 20,
              vertical: isMobileLayout ? 10 : 16,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabs = SegmentedButton<ReportsTab>(
                  showSelectedIcon: false,
                  style:
                      isMobileLayout
                          ? ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            textStyle: WidgetStatePropertyAll(
                              theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          : null,
                  segments: ReportsTab.values
                      .map(
                        (tab) => ButtonSegment<ReportsTab>(
                          value: tab,
                          label: Text(tab.label),
                        ),
                      )
                      .toList(growable: false),
                  selected: {_activeTab},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    _setActiveTab(selection.first);
                  },
                );

                final cutoffChip =
                    kReportingCutoff == null
                        ? null
                        : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Dati inclusi dal ${periodFormatter.format(kReportingCutoff!.toLocal())}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );

                if (cutoffChip == null || constraints.maxWidth < 980) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tabs,
                      if (cutoffChip != null) ...[
                        const SizedBox(height: 12),
                        cutoffChip,
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: tabs),
                    const SizedBox(width: 16),
                    cutoffChip,
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey<String>(
                'reports_${_activeTab.name}_${_filters.hashCode}',
              ),
              child: body,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardTab({
    required BuildContext context,
    required ReportsSnapshot snapshot,
    required NumberFormat currency,
  }) {
    final theme = Theme.of(context);
    final preview = _previewData(snapshot, currency);
    final secondaryMetrics = <_SecondaryMetricDefinition>[
      _SecondaryMetricDefinition(
        title: 'Appuntamenti completati',
        value: '${snapshot.current.completedAppointments}',
        subtitle: _formatDelta(
          current: snapshot.current.completedAppointments.toDouble(),
          previous: snapshot.previous.completedAppointments.toDouble(),
        ),
        icon: Icons.event_available_rounded,
      ),
      _SecondaryMetricDefinition(
        title: 'Tasso cancellazioni',
        value: _formatPercent(snapshot.current.cancellationRate),
        subtitle: _formatDelta(
          current: snapshot.current.cancellationRate,
          previous: snapshot.previous.cancellationRate,
          isRate: true,
        ),
        icon: Icons.event_busy_rounded,
      ),
      _SecondaryMetricDefinition(
        title: 'Tasso no-show',
        value: _formatPercent(snapshot.current.noShowRate),
        subtitle: _formatDelta(
          current: snapshot.current.noShowRate,
          previous: snapshot.previous.noShowRate,
          isRate: true,
        ),
        icon: Icons.person_off_rounded,
      ),
      _SecondaryMetricDefinition(
        title: 'Clienti di ritorno',
        value: _formatPercent(snapshot.current.returningClientsRate),
        subtitle:
            '${snapshot.current.returningClients}/${snapshot.current.activeClients} attivi',
        icon: Icons.repeat_rounded,
      ),
      _SecondaryMetricDefinition(
        title: 'Valore medio per cliente',
        value: currency.format(snapshot.current.averageRevenuePerClient),
        subtitle:
            'Clienti attivi nel periodo: ${snapshot.current.activeClients}',
        icon: Icons.savings_rounded,
      ),
      _SecondaryMetricDefinition(
        title: 'Alert magazzino',
        value: '${snapshot.inventoryAlerts.length}',
        subtitle:
            snapshot.inventoryAlerts.isEmpty
                ? 'Nessuna criticita'
                : 'Stock sotto soglia',
        icon: Icons.inventory_rounded,
      ),
    ];

    return SingleChildScrollView(
      key: const ValueKey<String>('reports_dashboard'),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _HeroMetricCard(
                title: 'Fatturato periodo',
                value: currency.format(snapshot.current.totalRevenue),
                icon: Icons.account_balance_wallet_rounded,
                deltaLabel: _formatDelta(
                  current: snapshot.current.totalRevenue,
                  previous: snapshot.previous.totalRevenue,
                ),
                accentColor: const Color(0xFF15803D),
              ),
              _HeroMetricCard(
                title: 'Nuovi clienti',
                value: '${snapshot.current.newClients}',
                icon: Icons.person_add_alt_1_rounded,
                deltaLabel: _formatDelta(
                  current: snapshot.current.newClients.toDouble(),
                  previous: snapshot.previous.newClients.toDouble(),
                ),
                accentColor: theme.colorScheme.primary,
              ),
              _HeroMetricCard(
                title: 'Tasso occupazione',
                value: _formatOccupancy(snapshot.current.occupancy),
                icon: Icons.analytics_rounded,
                deltaLabel: _formatDelta(
                  current: snapshot.current.occupancy.ratio,
                  previous: snapshot.previous.occupancy.ratio,
                  isRate: true,
                ),
                accentColor: theme.colorScheme.tertiary,
                badgeLabel:
                    snapshot.current.occupancy.estimated ? 'Stimato' : null,
              ),
              _HeroMetricCard(
                title: 'Ticket medio',
                value: currency.format(snapshot.current.averageTicket),
                icon: Icons.receipt_long_rounded,
                deltaLabel: _formatDelta(
                  current: snapshot.current.averageTicket,
                  previous: snapshot.previous.averageTicket,
                ),
                accentColor: const Color(0xFFD97706),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              final shortcuts = _DashboardShortcutCard(
                onSelectSales:
                    () => _jumpToAnalyticsSection(ReportAnalyticsSection.sales),
                onSelectStaff:
                    () => _jumpToAnalyticsSection(ReportAnalyticsSection.staff),
                onSelectClients:
                    () =>
                        _jumpToAnalyticsSection(ReportAnalyticsSection.clients),
                onSelectInventory:
                    () => _jumpToAnalyticsSection(
                      ReportAnalyticsSection.inventory,
                    ),
                onSelectMarketing:
                    () => _jumpToAnalyticsSection(
                      ReportAnalyticsSection.marketing,
                    ),
              );
              final previewCard = _PreviewAnalyticsCard(
                previewMetric: _previewMetric,
                onMetricSelected:
                    (metric) => setState(() => _previewMetric = metric),
                title: preview.title,
                subtitle: preview.subtitle,
                badgeLabel: preview.badgeLabel,
                dateFormatter: preview.dateFormatter,
                points: preview.points,
                valueLabelBuilder: preview.valueLabelBuilder,
                tooltipBuilder: preview.tooltipBuilder,
                emptyMessage: preview.emptyMessage,
              );

              if (!isWide) {
                return Column(
                  children: [
                    shortcuts,
                    const SizedBox(height: 16),
                    previewCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 360, child: shortcuts),
                  const SizedBox(width: 16),
                  Expanded(child: previewCard),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Indicatori operativi',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: secondaryMetrics
                .map((metric) => _SecondaryMetricCard(metric: metric))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab({
    required BuildContext context,
    required ReportsSnapshot snapshot,
    required NumberFormat currency,
  }) {
    final theme = Theme.of(context);
    final trendFormatter = _trendDateFormatter(snapshot.trendGranularity);

    return CustomScrollView(
      key: const ValueKey<String>('reports_analytics'),
      controller: _analyticsScrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          sliver: SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedHeaderDelegate(
              extent: 64,
              child: Container(
                color: theme.colorScheme.surfaceContainerLowest,
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ReportAnalyticsSection.values
                        .map(
                          (section) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ChoiceChip(
                              label: Text(section.label),
                              selected: _selectedSection == section,
                              onSelected:
                                  (_) => _jumpToAnalyticsSection(section),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AnalyticsSection(
                  key: _sectionKeys[ReportAnalyticsSection.sales],
                  title: 'Vendite',
                  description:
                      'Trend fatturato, ticket medio e servizi a maggiore resa.',
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _MiniInsightCard(
                            title: 'Incasso',
                            value: currency.format(
                              snapshot.current.totalRevenue,
                            ),
                            subtitle: _formatDelta(
                              current: snapshot.current.totalRevenue,
                              previous: snapshot.previous.totalRevenue,
                            ),
                          ),
                          _MiniInsightCard(
                            title: 'Ticket medio',
                            value: currency.format(
                              snapshot.current.averageTicket,
                            ),
                            subtitle: _formatDelta(
                              current: snapshot.current.averageTicket,
                              previous: snapshot.previous.averageTicket,
                            ),
                          ),
                          _MiniInsightCard(
                            title: 'Vendite registrate',
                            value: '${snapshot.current.salesCount}',
                            subtitle: 'Periodo corrente',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final chart = _TrendPanel(
                            title: 'Trend fatturato',
                            subtitle:
                                'Aggregazione ${_granularityLabel(snapshot.trendGranularity)}',
                            points: snapshot.revenueTrend,
                            dateFormatter: trendFormatter,
                            valueLabelBuilder: currency.format,
                            tooltipBuilder: currency.format,
                            emptyMessage:
                                'Nessuna vendita nel periodo selezionato',
                          );
                          final categories = _SimpleValueTableCard(
                            title: 'Fatturato per categoria',
                            emptyMessage: 'Nessuna categoria disponibile',
                            rows: snapshot.revenueByCategory
                                .map(
                                  (entry) => _ValueTableRow(
                                    label: entry.label,
                                    value: currency.format(entry.revenue),
                                  ),
                                )
                                .toList(growable: false),
                          );
                          if (constraints.maxWidth < 980) {
                            return Column(
                              children: [
                                chart,
                                const SizedBox(height: 16),
                                categories,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: chart),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: categories),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _TopServicesTable(
                        entries: snapshot.topServices,
                        currency: currency,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _AnalyticsSection(
                  key: _sectionKeys[ReportAnalyticsSection.appointments],
                  title: 'Appuntamenti',
                  description:
                      'Volumi, qualità operativa e mix dei canali di prenotazione.',
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _MiniInsightCard(
                            title: 'Completati',
                            value: '${snapshot.current.completedAppointments}',
                            subtitle:
                                'Completion rate ${_formatPercent(snapshot.current.completionRate)}',
                          ),
                          _MiniInsightCard(
                            title: 'Cancellazioni',
                            value: _formatPercent(
                              snapshot.current.cancellationRate,
                            ),
                            subtitle:
                                '${snapshot.current.cancelledAppointments}/${snapshot.current.totalAppointments}',
                          ),
                          _MiniInsightCard(
                            title: 'No-show',
                            value: _formatPercent(snapshot.current.noShowRate),
                            subtitle:
                                '${snapshot.current.noShowAppointments}/${snapshot.current.totalAppointments}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final chart = _TrendPanel(
                            title: 'Trend appuntamenti',
                            subtitle:
                                'Aggregazione ${_granularityLabel(snapshot.trendGranularity)}',
                            points: snapshot.appointmentTrend,
                            dateFormatter: trendFormatter,
                            valueLabelBuilder:
                                (value) => value.toInt().toString(),
                            tooltipBuilder:
                                (value) => '${value.toInt()} appuntamenti',
                            emptyMessage:
                                'Nessun appuntamento nel periodo selezionato',
                          );
                          final channels = _SimpleValueTableCard(
                            title: 'Mix canali prenotazione',
                            emptyMessage: 'Nessun canale disponibile',
                            rows: snapshot.bookingChannelMix
                                .map(
                                  (entry) => _ValueTableRow(
                                    label: entry.label,
                                    value: entry.value.toInt().toString(),
                                  ),
                                )
                                .toList(growable: false),
                          );
                          if (constraints.maxWidth < 980) {
                            return Column(
                              children: [
                                chart,
                                const SizedBox(height: 16),
                                channels,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: chart),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: channels),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _AppointmentStatusTable(
                        appointments: snapshot.filteredAppointments,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _AnalyticsSection(
                  key: _sectionKeys[ReportAnalyticsSection.clients],
                  title: 'Clienti',
                  description:
                      'Acquisizione, ritorno e fonti di provenienza del periodo.',
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _MiniInsightCard(
                            title: 'Nuovi clienti',
                            value: '${snapshot.current.newClients}',
                            subtitle: _formatDelta(
                              current: snapshot.current.newClients.toDouble(),
                              previous: snapshot.previous.newClients.toDouble(),
                            ),
                          ),
                          _MiniInsightCard(
                            title: 'Clienti attivi',
                            value: '${snapshot.current.activeClients}',
                            subtitle:
                                'Con almeno una vendita o un appuntamento',
                          ),
                          _MiniInsightCard(
                            title: 'Clienti di ritorno',
                            value: _formatPercent(
                              snapshot.current.returningClientsRate,
                            ),
                            subtitle:
                                '${snapshot.current.returningClients}/${snapshot.current.activeClients} attivi',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final chart = _TrendPanel(
                            title: 'Trend nuovi clienti',
                            subtitle:
                                'Aggregazione ${_granularityLabel(snapshot.trendGranularity)}',
                            points: snapshot.clientTrend,
                            dateFormatter: trendFormatter,
                            valueLabelBuilder:
                                (value) => value.toInt().toString(),
                            tooltipBuilder:
                                (value) => '${value.toInt()} nuovi clienti',
                            emptyMessage:
                                'Nessun nuovo cliente nel periodo selezionato',
                          );
                          final referral = _SimpleValueTableCard(
                            title: 'Referral source',
                            emptyMessage: 'Nessuna fonte disponibile',
                            rows: snapshot.referralSources
                                .map(
                                  (entry) => _ValueTableRow(
                                    label: entry.label,
                                    value: entry.value.toInt().toString(),
                                  ),
                                )
                                .toList(growable: false),
                          );
                          if (constraints.maxWidth < 980) {
                            return Column(
                              children: [
                                chart,
                                const SizedBox(height: 16),
                                referral,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: chart),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: referral),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _AnalyticsSection(
                  key: _sectionKeys[ReportAnalyticsSection.staff],
                  title: 'Staff',
                  description:
                      'Produttivita, ticket medio e occupazione per operatore.',
                  child: _StaffPerformanceTable(
                    rows: snapshot.staffPerformance,
                    currency: currency,
                  ),
                ),
                const SizedBox(height: 18),
                _AnalyticsSection(
                  key: _sectionKeys[ReportAnalyticsSection.inventory],
                  title: 'Inventario',
                  description: 'Stato attuale dello stock e prodotti critici.',
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _MiniInsightCard(
                            title: 'Valore stock',
                            value: currency.format(snapshot.inventoryValue),
                            subtitle: 'Valore inventario attuale',
                          ),
                          _MiniInsightCard(
                            title: 'Alert',
                            value: '${snapshot.inventoryAlerts.length}',
                            subtitle:
                                snapshot.inventoryAlerts.isEmpty
                                    ? 'Nessuna criticita'
                                    : 'Prodotti sotto soglia',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InventoryTable(
                        entries:
                            snapshot.inventoryAlerts.isEmpty
                                ? snapshot.inventoryEntries
                                : snapshot.inventoryAlerts,
                        currency: currency,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _AnalyticsSection(
                  key: _sectionKeys[ReportAnalyticsSection.marketing],
                  title: 'Marketing & promozioni',
                  description: 'Engagement delle promozioni e CTR complessivo.',
                  child: Column(
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _MiniInsightCard(
                            title: 'Views',
                            value: '${snapshot.totalPromotionViews}',
                            subtitle: 'Promozioni nel periodo',
                          ),
                          _MiniInsightCard(
                            title: 'Click CTA',
                            value: '${snapshot.totalPromotionClicks}',
                            subtitle: 'Interazioni registrate',
                          ),
                          _MiniInsightCard(
                            title: 'CTR',
                            value: _formatPercent(snapshot.promotionCtr),
                            subtitle:
                                snapshot.promotionEntries.isEmpty
                                    ? 'Nessuna promozione'
                                    : 'Media delle promozioni visibili',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _PromotionTable(entries: snapshot.promotionEntries),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fine report',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExportTab({
    required BuildContext context,
    required ReportsSnapshot snapshot,
    required NumberFormat currency,
  }) {
    final theme = Theme.of(context);
    final datasetCounts = <ReportExportDataset, int>{
      ReportExportDataset.sales: snapshot.filteredSales.length,
      ReportExportDataset.appointments: snapshot.filteredAppointments.length,
      ReportExportDataset.clients: snapshot.filteredClients.length,
      ReportExportDataset.staff: snapshot.staffPerformance.length,
      ReportExportDataset.inventory: snapshot.inventoryEntries.length,
      ReportExportDataset.marketing: snapshot.promotionEntries.length,
    };
    final hasAnyCsv = datasetCounts.values.any((count) => count > 0);

    return SingleChildScrollView(
      key: const ValueKey<String>('reports_export'),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Executive PDF',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Genera un report manageriale condivisibile con KPI principali, trend, top servizi, performance staff, alert magazzino e promozioni.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _MiniInsightCard(
                        title: 'Fatturato',
                        value: currency.format(snapshot.current.totalRevenue),
                        subtitle: 'Periodo filtrato',
                      ),
                      _MiniInsightCard(
                        title: 'Nuovi clienti',
                        value: '${snapshot.current.newClients}',
                        subtitle: 'Periodo filtrato',
                      ),
                      _MiniInsightCard(
                        title: 'Occupazione',
                        value: _formatOccupancy(snapshot.current.occupancy),
                        subtitle:
                            snapshot.current.occupancy.estimated
                                ? 'Fallback stimato'
                                : 'Turni reali',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed:
                        _isExportingPdf || !snapshot.hasAnyData
                            ? null
                            : () => _exportExecutivePdf(snapshot),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AD31),
                      foregroundColor: Colors.black,
                    ),
                    icon:
                        _isExportingPdf
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Esporta executive PDF'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dataset CSV',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esporta i dati grezzi del report corrente. Ogni file rispetta filtri, salone e periodo selezionati.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: ReportExportDataset.values
                        .map((dataset) {
                          final count = datasetCounts[dataset] ?? 0;
                          final isLoading = _exportingDatasets.contains(
                            dataset,
                          );
                          return _DatasetExportTile(
                            dataset: dataset,
                            count: count,
                            isLoading: isLoading,
                            onExport:
                                count <= 0 || isLoading
                                    ? null
                                    : () =>
                                        _exportCsvDataset(snapshot, dataset),
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        !hasAnyCsv || _exportingAllCsv
                            ? null
                            : () => _exportAllCsv(snapshot),
                    icon:
                        _exportingAllCsv
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.table_view_rounded),
                    label: const Text('Esporta tutti i CSV'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _PreviewMetricData _previewData(
    ReportsSnapshot snapshot,
    NumberFormat currency,
  ) {
    return switch (_previewMetric) {
      ReportPreviewMetric.sales => _PreviewMetricData(
        title: 'Trend vendite',
        subtitle:
            'Andamento ${_granularityLabel(snapshot.trendGranularity)} del fatturato',
        points: snapshot.revenueTrend,
        dateFormatter: _trendDateFormatter(snapshot.trendGranularity),
        valueLabelBuilder: currency.format,
        tooltipBuilder: currency.format,
        emptyMessage: 'Nessuna vendita nel periodo selezionato',
      ),
      ReportPreviewMetric.appointments => _PreviewMetricData(
        title: 'Trend appuntamenti',
        subtitle: 'Carico agenda del periodo filtrato',
        points: snapshot.appointmentTrend,
        dateFormatter: _trendDateFormatter(snapshot.trendGranularity),
        valueLabelBuilder: (value) => value.toInt().toString(),
        tooltipBuilder: (value) => '${value.toInt()} appuntamenti',
        emptyMessage: 'Nessun appuntamento nel periodo selezionato',
      ),
      ReportPreviewMetric.clients => _PreviewMetricData(
        title: 'Trend clienti',
        subtitle: 'Nuove anagrafiche registrate nel periodo',
        points: snapshot.clientTrend,
        dateFormatter: _trendDateFormatter(snapshot.trendGranularity),
        valueLabelBuilder: (value) => value.toInt().toString(),
        tooltipBuilder: (value) => '${value.toInt()} nuovi clienti',
        emptyMessage: 'Nessun nuovo cliente nel periodo selezionato',
      ),
      ReportPreviewMetric.occupancy => _PreviewMetricData(
        title: 'Trend occupazione',
        subtitle:
            snapshot.current.occupancy.estimated
                ? 'Capacita stimata sullo schedule del salone'
                : 'Capacita calcolata sui turni reali',
        badgeLabel: snapshot.current.occupancy.estimated ? 'Stimato' : 'Reale',
        points: snapshot.occupancyTrend,
        dateFormatter: _trendDateFormatter(snapshot.trendGranularity),
        valueLabelBuilder: (value) => _formatPercent(value),
        tooltipBuilder: (value) => _formatPercent(value),
        emptyMessage: 'Occupazione non disponibile per il periodo selezionato',
      ),
    };
  }

  void _updateFilters(ReportFilters next, {bool persistQuery = true}) {
    if (_filters == next) {
      return;
    }
    setState(() => _filters = next);
    if (persistQuery) {
      _schedulePersistQuery();
    }
  }

  void _setActiveTab(ReportsTab tab, {bool persistQuery = true}) {
    if (_activeTab == tab) {
      return;
    }
    setState(() => _activeTab = tab);
    if (persistQuery) {
      _schedulePersistQuery();
    }
  }

  void _jumpToAnalyticsSection(ReportAnalyticsSection section) {
    if (_selectedSection != section) {
      setState(() => _selectedSection = section);
    }
    if (_activeTab != ReportsTab.analytics) {
      _setActiveTab(ReportsTab.analytics);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final contextForSection = _sectionKeys[section]?.currentContext;
      if (contextForSection != null) {
        Scrollable.ensureVisible(
          contextForSection,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      }
    });
  }

  void _schedulePersistQuery() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _persistQuery();
    });
  }

  void _persistQuery() {
    final router = GoRouter.of(context);
    final state = GoRouterState.of(context);
    final currentParams = Map<String, String>.from(state.uri.queryParameters);
    final nextParams =
        Map<String, String>.from(currentParams)
          ..removeWhere((key, _) => key.startsWith(ReportsQueryKeys.prefix))
          ..addAll(_filters.toQueryParameters());
    if (_activeTab != ReportsTab.dashboard) {
      nextParams[ReportsQueryKeys.tab] = _activeTab.queryValue;
    }

    const equality = MapEquality<String, String>();
    if (equality.equals(currentParams, nextParams)) {
      return;
    }

    final updatedUri = state.uri.replace(
      queryParameters:
          nextParams.isEmpty ? null : Map<String, dynamic>.from(nextParams),
    );
    router.replace(updatedUri.toString());
  }

  static String _reportQuerySignature(Uri uri) {
    final entries =
        uri.queryParameters.entries
            .where((entry) => entry.key.startsWith(ReportsQueryKeys.prefix))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
  }

  Future<void> _exportExecutivePdf(ReportsSnapshot snapshot) async {
    setState(() => _isExportingPdf = true);
    try {
      final pdf = await _exportService.buildExecutivePdf(snapshot: snapshot);
      await _exportService.shareFiles(
        files: [pdf],
        subject: 'Report analytics youbook',
        text: 'Report esportato dal modulo analytics.',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('PDF report generato correttamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Impossibile esportare il PDF: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  Future<void> _exportCsvDataset(
    ReportsSnapshot snapshot,
    ReportExportDataset dataset,
  ) async {
    setState(() => _exportingDatasets.add(dataset));
    try {
      final file = _exportService.buildCsvDataset(
        snapshot: snapshot,
        dataset: dataset,
      );
      await _exportService.shareFiles(
        files: [file],
        subject: 'Esportazione ${dataset.label.toLowerCase()}',
        text: 'Dataset generato dal modulo report di youbook.',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('CSV ${dataset.label} generato correttamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Impossibile esportare ${dataset.label}: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingDatasets.remove(dataset));
      }
    }
  }

  Future<void> _exportAllCsv(ReportsSnapshot snapshot) async {
    setState(() => _exportingAllCsv = true);
    try {
      final files = _exportService.buildAllCsvDatasets(snapshot: snapshot);
      await _exportService.shareFiles(
        files: files,
        subject: 'Esportazione completa report',
        text: 'Dataset CSV generati dal modulo report di youbook.',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Tutti i CSV sono stati generati.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Impossibile esportare i CSV: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _exportingAllCsv = false);
      }
    }
  }

  static String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  static String _formatOccupancy(ReportOccupancySummary occupancy) {
    final ratio = occupancy.ratio;
    if (ratio == null) {
      return 'N/D';
    }
    final suffix = occupancy.estimated ? ' stimato' : '';
    return '${(ratio * 100).toStringAsFixed(1)}%$suffix';
  }

  static String _formatDelta({
    required double? current,
    required double? previous,
    bool isRate = false,
  }) {
    if (current == null || previous == null) {
      return 'Confronto non disponibile';
    }
    if (isRate) {
      final delta = (current - previous) * 100;
      if (delta.abs() < 0.05) {
        return 'Stabile vs periodo precedente';
      }
      final sign = delta >= 0 ? '+' : '';
      return '$sign${delta.toStringAsFixed(1)} pt vs periodo precedente';
    }
    if (previous.abs() < 0.0001) {
      if (current.abs() < 0.0001) {
        return 'Stabile vs periodo precedente';
      }
      return 'Nuovo nel periodo';
    }
    final delta = ((current - previous) / previous) * 100;
    if (delta.abs() < 0.05) {
      return 'Stabile vs periodo precedente';
    }
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)}% vs periodo precedente';
  }

  static DateFormat _trendDateFormatter(ReportTrendGranularity granularity) {
    return granularity == ReportTrendGranularity.monthly
        ? DateFormat('MMM yy', 'it_IT')
        : DateFormat('dd MMM', 'it_IT');
  }

  static String _granularityLabel(ReportTrendGranularity granularity) {
    return granularity == ReportTrendGranularity.monthly
        ? 'mensile'
        : 'giornaliera';
  }
}

class _AnalyticsSection extends StatelessWidget {
  const _AnalyticsSection({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _PreviewMetricData {
  const _PreviewMetricData({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.dateFormatter,
    required this.valueLabelBuilder,
    required this.tooltipBuilder,
    required this.emptyMessage,
    this.badgeLabel,
  });

  final String title;
  final String subtitle;
  final String? badgeLabel;
  final List<ReportTrendPoint> points;
  final DateFormat dateFormatter;
  final _TrendValueFormatter valueLabelBuilder;
  final _TrendValueFormatter tooltipBuilder;
  final String emptyMessage;
}

class _DashboardShortcutCard extends StatelessWidget {
  const _DashboardShortcutCard({
    required this.onSelectSales,
    required this.onSelectStaff,
    required this.onSelectClients,
    required this.onSelectInventory,
    required this.onSelectMarketing,
  });

  final VoidCallback onSelectSales;
  final VoidCallback onSelectStaff;
  final VoidCallback onSelectClients;
  final VoidCallback onSelectInventory;
  final VoidCallback onSelectMarketing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report disponibili',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _ShortcutTile(
              title: 'Vendite per periodo',
              subtitle: 'Analisi vendite mensile/annuale',
              icon: Icons.trending_up_rounded,
              onTap: onSelectSales,
            ),
            const SizedBox(height: 10),
            _ShortcutTile(
              title: 'Performance staff',
              subtitle: 'Produttivita e statistiche team',
              icon: Icons.groups_2_rounded,
              onTap: onSelectStaff,
            ),
            const SizedBox(height: 10),
            _ShortcutTile(
              title: 'Analisi clienti',
              subtitle: 'Segmentazione e comportamento',
              icon: Icons.people_alt_rounded,
              onTap: onSelectClients,
            ),
            const SizedBox(height: 10),
            _ShortcutTile(
              title: 'Inventario',
              subtitle: 'Movimenti magazzino e soglie',
              icon: Icons.inventory_2_rounded,
              onTap: onSelectInventory,
            ),
            const SizedBox(height: 10),
            _ShortcutTile(
              title: 'Marketing & promozioni',
              subtitle: 'Engagement e CTR campagne',
              icon: Icons.campaign_rounded,
              onTap: onSelectMarketing,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_outward_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PreviewAnalyticsCard extends StatelessWidget {
  const _PreviewAnalyticsCard({
    required this.previewMetric,
    required this.onMetricSelected,
    required this.title,
    required this.subtitle,
    required this.dateFormatter,
    required this.points,
    required this.valueLabelBuilder,
    required this.tooltipBuilder,
    required this.emptyMessage,
    this.badgeLabel,
  });

  final ReportPreviewMetric previewMetric;
  final ValueChanged<ReportPreviewMetric> onMetricSelected;
  final String title;
  final String subtitle;
  final String? badgeLabel;
  final DateFormat dateFormatter;
  final List<ReportTrendPoint> points;
  final _TrendValueFormatter valueLabelBuilder;
  final _TrendValueFormatter tooltipBuilder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badgeLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeLabel!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _TrendPanel(
              title: '',
              subtitle: '',
              points: points,
              dateFormatter: dateFormatter,
              valueLabelBuilder: valueLabelBuilder,
              tooltipBuilder: tooltipBuilder,
              emptyMessage: emptyMessage,
              denseHeader: true,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ReportPreviewMetric.values
                  .map(
                    (metric) => ChoiceChip(
                      label: Text(metric.label),
                      selected: previewMetric == metric,
                      onSelected: (_) => onMetricSelected(metric),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetricCard extends StatelessWidget {
  const _HeroMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.deltaLabel,
    required this.accentColor,
    this.badgeLabel,
  });

  final String title;
  final String value;
  final IconData icon;
  final String deltaLabel;
  final Color accentColor;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 255,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, color: accentColor, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                deltaLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badgeLabel != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryMetricDefinition {
  const _SecondaryMetricDefinition({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
}

class _SecondaryMetricCard extends StatelessWidget {
  const _SecondaryMetricCard({required this.metric});

  final _SecondaryMetricDefinition metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(metric.icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                metric.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                metric.value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                metric.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInsightCard extends StatelessWidget {
  const _MiniInsightCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 230,
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueTableRow {
  const _ValueTableRow({required this.label, required this.value});

  final String label;
  final String value;
}

class _SimpleValueTableCard extends StatelessWidget {
  const _SimpleValueTableCard({
    required this.title,
    required this.rows,
    required this.emptyMessage,
  });

  final String title;
  final List<_ValueTableRow> rows;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              Text(
                emptyMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.label,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        row.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DatasetExportTile extends StatelessWidget {
  const _DatasetExportTile({
    required this.dataset,
    required this.count,
    required this.isLoading,
    this.onExport,
  });

  final ReportExportDataset dataset;
  final int count;
  final bool isLoading;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dataset.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count record disponibili',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onExport,
              icon:
                  isLoading
                      ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.download_rounded, size: 18),
              label: const Text('Esporta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopServicesTable extends StatelessWidget {
  const _TopServicesTable({required this.entries, required this.currency});

  final List<ReportTopServiceEntry> entries;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyTableCard(
        title: 'Servizi piu venduti',
        message: 'Nessuna vendita di servizi nel periodo selezionato.',
      );
    }
    return Card(
      elevation: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Servizio')),
            DataColumn(label: Text('Quantita')),
            DataColumn(label: Text('Fatturato')),
          ],
          rows: entries
              .map(
                (entry) => DataRow(
                  cells: [
                    DataCell(Text(entry.name)),
                    DataCell(Text(entry.quantity.toStringAsFixed(0))),
                    DataCell(Text(currency.format(entry.revenue))),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _AppointmentStatusTable extends StatelessWidget {
  const _AppointmentStatusTable({required this.appointments});

  final List<Appointment> appointments;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return const _EmptyTableCard(
        title: 'Riepilogo appuntamenti',
        message: 'Nessun appuntamento nel periodo selezionato.',
      );
    }
    final buckets = <AppointmentStatus, int>{
      AppointmentStatus.completed: 0,
      AppointmentStatus.cancelled: 0,
      AppointmentStatus.noShow: 0,
      AppointmentStatus.scheduled: 0,
    };
    for (final appointment in appointments) {
      buckets[appointment.status] = (buckets[appointment.status] ?? 0) + 1;
    }
    return Card(
      elevation: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Stato')),
            DataColumn(label: Text('Totale')),
          ],
          rows: buckets.entries
              .map(
                (entry) => DataRow(
                  cells: [
                    DataCell(Text(entry.key.name)),
                    DataCell(Text('${entry.value}')),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _StaffPerformanceTable extends StatelessWidget {
  const _StaffPerformanceTable({required this.rows, required this.currency});

  final List<ReportStaffPerformanceRow> rows;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _EmptyTableCard(
        title: 'Performance staff',
        message: 'Nessun operatore disponibile per il filtro selezionato.',
      );
    }
    return Card(
      elevation: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Staff')),
            DataColumn(label: Text('Fatturato')),
            DataColumn(label: Text('Scontrini')),
            DataColumn(label: Text('Completati')),
            DataColumn(label: Text('Ticket medio')),
            DataColumn(label: Text('Occupazione')),
          ],
          rows: rows
              .map(
                (row) => DataRow(
                  cells: [
                    DataCell(Text(row.staffName)),
                    DataCell(Text(currency.format(row.revenue))),
                    DataCell(Text('${row.salesCount}')),
                    DataCell(Text('${row.completedAppointments}')),
                    DataCell(Text(currency.format(row.averageTicket))),
                    DataCell(
                      Text(_ReportsModuleState._formatOccupancy(row.occupancy)),
                    ),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _InventoryTable extends StatelessWidget {
  const _InventoryTable({required this.entries, required this.currency});

  final List<ReportInventoryEntry> entries;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyTableCard(
        title: 'Inventario',
        message: 'Nessun prodotto disponibile.',
      );
    }
    return Card(
      elevation: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Prodotto')),
            DataColumn(label: Text('Categoria')),
            DataColumn(label: Text('Giacenza')),
            DataColumn(label: Text('Soglia')),
            DataColumn(label: Text('Stato')),
            DataColumn(label: Text('Valore stock')),
          ],
          rows: entries
              .map(
                (entry) => DataRow(
                  cells: [
                    DataCell(Text(entry.item.name)),
                    DataCell(Text(entry.item.category)),
                    DataCell(Text(entry.item.quantity.toStringAsFixed(0))),
                    DataCell(Text(entry.item.threshold.toStringAsFixed(0))),
                    DataCell(Text(entry.statusLabel)),
                    DataCell(Text(currency.format(entry.stockValue))),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _PromotionTable extends StatelessWidget {
  const _PromotionTable({required this.entries});

  final List<ReportPromotionEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const _EmptyTableCard(
        title: 'Promozioni',
        message: 'Nessuna promozione disponibile nel periodo selezionato.',
      );
    }
    return Card(
      elevation: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Promozione')),
            DataColumn(label: Text('Stato')),
            DataColumn(label: Text('Views')),
            DataColumn(label: Text('Click CTA')),
            DataColumn(label: Text('CTR')),
          ],
          rows: entries
              .map(
                (entry) => DataRow(
                  cells: [
                    DataCell(Text(entry.promotion.title)),
                    DataCell(Text(entry.promotion.status.name)),
                    DataCell(Text('${entry.viewCount}')),
                    DataCell(Text('${entry.ctaClicks}')),
                    DataCell(
                      Text(_ReportsModuleState._formatPercent(entry.ctr)),
                    ),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _EmptyTableCard extends StatelessWidget {
  const _EmptyTableCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedHeaderDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || child != oldDelegate.child;
  }
}

class ReportsFiltersBar extends StatefulWidget {
  const ReportsFiltersBar({
    super.key,
    required this.range,
    required this.dateFormatter,
    required this.onRangeChanged,
    required this.staffMembers,
    required this.selectedOperatorId,
    required this.onOperatorChanged,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.services,
    required this.selectedServiceId,
    required this.onServiceChanged,
    required this.bookingChannels,
    required this.selectedBookingChannel,
    required this.onBookingChannelChanged,
    this.compact = false,
  });

  final DateTimeRange range;
  final DateFormat dateFormatter;
  final ValueChanged<DateTimeRange> onRangeChanged;
  final List<StaffMember> staffMembers;
  final String? selectedOperatorId;
  final ValueChanged<String?> onOperatorChanged;
  final List<ServiceCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final List<Service> services;
  final String? selectedServiceId;
  final ValueChanged<String?> onServiceChanged;
  final List<String> bookingChannels;
  final String? selectedBookingChannel;
  final ValueChanged<String?> onBookingChannelChanged;
  final bool compact;

  @override
  State<ReportsFiltersBar> createState() => _ReportsFiltersBarState();
}

class _ReportsFiltersBarState extends State<ReportsFiltersBar> {
  bool _filtersExpanded = false;

  Future<void> _selectRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: DateTime(
          widget.range.start.year,
          widget.range.start.month,
          widget.range.start.day,
        ),
        end: DateTime(
          widget.range.end.year,
          widget.range.end.month,
          widget.range.end.day,
        ),
      ),
    );
    if (picked == null) {
      return;
    }
    widget.onRangeChanged(
      DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controls = <Widget>[
      _RangeField(
        compact: widget.compact,
        expand: widget.compact,
        label:
            '${widget.dateFormatter.format(widget.range.start)} -> ${widget.dateFormatter.format(widget.range.end)}',
        onTap: () => _selectRange(context),
      ),
      _DropdownField(
        compact: widget.compact,
        expand: widget.compact,
        label: 'Operatore',
        value: _ensureValue(
          widget.selectedOperatorId,
          widget.staffMembers.map((member) => member.id),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tutti gli operatori'),
          ),
          ...widget.staffMembers.sortedByDisplayOrder().map(
            (member) => DropdownMenuItem<String?>(
              value: member.id,
              child: Text(member.fullName),
            ),
          ),
        ],
        onChanged: widget.onOperatorChanged,
      ),
      _DropdownField(
        compact: widget.compact,
        expand: widget.compact,
        label: 'Categoria',
        value: _ensureValue(
          widget.selectedCategoryId,
          widget.categories.map((category) => category.id),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tutte le categorie'),
          ),
          ...widget.categories.map(
            (category) => DropdownMenuItem<String?>(
              value: category.id,
              child: Text(category.name),
            ),
          ),
        ],
        onChanged: widget.onCategoryChanged,
      ),
      _DropdownField(
        compact: widget.compact,
        expand: widget.compact,
        label: 'Servizio',
        value: _ensureValue(
          widget.selectedServiceId,
          widget.services.map((service) => service.id),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tutti i servizi'),
          ),
          ...widget.services
              .sortedBy((service) => service.name.toLowerCase())
              .map(
                (service) => DropdownMenuItem<String?>(
                  value: service.id,
                  child: Text(service.name),
                ),
              ),
        ],
        onChanged: widget.onServiceChanged,
      ),
      _DropdownField(
        compact: widget.compact,
        expand: widget.compact,
        label: 'Canale',
        value: _ensureValue(
          widget.selectedBookingChannel,
          widget.bookingChannels,
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tutti i canali'),
          ),
          ...widget.bookingChannels.map(
            (channel) => DropdownMenuItem<String?>(
              value: channel,
              child: Text(formatReportChannelLabel(channel)),
            ),
          ),
        ],
        onChanged: widget.onBookingChannelChanged,
      ),
    ];

    final activeFiltersCount =
        (widget.selectedOperatorId == null ? 0 : 1) +
        (widget.selectedCategoryId == null ? 0 : 1) +
        (widget.selectedServiceId == null ? 0 : 1) +
        (widget.selectedBookingChannel == null ? 0 : 1);
    final summaryText =
        activeFiltersCount == 0
            ? 'Nessun filtro avanzato'
            : '$activeFiltersCount filtro${activeFiltersCount == 1 ? '' : 'i'} attiv${activeFiltersCount == 1 ? 'o' : 'i'}';
    final advancedFiltersSummary = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              key: const ValueKey('reports_filters_toggle'),
              onPressed:
                  () => setState(() => _filtersExpanded = !_filtersExpanded),
              icon: Icon(
                _filtersExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(_filtersExpanded ? 'Chiudi' : 'Filtri'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final expandedFilters =
        widget.compact
            ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: controls
                  .skip(1)
                  .map(
                    (control) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: control,
                    ),
                  )
                  .toList(growable: false),
            )
            : Wrap(
              spacing: 14,
              runSpacing: 14,
              children: controls.skip(1).toList(growable: false),
            );

    return Column(
      key: ValueKey<String>(
        widget.compact
            ? 'reports_mobile_filters_bar'
            : 'reports_desktop_filters_bar',
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.compact) ...[
          controls.first,
          const SizedBox(height: 10),
          advancedFiltersSummary,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: controls.first),
              const SizedBox(width: 14),
              Expanded(child: advancedFiltersSummary),
            ],
          ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: expandedFilters,
          ),
          crossFadeState:
              _filtersExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeOutCubic,
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }

  static String? _ensureValue(String? value, Iterable<String> allowedValues) {
    if (value == null) {
      return null;
    }
    return allowedValues.contains(value) ? value : null;
  }
}

class _RangeField extends StatelessWidget {
  const _RangeField({
    required this.label,
    required this.onTap,
    this.compact = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Periodo',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(compact ? 12 : 14),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
    if (expand) {
      return field;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 220 : 260),
      child: field,
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.compact = false,
    this.expand = false,
  });

  final String label;
  final String? value;
  final List<DropdownMenuItem<String?>> items;
  final ValueChanged<String?> onChanged;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<String?>(
      key: ValueKey<String>('reports_dropdown_${label}_${value ?? 'all'}'),
      initialValue: value,
      items: items,
      onChanged: items.length > 1 ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
      ),
      isDense: true,
      isExpanded: true,
    );
    if (expand) {
      return field;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 180 : 220),
      child: field,
    );
  }
}

typedef _TrendValueFormatter = String Function(double value);

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.dateFormatter,
    required this.valueLabelBuilder,
    required this.tooltipBuilder,
    required this.emptyMessage,
    this.denseHeader = false,
  });

  final String title;
  final String subtitle;
  final List<ReportTrendPoint> points;
  final DateFormat dateFormatter;
  final _TrendValueFormatter valueLabelBuilder;
  final _TrendValueFormatter tooltipBuilder;
  final String emptyMessage;
  final bool denseHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!denseHeader && title.isNotEmpty) ...[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (points.isEmpty)
              SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              Text(
                valueLabelBuilder(points.last.value),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aggiornato al ${dateFormatter.format(points.last.date)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: _TrendChart(
                  points: points,
                  dateFormatter: dateFormatter,
                  valueLabelBuilder: valueLabelBuilder,
                  tooltipBuilder: tooltipBuilder,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.points,
    required this.dateFormatter,
    required this.valueLabelBuilder,
    required this.tooltipBuilder,
  });

  final List<ReportTrendPoint> points;
  final DateFormat dateFormatter;
  final _TrendValueFormatter valueLabelBuilder;
  final _TrendValueFormatter tooltipBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final axisStyle = (theme.textTheme.labelSmall ??
            theme.textTheme.bodySmall ??
            const TextStyle(fontSize: 11))
        .copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
        );
    final lineColor = theme.colorScheme.primary;
    final pointColor = theme.colorScheme.primary;
    final gridColor = theme.dividerColor.withValues(alpha: 0.36);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size.width <= 0 || size.height <= 0 || points.isEmpty) {
          return const SizedBox.shrink();
        }

        const leftPadding = 56.0;
        const rightPadding = 16.0;
        const topPadding = 16.0;
        const bottomPadding = 48.0;
        final chartWidth = size.width - leftPadding - rightPadding;
        final chartHeight = size.height - topPadding - bottomPadding;
        if (chartWidth <= 0 || chartHeight <= 0) {
          return const SizedBox.shrink();
        }

        final chartRect = Rect.fromLTWH(
          leftPadding,
          topPadding,
          chartWidth,
          chartHeight,
        );

        var minValue = points.first.value;
        var maxValue = points.first.value;
        for (final point in points.skip(1)) {
          minValue = math.min(minValue, point.value);
          maxValue = math.max(maxValue, point.value);
        }
        final actualMin = minValue;
        final actualMax = maxValue;
        if ((maxValue - minValue).abs() < 1e-6) {
          final padding = maxValue == 0 ? 1 : (maxValue.abs() * 0.1);
          maxValue += padding;
          minValue -= padding;
          if (minValue < 0 && actualMin >= 0) {
            minValue = 0;
          }
        }

        final span =
            (maxValue - minValue).abs() < 1e-6 ? 1 : (maxValue - minValue);
        final pointOffsets = <Offset>[];
        for (var index = 0; index < points.length; index++) {
          final point = points[index];
          final ratioX = points.length == 1 ? 0.5 : index / (points.length - 1);
          final ratioY = ((point.value - minValue) / span).clamp(0.0, 1.0);
          final dx = chartRect.left + ratioX * chartRect.width;
          final dy = chartRect.bottom - ratioY * chartRect.height;
          pointOffsets.add(Offset(dx, dy));
        }

        final xAxisLabels = _buildXAxisLabels(
          points: points,
          chartRect: chartRect,
          dateFormatter: dateFormatter,
        );
        final yAxisLabels = _buildYAxisLabels(
          chartRect: chartRect,
          minValue: minValue,
          maxValue: maxValue,
          actualMin: actualMin,
          actualMax: actualMax,
          valueLabelBuilder: valueLabelBuilder,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: size,
              painter: _TrendChartPainter(
                chartRect: chartRect,
                points: pointOffsets,
                lineColor: lineColor,
                pointColor: pointColor,
                gridColor: gridColor,
                axisLabelStyle: axisStyle,
                xAxisLabels: xAxisLabels,
                yAxisLabels: yAxisLabels,
              ),
            ),
            for (var i = 0; i < pointOffsets.length; i++)
              Positioned(
                left: pointOffsets[i].dx - 12,
                top: pointOffsets[i].dy - 12,
                child: Tooltip(
                  triggerMode: TooltipTriggerMode.tap,
                  message:
                      '${dateFormatter.format(points[i].date)} • '
                      '${tooltipBuilder(points[i].value)}',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 24,
                      height: 24,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _XAxisLabel {
  const _XAxisLabel({required this.position, required this.text});

  final double position;
  final String text;
}

class _YAxisLabel {
  const _YAxisLabel({required this.position, required this.text});

  final double position;
  final String text;
}

List<_XAxisLabel> _buildXAxisLabels({
  required List<ReportTrendPoint> points,
  required Rect chartRect,
  required DateFormat dateFormatter,
}) {
  if (points.isEmpty) {
    return const [];
  }
  final indexes = <int>{};
  if (points.length <= 4) {
    indexes.addAll(List<int>.generate(points.length, (index) => index));
  } else {
    indexes.addAll({
      0,
      math.max(0, (points.length - 1) ~/ 3),
      math.max(0, ((points.length - 1) * 2) ~/ 3),
      points.length - 1,
    });
  }
  final sortedIndexes = indexes.toList()..sort();
  return sortedIndexes
      .map((index) {
        final ratio = points.length == 1 ? 0.5 : index / (points.length - 1);
        final position = chartRect.left + ratio * chartRect.width;
        return _XAxisLabel(
          position: position,
          text: dateFormatter.format(points[index].date),
        );
      })
      .toList(growable: false);
}

List<_YAxisLabel> _buildYAxisLabels({
  required Rect chartRect,
  required double minValue,
  required double maxValue,
  required double actualMin,
  required double actualMax,
  required _TrendValueFormatter valueLabelBuilder,
}) {
  final span = (maxValue - minValue).abs();
  if (span <= 1e-6) {
    return [
      _YAxisLabel(
        position: chartRect.center.dy,
        text: valueLabelBuilder(actualMax),
      ),
    ];
  }

  final candidateValues = <double>[actualMax];
  final midValue = (actualMax + actualMin) / 2;
  if ((midValue - actualMax).abs() > 1e-6 &&
      (midValue - actualMin).abs() > 1e-6) {
    candidateValues.add(midValue);
  }
  if ((actualMin - actualMax).abs() > 1e-6) {
    candidateValues.add(actualMin);
  }

  final uniqueValues = <double>[];
  for (final value in candidateValues) {
    final alreadyPresent = uniqueValues.any(
      (existing) => (existing - value).abs() < 1e-6,
    );
    if (!alreadyPresent) {
      uniqueValues.add(value);
    }
  }
  uniqueValues.sort((a, b) => b.compareTo(a));

  return uniqueValues
      .map((value) {
        final ratio = ((value - minValue) / (maxValue - minValue)).clamp(
          0.0,
          1.0,
        );
        final position = chartRect.bottom - ratio * chartRect.height;
        return _YAxisLabel(position: position, text: valueLabelBuilder(value));
      })
      .toList(growable: false);
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({
    required this.chartRect,
    required this.points,
    required this.lineColor,
    required this.pointColor,
    required this.gridColor,
    required this.axisLabelStyle,
    required this.xAxisLabels,
    required this.yAxisLabels,
  });

  final Rect chartRect;
  final List<Offset> points;
  final Color lineColor;
  final Color pointColor;
  final Color gridColor;
  final TextStyle axisLabelStyle;
  final List<_XAxisLabel> xAxisLabels;
  final List<_YAxisLabel> yAxisLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint =
        Paint()
          ..color = gridColor.withValues(alpha: 0.9)
          ..strokeWidth = 1;
    final gridPaint =
        Paint()
          ..color = gridColor
          ..strokeWidth = 1;

    for (final label in yAxisLabels) {
      final y = label.position;
      if ((y - chartRect.bottom).abs() < 0.5 ||
          (y - chartRect.top).abs() < 0.5) {
        continue;
      }
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    canvas.drawLine(chartRect.bottomLeft, chartRect.bottomRight, axisPaint);
    canvas.drawLine(chartRect.bottomLeft, chartRect.topLeft, axisPaint);

    if (points.length >= 2) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      final linePaint =
          Paint()
            ..color = lineColor
            ..strokeWidth = 2.2
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);
    }

    final pointFill =
        Paint()
          ..color = pointColor
          ..style = PaintingStyle.fill;
    final pointStroke =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
    for (final point in points) {
      canvas.drawCircle(point, 4, pointFill);
      canvas.drawCircle(point, 4, pointStroke);
    }

    for (final label in xAxisLabels) {
      final textPainter = TextPainter(
        text: TextSpan(text: label.text, style: axisLabelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(label.position - textPainter.width / 2, chartRect.bottom + 6),
      );
    }

    for (final label in yAxisLabels) {
      final textPainter = TextPainter(
        text: TextSpan(text: label.text, style: axisLabelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          chartRect.left - 8 - textPainter.width,
          label.position - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return true;
  }
}
