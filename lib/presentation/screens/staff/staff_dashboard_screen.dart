import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/staff_absence.dart';
import 'package:you_book/domain/entities/staff_absence_request.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/common/theme_mode_action.dart';
import 'package:you_book/presentation/screens/staff/forms/staff_absence_request_form_sheet.dart';
import 'package:you_book/presentation/shared/client_package_purchase.dart';
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
    final upcomingAppointments =
        data.appointments
            .where(
              (appt) =>
                  appt.clientId == appointment.clientId &&
                  appt.id != appointment.id &&
                  appt.start.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

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
              Text('Scheda cliente', style: theme.textTheme.titleLarge),
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
              Text('Pacchetti attivi', style: theme.textTheme.titleLarge),
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
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(purchase.displayName),
                      subtitle: Text('$sessionsLabel • $expirationLabel'),
                      trailing: Text(
                        currencyFormatter.format(purchase.totalAmount),
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Text('Prossimi appuntamenti', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (upcomingAppointments.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.event_available_outlined),
                    title: Text('Nessun appuntamento in programma'),
                  ),
                )
              else
                ...upcomingAppointments.take(5).map((appt) {
                  final upcomingService = data.services.firstWhereOrNull(
                    (service) => service.id == appt.serviceId,
                  );
                  final upcomingDate = dateFormatter.format(appt.start);
                  return _AppointmentSummaryCard(
                    icon: Icons.calendar_month_outlined,
                    title: upcomingService?.name ?? 'Servizio',
                    subtitle: upcomingDate,
                    status: appt.status,
                  );
                }),
              const SizedBox(height: 16),
              if (historyAppointments.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.history_toggle_off_outlined),
                    title: Text('Nessun appuntamento nello storico'),
                  ),
                )
              else
                Card(
                  child: ExpansionTile(
                    title: const Text('Storico appuntamenti (ultimi 24 mesi)'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children:
                        historyAppointments.map((appt) {
                          final historyService = data.services.firstWhereOrNull(
                            (service) => service.id == appt.serviceId,
                          );
                          final historyStaff = data.staff.firstWhereOrNull(
                            (member) => member.id == appt.staffId,
                          );
                          final historyDate = dateFormatter.format(appt.start);
                          final historyDuration = _formatDuration(
                            appt.duration,
                          );
                          final subtitleParts = [historyDate, historyDuration];
                          if (historyStaff != null) {
                            subtitleParts.add(historyStaff.fullName);
                          }
                          return _AppointmentSummaryCard(
                            margin: const EdgeInsets.only(top: 8),
                            icon: Icons.history_rounded,
                            title: historyService?.name ?? 'Servizio',
                            subtitle: subtitleParts.join(' • '),
                            status: appt.status,
                          );
                        }).toList(),
                  ),
                ),
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
    final staffId = session.user?.staffId ?? session.userId;
    final selectedStaff = staffMembers.firstWhereOrNull(
      (member) => member.id == staffId,
    );

    if (staffMembers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (selectedStaff == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff')),
        body: const Center(
          child: Text('Nessun profilo staff collegato a questo account.'),
        ),
      );
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
    final staffAbsenceRequests =
        data.staffAbsenceRequests.toList()..sort((a, b) {
          final left = a.createdAt ?? a.start;
          final right = b.createdAt ?? b.start;
          return right.compareTo(left);
        });
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
            const ThemeModeAction(),
            IconButton(
              tooltip: 'Esci',
              onPressed: () async {
                await performSignOut(ref);
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _TodayView(appointments: todayAppointments),
            _AgendaView(appointments: upcoming),
            _AbsenceView(
              staff: selectedStaff,
              absences: staffAbsences,
              requests: staffAbsenceRequests,
              shifts: staffShifts,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayView extends ConsumerWidget {
  const _TodayView({required this.appointments});

  final List<Appointment> appointments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final theme = Theme.of(context);
    final sortedAppointments = List<Appointment>.from(appointments)
      ..sort((a, b) => a.start.compareTo(b.start));
    final now = DateTime.now();
    final nextAppointment = sortedAppointments.firstWhereOrNull(
      (appointment) => appointment.end.isAfter(now),
    );
    final nextClient =
        nextAppointment == null
            ? null
            : data.clients.firstWhereOrNull(
              (client) => client.id == nextAppointment.clientId,
            );
    final nextServices =
        nextAppointment == null
            ? const <Service>[]
            : nextAppointment.serviceIds
                .map(
                  (id) => data.services.firstWhereOrNull(
                    (service) => service.id == id,
                  ),
                )
                .whereType<Service>()
                .toList();
    final nextServiceLabel =
        nextServices.isNotEmpty
            ? nextServices.map((service) => service.name).join(' + ')
            : 'Servizio';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nextAppointment != null) ...[
            Text('Prossimo appuntamento', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _NextAppointmentCard(
              clientName: nextClient?.fullName ?? 'Cliente',
              clientInitial:
                  nextClient?.firstName.characters.firstOrNull?.toUpperCase() ??
                  '?',
              serviceLabel: nextServiceLabel,
              durationLabel: _formatDuration(nextAppointment.duration),
              timeLabel:
                  '${DateFormat('HH:mm').format(nextAppointment.start)} - ${DateFormat('HH:mm').format(nextAppointment.end)}',
              onTap: () => _showAppointmentDetails(context, nextAppointment),
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _TodayCard(
                icon: Icons.event_available_rounded,
                title: 'Appuntamenti di oggi',
                value: '${sortedAppointments.length}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Agenda di oggi', style: theme.textTheme.titleLarge),
              Text(
                '${sortedAppointments.length} appuntamenti',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sortedAppointments.isEmpty)
            const Card(child: ListTile(title: Text('Nessun appuntamento oggi')))
          else
            ...sortedAppointments.map((appointment) {
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
      builder: (ctx) => _AppointmentDetailSheet(appointment: appointment),
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

class _AbsenceView extends ConsumerWidget {
  const _AbsenceView({
    required this.staff,
    required this.absences,
    required this.requests,
    required this.shifts,
  });

  final StaffMember? staff;
  final List<StaffAbsence> absences;
  final List<StaffAbsenceRequest> requests;
  final List<Shift> shifts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (staff == null) {
      return const Center(child: Text('Seleziona un membro dello staff'));
    }

    final theme = Theme.of(context);
    final pendingRequests =
        requests.where((request) => request.status.isPending).toList();
    final historyRequests =
        requests.where((request) => !request.status.isPending).toList();
    const historyPreviewLimit = 3;
    final historyPreview = historyRequests.take(historyPreviewLimit).toList();
    final showHistoryButton = historyRequests.isNotEmpty;
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
          Text('Richieste ferie & permessi', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _openAbsenceRequestForm(context, staff: staff!),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuova richiesta'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _AbsenceSummaryCard(
                  icon: Icons.beach_access_rounded,
                  title: 'Ferie',
                  value: _formatDays(summary.vacationRemaining),
                  subtitle:
                      'Usate ${_formatDays(summary.vacationUsed)} su ${staff!.vacationAllowance} giorni',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AbsenceSummaryCard(
                  icon: Icons.event_busy_rounded,
                  title: 'Permessi',
                  value: _formatDays(summary.permissionRemaining),
                  subtitle:
                      'Usati ${_formatDays(summary.permissionUsed)} su ${staff!.permissionAllowance} giorni',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (pendingRequests.isEmpty && historyPreview.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.event_available_outlined),
                title: Text('Nessuna richiesta inviata'),
              ),
            )
          else ...[
            if (pendingRequests.isNotEmpty) ...[
              Text(
                'In attesa (${pendingRequests.length})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...pendingRequests.map(
                (request) => _AbsenceRequestCard(
                  request: request,
                  onCancel: () => _confirmCancelRequest(context, ref, request),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (historyPreview.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Storico recente', style: theme.textTheme.titleMedium),
                  if (showHistoryButton)
                    TextButton(
                      onPressed:
                          () =>
                              _openAbsenceHistory(context, requests: requests),
                      child: const Text('Vedi storico'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...historyPreview.map(
                (request) => _AbsenceRequestCard(
                  request: request,
                  onCancel:
                      request.status.isPending
                          ? () => _confirmCancelRequest(context, ref, request)
                          : null,
                ),
              ),
            ],
          ],
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

class _AbsenceRequestCard extends StatelessWidget {
  const _AbsenceRequestCard({required this.request, this.onCancel});

  final StaffAbsenceRequest request;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = request.notes?.trim();
    final adminNote = request.adminNote?.trim();
    final showNotes = notes != null && notes.isNotEmpty;
    final showAdminNote =
        adminNote != null && adminNote.isNotEmpty && !request.status.isPending;
    final rangeLabel = _formatRequestRange(request.start, request.end);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_absenceIcon(request.type)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.type.label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(rangeLabel, style: theme.textTheme.bodySmall),
                  if (showNotes) ...[
                    const SizedBox(height: 4),
                    Text(notes, style: theme.textTheme.bodySmall),
                  ],
                  if (showAdminNote) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Risposta admin: $adminNote',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _requestStatusChip(request.status, context),
                if (onCancel != null)
                  TextButton(onPressed: onCancel, child: const Text('Annulla')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openAbsenceRequestForm(
  BuildContext context, {
  required StaffMember staff,
}) {
  return showAppModalSheet<void>(
    context: context,
    builder:
        (_) =>
            StaffAbsenceRequestFormSheet(staff: staff, salonId: staff.salonId),
  );
}

Future<void> _openAbsenceHistory(
  BuildContext context, {
  required List<StaffAbsenceRequest> requests,
}) {
  return showAppModalSheet<void>(
    context: context,
    builder: (_) => _AbsenceHistorySheet(requests: requests),
  );
}

Future<void> _confirmCancelRequest(
  BuildContext context,
  WidgetRef ref,
  StaffAbsenceRequest request,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: const Text('Annulla richiesta'),
          content: const Text(
            'Vuoi annullare questa richiesta di ferie/permesso?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Si, annulla'),
            ),
          ],
        ),
  );
  if (confirmed != true) {
    return;
  }

  await ref
      .read(appDataProvider.notifier)
      .cancelStaffAbsenceRequest(request: request);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Richiesta annullata.')));
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

class _AbsenceHistorySheet extends ConsumerWidget {
  const _AbsenceHistorySheet({required this.requests});

  final List<StaffAbsenceRequest> requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final body =
        requests.isEmpty
            ? const Card(
              child: ListTile(
                leading: Icon(Icons.event_available_outlined),
                title: Text('Nessuna richiesta disponibile'),
              ),
            )
            : Column(
              children:
                  requests
                      .map(
                        (request) => _AbsenceRequestCard(
                          request: request,
                          onCancel:
                              request.status.isPending
                                  ? () => _confirmCancelRequest(
                                    context,
                                    ref,
                                    request,
                                  )
                                  : null,
                        ),
                      )
                      .toList(),
            );

    return DialogActionLayout(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Storico richieste', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          body,
        ],
      ),
      actions: const [],
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
    return Card(
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

String _formatRequestRange(DateTime start, DateTime end) {
  final dayFormatter = DateFormat('dd/MM/yyyy');
  final timeFormatter = DateFormat('HH:mm');
  final startDay = dayFormatter.format(start);
  final endDay = dayFormatter.format(end);
  final isSingleDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  final isAllDay =
      start.hour == 0 &&
      start.minute == 0 &&
      end.hour == 23 &&
      end.minute == 59;

  if (isSingleDay) {
    if (isAllDay) {
      return startDay;
    }
    return '$startDay • ${timeFormatter.format(start)}-${timeFormatter.format(end)}';
  }

  if (isAllDay) {
    return '$startDay → $endDay';
  }

  return '$startDay → $endDay • ${timeFormatter.format(start)}-${timeFormatter.format(end)}';
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

class _AppointmentSummaryCard extends StatelessWidget {
  const _AppointmentSummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.margin,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppointmentStatus status;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
    final statusChip = _appointmentStatusChip(status, context);

    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 360;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: 8),
                  statusChip,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 12),
                Expanded(child: details),
                const SizedBox(width: 12),
                statusChip,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.clientName,
    required this.clientInitial,
    required this.serviceLabel,
    required this.durationLabel,
    required this.timeLabel,
    this.onTap,
  });

  final String clientName;
  final String clientInitial;
  final String serviceLabel;
  final String durationLabel;
  final String timeLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onPrimaryContainer,
    );
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onPrimaryContainer,
    );
    final secondaryStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onPrimaryContainer.withOpacity(0.8),
    );

    return Card(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.onPrimaryContainer.withOpacity(0.12),
                foregroundColor: scheme.onPrimaryContainer,
                child: Text(clientInitial),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clientName, style: titleStyle),
                    const SizedBox(height: 4),
                    Text('$serviceLabel · $durationLabel', style: bodyStyle),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: scheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                        const SizedBox(width: 6),
                        Text(timeLabel, style: secondaryStyle),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.navigate_next_rounded,
                color: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
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

Widget _requestStatusChip(
  StaffAbsenceRequestStatus status,
  BuildContext context,
) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case StaffAbsenceRequestStatus.pending:
      return Chip(
        label: const Text('In attesa'),
        backgroundColor: scheme.secondaryContainer,
      );
    case StaffAbsenceRequestStatus.approved:
      return Chip(
        label: const Text('Approvata'),
        backgroundColor: scheme.tertiaryContainer,
      );
    case StaffAbsenceRequestStatus.rejected:
      return Chip(
        label: const Text('Rifiutata'),
        backgroundColor: scheme.errorContainer,
      );
    case StaffAbsenceRequestStatus.cancelled:
      return Chip(
        label: const Text('Annullata'),
        backgroundColor: scheme.surfaceVariant,
      );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inMinutes / 60;
  return '${hours.toStringAsFixed(1)} h';
}
