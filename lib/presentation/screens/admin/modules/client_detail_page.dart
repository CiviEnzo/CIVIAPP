import 'dart:math' as math;

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/cash_flow_entry.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/client_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_deposit_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_purchase_edit_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_sale_form_sheet.dart';
import 'package:civiapp/presentation/shared/client_package_purchase.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class ClientDetailPage extends ConsumerStatefulWidget {
  const ClientDetailPage({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends ConsumerState<ClientDetailPage> {
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final client = data.clients.firstWhereOrNull(
      (element) => element.id == widget.clientId,
    );

    if (client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dettaglio cliente')),
        body: const Center(
          child: Text('Cliente non trovato. Aggiorna l\'elenco e riprova.'),
        ),
      );
    }

    final salon = data.salons.firstWhereOrNull(
      (element) => element.id == client.salonId,
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(client.fullName),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Scheda'),
              Tab(text: 'Appuntamenti'),
              Tab(text: 'Pacchetti'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Modifica scheda',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => _editClient(context, client),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _ProfileTab(client: client, salon: salon),
            _AppointmentsTab(clientId: client.id),
            _PackagesTab(clientId: client.id),
          ],
        ),
      ),
    );
  }

  Future<void> _editClient(BuildContext context, Client client) async {
    final data = ref.read(appDataProvider);
    final salons = data.salons;
    final updated = await showAppModalSheet<Client>(
      context: context,
      builder:
          (ctx) => ClientFormSheet(
            salons: salons,
            initial: client,
            defaultSalonId: client.salonId,
          ),
    );
    if (updated != null) {
      await ref.read(appDataProvider.notifier).upsertClient(updated);
    }
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.client, required this.salon});

  final Client client;
  final Salon? salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dati anagrafici', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _InfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Numero cliente',
                  value: client.clientNumber ?? 'Non assegnato',
                ),
                _InfoTile(
                  icon: Icons.cake_outlined,
                  label: 'Data di nascita',
                  value:
                      client.dateOfBirth == null
                          ? '—'
                          : dateFormat.format(client.dateOfBirth!),
                ),
                _InfoTile(
                  icon: Icons.phone,
                  label: 'Telefono',
                  value: client.phone,
                ),
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: client.email ?? '—',
                ),
                _InfoTile(
                  icon: Icons.home_outlined,
                  label: 'Indirizzo',
                  value: client.address ?? '—',
                ),
                _InfoTile(
                  icon: Icons.work_outline,
                  label: 'Professione',
                  value: client.profession ?? '—',
                ),
                _InfoTile(
                  icon: Icons.campaign_outlined,
                  label: 'Come ci ha conosciuto',
                  value: client.referralSource ?? '—',
                ),
                _InfoTile(
                  icon: Icons.loyalty_rounded,
                  label: 'Punti fedeltà',
                  value: client.loyaltyPoints.toString(),
                ),
                if (salon != null)
                  _InfoTile(
                    icon: Icons.apartment_rounded,
                    label: 'Salone associato',
                    value: salon!.name,
                  ),
              ],
            ),
          ),
        ),
        if (client.notes != null && client.notes!.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Note', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(client.notes!),
                ],
              ),
            ),
          ),
        if (client.marketedConsents.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consensi marketing',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        client.marketedConsents
                            .map(
                              (consent) => Chip(
                                avatar: const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  '${_consentLabel(consent.type)} · ${dateFormat.format(consent.acceptedAt)}',
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _consentLabel(ConsentType type) {
    switch (type) {
      case ConsentType.marketing:
        return 'Marketing';
      case ConsentType.privacy:
        return 'Privacy';
      case ConsentType.profilazione:
        return 'Profilazione';
    }
  }
}

class _AppointmentsTab extends ConsumerWidget {
  const _AppointmentsTab({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final now = DateTime.now();

    final appointments =
        data.appointments
            .where((appointment) => appointment.clientId == clientId)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final staff = data.staff;
    final services = data.services;

    final upcoming =
        appointments
            .where((appointment) => appointment.start.isAfter(now))
            .toList();
    final history =
        appointments
            .where((appointment) => !appointment.start.isAfter(now))
            .toList()
            .reversed
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AppointmentGroup(
          title: 'Appuntamenti futuri',
          emptyMessage: 'Nessun appuntamento futuro prenotato.',
          appointments: upcoming,
          staff: staff,
          services: services,
          dateFormat: dateFormat,
          currency: currency,
        ),
        const SizedBox(height: 16),
        _AppointmentGroup(
          title: 'Appuntamenti passati',
          emptyMessage: 'Non sono presenti appuntamenti passati.',
          appointments: history,
          staff: staff,
          services: services,
          dateFormat: dateFormat,
          currency: currency,
        ),
      ],
    );
  }
}

class _AppointmentGroup extends StatelessWidget {
  const _AppointmentGroup({
    required this.title,
    required this.emptyMessage,
    required this.appointments,
    required this.staff,
    required this.services,
    required this.dateFormat,
    required this.currency,
  });

  final String title;
  final String emptyMessage;
  final List<Appointment> appointments;
  final List<StaffMember> staff;
  final List<Service> services;
  final DateFormat dateFormat;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (appointments.isEmpty)
              Text(emptyMessage, style: theme.textTheme.bodyMedium)
            else
              ...appointments.map((appointment) {
                final service = services.firstWhereOrNull(
                  (element) => element.id == appointment.serviceId,
                );
                final operator = staff.firstWhereOrNull(
                  (element) => element.id == appointment.staffId,
                );
                final statusChip = _statusChip(context, appointment.status);
                final amount = service?.price;
                final packageLabel =
                    appointment.packageId == null
                        ? null
                        : 'Pacchetto #${appointment.packageId}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    isThreeLine: packageLabel != null,
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: Text(service?.name ?? 'Servizio'),
                    subtitle: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateFormat.format(appointment.start)),
                        Text(
                          'Operatore: ${operator?.fullName ?? 'Da assegnare'}',
                        ),
                        if (packageLabel != null) Text(packageLabel),
                      ],
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (amount != null) ...[
                          Text(
                            currency.format(amount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                        ],
                        statusChip,
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, AppointmentStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case AppointmentStatus.scheduled:
        return Chip(
          label: const Text('Programmato'),
          backgroundColor: scheme.primaryContainer,
        );
      case AppointmentStatus.confirmed:
        return Chip(
          label: const Text('Confermato'),
          backgroundColor: scheme.secondaryContainer,
        );
      case AppointmentStatus.completed:
        return Chip(
          label: const Text('Completato'),
          backgroundColor: scheme.tertiaryContainer,
        );
      case AppointmentStatus.cancelled:
        return Chip(
          label: const Text('Annullato'),
          backgroundColor: scheme.errorContainer,
        );
      case AppointmentStatus.noShow:
        return Chip(
          label: const Text('No show'),
          backgroundColor: scheme.error.withValues(alpha: 0.1),
        );
    }
  }
}

class _PackagesTab extends ConsumerStatefulWidget {
  const _PackagesTab({required this.clientId});

  final String clientId;

  @override
  ConsumerState<_PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends ConsumerState<_PackagesTab> {
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final client = data.clients.firstWhereOrNull(
      (element) => element.id == widget.clientId,
    );
    if (client == null) {
      return const Center(child: Text('Cliente non trovato.'));
    }
    final purchases = resolveClientPackagePurchases(
      sales: data.sales,
      packages: data.packages,
      appointments: data.appointments,
      services: data.services,
      clientId: client.id,
    );
    final active = purchases.where((item) => item.isActive).toList();
    final expired = purchases.where((item) => !item.isActive).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _createCustomPackage(context, client),
                icon: const Icon(Icons.design_services_rounded),
                label: const Text('Personalizza pacchetto'),
              ),
              FilledButton.icon(
                onPressed: () => _registerPackagePurchase(context, client),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Aggiungi pacchetto'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PackageGroup(
          title: 'Pacchetti in corso',
          items: active,
          onEdit: (purchase) => _editPackage(client, purchase),
          onDelete: (purchase) => _deletePackage(client, purchase),
          onAddDeposit: (purchase) => _addDeposit(client, purchase),
          onDeleteDeposit:
              (purchase, deposit) => _removeDeposit(client, purchase, deposit),
        ),
        const SizedBox(height: 16),
        _PackageGroup(
          title: 'Pacchetti passati',
          items: expired,
          onEdit: (purchase) => _editPackage(client, purchase),
          onAddDeposit: null,
          onDeleteDeposit: null,
        ),
      ],
    );
  }

  Future<void> _registerPackagePurchase(
    BuildContext context,
    Client client,
  ) async {
    final data = ref.read(appDataProvider);
    final packages =
        data.packages.where((pkg) => pkg.salonId == client.salonId).toList();
    if (packages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun pacchetto disponibile per questo salone.'),
        ),
      );
      return;
    }

    final sale = await showAppModalSheet<Sale>(
      context: context,
      builder:
          (ctx) => PackageSaleFormSheet(client: client, packages: packages),
    );
    if (!mounted) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (sale != null) {
      await ref.read(appDataProvider.notifier).upsertSale(sale);
      await _registerDepositCashFlow(client, sale);
    }
  }

  Future<void> _createCustomPackage(BuildContext context, Client client) async {
    final data = ref.read(appDataProvider);
    final salonId = client.salonId;

    var salons = data.salons.where((salon) => salon.id == salonId).toList();
    if (salons.isEmpty) {
      salons = data.salons;
    }

    var services =
        data.services.where((service) => service.salonId == salonId).toList();
    if (services.isEmpty) {
      services = data.services;
    }
    if (salons.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun salone disponibile per creare un pacchetto.'),
        ),
      );
      return;
    }

    if (services.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nessun servizio disponibile per creare un pacchetto personalizzato.',
          ),
        ),
      );
      return;
    }

    final defaultSalonId = salonId;
    final customPackage = await showAppModalSheet<ServicePackage>(
      context: context,
      builder:
          (ctx) => PackageFormSheet(
            salons: salons,
            services: services,
            defaultSalonId: defaultSalonId,
          ),
    );

    if (customPackage == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final sale = await showAppModalSheet<Sale>(
      context: context,
      builder:
          (ctx) =>
              PackageSaleFormSheet(client: client, packages: [customPackage]),
    );

    if (sale == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    await ref.read(appDataProvider.notifier).upsertSale(sale);
    await _registerDepositCashFlow(client, sale);
  }

  Future<void> _registerDepositCashFlow(Client client, Sale sale) async {
    final depositItems = sale.items.where(
      (item) =>
          item.referenceType == SaleReferenceType.package &&
          item.depositAmount > 0,
    );
    double depositTotal = 0;
    final descriptions = <String>[];
    for (final item in depositItems) {
      final amount = item.depositAmount;
      depositTotal += amount;
      if (item.description.isNotEmpty) {
        descriptions.add(item.description);
      }
    }
    final normalized = double.parse(depositTotal.toStringAsFixed(2));
    if (normalized <= 0) {
      return;
    }

    final isPaid = depositItems.any(
      (item) => item.packagePaymentStatus == PackagePaymentStatus.paid,
    );
    final description =
        isPaid
            ? (descriptions.isEmpty
                ? 'Saldato pacchetto cliente ${client.fullName}'
                : 'Saldato pacchetti: ${descriptions.join(', ')}')
            : (descriptions.isEmpty
                ? 'Acconto pacchetto cliente ${client.fullName}'
                : 'Acconto pacchetti: ${descriptions.join(', ')}');
    await _recordCashFlowEntry(
      client: client,
      amount: normalized,
      description: description,
      date: sale.createdAt,
    );
  }

  Future<void> _addDeposit(
    Client client,
    ClientPackagePurchase purchase,
  ) async {
    final outstanding = double.parse(
      purchase.outstandingAmount.toStringAsFixed(2),
    );
    if (outstanding <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Il pacchetto è già saldato.')),
      );
      return;
    }

    final deposit = await showAppModalSheet<PackageDeposit>(
      context: context,
      builder: (ctx) => PackageDepositFormSheet(maxAmount: outstanding),
    );

    if (deposit == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    var recordedDeposit = deposit;
    final deposits = [...purchase.item.deposits, recordedDeposit];
    var updatedItem = _updateItemWithDeposits(
      purchase.item,
      deposits,
      purchase.totalAmount,
    );

    final packageLabel = purchase.package?.name ?? purchase.item.description;
    final isSettled =
        updatedItem.packagePaymentStatus == PackagePaymentStatus.paid;

    if (isSettled) {
      recordedDeposit = recordedDeposit.copyWith(note: 'Saldato');
      deposits[deposits.length - 1] = recordedDeposit;
      updatedItem = _updateItemWithDeposits(
        purchase.item,
        deposits,
        purchase.totalAmount,
      );
    }

    await _persistUpdatedItem(purchase, updatedItem);
    await _recordCashFlowEntry(
      client: client,
      amount: recordedDeposit.amount,
      description:
          isSettled
              ? 'Saldato pacchetto ${packageLabel}'
              : 'Acconto pacchetto ${packageLabel}',
      date: recordedDeposit.date,
    );
  }

  Future<void> _editPackage(
    Client client,
    ClientPackagePurchase purchase,
  ) async {
    final updatedItem = await showAppModalSheet<SaleItem>(
      context: context,
      builder:
          (ctx) => PackagePurchaseEditSheet(
            initialItem: purchase.item,
            purchaseDate: purchase.sale.createdAt,
            package: purchase.package,
          ),
    );
    if (updatedItem == null) {
      return;
    }

    await _persistUpdatedItem(purchase, updatedItem);
    await _handleDepositAdjustments(client, purchase, updatedItem);
  }

  Future<void> _deletePackage(
    Client client,
    ClientPackagePurchase purchase,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Elimina pacchetto'),
            content: const Text(
              'Vuoi davvero eliminare questo pacchetto? L\'operazione può essere annullata entro pochi secondi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Elimina'),
              ),
            ],
          ),
    );
    if (confirm != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final notifier = ref.read(appDataProvider.notifier);
    final originalSale = purchase.sale;
    final updatedItems = [...originalSale.items]..removeAt(purchase.itemIndex);

    if (updatedItems.isEmpty) {
      await notifier.deleteSale(originalSale.id);
    } else {
      final updatedSale = originalSale.copyWith(
        items: updatedItems,
        total: updatedItems.fold<double>(0, (sum, item) => sum + item.amount),
      );
      await notifier.upsertSale(updatedSale);
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Pacchetto rimosso'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Annulla',
          onPressed: () async {
            await ref.read(appDataProvider.notifier).upsertSale(originalSale);
          },
        ),
      ),
    );

    final reversal = double.parse(
      purchase.item.depositAmount.toStringAsFixed(2),
    );
    if (reversal > 0.01) {
      await _recordCashFlowEntry(
        client: client,
        amount: -reversal,
        description:
            'Storno completo pacchetto ${purchase.package?.name ?? purchase.item.description}',
      );
    }
  }

  SaleItem _updateItemWithDeposits(
    SaleItem original,
    List<PackageDeposit> deposits,
    double totalAmount,
  ) {
    final depositSum = deposits.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    final outstanding = double.parse(
      (totalAmount - depositSum).toStringAsFixed(2),
    );
    final nextStatus =
        outstanding <= 0
            ? PackagePaymentStatus.paid
            : PackagePaymentStatus.deposit;
    return original.copyWith(
      deposits: deposits,
      packagePaymentStatus: nextStatus,
    );
  }

  Future<Sale> _persistUpdatedItem(
    ClientPackagePurchase purchase,
    SaleItem updatedItem,
  ) async {
    final items = [...purchase.sale.items];
    items[purchase.itemIndex] = updatedItem;
    final updatedSale = purchase.sale.copyWith(
      items: items,
      total: items.fold<double>(0, (sum, item) => sum + item.amount),
    );
    await ref.read(appDataProvider.notifier).upsertSale(updatedSale);
    return updatedSale;
  }

  Future<void> _removeDeposit(
    Client client,
    ClientPackagePurchase purchase,
    PackageDeposit deposit,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Storna acconto'),
            content: Text(
              'Vuoi stornare l\'acconto da ${NumberFormat.simpleCurrency(locale: 'it_IT').format(deposit.amount)}? Verrà registrato un movimento negativo in cassa.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Conferma'),
              ),
            ],
          ),
    );
    if (confirm != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final remainingDeposits =
        purchase.deposits.where((entry) => entry.id != deposit.id).toList();
    final updatedItem = _updateItemWithDeposits(
      purchase.item,
      remainingDeposits,
      purchase.totalAmount,
    );

    await _persistUpdatedItem(purchase, updatedItem);
    await _recordCashFlowEntry(
      client: client,
      amount: -deposit.amount,
      description:
          'Storno acconto ${purchase.package?.name ?? purchase.item.description}',
      date: DateTime.now(),
    );
  }

  Future<void> _handleDepositAdjustments(
    Client client,
    ClientPackagePurchase originalPurchase,
    SaleItem updatedItem,
  ) async {
    final totalAmount = originalPurchase.totalAmount;
    final originalItem = originalPurchase.item;
    final packageName =
        originalPurchase.package?.name ?? originalItem.description;

    var itemToPersist = updatedItem;
    if (itemToPersist.packagePaymentStatus == PackagePaymentStatus.paid) {
      final outstanding = double.parse(
        (totalAmount - itemToPersist.depositAmount).toStringAsFixed(2),
      );
      if (outstanding > 0.01) {
        final settlementDeposit = PackageDeposit(
          id: const Uuid().v4(),
          amount: outstanding,
          date: DateTime.now(),
          note: 'Saldato',
          paymentMethod:
              itemToPersist.deposits.isNotEmpty
                  ? itemToPersist.deposits.last.paymentMethod
                  : originalPurchase.sale.paymentMethod,
        );
        itemToPersist = _updateItemWithDeposits(itemToPersist, [
          ...itemToPersist.deposits,
          settlementDeposit,
        ], totalAmount);
      } else {
        itemToPersist = _updateItemWithDeposits(
          itemToPersist,
          itemToPersist.deposits,
          totalAmount,
        );
      }
    } else {
      itemToPersist = _updateItemWithDeposits(
        itemToPersist,
        itemToPersist.deposits,
        totalAmount,
      );
    }

    final originalDeposit = originalItem.depositAmount;
    final newDeposit = itemToPersist.depositAmount;
    final deltaDeposit = double.parse(
      (newDeposit - originalDeposit).toStringAsFixed(2),
    );

    await _persistUpdatedItem(originalPurchase, itemToPersist);

    if (deltaDeposit.abs() >= 0.01) {
      final originalStatus = _effectivePaymentStatus(originalItem, totalAmount);
      final newStatus = _effectivePaymentStatus(itemToPersist, totalAmount);

      final description =
          deltaDeposit > 0 &&
                  newStatus == PackagePaymentStatus.paid &&
                  originalStatus != PackagePaymentStatus.paid
              ? 'Saldato pacchetto $packageName'
              : deltaDeposit >= 0
              ? 'Acconto aggiuntivo $packageName'
              : 'Storno acconto $packageName';

      await _recordCashFlowEntry(
        client: client,
        amount: deltaDeposit,
        description: description,
      );
    }
  }

  PackagePaymentStatus _effectivePaymentStatus(
    SaleItem item,
    double totalAmount,
  ) {
    final stored = item.packagePaymentStatus;
    if (stored != null) {
      return stored;
    }
    final deposit = item.depositAmount;
    final outstanding = math.max(totalAmount - deposit, 0);
    if (deposit > 0 && outstanding > 0) {
      return PackagePaymentStatus.deposit;
    }
    return PackagePaymentStatus.paid;
  }

  Future<void> _recordCashFlowEntry({
    required Client client,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    final normalized = double.parse(amount.toStringAsFixed(2));
    if (normalized.abs() < 0.01) {
      return;
    }
    final entry = CashFlowEntry(
      id: const Uuid().v4(),
      salonId: client.salonId,
      type: normalized >= 0 ? CashFlowType.income : CashFlowType.expense,
      amount: normalized.abs(),
      date: date ?? DateTime.now(),
      description: description,
      category: 'Acconti',
    );
    await ref.read(appDataProvider.notifier).upsertCashFlowEntry(entry);
  }
}

class _PackageGroup extends StatelessWidget {
  const _PackageGroup({
    required this.title,
    required this.items,
    this.onEdit,
    this.onDelete,
    this.onAddDeposit,
    this.onDeleteDeposit,
  });

  final String title;
  final List<ClientPackagePurchase> items;
  final ValueChanged<ClientPackagePurchase>? onEdit;
  final ValueChanged<ClientPackagePurchase>? onDelete;
  final ValueChanged<ClientPackagePurchase>? onAddDeposit;
  final void Function(ClientPackagePurchase, PackageDeposit)? onDeleteDeposit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(
                title.contains('corso')
                    ? 'Nessun pacchetto attivo per il cliente.'
                    : 'Non risultano pacchetti passati registrati.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...items.map((purchase) {
                final expiry = purchase.expirationDate;
                final sessionLabel = _sessionLabel(purchase);
                final servicesLabel = purchase.serviceNames.join(', ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              purchase.package?.name ??
                                  purchase.item.description,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if (onEdit != null || onDelete != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (onEdit != null)
                                  IconButton(
                                    tooltip: 'Modifica pacchetto',
                                    icon: const Icon(Icons.edit_rounded),
                                    onPressed: () => onEdit?.call(purchase),
                                  ),
                                if (onDelete != null)
                                  IconButton(
                                    tooltip: 'Elimina pacchetto',
                                    icon: const Icon(Icons.delete_rounded),
                                    onPressed: () => onDelete?.call(purchase),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _statusChip(context, purchase.status),
                          _Chip(
                            label: purchase.paymentStatus.label,
                            icon:
                                purchase.paymentStatus ==
                                        PackagePaymentStatus.deposit
                                    ? Icons.savings_rounded
                                    : Icons.verified_rounded,
                          ),
                          if (purchase.depositAmount > 0)
                            _Chip(
                              label:
                                  'Acconto: ${currency.format(purchase.depositAmount)}',
                              icon: Icons.account_balance_wallet_rounded,
                            ),
                          if (purchase.outstandingAmount > 0)
                            _Chip(
                              label:
                                  'Da saldare: ${currency.format(purchase.outstandingAmount)}',
                              icon: Icons.pending_actions_rounded,
                            ),
                          _Chip(
                            label: currency.format(purchase.totalAmount),
                            icon: Icons.euro_rounded,
                          ),
                          _Chip(
                            label: _paymentLabel(purchase.sale.paymentMethod),
                            icon: Icons.payments_rounded,
                          ),
                          _Chip(
                            label:
                                'Acquisto: ${dateFormat.format(purchase.sale.createdAt)}',
                            icon: Icons.calendar_today_rounded,
                          ),
                          _Chip(
                            label:
                                expiry == null
                                    ? 'Senza scadenza'
                                    : 'Scadenza: ${dateFormat.format(expiry)}',
                            icon: Icons.timer_outlined,
                          ),
                          _Chip(
                            label: sessionLabel,
                            icon: Icons.event_repeat_rounded,
                          ),
                        ],
                      ),
                      if (servicesLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Servizi inclusi: $servicesLabel'),
                      ],
                      if (purchase.deposits.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Acconti', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Column(
                          children:
                              purchase.deposits.map((deposit) {
                                final subtitleBuffer = StringBuffer(
                                  '${DateFormat('dd/MM/yyyy HH:mm').format(deposit.date)} • ${_paymentLabel(deposit.paymentMethod)}',
                                );
                                if (deposit.note != null &&
                                    deposit.note!.isNotEmpty) {
                                  subtitleBuffer
                                    ..write('\n')
                                    ..write(deposit.note);
                                }
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  title: Text(currency.format(deposit.amount)),
                                  subtitle: Text(subtitleBuffer.toString()),
                                  trailing:
                                      onDeleteDeposit == null
                                          ? null
                                          : IconButton(
                                            tooltip: 'Storna acconto',
                                            icon: const Icon(
                                              Icons.undo_rounded,
                                            ),
                                            onPressed:
                                                () => onDeleteDeposit?.call(
                                                  purchase,
                                                  deposit,
                                                ),
                                          ),
                                );
                              }).toList(),
                        ),
                      ],
                      if (onAddDeposit != null &&
                          purchase.outstandingAmount > 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => onAddDeposit?.call(purchase),
                            icon: const Icon(Icons.add_card_rounded),
                            label: const Text('Aggiungi acconto'),
                          ),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  static String _paymentLabel(PaymentMethod method) {
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

  static String _sessionLabel(ClientPackagePurchase purchase) {
    final remaining = purchase.remainingSessions;
    final total = purchase.totalSessions;
    if (remaining == null && total == null) {
      return 'Sessioni non definite';
    }
    if (total == null) {
      return 'Rimanenti: ${remaining ?? '-'}';
    }
    final remainingLabel = remaining?.toString() ?? '—';
    return '$remainingLabel / $total sessioni rimaste';
  }

  static Widget _statusChip(
    BuildContext context,
    PackagePurchaseStatus status,
  ) {
    final scheme = Theme.of(context).colorScheme;
    late final Color background;
    late final Color foreground;
    late final IconData icon;

    switch (status) {
      case PackagePurchaseStatus.active:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        icon = Icons.play_arrow_rounded;
        break;
      case PackagePurchaseStatus.completed:
        background = scheme.tertiaryContainer;
        foreground = scheme.onTertiaryContainer;
        icon = Icons.check_circle_rounded;
        break;
      case PackagePurchaseStatus.cancelled:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        icon = Icons.cancel_rounded;
        break;
    }

    return Chip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(status.label, style: TextStyle(color: foreground)),
      backgroundColor: background,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      backgroundColor: scheme.surfaceContainerHighest,
      avatar: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
      label: Text(label),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
