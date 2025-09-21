import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ReportsModule extends ConsumerWidget {
  const ReportsModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');

    final filteredSales = data.sales
        .where((sale) => salonId == null || sale.salonId == salonId)
        .toList();
    final filteredAppointments = data.appointments
        .where((appointment) => salonId == null || appointment.salonId == salonId)
        .toList();
    final filteredServices = data.services
        .where((service) => salonId == null || service.salonId == salonId)
        .toList();

    final monthlyGroups = groupBy<Sale, String>(
      filteredSales,
      (sale) => DateFormat('yyyy-MM').format(sale.createdAt),
    );

    final monthlyTotals = monthlyGroups.entries.map((entry) {
      final total = entry.value.fold<double>(0, (sum, sale) => sum + sale.total);
      return _MonthlyTotal(month: entry.key, value: total);
    }).sorted((a, b) => b.month.compareTo(a.month));

    final topServices = _calculateTopServices(filteredSales, filteredServices);

    final totalAppointments = filteredAppointments.length;
    final completed = filteredAppointments.where((app) => app.status == AppointmentStatus.completed).length;
    final cancelled = filteredAppointments.where((app) => app.status == AppointmentStatus.cancelled).length;
    final noShow = filteredAppointments.where((app) => app.status == AppointmentStatus.noShow).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ReportCard(
                title: 'Incasso totale',
                subtitle: 'Vendite registrate',
                value: currency.format(filteredSales.fold<double>(0, (sum, sale) => sum + sale.total)),
                icon: Icons.account_balance_wallet_rounded,
              ),
              _ReportCard(
                title: 'Appuntamenti conclusi',
                subtitle: 'Su $totalAppointments totali',
                value: '$completed',
                icon: Icons.check_circle_rounded,
              ),
              _ReportCard(
                title: 'Annullati',
                subtitle: 'Cancellazioni cliente/staff',
                value: '$cancelled',
                icon: Icons.cancel_schedule_send_rounded,
              ),
              _ReportCard(
                title: 'No show',
                subtitle: 'Mancate presentazioni',
                value: '$noShow',
                icon: Icons.report_problem_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Andamento mensile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (monthlyTotals.isEmpty)
            const Card(child: ListTile(title: Text('Nessuna vendita registrata')))
          else
            _MonthlyChartPlaceholder(monthlyTotals: monthlyTotals, currency: currency),
          const SizedBox(height: 24),
          Text('Servizi più venduti', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (topServices.isEmpty)
            const Card(child: ListTile(title: Text('Nessuna vendita di servizi registrata')))
          else
            Card(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Servizio')),
                  DataColumn(label: Text('Quantità')),
                  DataColumn(label: Text('Fatturato')),
                ],
                rows: topServices
                    .map(
                      (service) => DataRow(
                        cells: [
                          DataCell(Text(service.name)),
                          DataCell(Text('${service.quantity}')),
                          DataCell(Text(currency.format(service.revenue))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<_TopService> _calculateTopServices(List<Sale> sales, List<Service> services) {
    final grouped = <String, _TopService>{};
    for (final sale in sales) {
      for (final item in sale.items) {
        if (item.referenceType == SaleReferenceType.service) {
          final name = services.firstWhereOrNull((service) => service.id == item.referenceId)?.name ?? item.referenceId;
          final entry = grouped[item.referenceId];
          if (entry == null) {
            grouped[item.referenceId] = _TopService(name: name, quantity: item.quantity, revenue: item.amount);
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
    return grouped.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));
  }
}

class _MonthlyChartPlaceholder extends StatelessWidget {
  const _MonthlyChartPlaceholder({required this.monthlyTotals, required this.currency});

  final List<_MonthlyTotal> monthlyTotals;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grafico vendite (placeholder)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...monthlyTotals.take(6).map(
              (total) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(width: 120, child: Text(_formatMonth(total.month))),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (total.value / monthlyTotals.first.value).clamp(0.0, 1.0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(currency.format(total.value)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonth(String month) {
    final date = DateFormat('yyyy-MM').parse(month);
    return DateFormat('MMMM yyyy', 'it_IT').format(date);
  }
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
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyTotal {
  const _MonthlyTotal({required this.month, required this.value});

  final String month;
  final double value;
}

class _TopService {
  const _TopService({required this.name, required this.quantity, required this.revenue});

  final String name;
  final double quantity;
  final double revenue;
}
