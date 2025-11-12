import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/appointment_service_allocation.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/payment_ticket.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/screens/admin/forms/appointment_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/sale_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/appointment_save_utils.dart';
import 'package:you_book/presentation/screens/admin/modules/sales/sale_helpers.dart';

class AppointmentSaleFlowSheet extends ConsumerStatefulWidget {
  const AppointmentSaleFlowSheet({
    super.key,
    required this.salons,
    required this.clients,
    required this.staff,
    required this.services,
    required this.serviceCategories,
    this.initial,
    this.defaultSalonId,
    this.defaultClientId,
    this.suggestedStart,
    this.suggestedEnd,
    this.suggestedStaffId,
    this.enableDelete = false,
  });

  final List<Salon> salons;
  final List<Client> clients;
  final List<StaffMember> staff;
  final List<Service> services;
  final List<ServiceCategory> serviceCategories;
  final Appointment? initial;
  final String? defaultSalonId;
  final String? defaultClientId;
  final DateTime? suggestedStart;
  final DateTime? suggestedEnd;
  final String? suggestedStaffId;
  final bool enableDelete;

  @override
  ConsumerState<AppointmentSaleFlowSheet> createState() =>
      _AppointmentSaleFlowSheetState();
}

class _AppointmentSaleFlowSheetState
    extends ConsumerState<AppointmentSaleFlowSheet> {
  bool _showSaleStep = false;
  AppointmentFormResult? _lastResult;
  PaymentTicket? _pendingTicket;
  Appointment? _savedAppointment;

  Future<void> _handleAppointmentSaved(AppointmentFormResult result) async {
    if (result.action != AppointmentFormAction.save) {
      Navigator.of(context).pop(result);
      return;
    }
    final saved = await validateAndSaveAppointment(
      context: context,
      ref: ref,
      appointment: result.appointment,
      fallbackServices: widget.services,
      fallbackSalons: widget.salons,
    );
    if (!saved || !mounted) {
      return;
    }
    final data = ref.read(appDataProvider);
    final openTicket = data.paymentTickets.firstWhereOrNull(
      (ticket) =>
          ticket.appointmentId == result.appointment.id &&
          ticket.status == PaymentTicketStatus.open,
    );
    if (openTicket == null) {
      Navigator.of(context).pop(result);
      return;
    }
    setState(() {
      _lastResult = result;
      _savedAppointment = result.appointment;
      _pendingTicket = openTicket;
      _showSaleStep = true;
    });
  }

  Future<void> _handleSaleSaved(Sale sale) async {
    final store = ref.read(appDataProvider.notifier);
    await store.upsertSale(sale);
    final clients = ref.read(appDataProvider).clients;
    await recordSaleCashFlow(ref: ref, sale: sale, clients: clients);
    final ticket = _pendingTicket;
    if (ticket != null &&
        sale.paymentStatus != SalePaymentStatus.posticipated) {
      await store.closePaymentTicket(ticket.id, saleId: sale.id);
    }
    if (!mounted) {
      return;
    }
    final result =
        _lastResult ??
        (_savedAppointment == null
            ? null
            : AppointmentFormResult(
              action: AppointmentFormAction.save,
              appointment: _savedAppointment!,
            ));
    Navigator.of(context).pop(result);
  }

  void _closeFlow() {
    if (_lastResult != null) {
      Navigator.of(context).pop(_lastResult);
      return;
    }
    Navigator.of(context).pop();
  }

  List<SaleItem>? _buildInitialSaleItems(
    PaymentTicket ticket,
    List<Service> services,
  ) {
    final appointment = _savedAppointment;
    if (appointment != null) {
      final items = _saleItemsFromAppointment(appointment, services, ticket);
      if (items.isNotEmpty) {
        return items;
      }
    }
    final matchedService =
        ticket.serviceId == null || ticket.serviceId!.isEmpty
            ? null
            : services.firstWhereOrNull(
              (service) => service.id == ticket.serviceId,
            );
    final unitPrice =
        (matchedService?.price ?? ticket.expectedTotal ?? 0.0).toDouble();
    final description =
        matchedService?.name ?? ticket.serviceName ?? 'Servizio';
    return [
      SaleItem(
        referenceId: ticket.serviceId,
        referenceType: SaleReferenceType.service,
        description: description,
        quantity: 1,
        unitPrice: unitPrice,
      ),
    ];
  }

  List<SaleItem> _saleItemsFromAppointment(
    Appointment appointment,
    List<Service> services,
    PaymentTicket ticket,
  ) {
    final serviceById = {for (final service in services) service.id: service};
    final allocations =
        appointment.serviceAllocations.isNotEmpty
            ? appointment.serviceAllocations
            : _legacyAllocationsForAppointment(appointment);
    final items = <SaleItem>[];

    for (final allocation in allocations) {
      var remainingQuantity = allocation.quantity;
      for (final consumption in allocation.packageConsumptions) {
        remainingQuantity -= consumption.quantity;
      }
      if (remainingQuantity <= 0) {
        continue;
      }
      final service = serviceById[allocation.serviceId];
      final description = service?.name ?? ticket.serviceName ?? 'Servizio';
      final unitPrice =
          (service?.price ?? ticket.expectedTotal ?? 0.0).toDouble();
      final referenceId = service?.id ?? ticket.serviceId;
      items.add(
        SaleItem(
          referenceId: referenceId,
          referenceType: SaleReferenceType.service,
          description: description,
          quantity: remainingQuantity.toDouble(),
          unitPrice: unitPrice,
        ),
      );
    }

    return items;
  }

  List<AppointmentServiceAllocation> _legacyAllocationsForAppointment(
    Appointment appointment,
  ) {
    if (appointment.serviceIds.isEmpty) {
      return const <AppointmentServiceAllocation>[];
    }
    return appointment.serviceIds
        .map(
          (serviceId) => AppointmentServiceAllocation(
            serviceId: serviceId,
            quantity: 1,
            packageConsumptions: const <AppointmentPackageConsumption>[],
          ),
        )
        .toList(growable: false);
  }

  Widget _buildTicketSummary(AppDataState data, PaymentTicket ticket) {
    final clientName =
        data.clients
            .firstWhereOrNull((client) => client.id == ticket.clientId)
            ?.fullName ??
        'Cliente';
    final serviceName =
        data.services
            .firstWhereOrNull((service) => service.id == ticket.serviceId)
            ?.name ??
        ticket.serviceName ??
        'Servizio';
    final amount = ticket.expectedTotal;
    final ticketDate = DateFormat(
      'dd/MM/yyyy HH:mm',
      'it_IT',
    ).format(ticket.appointmentStart);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(clientName),
        subtitle: Text('$serviceName · $ticketDate'),
        trailing: amount != null ? Text(currency.format(amount)) : null,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final title = _showSaleStep ? 'Gestisci ticket' : 'Dettaglio appuntamento';
    final subtitle = _showSaleStep ? 'Passaggio 2 di 2' : 'Passaggio 1 di 2';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          if (_showSaleStep)
            IconButton(
              onPressed: () {
                setState(() => _showSaleStep = false);
              },
              icon: const Icon(Icons.chevron_left_rounded),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: _closeFlow,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentStep(AppDataState data) {
    return AppointmentFormSheet(
      key: const ValueKey('appointment-step'),
      salons: widget.salons,
      clients: widget.clients,
      staff: widget.staff,
      services: widget.services,
      serviceCategories: widget.serviceCategories,
      initial: widget.initial,
      defaultSalonId: widget.defaultSalonId,
      defaultClientId: widget.defaultClientId,
      suggestedStart: widget.suggestedStart,
      suggestedEnd: widget.suggestedEnd,
      suggestedStaffId: widget.suggestedStaffId,
      enableDelete: widget.enableDelete,
      onSaved: _handleAppointmentSaved,
    );
  }

  Widget _buildSaleStep(AppDataState data) {
    final ticket = _pendingTicket;
    if (ticket == null) {
      return const SizedBox.shrink();
    }
    final initialItems = _buildInitialSaleItems(ticket, data.services);
    final saleForm = SaleFormSheet(
      key: const ValueKey('sale-step'),
      salons: data.salons,
      clients: data.clients,
      staff: data.staff,
      services: data.services,
      packages: data.packages,
      inventoryItems: data.inventoryItems,
      sales: data.sales,
      defaultSalonId: ticket.salonId ?? widget.defaultSalonId,
      initialClientId: ticket.clientId,
      initialItems: initialItems,
      initialNotes: ticket.notes,
      initialDate: ticket.appointmentEnd,
      initialStaffId: ticket.staffId,
      onSaved: _handleSaleSaved,
    );

    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(child: saleForm),
        OutlinedButton(
          onPressed: _closeFlow,
          child: const Text('Non gestire ora il ticket'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final content =
        _showSaleStep ? _buildSaleStep(data) : _buildAppointmentStep(data);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const SizedBox(height: 4),
            Flexible(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
