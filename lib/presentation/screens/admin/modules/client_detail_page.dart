import 'dart:math' as math;

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/availability/appointment_conflicts.dart';
import 'package:civiapp/domain/availability/equipment_availability.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/cash_flow_entry.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/inventory_item.dart';
import 'package:civiapp/domain/entities/package.dart';
import 'package:civiapp/domain/entities/payment_ticket.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/client_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/appointment_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_deposit_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_purchase_edit_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/package_sale_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/outstanding_payment_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/sale_form_sheet.dart';
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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(client.fullName),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Scheda'),
              Tab(text: 'Appuntamenti'),
              Tab(text: 'Pacchetti'),
              Tab(text: 'Fatturazione'),
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
            _BillingTab(clientId: client.id),
          ],
        ),
      ),
    );
  }

  Future<void> _editClient(BuildContext context, Client client) async {
    final data = ref.read(appDataProvider);
    final salons = data.salons;
    final clients = data.clients;
    final updated = await showAppModalSheet<Client>(
      context: context,
      builder:
          (ctx) => ClientFormSheet(
            salons: salons,
            clients: clients,
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
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preferenze canali', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _channelPreferenceChips(
                    context,
                    client.channelPreferences,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  client.channelPreferences.updatedAt != null
                      ? 'Ultimo aggiornamento: ${dateTimeFormat.format(client.channelPreferences.updatedAt!)}'
                      : 'Preferenze non ancora registrate.',
                  style: theme.textTheme.bodySmall,
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

  List<Widget> _channelPreferenceChips(
    BuildContext context,
    ChannelPreferences preferences,
  ) {
    Widget buildChip(bool enabled, String label, IconData icon) {
      final theme = Theme.of(context);
      final Color selectedBackground = theme.colorScheme.secondaryContainer;
      final Color selectedForeground = theme.colorScheme.onSecondaryContainer;
      final Color disabledBackground =
          theme.colorScheme.surfaceContainerHighest;
      final Color disabledForeground = theme.colorScheme.onSurfaceVariant;
      return Chip(
        avatar: Icon(
          icon,
          size: 16,
          color: enabled ? selectedForeground : disabledForeground,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: enabled ? selectedForeground : disabledForeground,
          ),
        ),
        backgroundColor: enabled ? selectedBackground : disabledBackground,
      );
    }

    return [
      buildChip(preferences.push, 'Push', Icons.notifications_active_rounded),
      buildChip(preferences.email, 'Email', Icons.email_rounded),
      buildChip(preferences.whatsapp, 'WhatsApp', Icons.chat_rounded),
      buildChip(preferences.sms, 'SMS', Icons.sms_rounded),
    ];
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
    final salons = data.salons;
    final clients = data.clients;
    final client = clients.firstWhereOrNull((item) => item.id == clientId);

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

    Future<void> openForm({Appointment? existing}) async {
      final latest = ref.read(appDataProvider);
      final sheetSalons = latest.salons.isNotEmpty ? latest.salons : salons;
      final sheetClients = latest.clients.isNotEmpty ? latest.clients : clients;
      final sheetStaff = latest.staff.isNotEmpty ? latest.staff : staff;
      final sheetServices =
          latest.services.isNotEmpty ? latest.services : services;

      final result = await showAppModalSheet<Appointment>(
        context: context,
        builder:
            (ctx) => AppointmentFormSheet(
              salons: sheetSalons,
              clients: sheetClients,
              staff: sheetStaff,
              services: sheetServices,
              defaultSalonId: existing?.salonId ?? client?.salonId,
              defaultClientId: existing?.clientId ?? client?.id,
              initial: existing,
              enableDelete: existing != null,
            ),
      );
      if (result == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      await _validateAndSaveAppointment(
        context,
        ref,
        result,
        appointments,
        sheetServices,
        sheetSalons,
      );
    }

    Future<void> createAppointment() async {
      await openForm();
    }

    Future<void> editAppointment(Appointment appointment) async {
      await openForm(existing: appointment);
    }

    Future<void> deleteAppointment(Appointment appointment) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Elimina appuntamento'),
              content: const Text(
                'Vuoi eliminare definitivamente questo appuntamento?',
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
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref
            .read(appDataProvider.notifier)
            .deleteAppointment(appointment.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Appuntamento eliminato.')),
        );
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text('Errore durante l\'eliminazione: $error')),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: client == null ? null : createAppointment,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuovo appuntamento'),
          ),
        ),
        const SizedBox(height: 16),
        _AppointmentGroup(
          title: 'Appuntamenti futuri',
          emptyMessage: 'Nessun appuntamento futuro prenotato.',
          appointments: upcoming,
          staff: staff,
          services: services,
          dateFormat: dateFormat,
          currency: currency,
          enableActions: true,
          onEditAppointment: editAppointment,
          onDeleteAppointment: deleteAppointment,
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

  Future<bool> _validateAndSaveAppointment(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
    List<Appointment> fallbackAppointments,
    List<Service> fallbackServices,
    List<Salon> fallbackSalons,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = ref.read(appDataProvider);
    final existingAppointments =
        data.appointments.isNotEmpty ? data.appointments : fallbackAppointments;
    final services =
        data.services.isNotEmpty ? data.services : fallbackServices;
    final salons = data.salons.isNotEmpty ? data.salons : fallbackSalons;

    final hasStaffConflict = hasStaffBookingConflict(
      appointments: existingAppointments,
      staffId: appointment.staffId,
      start: appointment.start,
      end: appointment.end,
      excludeAppointmentId: appointment.id,
    );
    if (hasStaffConflict) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile salvare: operatore già occupato in quel periodo',
          ),
        ),
      );
      return false;
    }

    final hasClientConflict = hasClientBookingConflict(
      appointments: existingAppointments,
      clientId: appointment.clientId,
      start: appointment.start,
      end: appointment.end,
      excludeAppointmentId: appointment.id,
    );
    if (hasClientConflict) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile salvare: il cliente ha già un appuntamento in quel periodo',
          ),
        ),
      );
      return false;
    }

    final appointmentServices =
        appointment.serviceIds
            .map((id) => services.firstWhereOrNull((item) => item.id == id))
            .whereType<Service>()
            .toList();
    if (appointmentServices.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Servizio non valido.')),
      );
      return false;
    }
    final salon = salons.firstWhereOrNull(
      (item) => item.id == appointment.salonId,
    );
    final blockingEquipment = <String>{};
    for (final service in appointmentServices) {
      final equipmentCheck = EquipmentAvailabilityChecker.check(
        salon: salon,
        service: service,
        allServices: services,
        appointments: existingAppointments,
        start: appointment.start,
        end: appointment.end,
        excludeAppointmentId: appointment.id,
      );
      if (equipmentCheck.hasConflicts) {
        blockingEquipment.addAll(equipmentCheck.blockingEquipment);
      }
    }
    if (blockingEquipment.isNotEmpty) {
      final equipmentLabel = blockingEquipment.join(', ');
      final message =
          equipmentLabel.isEmpty
              ? 'Macchinario non disponibile per questo orario.'
              : 'Macchinario non disponibile per questo orario: $equipmentLabel.';
      messenger.showSnackBar(
        SnackBar(content: Text('$message Scegli un altro slot.')),
      );
      return false;
    }

    try {
      await ref.read(appDataProvider.notifier).upsertAppointment(appointment);
      return true;
    } on StateError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return false;
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $error')),
      );
      return false;
    }
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
    this.enableActions = false,
    this.onEditAppointment,
    this.onDeleteAppointment,
  });

  final String title;
  final String emptyMessage;
  final List<Appointment> appointments;
  final List<StaffMember> staff;
  final List<Service> services;
  final DateFormat dateFormat;
  final NumberFormat currency;
  final bool enableActions;
  final Future<void> Function(Appointment appointment)? onEditAppointment;
  final Future<void> Function(Appointment appointment)? onDeleteAppointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showActions =
        enableActions &&
        (onEditAppointment != null || onDeleteAppointment != null);
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
                final appointmentServices =
                    appointment.serviceIds
                        .map(
                          (id) => services.firstWhereOrNull(
                            (element) => element.id == id,
                          ),
                        )
                        .whereType<Service>()
                        .toList();
                final operator = staff.firstWhereOrNull(
                  (element) => element.id == appointment.staffId,
                );
                final statusChip = _statusChip(context, appointment.status);
                final amount =
                    appointmentServices.isNotEmpty
                        ? appointmentServices
                            .map((service) => service.price)
                            .fold<double>(0, (value, price) => value + price)
                        : null;
                final packageLabel =
                    appointment.packageId == null
                        ? null
                        : 'Pacchetto #${appointment.packageId}';
                final serviceLabel =
                    appointmentServices.isNotEmpty
                        ? appointmentServices
                            .map((service) => service.name)
                            .join(' + ')
                        : 'Servizio';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    // Allow enough vertical space when actions are visible.
                    isThreeLine: packageLabel != null || showActions,
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: Text(serviceLabel),
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
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.end,
                          children: [
                            statusChip,
                            if (showActions && onEditAppointment != null)
                              IconButton(
                                tooltip: 'Modifica appuntamento',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                                icon: const Icon(Icons.edit_rounded, size: 20),
                                onPressed: () async {
                                  await onEditAppointment!(appointment);
                                },
                              ),
                            if (showActions && onDeleteAppointment != null)
                              IconButton(
                                tooltip: 'Elimina appuntamento',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  await onDeleteAppointment!(appointment);
                                },
                              ),
                          ],
                        ),
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
              /*  FilledButton.tonalIcon(
                onPressed: () => _createCustomPackage(context, client),
                icon: const Icon(Icons.design_services_rounded),
                label: const Text('Personalizza pacchetto'),
              ),
              FilledButton.icon(
                onPressed: () => _registerPackagePurchase(context, client),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Aggiungi pacchetto'),
              ),*/
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
              ? 'Saldato pacchetto $packageLabel'
              : 'Acconto pacchetto $packageLabel',
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

class _BillingTab extends ConsumerWidget {
  const _BillingTab({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final client = data.clients.firstWhereOrNull(
      (element) => element.id == clientId,
    );

    if (client == null) {
      return const Center(child: Text('Cliente non trovato.'));
    }

    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

    final sales =
        data.sales.where((sale) => sale.clientId == clientId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalPaid = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );
    int resolveLoyaltyValue(int? stored, int aggregated) {
      if (stored == null) {
        return aggregated;
      }
      if (stored == 0 && aggregated != 0) {
        return aggregated;
      }
      return stored;
    }

    final aggregatedEarned = sales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.resolvedEarnedPoints,
    );
    final aggregatedRedeemed = sales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.redeemedPoints,
    );
    final totalEarnedPoints = resolveLoyaltyValue(
      client.loyaltyTotalEarned,
      aggregatedEarned,
    );
    final totalRedeemedPoints = resolveLoyaltyValue(
      client.loyaltyTotalRedeemed,
      aggregatedRedeemed,
    );
    final initialPoints = client.loyaltyInitialPoints;
    final computedSpendable =
        initialPoints + totalEarnedPoints - totalRedeemedPoints;
    final loyaltySpendable = _resolveSpendableBalance(
      stored: client.loyaltyPoints,
      computed: computedSpendable,
    );

    final packages = resolveClientPackagePurchases(
      sales: data.sales,
      packages: data.packages,
      appointments: data.appointments,
      services: data.services,
      clientId: clientId,
    );

    final outstandingPackages =
        packages.where((purchase) => purchase.outstandingAmount > 0).toList()
          ..sort((a, b) => b.outstandingAmount.compareTo(a.outstandingAmount));

    final outstandingSales = <_OutstandingSale>[];
    for (final sale in sales) {
      if (sale.paymentStatus != SalePaymentStatus.deposit ||
          sale.outstandingAmount <= 0) {
        continue;
      }
      final packageOutstanding = _packageOutstandingAmount(sale);
      final residual = _normalizeCurrency(
        sale.outstandingAmount - packageOutstanding,
      );
      if (residual > 0.009) {
        outstandingSales.add(
          _OutstandingSale(sale: sale, outstanding: residual),
        );
      }
    }
    outstandingSales.sort(
      (a, b) => b.sale.createdAt.compareTo(a.sale.createdAt),
    );

    final openTickets =
        data.paymentTickets
            .where(
              (ticket) =>
                  ticket.clientId == clientId &&
                  ticket.status == PaymentTicketStatus.open,
            )
            .toList()
          ..sort((a, b) => a.appointmentStart.compareTo(b.appointmentStart));

    final outstandingPackagesTotal = outstandingPackages.fold<double>(
      0,
      (sum, purchase) => sum + purchase.outstandingAmount,
    );

    final outstandingSalesTotal = outstandingSales.fold<double>(
      0,
      (sum, entry) => sum + entry.outstanding,
    );

    final outstandingTicketsTotal = openTickets.fold<double>(
      0,
      (sum, ticket) => sum + (ticket.expectedTotal ?? 0),
    );

    final outstandingTotal =
        outstandingPackagesTotal +
        outstandingSalesTotal +
        outstandingTicketsTotal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed:
                () => _registerSale(
                  context: context,
                  ref: ref,
                  client: client,
                  salons: data.salons,
                  clients: data.clients,
                  staff: data.staff,
                  services: data.services,
                  packages: data.packages,
                  inventory: data.inventoryItems,
                  sales: data.sales,
                ),
            icon: const Icon(Icons.point_of_sale_rounded),
            label: const Text('Registra vendita'),
          ),
        ),
        const SizedBox(height: 16),
        _buildSummaryCard(
          theme,
          currency,
          totalPaid: totalPaid,
          outstandingTotal: outstandingTotal,
          loyaltyInitial: initialPoints,
          loyaltySpendable: loyaltySpendable,
          loyaltyEarned: totalEarnedPoints,
          loyaltyRedeemed: totalRedeemedPoints,
        ),
        const SizedBox(height: 16),
        _buildOutstandingCard(
          context,
          ref,
          theme,
          currency,
          dateFormat,
          dateTimeFormat,
          outstandingSales,
          outstandingPackages,
          openTickets,
          data.services,
          data.staff,
          data.clients,
        ),
        const SizedBox(height: 16),
        _buildHistoryCard(context, ref, theme, currency, dateTimeFormat, sales),
      ],
    );
  }

  Future<void> _registerSale({
    required BuildContext context,
    required WidgetRef ref,
    required Client client,
    required List<Salon> salons,
    required List<Client> clients,
    required List<StaffMember> staff,
    required List<Service> services,
    required List<ServicePackage> packages,
    required List<InventoryItem> inventory,
    required List<Sale> sales,
  }) async {
    if (salons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crea un salone prima di registrare una vendita.'),
        ),
      );
      return;
    }

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
            defaultSalonId: client.salonId,
            initialClientId: client.id,
          ),
    );

    if (sale == null) {
      return;
    }

    final store = ref.read(appDataProvider.notifier);
    await store.upsertSale(sale);
    await _recordSaleCashFlow(ref: ref, sale: sale, clients: clients);

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Vendita registrata.')));
  }

  Future<void> _recordSaleCashFlow({
    required WidgetRef ref,
    required Sale sale,
    required List<Client> clients,
  }) async {
    final cashPortion =
        sale.paymentStatus == SalePaymentStatus.deposit
            ? sale.paidAmount
            : sale.total;
    final normalized = _normalizeCurrency(cashPortion);
    if (normalized <= 0) {
      return;
    }
    final clientName =
        clients
            .firstWhereOrNull((client) => client.id == sale.clientId)
            ?.fullName ??
        'Cliente';
    final description =
        sale.paymentStatus == SalePaymentStatus.deposit
            ? 'Acconto vendita a $clientName'
            : 'Vendita a $clientName';
    await _recordCashFlowEntry(
      ref: ref,
      sale: sale,
      amount: normalized,
      description: description,
      date: sale.createdAt,
    );
  }

  double _packageOutstandingAmount(Sale sale) {
    var total = 0.0;
    for (final item in sale.items) {
      if (item.referenceType != SaleReferenceType.package) {
        continue;
      }
      final outstanding = item.amount - item.depositAmount;
      if (outstanding > 0) {
        total += outstanding;
      }
    }
    return _normalizeCurrency(total);
  }

  double _normalizeCurrency(double value) {
    if (value <= 0) {
      return 0;
    }
    return double.parse(value.toStringAsFixed(2));
  }

  List<SaleItem> _applyPackagePaymentDistribution({
    required List<SaleItem> items,
    required SalePaymentStatus paymentStatus,
    required double paidAmount,
  }) {
    if (!items.any((item) => item.referenceType == SaleReferenceType.package)) {
      return items;
    }

    final updated = <SaleItem>[];
    if (paymentStatus == SalePaymentStatus.deposit) {
      var remaining = _normalizeCurrency(paidAmount);
      for (final item in items) {
        if (item.referenceType == SaleReferenceType.package) {
          final lineTotal = item.amount;
          final applied = _normalizeCurrency(
            remaining <= 0
                ? 0
                : remaining >= lineTotal
                ? lineTotal
                : remaining,
          );
          remaining = _normalizeCurrency(remaining - applied);
          final packageStatus =
              applied >= lineTotal - 0.009
                  ? PackagePaymentStatus.paid
                  : PackagePaymentStatus.deposit;
          updated.add(
            item.copyWith(
              depositAmount: applied,
              packagePaymentStatus: packageStatus,
            ),
          );
        } else {
          updated.add(item);
        }
      }
    } else {
      for (final item in items) {
        if (item.referenceType == SaleReferenceType.package) {
          updated.add(
            item.copyWith(
              depositAmount: _normalizeCurrency(item.amount),
              packagePaymentStatus: PackagePaymentStatus.paid,
            ),
          );
        } else {
          updated.add(item);
        }
      }
    }
    return updated;
  }

  List<_SaleDepositEntry> _collectSaleDeposits(Sale sale) {
    final entries = <_SaleDepositEntry>[];
    if (sale.paymentHistory.isNotEmpty) {
      for (final movement in sale.paymentHistory) {
        if (movement.amount <= 0) {
          continue;
        }
        entries.add(
          _SaleDepositEntry(
            id: movement.id,
            amount: _normalizeCurrency(movement.amount),
            date: movement.date,
            paymentMethod: movement.paymentMethod,
            note: movement.note,
            recordedBy: movement.recordedBy,
            movementType: movement.type,
          ),
        );
      }
    } else {
      for (final item in sale.items) {
        if (item.deposits.isEmpty) {
          continue;
        }
        final itemLabel =
            item.description.trim().isEmpty ? null : item.description.trim();
        for (final deposit in item.deposits) {
          if (deposit.amount <= 0) {
            continue;
          }
          entries.add(
            _SaleDepositEntry(
              id: deposit.id,
              amount: _normalizeCurrency(deposit.amount),
              date: deposit.date,
              paymentMethod: deposit.paymentMethod,
              note: deposit.note,
              itemDescription: itemLabel,
            ),
          );
        }
      }
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  List<PackageDeposit> _alignDepositsToAmount(
    List<PackageDeposit> deposits,
    double targetAmount,
  ) {
    final normalizedTarget = _normalizeCurrency(targetAmount);
    if (normalizedTarget <= 0 || deposits.isEmpty) {
      return normalizedTarget <= 0 ? const <PackageDeposit>[] : deposits;
    }

    final sorted = [...deposits]..sort((a, b) => a.date.compareTo(b.date));
    final result = <PackageDeposit>[];
    var remaining = normalizedTarget;

    for (final deposit in sorted) {
      if (remaining <= 0.009) {
        break;
      }
      final amount = _normalizeCurrency(deposit.amount);
      if (amount <= remaining + 0.009) {
        result.add(deposit.copyWith(amount: amount));
        remaining = _normalizeCurrency(remaining - amount);
      } else {
        result.add(deposit.copyWith(amount: remaining));
        remaining = 0;
        break;
      }
    }

    if (remaining > 0.009 && result.isNotEmpty) {
      final lastIndex = result.length - 1;
      final last = result[lastIndex];
      result[lastIndex] = last.copyWith(
        amount: _normalizeCurrency(last.amount + remaining),
      );
    }

    return result;
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    NumberFormat currency, {
    required double totalPaid,
    required double outstandingTotal,
    required int loyaltyInitial,
    required int loyaltySpendable,
    required int loyaltyEarned,
    required int loyaltyRedeemed,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Riepilogo incassi', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Incassato',
                    value: currency.format(totalPaid),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Da incassare',
                    value: currency.format(outstandingTotal),
                    emphasize: outstandingTotal > 0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Saldo utilizzabile',
                    value: '$loyaltySpendable pt',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Punti iniziali',
                    value: '$loyaltyInitial pt',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Punti accumulati',
                    value: '$loyaltyEarned pt',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryValue(
                    theme,
                    label: 'Punti utilizzati',
                    value: '$loyaltyRedeemed pt',
                    emphasize: loyaltyRedeemed > 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _resolveSpendableBalance({required int stored, required int computed}) {
    final normalizedStored = stored < 0 ? 0 : stored;
    final normalizedComputed = computed < 0 ? 0 : computed;
    if (normalizedStored == normalizedComputed) {
      return normalizedStored;
    }
    if (normalizedComputed == 0 && normalizedStored != 0) {
      return normalizedStored;
    }
    return normalizedComputed;
  }

  Widget _buildSummaryValue(
    ThemeData theme, {
    required String label,
    required String value,
    bool emphasize = false,
  }) {
    final baseStyle =
        theme.textTheme.titleLarge ??
        const TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
    final valueStyle =
        emphasize
            ? baseStyle.copyWith(color: theme.colorScheme.error)
            : baseStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: valueStyle),
      ],
    );
  }

  Widget _buildOutstandingCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    NumberFormat currency,
    DateFormat dateFormat,
    DateFormat dateTimeFormat,
    List<_OutstandingSale> outstandingSales,
    List<ClientPackagePurchase> outstandingPackages,
    List<PaymentTicket> openTickets,
    List<Service> services,
    List<StaffMember> staff,
    List<Client> clients,
  ) {
    if (openTickets.isEmpty &&
        outstandingPackages.isEmpty &&
        outstandingSales.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.verified_rounded),
          title: Text('Nessun pagamento in sospeso'),
        ),
      );
    }

    final content = <Widget>[
      Text('Pagamenti da saldare', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
    ];

    var hasSection = false;

    void addSectionSpacingIfNeeded() {
      if (!hasSection) {
        hasSection = true;
        return;
      }
      content.add(const SizedBox(height: 16));
      content.add(const Divider());
      content.add(const SizedBox(height: 16));
    }

    if (outstandingSales.isNotEmpty) {
      addSectionSpacingIfNeeded();
      content.add(
        Text('Vendite con acconto', style: theme.textTheme.titleSmall),
      );
      content.add(const SizedBox(height: 8));
      for (var index = 0; index < outstandingSales.length; index++) {
        final outstandingSale = outstandingSales[index];
        content.add(
          _buildOutstandingSaleTile(
            theme,
            currency,
            dateTimeFormat,
            staff,
            outstandingSale,
            onTap:
                () => _editSalePayment(
                  context: context,
                  ref: ref,
                  sale: outstandingSale.sale,
                  clients: clients,
                  staff: staff,
                ),
          ),
        );
        if (index < outstandingSales.length - 1) {
          content.add(const SizedBox(height: 12));
        }
      }
    }

    if (openTickets.isNotEmpty) {
      addSectionSpacingIfNeeded();
      content.add(Text('Ticket aperti', style: theme.textTheme.titleSmall));
      content.add(const SizedBox(height: 8));
      for (var index = 0; index < openTickets.length; index++) {
        final ticket = openTickets[index];
        content.add(
          _buildTicketTile(
            theme,
            currency,
            dateTimeFormat,
            services,
            staff,
            ticket,
            onTap:
                () => _openTicketSale(
                  context: context,
                  ref: ref,
                  ticket: ticket,
                  clients: clients,
                  staff: staff,
                  services: services,
                ),
          ),
        );
        if (index < openTickets.length - 1) {
          content.add(const SizedBox(height: 12));
        }
      }
    }

    if (outstandingPackages.isNotEmpty) {
      addSectionSpacingIfNeeded();
      content.add(
        Text('Pacchetti con saldo residuo', style: theme.textTheme.titleSmall),
      );
      content.add(const SizedBox(height: 8));
      for (var index = 0; index < outstandingPackages.length; index++) {
        final purchase = outstandingPackages[index];
        content.add(
          _buildOutstandingPackageTile(
            theme,
            currency,
            dateFormat,
            purchase,
            onTap:
                () => _editSalePayment(
                  context: context,
                  ref: ref,
                  sale: purchase.sale,
                  clients: clients,
                  staff: staff,
                ),
          ),
        );
        if (index < outstandingPackages.length - 1) {
          content.add(const SizedBox(height: 12));
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        ),
      ),
    );
  }

  Future<void> _editSalePayment({
    required BuildContext context,
    required WidgetRef ref,
    required Sale sale,
    required List<Client> clients,
    required List<StaffMember> staff,
  }) async {
    final outstanding = _normalizeCurrency(sale.outstandingAmount);
    if (outstanding <= 0) {
      return;
    }

    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final staffOptions =
        staff.where((member) => member.salonId == sale.salonId).toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final saleStaffName =
        staffOptions
            .firstWhereOrNull((member) => member.id == sale.staffId)
            ?.fullName ??
        staff.firstWhereOrNull((member) => member.id == sale.staffId)?.fullName;
    final result = await showAppModalSheet<OutstandingPaymentResult>(
      context: context,
      builder:
          (ctx) => OutstandingPaymentFormSheet(
            title: 'Registra incasso',
            subtitle: 'Residuo disponibile: ${currency.format(outstanding)}',
            outstandingAmount: outstanding,
            initialAmount: outstanding,
            staff: staffOptions,
            initialStaffId: sale.staffId,
            staffName: saleStaffName,
            currency: currency,
          ),
    );

    if (result == null) {
      return;
    }

    final additional = _normalizeCurrency(result.amount);
    if (additional <= 0) {
      return;
    }

    final timestamp = DateTime.now();
    final nextPaidAmount = _normalizeCurrency(sale.paidAmount + additional);
    final nextStatus =
        nextPaidAmount >= sale.total - 0.009
            ? SalePaymentStatus.paid
            : SalePaymentStatus.deposit;

    final updatedItems = _applyPackagePaymentDistribution(
      items: sale.items,
      paymentStatus: nextStatus,
      paidAmount: nextPaidAmount,
    );

    final enrichedItems = <SaleItem>[];
    for (var index = 0; index < updatedItems.length; index++) {
      final updatedItem = updatedItems[index];
      final originalItem = sale.items[index];
      if (updatedItem.referenceType != SaleReferenceType.package) {
        enrichedItems.add(updatedItem);
        continue;
      }

      final previousDeposit = _normalizeCurrency(originalItem.depositAmount);
      final currentDeposit = _normalizeCurrency(updatedItem.depositAmount);
      final delta = _normalizeCurrency(currentDeposit - previousDeposit);
      if (delta <= 0.009) {
        enrichedItems.add(updatedItem);
        continue;
      }

      final deposits = [...updatedItem.deposits];
      if (deposits.isEmpty && previousDeposit > 0.009) {
        deposits.add(
          PackageDeposit(
            id: const Uuid().v4(),
            amount: previousDeposit,
            date: sale.createdAt,
            note: 'Acconto iniziale',
            paymentMethod: sale.paymentMethod,
          ),
        );
      }
      deposits.add(
        PackageDeposit(
          id: const Uuid().v4(),
          amount: delta,
          date: timestamp,
          note:
              updatedItem.packagePaymentStatus == PackagePaymentStatus.paid
                  ? 'Saldo registrato'
                  : 'Acconto registrato',
          paymentMethod: result.method,
        ),
      );

      enrichedItems.add(
        updatedItem.copyWith(
          deposits: deposits,
          depositAmount: updatedItem.depositAmount,
        ),
      );
    }

    final store = ref.read(appDataProvider.notifier);
    final selectedStaff = staffOptions.firstWhereOrNull(
      (member) => member.id == result.staffId,
    );
    final recorder =
        selectedStaff?.fullName ??
        store.currentUser?.displayName ??
        store.currentUser?.uid;
    final movementType =
        nextStatus == SalePaymentStatus.paid
            ? SalePaymentType.settlement
            : SalePaymentType.deposit;
    final movements =
        sale.paymentHistory.isNotEmpty
            ? [...sale.paymentHistory]
            : <SalePaymentMovement>[];
    if (movements.isEmpty) {
      final legacyDeposit = _totalSaleDeposits(sale);
      if (legacyDeposit > 0.009) {
        final initialType =
            sale.paymentStatus == SalePaymentStatus.paid
                ? SalePaymentType.settlement
                : SalePaymentType.deposit;
        final legacyRecorder =
            staff
                .firstWhereOrNull((member) => member.id == sale.staffId)
                ?.fullName;
        movements.add(
          SalePaymentMovement(
            id: const Uuid().v4(),
            amount: legacyDeposit,
            type: initialType,
            date: sale.createdAt,
            paymentMethod: sale.paymentMethod,
            recordedBy: legacyRecorder,
            note:
                initialType == SalePaymentType.deposit
                    ? 'Acconto iniziale (storico)'
                    : 'Saldo iniziale (storico)',
          ),
        );
      }
    }
    movements.add(
      SalePaymentMovement(
        id: const Uuid().v4(),
        amount: additional,
        type: movementType,
        date: timestamp,
        paymentMethod: result.method,
        recordedBy: recorder,
        note:
            movementType == SalePaymentType.deposit
                ? 'Acconto registrato'
                : 'Saldo registrato',
      ),
    );
    movements.sort((a, b) => a.date.compareTo(b.date));

    final updatedSale = sale.copyWith(
      paidAmount: nextPaidAmount,
      paymentStatus: nextStatus,
      items: enrichedItems,
      paymentMethod: result.method,
      staffId: result.staffId ?? sale.staffId,
      paymentHistory: movements,
    );

    await store.upsertSale(updatedSale);

    final clientName =
        clients
            .firstWhereOrNull((client) => client.id == sale.clientId)
            ?.fullName ??
        'Cliente';
    final isFinal =
        nextStatus == SalePaymentStatus.paid ||
        updatedSale.outstandingAmount <= 0.009;
    final description =
        isFinal
            ? 'Saldo vendita a $clientName'
            : 'Acconto vendita a $clientName';

    await _recordCashFlowEntry(
      ref: ref,
      sale: updatedSale,
      amount: additional,
      description: description,
      date: timestamp,
    );
  }

  Future<void> _reverseSaleDeposit({
    required BuildContext context,
    required WidgetRef ref,
    required Sale sale,
    required _SaleDepositEntry deposit,
    required NumberFormat currency,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Storna acconto'),
            content: Text(
              'Vuoi stornare l\'acconto da ${currency.format(deposit.amount)}? Verrà registrato un movimento negativo in cassa.',
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

    final amount = _normalizeCurrency(deposit.amount);
    if (amount <= 0) {
      return;
    }

    final movement = sale.paymentHistory.firstWhereOrNull(
      (entry) => entry.id == deposit.id,
    );
    final movements =
        sale.paymentHistory.isEmpty
            ? <SalePaymentMovement>[]
            : [...sale.paymentHistory];
    if (movement != null) {
      movements.removeWhere((entry) => entry.id == movement.id);
    }

    var nextPaidAmount = sale.paidAmount - amount;
    if (nextPaidAmount < 0) {
      nextPaidAmount = 0;
    }
    nextPaidAmount = _normalizeCurrency(nextPaidAmount);

    final nextStatus =
        nextPaidAmount >= sale.total - 0.009
            ? SalePaymentStatus.paid
            : SalePaymentStatus.deposit;

    final distributedItems = _applyPackagePaymentDistribution(
      items: sale.items,
      paymentStatus: nextStatus,
      paidAmount: nextPaidAmount,
    );

    final adjustedItems = <SaleItem>[];
    for (var index = 0; index < distributedItems.length; index++) {
      final updatedItem = distributedItems[index];
      if (updatedItem.referenceType != SaleReferenceType.package) {
        adjustedItems.add(updatedItem);
        continue;
      }
      final originalItem = sale.items[index];
      var deposits = originalItem.deposits;
      if (deposits.isNotEmpty) {
        deposits = deposits.where((entry) => entry.id != deposit.id).toList();
      }
      final alignedDeposits = _alignDepositsToAmount(
        deposits,
        updatedItem.depositAmount,
      );
      adjustedItems.add(updatedItem.copyWith(deposits: alignedDeposits));
    }

    movements.sort((a, b) => a.date.compareTo(b.date));

    var loyaltySummary = sale.loyalty;
    var discountAmount = sale.discountAmount;
    var totalAmount = sale.total;
    final loyaltyDiscount = _normalizeCurrency(sale.loyalty.redeemedValue);

    if (nextPaidAmount <= 0.009 &&
        (loyaltySummary.redeemedPoints != 0 ||
            loyaltySummary.earnedPoints != 0)) {
      loyaltySummary = SaleLoyaltySummary();
      if (loyaltyDiscount > 0) {
        discountAmount = _normalizeCurrency(discountAmount - loyaltyDiscount);
        totalAmount = _normalizeCurrency(totalAmount + loyaltyDiscount);
      }
    }

    final updatedSale = sale.copyWith(
      paidAmount: nextPaidAmount,
      paymentStatus: nextStatus,
      items: adjustedItems,
      paymentHistory: movements,
      loyalty: loyaltySummary,
      discountAmount: discountAmount,
      total: totalAmount,
    );

    final store = ref.read(appDataProvider.notifier);
    await store.upsertSale(updatedSale);

    final clients = ref.read(appDataProvider).clients;
    final clientName =
        clients
            .firstWhereOrNull((client) => client.id == sale.clientId)
            ?.fullName ??
        'Cliente';
    final description =
        deposit.movementType == SalePaymentType.settlement
            ? 'Storno saldo vendita a $clientName'
            : 'Storno acconto vendita a $clientName';

    await _recordCashFlowEntry(
      ref: ref,
      sale: updatedSale,
      amount: -amount,
      description: description,
      date: DateTime.now(),
    );

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Acconto stornato.')));
  }

  Future<void> _openTicketSale({
    required BuildContext context,
    required WidgetRef ref,
    required PaymentTicket ticket,
    required List<Client> clients,
    required List<StaffMember> staff,
    required List<Service> services,
  }) async {
    final matchedService = services.firstWhereOrNull(
      (service) => service.id == ticket.serviceId,
    );
    final rawTotal = ticket.expectedTotal ?? matchedService?.price ?? 0;
    final normalizedTotal = rawTotal > 0 ? _normalizeCurrency(rawTotal) : null;
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final store = ref.read(appDataProvider.notifier);
    final staffOptions =
        staff.where((member) => member.salonId == ticket.salonId).toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final saleStaffName =
        staffOptions
            .firstWhereOrNull((member) => member.id == ticket.staffId)
            ?.fullName ??
        staff
            .firstWhereOrNull((member) => member.id == ticket.staffId)
            ?.fullName;

    final result = await showAppModalSheet<OutstandingPaymentResult>(
      context: context,
      builder:
          (ctx) => OutstandingPaymentFormSheet(
            title: 'Registra incasso',
            subtitle:
                normalizedTotal == null
                    ? 'Inserisci l\'importo da incassare'
                    : 'Totale previsto: ${currency.format(normalizedTotal)}',
            outstandingAmount: normalizedTotal ?? double.infinity,
            initialAmount: normalizedTotal,
            staff: staffOptions,
            initialStaffId: ticket.staffId,
            staffName: saleStaffName,
            currency: currency,
          ),
    );

    if (result == null) {
      return;
    }

    final paidAmount = _normalizeCurrency(result.amount);
    if (paidAmount <= 0) {
      return;
    }

    final selectedStaff = staffOptions.firstWhereOrNull(
      (member) => member.id == result.staffId,
    );
    final recorder =
        selectedStaff?.fullName ??
        store.currentUser?.displayName ??
        store.currentUser?.uid;

    final saleTotal = normalizedTotal ?? paidAmount;
    final status =
        paidAmount >= saleTotal - 0.009
            ? SalePaymentStatus.paid
            : SalePaymentStatus.deposit;
    final creationDate = DateTime.now();
    final movementType =
        status == SalePaymentStatus.paid
            ? SalePaymentType.settlement
            : SalePaymentType.deposit;
    final paymentMovements = <SalePaymentMovement>[
      SalePaymentMovement(
        id: const Uuid().v4(),
        amount: paidAmount,
        type: movementType,
        date: creationDate,
        paymentMethod: result.method,
        recordedBy: recorder,
        note:
            movementType == SalePaymentType.deposit
                ? 'Incasso ticket (acconto)'
                : 'Incasso ticket (saldo)',
      ),
    ];

    final sale = Sale(
      id: const Uuid().v4(),
      salonId: ticket.salonId,
      clientId: ticket.clientId,
      items: [
        SaleItem(
          referenceId: ticket.serviceId,
          referenceType: SaleReferenceType.service,
          description: matchedService?.name ?? ticket.serviceName ?? 'Servizio',
          quantity: 1,
          unitPrice: saleTotal,
        ),
      ],
      total: saleTotal,
      createdAt: creationDate,
      paymentMethod: result.method,
      paymentStatus: status,
      paidAmount: status == SalePaymentStatus.paid ? saleTotal : paidAmount,
      invoiceNumber: null,
      notes: ticket.notes,
      discountAmount: 0,
      staffId: result.staffId ?? ticket.staffId,
      paymentHistory: paymentMovements,
    );

    await store.upsertSale(sale);

    final clientName =
        clients
            .firstWhereOrNull((client) => client.id == sale.clientId)
            ?.fullName ??
        'Cliente';
    final description =
        status == SalePaymentStatus.deposit
            ? 'Acconto vendita a $clientName'
            : 'Vendita a $clientName';

    await _recordCashFlowEntry(
      ref: ref,
      sale: sale,
      amount: paidAmount,
      description: description,
      date: creationDate,
    );

    await store.closePaymentTicket(ticket.id, saleId: sale.id);
  }

  Future<void> _recordCashFlowEntry({
    required WidgetRef ref,
    required Sale sale,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    final magnitude = _normalizeCurrency(amount.abs());
    if (magnitude <= 0) {
      return;
    }
    final type = amount >= 0 ? CashFlowType.income : CashFlowType.expense;
    final entry = CashFlowEntry(
      id: const Uuid().v4(),
      salonId: sale.salonId,
      type: type,
      amount: magnitude,
      date: date ?? DateTime.now(),
      description: description,
      category: 'Vendite',
      staffId: sale.staffId,
    );
    await ref.read(appDataProvider.notifier).upsertCashFlowEntry(entry);
  }

  Widget _buildOutstandingSaleTile(
    ThemeData theme,
    NumberFormat currency,
    DateFormat dateTimeFormat,
    List<StaffMember> staff,
    _OutstandingSale outstandingSale, {
    VoidCallback? onTap,
  }) {
    final sale = outstandingSale.sale;
    final saleDate = dateTimeFormat.format(sale.createdAt);
    final staffMember =
        sale.staffId == null
            ? null
            : staff.firstWhereOrNull((member) => member.id == sale.staffId);
    final items =
        sale.items
            .map((item) => item.description)
            .where((value) => value.isNotEmpty)
            .toList();
    final preview = items.take(2).join(', ');
    final remaining = math.max(items.length - 2, 0);
    final depositTotal = _totalSaleDeposits(sale);
    final subtitleLines = <String>[
      'Metodo: ${_PackageGroup._paymentLabel(sale.paymentMethod)} • Incassato ${currency.format(depositTotal)} di ${currency.format(sale.total)}',
    ];
    if (staffMember != null) {
      subtitleLines.add('Operatore: ${staffMember.fullName}');
    }
    if (preview.isNotEmpty) {
      subtitleLines.add(
        remaining > 0 ? 'Voci: $preview (+$remaining)' : 'Voci: $preview',
      );
    }
    if (sale.notes != null && sale.notes!.isNotEmpty) {
      subtitleLines.add('Note: ${sale.notes}');
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.point_of_sale_rounded,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text('Vendita del $saleDate'),
      subtitle: Text(subtitleLines.join('\n')),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currency.format(outstandingSale.outstanding),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Residuo da incassare', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildTicketTile(
    ThemeData theme,
    NumberFormat currency,
    DateFormat dateTimeFormat,
    List<Service> services,
    List<StaffMember> staff,
    PaymentTicket ticket, {
    VoidCallback? onTap,
  }) {
    final service = services.firstWhereOrNull(
      (element) => element.id == ticket.serviceId,
    );
    final serviceName = ticket.serviceName ?? service?.name ?? 'Servizio';
    final operator =
        ticket.staffId == null
            ? null
            : staff.firstWhereOrNull((member) => member.id == ticket.staffId);
    final appointmentLabel = dateTimeFormat.format(ticket.appointmentStart);
    final amount = ticket.expectedTotal;
    final subtitleParts = <String>['Appuntamento: $appointmentLabel'];
    if (operator != null) {
      subtitleParts.add('Operatore: ${operator.fullName}');
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.receipt_long_rounded,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(serviceName),
      subtitle: Text(subtitleParts.join(' • ')),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount != null && amount > 0
                ? currency.format(amount)
                : 'Importo n/d',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Residuo da incassare', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildOutstandingPackageTile(
    ThemeData theme,
    NumberFormat currency,
    DateFormat dateFormat,
    ClientPackagePurchase purchase, {
    VoidCallback? onTap,
  }) {
    final purchaseDate = dateFormat.format(purchase.sale.createdAt);
    final deposit = _packageDepositTotal(purchase);
    final paymentMethod = _PackageGroup._paymentLabel(
      purchase.sale.paymentMethod,
    );
    final info = <String>['Acquisto: $purchaseDate', 'Metodo: $paymentMethod'];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.card_membership_rounded,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(purchase.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(info.join(' • ')),
          if (deposit > 0) Text('Acconto versato: ${currency.format(deposit)}'),
          if (purchase.serviceNames.isNotEmpty)
            Text('Servizi: ${purchase.serviceNames.join(', ')}'),
        ],
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currency.format(purchase.outstandingAmount),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Da saldare', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  double _totalSaleDeposits(Sale sale) {
    final history = sale.paymentHistory;
    final depositsFromHistory = history
        .where((movement) => movement.type == SalePaymentType.deposit)
        .fold<double>(0, (sum, movement) => sum + movement.amount);
    if (depositsFromHistory > 0.009) {
      return _normalizeCurrency(depositsFromHistory);
    }
    final depositsFromItems = sale.items.fold<double>(
      0,
      (sum, item) => sum + item.depositAmount,
    );
    if (depositsFromItems > 0.009) {
      return _normalizeCurrency(depositsFromItems);
    }
    if (sale.paymentStatus == SalePaymentStatus.deposit &&
        sale.paidAmount > 0) {
      return _normalizeCurrency(sale.paidAmount);
    }
    return 0;
  }

  double _packageDepositTotal(ClientPackagePurchase purchase) {
    final deposits = purchase.deposits;
    final depositsSum = deposits.fold<double>(
      0,
      (sum, entry) => sum + entry.amount,
    );
    final expectedDeposit = _normalizeCurrency(purchase.depositAmount);
    var result = 0.0;
    if (depositsSum > result + 0.009) {
      result = _normalizeCurrency(depositsSum);
    }
    if (expectedDeposit > result + 0.009) {
      result = expectedDeposit;
    }
    final saleLevelDeposits = _totalSaleDeposits(purchase.sale);
    if (saleLevelDeposits > result + 0.009) {
      result = saleLevelDeposits;
    }
    return result;
  }

  Widget _buildHistoryCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    NumberFormat currency,
    DateFormat dateTimeFormat,
    List<Sale> sales,
  ) {
    if (sales.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline_rounded),
          title: Text('Nessun pagamento registrato'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Storico pagamenti', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...List.generate(sales.length, (index) {
              final sale = sales[index];
              final saleDate = dateTimeFormat.format(sale.createdAt);
              final itemDescriptions =
                  sale.items
                      .map((item) => item.description)
                      .where((value) => value.isNotEmpty)
                      .toList();
              final preview = itemDescriptions.take(3).join(', ');
              final remaining = math.max(itemDescriptions.length - 3, 0);
              final details =
                  StringBuffer()
                    ..write(
                      'Metodo: ${_PackageGroup._paymentLabel(sale.paymentMethod)}',
                    )
                    ..write(' • Stato: ${sale.paymentStatus.label}')
                    ..write(' • Articoli: ${sale.items.length}');
              if (sale.invoiceNumber != null &&
                  sale.invoiceNumber!.isNotEmpty) {
                details.write(' • Documento: ${sale.invoiceNumber}');
              }
              if (sale.discountAmount > 0) {
                details.write(
                  ' • Sconto: ${currency.format(sale.discountAmount)}',
                );
              }
              final subtitleLines = <String>[details.toString()];
              if (preview.isNotEmpty) {
                subtitleLines.add(
                  remaining > 0
                      ? 'Elementi: $preview (+$remaining)'
                      : 'Elementi: $preview',
                );
              }
              if (sale.notes != null && sale.notes!.isNotEmpty) {
                subtitleLines.add('Note: ${sale.notes}');
              }
              if (sale.paymentStatus == SalePaymentStatus.deposit) {
                subtitleLines.add(
                  'Incassato: ${currency.format(sale.paidAmount)} · Residuo: ${currency.format(sale.outstandingAmount)}',
                );
              }
              final deposits = _collectSaleDeposits(sale);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == sales.length - 1 ? 0 : 12,
                ),
                child: _PaymentHistoryTile(
                  key: ValueKey('payment-history-${sale.id}'),
                  sale: sale,
                  title: 'Vendita del $saleDate',
                  subtitleLines: subtitleLines,
                  currency: currency,
                  theme: theme,
                  dateTimeFormat: dateTimeFormat,
                  deposits: deposits,
                  onDeleteDeposit:
                      deposits.isEmpty
                          ? null
                          : (entry) => _reverseSaleDeposit(
                            context: context,
                            ref: ref,
                            sale: sale,
                            deposit: entry,
                            currency: currency,
                          ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _OutstandingSale {
  const _OutstandingSale({required this.sale, required this.outstanding});

  final Sale sale;
  final double outstanding;
}

class _SaleDepositEntry {
  const _SaleDepositEntry({
    required this.id,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.note,
    this.itemDescription,
    this.recordedBy,
    this.movementType,
  });

  final String id;
  final double amount;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final String? note;
  final String? itemDescription;
  final String? recordedBy;
  final SalePaymentType? movementType;
}

class _PaymentHistoryTile extends StatefulWidget {
  const _PaymentHistoryTile({
    required this.sale,
    required this.title,
    required this.subtitleLines,
    required this.currency,
    required this.theme,
    required this.dateTimeFormat,
    required this.deposits,
    this.onDeleteDeposit,
    super.key,
  });

  final Sale sale;
  final String title;
  final List<String> subtitleLines;
  final NumberFormat currency;
  final ThemeData theme;
  final DateFormat dateTimeFormat;
  final List<_SaleDepositEntry> deposits;
  final Future<void> Function(_SaleDepositEntry entry)? onDeleteDeposit;

  @override
  State<_PaymentHistoryTile> createState() => _PaymentHistoryTileState();
}

class _PaymentHistoryTileState extends State<_PaymentHistoryTile> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final hasDeposits = widget.deposits.isNotEmpty;
    final scheme = widget.theme.colorScheme;
    final trailingAmount =
        sale.paymentStatus == SalePaymentStatus.deposit
            ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.currency.format(sale.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Incassato ${widget.currency.format(sale.paidAmount)}',
                  style: widget.theme.textTheme.bodySmall,
                ),
              ],
            )
            : Text(
              widget.currency.format(sale.total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          key: ValueKey('payment-history-tile-${sale.id}'),
          contentPadding: EdgeInsets.zero,
          onTap: _toggle,
          leading: CircleAvatar(
            backgroundColor: scheme.surfaceContainerHighest,
            child: Icon(Icons.payment_rounded, color: scheme.primary),
          ),
          title: Text(widget.title),
          subtitle: Text(widget.subtitleLines.join('\n')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              trailingAmount,
              const SizedBox(width: 8),
              Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color:
                    hasDeposits
                        ? widget.theme.iconTheme.color
                        : widget.theme.disabledColor,
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
            child: _buildDepositsSection(
              scheme,
              widget.currency,
              widget.dateTimeFormat,
              widget.deposits,
              widget.onDeleteDeposit,
            ),
          ),
      ],
    );
  }

  Widget _buildDepositsSection(
    ColorScheme scheme,
    NumberFormat currency,
    DateFormat dateFormat,
    List<_SaleDepositEntry> deposits,
    Future<void> Function(_SaleDepositEntry entry)? onDeleteDeposit,
  ) {
    final background = scheme.surfaceContainerHighest;
    final outline = scheme.outlineVariant.withOpacity(0.6);
    final theme = widget.theme;
    if (deposits.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: outline, width: 0.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nessun movimento registrato',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outline, width: 0.5),
      ),
      child: Column(
        children: [
          for (var index = 0; index < deposits.length; index++)
            _DepositRow(
              entry: deposits[index],
              currency: currency,
              dateFormat: dateFormat,
              showDivider: index < deposits.length - 1,
              onDelete: onDeleteDeposit,
            ),
        ],
      ),
    );
  }
}

class _DepositRow extends StatelessWidget {
  const _DepositRow({
    required this.entry,
    required this.currency,
    required this.dateFormat,
    this.showDivider = false,
    this.onDelete,
  });

  final _SaleDepositEntry entry;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final bool showDivider;
  final Future<void> Function(_SaleDepositEntry entry)? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.savings_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.movementType == null
                          ? currency.format(entry.amount)
                          : '${currency.format(entry.amount)} • ${entry.movementType!.label}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        dateFormat.format(entry.date),
                        _PackageGroup._paymentLabel(entry.paymentMethod),
                        if (entry.recordedBy != null &&
                            entry.recordedBy!.isNotEmpty)
                          'Operatore: ${entry.recordedBy}',
                      ].join(' • '),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (entry.itemDescription != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.itemDescription!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (entry.note != null && entry.note!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Nota: ${entry.note}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Storna acconto',
                  icon: const Icon(Icons.undo_rounded),
                  onPressed: () => onDelete?.call(entry),
                ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            color: scheme.outlineVariant.withOpacity(0.5),
          ),
      ],
    );
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
