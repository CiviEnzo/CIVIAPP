import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/appointment.dart';
import 'package:civiapp/domain/entities/service.dart';
import 'package:civiapp/domain/entities/staff_absence.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/shift.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/common/theme_mode_action.dart';
import 'package:civiapp/presentation/shared/client_package_purchase.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  ConsumerState<StaffDashboardScreen> createState() =>
      _StaffDashboardScreenState();
}

class _AppointmentDetailSheet extends ConsumerWidget {
  const _AppointmentDetailSheet({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(appDataProvider);
    final client = data.clients.firstWhereOrNull(
      (element) => element.id == appointment.clientId,
    );
    final appointmentServices =
        appointment.serviceIds
            .map(
              (id) =>
                  data.services.firstWhereOrNull((element) => element.id == id),
            )
            .whereType<Service>()
            .toList();
    final serviceLabel =
        appointmentServices.isNotEmpty
            ? appointmentServices.map((service) => service.name).join(' + ')
            : 'Servizio';
    final staff = data.staff.firstWhereOrNull(
      (element) => element.id == appointment.staffId,
    );
    final salon = data.salons.firstWhereOrNull(
      (element) => element.id == appointment.salonId,
    );
    final room = salon?.rooms.firstWhereOrNull(
      (element) => element.id == appointment.roomId,
    );

    final now = DateTime.now();
    final historyThreshold = now.subtract(const Duration(days: 730));
    final historyAppointments =
        data.appointments
            .where(
              (appt) =>
                  appt.clientId == appointment.clientId &&
                  appt.id != appointment.id &&
                  appt.start.isAfter(historyThreshold) &&
                  appt.start.isBefore(now),
            )
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));

    final purchases =
        resolveClientPackagePurchases(
          sales: data.sales,
          packages: data.packages,
          appointments: data.appointments,
          services: data.services,
          clientId: appointment.clientId,
          salonId: appointment.salonId,
        ).where((purchase) => purchase.isActive).toList();

    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');
    final timeFormatter = DateFormat('HH:mm');
    final currencyFormatter = NumberFormat.simpleCurrency(locale: 'it_IT');

    final startLabel = dateFormatter.format(appointment.start);
    final endLabel = timeFormatter.format(appointment.end);
    final durationLabel = _formatDuration(appointment.duration);
    final roomLabel = room?.name ?? 'Non assegnata';
    final notes = appointment.notes?.trim();
    final notesLabel =
        (notes == null || notes.isEmpty) ? 'Nessuna nota' : notes;

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Text('Dettagli appuntamento', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceLabel, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.calendar_month_outlined,
                        label: 'Data e ora',
                        value: '$startLabel • $endLabel',
                      ),
                      _InfoRow(
                        icon: Icons.timer_outlined,
                        label: 'Durata',
                        value: durationLabel,
                      ),
                      if (staff != null)
                        _InfoRow(
                          icon: Icons.person_outline,
                          label: 'Staff',
                          value: staff.fullName,
                        ),
                      _InfoRow(
                        icon: Icons.store_mall_directory_outlined,
                        label: 'Cabina',
                        value: roomLabel,
                      ),
                      _InfoRow(
                        icon: Icons.sticky_note_2_outlined,
                        label: 'Note',
                        value: notesLabel,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Dettaglio cliente', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (client == null)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.person_off_outlined),
                    title: Text('Cliente non disponibile'),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.fullName,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (client.clientNumber != null &&
                            client.clientNumber!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Codice cliente: ${client.clientNumber}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Telefono',
                          value: client.phone,
                        ),
                        if (client.email != null && client.email!.isNotEmpty)
                          _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: client.email!,
                          ),
                        if (client.address != null &&
                            client.address!.isNotEmpty)
                          _InfoRow(
                            icon: Icons.home_outlined,
                            label: 'Indirizzo',
                            value: client.address!,
                          ),
                        if (client.notes != null &&
                            client.notes!.trim().isNotEmpty)
                          _InfoRow(
                            icon: Icons.note_alt_outlined,
                            label: 'Note cliente',
                            value: client.notes!.trim(),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Storico appuntamenti (ultimi 24 mesi)',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (historyAppointments.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.history_toggle_off_outlined),
                    title: Text('Nessun appuntamento nel periodo selezionato'),
                  ),
                )
              else
                ...historyAppointments.map((appt) {
                  final historyService = data.services.firstWhereOrNull(
                    (service) => service.id == appt.serviceId,
                  );
                  final historyStaff = data.staff.firstWhereOrNull(
                    (member) => member.id == appt.staffId,
                  );
                  final historyDate = dateFormatter.format(appt.start);
                  final historyDuration = _formatDuration(appt.duration);
                  final subtitleParts = [historyDate, historyDuration];
                  if (historyStaff != null) {
                    subtitleParts.add(historyStaff.fullName);
                  }
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: Text(historyService?.name ?? 'Servizio'),
                      subtitle: Text(subtitleParts.join(' • ')),
                      trailing: _appointmentStatusChip(appt.status, context),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Text('Pacchetti in corso', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (purchases.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.inventory_2_outlined),
                    title: Text('Nessun pacchetto attivo'),
                  ),
                )
              else
                ...purchases.map((purchase) {
                  final remaining = purchase.remainingSessions;
                  final totalSessions = purchase.totalSessions;
                  String sessionsLabel;
                  if (remaining != null && totalSessions != null) {
                    sessionsLabel = '$remaining / $totalSessions sessioni';
                  } else if (remaining != null) {
                    sessionsLabel = '$remaining sessioni residue';
                  } else {
                    sessionsLabel = 'Sessioni non disponibili';
                  }
                  final expiration = purchase.expirationDate;
                  final expirationLabel =
                      expiration != null
                          ? DateFormat('dd/MM/yyyy').format(expiration)
                          : 'Nessuna scadenza';
                  final outstanding = purchase.outstandingAmount;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            purchase.displayName,
                            style: theme.textTheme.titleMedium,
                          ),
                          if (purchase.serviceNames.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                purchase.serviceNames.join(', '),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.event_available_outlined,
                            label: 'Sessioni',
                            value: sessionsLabel,
                          ),
                          _InfoRow(
                            icon: Icons.hourglass_bottom_outlined,
                            label: 'Scadenza',
                            value: expirationLabel,
                          ),
                          _InfoRow(
                            icon: Icons.payments_outlined,
                            label: 'Pagamento',
                            value: purchase.paymentStatus.label,
                          ),
                          _InfoRow(
                            icon: Icons.euro_outlined,
                            label: 'Importo',
                            value: currencyFormatter.format(
                              purchase.totalAmount,
                            ),
                          ),
                          if (purchase.depositAmount > 0)
                            _InfoRow(
                              icon: Icons.savings_outlined,
                              label: 'Acconti versati',
                              value: currencyFormatter.format(
                                purchase.depositAmount,
                              ),
                            ),
                          if (outstanding > 0)
                            _InfoRow(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Residuo da saldare',
                              value: currencyFormatter.format(outstanding),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final session = ref.watch(sessionControllerProvider);
    final staffMembers = data.staff;
    StaffMember? selectedStaff = staffMembers.firstWhereOrNull(
      (member) => member.id == session.userId,
    );

    if (selectedStaff == null && staffMembers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(sessionControllerProvider.notifier)
            .setUser(staffMembers.first.id);
        ref
            .read(sessionControllerProvider.notifier)
            .setSalon(staffMembers.first.salonId);
      });
      selectedStaff = staffMembers.first;
    }

    final relatedAppointments =
        data.appointments
            .where((appointment) => appointment.staffId == selectedStaff?.id)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final today = DateTime.now();
    final todayAppointments =
        relatedAppointments
            .where(
              (appointment) =>
                  appointment.start.year == today.year &&
                  appointment.start.month == today.month &&
                  appointment.start.day == today.day,
            )
            .toList();
    final upcoming =
        relatedAppointments
            .where((appointment) => appointment.start.isAfter(DateTime.now()))
            .toList();

    final staffAbsences =
        data.staffAbsences
            .where((absence) => absence.staffId == selectedStaff?.id)
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final staffShifts =
        data.shifts
            .where((shift) => shift.staffId == selectedStaff?.id)
            .toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Ciao ${selectedStaff?.fullName.split(' ').first ?? 'Staff'}',
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Oggi'),
              Tab(text: 'Agenda'),
              Tab(text: 'Ferie & Permessi'),
            ],
          ),
          actions: [
            if (staffMembers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedStaff?.id,
                    items:
                        staffMembers
                            .map(
                              (member) => DropdownMenuItem(
                                value: member.id,
                                child: Text(member.fullName),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      final member = staffMembers.firstWhereOrNull(
                        (m) => m.id == value,
                      );
                      ref
                          .read(sessionControllerProvider.notifier)
                          .setUser(member?.id);
                      ref
                          .read(sessionControllerProvider.notifier)
                          .setSalon(member?.salonId);
                    },
                  ),
                ),
              ),
            const ThemeModeAction(),
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
            _TodayView(
              appointments: todayAppointments,
              allAppointments: relatedAppointments,
            ),
            _AgendaView(appointments: upcoming),
            _AbsenceView(
              staff: selectedStaff,
              absences: staffAbsences,
              shifts: staffShifts,
            ),
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
                value: _formatDuration(
                  appointments.fold<Duration>(
                    Duration.zero,
                    (total, appointment) =>
                        total + appointment.end.difference(appointment.start),
                  ),
                ),
              ),
              _TodayCard(
                icon: Icons.calendar_month_rounded,
                title: 'Agenda totale',
                value: '${allAppointments.length}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Dettaglio appuntamenti',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (appointments.isEmpty)
            const Card(child: ListTile(title: Text('Nessun appuntamento oggi')))
          else
            ...appointments.map((appointment) {
              final client = data.clients.firstWhereOrNull(
                (client) => client.id == appointment.clientId,
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
              final serviceLabel =
                  services.isNotEmpty
                      ? services.map((service) => service.name).join(' + ')
                      : 'Servizio';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      client?.firstName.characters.firstOrNull?.toUpperCase() ??
                          '?',
                    ),
                  ),
                  title: Text(client?.fullName ?? 'Cliente'),
                  subtitle: Text(
                    '$serviceLabel · ${DateFormat('HH:mm').format(appointment.start)}',
                  ),
                  trailing: const Icon(Icons.navigate_next_rounded),
                  onTap: () => _showAppointmentDetails(context, appointment),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showAppointmentDetails(
    BuildContext context,
    Appointment appointment,
  ) {
    return showAppModalSheet<void>(
      context: context,
      builder:
          (ctx) => _AppointmentDetailSheet(appointment: appointment),
    );
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
        final client = data.clients.firstWhereOrNull(
          (client) => client.id == appointment.clientId,
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
        final serviceLabel =
            services.isNotEmpty
                ? services.map((service) => service.name).join(' + ')
                : 'Servizio';
        return Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_month_rounded),
            title: Text(serviceLabel),
            subtitle: Text(
              '${client?.fullName ?? 'Cliente'} · ${DateFormat('dd/MM HH:mm').format(appointment.start)}',
            ),
            trailing: _appointmentStatusChip(appointment.status, context),
          ),
        );
      },
    );
  }
}

class _AbsenceView extends StatelessWidget {
  const _AbsenceView({
    required this.staff,
    required this.absences,
    required this.shifts,
  });

  final StaffMember? staff;
  final List<StaffAbsence> absences;
  final List<Shift> shifts;

  @override
  Widget build(BuildContext context) {
    if (staff == null) {
      return const Center(child: Text('Seleziona un membro dello staff'));
    }

    final theme = Theme.of(context);
    final shiftsByDay = _groupShiftsByDay(shifts);
    final holidaysCache = <int, Set<DateTime>>{};
    Set<DateTime> holidaysForYear(int year) {
      return holidaysCache.putIfAbsent(
        year,
        () => _nationalHolidaysForYear(year),
      );
    }

    final summary = _calculateAbsenceSummary(
      staff: staff!,
      absences: absences,
      shiftsByDay: shiftsByDay,
      holidaysForYear: holidaysForYear,
      referenceYear: DateTime.now().year,
    );

    final vacationAndPermissions =
        absences
            .where(
              (absence) =>
                  absence.type == StaffAbsenceType.vacation ||
                  absence.type == StaffAbsenceType.permission,
            )
            .toList();
    final sickLeaves =
        absences
            .where((absence) => absence.type == StaffAbsenceType.sickLeave)
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _AbsenceSummaryCard(
                icon: Icons.beach_access_rounded,
                title: 'Ferie residue',
                value: _formatDays(summary.vacationRemaining),
                subtitle:
                    'Usate ${_formatDays(summary.vacationUsed)} su ${staff!.vacationAllowance} giorni',
              ),
              _AbsenceSummaryCard(
                icon: Icons.event_busy_rounded,
                title: 'Permessi residui',
                value: _formatDays(summary.permissionRemaining),
                subtitle:
                    'Usati ${_formatDays(summary.permissionUsed)} su ${staff!.permissionAllowance} giorni',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _AbsenceSection(
            title: 'Ferie & Permessi',
            absences: vacationAndPermissions,
            emptyLabel: 'Nessuna assenza registrata',
            emptyIcon: Icons.event_available_outlined,
            shiftsByDay: shiftsByDay,
            holidaysForYear: holidaysForYear,
          ),
          _AbsenceSection(
            title: 'Malattie',
            absences: sickLeaves,
            emptyLabel: 'Nessuna malattia registrata',
            emptyIcon: Icons.healing_outlined,
            shiftsByDay: shiftsByDay,
            holidaysForYear: holidaysForYear,
          ),
        ],
      ),
    );
  }
}

class _AbsenceSection extends StatelessWidget {
  const _AbsenceSection({
    required this.title,
    required this.absences,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.shiftsByDay,
    required this.holidaysForYear,
  });

  final String title;
  final List<StaffAbsence> absences;
  final String emptyLabel;
  final IconData emptyIcon;
  final Map<DateTime, List<Shift>> shiftsByDay;
  final Set<DateTime> Function(int year) holidaysForYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (absences.isEmpty)
          Card(
            child: ListTile(leading: Icon(emptyIcon), title: Text(emptyLabel)),
          )
        else
          ...absences.map((absence) {
            final daysLabel = _formatDays(
              _absenceWorkingDays(absence, shiftsByDay, holidaysForYear),
            );
            final rangeLabel = _formatAbsenceRange(absence);
            final notes = absence.notes?.trim();
            final hasValidNotes = notes != null && notes.isNotEmpty;
            return Card(
              child: ListTile(
                leading: Icon(_absenceIcon(absence.type)),
                title: Text(
                  '${absence.type.label} · $daysLabel',
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(rangeLabel),
                    if (hasValidNotes)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(notes, style: theme.textTheme.bodySmall),
                      ),
                  ],
                ),
                isThreeLine: hasValidNotes,
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AbsenceSummaryCard extends StatelessWidget {
  const _AbsenceSummaryCard({
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
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

_AbsenceSummary _calculateAbsenceSummary({
  required StaffMember staff,
  required Iterable<StaffAbsence> absences,
  required Map<DateTime, List<Shift>> shiftsByDay,
  required Set<DateTime> Function(int year) holidaysForYear,
  required int referenceYear,
}) {
  double vacation = 0;
  double permissions = 0;
  final rangeStart = DateTime(referenceYear, 1, 1);
  final rangeEnd = DateTime(referenceYear + 1, 1, 1);

  for (final absence in absences) {
    final days = _absenceWorkingDays(
      absence,
      shiftsByDay,
      holidaysForYear,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    if (days <= 0) {
      continue;
    }
    switch (absence.type) {
      case StaffAbsenceType.vacation:
        vacation += days;
        break;
      case StaffAbsenceType.permission:
        permissions += days;
        break;
      case StaffAbsenceType.sickLeave:
        break;
    }
  }

  final vacationRemaining =
      (staff.vacationAllowance.toDouble() - vacation)
          .clamp(0, double.infinity)
          .toDouble();
  final permissionRemaining =
      (staff.permissionAllowance.toDouble() - permissions)
          .clamp(0, double.infinity)
          .toDouble();

  return _AbsenceSummary(
    vacationUsed: vacation,
    permissionUsed: permissions,
    vacationRemaining: vacationRemaining,
    permissionRemaining: permissionRemaining,
  );
}

String _formatDays(double value) {
  final isInteger = value == value.roundToDouble();
  if (isInteger) {
    final count = value.round();
    final suffix = count == 1 ? 'giorno' : 'giorni';
    return '$count $suffix';
  }
  return '${value.toStringAsFixed(1)} giorni';
}

IconData _absenceIcon(StaffAbsenceType type) {
  switch (type) {
    case StaffAbsenceType.vacation:
      return Icons.beach_access_outlined;
    case StaffAbsenceType.permission:
      return Icons.schedule_outlined;
    case StaffAbsenceType.sickLeave:
      return Icons.healing_outlined;
  }
}

String _formatAbsenceRange(StaffAbsence absence) {
  final dayFormatter = DateFormat('dd/MM/yyyy');
  final timeFormatter = DateFormat('HH:mm');

  final startDay = dayFormatter.format(absence.start);
  final endDay = dayFormatter.format(absence.end);

  if (absence.isSingleDay) {
    if (absence.isAllDay) {
      return startDay;
    }
    final startTime = timeFormatter.format(absence.start);
    final endTime = timeFormatter.format(absence.end);
    return '$startDay • $startTime-$endTime';
  }

  if (absence.isAllDay) {
    return '$startDay → $endDay';
  }

  final startTime = timeFormatter.format(absence.start);
  final endTime = timeFormatter.format(absence.end);
  return '$startDay → $endDay • $startTime-$endTime';
}

double _absenceWorkingDays(
  StaffAbsence absence,
  Map<DateTime, List<Shift>> shiftsByDay,
  Set<DateTime> Function(int year) holidaysForYear, {
  DateTime? rangeStart,
  DateTime? rangeEnd,
}) {
  var start = absence.start;
  var end = absence.end;

  if (rangeStart != null && end.isBefore(rangeStart)) {
    return 0;
  }
  if (rangeEnd != null && !start.isBefore(rangeEnd)) {
    return 0;
  }
  if (rangeStart != null && start.isBefore(rangeStart)) {
    start = rangeStart;
  }
  if (rangeEnd != null && !end.isBefore(rangeEnd)) {
    end = rangeEnd.subtract(const Duration(microseconds: 1));
  }
  if (!end.isAfter(start)) {
    return 0;
  }

  final startDay = _dateOnly(start);
  final endDay = _dateOnly(end);
  var currentDay = startDay;
  double total = 0;

  while (!currentDay.isAfter(endDay)) {
    final shifts = shiftsByDay[currentDay];
    if (shifts == null || shifts.isEmpty) {
      currentDay = currentDay.add(const Duration(days: 1));
      continue;
    }
    if (holidaysForYear(currentDay.year).contains(currentDay)) {
      currentDay = currentDay.add(const Duration(days: 1));
      continue;
    }

    final dayStart = currentDay;
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayAbsenceStart = start.isAfter(dayStart) ? start : dayStart;
    final dayAbsenceEnd = end.isBefore(dayEnd) ? end : dayEnd;

    if (!dayAbsenceEnd.isAfter(dayAbsenceStart)) {
      currentDay = currentDay.add(const Duration(days: 1));
      continue;
    }

    if (absence.isAllDay) {
      total += 1;
      currentDay = currentDay.add(const Duration(days: 1));
      continue;
    }

    var totalShiftMinutes = 0;
    var overlapMinutes = 0;
    for (final shift in shifts) {
      final shiftStart =
          shift.start.isBefore(dayStart) ? dayStart : shift.start;
      final shiftEnd = shift.end.isAfter(dayEnd) ? dayEnd : shift.end;
      if (!shiftEnd.isAfter(shiftStart)) {
        continue;
      }

      totalShiftMinutes += shiftEnd.difference(shiftStart).inMinutes;
      overlapMinutes += _overlapMinutes(
        dayAbsenceStart,
        dayAbsenceEnd,
        shiftStart,
        shiftEnd,
      );
    }

    if (totalShiftMinutes <= 0) {
      currentDay = currentDay.add(const Duration(days: 1));
      continue;
    }

    final fraction = overlapMinutes / totalShiftMinutes;
    if (fraction > 0) {
      total += fraction.clamp(0, 1);
    }

    currentDay = currentDay.add(const Duration(days: 1));
  }

  return total;
}

Map<DateTime, List<Shift>> _groupShiftsByDay(Iterable<Shift> shifts) {
  final map = <DateTime, List<Shift>>{};
  for (final shift in shifts) {
    final day = _dateOnly(shift.start);
    map.putIfAbsent(day, () => <Shift>[]).add(shift);
  }
  return map;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int _overlapMinutes(
  DateTime startA,
  DateTime endA,
  DateTime startB,
  DateTime endB,
) {
  final start = startA.isAfter(startB) ? startA : startB;
  final end = endA.isBefore(endB) ? endA : endB;
  if (!end.isAfter(start)) {
    return 0;
  }
  return end.difference(start).inMinutes;
}

Set<DateTime> _nationalHolidaysForYear(int year) {
  final dates = <DateTime>{
    DateTime(year, 1, 1), // Capodanno
    DateTime(year, 1, 6), // Epifania
    DateTime(year, 4, 25), // Liberazione
    DateTime(year, 5, 1), // Festa del lavoro
    DateTime(year, 6, 2), // Festa della Repubblica
    DateTime(year, 8, 15), // Ferragosto
    DateTime(year, 11, 1), // Ognissanti
    DateTime(year, 12, 8), // Immacolata
    DateTime(year, 12, 25), // Natale
    DateTime(year, 12, 26), // Santo Stefano
  };

  final easterMonday = _calculateEasterSunday(
    year,
  ).add(const Duration(days: 1));
  dates.add(_dateOnly(easterMonday));

  return dates.map(_dateOnly).toSet();
}

DateTime _calculateEasterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

class _AbsenceSummary {
  const _AbsenceSummary({
    required this.vacationUsed,
    required this.permissionUsed,
    required this.vacationRemaining,
    required this.permissionRemaining,
  });

  final double vacationUsed;
  final double permissionUsed;
  final double vacationRemaining;
  final double permissionRemaining;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.icon,
    required this.title,
    required this.value,
  });

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
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _appointmentStatusChip(AppointmentStatus status, BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case AppointmentStatus.scheduled:
      return Chip(
        label: const Text('Programmato'),
        backgroundColor: scheme.primaryContainer,
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
        backgroundColor: scheme.error.withOpacity(0.1),
      );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inMinutes / 60;
  return '${hours.toStringAsFixed(1)} h';
}
