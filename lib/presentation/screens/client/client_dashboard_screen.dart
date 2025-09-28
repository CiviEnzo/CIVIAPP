import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/presentation/shared/client_package_purchase.dart';
import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'client_booking_sheet.dart';

class ClientDashboardScreen extends ConsumerStatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  ConsumerState<ClientDashboardScreen> createState() =>
      _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends ConsumerState<ClientDashboardScreen> {
  Future<void> _openBookingSheet(
    Client client, {
    Service? preselectedService,
  }) async {
    final appointment = await ClientBookingSheet.show(
      context,
      client: client,
      preselectedService: preselectedService,
    );
    if (!mounted || appointment == null) {
      return;
    }
    final confirmationFormat = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Appuntamento prenotato per '
          '${confirmationFormat.format(appointment.start)}.',
        ),
      ),
    );
  }

  Future<void> _rescheduleAppointment(
    Client client,
    Appointment appointment,
  ) async {
    final updated = await ClientBookingSheet.show(
      context,
      client: client,
      existingAppointment: appointment,
    );
    if (!mounted || updated == null) {
      return;
    }
    final format = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Appuntamento aggiornato al ${format.format(updated.start)}.',
        ),
      ),
    );
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    final format = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
    final appointmentLabel = format.format(appointment.start);
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Annulla appuntamento'),
          content: Text(
            'Vuoi annullare l\'appuntamento del $appointmentLabel?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sì, annulla'),
            ),
          ],
        );
      },
    );
    if (shouldCancel != true) {
      return;
    }
    try {
      await ref
          .read(appDataProvider.notifier)
          .upsertAppointment(
            appointment.copyWith(status: AppointmentStatus.cancelled),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appuntamento del $appointmentLabel annullato.'),
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Errore durante l\'annullamento. Riprova.'),
        ),
      );
    }
  }

  Future<void> _deleteAppointment(Appointment appointment) async {
    final format = DateFormat('dd MMMM yyyy HH:mm', 'it_IT');
    final appointmentLabel = format.format(appointment.start);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('Elimina appuntamento'),
          content: Text(
            'Vuoi eliminare definitivamente l\'appuntamento del $appointmentLabel?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(appDataProvider.notifier)
          .deleteAppointment(appointment.id);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Appuntamento del $appointmentLabel eliminato.'),
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      final message =
          error.code == 'permission-denied'
              ? 'Non hai i permessi per eliminare questo appuntamento.'
              : (error.message?.isNotEmpty == true
                  ? error.message!
                  : 'Errore durante l\'eliminazione. Riprova.');
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } on StateError catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Errore durante l\'eliminazione: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final session = ref.watch(sessionControllerProvider);
    final clients = data.clients;
    final selectedClient = clients.firstWhereOrNull(
      (client) => client.id == session.userId,
    );

    if (clients.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Area clienti'),
          actions: [
            IconButton(
              tooltip: 'Esci',
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Non è stato trovato alcun profilo cliente associato all\'account. Completa l\'onboarding oppure contatta il salone per essere invitato.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (selectedClient == null && clients.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sessionControllerProvider.notifier).setUser(clients.first.id);
        ref
            .read(sessionControllerProvider.notifier)
            .setSalon(clients.first.salonId);
      });
    }

    final currentClient = selectedClient ?? clients.first;
    final salon = data.salons.firstWhereOrNull(
      (salon) => salon.id == currentClient.salonId,
    );
    final appointments =
        data.appointments
            .where((appointment) => appointment.clientId == currentClient.id)
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final now = DateTime.now();
    final upcoming =
        appointments
            .where(
              (appointment) =>
                  appointment.start.isAfter(now) &&
                  appointment.status != AppointmentStatus.cancelled &&
                  appointment.status != AppointmentStatus.noShow,
            )
            .toList();
    final history =
        appointments
            .where(
              (appointment) =>
                  appointment.start.isBefore(now) ||
                  appointment.status == AppointmentStatus.cancelled ||
                  appointment.status == AppointmentStatus.noShow,
            )
            .toList();

    final salonServices =
        data.services
            .where((service) => service.salonId == currentClient.salonId)
            .toList();
    final clientPackages = resolveClientPackagePurchases(
      sales: data.sales,
      packages: data.packages,
      appointments: data.appointments,
      services: data.services,
      clientId: currentClient.id,
      salonId: currentClient.salonId,
    );
    final activePackages = clientPackages
        .where((pkg) => pkg.isActive)
        .toList(growable: false);
    final pastPackages = clientPackages
        .where((pkg) => !pkg.isActive)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Benvenuta ${currentClient.firstName}'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentClient.id,
              items:
                  clients
                      .map(
                        (client) => DropdownMenuItem(
                          value: client.id,
                          child: Text(client.fullName),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                final client = clients.firstWhereOrNull((c) => c.id == value);
                ref
                    .read(sessionControllerProvider.notifier)
                    .setUser(client?.id);
                ref
                    .read(sessionControllerProvider.notifier)
                    .setSalon(client?.salonId);
              },
            ),
          ),
          IconButton(
            tooltip: 'Esci',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (salon != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.apartment_rounded),
                title: Text(salon.name),
                subtitle: Text(
                  '${salon.address}, ${salon.city}\n${salon.phone}',
                ),
                trailing: const Icon(Icons.navigate_next_rounded),
                onTap: () {
                  // Dettaglio salone da implementare.
                },
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Prossimi appuntamenti',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (upcoming.isEmpty)
            const Card(
              child: ListTile(title: Text('Non hai appuntamenti futuri')),
            )
          else
            ...upcoming.map(
              (appointment) => _AppointmentCard(
                appointment: appointment,
                onReschedule:
                    () => _rescheduleAppointment(currentClient, appointment),
                onCancel: () => _cancelAppointment(appointment),
                onDelete: () => _deleteAppointment(appointment),
              ),
            ),
          const SizedBox(height: 24),
          Text('Storico', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (history.isEmpty)
            const Card(
              child: ListTile(
                title: Text(
                  'Lo storico sarà disponibile dopo il primo appuntamento',
                ),
              ),
            )
          else
            ...history
                .take(5)
                .map(
                  (appointment) => _AppointmentCard(appointment: appointment),
                ),
          const SizedBox(height: 24),
          Text(
            'Servizi disponibili',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (salonServices.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Nessun servizio configurato per questo salone'),
              ),
            )
          else
            _ServicesCarousel(
              services: salonServices,
              onBook:
                  (service) => _openBookingSheet(
                    currentClient,
                    preselectedService: service,
                  ),
            ),
          const SizedBox(height: 24),
          Text('Pacchetti', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (clientPackages.isEmpty)
            const Card(
              child: ListTile(
                title: Text(
                  'Non risultano pacchetti registrati per il cliente',
                ),
              ),
            )
          else
            _ClientPackagesSection(
              activePackages: activePackages,
              pastPackages: pastPackages,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBookingSheet(currentClient),
        icon: const Icon(Icons.calendar_month_rounded),
        label: const Text('Prenota ora'),
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  const _AppointmentCard({
    required this.appointment,
    this.onReschedule,
    this.onCancel,
    this.onDelete,
  });

  final Appointment appointment;
  final VoidCallback? onReschedule;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final staff = data.staff.firstWhereOrNull(
      (member) => member.id == appointment.staffId,
    );
    final service = data.services.firstWhereOrNull(
      (service) => service.id == appointment.serviceId,
    );
    final date = DateFormat(
      'dd/MM/yyyy HH:mm',
      'it_IT',
    ).format(appointment.start);
    final actionsAvailable =
        onReschedule != null || onCancel != null || onDelete != null;
    final statusChip = _statusChip(context, appointment.status);
    final trailing = statusChip;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.spa_rounded),
        title: Text(service?.name ?? 'Servizio'),
        subtitle: Text(
          '$date\nOperatore: ${staff?.fullName ?? 'Da assegnare'}',
        ),
        trailing: trailing,
        onTap: actionsAvailable ? () => _showActions(context) : null,
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

  void _showActions(BuildContext context) {
    if (onReschedule == null && onCancel == null && onDelete == null) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onReschedule != null)
                ListTile(
                  leading: const Icon(Icons.edit_calendar_rounded),
                  title: const Text('Modifica appuntamento'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onReschedule?.call();
                  },
                ),
              if (onCancel != null)
                ListTile(
                  leading: const Icon(Icons.event_busy_rounded),
                  title: const Text('Annulla appuntamento'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onCancel?.call();
                  },
                ),
              if (onDelete != null)
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Elimina appuntamento',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onDelete?.call();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ServicesCarousel extends StatelessWidget {
  const _ServicesCarousel({required this.services, required this.onBook});

  final List<Service> services;
  final ValueChanged<Service> onBook;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final service = services[index];
          return SizedBox(
            width: 220,
            child: Card(
              child: SizedBox(
                height: 260,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.description ?? 'Esperienza da provare',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text('${service.duration.inMinutes} minuti'),
                      const SizedBox(height: 4),
                      Text(
                        currency.format(service.price),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: () => onBook(service),
                          child: const Text('Prenota'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClientPackagesSection extends StatelessWidget {
  const _ClientPackagesSection({
    required this.activePackages,
    required this.pastPackages,
  });

  final List<ClientPackagePurchase> activePackages;
  final List<ClientPackagePurchase> pastPackages;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ClientPackageGroup(
          title: 'Pacchetti in corso',
          packages: activePackages,
        ),
        const SizedBox(height: 16),
        _ClientPackageGroup(title: 'Pacchetti passati', packages: pastPackages),
      ],
    );
  }
}

class _ClientPackageGroup extends StatelessWidget {
  const _ClientPackageGroup({required this.title, required this.packages});

  final String title;
  final List<ClientPackagePurchase> packages;

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
            if (packages.isEmpty)
              Text(
                title.contains('corso')
                    ? 'Nessun pacchetto attivo al momento.'
                    : 'Non risultano pacchetti passati.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...packages.map((purchase) {
                final expiry = purchase.expirationDate;
                final servicesLabel = purchase.serviceNames.join(', ');
                final statusChip = _packageStatusChip(context, purchase.status);
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
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              statusChip,
                              const SizedBox(height: 8),
                              Text(
                                currency.format(purchase.totalAmount),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(purchase.paymentStatus.label),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _ClientInfoChip(
                            icon: Icons.event_repeat_rounded,
                            label: _sessionLabel(purchase),
                          ),
                          _ClientInfoChip(
                            icon: Icons.calendar_today_rounded,
                            label:
                                'Acquisto: ${dateFormat.format(purchase.sale.createdAt)}',
                          ),
                          _ClientInfoChip(
                            icon: Icons.timer_outlined,
                            label:
                                expiry == null
                                    ? 'Senza scadenza'
                                    : 'Scadenza: ${dateFormat.format(expiry)}',
                          ),
                          if (purchase.depositAmount > 0)
                            _ClientInfoChip(
                              icon: Icons.savings_rounded,
                              label:
                                  'Acconto: ${currency.format(purchase.depositAmount)}',
                            ),
                          if (purchase.outstandingAmount > 0)
                            _ClientInfoChip(
                              icon: Icons.pending_actions_rounded,
                              label:
                                  'Da saldare: ${currency.format(purchase.outstandingAmount)}',
                            ),
                        ],
                      ),
                      if (servicesLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Servizi inclusi: $servicesLabel'),
                      ],
                      if (purchase.deposits.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Acconti registrati',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Column(
                          children:
                              purchase.deposits.map((deposit) {
                                final subtitleBuffer = StringBuffer(
                                  '${DateFormat('dd/MM/yyyy HH:mm').format(deposit.date)} • ${_paymentMethodLabel(deposit.paymentMethod)}',
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
                                  leading: const Icon(
                                    Icons.receipt_long_rounded,
                                  ),
                                  title: Text(currency.format(deposit.amount)),
                                  subtitle: Text(subtitleBuffer.toString()),
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

  static String _paymentMethodLabel(PaymentMethod method) {
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

  static Widget _packageStatusChip(
    BuildContext context,
    PackagePurchaseStatus status,
  ) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case PackagePurchaseStatus.active:
        return Chip(
          label: Text(status.label),
          backgroundColor: scheme.primaryContainer,
        );
      case PackagePurchaseStatus.completed:
        return Chip(
          label: Text(status.label),
          backgroundColor: scheme.secondaryContainer,
        );
      case PackagePurchaseStatus.cancelled:
        return Chip(
          label: Text(status.label),
          backgroundColor: scheme.errorContainer,
        );
    }
  }
}

class _ClientInfoChip extends StatelessWidget {
  const _ClientInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}
