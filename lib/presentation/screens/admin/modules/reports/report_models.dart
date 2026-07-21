import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportsQueryKeys {
  const ReportsQueryKeys._();

  static const prefix = 'reports_';
  static const dateFrom = 'reports_from';
  static const dateTo = 'reports_to';
  static const salon = 'reports_salon';
  static const operators = 'reports_operators';
  static const services = 'reports_services';
  static const categories = 'reports_categories';
  static const channels = 'reports_channels';
  static const tab = 'reports_tab';
}

enum ReportsTab { dashboard, analytics, export }

extension ReportsTabX on ReportsTab {
  String get queryValue => name;

  String get label {
    switch (this) {
      case ReportsTab.dashboard:
        return 'Dashboard';
      case ReportsTab.analytics:
        return 'Analytics';
      case ReportsTab.export:
        return 'Export';
    }
  }

  static ReportsTab fromQuery(String? value) {
    return ReportsTab.values.firstWhere(
      (tab) => tab.queryValue == value,
      orElse: () => ReportsTab.dashboard,
    );
  }
}

enum ReportPreviewMetric { sales, appointments, clients, occupancy }

extension ReportPreviewMetricX on ReportPreviewMetric {
  String get label {
    switch (this) {
      case ReportPreviewMetric.sales:
        return 'Vendite';
      case ReportPreviewMetric.appointments:
        return 'Appuntamenti';
      case ReportPreviewMetric.clients:
        return 'Clienti';
      case ReportPreviewMetric.occupancy:
        return 'Occupazione';
    }
  }
}

enum ReportAnalyticsSection {
  sales,
  expenses,
  appointments,
  clients,
  staff,
  inventory,
  marketing,
}

extension ReportAnalyticsSectionX on ReportAnalyticsSection {
  String get label {
    switch (this) {
      case ReportAnalyticsSection.sales:
        return 'Vendite';
      case ReportAnalyticsSection.expenses:
        return 'Uscite';
      case ReportAnalyticsSection.appointments:
        return 'Appuntamenti';
      case ReportAnalyticsSection.clients:
        return 'Clienti';
      case ReportAnalyticsSection.staff:
        return 'Staff';
      case ReportAnalyticsSection.inventory:
        return 'Inventario';
      case ReportAnalyticsSection.marketing:
        return 'Marketing';
    }
  }
}

enum ReportExportDataset {
  sales,
  expenses,
  appointments,
  clients,
  staff,
  inventory,
  marketing,
}

extension ReportExportDatasetX on ReportExportDataset {
  String get label {
    switch (this) {
      case ReportExportDataset.sales:
        return 'Vendite';
      case ReportExportDataset.expenses:
        return 'Uscite';
      case ReportExportDataset.appointments:
        return 'Appuntamenti';
      case ReportExportDataset.clients:
        return 'Clienti';
      case ReportExportDataset.staff:
        return 'Staff';
      case ReportExportDataset.inventory:
        return 'Magazzino';
      case ReportExportDataset.marketing:
        return 'Marketing';
    }
  }

  String get fileStem {
    switch (this) {
      case ReportExportDataset.sales:
        return 'vendite';
      case ReportExportDataset.expenses:
        return 'uscite';
      case ReportExportDataset.appointments:
        return 'appuntamenti';
      case ReportExportDataset.clients:
        return 'clienti';
      case ReportExportDataset.staff:
        return 'staff';
      case ReportExportDataset.inventory:
        return 'magazzino';
      case ReportExportDataset.marketing:
        return 'marketing';
    }
  }
}

String formatReportChannelLabel(String channel) {
  if (channel.isEmpty) {
    return channel;
  }
  final normalized = channel.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) {
    return channel;
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

class ReportFilters {
  ReportFilters({
    required this.range,
    this.salonId,
    Set<String> operatorIds = const <String>{},
    Set<String> serviceIds = const <String>{},
    Set<String> categoryIds = const <String>{},
    Set<String> bookingChannels = const <String>{},
  }) : operatorIds = Set<String>.unmodifiable(operatorIds),
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
  static const Object _unset = Object();
  static final SetEquality<String> _setEquality = const SetEquality<String>();

  factory ReportFilters.initial({String? defaultSalonId}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return ReportFilters(
      range: DateTimeRange(
        start: today.subtract(const Duration(days: 29)),
        end: DateTime(today.year, today.month, today.day, 23, 59, 59),
      ),
      salonId: defaultSalonId,
    );
  }

  factory ReportFilters.fromUri(Uri uri, {required String? defaultSalonId}) {
    final base = ReportFilters.initial(defaultSalonId: defaultSalonId);
    final params = uri.queryParameters;
    final parsedRange = _parseRange(
      params[ReportsQueryKeys.dateFrom],
      params[ReportsQueryKeys.dateTo],
    );

    final salonParam = params[ReportsQueryKeys.salon];
    final resolvedSalon =
        salonParam != null && salonParam.isNotEmpty
            ? salonParam
            : defaultSalonId;

    return ReportFilters(
      range: parsedRange ?? base.range,
      salonId: resolvedSalon,
      operatorIds: _parseSet(params[ReportsQueryKeys.operators]),
      serviceIds: _parseSet(params[ReportsQueryKeys.services]),
      categoryIds: _parseSet(params[ReportsQueryKeys.categories]),
      bookingChannels: _parseSet(params[ReportsQueryKeys.channels]),
    );
  }

  ReportFilters copyWith({
    DateTimeRange? range,
    Object? salonId = _unset,
    Set<String>? operatorIds,
    Set<String>? serviceIds,
    Set<String>? categoryIds,
    Set<String>? bookingChannels,
  }) {
    return ReportFilters(
      range: range ?? this.range,
      salonId: identical(salonId, _unset) ? this.salonId : salonId as String?,
      operatorIds: operatorIds ?? this.operatorIds,
      serviceIds: serviceIds ?? this.serviceIds,
      categoryIds: categoryIds ?? this.categoryIds,
      bookingChannels: bookingChannels ?? this.bookingChannels,
    );
  }

  Map<String, String> toQueryParameters() {
    final params = <String, String>{
      ReportsQueryKeys.dateFrom: _queryDateFormatter.format(
        DateTime(range.start.year, range.start.month, range.start.day),
      ),
      ReportsQueryKeys.dateTo: _queryDateFormatter.format(
        DateTime(range.end.year, range.end.month, range.end.day),
      ),
    };
    if (salonId != null && salonId!.isNotEmpty) {
      params[ReportsQueryKeys.salon] = salonId!;
    }
    if (operatorIds.isNotEmpty) {
      params[ReportsQueryKeys.operators] = _sorted(operatorIds).join(',');
    }
    if (serviceIds.isNotEmpty) {
      params[ReportsQueryKeys.services] = _sorted(serviceIds).join(',');
    }
    if (categoryIds.isNotEmpty) {
      params[ReportsQueryKeys.categories] = _sorted(categoryIds).join(',');
    }
    if (bookingChannels.isNotEmpty) {
      params[ReportsQueryKeys.channels] = _sorted(bookingChannels).join(',');
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
    if (other is! ReportFilters) return false;
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

class ReportComparisonWindow {
  ReportComparisonWindow({required this.current, required this.previous});

  final DateTimeRange current;
  final DateTimeRange previous;

  int get totalDays => current.end.difference(current.start).inDays + 1;

  static DateTimeRange normalizeRange(DateTimeRange range) {
    return DateTimeRange(
      start: DateTime(range.start.year, range.start.month, range.start.day),
      end: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59),
    );
  }

  factory ReportComparisonWindow.fromCurrent(DateTimeRange sourceRange) {
    final current = normalizeRange(sourceRange);
    final totalDays = current.end.difference(current.start).inDays + 1;
    final previousEnd = current.start.subtract(const Duration(seconds: 1));
    final previousStart = DateTime(
      previousEnd.year,
      previousEnd.month,
      previousEnd.day,
    ).subtract(Duration(days: totalDays - 1));
    return ReportComparisonWindow(
      current: current,
      previous: DateTimeRange(
        start: previousStart,
        end: DateTime(
          previousEnd.year,
          previousEnd.month,
          previousEnd.day,
          23,
          59,
          59,
        ),
      ),
    );
  }
}
