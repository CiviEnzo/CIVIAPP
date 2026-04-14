import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:you_book/app/reporting_config.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/screens/admin/modules/reports/report_models.dart';

enum ReportTrendGranularity { daily, monthly }

class ReportTrendPoint {
  const ReportTrendPoint({
    required this.date,
    required this.value,
    this.estimated = false,
  });

  final DateTime date;
  final double value;
  final bool estimated;
}

class ReportOccupancySummary {
  const ReportOccupancySummary({
    required this.ratio,
    required this.bookedMinutes,
    required this.availableMinutes,
    required this.estimated,
  });

  final double? ratio;
  final int bookedMinutes;
  final int availableMinutes;
  final bool estimated;

  bool get hasCapacity => availableMinutes > 0;
}

class FilteredSaleRecord {
  const FilteredSaleRecord({
    required this.sale,
    required this.amount,
    required this.items,
  });

  final Sale sale;
  final double amount;
  final List<SaleItem> items;
}

class ReportPeriodSummary {
  const ReportPeriodSummary({
    required this.totalRevenue,
    required this.salesCount,
    required this.averageTicket,
    required this.newClients,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.noShowAppointments,
    required this.scheduledAppointments,
    required this.activeClients,
    required this.returningClients,
    required this.averageRevenuePerClient,
    required this.occupancy,
  });

  final double totalRevenue;
  final int salesCount;
  final double averageTicket;
  final int newClients;
  final int completedAppointments;
  final int cancelledAppointments;
  final int noShowAppointments;
  final int scheduledAppointments;
  final int activeClients;
  final int returningClients;
  final double averageRevenuePerClient;
  final ReportOccupancySummary occupancy;

  int get totalAppointments =>
      completedAppointments +
      cancelledAppointments +
      noShowAppointments +
      scheduledAppointments;

  double get completionRate =>
      totalAppointments == 0 ? 0 : completedAppointments / totalAppointments;

  double get cancellationRate =>
      totalAppointments == 0 ? 0 : cancelledAppointments / totalAppointments;

  double get noShowRate =>
      totalAppointments == 0 ? 0 : noShowAppointments / totalAppointments;

  double get returningClientsRate =>
      activeClients == 0 ? 0 : returningClients / activeClients;
}

class ReportTopServiceEntry {
  const ReportTopServiceEntry({
    required this.serviceId,
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String serviceId;
  final String name;
  final double quantity;
  final double revenue;
}

class ReportCategoryRevenueEntry {
  const ReportCategoryRevenueEntry({
    required this.categoryId,
    required this.label,
    required this.revenue,
  });

  final String categoryId;
  final String label;
  final double revenue;
}

class ReportLabeledValue {
  const ReportLabeledValue({required this.label, required this.value});

  final String label;
  final double value;
}

class ReportStaffPerformanceRow {
  const ReportStaffPerformanceRow({
    required this.staffId,
    required this.staffName,
    required this.revenue,
    required this.salesCount,
    required this.completedAppointments,
    required this.averageTicket,
    required this.occupancy,
  });

  final String staffId;
  final String staffName;
  final double revenue;
  final int salesCount;
  final int completedAppointments;
  final double averageTicket;
  final ReportOccupancySummary occupancy;
}

class ReportInventoryEntry {
  const ReportInventoryEntry({
    required this.item,
    required this.stockValue,
    required this.isLowStock,
    required this.isOutOfStock,
    required this.statusLabel,
  });

  final InventoryItem item;
  final double stockValue;
  final bool isLowStock;
  final bool isOutOfStock;
  final String statusLabel;
}

class ReportPromotionEntry {
  const ReportPromotionEntry({
    required this.promotion,
    required this.viewCount,
    required this.ctaClicks,
    required this.ctr,
  });

  final Promotion promotion;
  final int viewCount;
  final int ctaClicks;
  final double ctr;
}

class ReportsSnapshot {
  const ReportsSnapshot({
    required this.filters,
    required this.comparison,
    required this.selectedSalon,
    required this.current,
    required this.previous,
    required this.filteredSales,
    required this.filteredAppointments,
    required this.filteredClients,
    required this.currentActiveClientIds,
    required this.currentReturningClientIds,
    required this.trendGranularity,
    required this.revenueTrend,
    required this.appointmentTrend,
    required this.clientTrend,
    required this.occupancyTrend,
    required this.topServices,
    required this.revenueByCategory,
    required this.bookingChannelMix,
    required this.referralSources,
    required this.staffPerformance,
    required this.inventoryEntries,
    required this.inventoryAlerts,
    required this.promotionEntries,
    required this.clientLookup,
    required this.staffLookup,
    required this.serviceLookup,
    required this.categoryLookup,
  });

  final ReportFilters filters;
  final ReportComparisonWindow comparison;
  final Salon? selectedSalon;
  final ReportPeriodSummary current;
  final ReportPeriodSummary previous;
  final List<FilteredSaleRecord> filteredSales;
  final List<Appointment> filteredAppointments;
  final List<Client> filteredClients;
  final Set<String> currentActiveClientIds;
  final Set<String> currentReturningClientIds;
  final ReportTrendGranularity trendGranularity;
  final List<ReportTrendPoint> revenueTrend;
  final List<ReportTrendPoint> appointmentTrend;
  final List<ReportTrendPoint> clientTrend;
  final List<ReportTrendPoint> occupancyTrend;
  final List<ReportTopServiceEntry> topServices;
  final List<ReportCategoryRevenueEntry> revenueByCategory;
  final List<ReportLabeledValue> bookingChannelMix;
  final List<ReportLabeledValue> referralSources;
  final List<ReportStaffPerformanceRow> staffPerformance;
  final List<ReportInventoryEntry> inventoryEntries;
  final List<ReportInventoryEntry> inventoryAlerts;
  final List<ReportPromotionEntry> promotionEntries;
  final Map<String, Client> clientLookup;
  final Map<String, StaffMember> staffLookup;
  final Map<String, Service> serviceLookup;
  final Map<String, ServiceCategory> categoryLookup;

  bool get hasAnyData =>
      filteredSales.isNotEmpty ||
      filteredAppointments.isNotEmpty ||
      filteredClients.isNotEmpty ||
      inventoryEntries.isNotEmpty ||
      promotionEntries.isNotEmpty;

  double get inventoryValue =>
      inventoryEntries.fold<double>(0, (sum, entry) => sum + entry.stockValue);

  int get totalPromotionViews =>
      promotionEntries.fold<int>(0, (sum, entry) => sum + entry.viewCount);

  int get totalPromotionClicks =>
      promotionEntries.fold<int>(0, (sum, entry) => sum + entry.ctaClicks);

  double get promotionCtr {
    final views = totalPromotionViews;
    if (views <= 0) {
      return 0;
    }
    return totalPromotionClicks / views;
  }
}

class ReportsAggregator {
  const ReportsAggregator._();

  static ReportsSnapshot build({
    required AppDataState data,
    required ReportFilters filters,
  }) {
    final comparison = ReportComparisonWindow.fromCurrent(filters.range);
    final trendGranularity =
        comparison.totalDays > 62
            ? ReportTrendGranularity.monthly
            : ReportTrendGranularity.daily;

    final selectedSalon = data.salons.firstWhereOrNull(
      (salon) => salon.id == filters.salonId,
    );
    final salonScopedSalons =
        filters.salonId == null
            ? data.salons
            : data.salons
                .where((salon) => salon.id == filters.salonId)
                .toList(growable: false);

    final staffMembers = data.staff
        .where(
          (member) =>
              (filters.salonId == null || member.salonId == filters.salonId) &&
              member.isActive &&
              !member.isEquipment,
        )
        .toList(growable: false);
    final staffLookup = {for (final staff in staffMembers) staff.id: staff};
    final filteredStaffMembers =
        filters.operatorIds.isEmpty
            ? staffMembers
            : staffMembers
                .where((member) => filters.operatorIds.contains(member.id))
                .toList(growable: false);

    final services = data.services
        .where(
          (service) =>
              filters.salonId == null || service.salonId == filters.salonId,
        )
        .toList(growable: false);
    final serviceLookup = {for (final service in services) service.id: service};

    final categories = data.serviceCategories
        .where(
          (category) =>
              filters.salonId == null || category.salonId == filters.salonId,
        )
        .toList(growable: false);
    final categoryLookup = {
      for (final category in categories) category.id: category,
    };

    final clients = data.clients
        .where(
          (client) =>
              filters.salonId == null || client.salonId == filters.salonId,
        )
        .toList(growable: false);
    final clientLookup = {for (final client in clients) client.id: client};

    final allReportingSales = data.sales
        .where(
          (sale) => filters.salonId == null || sale.salonId == filters.salonId,
        )
        .where((sale) => includeInReporting(primary: sale.createdAt))
        .toList(growable: false);
    final allReportingAppointments = data.appointments
        .where(
          (appointment) =>
              filters.salonId == null || appointment.salonId == filters.salonId,
        )
        .where(
          (appointment) => includeInReporting(
            primary: appointment.createdAt,
            fallback: appointment.start,
          ),
        )
        .toList(growable: false);
    final allReportingClients = clients
        .where((client) => includeInReporting(primary: client.createdAt))
        .toList(growable: false);

    final currentSales = _filterSales(
      sales: allReportingSales,
      serviceLookup: serviceLookup,
      filters: filters,
      range: comparison.current,
    );
    final previousSales = _filterSales(
      sales: allReportingSales,
      serviceLookup: serviceLookup,
      filters: filters,
      range: comparison.previous,
    );

    final currentAppointments = _filterAppointments(
      appointments: allReportingAppointments,
      serviceLookup: serviceLookup,
      filters: filters,
      range: comparison.current,
    );
    final previousAppointments = _filterAppointments(
      appointments: allReportingAppointments,
      serviceLookup: serviceLookup,
      filters: filters,
      range: comparison.previous,
    );

    final currentClients = _filterClients(
      clients: allReportingClients,
      range: comparison.current,
    );
    final previousClients = _filterClients(
      clients: allReportingClients,
      range: comparison.previous,
    );

    final clientFirstEngagement = _buildClientFirstEngagementMap(
      sales: allReportingSales,
      appointments: allReportingAppointments,
    );

    final relevantShifts = data.shifts
        .where(
          (shift) =>
              filters.salonId == null || shift.salonId == filters.salonId,
        )
        .where((shift) => staffLookup.containsKey(shift.staffId))
        .toList(growable: false);

    final currentOccupancy = _calculateOccupancy(
      range: comparison.current,
      shifts: relevantShifts,
      appointments: currentAppointments,
      salons: salonScopedSalons,
      staffMembers: filteredStaffMembers,
    );
    final previousOccupancy = _calculateOccupancy(
      range: comparison.previous,
      shifts: relevantShifts,
      appointments: previousAppointments,
      salons: salonScopedSalons,
      staffMembers: filteredStaffMembers,
    );

    final currentClientIds = _activeClientIds(
      sales: currentSales,
      appointments: currentAppointments,
    );
    final previousClientIds = _activeClientIds(
      sales: previousSales,
      appointments: previousAppointments,
    );

    final currentReturningClients =
        currentClientIds.where((clientId) {
          final firstEngagement = clientFirstEngagement[clientId];
          return firstEngagement != null &&
              firstEngagement.isBefore(comparison.current.start);
        }).toSet();
    final previousReturningClients =
        previousClientIds.where((clientId) {
          final firstEngagement = clientFirstEngagement[clientId];
          return firstEngagement != null &&
              firstEngagement.isBefore(comparison.previous.start);
        }).toSet();

    final currentSummary = _buildPeriodSummary(
      sales: currentSales,
      appointments: currentAppointments,
      clients: currentClients,
      activeClientIds: currentClientIds,
      returningClientIds: currentReturningClients,
      occupancy: currentOccupancy,
    );
    final previousSummary = _buildPeriodSummary(
      sales: previousSales,
      appointments: previousAppointments,
      clients: previousClients,
      activeClientIds: previousClientIds,
      returningClientIds: previousReturningClients,
      occupancy: previousOccupancy,
    );

    final revenueTrend = _buildAmountTrend(
      sales: currentSales,
      range: comparison.current,
      granularity: trendGranularity,
    );
    final appointmentTrend = _buildAppointmentTrend(
      appointments: currentAppointments,
      range: comparison.current,
      granularity: trendGranularity,
    );
    final clientTrend = _buildClientTrend(
      clients: currentClients,
      range: comparison.current,
      granularity: trendGranularity,
    );
    final occupancyTrend = _buildOccupancyTrend(
      range: comparison.current,
      shifts: relevantShifts,
      appointments: currentAppointments,
      salons: salonScopedSalons,
      staffMembers: filteredStaffMembers,
      granularity: trendGranularity,
    );

    final topServices = _buildTopServices(currentSales, serviceLookup);
    final revenueByCategory = _buildRevenueByCategory(
      sales: currentSales,
      serviceLookup: serviceLookup,
      categoryLookup: categoryLookup,
    );
    final bookingChannelMix = _buildBookingChannelMix(currentAppointments);
    final referralSources = _buildReferralSources(currentClients);
    final staffPerformance = _buildStaffPerformance(
      staffMembers: filteredStaffMembers,
      allShifts: relevantShifts,
      sales: currentSales,
      appointments: currentAppointments,
      salons: salonScopedSalons,
      comparison: comparison.current,
    );

    final inventoryEntries =
        data.inventoryItems
            .where(
              (item) =>
                  filters.salonId == null || item.salonId == filters.salonId,
            )
            .map(_mapInventoryEntry)
            .toList()
          ..sort((a, b) {
            final criticalCompare = _inventoryPriority(
              b,
            ).compareTo(_inventoryPriority(a));
            if (criticalCompare != 0) {
              return criticalCompare;
            }
            return a.item.name.toLowerCase().compareTo(
              b.item.name.toLowerCase(),
            );
          });

    final inventoryAlerts = inventoryEntries
        .where((entry) => entry.isLowStock || entry.isOutOfStock)
        .toList(growable: false);

    final promotionEntries =
        data.promotions
            .where(
              (promotion) =>
                  filters.salonId == null ||
                  promotion.salonId == filters.salonId,
            )
            .where(
              (promotion) =>
                  _promotionMatchesRange(promotion, comparison.current),
            )
            .map((promotion) {
              final analytics =
                  promotion.analytics ?? const PromotionAnalytics();
              final views = analytics.viewCount;
              final clicks = analytics.ctaClickCount;
              final ctr = views <= 0 ? 0.0 : clicks / views.toDouble();
              return ReportPromotionEntry(
                promotion: promotion,
                viewCount: views,
                ctaClicks: clicks,
                ctr: ctr,
              );
            })
            .toList()
          ..sort((a, b) => b.viewCount.compareTo(a.viewCount));

    return ReportsSnapshot(
      filters: filters,
      comparison: comparison,
      selectedSalon: selectedSalon,
      current: currentSummary,
      previous: previousSummary,
      filteredSales: List.unmodifiable(currentSales),
      filteredAppointments: List.unmodifiable(currentAppointments),
      filteredClients: List.unmodifiable(currentClients),
      currentActiveClientIds: Set.unmodifiable(currentClientIds),
      currentReturningClientIds: Set.unmodifiable(currentReturningClients),
      trendGranularity: trendGranularity,
      revenueTrend: List.unmodifiable(revenueTrend),
      appointmentTrend: List.unmodifiable(appointmentTrend),
      clientTrend: List.unmodifiable(clientTrend),
      occupancyTrend: List.unmodifiable(occupancyTrend),
      topServices: List.unmodifiable(topServices),
      revenueByCategory: List.unmodifiable(revenueByCategory),
      bookingChannelMix: List.unmodifiable(bookingChannelMix),
      referralSources: List.unmodifiable(referralSources),
      staffPerformance: List.unmodifiable(staffPerformance),
      inventoryEntries: List.unmodifiable(inventoryEntries),
      inventoryAlerts: List.unmodifiable(inventoryAlerts),
      promotionEntries: List.unmodifiable(promotionEntries),
      clientLookup: Map.unmodifiable(clientLookup),
      staffLookup: Map.unmodifiable(staffLookup),
      serviceLookup: Map.unmodifiable(serviceLookup),
      categoryLookup: Map.unmodifiable(categoryLookup),
    );
  }

  static List<FilteredSaleRecord> _filterSales({
    required List<Sale> sales,
    required Map<String, Service> serviceLookup,
    required ReportFilters filters,
    required DateTimeRange range,
  }) {
    final operatorFilter = filters.operatorIds;
    final serviceFilter = filters.serviceIds;
    final categoryFilter = filters.categoryIds;
    final channelFilter =
        filters.bookingChannels.map((value) => value.toLowerCase()).toSet();

    final results = <FilteredSaleRecord>[];
    for (final sale in sales) {
      if (!_isInRange(sale.createdAt, range)) {
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
        relevantItems = serviceItems
            .where((item) {
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
            })
            .toList(growable: false);
        if (relevantItems.isEmpty) {
          continue;
        }
      }

      final amount =
          (serviceFilter.isEmpty && categoryFilter.isEmpty)
              ? sale.total
              : relevantItems.fold<double>(0, (sum, item) => sum + item.amount);
      if (amount <= 0) {
        continue;
      }
      results.add(
        FilteredSaleRecord(
          sale: sale,
          amount: amount,
          items: List.unmodifiable(relevantItems),
        ),
      );
    }

    results.sort((a, b) => b.sale.createdAt.compareTo(a.sale.createdAt));
    return results;
  }

  static List<Appointment> _filterAppointments({
    required List<Appointment> appointments,
    required Map<String, Service> serviceLookup,
    required ReportFilters filters,
    required DateTimeRange range,
  }) {
    final operatorFilter = filters.operatorIds;
    final serviceFilter = filters.serviceIds;
    final categoryFilter = filters.categoryIds;
    final channelFilter =
        filters.bookingChannels.map((value) => value.toLowerCase()).toSet();

    final results =
        appointments.where((appointment) {
          if (!_isInRange(appointment.start, range)) {
            return false;
          }
          if (operatorFilter.isNotEmpty &&
              !operatorFilter.contains(appointment.staffId)) {
            return false;
          }
          if (channelFilter.isNotEmpty) {
            final channel = appointment.bookingChannel?.toLowerCase();
            if (channel == null || !channelFilter.contains(channel)) {
              return false;
            }
          }
          if (serviceFilter.isNotEmpty &&
              !appointment.serviceIds.any(serviceFilter.contains)) {
            return false;
          }
          if (categoryFilter.isNotEmpty) {
            final matchesCategory = appointment.serviceIds.any((serviceId) {
              final categoryId = serviceLookup[serviceId]?.categoryId;
              return categoryId != null && categoryFilter.contains(categoryId);
            });
            if (!matchesCategory) {
              return false;
            }
          }
          return true;
        }).toList();
    results.sort((a, b) => a.start.compareTo(b.start));
    return List.unmodifiable(results);
  }

  static List<Client> _filterClients({
    required List<Client> clients,
    required DateTimeRange range,
  }) {
    final results =
        clients.where((client) {
            final anchor =
                client.createdAt ??
                client.firstLoginAt ??
                client.invitationSentAt;
            return _isInRange(anchor, range);
          }).toList()
          ..sort((a, b) {
            final left =
                a.createdAt ??
                a.firstLoginAt ??
                a.invitationSentAt ??
                DateTime(0);
            final right =
                b.createdAt ??
                b.firstLoginAt ??
                b.invitationSentAt ??
                DateTime(0);
            return left.compareTo(right);
          });
    return List.unmodifiable(results);
  }

  static Map<String, DateTime> _buildClientFirstEngagementMap({
    required List<Sale> sales,
    required List<Appointment> appointments,
  }) {
    final map = <String, DateTime>{};
    for (final sale in sales) {
      final current = map[sale.clientId];
      if (current == null || sale.createdAt.isBefore(current)) {
        map[sale.clientId] = sale.createdAt;
      }
    }
    for (final appointment in appointments) {
      final anchor = appointment.start;
      final current = map[appointment.clientId];
      if (current == null || anchor.isBefore(current)) {
        map[appointment.clientId] = anchor;
      }
    }
    return map;
  }

  static Set<String> _activeClientIds({
    required List<FilteredSaleRecord> sales,
    required List<Appointment> appointments,
  }) {
    return {
      ...sales.map((entry) => entry.sale.clientId).where((id) => id.isNotEmpty),
      ...appointments
          .map((appointment) => appointment.clientId)
          .where((id) => id.isNotEmpty),
    };
  }

  static ReportPeriodSummary _buildPeriodSummary({
    required List<FilteredSaleRecord> sales,
    required List<Appointment> appointments,
    required List<Client> clients,
    required Set<String> activeClientIds,
    required Set<String> returningClientIds,
    required ReportOccupancySummary occupancy,
  }) {
    final totalRevenue = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.amount,
    );
    final salesCount = sales.length;
    final averageTicket = salesCount == 0 ? 0.0 : totalRevenue / salesCount;
    final completed =
        appointments
            .where(
              (appointment) =>
                  appointment.status == AppointmentStatus.completed,
            )
            .length;
    final cancelled =
        appointments
            .where(
              (appointment) =>
                  appointment.status == AppointmentStatus.cancelled,
            )
            .length;
    final noShow =
        appointments
            .where(
              (appointment) => appointment.status == AppointmentStatus.noShow,
            )
            .length;
    final scheduled =
        appointments
            .where(
              (appointment) =>
                  appointment.status == AppointmentStatus.scheduled,
            )
            .length;
    final averageRevenuePerClient =
        activeClientIds.isEmpty ? 0.0 : totalRevenue / activeClientIds.length;

    return ReportPeriodSummary(
      totalRevenue: totalRevenue,
      salesCount: salesCount,
      averageTicket: averageTicket,
      newClients: clients.length,
      completedAppointments: completed,
      cancelledAppointments: cancelled,
      noShowAppointments: noShow,
      scheduledAppointments: scheduled,
      activeClients: activeClientIds.length,
      returningClients: returningClientIds.length,
      averageRevenuePerClient: averageRevenuePerClient,
      occupancy: occupancy,
    );
  }

  static List<ReportTopServiceEntry> _buildTopServices(
    List<FilteredSaleRecord> sales,
    Map<String, Service> serviceLookup,
  ) {
    final grouped = <String, ReportTopServiceEntry>{};
    for (final entry in sales) {
      for (final item in entry.items) {
        final serviceId = item.referenceId;
        final existing = grouped[serviceId];
        final name = serviceLookup[serviceId]?.name ?? item.description;
        if (existing == null) {
          grouped[serviceId] = ReportTopServiceEntry(
            serviceId: serviceId,
            name: name,
            quantity: item.quantity,
            revenue: item.amount,
          );
          continue;
        }
        grouped[serviceId] = ReportTopServiceEntry(
          serviceId: serviceId,
          name: existing.name,
          quantity: existing.quantity + item.quantity,
          revenue: existing.revenue + item.amount,
        );
      }
    }
    final results =
        grouped.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));
    return List.unmodifiable(results.take(8));
  }

  static List<ReportCategoryRevenueEntry> _buildRevenueByCategory({
    required List<FilteredSaleRecord> sales,
    required Map<String, Service> serviceLookup,
    required Map<String, ServiceCategory> categoryLookup,
  }) {
    final grouped = <String, double>{};
    final labels = <String, String>{};
    for (final entry in sales) {
      for (final item in entry.items) {
        final categoryId =
            serviceLookup[item.referenceId]?.categoryId ?? 'uncategorized';
        labels[categoryId] =
            categoryLookup[categoryId]?.name ?? 'Senza categoria';
        grouped[categoryId] = (grouped[categoryId] ?? 0) + item.amount;
      }
    }
    final results =
        grouped.entries
            .map(
              (entry) => ReportCategoryRevenueEntry(
                categoryId: entry.key,
                label: labels[entry.key] ?? entry.key,
                revenue: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return List.unmodifiable(results);
  }

  static List<ReportLabeledValue> _buildBookingChannelMix(
    List<Appointment> appointments,
  ) {
    final grouped = <String, double>{};
    for (final appointment in appointments) {
      final label = _channelLabel(appointment.bookingChannel);
      grouped[label] = (grouped[label] ?? 0) + 1;
    }
    final results =
        grouped.entries
            .map(
              (entry) =>
                  ReportLabeledValue(label: entry.key, value: entry.value),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return List.unmodifiable(results);
  }

  static List<ReportLabeledValue> _buildReferralSources(List<Client> clients) {
    final grouped = <String, double>{};
    for (final client in clients) {
      final label =
          (client.referralSource ?? '').trim().isEmpty
              ? 'Non specificato'
              : client.referralSource!.trim();
      grouped[label] = (grouped[label] ?? 0) + 1;
    }
    final results =
        grouped.entries
            .map(
              (entry) =>
                  ReportLabeledValue(label: entry.key, value: entry.value),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return List.unmodifiable(results);
  }

  static List<ReportStaffPerformanceRow> _buildStaffPerformance({
    required List<StaffMember> staffMembers,
    required List<Shift> allShifts,
    required List<FilteredSaleRecord> sales,
    required List<Appointment> appointments,
    required List<Salon> salons,
    required DateTimeRange comparison,
  }) {
    final rows = <ReportStaffPerformanceRow>[];
    for (final member in staffMembers.sortedByDisplayOrder()) {
      final staffSales =
          sales.where((entry) => entry.sale.staffId == member.id).toList();
      final staffAppointments =
          appointments
              .where((appointment) => appointment.staffId == member.id)
              .toList();
      final staffOccupancy = _calculateOccupancy(
        range: comparison,
        shifts: allShifts.where((shift) => shift.staffId == member.id).toList(),
        appointments: staffAppointments,
        salons: salons.where((salon) => salon.id == member.salonId).toList(),
        staffMembers: [member],
      );
      final revenue = staffSales.fold<double>(
        0,
        (sum, sale) => sum + sale.amount,
      );
      final salesCount = staffSales.length;
      final completedAppointments =
          staffAppointments
              .where(
                (appointment) =>
                    appointment.status == AppointmentStatus.completed,
              )
              .length;
      rows.add(
        ReportStaffPerformanceRow(
          staffId: member.id,
          staffName: member.fullName,
          revenue: revenue,
          salesCount: salesCount,
          completedAppointments: completedAppointments,
          averageTicket: salesCount == 0 ? 0 : revenue / salesCount,
          occupancy: staffOccupancy,
        ),
      );
    }
    rows.sort((a, b) => b.revenue.compareTo(a.revenue));
    return List.unmodifiable(rows);
  }

  static ReportInventoryEntry _mapInventoryEntry(InventoryItem item) {
    final isOutOfStock = item.quantity <= 0;
    final isLowStock = !isOutOfStock && item.quantity <= item.threshold;
    final statusLabel =
        isOutOfStock
            ? 'Esaurito'
            : isLowStock
            ? 'Scorta bassa'
            : 'Disponibile';
    return ReportInventoryEntry(
      item: item,
      stockValue: item.quantity * item.cost,
      isLowStock: isLowStock,
      isOutOfStock: isOutOfStock,
      statusLabel: statusLabel,
    );
  }

  static int _inventoryPriority(ReportInventoryEntry entry) {
    if (entry.isOutOfStock) {
      return 2;
    }
    if (entry.isLowStock) {
      return 1;
    }
    return 0;
  }

  static bool _promotionMatchesRange(Promotion promotion, DateTimeRange range) {
    final start = promotion.startsAt;
    final end = promotion.endsAt;
    if (start == null && end == null) {
      return true;
    }
    if (start != null && start.isAfter(range.end)) {
      return false;
    }
    if (end != null && end.isBefore(range.start)) {
      return false;
    }
    return true;
  }

  static List<ReportTrendPoint> _buildAmountTrend({
    required List<FilteredSaleRecord> sales,
    required DateTimeRange range,
    required ReportTrendGranularity granularity,
  }) {
    final bucket = _createBucket(range: range, granularity: granularity);
    for (final entry in sales) {
      final key = _bucketKey(entry.sale.createdAt, granularity);
      if (!bucket.containsKey(key)) {
        continue;
      }
      bucket[key] = (bucket[key] ?? 0) + entry.amount;
    }
    return _bucketToPoints(bucket);
  }

  static List<ReportTrendPoint> _buildAppointmentTrend({
    required List<Appointment> appointments,
    required DateTimeRange range,
    required ReportTrendGranularity granularity,
  }) {
    final bucket = _createBucket(range: range, granularity: granularity);
    for (final appointment in appointments) {
      final key = _bucketKey(appointment.start, granularity);
      if (!bucket.containsKey(key)) {
        continue;
      }
      bucket[key] = (bucket[key] ?? 0) + 1;
    }
    return _bucketToPoints(bucket);
  }

  static List<ReportTrendPoint> _buildClientTrend({
    required List<Client> clients,
    required DateTimeRange range,
    required ReportTrendGranularity granularity,
  }) {
    final bucket = _createBucket(range: range, granularity: granularity);
    for (final client in clients) {
      final anchor =
          client.createdAt ?? client.firstLoginAt ?? client.invitationSentAt;
      if (anchor == null) {
        continue;
      }
      final key = _bucketKey(anchor, granularity);
      if (!bucket.containsKey(key)) {
        continue;
      }
      bucket[key] = (bucket[key] ?? 0) + 1;
    }
    return _bucketToPoints(bucket);
  }

  static List<ReportTrendPoint> _buildOccupancyTrend({
    required DateTimeRange range,
    required List<Shift> shifts,
    required List<Appointment> appointments,
    required List<Salon> salons,
    required List<StaffMember> staffMembers,
    required ReportTrendGranularity granularity,
  }) {
    final dailyBuckets = _buildDailyOccupancyBuckets(
      range: range,
      shifts: shifts,
      appointments: appointments,
      salons: salons,
      staffMembers: staffMembers,
    );
    if (granularity == ReportTrendGranularity.daily) {
      return List.unmodifiable(
        dailyBuckets
            .where((bucket) => bucket.availableMinutes > 0)
            .map(
              (bucket) => ReportTrendPoint(
                date: bucket.day,
                value: bucket.ratio,
                estimated: bucket.estimated,
              ),
            ),
      );
    }

    final grouped = <DateTime, _OccupancyBucket>{};
    for (final bucket in dailyBuckets) {
      if (bucket.availableMinutes <= 0) {
        continue;
      }
      final monthKey = DateTime(bucket.day.year, bucket.day.month);
      final current = grouped.putIfAbsent(
        monthKey,
        () => _OccupancyBucket(day: monthKey),
      );
      current.bookedMinutes += bucket.bookedMinutes;
      current.availableMinutes += bucket.availableMinutes;
      current.estimated = current.estimated || bucket.estimated;
    }

    final results =
        grouped.values.toList()..sort((a, b) => a.day.compareTo(b.day));
    return List.unmodifiable(
      results
          .where((bucket) => bucket.availableMinutes > 0)
          .map(
            (bucket) => ReportTrendPoint(
              date: bucket.day,
              value: bucket.ratio,
              estimated: bucket.estimated,
            ),
          ),
    );
  }

  static ReportOccupancySummary _calculateOccupancy({
    required DateTimeRange range,
    required List<Shift> shifts,
    required List<Appointment> appointments,
    required List<Salon> salons,
    required List<StaffMember> staffMembers,
  }) {
    final buckets = _buildDailyOccupancyBuckets(
      range: range,
      shifts: shifts,
      appointments: appointments,
      salons: salons,
      staffMembers: staffMembers,
    );
    var bookedMinutes = 0;
    var availableMinutes = 0;
    var estimated = false;
    for (final bucket in buckets) {
      bookedMinutes += bucket.bookedMinutes;
      availableMinutes += bucket.availableMinutes;
      estimated = estimated || bucket.estimated;
    }
    return ReportOccupancySummary(
      ratio:
          availableMinutes <= 0
              ? null
              : bookedMinutes / math.max(availableMinutes, 1),
      bookedMinutes: bookedMinutes,
      availableMinutes: availableMinutes,
      estimated: estimated && availableMinutes > 0,
    );
  }

  static List<_OccupancyBucket> _buildDailyOccupancyBuckets({
    required DateTimeRange range,
    required List<Shift> shifts,
    required List<Appointment> appointments,
    required List<Salon> salons,
    required List<StaffMember> staffMembers,
  }) {
    final buckets = <_OccupancyBucket>[];
    var cursor = DateTime(range.start.year, range.start.month, range.start.day);
    final endDate = DateTime(range.end.year, range.end.month, range.end.day);
    while (!cursor.isAfter(endDate)) {
      final dayStart = cursor;
      final dayEnd = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        23,
        59,
        59,
      );
      final bucket = _OccupancyBucket(day: dayStart);

      for (final appointment in appointments) {
        if (appointment.status == AppointmentStatus.cancelled) {
          continue;
        }
        bucket.bookedMinutes += _overlapMinutes(
          appointment.start,
          appointment.end,
          dayStart,
          dayEnd,
        );
      }

      final dayShifts =
          shifts
              .where(
                (shift) =>
                    _hasOverlap(shift.start, shift.end, dayStart, dayEnd),
              )
              .toList();
      if (dayShifts.isNotEmpty) {
        for (final shift in dayShifts) {
          bucket.availableMinutes += _shiftAvailableMinutesForDay(
            shift: shift,
            dayStart: dayStart,
            dayEnd: dayEnd,
          );
        }
      } else {
        bucket.availableMinutes += _fallbackAvailableMinutesForDay(
          day: dayStart,
          salons: salons,
          staffMembers: staffMembers,
        );
        bucket.estimated = bucket.availableMinutes > 0;
      }

      if (bucket.availableMinutes > 0) {
        buckets.add(bucket);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return List.unmodifiable(buckets);
  }

  static int _shiftAvailableMinutesForDay({
    required Shift shift,
    required DateTime dayStart,
    required DateTime dayEnd,
  }) {
    final total = _overlapMinutes(shift.start, shift.end, dayStart, dayEnd);
    if (total <= 0) {
      return 0;
    }
    final breakStart = shift.breakStart;
    final breakEnd = shift.breakEnd;
    if (breakStart == null || breakEnd == null) {
      return total;
    }
    final breakMinutes = _overlapMinutes(
      breakStart,
      breakEnd,
      dayStart,
      dayEnd,
    );
    return math.max(0, total - breakMinutes);
  }

  static int _fallbackAvailableMinutesForDay({
    required DateTime day,
    required List<Salon> salons,
    required List<StaffMember> staffMembers,
  }) {
    if (salons.isEmpty || staffMembers.isEmpty) {
      return 0;
    }
    final staffCountBySalon = <String, int>{};
    for (final member in staffMembers) {
      staffCountBySalon[member.salonId] =
          (staffCountBySalon[member.salonId] ?? 0) + 1;
    }

    var totalMinutes = 0;
    for (final salon in salons) {
      final staffCount = staffCountBySalon[salon.id] ?? 0;
      if (staffCount <= 0) {
        continue;
      }
      final schedule = salon.schedule.firstWhereOrNull(
        (entry) => entry.weekday == day.weekday,
      );
      if (schedule == null ||
          !schedule.isOpen ||
          schedule.durationMinutes == null) {
        continue;
      }
      var availableForSalon = schedule.durationMinutes!;
      availableForSalon -= _closureMinutesForDay(
        day: day,
        salon: salon,
        openMinuteOfDay: schedule.openMinuteOfDay!,
        closeMinuteOfDay: schedule.closeMinuteOfDay!,
      );
      if (availableForSalon <= 0) {
        continue;
      }
      totalMinutes += availableForSalon * staffCount;
    }
    return totalMinutes;
  }

  static int _closureMinutesForDay({
    required DateTime day,
    required Salon salon,
    required int openMinuteOfDay,
    required int closeMinuteOfDay,
  }) {
    final open = DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: openMinuteOfDay));
    final close = DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: closeMinuteOfDay));
    var total = 0;
    for (final closure in salon.closures) {
      total += _overlapMinutes(closure.start, closure.end, open, close);
    }
    return total.clamp(0, close.difference(open).inMinutes).toInt();
  }

  static Map<DateTime, double> _createBucket({
    required DateTimeRange range,
    required ReportTrendGranularity granularity,
  }) {
    final bucket = <DateTime, double>{};
    if (granularity == ReportTrendGranularity.daily) {
      var cursor = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final endDate = DateTime(range.end.year, range.end.month, range.end.day);
      while (!cursor.isAfter(endDate)) {
        bucket[cursor] = 0;
        cursor = cursor.add(const Duration(days: 1));
      }
      return bucket;
    }

    var cursor = DateTime(range.start.year, range.start.month);
    final endMonth = DateTime(range.end.year, range.end.month);
    while (!cursor.isAfter(endMonth)) {
      bucket[cursor] = 0;
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return bucket;
  }

  static DateTime _bucketKey(
    DateTime value,
    ReportTrendGranularity granularity,
  ) {
    if (granularity == ReportTrendGranularity.daily) {
      return DateTime(value.year, value.month, value.day);
    }
    return DateTime(value.year, value.month);
  }

  static List<ReportTrendPoint> _bucketToPoints(Map<DateTime, double> bucket) {
    final entries =
        bucket.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return List.unmodifiable(
      entries
          .map((entry) => ReportTrendPoint(date: entry.key, value: entry.value))
          .toList(),
    );
  }

  static bool _isInRange(DateTime? value, DateTimeRange range) {
    if (value == null) {
      return false;
    }
    final local = value.toLocal();
    return !local.isBefore(range.start) && !local.isAfter(range.end);
  }

  static bool _hasOverlap(
    DateTime start,
    DateTime end,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
  }

  static int _overlapMinutes(
    DateTime start,
    DateTime end,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final effectiveStart = start.isAfter(rangeStart) ? start : rangeStart;
    final effectiveEnd = end.isBefore(rangeEnd) ? end : rangeEnd;
    if (!effectiveEnd.isAfter(effectiveStart)) {
      return 0;
    }
    return effectiveEnd.difference(effectiveStart).inMinutes;
  }

  static String _channelLabel(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Non specificato';
    }
    return formatReportChannelLabel(normalized);
  }
}

class _OccupancyBucket {
  _OccupancyBucket({required this.day});

  final DateTime day;
  int bookedMinutes = 0;
  int availableMinutes = 0;
  bool estimated = false;

  double get ratio =>
      availableMinutes <= 0 ? 0 : bookedMinutes / math.max(availableMinutes, 1);
}
