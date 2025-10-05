import 'dart:async';
import 'dart:io';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/app_notification.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/client.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/presentation/shared/client_package_purchase.dart';
import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  StreamSubscription<RemoteMessage>? _foregroundSub;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTab = 0;

  int _resolveLoyaltyValue(int? stored, int aggregated) {
    if (stored == null) {
      return aggregated;
    }
    if (stored == 0 && aggregated != 0) {
      return aggregated;
    }
    return stored;
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

  _LoyaltyStats _calculateLoyaltyStats(Client client, List<Sale> sales) {
    final aggregatedEarned = sales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.resolvedEarnedPoints,
    );
    final aggregatedRedeemed = sales.fold<int>(
      0,
      (sum, sale) => sum + sale.loyalty.redeemedPoints,
    );
    final initialPoints = client.loyaltyInitialPoints;
    final totalEarned = _resolveLoyaltyValue(
      client.loyaltyTotalEarned,
      aggregatedEarned,
    );
    final totalRedeemed = _resolveLoyaltyValue(
      client.loyaltyTotalRedeemed,
      aggregatedRedeemed,
    );
    final computedSpendable = initialPoints + totalEarned - totalRedeemed;
    final spendable = _resolveSpendableBalance(
      stored: client.loyaltyPoints,
      computed: computedSpendable,
    );

    return _LoyaltyStats(
      initialPoints: initialPoints,
      totalEarned: totalEarned,
      totalRedeemed: totalRedeemed,
      spendable: spendable,
    );
  }

  @override
  void initState() {
    super.initState();
    _listenForegroundMessages();
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    super.dispose();
  }

  void _listenForegroundMessages() {
    _foregroundSub ??= FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      if (!mounted) {
        return;
      }
      final notification = message.notification;
      final title =
          notification?.title ??
          message.data['title'] as String? ??
          'Nuova notifica';
      final body = notification?.body ?? message.data['body'] as String? ?? '';
      final content = body.isEmpty ? title : '$title\n$body';
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(content), behavior: SnackBarBehavior.floating),
      );
    });
  }

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
            .where(
              (service) =>
                  service.salonId == currentClient.salonId && service.isActive,
            )
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
    final notifications =
        data.clientNotifications
            .where((notification) => notification.clientId == currentClient.id)
            .toList()
          ..sort(
            (a, b) => (b.sentAt ?? b.scheduledAt ?? b.createdAt).compareTo(
              a.sentAt ?? a.scheduledAt ?? a.createdAt,
            ),
          );
    final clientSales =
        data.sales.where((sale) => sale.clientId == currentClient.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final outstandingSales =
        clientSales.where((sale) => sale.outstandingAmount > 0.01).toList();
    final outstandingTotal = outstandingSales.fold<double>(
      0,
      (sum, sale) => sum + sale.outstandingAmount,
    );

    final tabViews = <Widget>[
      _buildHomeTab(
        context: context,
        client: currentClient,
        salon: salon,
        notifications: notifications,
        upcoming: upcoming,
        history: history,
        services: salonServices,
        activePackages: activePackages,
        pastPackages: pastPackages,
        sales: clientSales,
      ),
      _buildAppointmentsTab(
        context: context,
        client: currentClient,
        upcoming: upcoming,
        history: history,
      ),
      _buildLoyaltyTab(
        context: context,
        client: currentClient,
        sales: clientSales,
      ),
      _buildBillingTab(
        context: context,
        client: currentClient,
        sales: clientSales,
        outstandingSales: outstandingSales,
        outstandingTotal: outstandingTotal,
        activePackages: activePackages,
        pastPackages: pastPackages,
      ),
    ];

    Widget? floatingActionButton;
    if (_currentTab <= 1) {
      floatingActionButton = FloatingActionButton.extended(
        onPressed: () => _openBookingSheet(currentClient),
        icon: const Icon(Icons.calendar_month_rounded),
        label: const Text('Prenota ora'),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Menu',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu_rounded),
        ),
        title: Text('Ciao ${currentClient.firstName}'),
        actions: [
          if (clients.length > 1)
            PopupMenuButton<Client>(
              tooltip: 'Cambia cliente',
              icon: const Icon(Icons.switch_account_rounded),
              itemBuilder:
                  (context) =>
                      clients
                          .map(
                            (client) => PopupMenuItem<Client>(
                              value: client,
                              child: Text(client.fullName),
                            ),
                          )
                          .toList(),
              onSelected: (client) {
                ref.read(sessionControllerProvider.notifier).setUser(client.id);
                ref
                    .read(sessionControllerProvider.notifier)
                    .setSalon(client.salonId);
              },
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
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(currentClient.fullName),
                accountEmail: Text(salon?.name ?? 'Salone non configurato'),
                currentAccountPicture: const CircleAvatar(
                  child: Icon(Icons.person_rounded),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_rounded),
                title: const Text('Notifiche'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showNotificationsSheet(context, notifications);
                },
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard_rounded),
                title: const Text('Pacchetti'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showPackagesSheet(context, activePackages, pastPackages);
                },
              ),
              ListTile(
                leading: const Icon(Icons.design_services_rounded),
                title: const Text('Servizi'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showServicesSheet(context, salonServices);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Impostazioni (presto disponibili)'),
                onTap: () => Navigator.of(context).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Esci'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(authRepositoryProvider).signOut();
                },
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(index: _currentTab, children: tabViews),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Appuntamenti',
          ),
          NavigationDestination(
            icon: Icon(Icons.loyalty_outlined),
            selectedIcon: Icon(Icons.loyalty_rounded),
            label: 'Punti',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Fatturazione',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab({
    required BuildContext context,
    required Client client,
    required Salon? salon,
    required List<AppNotification> notifications,
    required List<Appointment> upcoming,
    required List<Appointment> history,
    required List<Service> services,
    required List<ClientPackagePurchase> activePackages,
    required List<ClientPackagePurchase> pastPackages,
    required List<Sale> sales,
  }) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final nextAppointment = upcoming.isEmpty ? null : upcoming.first;
    final loyaltyStats = _calculateLoyaltyStats(client, sales);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PushTokenRegistrar(clientId: client.id),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.fullName, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  salon == null
                      ? 'Salone non configurato'
                      : '${salon.name}\n${salon.address}, ${salon.city}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _SummaryChip(
                      icon: Icons.loyalty_rounded,
                      label: 'Saldo utilizzabile',
                      value: loyaltyStats.spendable.toString(),
                    ),
                    _SummaryChip(
                      icon: Icons.euro_rounded,
                      label: 'Totale speso',
                      value: currency.format(
                        sales.fold<double>(0, (sum, sale) => sum + sale.total),
                      ),
                    ),
                    _SummaryChip(
                      icon: Icons.event_available_rounded,
                      label: 'Prossimo appuntamento',
                      value:
                          nextAppointment == null
                              ? '—'
                              : DateFormat(
                                'dd MMM • HH:mm',
                                'it_IT',
                              ).format(nextAppointment.start),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (notifications.isNotEmpty) ...[
          Text('Ultime notifiche', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          ...notifications
              .take(3)
              .map(
                (notification) => _NotificationCard(notification: notification),
              ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showNotificationsSheet(context, notifications),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Mostra tutte'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (upcoming.isNotEmpty) ...[
          Text('Appuntamenti imminenti', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          _AppointmentCard(
            appointment: upcoming.first,
            onReschedule: () => _rescheduleAppointment(client, upcoming.first),
            onCancel: () => _cancelAppointment(upcoming.first),
            onDelete: () => _deleteAppointment(upcoming.first),
          ),
          if (upcoming.length > 1)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _currentTab = 1),
                icon: const Icon(Icons.calendar_today_rounded),
                label: const Text('Vedi tutti'),
              ),
            ),
          const SizedBox(height: 16),
        ] else ...[
          const Card(
            child: ListTile(title: Text('Non hai appuntamenti futuri')),
          ),
          const SizedBox(height: 16),
        ],
        Text('Servizi consigliati', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (services.isEmpty)
          const Card(
            child: ListTile(
              title: Text('Nessun servizio configurato per questo salone'),
            ),
          )
        else
          _ServicesCarousel(
            services: services,
            onBook:
                (service) =>
                    _openBookingSheet(client, preselectedService: service),
          ),
        const SizedBox(height: 16),
        Text('Pacchetti', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (activePackages.isEmpty && pastPackages.isEmpty)
          const Card(
            child: ListTile(title: Text('Non risultano pacchetti registrati')),
          )
        else
          _ClientPackagesSection(
            activePackages: activePackages,
            pastPackages: pastPackages,
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAppointmentsTab({
    required BuildContext context,
    required Client client,
    required List<Appointment> upcoming,
    required List<Appointment> history,
  }) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Agenda', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (upcoming.isEmpty)
          const Card(
            child: ListTile(title: Text('Non hai appuntamenti futuri')),
          )
        else
          ...upcoming.map(
            (appointment) => _AppointmentCard(
              appointment: appointment,
              onReschedule: () => _rescheduleAppointment(client, appointment),
              onCancel: () => _cancelAppointment(appointment),
              onDelete: () => _deleteAppointment(appointment),
            ),
          ),
        const SizedBox(height: 24),
        Text('Storico', style: theme.textTheme.titleLarge),
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
          ...history.map(
            (appointment) => _AppointmentCard(appointment: appointment),
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _openBookingSheet(client),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Prenota un nuovo appuntamento'),
        ),
      ],
    );
  }

  Widget _buildLoyaltyTab({
    required BuildContext context,
    required Client client,
    required List<Sale> sales,
  }) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final loyaltySales =
        sales
            .where(
              (sale) =>
                  sale.loyalty.resolvedEarnedPoints > 0 ||
                  sale.loyalty.redeemedPoints > 0,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final loyaltyStats = _calculateLoyaltyStats(client, sales);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo utilizzabile', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  '${loyaltyStats.spendable} pt',
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    text: 'Punti iniziali: ',
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${loyaltyStats.initialPoints} pt',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: 'Punti accumulati: ',
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${loyaltyStats.totalEarned} pt',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: 'Punti utilizzati: ',
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${loyaltyStats.totalRedeemed} pt',
                        style: (theme.textTheme.titleMedium ??
                                const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ))
                            .copyWith(
                              color:
                                  loyaltyStats.totalRedeemed > 0
                                      ? theme.colorScheme.error
                                      : null,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Movimenti recenti', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (loyaltySales.isEmpty)
          const Card(
            child: ListTile(title: Text('Non ci sono movimenti registrati.')),
          )
        else
          ...loyaltySales.map((sale) {
            final date = DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt);
            final summary = sale.loyalty;
            final net = summary.netPoints;
            final icon =
                net >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded;
            final color =
                net >= 0 ? theme.colorScheme.primary : theme.colorScheme.error;
            return Card(
              child: ListTile(
                leading: Icon(icon, color: color),
                title: Text('Vendita del $date'),
                subtitle: Text(
                  'Assegnati: ${summary.resolvedEarnedPoints} • Usati: ${summary.redeemedPoints}\nValore sconto: ${currency.format(summary.redeemedValue)}',
                ),
                trailing: Text(
                  net >= 0 ? '+$net pt' : '$net pt',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBillingTab({
    required BuildContext context,
    required Client client,
    required List<Sale> sales,
    required List<Sale> outstandingSales,
    required double outstandingTotal,
    required List<ClientPackagePurchase> activePackages,
    required List<ClientPackagePurchase> pastPackages,
  }) {
    final theme = Theme.of(context);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final totalPaid = sales.fold<double>(
      0,
      (sum, sale) => sum + sale.paidAmount,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Riepilogo fatture', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('Incassato: ${currency.format(totalPaid)}'),
                Text('Da saldare: ${currency.format(outstandingTotal)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Vendite recenti', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (sales.isEmpty)
          const Card(
            child: ListTile(title: Text('Non risultano vendite registrate')),
          )
        else
          ...sales.map((sale) {
            final date = DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt);
            final subtitle =
                sale.loyalty.redeemedPoints > 0
                    ? 'Totale: ${currency.format(sale.total)} • Punti usati: ${sale.loyalty.redeemedPoints}'
                    : 'Totale: ${currency.format(sale.total)}';
            final outstanding = sale.outstandingAmount;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: Text('Vendita del $date'),
                subtitle: Text(subtitle),
                trailing:
                    outstanding > 0
                        ? Text(
                          'Da saldare\n${currency.format(outstanding)}',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        )
                        : Text(
                          currency.format(sale.total),
                          style: theme.textTheme.titleMedium,
                        ),
              ),
            );
          }),
        if (outstandingSales.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Pagamenti da completare', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          ...outstandingSales.map((sale) {
            final date = DateFormat('dd/MM/yyyy HH:mm').format(sale.createdAt);
            return Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text('Vendita del $date'),
                subtitle: Text(
                  'Residuo ${currency.format(sale.outstandingAmount)}',
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  void _showNotificationsSheet(
    BuildContext context,
    List<AppNotification> notifications,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        if (notifications.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Non ci sono notifiche recenti.'),
            ),
          );
        }
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder:
                (ctx, index) =>
                    _NotificationCard(notification: notifications[index]),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: notifications.length,
          ),
        );
      },
    );
  }

  void _showPackagesSheet(
    BuildContext context,
    List<ClientPackagePurchase> active,
    List<ClientPackagePurchase> past,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _ClientPackagesSection(
              activePackages: active,
              pastPackages: past,
            ),
          ),
        );
      },
    );
  }

  void _showServicesSheet(BuildContext context, List<Service> services) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        if (services.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nessun servizio configurato.'),
            ),
          );
        }
        final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (ctx, index) {
              final service = services[index];
              return ListTile(
                leading: const Icon(Icons.design_services_rounded),
                title: Text(service.name),
                subtitle: Text(currency.format(service.price)),
              );
            },
            separatorBuilder: (_, __) => const Divider(),
            itemCount: services.length,
          ),
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
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
    return Chip(
      avatar: Icon(icon, size: 18, color: theme.colorScheme.primary),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _PushTokenRegistrar extends ConsumerStatefulWidget {
  const _PushTokenRegistrar({required this.clientId});

  final String clientId;

  @override
  ConsumerState<_PushTokenRegistrar> createState() =>
      _PushTokenRegistrarState();
}

class _PushTokenRegistrarState extends ConsumerState<_PushTokenRegistrar> {
  StreamSubscription<String>? _subscription;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ensureRegistered();
  }

  Future<void> _ensureRegistered() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    final messaging = ref.read(firebaseMessagingProvider);
    try {
      await messaging.setAutoInitEnabled(true);
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final token = await messaging.getToken();
      if (token != null) {
        await ref
            .read(appDataProvider.notifier)
            .registerClientPushToken(clientId: widget.clientId, token: token);
      }

      _subscription = messaging.onTokenRefresh.listen((freshToken) async {
        await ref
            .read(appDataProvider.notifier)
            .registerClientPushToken(
              clientId: widget.clientId,
              token: freshToken,
            );
      });
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'ClientDashboardScreen',
          informationCollector:
              () => [DiagnosticsNode.message('Failed to register FCM token')],
        ),
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'it_IT');
    final referenceDate =
        notification.sentAt ??
        notification.scheduledAt ??
        notification.createdAt;
    final title = notification.title ?? 'Notifica';
    final body =
        notification.body ?? (notification.payload['body'] as String? ?? '');
    final statusLabel = _statusLabel(notification.status);
    final colors = _statusColors(theme, notification.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: colors.background,
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
            if (body.isNotEmpty) ...[const SizedBox(height: 8), Text(body)],
            const SizedBox(height: 8),
            Text(
              'Aggiornata il ${dateFormat.format(referenceDate)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'sent':
        return 'Inviata';
      case 'queued':
        return 'In coda';
      case 'failed':
        return 'Errore';
      case 'skipped':
        return 'Saltata';
      case 'pending':
      default:
        return 'Programmato';
    }
  }

  ({Color background, Color foreground}) _statusColors(
    ThemeData theme,
    String status,
  ) {
    switch (status) {
      case 'sent':
        return (
          background: theme.colorScheme.secondaryContainer,
          foreground: theme.colorScheme.onSecondaryContainer,
        );
      case 'failed':
        return (
          background: theme.colorScheme.errorContainer,
          foreground: theme.colorScheme.onErrorContainer,
        );
      case 'skipped':
        return (
          background: theme.colorScheme.surfaceVariant,
          foreground: theme.colorScheme.onSurfaceVariant,
        );
      case 'queued':
        return (
          background: theme.colorScheme.tertiaryContainer,
          foreground: theme.colorScheme.onTertiaryContainer,
        );
      case 'pending':
      default:
        return (
          background: theme.colorScheme.surfaceContainerHighest,
          foreground: theme.colorScheme.onSurface,
        );
    }
  }
}

class _LoyaltyStats {
  const _LoyaltyStats({
    required this.initialPoints,
    required this.totalEarned,
    required this.totalRedeemed,
    required this.spendable,
  });

  final int initialPoints;
  final int totalEarned;
  final int totalRedeemed;
  final int spendable;
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
    final services =
        appointment.serviceIds
            .map(
              (id) =>
                  data.services.firstWhereOrNull((service) => service.id == id),
            )
            .whereType<Service>()
            .toList();
    final serviceLabel =
        services.isNotEmpty
            ? services.map((service) => service.name).join(' + ')
            : 'Servizio';
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
        title: Text(serviceLabel),
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
