import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/app/reporting_config.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/service.dart';

class ReportsModule extends ConsumerStatefulWidget {
  const ReportsModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<ReportsModule> createState() => _ReportsModuleState();
}

class _ReportsModuleState extends ConsumerState<ReportsModule> {
  late DateTimeRange _activeRange;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _activeRange = DateTimeRange(
      start: today.subtract(const Duration(days: 29)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(appDataProvider.notifier);
    final data = ref.watch(appDataProvider.select((state) => state));
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormatter = DateFormat('dd/MM/yyyy');

    final sales = _filterSales(store.reportingSales(salonId: widget.salonId));
    final appointments =
        _filterAppointments(store.reportingAppointments(salonId: widget.salonId));
    final clients = _filterClients(store.reportingClients(salonId: widget.salonId));
    final services = data.services
        .where((service) => widget.salonId == null || service.salonId == widget.salonId)
        .toList(growable: false);

    final summary = _ReportSummary.compute(
      sales: sales,
      appointments: appointments,
      clients: clients,
    );

    final revenueTrend = _groupRevenueByDate(sales);
    final topServices = _calculateTopServices(sales, services);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _FiltersBar(
                range: _activeRange,
                dateFormatter: dateFormatter,
                onRangeChanged: (range) => setState(() => _activeRange = range),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
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
              ),
              _ReportCard(
                title: 'Vendite registrate',
                subtitle: 'Ticket medi: ${currency.format(summary.averageTicket)}',
                value: '${summary.salesCount}',
                icon: Icons.receipt_long_rounded,
              ),
              _ReportCard(
                title: 'Nuovi clienti',
                subtitle: 'Registrati nel periodo',
                value: '${summary.newClients}',
                icon: Icons.person_add_alt_1_rounded,
              ),
              _ReportCard(
                title: 'Appuntamenti completati',
                subtitle:
                    'Completion rate ${(summary.completionRate * 100).toStringAsFixed(1)}%',
                value: '${summary.completedAppointments}',
                icon: Icons.event_available_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Andamento incassi'),
          const SizedBox(height: 12),
          revenueTrend.isEmpty
              ? const _EmptyState(message: 'Nessuna vendita nel periodo selezionato')
              : _RevenueTrendCard(trend: revenueTrend, currency: currency),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Appuntamenti'),
          const SizedBox(height: 12),
          appointments.isEmpty
              ? const _EmptyState(message: 'Nessun appuntamento registrato')
              : _AppointmentsTable(appointments: appointments, dateFormatter: dateFormatter),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Servizi più venduti'),
          const SizedBox(height: 12),
          topServices.isEmpty
              ? const _EmptyState(message: 'Nessuna vendita di servizi nel periodo')
              : _TopServicesTable(entries: topServices, currency: currency),
        ],
      ),
    );
  }

  List<Sale> _filterSales(List<Sale> sales) {
    return sales.where((sale) => _isInRange(sale.createdAt)).toList(growable: false);
  }

  List<Appointment> _filterAppointments(List<Appointment> appointments) {
    return appointments
        .where(
          (appointment) => _isInRange(
            appointment.createdAt ?? appointment.start,
          ),
        )
        .toList(growable: false);
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
    return !normalized.isBefore(_activeRange.start) &&
        !normalized.isAfter(_activeRange.end);
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.range,
    required this.dateFormatter,
    required this.onRangeChanged,
  });

  final DateTimeRange range;
  final DateFormat dateFormatter;
  final ValueChanged<DateTimeRange> onRangeChanged;

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
        start: DateTime(picked.start.year, picked.start.month, picked.start.day),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
      onRangeChanged(normalized);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Intervallo temporale'),
              const SizedBox(height: 4),
              Text(
                '${dateFormatter.format(range.start)} → ${dateFormatter.format(range.end)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: () => _selectRange(context),
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('Modifica'),
        ),
      ],
    );
  }
}

List<_TopService> _calculateTopServices(
  List<Sale> sales,
  List<Service> services,
) {
  final grouped = <String, _TopService>{};
  for (final sale in sales) {
    for (final item in sale.items) {
      if (item.referenceType == SaleReferenceType.service) {
        final name =
            services
                .firstWhereOrNull((service) => service.id == item.referenceId)
                ?.name ??
            item.referenceId;
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
  }
  return grouped.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
}

List<_RevenuePoint> _groupRevenueByDate(List<Sale> sales) {
  final bucket = <DateTime, double>{};
  for (final sale in sales) {
    final local = sale.createdAt.toLocal();
    final key = DateTime(local.year, local.month, local.day);
    bucket[key] = (bucket[key] ?? 0) + sale.total;
  }
  final entries = bucket.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
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
  });

  final String title;
  final String subtitle;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
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
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _RevenueTrendCard extends StatelessWidget {
  const _RevenueTrendCard({required this.trend, required this.currency});

  final List<_RevenuePoint> trend;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final maxValue = trend.fold<double>(0, (prev, point) => math.max(prev, point.value));
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      child: LinearProgressIndicator(
                        value: maxValue == 0 ? 0 : (point.value / maxValue).clamp(0.0, 1.0),
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
  const _AppointmentsTable({required this.appointments, required this.dateFormatter});

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
          rows: buckets
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
    final buckets = map.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
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
          rows: entries
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
      completedAppointments + cancelledAppointments + noShowAppointments + scheduledAppointments;

  double get completionRate =>
      totalAppointments == 0 ? 0 : completedAppointments / totalAppointments;

  static _ReportSummary compute({
    required List<Sale> sales,
    required List<Appointment> appointments,
    required List<Client> clients,
  }) {
    final totalRevenue = sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final salesCount = sales.length;
    final averageTicket = salesCount == 0 ? 0 : totalRevenue / salesCount;
    final newClients = clients.length;
    final completed = appointments.where((appt) => appt.status == AppointmentStatus.completed).length;
    final cancelled = appointments.where((appt) => appt.status == AppointmentStatus.cancelled).length;
    final noShow = appointments.where((appt) => appt.status == AppointmentStatus.noShow).length;
    final scheduled = appointments.where((appt) => appt.status == AppointmentStatus.scheduled).length;

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
