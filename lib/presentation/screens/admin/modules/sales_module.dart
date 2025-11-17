import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/appointment.dart';
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

  static const int _clientBillingTabIndex = 6;

  void _openClientBillingTab(String clientId) {
    ref
        .read(adminDashboardIntentProvider.notifier)
        .state = AdminDashboardIntent(
      moduleId: 'clients',
      payload: {'clientId': clientId, 'detailTabIndex': _clientBillingTabIndex},
    );
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
    final appointments = data.appointments;
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
    final closedTickets =
        paymentTickets
            .where((ticket) => ticket.status == PaymentTicketStatus.closed)
            .where((ticket) {
              final closedAt = ticket.closedAt ?? ticket.createdAt;
              return DateUtils.isSameDay(closedAt.toLocal(), _selectedDate);
            })
            .toList()
          ..sort((a, b) {
            final aAt = a.closedAt ?? a.createdAt;
            final bAt = b.closedAt ?? b.createdAt;
            return bAt.compareTo(aAt);
          });
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
    final closedTicketSaleIds =
        closedTickets.map((ticket) => ticket.saleId).whereNotNull().toSet();
    final salesWithoutTicket =
        selectedSales
            .where((sale) => !closedTicketSaleIds.contains(sale.id))
            .toList();
    final completedEntries = <_CompletedEntry>[];
    for (final ticket in closedTickets) {
      final client = clients.firstWhereOrNull(
        (client) => client.id == ticket.clientId,
      );
      final staffName =
          ticket.staffId == null
              ? null
              : staff
                  .firstWhereOrNull((member) => member.id == ticket.staffId)
                  ?.fullName;
      final appointment = appointments.firstWhereOrNull(
        (item) => item.id == ticket.appointmentId,
      );
      final sale =
          ticket.saleId == null
              ? null
              : sales.firstWhereOrNull((item) => item.id == ticket.saleId);
      final serviceName = _ticketServiceLabel(ticket, appointment, services);
      final amount =
          sale?.total ??
          ticket.expectedTotal ??
          services
              .firstWhereOrNull((item) => item.id == ticket.serviceId)
              ?.price;
      completedEntries.add(
        _CompletedEntry(
          date: ticket.closedAt ?? ticket.createdAt,
          clientName: client?.fullName ?? 'Cliente',
          clientId: client?.id,
          onOpenClientBilling:
              client == null ? null : () => _openClientBillingTab(client.id),
          staffName: staffName,
          serviceName: serviceName,
          amount: amount,
          ticket: ticket,
          sale: sale,
        ),
      );
    }
    for (final sale in salesWithoutTicket) {
      final client = clients.firstWhereOrNull(
        (client) => client.id == sale.clientId,
      );
      final staffName =
          sale.staffId == null
              ? null
              : staff
                  .firstWhereOrNull((member) => member.id == sale.staffId)
                  ?.fullName;
      completedEntries.add(
        _CompletedEntry(
          date: sale.createdAt,
          clientName: client?.fullName ?? 'Cliente',
          clientId: client?.id,
          onOpenClientBilling:
              client == null ? null : () => _openClientBillingTab(client.id),
          staffName: staffName,
          paymentLabel: _paymentMethodLabel(sale.paymentMethod),
          amount: sale.total,
          sale: sale,
        ),
      );
    }
    completedEntries.sort((a, b) => b.date.compareTo(a.date));
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
                      appointments: appointments,
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
                final client = clients.firstWhereOrNull(
                  (client) => client.id == ticket.clientId,
                );
                final clientName = client?.fullName ?? 'Cliente';
                final staffName =
                    ticket.staffId == null
                        ? null
                        : staff
                            .firstWhereOrNull(
                              (member) => member.id == ticket.staffId,
                            )
                            ?.fullName;
                final appointment = appointments.firstWhereOrNull(
                  (item) => item.id == ticket.appointmentId,
                );
                final serviceName = _ticketServiceLabel(
                  ticket,
                  appointment,
                  services,
                );
                final fallbackService = services.firstWhereOrNull(
                  (item) => item.id == ticket.serviceId,
                );
                final amount = ticket.expectedTotal ?? fallbackService?.price;
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
                          appointments: appointments,
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
                                fontSize: 16,
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
          Text(
            'Vendite concluse',
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
          if (completedEntries.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.receipt_long_rounded),
                title: Text('Nessuna vendita conclusa in questa data'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: completedEntries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = completedEntries[index];
                final creationLabel = DateFormat(
                  'dd/MM/yyyy HH:mm',
                  'it_IT',
                ).format(entry.date.toLocal());
                final subtitleLines = <String>['Registrato il $creationLabel'];
                if (entry.ticket != null) {
                  subtitleLines.add(entry.serviceName ?? 'Servizio');
                  subtitleLines.add(
                    '${ticketDateFormat.format(entry.ticket!.appointmentStart)} · Chiuso ${DateFormat('HH:mm', 'it_IT').format((entry.ticket!.closedAt ?? entry.ticket!.createdAt).toLocal())}',
                  );
                  if (entry.staffName != null) {
                    subtitleLines.add(entry.staffName!);
                  }
                } else if (entry.sale != null) {
                  if (entry.staffName != null) {
                    subtitleLines.add(entry.staffName!);
                  }
                  if (entry.paymentLabel != null) {
                    subtitleLines.add(entry.paymentLabel!);
                  }
                  final outstanding = entry.sale!.outstandingAmount;
                  if (outstanding > 0) {
                    subtitleLines.add(
                      'Residuo ${currency.format(outstanding)}',
                    );
                  }
                  if (entry.sale!.notes != null &&
                      entry.sale!.notes!.isNotEmpty) {
                    subtitleLines.add(entry.sale!.notes!);
                  }
                }
                return Card(
                  child: ListTile(
                    onTap:
                        entry.ticket != null
                            ? () => _showClosedTicketDetails(
                              context: context,
                              ticket: entry.ticket!,
                              clients: clients,
                              services: services,
                              staff: staff,
                              sales: sales,
                              clientId: entry.clientId,
                              onOpenClientBilling: entry.onOpenClientBilling,
                            )
                            : () => _showSaleDetails(
                              context: context,
                              sale: entry.sale!,
                              clientName: entry.clientName,
                              staffName: entry.staffName,
                              onOpenClientBilling: entry.onOpenClientBilling,
                            ),
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        entry.ticket != null
                            ? Icons.receipt_long_rounded
                            : Icons.point_of_sale_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(entry.clientName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var line in subtitleLines) ...[Text(line)],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (entry.amount != null)
                          Text(
                            currency.format(entry.amount!),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        else
                          const Icon(Icons.info_outline_rounded, size: 16),
                        if (entry.onOpenClientBilling != null) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            tooltip: 'Apri scheda fatturazione',
                            onPressed: entry.onOpenClientBilling,
                            icon: const Icon(Icons.open_in_new_rounded),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          /*  if (cashFlow.isEmpty)
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
                final client =
                    entry.clientId == null
                        ? null
                        : clients.firstWhereOrNull(
                          (client) => client.id == entry.clientId,
                        );
                final titleLabel =
                    client?.fullName ?? entry.description ?? 'Movimento';
                final dateLabel = DateFormat('dd/MM/yyyy').format(entryDate);
                final categoryLabel = entry.category ?? 'Generale';
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
                    title: Row(
                      children: [
                        Expanded(child: Text(titleLabel)),
                        if (client != null)
                          IconButton(
                            iconSize: 24,
                            tooltip: 'Apri scheda fatturazione',
                            onPressed: () => _openClientBillingTab(client.id),
                            icon: const Icon(Icons.open_in_new_rounded),
                          ),
                      ],
                    ),
                    subtitle: Text('$dateLabel · $categoryLabel'),
                    trailing: Text(
                      currency.format(entry.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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

          const SizedBox(height: 24),*/
          // civi cash test
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
                          'Pagamento: ${_paymentMethodLabel(sale.paymentMethod)} · Stato: ${sale.paymentStatus.label} · ${sale.invoiceNumber ?? 'No Fiscale'}',
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

  String _ticketServiceLabel(
    PaymentTicket ticket,
    Appointment? appointment,
    List<Service> services,
  ) {
    final serviceNames = <String>[];
    if (appointment != null) {
      for (final serviceId in appointment.serviceIds) {
        if (serviceId.isEmpty) {
          continue;
        }
        final service = services.firstWhereOrNull(
          (item) => item.id == serviceId,
        );
        serviceNames.add(service?.name ?? 'Servizio');
      }
    }
    if (serviceNames.isNotEmpty) {
      return serviceNames.join(' · ');
    }
    final matchedService = services.firstWhereOrNull(
      (item) => item.id == ticket.serviceId,
    );
    return matchedService?.name ?? ticket.serviceName ?? 'Servizio';
  }
}

String _paymentMethodLabel(PaymentMethod method) {
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
  required List<Appointment> appointments,
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
  final appointment =
      ticket == null
          ? null
          : appointments.firstWhereOrNull(
            (item) => item.id == ticket.appointmentId,
          );
  final initialItems =
      ticket == null
          ? null
          : _initialItemsFromTicket(ticket, appointment, services);
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
    if (ticket != null) {
      await store.closePaymentTicket(ticket.id, saleId: sale.id);
    }
  }
}

Future<void> _showClosedTicketDetails({
  required BuildContext context,
  required PaymentTicket ticket,
  required List<Client> clients,
  required List<Service> services,
  required List<StaffMember> staff,
  required List<Sale> sales,
  String? clientId,
  VoidCallback? onOpenClientBilling,
}) async {
  final client = clients.firstWhereOrNull(
    (client) => client.id == ticket.clientId,
  );
  final staffMember =
      ticket.staffId == null
          ? null
          : staff.firstWhereOrNull((member) => member.id == ticket.staffId);
  final service = services.firstWhereOrNull(
    (service) => service.id == ticket.serviceId,
  );
  final sale =
      ticket.saleId == null
          ? null
          : sales.firstWhereOrNull((item) => item.id == ticket.saleId);
  await showAppModalSheet<void>(
    context: context,
    builder:
        (_) => _ClosedTicketDetailsSheet(
          ticket: ticket,
          clientName: client?.fullName ?? 'Cliente',
          serviceName: service?.name ?? ticket.serviceName ?? 'Servizio',
          staffName: staffMember?.fullName,
          sale: sale,
          expectedTotal: ticket.expectedTotal,
          onOpenClientBilling: onOpenClientBilling,
        ),
  );
}

Future<void> _showSaleDetails({
  required BuildContext context,
  required Sale sale,
  required String clientName,
  String? staffName,
  VoidCallback? onOpenClientBilling,
}) async {
  await showAppModalSheet<void>(
    context: context,
    builder:
        (_) => _SaleDetailsSheet(
          sale: sale,
          clientName: clientName,
          staffName: staffName,
          onOpenClientBilling: onOpenClientBilling,
        ),
  );
}

List<SaleItem> _initialItemsFromTicket(
  PaymentTicket ticket,
  Appointment? appointment,
  List<Service> services,
) {
  final serviceIds =
      appointment?.serviceIds.where((id) => id.isNotEmpty).toList();
  if (serviceIds != null && serviceIds.isNotEmpty) {
    return serviceIds
        .map((serviceId) {
          final service = services.firstWhereOrNull(
            (item) => item.id == serviceId,
          );
          return SaleItem(
            referenceId: serviceId,
            referenceType: SaleReferenceType.service,
            description: service?.name ?? ticket.serviceName ?? 'Servizio',
            quantity: 1,
            unitPrice: service?.price ?? 0,
          );
        })
        .toList(growable: false);
  }
  final matchedService = services.firstWhereOrNull(
    (item) => item.id == ticket.serviceId,
  );
  return [
    SaleItem(
      referenceId: ticket.serviceId,
      referenceType: SaleReferenceType.service,
      description: matchedService?.name ?? ticket.serviceName ?? 'Servizio',
      quantity: 1,
      unitPrice: matchedService?.price ?? ticket.expectedTotal ?? 0,
    ),
  ];
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

class _ClosedTicketDetailsSheet extends StatelessWidget {
  const _ClosedTicketDetailsSheet({
    required this.ticket,
    required this.clientName,
    required this.serviceName,
    required this.sale,
    this.staffName,
    this.expectedTotal,
    this.onOpenClientBilling,
  });

  final PaymentTicket ticket;
  final String clientName;
  final String serviceName;
  final String? staffName;
  final Sale? sale;
  final double? expectedTotal;
  final VoidCallback? onOpenClientBilling;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'it_IT');
    final timeFormat = DateFormat('HH:mm', 'it_IT');
    final closedAt = ticket.closedAt ?? ticket.createdAt;
    final appointmentLabel =
        '${dateFormat.format(ticket.appointmentStart.toLocal())} – ${timeFormat.format(ticket.appointmentEnd.toLocal())}';
    final associatedSale = sale;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Dettaglio ticket chiuso', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          _DetailRow(
            label: 'Cliente',
            value: clientName,
            action: _buildClientHyperlinkAction(
              context,
              onOpenClientBilling,
              clientName,
            ),
          ),
          _DetailRow(label: 'Servizio', value: serviceName),
          if (staffName != null)
            _DetailRow(label: 'Operatore', value: staffName!),
          _DetailRow(label: 'Appuntamento', value: appointmentLabel),
          _DetailRow(
            label: 'Chiuso il',
            value: dateFormat.format(closedAt.toLocal()),
          ),
          _DetailRow(label: 'ID ticket', value: ticket.id),
          const Divider(height: 24),
          if (associatedSale != null) ...[
            Text('Vendita collegata', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Stato pagamento',
              value: associatedSale.paymentStatus.label,
            ),
            _DetailRow(
              label: 'Totale registrato',
              value: currency.format(associatedSale.total),
            ),
            _DetailRow(
              label: 'Pagato',
              value: currency.format(associatedSale.paidAmount),
            ),
            if (associatedSale.outstandingAmount > 0)
              _DetailRow(
                label: 'Residuo',
                value: currency.format(associatedSale.outstandingAmount),
              ),
          ] else if (expectedTotal != null) ...[
            Text('Vendita collegata', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Totale previsto',
              value: currency.format(expectedTotal!),
            ),
          ],
          if (ticket.notes != null && ticket.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Note', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(ticket.notes!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Chiudi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleDetailsSheet extends StatelessWidget {
  const _SaleDetailsSheet({
    required this.sale,
    required this.clientName,
    this.staffName,
    this.onOpenClientBilling,
  });

  final Sale sale;
  final String clientName;
  final String? staffName;
  final VoidCallback? onOpenClientBilling;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'it_IT');
    final createdAt = sale.createdAt.toLocal();
    final outstanding = sale.outstandingAmount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Dettaglio vendita', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          _DetailRow(
            label: 'Cliente',
            value: clientName,
            action: _buildClientHyperlinkAction(
              context,
              onOpenClientBilling,
              clientName,
            ),
          ),
          if (staffName != null) ...[
            _DetailRow(label: 'Operatore', value: staffName!),
          ],
          _DetailRow(label: 'Data', value: dateFormat.format(createdAt)),
          _DetailRow(
            label: 'Metodo di pagamento',
            value: _paymentMethodLabel(sale.paymentMethod),
          ),
          _DetailRow(label: 'Stato pagamento', value: sale.paymentStatus.label),
          _DetailRow(
            label: 'Totale registrato',
            value: currency.format(sale.total),
          ),
          _DetailRow(label: 'Pagato', value: currency.format(sale.paidAmount)),
          if (outstanding > 0)
            _DetailRow(label: 'Residuo', value: currency.format(outstanding)),
          if (sale.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Articoli', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final item in sale.items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.description.isNotEmpty
                          ? item.description
                          : 'Servizio',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    currency.format(item.amount),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              Text(
                '${item.quantity} × ${currency.format(item.unitPrice)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Note', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(sale.notes!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Chiudi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.action});

  final String label;
  final String value;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontWeight: FontWeight.w600);
    final labelStyle = theme.textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 2),
          if (action == null) Text(value, style: valueStyle) else action!,
        ],
      ),
    );
  }
}

class _CompletedEntry {
  const _CompletedEntry({
    required this.date,
    required this.clientName,
    required this.clientId,
    required this.onOpenClientBilling,
    this.staffName,
    this.serviceName,
    this.paymentLabel,
    this.amount,
    this.ticket,
    this.sale,
  });

  final DateTime date;
  final String clientName;
  final String? clientId;
  final VoidCallback? onOpenClientBilling;
  final String? staffName;
  final String? serviceName;
  final String? paymentLabel;
  final double? amount;
  final PaymentTicket? ticket;
  final Sale? sale;
}

Widget? _buildClientHyperlinkAction(
  BuildContext context,
  VoidCallback? action,
  String value,
) {
  if (action == null) {
    return null;
  }
  final theme = Theme.of(context);
  return TextButton.icon(
    style: TextButton.styleFrom(
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: theme.colorScheme.primary,
      textStyle: theme.textTheme.bodyMedium,
    ),
    icon: Icon(
      Icons.open_in_new_rounded,
      size: 16,
      color: theme.colorScheme.primary,
    ),
    label: Text(value),
    onPressed: () {
      Navigator.of(context).pop();
      action();
    },
  );
}
