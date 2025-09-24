import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/salon_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SalonManagementModule extends ConsumerWidget {
  const SalonManagementModule({super.key, this.selectedSalonId});

  final String? selectedSalonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final theme = Theme.of(context);
    final salons = data.salons;

    if (salons.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nessun salone configurato',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Crea salone'),
            ),
          ],
        ),
      );
    }

    final selected =
        selectedSalonId == null
            ? salons
            : salons.where((salon) => salon.id == selectedSalonId).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: selected.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Nuovo salone'),
            ),
          );
        }
        final salon = selected[index - 1];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  salon.name,
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(status: salon.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${salon.address}, ${salon.city}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone, size: 18),
                                  const SizedBox(width: 4),
                                  Text(salon.phone),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.email, size: 18),
                                  const SizedBox(width: 4),
                                  Text(salon.email),
                                ],
                              ),
                              if (salon.postalCode != null &&
                                  salon.postalCode!.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.local_post_office_rounded,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text('CAP ${salon.postalCode}'),
                                  ],
                                ),
                              if (salon.bookingLink != null &&
                                  salon.bookingLink!.isNotEmpty)
                                Tooltip(
                                  message: salon.bookingLink!,
                                  child: Chip(
                                    avatar: const Icon(Icons.link, size: 18),
                                    label: const Text('Prenotazioni online'),
                                  ),
                                ),
                              if (salon.latitude != null &&
                                  salon.longitude != null)
                                Chip(
                                  avatar: const Icon(
                                    Icons.location_on_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    '${salon.latitude!.toStringAsFixed(4)}, ${salon.longitude!.toStringAsFixed(4)}',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Modifica salone',
                      onPressed: () => _openForm(context, ref, existing: salon),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                  ],
                ),
                if (salon.description != null) ...[
                  const SizedBox(height: 12),
                  Text(salon.description!),
                ],
                const SizedBox(height: 16),
                _SalonStats(salon: salon),
                const SizedBox(height: 12),
                _EquipmentList(equipment: salon.equipment),
                if (salon.closures.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ClosuresList(closures: salon.closures),
                ],
                const SizedBox(height: 12),
                _RoomsList(rooms: salon.rooms),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SalonStats extends ConsumerWidget {
  const _SalonStats({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final staffCount =
        data.staff.where((member) => member.salonId == salon.id).length;
    final clientsCount =
        data.clients.where((client) => client.salonId == salon.id).length;
    final upcomingAppointments =
        data.appointments
            .where(
              (appointment) =>
                  appointment.salonId == salon.id &&
                  appointment.start.isAfter(DateTime.now()),
            )
            .length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _InfoChip(
          icon: Icons.groups,
          label: 'Staff',
          value: staffCount.toString(),
        ),
        _InfoChip(
          icon: Icons.people_alt,
          label: 'Clienti',
          value: clientsCount.toString(),
        ),
        _InfoChip(
          icon: Icons.event_available,
          label: 'Appuntamenti',
          value: upcomingAppointments.toString(),
        ),
      ],
    );
  }
}

class _RoomsList extends StatelessWidget {
  const _RoomsList({required this.rooms});

  final List<SalonRoom> rooms;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) {
      return Text(
        'Nessuna cabina configurata',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cabine e stanze', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              rooms
                  .map(
                    (room) => Chip(
                      avatar: const Icon(
                        Icons.door_front_door_rounded,
                        size: 18,
                      ),
                      label: Text('${room.name} · Capienza ${room.capacity}'),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }
}

class _EquipmentList extends StatelessWidget {
  const _EquipmentList({required this.equipment});

  final List<SalonEquipment> equipment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (equipment.isEmpty) {
      return Text(
        'Nessun macchinario configurato',
        style: theme.textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Macchinari', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              equipment.map((item) {
                final chip = Chip(
                  avatar: Icon(
                    Icons.precision_manufacturing_rounded,
                    size: 18,
                    color: _equipmentStatusColor(context, item.status),
                  ),
                  label: Text(
                    '${item.name} · ${item.quantity}x · ${item.status.label}',
                  ),
                  backgroundColor: _equipmentStatusColor(
                    context,
                    item.status,
                  ).withOpacity(0.12),
                  side: BorderSide(
                    color: _equipmentStatusColor(
                      context,
                      item.status,
                    ).withOpacity(0.35),
                  ),
                );
                if (item.notes != null && item.notes!.isNotEmpty) {
                  return Tooltip(message: item.notes!, child: chip);
                }
                return chip;
              }).toList(),
        ),
      ],
    );
  }
}

class _ClosuresList extends StatelessWidget {
  const _ClosuresList({required this.closures});

  final List<SalonClosure> closures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('dd MMM yyyy', 'it');
    final sorted =
        closures.toList()..sort((a, b) => a.start.compareTo(b.start));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chiusure programmate', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...sorted.map((closure) {
          final range =
              closure.isSingleDay
                  ? formatter.format(closure.start)
                  : '${formatter.format(closure.start)} → ${formatter.format(closure.end)}';
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy_rounded),
            title: Text(range),
            subtitle:
                closure.reason != null && closure.reason!.isNotEmpty
                    ? Text(closure.reason!)
                    : null,
          );
        }),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SalonStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, status);
    return Chip(
      avatar: Icon(_statusIcon(status), size: 18, color: color),
      label: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      side: BorderSide(color: color.withOpacity(0.35)),
      backgroundColor: color.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      avatar: Icon(icon, size: 18),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

Color _statusColor(BuildContext context, SalonStatus status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case SalonStatus.active:
      return scheme.primary;
    case SalonStatus.suspended:
      return scheme.tertiary;
    case SalonStatus.archived:
      return scheme.outline;
  }
}

IconData _statusIcon(SalonStatus status) {
  switch (status) {
    case SalonStatus.active:
      return Icons.check_circle_rounded;
    case SalonStatus.suspended:
      return Icons.pause_circle_filled_rounded;
    case SalonStatus.archived:
      return Icons.inventory_2_rounded;
  }
}

Color _equipmentStatusColor(BuildContext context, SalonEquipmentStatus status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case SalonEquipmentStatus.operational:
      return scheme.primary;
    case SalonEquipmentStatus.maintenance:
      return scheme.tertiary;
    case SalonEquipmentStatus.outOfOrder:
      return scheme.error;
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  Salon? existing,
}) async {
  final result = await showAppModalSheet<Salon>(
    context: context,
    builder: (ctx) => SalonFormSheet(initial: existing),
  );
  if (result != null) {
    await ref.read(appDataProvider.notifier).upsertSalon(result);
  }
}
