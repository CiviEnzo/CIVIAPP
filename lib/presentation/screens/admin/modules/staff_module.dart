import 'dart:math' as math;

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/shift.dart';
import 'package:civiapp/domain/entities/staff_absence.dart';
import 'package:civiapp/domain/entities/staff_member.dart';
import 'package:civiapp/domain/entities/staff_role.dart';
import 'package:civiapp/domain/entities/user_role.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/shift_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/shift_bulk_delete_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/staff_absence_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/staff_form_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/staff_role_manager_sheet.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class StaffModule extends ConsumerWidget {
  const StaffModule({super.key, this.salonId});

  final String? salonId;

  static final _dayLabel = DateFormat('EEE dd MMM', 'it_IT');
  static final _timeLabel = DateFormat('HH:mm', 'it_IT');
  static final _birthLabel = DateFormat('dd MMM yyyy', 'it_IT');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final data = ref.watch(appDataProvider);
    final salons = data.salons;
    final staffRoles = data.staffRoles;
    final staffMembers = data.staff
        .where((member) => salonId == null || member.salonId == salonId)
        .sortedBy((member) => member.fullName.toLowerCase());
    final shifts = data.shifts
        .where((shift) => salonId == null || shift.salonId == salonId)
        .sortedBy((shift) => shift.start);
    final absences = data.staffAbsences
        .where((absence) => salonId == null || absence.salonId == salonId)
        .sortedBy((absence) => absence.start);
    final now = DateTime.now();
    final canManageRoles = session.role == UserRole.admin;
    final rolesById = {for (final role in staffRoles) role.id: role};

    final roomsBySalon = <String, Map<String, String>>{};
    for (final salon in salons) {
      roomsBySalon[salon.id] = {
        for (final room in salon.rooms) room.id: room.name,
      };
    }
    final absencesByStaff = groupBy<StaffAbsence, String>(
      absences,
      (absence) => absence.staffId,
    );

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: staffMembers.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed:
                      () => _openStaffForm(
                        context,
                        ref,
                        salons: salons,
                        roles: staffRoles,
                        defaultSalonId: salonId,
                        defaultRoleId: staffRoles.firstOrNull?.id,
                      ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Nuovo membro'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      () => _openRoleManager(
                        context,
                        ref,
                        roles: staffRoles,
                        canManageRoles: canManageRoles,
                      ),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Gestisci ruoli'),
                ),
              ],
            ),
          );
        }

        final staff = staffMembers[index - 1];
        final staffShifts =
            shifts.where((shift) => shift.staffId == staff.id).toList();
        final futureShifts =
            staffShifts
                .where((shift) => shift.end.isAfter(now))
                .sortedBy((shift) => shift.start)
                .toList();
        final upcoming = futureShifts.take(6).toList();
        final roomNames = roomsBySalon[staff.salonId] ?? const {};
        final allStaffAbsences =
            absencesByStaff[staff.id] ?? const <StaffAbsence>[];
        final upcomingAbsences =
            allStaffAbsences
                .where((absence) => !absence.end.isBefore(now))
                .sortedBy((absence) => absence.start)
                .toList();
        final pastAbsences =
            allStaffAbsences
                .where((absence) => absence.end.isBefore(now))
                .sortedBy((absence) => absence.start)
                .toList()
                .reversed
                .toList();
        final absenceSummary = _calculateAbsenceSummary(
          staff: staff,
          absences: allStaffAbsences,
          referenceYear: now.year,
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      child: Text(
                        staff.fullName.characters.firstOrNull?.toUpperCase() ??
                            '?',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staff.fullName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rolesById[staff.roleId]?.displayName ?? 'Mansione',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (staff.dateOfBirth != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Nato il ${_birthLabel.format(staff.dateOfBirth!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (staff.skills.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  staff.skills
                                      .map((skill) => Chip(label: Text(skill)))
                                      .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Modifica profilo',
                          onPressed:
                              () => _openStaffForm(
                                context,
                                ref,
                                salons: salons,
                                roles: staffRoles,
                                defaultSalonId: salonId,
                                defaultRoleId: staff.roleId,
                                existing: staff,
                              ),
                          icon: const Icon(Icons.edit_rounded),
                        ),
                        IconButton(
                          tooltip: 'Elimina membro',
                          onPressed:
                              () => _confirmDeleteStaff(
                                context,
                                ref,
                                staff: staff,
                                hasUpcomingShifts: futureShifts.isNotEmpty,
                              ),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                        if (staff.phone != null || staff.email != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (staff.phone != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.phone, size: 16),
                                      const SizedBox(width: 4),
                                      Text(staff.phone!),
                                    ],
                                  ),
                                ),
                              if (staff.email != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.email, size: 16),
                                      const SizedBox(width: 4),
                                      Text(staff.email!),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Turni programmati',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed:
                                    () => _openShiftForm(
                                      context,
                                      ref,
                                      salons: salons,
                                      staff: staffMembers,
                                      defaultSalonId: staff.salonId,
                                      defaultStaffId: staff.id,
                                    ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Nuovo turno'),
                              ),
                              if (futureShifts.isNotEmpty)
                                TextButton.icon(
                                  onPressed:
                                      () => _openShiftBulkDelete(
                                        context,
                                        ref,
                                        staff: staff,
                                        shifts: futureShifts,
                                        roomNames: roomNames,
                                      ),
                                  icon: const Icon(Icons.delete_sweep_rounded),
                                  label: const Text('Elimina turni'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (upcoming.isEmpty)
                        Text(
                          'Nessun turno in programma. Pianifica un turno per rendere disponibile il membro dello staff.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        Column(
                          children:
                              upcoming
                                  .map(
                                    (shift) => _ShiftTile(
                                      shift: shift,
                                      roomName: roomNames[shift.roomId],
                                      onEdit:
                                          () => _openShiftForm(
                                            context,
                                            ref,
                                            salons: salons,
                                            staff: staffMembers,
                                            initial: shift,
                                          ),
                                      onDelete:
                                          () => _confirmDeleteShift(
                                            context,
                                            ref,
                                            shift,
                                          ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      if (staffShifts.length > upcoming.length)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Sono presenti altri ${staffShifts.length - upcoming.length} turni futuri.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Assenze e ferie',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          TextButton.icon(
                            onPressed:
                                () => _openAbsenceForm(
                                  context,
                                  ref,
                                  salons: salons,
                                  staff: staffMembers,
                                  defaultSalonId: staff.salonId,
                                  defaultStaffId: staff.id,
                                ),
                            icon: const Icon(Icons.event_busy_rounded),
                            label: const Text('Nuova assenza'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _AllowanceChip(
                            label: 'Ferie',
                            usedLabel: 'Usate',
                            remainingLabel: 'Residue',
                            used: absenceSummary.vacationUsed,
                            remaining: absenceSummary.vacationRemaining,
                            total: staff.vacationAllowance.toDouble(),
                          ),
                          _AllowanceChip(
                            label: 'Permessi',
                            usedLabel: 'Usati',
                            remainingLabel: 'Residui',
                            used: absenceSummary.permissionUsed,
                            remaining: absenceSummary.permissionRemaining,
                            total: staff.permissionAllowance.toDouble(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Assenze in programma',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      if (upcomingAbsences.isEmpty)
                        Text(
                          'Nessuna assenza pianificata. Usa "Nuova assenza" per registrare ferie, permessi o malattia.',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        Column(
                          children:
                              upcomingAbsences
                                  .take(4)
                                  .map(
                                    (absence) => _AbsenceTile(
                                      absence: absence,
                                      onEdit:
                                          () => _openAbsenceForm(
                                            context,
                                            ref,
                                            salons: salons,
                                            staff: staffMembers,
                                            initial: absence,
                                          ),
                                      onDelete:
                                          () => _confirmDeleteAbsence(
                                            context,
                                            ref,
                                            absence,
                                          ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      if (upcomingAbsences.length > 4)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Sono presenti altre ${upcomingAbsences.length - 4} assenze pianificate.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      if (pastAbsences.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Storico ${now.year}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        Column(
                          children:
                              pastAbsences
                                  .take(3)
                                  .map(
                                    (absence) => _AbsenceTile(
                                      absence: absence,
                                      onEdit:
                                          () => _openAbsenceForm(
                                            context,
                                            ref,
                                            salons: salons,
                                            staff: staffMembers,
                                            initial: absence,
                                          ),
                                      onDelete:
                                          () => _confirmDeleteAbsence(
                                            context,
                                            ref,
                                            absence,
                                          ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        if (pastAbsences.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              'Sono presenti altre ${pastAbsences.length - 3} assenze concluse.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStaffForm(
    BuildContext context,
    WidgetRef ref, {
    required List<Salon> salons,
    required List<StaffRole> roles,
    String? defaultSalonId,
    String? defaultRoleId,
    StaffMember? existing,
  }) async {
    if (salons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crea prima un salone per assegnare lo staff.'),
        ),
      );
      return;
    }
    final result = await showAppModalSheet<StaffMember>(
      context: context,
      builder:
          (ctx) => StaffFormSheet(
            salons: salons,
            roles: roles,
            defaultSalonId: defaultSalonId,
            defaultRoleId: defaultRoleId,
            initial: existing,
          ),
    );
    if (result != null) {
      await ref.read(appDataProvider.notifier).upsertStaff(result);
    }
  }

  Future<void> _openRoleManager(
    BuildContext context,
    WidgetRef ref, {
    required List<StaffRole> roles,
    required bool canManageRoles,
  }) async {
    await showAppModalSheet<void>(
      context: context,
      builder:
          (_) => StaffRoleManagerSheet(
            roles: roles,
            canManageRoles: canManageRoles,
          ),
    );
  }

  Future<void> _openShiftForm(
    BuildContext context,
    WidgetRef ref, {
    required List<Salon> salons,
    required List<StaffMember> staff,
    String? defaultSalonId,
    String? defaultStaffId,
    Shift? initial,
  }) async {
    if (salons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aggiungi almeno un salone prima di pianificare turni.',
          ),
        ),
      );
      return;
    }
    final result = await showAppModalSheet<ShiftFormResult>(
      context: context,
      builder:
          (ctx) => ShiftFormSheet(
            salons: salons,
            staff: staff,
            defaultSalonId: defaultSalonId,
            defaultStaffId: defaultStaffId,
            initial: initial,
          ),
    );
    if (result != null) {
      await ref.read(appDataProvider.notifier).upsertShifts(result.shifts);
      if (context.mounted) {
        final anchor = result.shifts.first.start;
        final label =
            result.isSeries
                ? '${result.shifts.length} turni salvati a partire dal ${_dayLabel.format(anchor)}.'
                : 'Turno salvato per ${_dayLabel.format(anchor)}.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(label)));
      }
    }
  }

  Future<void> _openShiftBulkDelete(
    BuildContext context,
    WidgetRef ref, {
    required StaffMember staff,
    required List<Shift> shifts,
    required Map<String, String> roomNames,
  }) async {
    if (shifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non ci sono turni da eliminare.')),
      );
      return;
    }
    final ids = await showAppModalSheet<List<String>>(
      context: context,
      builder:
          (_) => ShiftBulkDeleteSheet(
            shifts: shifts,
            staff: staff,
            roomNames: roomNames,
          ),
    );
    if (ids == null || ids.isEmpty) {
      return;
    }
    await ref.read(appDataProvider.notifier).deleteShiftsByIds(ids);
    if (context.mounted) {
      final label =
          ids.length > 1
              ? 'Eliminati ${ids.length} turni.'
              : 'Turno eliminato.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(label)));
    }
  }

  Future<void> _confirmDeleteStaff(
    BuildContext context,
    WidgetRef ref, {
    required StaffMember staff,
    required bool hasUpcomingShifts,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final buffer = StringBuffer('Vuoi eliminare ${staff.fullName}?');
        if (hasUpcomingShifts) {
          buffer.write('\nI turni futuri verranno eliminati automaticamente.');
        }
        buffer.write(
          '\nGli appuntamenti resteranno senza operatore assegnato.',
        );
        return AlertDialog(
          title: const Text('Elimina membro dello staff'),
          content: Text(buffer.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(appDataProvider.notifier).deleteStaff(staff.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${staff.fullName} eliminato.')));
    }
  }

  Future<void> _openAbsenceForm(
    BuildContext context,
    WidgetRef ref, {
    required List<Salon> salons,
    required List<StaffMember> staff,
    String? defaultSalonId,
    String? defaultStaffId,
    StaffAbsence? initial,
  }) async {
    if (salons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crea prima un salone per assegnare le assenze.'),
        ),
      );
      return;
    }

    final result = await showAppModalSheet<StaffAbsence>(
      context: context,
      builder:
          (ctx) => StaffAbsenceFormSheet(
            salons: salons,
            staff: staff,
            initial: initial,
            defaultSalonId: defaultSalonId,
            defaultStaffId: defaultStaffId,
          ),
    );

    if (result != null) {
      await ref.read(appDataProvider.notifier).upsertStaffAbsence(result);
      if (context.mounted) {
        final label =
            initial == null ? 'Assenza registrata.' : 'Assenza aggiornata.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(label)));
      }
    }
  }

  Future<void> _confirmDeleteShift(
    BuildContext context,
    WidgetRef ref,
    Shift shift,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Elimina turno'),
            content: Text(
              'Vuoi davvero eliminare il turno del ${_dayLabel.format(shift.start)}?',
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
    if (confirmed == true) {
      await ref.read(appDataProvider.notifier).deleteShift(shift.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Turno eliminato (${_dayLabel.format(shift.start)} ${_timeLabel.format(shift.start)}).',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAbsence(
    BuildContext context,
    WidgetRef ref,
    StaffAbsence absence,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Elimina assenza'),
            content: Text(
              'Vuoi eliminare l\'assenza dal ${_dayLabel.format(absence.start)}?',
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
    if (confirmed == true) {
      await ref.read(appDataProvider.notifier).deleteStaffAbsence(absence.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Assenza rimossa (${_dayLabel.format(absence.start)}).',
            ),
          ),
        );
      }
    }
  }

  static _AbsenceSummary _calculateAbsenceSummary({
    required StaffMember staff,
    required Iterable<StaffAbsence> absences,
    required int referenceYear,
  }) {
    double vacation = 0;
    double permissions = 0;
    for (final absence in absences) {
      final days = _absenceDaysWithinYear(absence, referenceYear);
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
    final vacationRemaining = math.max(
      0.0,
      staff.vacationAllowance.toDouble() - vacation,
    );
    final permissionRemaining = math.max(
      0.0,
      staff.permissionAllowance.toDouble() - permissions,
    );
    return _AbsenceSummary(
      vacationUsed: vacation,
      permissionUsed: permissions,
      vacationRemaining: vacationRemaining,
      permissionRemaining: permissionRemaining,
    );
  }

  static double _absenceDaysWithinYear(StaffAbsence absence, int year) {
    final rangeStart = DateTime(year, 1, 1);
    final rangeEnd = DateTime(year + 1, 1, 1);
    var start = absence.start;
    var end = absence.end;
    if (end.isBefore(rangeStart) || !start.isBefore(rangeEnd)) {
      return 0;
    }
    if (start.isBefore(rangeStart)) {
      start = rangeStart;
    }
    if (end.isAfter(rangeEnd)) {
      end = rangeEnd.subtract(const Duration(minutes: 1));
    }
    if (!end.isAfter(start)) {
      return 0;
    }
    if (absence.isAllDay) {
      final startDate = DateTime(start.year, start.month, start.day);
      final endDate = DateTime(end.year, end.month, end.day);
      return (endDate.difference(startDate).inDays + 1).toDouble();
    }
    const workdayMinutes = 8 * 60;
    final minutes = end.difference(start).inMinutes;
    return minutes / workdayMinutes;
  }
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

class _AllowanceChip extends StatelessWidget {
  const _AllowanceChip({
    required this.label,
    required this.usedLabel,
    required this.remainingLabel,
    required this.used,
    required this.remaining,
    required this.total,
  });

  final String label;
  final String usedLabel;
  final String remainingLabel;
  final double used;
  final double remaining;
  final double total;

  String _format(double value) {
    if ((value - value.round()).abs() < 0.05) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text =
        '$label · $usedLabel ${_format(used)} · $remainingLabel ${_format(remaining)} / ${_format(total)}';
    return InputChip(label: Text(text, style: theme.textTheme.bodySmall));
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({
    required this.shift,
    required this.roomName,
    required this.onEdit,
    required this.onDelete,
  });

  final Shift shift;
  final String? roomName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static final _dayLabel = StaffModule._dayLabel;
  static final _timeLabel = StaffModule._timeLabel;
  static final DateFormat _weekdayFormatter = DateFormat('EEE', 'it_IT');
  static final DateFormat _chipDayLabel = DateFormat('dd MMM', 'it_IT');

  @override
  Widget build(BuildContext context) {
    final timeRange =
        '${_timeLabel.format(shift.start)} - ${_timeLabel.format(shift.end)}';
    final chipLabel = '${_chipDayLabel.format(shift.start)} • $timeRange';

    final tooltipLines = <String>[
      _dayLabel.format(shift.start),
      'Orario: $timeRange',
    ];
    if (roomName != null && roomName!.isNotEmpty) {
      tooltipLines.add('Cabina: $roomName');
    }
    if (shift.breakStart != null && shift.breakEnd != null) {
      tooltipLines.add(
        'Pausa: ${_timeLabel.format(shift.breakStart!)} - ${_timeLabel.format(shift.breakEnd!)}',
      );
    }
    if (shift.seriesId != null) {
      tooltipLines.add(_recurrenceLabel(shift.recurrence));
    }
    if (shift.notes != null && shift.notes!.isNotEmpty) {
      tooltipLines.add('Note: ${shift.notes}');
    }

    return Tooltip(
      message: tooltipLines.join('\n'),
      preferBelow: false,
      child: InputChip(
        avatar: const Icon(Icons.schedule_rounded, size: 18),
        label: Text(chipLabel),
        onPressed: onEdit,
        onDeleted: onDelete,
      ),
    );
  }

  String _recurrenceLabel(ShiftRecurrence? recurrence) {
    if (recurrence == null) {
      return 'Serie';
    }
    final freq = () {
      switch (recurrence.frequency) {
        case ShiftRecurrenceFrequency.daily:
          return 'Giornaliera';
        case ShiftRecurrenceFrequency.weekly:
          final active = recurrence.activeWeeks ?? 1;
          final rawPause =
              recurrence.inactiveWeeks ?? (recurrence.interval - active);
          final pause =
              rawPause < 0
                  ? 0
                  : rawPause > 52
                  ? 52
                  : rawPause;
          if (pause > 0) {
            return 'Settimanale ($active attive, $pause pausa)';
          }
          return active > 1
              ? 'Settimanale ($active settimane consecutive)'
              : 'Settimanale';
        case ShiftRecurrenceFrequency.monthly:
          return recurrence.interval > 1
              ? 'Mensile (ogni ${recurrence.interval})'
              : 'Mensile';
        case ShiftRecurrenceFrequency.yearly:
          return recurrence.interval > 1
              ? 'Annuale (ogni ${recurrence.interval})'
              : 'Annuale';
      }
    }();
    final days = recurrence.weekdays;
    final daysLabel =
        days != null && days.isNotEmpty
            ? ' (${days.map(_weekdayLabel).join(', ')})'
            : '';
    return '$freq$daysLabel fino al ${StaffModule._dayLabel.format(recurrence.until)}';
  }

  static String _weekdayLabel(int weekday) {
    final reference = DateTime(
      2024,
      1,
      1,
    ).add(Duration(days: weekday - DateTime.monday));
    final label = _weekdayFormatter.format(reference);
    if (label.isEmpty) {
      return label;
    }
    return label[0].toUpperCase() + label.substring(1);
  }
}

class _AbsenceTile extends StatelessWidget {
  const _AbsenceTile({
    required this.absence,
    required this.onEdit,
    required this.onDelete,
  });

  final StaffAbsence absence;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static final _dayLabel = StaffModule._dayLabel;

  IconData get _icon {
    switch (absence.type) {
      case StaffAbsenceType.sickLeave:
        return Icons.healing_rounded;
      case StaffAbsenceType.vacation:
        return Icons.beach_access_rounded;
      case StaffAbsenceType.permission:
        return Icons.event_available_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final range =
        absence.isSingleDay
            ? _dayLabel.format(absence.start)
            : '${_dayLabel.format(absence.start)} → ${_dayLabel.format(absence.end)}';
    final subtitle = StringBuffer(range);
    if (!absence.isAllDay) {
      subtitle.write(
        '\n${StaffModule._timeLabel.format(absence.start)} - ${StaffModule._timeLabel.format(absence.end)}',
      );
    }
    if (absence.notes != null && absence.notes!.isNotEmpty) {
      subtitle.write('\n${absence.notes}');
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_icon),
      title: Text(absence.type.label),
      subtitle: Text(subtitle.toString()),
      trailing: PopupMenuButton<String>(
        tooltip: 'Azioni assenza',
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEdit();
              break;
            case 'delete':
              onDelete();
              break;
          }
        },
        itemBuilder:
            (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_rounded),
                  title: Text('Modifica'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Elimina'),
                ),
              ),
            ],
      ),
    );
  }
}
