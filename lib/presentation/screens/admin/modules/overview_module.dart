import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AdminOverviewModule extends ConsumerWidget {
  const AdminOverviewModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final theme = Theme.of(context);

    final appointments =
        data.appointments
            .where(
              (appointment) =>
                  salonId == null || appointment.salonId == salonId,
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final upcoming =
        appointments
            .where((a) => a.start.isAfter(DateTime.now()))
            .take(6)
            .toList();

    final staff =
        data.staff
            .where((item) => salonId == null || item.salonId == salonId)
            .toList();
    final clients =
        data.clients
            .where((item) => salonId == null || item.salonId == salonId)
            .toList();
    final services =
        data.services
            .where((item) => salonId == null || item.salonId == salonId)
            .toList();
    final packages =
        data.packages
            .where((item) => salonId == null || item.salonId == salonId)
            .toList();
    final sales =
        data.sales
            .where((item) => salonId == null || item.salonId == salonId)
            .toList();

    final today = DateTime.now();
    final todayRevenue = sales
        .where(
          (sale) =>
              sale.createdAt.year == today.year &&
              sale.createdAt.month == today.month &&
              sale.createdAt.day == today.day,
        )
        .fold<double>(0, (total, sale) => total + sale.total);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(
                title: 'Appuntamenti',
                value: appointments.length.toString(),
                subtitle: 'Totale pianificati',
                icon: Icons.event_available_rounded,
                accentColor: theme.colorScheme.primary,
              ),
              _MetricCard(
                title: 'Staff attivo',
                value: staff.length.toString(),
                subtitle: 'Operatori per salone',
                icon: Icons.groups_2_rounded,
                accentColor: theme.colorScheme.tertiary,
              ),
              _MetricCard(
                title: 'Clienti',
                value: clients.length.toString(),
                subtitle: 'Anagrafiche registrate',
                icon: Icons.people_alt_rounded,
                accentColor: theme.colorScheme.secondary,
              ),
              _MetricCard(
                title: 'Incasso oggi',
                value: NumberFormat.simpleCurrency(
                  locale: 'it_IT',
                ).format(todayRevenue),
                subtitle: 'Vendite registrate',
                icon: Icons.point_of_sale_rounded,
                accentColor: theme.colorScheme.error,
              ),
              _MetricCard(
                title: 'Servizi',
                value: services.length.toString(),
                subtitle: 'Catalogo trattamenti',
                icon: Icons.spa_rounded,
                accentColor: theme.colorScheme.primary,
              ),
              _MetricCard(
                title: 'Pacchetti',
                value: packages.length.toString(),
                subtitle: 'Offerte attive',
                icon: Icons.card_giftcard_rounded,
                accentColor: theme.colorScheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (upcoming.isNotEmpty) ...[
            Text('Prossimi appuntamenti', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final appointment = upcoming[index];
                  final client = data.clients.firstWhereOrNull(
                    (c) => c.id == appointment.clientId,
                  );
                  final services =
                      appointment.serviceIds
                          .map(
                            (id) => data.services.firstWhereOrNull(
                              (service) => service.id == id,
                            ),
                          )
                          .whereType<Service>()
                          .toList();
                  final staffMember = data.staff.firstWhereOrNull(
                    (s) => s.id == appointment.staffId,
                  );
                  final date = DateFormat(
                    'EEEE dd MMMM HH:mm',
                    'it_IT',
                  ).format(appointment.start);
                  final serviceLabel =
                      services.isNotEmpty
                          ? services.map((service) => service.name).join(' + ')
                          : 'Servizio';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      child: Text(
                        client?.firstName.characters.firstOrNull
                                ?.toUpperCase() ??
                            '?',
                      ),
                    ),
                    title: Text(
                      '${client?.fullName ?? 'Cliente'} • $serviceLabel',
                    ),
                    subtitle: Text(
                      '$date • ${staffMember?.fullName ?? 'Staff'}',
                    ),
                    trailing: _statusChip(appointment.status, theme),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: upcoming.length,
              ),
            ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Nessun appuntamento imminente',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(AppointmentStatus status, ThemeData theme) {
    Color background;
    Color foreground;
    String label;
    switch (status) {
      case AppointmentStatus.scheduled:
        background = theme.colorScheme.primaryContainer;
        foreground = theme.colorScheme.onPrimaryContainer;
        label = 'Programmato';
        break;
      case AppointmentStatus.confirmed:
        background = theme.colorScheme.secondaryContainer;
        foreground = theme.colorScheme.onSecondaryContainer;
        label = 'Confermato';
        break;
      case AppointmentStatus.completed:
        background = theme.colorScheme.tertiaryContainer;
        foreground = theme.colorScheme.onTertiaryContainer;
        label = 'Completato';
        break;
      case AppointmentStatus.cancelled:
        background = theme.colorScheme.errorContainer;
        foreground = theme.colorScheme.onErrorContainer;
        label = 'Annullato';
        break;
      case AppointmentStatus.noShow:
        background = theme.colorScheme.error.withValues(alpha: 0.2);
        foreground = theme.colorScheme.error;
        label = 'No show';
        break;
    }

    return Chip(
      label: Text(label),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.accentColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveAccent = accentColor ?? theme.colorScheme.primary;
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: effectiveAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: effectiveAccent, size: 24),
              ),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
