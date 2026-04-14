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
import 'package:you_book/presentation/screens/admin/modules/client_detail_page.dart';
import 'package:you_book/presentation/screens/admin/forms/cash_flow_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/sale_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/modules/sales/sale_helpers.dart';
import 'package:you_book/presentation/screens/admin/widgets/admin_responsive_helpers.dart';
import 'package:you_book/widgets/shared/badge/status_badge.dart';
import 'package:you_book/widgets/shared/states/empty_state.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  void _jumpToToday() {
    _setSelectedDate(DateTime.now());
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

  Future<void> _openClientBillingTab(String clientId) async {
    final isCompact = isCompactClientLayout(context);
    if (!isCompact) {
      ref
          .read(adminDashboardIntentProvider.notifier)
          .state = AdminDashboardIntent(
        moduleId: 'clients',
        payload: {
          'clientId': clientId,
          'detailTabIndex': _clientBillingTabIndex,
        },
      );
    }
    await openClientDetailPage(
      context,
      clientId: clientId,
      initialTabIndex: _clientBillingTabIndex,
      compactOnly: true,
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
                  DateUtils.isSameDay(entry.date.toLocal(), _selectedDate),
            )
            .toList();
    final closedTickets =
        paymentTickets
            .where((ticket) => ticket.status == PaymentTicketStatus.closed)
            .where(
              (ticket) => DateUtils.isSameDay(
                ticket.createdAt.toLocal(),
                _selectedDate,
              ),
            )
            .toList()
          ..sort((a, b) {
            return b.createdAt.compareTo(a.createdAt);
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
    final isToday = DateUtils.isSameDay(_selectedDate, today);
    final selectedWeekdayLabel =
        toBeginningOfSentenceCase(
          DateFormat.EEEE('it_IT').format(_selectedDate),
        ) ??
        DateFormat.EEEE('it_IT').format(_selectedDate);
    final selectedDateLabel = DateFormat(
      'd MMMM yyyy',
      'it_IT',
    ).format(_selectedDate);
    final selectedCompactDateLabel = DateFormat(
      'd MMM yyyy',
      'it_IT',
    ).format(_selectedDate);
    final quantityFormat = NumberFormat.decimalPattern('it_IT');

    final selectedSales =
        sales
            .where(
              (sale) =>
                  DateUtils.isSameDay(sale.createdAt.toLocal(), _selectedDate),
            )
            .toList();
    final closedTicketSaleIds =
        closedTickets.map((ticket) => ticket.saleId).nonNulls.toSet();
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
          date: ticket.createdAt,
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
    final selectedReceiptsCount = completedEntries.length;
    final selectedIncome = cashFlow
        .where((entry) => entry.type == CashFlowType.income)
        .fold<double>(0, (total, entry) => total + entry.amount);
    final selectedIncomeByPaymentMethod = <PaymentMethod, double>{
      for (final method in PaymentMethod.values) method: 0.0,
    };
    for (final sale in selectedSales) {
      if (sale.paymentStatus == SalePaymentStatus.posticipated) {
        continue;
      }
      final cashAmount =
          sale.paymentStatus == SalePaymentStatus.deposit
              ? sale.paidAmount
              : sale.total;
      if (cashAmount <= 0.009) {
        continue;
      }
      selectedIncomeByPaymentMethod.update(
        sale.paymentMethod,
        (value) => value + cashAmount,
      );
    }
    final incomeByMethodLines =
        PaymentMethod.values
            .where(
              (method) =>
                  (selectedIncomeByPaymentMethod[method] ?? 0).abs() > 0.009,
            )
            .map(
              (method) =>
                  '${_paymentMethodLabel(method)}: ${currency.format(selectedIncomeByPaymentMethod[method] ?? 0)}',
            )
            .toList();
    final classifiedIncome = selectedIncomeByPaymentMethod.values.fold<double>(
      0,
      (total, amount) => total + amount,
    );
    final unclassifiedIncome = selectedIncome - classifiedIncome;
    if (unclassifiedIncome.abs() > 0.009) {
      incomeByMethodLines.add(
        'Altri mov.: ${currency.format(unclassifiedIncome)}',
      );
    }
    final incomeSubtitle =
        incomeByMethodLines.isEmpty
            ? 'Totale incasso'
            : 'Totale incasso\n${incomeByMethodLines.join('\n')}';
    final selectedPackageItems =
        selectedSales
            .expand((sale) => sale.items)
            .where((item) => item.referenceType == SaleReferenceType.package)
            .toList();
    final selectedPackagesSoldCount = selectedPackageItems.fold<double>(
      0,
      (total, item) => total + item.quantity,
    );
    final selectedPackagesSoldAmount = selectedPackageItems.fold<double>(
      0,
      (total, item) => total + item.amount,
    );

    final completedRows = completedEntries.take(50).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final action = FilledButton.icon(
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
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nuova vendita'),
              );
              if (constraints.maxWidth < kAdminPhoneBreakpoint) {
                return SizedBox(width: double.infinity, child: action);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const Spacer(), action],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 1200
                      ? 4
                      : constraints.maxWidth >= 760
                      ? 2
                      : 1;
              final tileWidth =
                  columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - (12 * (columns - 1))) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryTile(
                    icon: Icons.receipt_long_rounded,
                    title: 'Vendite oggi',
                    value: selectedReceiptsCount.toString(),
                    subtitle: 'Scontrini chiusi',
                    width: tileWidth,
                  ),
                  _SummaryTile(
                    icon: Icons.payments_rounded,
                    title: 'Incasso oggi',
                    value: currency.format(selectedIncome),
                    subtitle: incomeSubtitle,
                    width: tileWidth,
                    accentColor: const Color(0xFF22C55E),
                  ),
                  _SummaryTile(
                    icon: Icons.calendar_month_rounded,
                    title: 'Incasso mese',
                    value: currency.format(
                      sales
                          .where(
                            (sale) =>
                                sale.createdAt.year == _selectedDate.year &&
                                sale.createdAt.month == _selectedDate.month,
                          )
                          .fold<double>(0, (sum, sale) => sum + sale.total),
                    ),
                    subtitle:
                        '${quantityFormat.format(selectedPackagesSoldCount)} pacchetti • ${currency.format(selectedPackagesSoldAmount)}',
                    width: tileWidth,
                    accentColor: Theme.of(context).colorScheme.primary,
                  ),
                  _SummaryTile(
                    icon: Icons.hourglass_bottom_rounded,
                    title: 'In attesa',
                    value: currency.format(
                      openTickets.fold<double>(
                        0,
                        (sum, ticket) => sum + (ticket.expectedTotal ?? 0),
                      ),
                    ),
                    subtitle: '${openTickets.length} ticket aperti',
                    width: tileWidth,
                    accentColor: const Color(0xFFF59E0B),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: AdminResponsiveHeader(
                title: 'Ticket aperti',
                trailing: Text(
                  '${openTickets.length} ticket',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          if (openTickets.isEmpty)
            const Card(
              margin: EdgeInsets.only(top: 8),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: SharedEmptyState(
                  title: 'Nessun ticket da completare',
                  description:
                      'I ticket aperti appariranno qui appena viene registrato un acconto o un pagamento parziale.',
                  icon: Icons.receipt_long_rounded,
                ),
              ),
            )
          else
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760) {
                    return Column(
                      key: const ValueKey('sales_open_tickets_mobile_list'),
                      children:
                          openTickets.map((ticket) {
                            final client = clients.firstWhereOrNull(
                              (item) => item.id == ticket.clientId,
                            );
                            final appointment = appointments.firstWhereOrNull(
                              (item) => item.id == ticket.appointmentId,
                            );
                            final serviceName = _ticketServiceLabel(
                              ticket,
                              appointment,
                              services,
                            );
                            final staffName =
                                ticket.staffId == null
                                    ? null
                                    : staff
                                        .firstWhereOrNull(
                                          (member) =>
                                              member.id == ticket.staffId,
                                        )
                                        ?.fullName;
                            final appointmentDate = DateFormat(
                              'dd/MM/yyyy HH:mm',
                              'it_IT',
                            ).format(ticket.appointmentStart.toLocal());
                            final amount = ticket.expectedTotal ?? 0;
                            return _MobileTicketSummaryCard(
                              codeLabel: 'N. ticket',
                              codeValue:
                                  'TKT-${ticket.id.substring(0, 4).toUpperCase()}',
                              rows: [
                                _MobileTicketSummaryRow(
                                  label: 'Cliente',
                                  value: client?.fullName ?? 'Cliente',
                                ),
                                _MobileTicketSummaryRow(
                                  label: 'Appuntamento',
                                  value: appointmentDate,
                                ),
                                _MobileTicketSummaryRow(
                                  label: 'Servizio',
                                  value: serviceName,
                                ),
                                _MobileTicketSummaryRow(
                                  label: 'Operatore',
                                  value: staffName ?? 'Non assegnato',
                                ),
                                _MobileTicketSummaryRow(
                                  label: 'Importo',
                                  value: currency.format(amount),
                                  valueColor:
                                      Theme.of(context).colorScheme.primary,
                                ),
                                const _MobileTicketSummaryRow(
                                  label: 'Stato',
                                  child: StatusBadge(
                                    status: BadgeStatus.pending,
                                    label: 'In attesa',
                                  ),
                                ),
                              ],
                              actions: [
                                _MobileTicketActionButton(
                                  tooltip: 'Apri ticket',
                                  icon: Icons.visibility_outlined,
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
                                        ticket: ticket,
                                      ),
                                ),
                                _MobileTicketActionButton(
                                  tooltip: 'Apri scheda cliente',
                                  icon: Icons.open_in_new_rounded,
                                  onPressed:
                                      client == null
                                          ? null
                                          : () async =>
                                              await _openClientBillingTab(
                                                client.id,
                                              ),
                                ),
                              ],
                            );
                          }).toList(),
                    );
                  }
                  return SingleChildScrollView(
                    key: const ValueKey('sales_open_tickets_table'),
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        headingRowHeight: 48,
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 66,
                        columns: const [
                          DataColumn(label: Text('Numero ticket')),
                          DataColumn(label: Text('Cliente')),
                          DataColumn(label: Text('Servizio')),
                          DataColumn(label: Text('Appuntamento')),
                          DataColumn(label: Text('Importo')),
                          DataColumn(label: Text('Stato')),
                          DataColumn(label: Text('Azioni')),
                        ],
                        rows:
                            openTickets.map((ticket) {
                              final client = clients.firstWhereOrNull(
                                (item) => item.id == ticket.clientId,
                              );
                              final appointment = appointments.firstWhereOrNull(
                                (item) => item.id == ticket.appointmentId,
                              );
                              final serviceName = _ticketServiceLabel(
                                ticket,
                                appointment,
                                services,
                              );
                              final staffName =
                                  ticket.staffId == null
                                      ? null
                                      : staff
                                          .firstWhereOrNull(
                                            (member) =>
                                                member.id == ticket.staffId,
                                          )
                                          ?.fullName;
                              final appointmentDate = DateFormat(
                                'dd/MM/yyyy HH:mm',
                                'it_IT',
                              ).format(ticket.appointmentStart.toLocal());
                              final amount = ticket.expectedTotal ?? 0;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      'TKT-${ticket.id.substring(0, 4).toUpperCase()}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(client?.fullName ?? 'Cliente')),
                                  DataCell(
                                    Text(
                                      serviceName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      staffName == null
                                          ? appointmentDate
                                          : '$appointmentDate • $staffName',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      currency.format(amount),
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const DataCell(
                                    StatusBadge(
                                      status: BadgeStatus.pending,
                                      label: 'In attesa',
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Apri ticket',
                                          icon: const Icon(
                                            Icons.visibility_outlined,
                                          ),
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
                                                ticket: ticket,
                                              ),
                                        ),
                                        IconButton(
                                          tooltip: 'Apri scheda cliente',
                                          icon: const Icon(
                                            Icons.open_in_new_rounded,
                                          ),
                                          onPressed:
                                              client == null
                                                  ? null
                                                  : () async =>
                                                      await _openClientBillingTab(
                                                        client.id,
                                                      ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stackedControls =
                      constraints.maxWidth < kAdminStackBreakpoint;
                  final controlsWidth =
                      stackedControls
                          ? double.infinity
                          : (constraints.maxWidth * 0.46)
                              .clamp(280.0, 420.0)
                              .toDouble();
                  return AdminResponsiveHeader(
                    title: 'Vendite concluse',
                    stackBreakpoint: kAdminStackBreakpoint,
                    trailingFullWidthOnStack: true,
                    trailing: SizedBox(
                      width: controlsWidth,
                      child: _SalesDateNavigator(
                        weekdayLabel: selectedWeekdayLabel,
                        dateLabel: selectedDateLabel,
                        compactDateLabel: selectedCompactDateLabel,
                        isToday: isToday,
                        onPrevious: canGoBackward ? () => _changeDay(-1) : null,
                        onNext: canGoForward ? () => _changeDay(1) : null,
                        onPickDate:
                            () => _pickDate(
                              context,
                              firstDate: firstAvailableDate,
                              lastDate: today,
                            ),
                        onJumpToToday: isToday ? null : _jumpToToday,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (completedRows.isEmpty)
            const Card(
              margin: EdgeInsets.only(top: 8),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: SharedEmptyState(
                  title: 'Nessuna vendita registrata',
                  description:
                      'Per questa data non risultano vendite concluse.',
                  icon: Icons.receipt_long_rounded,
                ),
              ),
            )
          else
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760) {
                    return Column(
                      key: const ValueKey('sales_completed_mobile_list'),
                      children:
                          completedRows.map((entry) {
                            final sale = entry.sale;
                            final ticket = entry.ticket;
                            final saleCode =
                                sale != null
                                    ? (sale.invoiceNumber?.trim().isNotEmpty ??
                                            false)
                                        ? sale.invoiceNumber!
                                        : 'VEN-${sale.createdAt.year}-${sale.id.substring(0, 3).toUpperCase()}'
                                    : 'TKT-${ticket!.id.substring(0, 4).toUpperCase()}';
                            final paymentMethod =
                                sale != null
                                    ? _paymentMethodLabel(sale.paymentMethod)
                                    : 'Ticket';
                            final amount = entry.amount ?? sale?.total ?? 0;
                            final statusBadge = _statusBadgeForEntry(entry);
                            return _MobileTicketSummaryCard(
                              codeLabel: 'N. vendita',
                              codeValue: saleCode,
                              rows: [
                                _MobileTicketSummaryRow(
                                  label: 'Appuntamento',
                                  value: DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                    'it_IT',
                                  ).format(entry.date.toLocal()),
                                ),
                                if ((entry.serviceName ?? '').trim().isNotEmpty)
                                  _MobileTicketSummaryRow(
                                    label: 'Servizio',
                                    value: entry.serviceName!,
                                  ),
                                if ((entry.staffName ?? '').trim().isNotEmpty)
                                  _MobileTicketSummaryRow(
                                    label: 'Operatore',
                                    value: entry.staffName!,
                                  ),
                                _MobileTicketSummaryRow(
                                  label: 'Cliente',
                                  value: entry.clientName,
                                ),
                                _MobileTicketSummaryRow(
                                  label: 'Importo',
                                  value: currency.format(amount),
                                  valueColor:
                                      Theme.of(context).colorScheme.primary,
                                ),
                                _MobileTicketSummaryRow(
                                  label: 'Metodo',
                                  value: paymentMethod,
                                ),
                                _MobileTicketSummaryRow(
                                  label: 'Stato',
                                  child: StatusBadge(
                                    status: statusBadge.$1,
                                    label: statusBadge.$2,
                                  ),
                                ),
                              ],
                              actions: [
                                _MobileTicketActionButton(
                                  tooltip: 'Dettaglio',
                                  icon: Icons.visibility_outlined,
                                  onPressed: () {
                                    if (entry.ticket != null) {
                                      _showClosedTicketDetails(
                                        context: context,
                                        ticket: entry.ticket!,
                                        clients: clients,
                                        services: services,
                                        staff: staff,
                                        sales: sales,
                                        clientId: entry.clientId,
                                        onOpenClientBilling:
                                            entry.onOpenClientBilling,
                                      );
                                    } else if (entry.sale != null) {
                                      _showSaleDetails(
                                        context: context,
                                        sale: entry.sale!,
                                        clientName: entry.clientName,
                                        staffName: entry.staffName,
                                        onOpenClientBilling:
                                            entry.onOpenClientBilling,
                                      );
                                    }
                                  },
                                ),
                                _MobileTicketActionButton(
                                  tooltip: 'Apri scheda cliente',
                                  icon: Icons.open_in_new_rounded,
                                  onPressed:
                                      entry.onOpenClientBilling == null
                                          ? null
                                          : () async =>
                                              await entry
                                                  .onOpenClientBilling!(),
                                ),
                              ],
                            );
                          }).toList(),
                    );
                  }
                  return SingleChildScrollView(
                    key: const ValueKey('sales_completed_table'),
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        headingRowHeight: 48,
                        dataRowMinHeight: 58,
                        dataRowMaxHeight: 66,
                        columns: const [
                          DataColumn(label: Text('Numero vendita')),
                          DataColumn(label: Text('Cliente')),
                          DataColumn(label: Text('Importo')),
                          DataColumn(label: Text('Metodo')),
                          DataColumn(label: Text('Stato')),
                          DataColumn(label: Text('Azioni')),
                        ],
                        rows:
                            completedRows.map((entry) {
                              final sale = entry.sale;
                              final ticket = entry.ticket;
                              final saleCode =
                                  sale != null
                                      ? (sale.invoiceNumber
                                                  ?.trim()
                                                  .isNotEmpty ??
                                              false)
                                          ? sale.invoiceNumber!
                                          : 'VEN-${sale.createdAt.year}-${sale.id.substring(0, 3).toUpperCase()}'
                                      : 'TKT-${ticket!.id.substring(0, 4).toUpperCase()}';
                              final paymentMethod =
                                  sale != null
                                      ? _paymentMethodLabel(sale.paymentMethod)
                                      : 'Ticket';
                              final amount = entry.amount ?? sale?.total ?? 0;
                              final statusBadge = _statusBadgeForEntry(entry);
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          saleCode,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'yyyy-MM-dd HH:mm',
                                            'it_IT',
                                          ).format(entry.date.toLocal()),
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(entry.clientName)),
                                  DataCell(
                                    Text(
                                      currency.format(amount),
                                      style: TextStyle(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(paymentMethod)),
                                  DataCell(
                                    StatusBadge(
                                      status: statusBadge.$1,
                                      label: statusBadge.$2,
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Dettaglio',
                                          icon: const Icon(
                                            Icons.visibility_outlined,
                                          ),
                                          onPressed: () {
                                            if (entry.ticket != null) {
                                              _showClosedTicketDetails(
                                                context: context,
                                                ticket: entry.ticket!,
                                                clients: clients,
                                                services: services,
                                                staff: staff,
                                                sales: sales,
                                                clientId: entry.clientId,
                                                onOpenClientBilling:
                                                    entry.onOpenClientBilling,
                                              );
                                            } else if (entry.sale != null) {
                                              _showSaleDetails(
                                                context: context,
                                                sale: entry.sale!,
                                                clientName: entry.clientName,
                                                staffName: entry.staffName,
                                                onOpenClientBilling:
                                                    entry.onOpenClientBilling,
                                              );
                                            }
                                          },
                                        ),
                                        IconButton(
                                          tooltip: 'Apri scheda cliente',
                                          icon: const Icon(
                                            Icons.open_in_new_rounded,
                                          ),
                                          onPressed:
                                              entry.onOpenClientBilling == null
                                                  ? null
                                                  : () async =>
                                                      await entry
                                                          .onOpenClientBilling!(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  );
                },
              ),
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
                            onPressed: () async {
                              await _openClientBillingTab(client.id);
                            },
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

  (BadgeStatus, String) _statusBadgeForEntry(_CompletedEntry entry) {
    if (entry.ticket != null) {
      return (BadgeStatus.success, 'Completata');
    }
    final sale = entry.sale;
    if (sale == null) {
      return (BadgeStatus.info, 'Registrata');
    }
    switch (sale.paymentStatus) {
      case SalePaymentStatus.paid:
        return (BadgeStatus.success, 'Completata');
      case SalePaymentStatus.deposit:
        return (BadgeStatus.pending, 'Acconto');
      case SalePaymentStatus.posticipated:
        return (BadgeStatus.pending, 'In attesa');
    }
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
  return method.label;
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
    ScaffoldMessenger.of(context).showAppSnackBar(
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
    includeCloseButton: false,
    desktopMaxWidth: 1160,
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
  Future<void> Function()? onOpenClientBilling,
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
  Future<void> Function()? onOpenClientBilling,
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
    ScaffoldMessenger.of(context).showAppSnackBar(
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
    this.width = 220,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final double width;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 22,
                color: accentColor ?? Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalesDateNavigator extends StatelessWidget {
  const _SalesDateNavigator({
    required this.weekdayLabel,
    required this.dateLabel,
    required this.compactDateLabel,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
    required this.onJumpToToday,
  });

  final String weekdayLabel;
  final String dateLabel;
  final String compactDateLabel;
  final bool isToday;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPickDate;
  final VoidCallback? onJumpToToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _SalesDateIconButton(
                      tooltip: 'Giorno precedente',
                      icon: Icons.chevron_left_rounded,
                      onPressed: onPrevious,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onPickDate,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                weekdayLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isCompact ? compactDateLabel : dateLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SalesDateIconButton(
                      tooltip: 'Giorno successivo',
                      icon: Icons.chevron_right_rounded,
                      onPressed: onNext,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: onPickDate,
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: Text(isCompact ? 'Calendario' : 'Seleziona data'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Oggi',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      FilledButton.tonal(
                        onPressed: onJumpToToday,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        child: const Text('Oggi'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SalesDateIconButton extends StatelessWidget {
  const _SalesDateIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        disabledForegroundColor: theme.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.45,
        ),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _MobileTicketSummaryCard extends StatelessWidget {
  const _MobileTicketSummaryCard({
    required this.codeLabel,
    required this.codeValue,
    required this.rows,
    this.actions = const <Widget>[],
  });

  final String codeLabel;
  final String codeValue;
  final List<Widget> rows;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  codeLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  codeValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rows,
          if (actions.isNotEmpty) ...[
            Divider(
              height: 24,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(spacing: 8, runSpacing: 8, children: actions),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileTicketSummaryRow extends StatelessWidget {
  const _MobileTicketSummaryRow({
    required this.label,
    this.value,
    this.child,
    this.valueColor,
  }) : assert(value != null || child != null);

  final String label;
  final String? value;
  final Widget? child;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueWidget =
        child ??
        Text(
          value!,
          textAlign: TextAlign.right,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: Align(alignment: Alignment.topRight, child: valueWidget),
          ),
        ],
      ),
    );
  }
}

class _MobileTicketActionButton extends StatelessWidget {
  const _MobileTicketActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        foregroundColor: theme.colorScheme.onSurface,
        disabledForegroundColor: theme.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.45,
        ),
      ),
      icon: Icon(icon, size: 18),
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
  final Future<void> Function()? onOpenClientBilling;

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
            _DetailRowPair(
              leftLabel: 'Stato pagamento',
              leftValue: associatedSale.paymentStatus.label,
              rightLabel: 'Metodo di pagamento',
              rightValue: _paymentMethodLabel(associatedSale.paymentMethod),
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
  final Future<void> Function()? onOpenClientBilling;

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
          _DetailRowPair(
            leftLabel: 'Stato pagamento',
            leftValue: sale.paymentStatus.label,
            rightLabel: 'Metodo di pagamento',
            rightValue: _paymentMethodLabel(sale.paymentMethod),
          ),
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

class _DetailRowPair extends StatelessWidget {
  const _DetailRowPair({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: leftLabel, value: leftValue),
              _DetailRow(label: rightLabel, value: rightValue),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _DetailRow(label: leftLabel, value: leftValue)),
            const SizedBox(width: 16),
            Expanded(child: _DetailRow(label: rightLabel, value: rightValue)),
          ],
        );
      },
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
  final Future<void> Function()? onOpenClientBilling;
  final String? staffName;
  final String? serviceName;
  final String? paymentLabel;
  final double? amount;
  final PaymentTicket? ticket;
  final Sale? sale;
}

Widget? _buildClientHyperlinkAction(
  BuildContext context,
  Future<void> Function()? action,
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
    onPressed: () async {
      Navigator.of(context).pop();
      await action();
    },
  );
}
