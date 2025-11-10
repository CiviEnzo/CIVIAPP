import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/cash_flow_entry.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/package.dart';
import 'package:you_book/domain/entities/payment_ticket.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/cash_flow_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/sale_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/modules/sales/sale_helpers.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class SalesModule extends ConsumerStatefulWidget {
  const SalesModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<SalesModule> createState() => _SalesModuleState();
}

class _SalesModuleState extends ConsumerState<SalesModule> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateUtils.dateOnly(now);
  }

  void _setSelectedDate(DateTime date) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(date);
    });
  }

  void _changeDay(int offset) {
    _setSelectedDate(_selectedDate.add(Duration(days: offset)));
  }

  Future<void> _pickDate(
    BuildContext context, {
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      _setSelectedDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final salonId = widget.salonId;
    final data = ref.watch(appDataProvider);
    final sales =
        data.sales
            .where((sale) => salonId == null || sale.salonId == salonId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final allCashFlow =
        data.cashFlowEntries
            .where((entry) => salonId == null || entry.salonId == salonId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final income = allCashFlow
        .where((entry) => entry.type == CashFlowType.income)
        .fold<double>(0, (total, entry) => total + entry.amount);
    final salons = data.salons;
    final clients = data.clients;
    final staff = data.staff;
    final services = data.services;
    final packages = data.packages;
    final inventoryItems = data.inventoryItems;
    final paymentTickets =
        data.paymentTickets
            .where((ticket) => salonId == null || ticket.salonId == salonId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final openTickets =
        paymentTickets
            .where((ticket) => ticket.status == PaymentTicketStatus.open)
            .toList()
          ..sort((a, b) => a.appointmentStart.compareTo(b.appointmentStart));

    final cashFlow =
        allCashFlow
            .where(
              (entry) =>
                  DateUtils.isSameDay(entry.createdAt.toLocal(), _selectedDate),
            )
            .toList();
    final today = DateUtils.dateOnly(DateTime.now());
    final fallbackStartDate = today.subtract(const Duration(days: 365));
    final earliestEntryDate =
        allCashFlow.isEmpty
            ? null
            : DateUtils.dateOnly(allCashFlow.last.createdAt.toLocal());
    final firstAvailableDate =
        earliestEntryDate == null
            ? fallbackStartDate
            : (earliestEntryDate.isBefore(fallbackStartDate)
                ? earliestEntryDate
                : fallbackStartDate);
    final canGoBackward = _selectedDate.isAfter(firstAvailableDate);
    final canGoForward = _selectedDate.isBefore(today);
    final formattedSelectedDate = DateFormat.yMMMMEEEEd(
      'it_IT',
    ).format(_selectedDate);
    final ticketDateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final selectedSales =
        sales
            .where(
              (sale) =>
                  DateUtils.isSameDay(sale.createdAt.toLocal(), _selectedDate),
            )
            .toList();
    final selectedEarnedPoints = selectedSales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.resolvedEarnedPoints,
    );
    final selectedRedeemedPoints = selectedSales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.redeemedPoints,
    );

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
                icon: Icons.receipt_long_rounded,
                title: 'Ticket aperti',
                value: openTickets.length.toString(),
                subtitle: 'Pagamenti da registrare',
              ),
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
                icon: Icons.stars_rounded,
                title: 'Punti netti',
                value: '${selectedEarnedPoints - selectedRedeemedPoints} pt',
                subtitle:
                    'Assegnati: $selectedEarnedPoints • Usati: $selectedRedeemedPoints',
              ),
              /*_SummaryTile(
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
              ),*/
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed:
                    () => openSaleForm(
                      context,
                      ref,
                      salons: salons,
                      clients: clients,
                      staff: staff,
                      services: services,
                      packages: packages,
                      inventory: inventoryItems,
                      sales: sales,
                      defaultSalonId: salonId,
                    ),
                icon: const Icon(Icons.point_of_sale_rounded),
                label: const Text('Registra vendita'),
              ),
              /* FilledButton.icon(
                onPressed:
                    () => _openCashFlowForm(
                      context,
                      ref,
                      salons: salons,
                      staff: staff,
                      defaultSalonId: salonId,
                    ),
                icon: const Icon(Icons.attach_money_rounded),
                label: const Text('Movimento cassa'),
              ),*/
            ],
          ),
          const SizedBox(height: 24),
          Text('Ticket aperti', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (openTickets.isEmpty)
            const Card(
              child: ListTile(title: Text('Nessun ticket da completare')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: openTickets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ticket = openTickets[index];
                final clientName =
                    clients
                        .firstWhereOrNull(
                          (client) => client.id == ticket.clientId,
                        )
                        ?.fullName ??
                    'Cliente';
                final staffName =
                    ticket.staffId == null
                        ? null
                        : staff
                            .firstWhereOrNull(
                              (member) => member.id == ticket.staffId,
                            )
                            ?.fullName;
                final service = services.firstWhereOrNull(
                  (item) => item.id == ticket.serviceId,
                );
                final serviceName =
                    service?.name ?? ticket.serviceName ?? 'Servizio';
                final amount = ticket.expectedTotal ?? service?.price;
                final appointmentDate = ticketDateFormat.format(
                  ticket.appointmentStart,
                );
                return Card(
                  child: ListTile(
                    onTap:
                        () => openSaleForm(
                          context,
                          ref,
                          salons: salons,
                          clients: clients,
                          staff: staff,
                          services: services,
                          packages: packages,
                          inventory: inventoryItems,
                          sales: sales,
                          defaultSalonId: salonId,
                          ticket: ticket,
                        ),
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(clientName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(serviceName),
                        const SizedBox(height: 4),
                        Text(
                          staffName == null
                              ? appointmentDate
                              : '$appointmentDate · $staffName',
                        ),
                        if (ticket.notes != null &&
                            ticket.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(ticket.notes!),
                        ],
                      ],
                    ),
                    trailing:
                        amount != null
                            ? Text(
                              currency.format(amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                            ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          Text('Ticket chiusi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Giorno precedente',
                onPressed: canGoBackward ? () => _changeDay(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: TextButton(
                  onPressed:
                      () => _pickDate(
                        context,
                        firstDate: firstAvailableDate,
                        lastDate: today,
                      ),
                  child: Text(
                    formattedSelectedDate,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Giorno successivo',
                onPressed: canGoForward ? () => _changeDay(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              IconButton(
                tooltip: 'Seleziona data',
                onPressed:
                    () => _pickDate(
                      context,
                      firstDate: firstAvailableDate,
                      lastDate: today,
                    ),
                icon: const Icon(Icons.event_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (cashFlow.isEmpty)
            const Card(
              child: ListTile(title: Text('Nessun movimento registrato')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cashFlow.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = cashFlow[index];
                final entryDate = entry.date.toLocal();
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          entry.type == CashFlowType.income
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                      child: Icon(
                        entry.type == CashFlowType.income
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    title: Text(entry.description ?? 'Movimento'),
                    subtitle: Text(
                      '${DateFormat('dd/MM/yyyy').format(entryDate)} · ${entry.category ?? 'Generale'}',
                    ),
                    trailing: Text(
                      currency.format(entry.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            entry.type == CashFlowType.income
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 24),
          /* Text(
            'Vendite recenti',
            style: Theme.of(context).textTheme.titleLarge,
          ),
           const SizedBox(height: 12),
          if (sales.isEmpty)
            const Card(
              child: ListTile(title: Text('Nessuna vendita registrata')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final sale = sales[index];
                final client =
                    data.clients
                        .firstWhereOrNull((c) => c.id == sale.clientId)
                        ?.fullName ??
                    'Cliente';
                final staffName =
                    sale.staffId == null
                        ? null
                        : data.staff
                            .firstWhereOrNull(
                              (member) => member.id == sale.staffId,
                            )
                            ?.fullName;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(client),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (staffName != null) ...[
                          Text('Staff: $staffName'),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          'Pagamento: ${_paymentLabel(sale.paymentMethod)} · Stato: ${sale.paymentStatus.label} · ${sale.invoiceNumber ?? 'No Fiscale'}',
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children:
                              sale.items
                                  .map(
                                    (item) => Chip(
                                      label: Text(
                                        '${item.description} · ${item.quantity} × ${currency.format(item.unitPrice)}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        if (sale.discountAmount > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Sconto applicato: ${currency.format(sale.discountAmount)}',
                          ),
                        ],
                        if (sale.paymentStatus == SalePaymentStatus.deposit) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Incassato: ${currency.format(sale.paidAmount)} · Residuo: ${currency.format(sale.outstandingAmount)}',
                          ),
                        ],
                        if (sale.notes != null && sale.notes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Note: ${sale.notes}'),
                        ],
                      ],
                    ),
                    trailing:
                        sale.paymentStatus == SalePaymentStatus.deposit
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currency.format(sale.total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Incassato ${currency.format(sale.paidAmount)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              )
                            : Text(
                                currency.format(sale.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: sales.length,
            ),
      */
        ],
      ),
    );
  }

  // ignore: unused_element
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
      case PaymentMethod.posticipated:
        return 'Posticipato';
    }
  }
}

Future<void> openSaleForm(
  BuildContext context,
  WidgetRef ref, {
  required List<Salon> salons,
  required List<Client> clients,
  required List<StaffMember> staff,
  required List<Service> services,
  required List<ServicePackage> packages,
  required List<InventoryItem> inventory,
  required List<Sale> sales,
  String? defaultSalonId,
  PaymentTicket? ticket,
}) async {
  if (salons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crea un salone prima di registrare vendite.'),
      ),
    );
    return;
  }
  final matchedService =
      ticket == null
          ? null
          : services.firstWhereOrNull(
            (service) => service.id == ticket.serviceId,
          );
  final initialItems =
      ticket == null
          ? null
          : [
            SaleItem(
              referenceId: ticket.serviceId,
              referenceType: SaleReferenceType.service,
              description:
                  matchedService?.name ?? ticket.serviceName ?? 'Servizio',
              quantity: 1,
              unitPrice: matchedService?.price ?? ticket.expectedTotal ?? 0,
            ),
          ];
  final sale = await showAppModalSheet<Sale>(
    context: context,
    builder:
        (ctx) => SaleFormSheet(
          salons: salons,
          clients: clients,
          staff: staff,
          services: services,
          packages: packages,
          inventoryItems: inventory,
          sales: sales,
          defaultSalonId: ticket?.salonId ?? defaultSalonId,
          initialClientId: ticket?.clientId,
          initialItems: initialItems,
          initialNotes: ticket?.notes,
          initialDate: ticket?.appointmentEnd,
          initialStaffId: ticket?.staffId,
        ),
  );
  if (sale != null) {
    final store = ref.read(appDataProvider.notifier);
    await store.upsertSale(sale);
    await recordSaleCashFlow(ref: ref, sale: sale, clients: clients);
    if (ticket != null && sale.paymentStatus != SalePaymentStatus.posticipated) {
      await store.closePaymentTicket(ticket.id, saleId: sale.id);
    }
  }
}

// ignore: unused_element
Future<void> _openCashFlowForm(
  BuildContext context,
  WidgetRef ref, {
  required List<Salon> salons,
  required List<StaffMember> staff,
  String? defaultSalonId,
}) async {
  if (salons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crea un salone prima di gestire la cassa.'),
      ),
    );
    return;
  }
  final entry = await showAppModalSheet<CashFlowEntry>(
    context: context,
    builder:
        (ctx) => CashFlowFormSheet(
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
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
