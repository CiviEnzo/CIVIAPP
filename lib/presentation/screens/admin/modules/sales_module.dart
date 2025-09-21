import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/cash_flow_entry.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/cash_flow_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/sale_form_sheet.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SalesModule extends ConsumerWidget {
  const SalesModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final sales = data.sales
        .where((sale) => salonId == null || sale.salonId == salonId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final cashFlow = data.cashFlowEntries
        .where((entry) => salonId == null || entry.salonId == salonId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final income = cashFlow.where((entry) => entry.type == CashFlowType.income).fold<double>(0, (total, entry) => total + entry.amount);
    final expense = cashFlow.where((entry) => entry.type == CashFlowType.expense).fold<double>(0, (total, entry) => total + entry.amount);
    final salons = data.salons;
    final clients = data.clients;
    final staff = data.staff;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _SummaryTile(
                icon: Icons.point_of_sale_rounded,
                title: 'Vendite',
                value: sales.length.toString(),
                subtitle: 'Totale scontrini',
              ),
              _SummaryTile(
                icon: Icons.payments_rounded,
                title: 'Incasso',
                value: currency.format(income),
                subtitle: 'Entrate registrate',
              ),
              _SummaryTile(
                icon: Icons.money_off_csred_rounded,
                title: 'Uscite',
                value: currency.format(expense),
                subtitle: 'Spese registrate',
              ),
              _SummaryTile(
                icon: Icons.assessment_rounded,
                title: 'Margine',
                value: currency.format(income - expense),
                subtitle: 'Entrate - Uscite',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => _openSaleForm(
                  context,
                  ref,
                  salons: salons,
                  clients: clients,
                  defaultSalonId: salonId,
                ),
                icon: const Icon(Icons.point_of_sale_rounded),
                label: const Text('Registra vendita'),
              ),
              FilledButton.icon(
                onPressed: () => _openCashFlowForm(
                  context,
                  ref,
                  salons: salons,
                  staff: staff,
                  defaultSalonId: salonId,
                ),
                icon: const Icon(Icons.attach_money_rounded),
                label: const Text('Movimento cassa'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Vendite recenti', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (sales.isEmpty)
            const Card(child: ListTile(title: Text('Nessuna vendita registrata')))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final sale = sales[index];
                final client = data.clients.firstWhereOrNull((c) => c.id == sale.clientId)?.fullName ?? 'Cliente';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(client),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pagamento: ${_paymentLabel(sale.paymentMethod)} · ${sale.invoiceNumber ?? 'No Fiscale'}'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: sale.items
                              .map(
                                (item) => Chip(
                                  label: Text('${item.description} · ${item.quantity} × ${currency.format(item.unitPrice)}'),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                    trailing: Text(currency.format(sale.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: sales.length,
            ),
          const SizedBox(height: 24),
          Text('Movimenti di cassa', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (cashFlow.isEmpty)
            const Card(child: ListTile(title: Text('Nessun movimento registrato')))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cashFlow.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = cashFlow[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: entry.type == CashFlowType.income
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      child: Icon(
                        entry.type == CashFlowType.income ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    title: Text(entry.description ?? 'Movimento'),
                    subtitle: Text('${DateFormat('dd/MM/yyyy').format(entry.date)} · ${entry.category ?? 'Generale'}'),
                    trailing: Text(
                      currency.format(entry.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: entry.type == CashFlowType.income
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _paymentLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Contanti';
      case PaymentMethod.pos:
        return 'POS';
      case PaymentMethod.transfer:
        return 'Bonifico';
      case PaymentMethod.giftCard:
        return 'Gift card';
    }
  }
}

Future<void> _openSaleForm(
  BuildContext context,
  WidgetRef ref, {
  required List<Salon> salons,
  required List<Client> clients,
  String? defaultSalonId,
}) async {
  if (salons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crea un salone prima di registrare vendite.')),
    );
    return;
  }
  final sale = await showAppModalSheet<Sale>(
    context: context,
    builder: (ctx) => SaleFormSheet(
      salons: salons,
      clients: clients,
      defaultSalonId: defaultSalonId,
    ),
  );
  if (sale != null) {
    await ref.read(appDataProvider.notifier).upsertSale(sale);
  }
}

Future<void> _openCashFlowForm(
  BuildContext context,
  WidgetRef ref, {
  required List<Salon> salons,
  required List<StaffMember> staff,
  String? defaultSalonId,
}) async {
  if (salons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crea un salone prima di gestire la cassa.')),
    );
    return;
  }
  final entry = await showAppModalSheet<CashFlowEntry>(
    context: context,
    builder: (ctx) => CashFlowFormSheet(
      salons: salons,
      staff: staff,
      defaultSalonId: defaultSalonId,
    ),
  );
  if (entry != null) {
    await ref.read(appDataProvider.notifier).upsertCashFlowEntry(entry);
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

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
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
