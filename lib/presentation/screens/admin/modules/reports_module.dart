import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/app/reporting_config.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/staff_member.dart';

class ReportsModule extends ConsumerStatefulWidget {
  const ReportsModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<ReportsModule> createState() => _ReportsModuleState();
}

class _ReportsQueryKeys {
  const _ReportsQueryKeys._();

  static const prefix = 'reports_';
  static const dateFrom = 'reports_from';
  static const dateTo = 'reports_to';
  static const salon = 'reports_salon';
  static const operators = 'reports_operators';
  static const services = 'reports_services';
  static const categories = 'reports_categories';
  static const channels = 'reports_channels';
}

String _formatChannelLabel(String channel) {
  if (channel.isEmpty) {
    return channel;
  }
  final normalized = channel.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) {
    return channel;
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

class _ReportFilters {
  _ReportFilters({
    required this.range,
    String? salonId,
    Set<String> operatorIds = const <String>{},
    Set<String> serviceIds = const <String>{},
    Set<String> categoryIds = const <String>{},
    Set<String> bookingChannels = const <String>{},
  }) : salonId = salonId,
       operatorIds = Set<String>.unmodifiable(operatorIds),
       serviceIds = Set<String>.unmodifiable(serviceIds),
       categoryIds = Set<String>.unmodifiable(categoryIds),
       bookingChannels = Set<String>.unmodifiable(bookingChannels);

  final DateTimeRange range;
  final String? salonId;
  final Set<String> operatorIds;
  final Set<String> serviceIds;
  final Set<String> categoryIds;
  final Set<String> bookingChannels;

  static final DateFormat _queryDateFormatter = DateFormat('yyyy-MM-dd');
  static const _unset = Object();
  static final SetEquality<String> _setEquality = const SetEquality<String>();

  factory _ReportFilters.initial({String? defaultSalonId}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _ReportFilters(
      range: DateTimeRange(
        start: today.subtract(const Duration(days: 29)),
        end: DateTime(today.year, today.month, today.day, 23, 59, 59),
      ),
      salonId: defaultSalonId,
    );
  }

  factory _ReportFilters.fromUri(Uri uri, {required String? defaultSalonId}) {
    final base = _ReportFilters.initial(defaultSalonId: defaultSalonId);
    final params = uri.queryParameters;
    final parsedRange = _parseRange(
      params[_ReportsQueryKeys.dateFrom],
      params[_ReportsQueryKeys.dateTo],
    );

    final salonParam = params[_ReportsQueryKeys.salon];
    final resolvedSalon =
        salonParam != null && salonParam.isNotEmpty
            ? salonParam
            : defaultSalonId;

    return _ReportFilters(
      range: parsedRange ?? base.range,
      salonId: resolvedSalon,
      operatorIds: _parseSet(params[_ReportsQueryKeys.operators]),
      serviceIds: _parseSet(params[_ReportsQueryKeys.services]),
      categoryIds: _parseSet(params[_ReportsQueryKeys.categories]),
      bookingChannels: _parseSet(params[_ReportsQueryKeys.channels]),
    );
  }

  _ReportFilters copyWith({
    DateTimeRange? range,
    Object? salonId = _unset,
    Set<String>? operatorIds,
    Set<String>? serviceIds,
    Set<String>? categoryIds,
    Set<String>? bookingChannels,
  }) {
    return _ReportFilters(
      range: range ?? this.range,
      salonId: salonId == _unset ? this.salonId : salonId as String?,
      operatorIds: operatorIds ?? this.operatorIds,
      serviceIds: serviceIds ?? this.serviceIds,
      categoryIds: categoryIds ?? this.categoryIds,
      bookingChannels: bookingChannels ?? this.bookingChannels,
    );
  }

  Map<String, String> toQueryParameters() {
    final params = <String, String>{
      _ReportsQueryKeys.dateFrom: _queryDateFormatter.format(
        DateTime(range.start.year, range.start.month, range.start.day),
      ),
      _ReportsQueryKeys.dateTo: _queryDateFormatter.format(
        DateTime(range.end.year, range.end.month, range.end.day),
      ),
    };
    if (salonId != null && salonId!.isNotEmpty) {
      params[_ReportsQueryKeys.salon] = salonId!;
    }
    if (operatorIds.isNotEmpty) {
      params[_ReportsQueryKeys.operators] = _sorted(operatorIds).join(',');
    }
    if (serviceIds.isNotEmpty) {
      params[_ReportsQueryKeys.services] = _sorted(serviceIds).join(',');
    }
    if (categoryIds.isNotEmpty) {
      params[_ReportsQueryKeys.categories] = _sorted(categoryIds).join(',');
    }
    if (bookingChannels.isNotEmpty) {
      params[_ReportsQueryKeys.channels] = _sorted(bookingChannels).join(',');
    }
    return params;
  }

  static Set<String> _parseSet(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const <String>{};
    }
    final parts = value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);
    return Set<String>.unmodifiable(parts);
  }

  static DateTimeRange? _parseRange(String? from, String? to) {
    final start = _parseDate(from);
    final end = _parseDate(to);
    if (start == null || end == null) {
      return null;
    }
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
    if (normalizedEnd.isBefore(normalizedStart)) {
      return null;
    }
    return DateTimeRange(start: normalizedStart, end: normalizedEnd);
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      return _queryDateFormatter.parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  static List<String> _sorted(Set<String> source) {
    final list = source.toList()..sort();
    return list;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _ReportFilters) return false;
    return range == other.range &&
        salonId == other.salonId &&
        _setEquality.equals(operatorIds, other.operatorIds) &&
        _setEquality.equals(serviceIds, other.serviceIds) &&
        _setEquality.equals(categoryIds, other.categoryIds) &&
        _setEquality.equals(bookingChannels, other.bookingChannels);
  }

  @override
  int get hashCode => Object.hashAll([
    range,
    salonId,
    _setEquality.hash(operatorIds),
    _setEquality.hash(serviceIds),
    _setEquality.hash(categoryIds),
    _setEquality.hash(bookingChannels),
  ]);
}

class _ReportsModuleState extends ConsumerState<ReportsModule> {
  late _ReportFilters _filters;
  bool _restoredFromQuery = false;

  @override
  void initState() {
    super.initState();
    _filters = _ReportFilters.initial(defaultSalonId: widget.salonId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routerState = GoRouterState.of(context);
    final restored = _ReportFilters.fromUri(
      routerState.uri,
      defaultSalonId: widget.salonId ?? _filters.salonId,
    );
    if (!_restoredFromQuery) {
      _filters = restored;
      _restoredFromQuery = true;
    } else if (_filters != restored) {
      setState(() => _filters = restored);
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
    final store = ref.read(appDataProvider.notifier);
    final data = ref.watch(appDataProvider.select((state) => state));
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    final filters = _filters;
    final activeSalonId = filters.salonId;

    final availableServices = data.services
        .where(
          (service) => activeSalonId == null || service.salonId == activeSalonId,
        )
        .toList(growable: false);
    final serviceLookup = {
      for (final service in availableServices) service.id: service,
    };
    final filteredSales = _filterSales(
      store.reportingSales(salonId: activeSalonId),
      serviceLookup,
    );
    final baseAppointments = store.reportingAppointments(salonId: activeSalonId);
    final appointments = _filterAppointments(baseAppointments, serviceLookup);
    final clients = _filterClients(
      store.reportingClients(salonId: activeSalonId),
    );
    final staffMembers = data.staff
        .where(
          (member) => activeSalonId == null || member.salonId == activeSalonId,
        )
        .toList(growable: false);
    final categories = data.serviceCategories
        .where(
          (category) => activeSalonId == null || category.salonId == activeSalonId,
        )
        .sortedByDisplayOrder();
    final bookingChannels = baseAppointments
        .map((appointment) => appointment.bookingChannel?.trim())
        .whereType<String>()
        .where((channel) => channel.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final salons = data.salons;
    final selectedOperatorId = filters.operatorIds.singleOrNull;
    final selectedCategoryId = filters.categoryIds.singleOrNull;
    final selectedServiceId = filters.serviceIds.singleOrNull;
    final selectedBookingChannel = filters.bookingChannels.singleOrNull;
    final serviceOptions =
        selectedCategoryId != null
            ? availableServices
                .where((service) => service.categoryId == selectedCategoryId)
                .toList(growable: false)
            : availableServices;
    final summaryBadges = _buildSummaryBadges(
      filters: filters,
      salons: salons,
      staff: staffMembers,
      categories: categories,
      services: availableServices,
    );
    final hasActiveFilters = filters.operatorIds.isNotEmpty ||
        filters.serviceIds.isNotEmpty ||
        filters.categoryIds.isNotEmpty ||
        filters.bookingChannels.isNotEmpty;

    final summary = _ReportSummary.compute(
      sales: filteredSales,
      appointments: appointments,
      clients: clients,
    );

    final revenueTrend = _groupRevenueByDate(filteredSales, filters.range);
    final topServices = _calculateTopServices(
      filteredSales,
      serviceLookup,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _FiltersBar(
                range: filters.range,
                dateFormatter: dateFormatter,
                onRangeChanged: _handleRangeChanged,
                salons: salons,
                selectedSalonId: filters.salonId,
                onSalonChanged: _handleSalonChanged,
                staffMembers: staffMembers,
                selectedOperatorId: selectedOperatorId,
                onOperatorChanged: _handleOperatorChanged,
                categories: categories,
                selectedCategoryId: selectedCategoryId,
                onCategoryChanged: _handleCategoryChanged,
                services: serviceOptions,
                selectedServiceId: selectedServiceId,
                onServiceChanged: _handleServiceChanged,
                bookingChannels: bookingChannels,
                selectedBookingChannel: selectedBookingChannel,
                onBookingChannelChanged: _handleBookingChannelChanged,
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 16.0;
              final maxWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.of(context).size.width;
              final columns =
                  maxWidth >= 1180
                      ? 4
                      : maxWidth >= 880
                          ? 3
                          : maxWidth >= 560
                              ? 2
                              : 1;
              final cards = <Widget>[
                if (kReportingCutoff != null)
                  _ReportCard(
                    title: 'Intervallo dati',
                    subtitle:
                        'Dati dal ${dateFormatter.format(kReportingCutoff!.toLocal())}',
                    value: '—',
                    icon: Icons.calendar_today_rounded,
                  ),
                _ReportCard(
                  title: 'Incasso totale',
                  subtitle: 'Somma vendite periodo',
                  value: currency.format(summary.totalRevenue),
                  icon: Icons.account_balance_wallet_rounded,
                  badges: summaryBadges,
                  onDrillDown: () => _openAdminModule('sales'),
                  drillDownLabel: 'Vai a Vendite & Cassa',
                ),
                _ReportCard(
                  title: 'Vendite registrate',
                  subtitle:
                      'Ticket medi: ${currency.format(summary.averageTicket)}',
                  value: '${summary.salesCount}',
                  icon: Icons.receipt_long_rounded,
                  badges: summaryBadges,
                  onDrillDown: () => _openAdminModule('sales'),
                  drillDownLabel: 'Apri dettagli vendite',
                ),
                _ReportCard(
                  title: 'Nuovi clienti',
                  subtitle: 'Registrati nel periodo',
                  value: '${summary.newClients}',
                  icon: Icons.person_add_alt_1_rounded,
                  badges: summaryBadges,
                  onDrillDown: () => _openAdminModule('clients'),
                  drillDownLabel: 'Vai a Clienti',
                ),
                _ReportCard(
                  title: 'Appuntamenti completati',
                  subtitle:
                      'Completion rate ${(summary.completionRate * 100).toStringAsFixed(1)}%',
                  value: '${summary.completedAppointments}',
                  icon: Icons.event_available_rounded,
                  badges: summaryBadges,
                  onDrillDown: () => _openAdminModule('appointments'),
                  drillDownLabel: 'Vai ad Appuntamenti',
                ),
              ];
              final tileWidth = columns == 1
                  ? maxWidth
                  : ((maxWidth - spacing * (columns - 1)) / columns)
                      .clamp(240.0, 360.0)
                      .toDouble();

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: tileWidth,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Andamento incassi'),
          const SizedBox(height: 12),
          revenueTrend.isEmpty
              ? _EmptyState(
                message: 'Nessuna vendita nel periodo selezionato',
                description:
                    hasActiveFilters
                        ? 'Prova a rimuovere i filtri o amplia l\'intervallo temporale.'
                        : 'Non sono state registrate vendite in questo intervallo.',
                actionLabel: hasActiveFilters ? 'Azzera filtri' : null,
                onAction: hasActiveFilters ? _clearFilterSelections : null,
              )
              : _RevenueTrendCard(
                trend: revenueTrend,
                currency: currency,
                onOpenDetails: () => _openAdminModule('sales'),
              ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Appuntamenti'),
          const SizedBox(height: 12),
          appointments.isEmpty
              ? _EmptyState(
                message: 'Nessun appuntamento registrato',
                description:
                    hasActiveFilters
                        ? 'I filtri correnti non restituiscono appuntamenti.'
                        : 'Non sono stati pianificati appuntamenti per il periodo selezionato.',
                actionLabel: hasActiveFilters ? 'Azzera filtri' : null,
                onAction: hasActiveFilters ? _clearFilterSelections : null,
              )
              : _AppointmentsTable(
                appointments: appointments,
                dateFormatter: dateFormatter,
              ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Servizi più venduti'),
          const SizedBox(height: 12),
          topServices.isEmpty
              ? _EmptyState(
                message: 'Nessuna vendita di servizi nel periodo',
                description:
                    hasActiveFilters
                        ? 'Regola i filtri per visualizzare i servizi movimentati.'
                        : 'Non risultano vendite di servizi nell\'intervallo selezionato.',
                actionLabel: hasActiveFilters ? 'Azzera filtri' : null,
                onAction: hasActiveFilters ? _clearFilterSelections : null,
              )
              : _TopServicesTable(entries: topServices, currency: currency),
        ],
      ),
    );
  }

  void _handleRangeChanged(DateTimeRange range) {
    final normalized = _normalizeRange(range);
    _updateFilters(_filters.copyWith(range: normalized));
  }

  void _openAdminModule(String moduleId, {Map<String, Object?> payload = const {}}) {
    ref.read(adminDashboardIntentProvider.notifier).state = AdminDashboardIntent(
      moduleId: moduleId,
      payload: payload,
    );
  }

  void _handleSalonChanged(String? salonId) {
    final normalized = salonId != null && salonId.isNotEmpty ? salonId : null;
    final next = _filters.copyWith(
      salonId: normalized,
      operatorIds: <String>{},
      serviceIds: <String>{},
      categoryIds: <String>{},
      bookingChannels: <String>{},
    );
    _updateFilters(next);
  }

  void _handleOperatorChanged(String? operatorId) {
    final selection =
        operatorId == null || operatorId.isEmpty ? <String>{} : <String>{operatorId};
    _updateFilters(_filters.copyWith(operatorIds: selection));
  }

  void _handleCategoryChanged(String? categoryId) {
    final selection =
        categoryId == null || categoryId.isEmpty ? <String>{} : <String>{categoryId};
    _updateFilters(
      _filters.copyWith(
        categoryIds: selection,
        serviceIds: <String>{},
      ),
    );
  }

  void _handleServiceChanged(String? serviceId) {
    final selection =
        serviceId == null || serviceId.isEmpty ? <String>{} : <String>{serviceId};
    _updateFilters(_filters.copyWith(serviceIds: selection));
  }

  void _handleBookingChannelChanged(String? channel) {
    final selection =
        channel == null || channel.isEmpty ? <String>{} : <String>{channel};
    _updateFilters(_filters.copyWith(bookingChannels: selection));
  }

  void _clearFilterSelections() {
    _updateFilters(
      _filters.copyWith(
        operatorIds: <String>{},
        serviceIds: <String>{},
        categoryIds: <String>{},
        bookingChannels: <String>{},
      ),
    );
  }

  List<Widget> _buildSummaryBadges({
    required _ReportFilters filters,
    required List<Salon> salons,
    required List<StaffMember> staff,
    required List<ServiceCategory> categories,
    required List<Service> services,
  }) {
    final badges = <Widget>[];
    if (filters.salonId != null) {
      final salon = salons.firstWhereOrNull((item) => item.id == filters.salonId);
      if (salon != null) {
        badges.add(
          _FilterBadge(
            label: 'Salone • ${salon.name}',
            icon: Icons.apartment_rounded,
          ),
        );
      }
    } else if (salons.length > 1) {
      badges.add(
        const _FilterBadge(
          label: 'Saloni • Tutti',
          icon: Icons.apartment_rounded,
        ),
      );
    }

    final staffById = {for (final member in staff) member.id: member};
    for (final operatorId in filters.operatorIds) {
      final member = staffById[operatorId];
      final name = member?.fullName ?? operatorId;
      badges.add(
        _FilterBadge(
          label: 'Operatore • $name',
          icon: Icons.badge_rounded,
        ),
      );
    }

    final categoriesById = {for (final category in categories) category.id: category};
    for (final categoryId in filters.categoryIds) {
      final category = categoriesById[categoryId];
      final name = category?.name ?? categoryId;
      badges.add(
        _FilterBadge(
          label: 'Categoria • $name',
          icon: Icons.category_rounded,
        ),
      );
    }

    final servicesById = {for (final service in services) service.id: service};
    for (final serviceId in filters.serviceIds) {
      final service = servicesById[serviceId];
      final name = service?.name ?? serviceId;
      badges.add(
        _FilterBadge(
          label: 'Servizio • $name',
          icon: Icons.design_services_rounded,
        ),
      );
    }

    for (final channel in filters.bookingChannels) {
      badges.add(
        _FilterBadge(
          label: 'Canale • ${_formatChannelLabel(channel)}',
          icon: Icons.auto_awesome_motion_rounded,
        ),
      );
    }

    return badges;
  }

  void _updateFilters(_ReportFilters next, {bool persistQuery = true}) {
    if (_filters == next) {
      return;
    }
    setState(() => _filters = next);
    if (!persistQuery) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _persistFilters(next);
    });
  }

  void _persistFilters(_ReportFilters filters) {
    final router = GoRouter.of(context);
    final state = GoRouterState.of(context);
    final currentParams = Map<String, String>.from(state.uri.queryParameters);
    final nextParams = Map<String, String>.from(currentParams)
      ..removeWhere((key, _) => key.startsWith(_ReportsQueryKeys.prefix))
      ..addAll(filters.toQueryParameters());

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

  DateTimeRange _normalizeRange(DateTimeRange range) {
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
    );
    return DateTimeRange(start: start, end: end);
  }

  List<_FilteredSale> _filterSales(
    List<Sale> sales,
    Map<String, Service> serviceLookup,
  ) {
    final filters = _filters;
    final operatorFilter = filters.operatorIds;
    final serviceFilter = filters.serviceIds;
    final categoryFilter = filters.categoryIds;
    final channelFilter = filters.bookingChannels
        .map((channel) => channel.toLowerCase())
        .toSet();

    final results = <_FilteredSale>[];
    for (final sale in sales) {
      if (!_isInRange(sale.createdAt)) {
        continue;
      }
      if (operatorFilter.isNotEmpty) {
        final staffId = sale.staffId;
        if (staffId == null || !operatorFilter.contains(staffId)) {
          continue;
        }
      }
      if (channelFilter.isNotEmpty) {
        final source = sale.source?.toLowerCase();
        if (source == null || !channelFilter.contains(source)) {
          continue;
        }
      }

      final serviceItems = sale.items
          .where((item) => item.referenceType == SaleReferenceType.service)
          .toList(growable: false);
      List<SaleItem> relevantItems;
      if (serviceFilter.isEmpty && categoryFilter.isEmpty) {
        relevantItems = serviceItems;
      } else {
        relevantItems = serviceItems.where((item) {
          final serviceId = item.referenceId;
          final matchesService =
              serviceFilter.isEmpty || serviceFilter.contains(serviceId);
          if (!matchesService) {
            return false;
          }
          if (categoryFilter.isEmpty) {
            return true;
          }
          final categoryId = serviceLookup[serviceId]?.categoryId;
          if (categoryId == null) {
            return false;
          }
          return categoryFilter.contains(categoryId);
        }).toList(growable: false);
        if (relevantItems.isEmpty) {
          continue;
        }
      }

      final amount =
          (serviceFilter.isEmpty && categoryFilter.isEmpty)
              ? sale.total
              : relevantItems.fold<double>(
                0,
                (sum, item) => sum + item.amount,
              );
      if (amount <= 0) {
        continue;
      }
      results.add(
        _FilteredSale(
          sale: sale,
          amount: amount,
          items: relevantItems,
        ),
      );
    }
    return results;
  }

  List<Appointment> _filterAppointments(
    List<Appointment> appointments,
    Map<String, Service> serviceLookup,
  ) {
    final filters = _filters;
    final operatorFilter = filters.operatorIds;
    final serviceFilter = filters.serviceIds;
    final categoryFilter = filters.categoryIds;
    final channelFilter = filters.bookingChannels
        .map((channel) => channel.toLowerCase())
        .toSet();

    return appointments.where((appointment) {
      if (!_isInRange(appointment.createdAt ?? appointment.start)) {
        return false;
      }
      if (operatorFilter.isNotEmpty &&
          !operatorFilter.contains(appointment.staffId)) {
        return false;
      }
      if (channelFilter.isNotEmpty) {
        final bookingChannel = appointment.bookingChannel?.toLowerCase();
        if (bookingChannel == null ||
            !channelFilter.contains(bookingChannel)) {
          return false;
        }
      }
      final servicesForAppointment = appointment.serviceIds;
      if (serviceFilter.isNotEmpty &&
          !servicesForAppointment.any(serviceFilter.contains)) {
        return false;
      }
      if (categoryFilter.isNotEmpty) {
        final matchesCategory = servicesForAppointment.any((serviceId) {
          final categoryId = serviceLookup[serviceId]?.categoryId;
          if (categoryId == null) {
            return false;
          }
          return categoryFilter.contains(categoryId);
        });
        if (!matchesCategory) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  List<Client> _filterClients(List<Client> clients) {
    return clients
        .where(
          (client) => _isInRange(
            client.createdAt ?? client.firstLoginAt ?? client.invitationSentAt,
          ),
        )
        .toList(growable: false);
  }

  bool _isInRange(DateTime? value) {
    if (value == null) {
      return false;
    }
    final normalized = value.toLocal();
    final range = _filters.range;
    return !normalized.isBefore(range.start) && !normalized.isAfter(range.end);
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.range,
    required this.dateFormatter,
    required this.onRangeChanged,
    required this.salons,
    required this.selectedSalonId,
    required this.onSalonChanged,
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
  });

  final DateTimeRange range;
  final DateFormat dateFormatter;
  final ValueChanged<DateTimeRange> onRangeChanged;

  final List<Salon> salons;
  final String? selectedSalonId;
  final ValueChanged<String?> onSalonChanged;

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

  Future<void> _selectRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: DateTime(range.start.year, range.start.month, range.start.day),
        end: DateTime(range.end.year, range.end.month, range.end.day),
      ),
    );
    if (picked != null) {
      final normalized = DateTimeRange(
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
      );
      onRangeChanged(normalized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controls = <Widget>[
      _buildRangeField(context),
      _buildDropdown(
        context: context,
        label: 'Salone',
        value: _ensureValue(selectedSalonId, salons.map((e) => e.id)),
        onChanged: onSalonChanged,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tutti i saloni'),
          ),
          ...salons.map(
            (salon) => DropdownMenuItem<String?>(
              value: salon.id,
              child: Text(salon.name),
            ),
          ),
        ],
      ),
      _buildDropdown(
        context: context,
        label: 'Operatore',
        value: _ensureValue(
          selectedOperatorId,
          staffMembers.map((e) => e.id),
        ),
        onChanged: onOperatorChanged,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tutti gli operatori'),
          ),
          ...staffMembers.sortedByDisplayOrder().map(
            (member) => DropdownMenuItem<String?>(
              value: member.id,
              child: Text(member.fullName),
            ),
          ),
        ],
      ),
      _buildDropdown(
        context: context,
        label: 'Categoria servizio',
        value: _ensureValue(
          selectedCategoryId,
          categories.map((category) => category.id),
        ),
        onChanged: onCategoryChanged,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tutte le categorie'),
          ),
          ...categories.map(
            (category) => DropdownMenuItem<String?>(
              value: category.id,
              child: Text(category.name),
            ),
          ),
        ],
      ),
      _buildDropdown(
        context: context,
        label: 'Servizio',
        value: _ensureValue(selectedServiceId, services.map((service) => service.id)),
        onChanged: onServiceChanged,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tutti i servizi'),
          ),
          ..._sortedServices().map(
            (service) => DropdownMenuItem<String?>(
              value: service.id,
              child: Text(service.name),
            ),
          ),
        ],
      ),
      _buildDropdown(
        context: context,
        label: 'Canale prenotazione',
        value: _ensureValue(
          selectedBookingChannel,
          bookingChannels,
        ),
        onChanged: onBookingChannelChanged,
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Tutti i canali'),
          ),
          ...bookingChannels.map(
            (channel) => DropdownMenuItem<String?>(
              value: channel,
              child: Text(_formatChannelLabel(channel)),
            ),
          ),
        ],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: controls,
        );
      },
    );
  }

  Widget _buildRangeField(BuildContext context) {
    final theme = Theme.of(context);
    final label = '${dateFormatter.format(range.start)} → ${dateFormatter.format(range.end)}';
    return SizedBox(
      width: 260,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectRange(context),
          child: InputDecorator(
            isFocused: false,
            isEmpty: false,
            decoration: InputDecoration(
              labelText: 'Periodo',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isEnabled = items.length > 1;
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String?>(
        value: value,
        items: items,
        onChanged: isEnabled ? onChanged : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        isDense: true,
      ),
    );
  }

  static String? _ensureValue(String? value, Iterable<String> candidates) {
    if (value == null) {
      return null;
    }
    return candidates.contains(value) ? value : null;
  }

  List<Service> _sortedServices() {
    final list = services.toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return list;
  }
}

List<_TopService> _calculateTopServices(
  List<_FilteredSale> sales,
  Map<String, Service> serviceLookup,
) {
  final grouped = <String, _TopService>{};
  for (final filtered in sales) {
    for (final item in filtered.items) {
      final service = serviceLookup[item.referenceId];
      final name = service?.name ?? item.referenceId;
      final entry = grouped[item.referenceId];
      if (entry == null) {
        grouped[item.referenceId] = _TopService(
          name: name,
          quantity: item.quantity,
          revenue: item.amount,
        );
      } else {
        grouped[item.referenceId] = _TopService(
          name: name,
          quantity: entry.quantity + item.quantity,
          revenue: entry.revenue + item.amount,
        );
      }
    }
  }
  return grouped.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
}

List<_RevenuePoint> _groupRevenueByDate(
  List<_FilteredSale> sales,
  DateTimeRange range,
) {
  final bucket = <DateTime, double>{};
  final startDate =
      DateTime(range.start.year, range.start.month, range.start.day);
  final endDate = DateTime(range.end.year, range.end.month, range.end.day);
  for (var cursor = startDate;
      !cursor.isAfter(endDate);
      cursor = cursor.add(const Duration(days: 1))) {
    bucket[cursor] = 0;
  }
  for (final sale in sales) {
    final local = sale.sale.createdAt.toLocal();
    final key = DateTime(local.year, local.month, local.day);
    if (!bucket.containsKey(key)) {
      continue;
    }
    bucket[key] = (bucket[key] ?? 0) + sale.amount;
  }
  final entries =
      bucket.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  return entries
      .map((entry) => _RevenuePoint(date: entry.key, value: entry.value))
      .toList(growable: false);
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    this.badges = const <Widget>[],
    this.onDrillDown,
    this.drillDownLabel,
  });

  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final List<Widget> badges;
  final VoidCallback? onDrillDown;
  final String? drillDownLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final valueStyle = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.bold,
      letterSpacing: -0.4,
    );
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      elevation: 1,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(value, style: valueStyle),
            const SizedBox(height: 4),
            Text(subtitle, style: subtitleStyle),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: badges,
              ),
            ],
            if (onDrillDown != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onDrillDown,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.outbond_rounded, size: 18),
                label: Text(drillDownLabel ?? 'Apri dettaglio'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterBadge extends StatelessWidget {
  const _FilterBadge({
    required this.label,
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.colorScheme.secondaryContainer;
    final foreground = theme.colorScheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilteredSale {
  const _FilteredSale({
    required this.sale,
    required this.amount,
    required this.items,
  });

  final Sale sale;
  final double amount;
  final List<SaleItem> items;
}

class _TopService {
  const _TopService({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final double quantity;
  final double revenue;
}

class _RevenuePoint {
  const _RevenuePoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.insights_rounded, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.insights_outlined,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (onAction != null && (actionLabel?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueTrendCard extends StatelessWidget {
  const _RevenueTrendCard({
    required this.trend,
    required this.currency,
    this.onOpenDetails,
  });

  final List<_RevenuePoint> trend;
  final NumberFormat currency;
  final VoidCallback? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final maxValue = trend.fold<double>(
      0,
      (prev, point) => math.max(prev, point.value),
    );
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onOpenDetails != null) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpenDetails,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.outbond_rounded, size: 18),
                  label: const Text('Apri vendite'),
                ),
              ),
              const SizedBox(height: 4),
            ],
            for (final point in trend)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 112,
                      child: Text(
                        DateFormat('EEE dd MMM', 'it_IT').format(point.date),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Tooltip(
                        message: currency.format(point.value),
                        triggerMode: TooltipTriggerMode.tap,
                        child: LinearProgressIndicator(
                          value:
                              maxValue == 0
                                  ? 0
                                  : (point.value / maxValue).clamp(0.0, 1.0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: Text(
                        currency.format(point.value),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentsTable extends StatelessWidget {
  const _AppointmentsTable({
    required this.appointments,
    required this.dateFormatter,
  });

  final List<Appointment> appointments;
  final DateFormat dateFormatter;

  @override
  Widget build(BuildContext context) {
    final buckets = _bucketize();
    if (buckets.isEmpty) {
      return const _EmptyState(message: 'Nessun appuntamento registrato');
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Data')),
            DataColumn(label: Text('Totale')),
            DataColumn(label: Text('Completati')),
            DataColumn(label: Text('Cancellati')),
            DataColumn(label: Text('No show')),
          ],
          rows:
              buckets
                  .map(
                    (bucket) => DataRow(
                      cells: [
                        DataCell(Text(dateFormatter.format(bucket.date))),
                        DataCell(Text('${bucket.total}')),
                        DataCell(Text('${bucket.completed}')),
                        DataCell(Text('${bucket.cancelled}')),
                        DataCell(Text('${bucket.noShow}')),
                      ],
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }

  List<_AppointmentBucket> _bucketize() {
    final map = <DateTime, _AppointmentBucket>{};
    for (final appointment in appointments) {
      final local = (appointment.createdAt ?? appointment.start).toLocal();
      final key = DateTime(local.year, local.month, local.day);
      final bucket = map.putIfAbsent(key, () => _AppointmentBucket(date: key));
      switch (appointment.status) {
        case AppointmentStatus.completed:
          bucket.completed += 1;
          break;
        case AppointmentStatus.cancelled:
          bucket.cancelled += 1;
          break;
        case AppointmentStatus.noShow:
          bucket.noShow += 1;
          break;
        case AppointmentStatus.scheduled:
          bucket.scheduled += 1;
          break;
      }
    }
    final buckets =
        map.values.toList()..sort((a, b) => a.date.compareTo(b.date));
    return buckets;
  }
}

class _AppointmentBucket {
  _AppointmentBucket({required this.date});

  final DateTime date;
  int completed = 0;
  int cancelled = 0;
  int noShow = 0;
  int scheduled = 0;

  int get total => completed + cancelled + noShow + scheduled;
}

class _TopServicesTable extends StatelessWidget {
  const _TopServicesTable({required this.entries, required this.currency});

  final List<_TopService> entries;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Servizio')),
            DataColumn(label: Text('Quantità')),
            DataColumn(label: Text('Fatturato')),
          ],
          rows:
              entries
                  .map(
                    (service) => DataRow(
                      cells: [
                        DataCell(Text(service.name)),
                        DataCell(Text(service.quantity.toStringAsFixed(0))),
                        DataCell(Text(currency.format(service.revenue))),
                      ],
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class _ReportSummary {
  const _ReportSummary({
    required this.totalRevenue,
    required this.salesCount,
    required this.averageTicket,
    required this.newClients,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.noShowAppointments,
    required this.scheduledAppointments,
  });

  final double totalRevenue;
  final int salesCount;
  final double averageTicket;
  final int newClients;
  final int completedAppointments;
  final int cancelledAppointments;
  final int noShowAppointments;
  final int scheduledAppointments;

  int get totalAppointments =>
      completedAppointments +
      cancelledAppointments +
      noShowAppointments +
      scheduledAppointments;

  double get completionRate =>
      totalAppointments == 0 ? 0 : completedAppointments / totalAppointments;

  static _ReportSummary compute({
    required List<_FilteredSale> sales,
    required List<Appointment> appointments,
    required List<Client> clients,
  }) {
    final totalRevenue =
        sales.fold<double>(0, (sum, entry) => sum + entry.amount);
    final salesCount = sales.length;
    final averageTicket = salesCount == 0 ? 0 : totalRevenue / salesCount;
    final newClients = clients.length;
    final completed =
        appointments
            .where((appt) => appt.status == AppointmentStatus.completed)
            .length;
    final cancelled =
        appointments
            .where((appt) => appt.status == AppointmentStatus.cancelled)
            .length;
    final noShow =
        appointments
            .where((appt) => appt.status == AppointmentStatus.noShow)
            .length;
    final scheduled =
        appointments
            .where((appt) => appt.status == AppointmentStatus.scheduled)
            .length;

    return _ReportSummary(
      totalRevenue: totalRevenue,
      salesCount: salesCount,
      averageTicket: averageTicket.toDouble(),
      newClients: newClients,
      completedAppointments: completed,
      cancelledAppointments: cancelled,
      noShowAppointments: noShow,
      scheduledAppointments: scheduled,
    );
  }
}
