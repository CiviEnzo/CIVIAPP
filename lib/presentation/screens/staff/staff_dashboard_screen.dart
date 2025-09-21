import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/inventory_item.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  ConsumerState<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final session = ref.watch(sessionControllerProvider);
    final staffMembers = data.staff;
    StaffMember? selectedStaff = staffMembers.firstWhereOrNull((member) => member.id == session.userId);

    if (selectedStaff == null && staffMembers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sessionControllerProvider.notifier).setUser(staffMembers.first.id);
        ref.read(sessionControllerProvider.notifier).setSalon(staffMembers.first.salonId);
      });
      selectedStaff = staffMembers.first;
    }

    final relatedAppointments = data.appointments
        .where((appointment) => appointment.staffId == selectedStaff?.id)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final today = DateTime.now();
    final todayAppointments = relatedAppointments
        .where((appointment) => appointment.start.year == today.year && appointment.start.month == today.month && appointment.start.day == today.day)
        .toList();
    final upcoming = relatedAppointments.where((appointment) => appointment.start.isAfter(DateTime.now())).toList();

    final lowInventory = data.inventoryItems
        .where((item) => item.salonId == selectedStaff?.salonId && item.quantity <= item.threshold)
        .toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Ciao ${selectedStaff?.fullName.split(' ').first ?? 'Staff'}'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Oggi'),
              Tab(text: 'Agenda'),
              Tab(text: 'Magazzino'),
            ],
          ),
          actions: [
            if (staffMembers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedStaff?.id,
                    items: staffMembers
                        .map(
                          (member) => DropdownMenuItem(
                            value: member.id,
                            child: Text(member.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final member = staffMembers.firstWhereOrNull((m) => m.id == value);
                      ref.read(sessionControllerProvider.notifier).setUser(member?.id);
                      ref.read(sessionControllerProvider.notifier).setSalon(member?.salonId);
                    },
                  ),
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
        body: TabBarView(
          children: [
            _TodayView(appointments: todayAppointments, allAppointments: relatedAppointments),
            _AgendaView(appointments: upcoming),
            _InventoryView(items: lowInventory),
          ],
        ),
      ),
    );
  }
}

class _TodayView extends ConsumerWidget {
  const _TodayView({required this.appointments, required this.allAppointments});

  final List<Appointment> appointments;
  final List<Appointment> allAppointments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');

    final expectedRevenue = appointments.fold<double>(
      0,
      (total, appointment) {
        final service = data.services.firstWhereOrNull((service) => service.id == appointment.serviceId);
        return total + (service?.price ?? 0);
      },
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
              _TodayCard(
                icon: Icons.event_available_rounded,
                title: 'Appuntamenti di oggi',
                value: '${appointments.length}',
              ),
              _TodayCard(
                icon: Icons.access_time_rounded,
                title: 'Totale ore lavoro',
                value: _formatDuration(appointments.fold<Duration>(Duration.zero, (total, appointment) => total + appointment.end.difference(appointment.start))),
              ),
              _TodayCard(
                icon: Icons.euro_rounded,
                title: 'Valore stimato',
                value: currency.format(expectedRevenue),
              ),
              _TodayCard(
                icon: Icons.calendar_month_rounded,
                title: 'Agenda totale',
                value: '${allAppointments.length}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Dettaglio appuntamenti', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (appointments.isEmpty)
            const Card(child: ListTile(title: Text('Nessun appuntamento oggi')))
          else
            ...appointments.map((appointment) {
              final client = data.clients.firstWhereOrNull((client) => client.id == appointment.clientId);
              final service = data.services.firstWhereOrNull((service) => service.id == appointment.serviceId);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(client?.firstName.characters.firstOrNull?.toUpperCase() ?? '?')),
                  title: Text(client?.fullName ?? 'Cliente'),
                  subtitle: Text('${service?.name ?? 'Servizio'} · ${DateFormat('HH:mm').format(appointment.start)}'),
                  trailing: const Icon(Icons.navigate_next_rounded),
                  onTap: () {},
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inMinutes / 60;
    return '${hours.toStringAsFixed(1)} h';
  }
}

class _AgendaView extends ConsumerWidget {
  const _AgendaView({required this.appointments});

  final List<Appointment> appointments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    if (appointments.isEmpty) {
      return const Center(child: Text('Nessun appuntamento futuro'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        final client = data.clients.firstWhereOrNull((client) => client.id == appointment.clientId);
        final service = data.services.firstWhereOrNull((service) => service.id == appointment.serviceId);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_month_rounded),
            title: Text(service?.name ?? 'Servizio'),
            subtitle: Text('${client?.fullName ?? 'Cliente'} · ${DateFormat('dd/MM HH:mm').format(appointment.start)}'),
            trailing: _statusChip(appointment.status, context),
          ),
        );
      },
    );
  }

  Widget _statusChip(AppointmentStatus status, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case AppointmentStatus.scheduled:
        return Chip(label: const Text('Programmato'), backgroundColor: scheme.primaryContainer);
      case AppointmentStatus.confirmed:
        return Chip(label: const Text('Confermato'), backgroundColor: scheme.secondaryContainer);
      case AppointmentStatus.completed:
        return Chip(label: const Text('Completato'), backgroundColor: scheme.tertiaryContainer);
      case AppointmentStatus.cancelled:
        return Chip(label: const Text('Annullato'), backgroundColor: scheme.errorContainer);
      case AppointmentStatus.noShow:
        return Chip(label: const Text('No show'), backgroundColor: scheme.error.withValues(alpha: 0.1));
    }
  }
}

class _InventoryView extends StatelessWidget {
  const _InventoryView({required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Nessun articolo sotto soglia'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2_rounded),
            title: Text(item.name),
            subtitle: Text('Disponibili ${item.quantity.toStringAsFixed(0)} ${item.unit} · Soglia ${item.threshold.toStringAsFixed(0)}'),
            trailing: TextButton(onPressed: () {}, child: const Text('Richiedi')), 
          ),
        );
      },
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

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
            ],
          ),
        ),
      ),
    );
  }
}
