import 'dart:math' as math;

import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/shift.dart';
import 'package:you_book/domain/entities/staff_absence.dart';
import 'package:you_book/domain/entities/staff_absence_request.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/staff_role.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/shift_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/shift_bulk_delete_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/staff_absence_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/staff_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/staff_role_manager_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/staff_order_sheet.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final _staffExpansionProvider = StateProvider.autoDispose.family<bool, String>(
  (ref, staffId) => false,
);
final _staffWeekOffsetProvider = StateProvider.autoDispose.family<int, String>(
  (ref, staffId) => 0,
);

class StaffModule extends ConsumerWidget {
  const StaffModule({super.key, this.salonId});

  final String? salonId;

  static final _dayLabel = DateFormat('EEE dd MMM', 'it_IT');
  static final _timeLabel = DateFormat('HH:mm', 'it_IT');
  static final _birthLabel = DateFormat('dd MMM yyyy', 'it_IT');
  static final _shortDateLabel = DateFormat('dd MMM', 'it_IT');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final data = ref.watch(appDataProvider);
    final salons = data.salons;
    final staffRoles = data.staffRoles;
    final effectiveSalonId = session.selectedSalonId ?? salonId;
    final visibleSalons =
        effectiveSalonId == null
            ? salons
            : salons.where((salon) => salon.id == effectiveSalonId).toList();
    final primarySalon = visibleSalons.length == 1 ? visibleSalons.first : null;
    final staffMembers =
        data.staff
            .where(
              (member) =>
                  effectiveSalonId == null ||
                  member.salonId == effectiveSalonId,
            )
            .sortedByDisplayOrder();
    final shifts = data.shifts
        .where(
          (shift) =>
              effectiveSalonId == null || shift.salonId == effectiveSalonId,
        )
        .sortedBy((shift) => shift.start);
    final absences = data.staffAbsences
        .where(
          (absence) =>
              effectiveSalonId == null || absence.salonId == effectiveSalonId,
        )
        .sortedBy((absence) => absence.start);
    final now = DateTime.now();
    final canManageRoles = session.role == UserRole.admin;
    final rolesById = {for (final role in staffRoles) role.id: role};
    final salonsById = {for (final salon in salons) salon.id: salon};
    final canCreateStaff = primarySalon != null;

    bool _hasStaffAccess(StaffMember staff) {
      final staffEmail = staff.email?.trim().toLowerCase();
      for (final user in data.users) {
        if (user.staffId == staff.id) {
          return true;
        }
        final userEmail = user.email?.trim().toLowerCase();
        if (staffEmail != null &&
            staffEmail.isNotEmpty &&
            userEmail == staffEmail) {
          return true;
        }
      }
      return false;
    }

    final roomsBySalon = <String, Map<String, String>>{};
    final roomSourceSalons = effectiveSalonId == null ? salons : visibleSalons;
    for (final salon in roomSourceSalons) {
      roomsBySalon[salon.id] = {
        for (final room in salon.rooms) room.id: room.name,
      };
    }
    final absencesByStaff = groupBy<StaffAbsence, String>(
      absences,
      (absence) => absence.staffId,
    );
    final absenceRequests =
        data.staffAbsenceRequests
            .where(
              (request) =>
                  effectiveSalonId == null ||
                  request.salonId == effectiveSalonId,
            )
            .toList()
          ..sort((a, b) {
            final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
    final requestsByStaff = groupBy<StaffAbsenceRequest, String>(
      absenceRequests,
      (request) => request.staffId,
    );
    final pendingRequestsByStaff = groupBy<StaffAbsenceRequest, String>(
      absenceRequests.where(
        (request) => request.status == StaffAbsenceRequestStatus.pending,
      ),
      (request) => request.staffId,
    );

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: staffMembers.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      !canCreateStaff
                          ? null
                          : () => StaffOrderSheet.show(
                            context,
                            salons: [primarySalon!],
                            selectedSalonId: primarySalon.id,
                          ),
                  icon: const Icon(Icons.sort_rounded),
                  label: const Text('Ordina staff'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      () => _openRoleManager(
                        context,
                        ref,
                        canManageRoles: canManageRoles,
                        salonId: primarySalon?.id ?? effectiveSalonId,
                      ),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Gestione ruoli'),
                ),
                FilledButton.icon(
                  onPressed:
                      !canCreateStaff
                          ? null
                          : () => _openStaffForm(
                            context,
                            ref,
                            salons: [primarySalon!],
                            roles: staffRoles,
                            defaultSalonId: primarySalon.id,
                            defaultRoleId: staffRoles.firstOrNull?.id,
                          ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Nuovo membro'),
                ),
              ],
            ),
          );
        }

        final staff = staffMembers[index - 1];
        final hasEmail = staff.email?.trim().isNotEmpty ?? false;
        final canCreateAccess = !staff.isEquipment && !_hasStaffAccess(staff);
        final staffShifts =
            shifts.where((shift) => shift.staffId == staff.id).toList();
        final futureShifts =
            staffShifts
                .where((shift) => shift.end.isAfter(now))
                .sortedBy((shift) => shift.start)
                .toList();
        final staffSalon = salonsById[staff.salonId];
        final staffSalons = staffSalon != null ? [staffSalon] : visibleSalons;
        final staffPeers =
            staffMembers
                .where((member) => member.salonId == staff.salonId)
                .toList();
        final roomNames = roomsBySalon[staff.salonId] ?? const {};
        final allStaffAbsences =
            absencesByStaff[staff.id] ?? const <StaffAbsence>[];
        final staffRequests =
            requestsByStaff[staff.id] ?? const <StaffAbsenceRequest>[];
        final pendingRequests =
            pendingRequestsByStaff[staff.id] ?? const <StaffAbsenceRequest>[];
        final resolvedRequests =
            staffRequests
                .where(
                  (request) =>
                      request.status != StaffAbsenceRequestStatus.pending,
                )
                .toList();
        final absenceSummary = _calculateAbsenceSummary(
          staff: staff,
          absences: allStaffAbsences,
          referenceYear: now.year,
        );
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
        final weekOffset = ref.watch(_staffWeekOffsetProvider(staff.id));
        final weekOffsetController = ref.read(
          _staffWeekOffsetProvider(staff.id).notifier,
        );
        final schedule = staffSalon?.schedule ?? primarySalon?.schedule;
        final openWeekdays =
            schedule == null || schedule.isEmpty
                ? const <int>[]
                : (schedule
                    .where((entry) => entry.isOpen)
                    .map((entry) => entry.weekday)
                    .toSet()
                    .toList()
                  ..sort());
        final weekStart = _startOfWeek(now).add(Duration(days: 7 * weekOffset));
        final weekEnd = weekStart.add(const Duration(days: 7));
        final weekShifts =
            staffShifts
                .where(
                  (shift) =>
                      shift.end.isAfter(weekStart) &&
                      shift.start.isBefore(weekEnd),
                )
                .sortedBy((shift) => shift.start)
                .toList();

        final isExpanded = ref.watch(_staffExpansionProvider(staff.id));
        final expansionController = ref.read(
          _staffExpansionProvider(staff.id).notifier,
        );

        void toggleExpansion() {
          expansionController.state = !expansionController.state;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;

            Widget actionBar({bool dense = false}) {
              final spacing = dense ? 4.0 : 8.0;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Modifica profilo',
                    visualDensity:
                        dense
                            ? const VisualDensity(horizontal: -2, vertical: -2)
                            : null,
                    onPressed:
                        () => _openStaffForm(
                          context,
                          ref,
                          salons: staffSalons,
                          roles: staffRoles,
                          defaultSalonId: staff.salonId,
                          defaultRoleId: staff.primaryRoleId,
                          existing: staff,
                        ),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    tooltip: 'Elimina membro',
                    visualDensity:
                        dense
                            ? const VisualDensity(horizontal: -2, vertical: -2)
                            : null,
                    onPressed:
                        () => _confirmDeleteStaff(
                          context,
                          ref,
                          staff: staff,
                          hasUpcomingShifts: futureShifts.isNotEmpty,
                        ),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                  IconButton(
                    tooltip:
                        isExpanded ? 'Comprimi dettagli' : 'Espandi dettagli',
                    visualDensity:
                        dense
                            ? const VisualDensity(horizontal: -2, vertical: -2)
                            : null,
                    onPressed: toggleExpansion,
                    icon: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more_rounded),
                    ),
                  ),
                ],
              );
            }

            return Card(
              elevation: isExpanded ? 3 : 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: _softSurface(context, blend: 0.14),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  InkWell(
                    onTap: toggleExpansion,
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage:
                                staff.avatarUrl != null &&
                                        staff.avatarUrl!.isNotEmpty
                                    ? NetworkImage(staff.avatarUrl!)
                                    : null,
                            child:
                                staff.avatarUrl == null ||
                                        staff.avatarUrl!.isEmpty
                                    ? Text(
                                      staff.fullName.characters.firstOrNull
                                              ?.toUpperCase() ??
                                          '?',
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isCompact) ...[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              staff.fullName,
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _roleLabel(
                                                rolesById: rolesById,
                                                staff: staff,
                                              ),
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium,
                                            ),
                                            if (pendingRequests.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Chip(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                avatar: const Icon(
                                                  Icons.notifications_active,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  '${pendingRequests.length} richiesta${pendingRequests.length == 1 ? '' : 'e'} in attesa',
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: actionBar(dense: true),
                                  ),
                                ] else ...[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              staff.fullName,
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _roleLabel(
                                                rolesById: rolesById,
                                                staff: staff,
                                              ),
                                              style:
                                                  Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium,
                                            ),
                                            if (pendingRequests.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Chip(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                avatar: const Icon(
                                                  Icons.notifications_active,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  '${pendingRequests.length} richiesta${pendingRequests.length == 1 ? '' : 'e'} in attesa',
                                                ),
                                              ),
                                            ],
                                            if (staff.isEquipment) ...[
                                              const SizedBox(height: 6),
                                              Chip(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                                visualDensity:
                                                    VisualDensity.compact,
                                                avatar: const Icon(
                                                  Icons.precision_manufacturing,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Macchinario',
                                                ),
                                              ),
                                            ],
                                            if (staff.dateOfBirth != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Nato il ${_birthLabel.format(staff.dateOfBirth!)}',
                                                style:
                                                    Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      actionBar(),
                                    ],
                                  ),
                                ],
                                if (staff.isEquipment && isCompact) ...[
                                  const SizedBox(height: 6),
                                  Chip(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    avatar: const Icon(
                                      Icons.precision_manufacturing,
                                      size: 16,
                                    ),
                                    label: const Text('Macchinario'),
                                  ),
                                ],
                                if (staff.dateOfBirth != null && isCompact) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Nato il ${_birthLabel.format(staff.dateOfBirth!)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                                if (staff.phone != null ||
                                    staff.email != null) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      if (staff.phone != null)
                                        _ContactInfo(
                                          icon: Icons.phone,
                                          label: staff.phone!,
                                        ),
                                      if (staff.email != null)
                                        _ContactInfo(
                                          icon: Icons.email,
                                          label: staff.email!,
                                        ),
                                    ],
                                  ),
                                ],
                                if (canCreateAccess) ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      if (!hasEmail) {
                                        await _openStaffForm(
                                          context,
                                          ref,
                                          salons: staffSalons,
                                          roles: staffRoles,
                                          defaultSalonId: staff.salonId,
                                          defaultRoleId: staff.primaryRoleId,
                                          existing: staff,
                                        );
                                        return;
                                      }
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      try {
                                        await ref
                                            .read(appDataProvider.notifier)
                                            .createStaffAccess(staff);
                                        messenger.showAppSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Accesso staff abilitato. Se nuovo account, inviata email di reset.',
                                            ),
                                          ),
                                        );
                                      } catch (_) {
                                        messenger.showAppSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Impossibile creare l\'accesso. Riprova.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.key_rounded),
                                    label: const Text('Crea accesso'),
                                  ),
                                  if (!hasEmail) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Aggiungi un\'email per creare l\'accesso.',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 220),
                    alignment: Alignment.topCenter,
                    crossFadeState:
                        isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: DefaultTabController(
                        length: 3,
                        child: Builder(
                          builder: (context) {
                            final theme = Theme.of(context);
                            final isLight =
                                theme.brightness == Brightness.light;
                            final tabController =
                                DefaultTabController.of(context)!;
                            final weekLabel =
                                '${_shortDateLabel.format(weekStart)} - ${_shortDateLabel.format(weekStart.add(const Duration(days: 6)))}';
                            final isWeekCompact = constraints.maxWidth < 720;

                            Widget buildShiftTab() {
                              return Column(
                                children: [
                                  _StaffSectionCard(
                                    title: 'Turni della settimana',
                                    trailing: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed:
                                              () => _openShiftForm(
                                                context,
                                                ref,
                                                salons: staffSalons,
                                                staff: staffPeers,
                                                defaultSalonId: staff.salonId,
                                                defaultStaffId: staff.id,
                                                defaultDay: weekStart,
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
                                            icon: const Icon(
                                              Icons.delete_sweep_rounded,
                                            ),
                                            label: const Text('Elimina turni'),
                                          ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            IconButton(
                                              tooltip: 'Settimana precedente',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () {
                                                weekOffsetController.state =
                                                    weekOffsetController.state -
                                                    1;
                                              },
                                              icon: const Icon(
                                                Icons.chevron_left_rounded,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                'Settimana $weekLabel',
                                                style:
                                                    theme.textTheme.labelLarge,
                                              ),
                                            ),
                                            if (!isCompact && weekOffset != 0)
                                              TextButton(
                                                onPressed:
                                                    () =>
                                                        weekOffsetController
                                                            .state = 0,
                                                child: const Text(
                                                  'Questa settimana',
                                                ),
                                              ),
                                            IconButton(
                                              tooltip: 'Settimana successiva',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onPressed: () {
                                                weekOffsetController.state =
                                                    weekOffsetController.state +
                                                    1;
                                              },
                                              icon: const Icon(
                                                Icons.chevron_right_rounded,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _ShiftWeekView(
                                          weekStart: weekStart,
                                          shifts: weekShifts,
                                          roomNames: roomNames,
                                          isCompact: isWeekCompact,
                                          visibleWeekdays: openWeekdays,
                                          onAddShift:
                                              (day) => _openShiftForm(
                                                context,
                                                ref,
                                                salons: staffSalons,
                                                staff: staffPeers,
                                                defaultSalonId: staff.salonId,
                                                defaultStaffId: staff.id,
                                                defaultDay: day,
                                              ),
                                          onEditShift:
                                              (shift) => _openShiftForm(
                                                context,
                                                ref,
                                                salons: staffSalons,
                                                staff: staffPeers,
                                                initial: shift,
                                              ),
                                          onDeleteShift:
                                              (shift) => _confirmDeleteShift(
                                                context,
                                                ref,
                                                shift,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            Widget buildAbsencesTab() {
                              const upcomingPreviewLimit = 4;
                              const historyPreviewLimit = 4;
                              final upcomingPreview =
                                  upcomingAbsences
                                      .take(upcomingPreviewLimit)
                                      .toList();
                              final pastPreview =
                                  pastAbsences
                                      .take(historyPreviewLimit)
                                      .toList();
                              return Column(
                                children: [
                                  _StaffSectionCard(
                                    title: 'Assenze',
                                    trailing: TextButton.icon(
                                      onPressed:
                                          () => _openAbsenceForm(
                                            context,
                                            ref,
                                            salons: staffSalons,
                                            staff: staffPeers,
                                            defaultSalonId: staff.salonId,
                                            defaultStaffId: staff.id,
                                          ),
                                      icon: const Icon(
                                        Icons.event_busy_rounded,
                                      ),
                                      label: const Text('Nuova assenza'),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _AllowanceChip(
                                              label: 'Ferie',
                                              usedLabel: 'Usate',
                                              remainingLabel: 'Residue',
                                              used: absenceSummary.vacationUsed,
                                              remaining:
                                                  absenceSummary
                                                      .vacationRemaining,
                                              total:
                                                  staff.vacationAllowance
                                                      .toDouble(),
                                            ),
                                            _AllowanceChip(
                                              label: 'Permessi',
                                              usedLabel: 'Usati',
                                              remainingLabel: 'Residui',
                                              used:
                                                  absenceSummary.permissionUsed,
                                              remaining:
                                                  absenceSummary
                                                      .permissionRemaining,
                                              total:
                                                  staff.permissionAllowance
                                                      .toDouble(),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Assenze in programma',
                                          style: theme.textTheme.labelLarge,
                                        ),
                                        const SizedBox(height: 6),
                                        if (upcomingAbsences.isEmpty)
                                          Text(
                                            'Nessuna assenza pianificata. Usa "Nuova assenza" per registrare ferie, permessi o malattia.',
                                            style: theme.textTheme.bodySmall,
                                          )
                                        else
                                          Column(
                                            children:
                                                upcomingPreview
                                                    .map(
                                                      (absence) => _AbsenceTile(
                                                        absence: absence,
                                                        onEdit:
                                                            () => _openAbsenceForm(
                                                              context,
                                                              ref,
                                                              salons:
                                                                  staffSalons,
                                                              staff: staffPeers,
                                                              initial: absence,
                                                            ),
                                                        onDelete:
                                                            () =>
                                                                _confirmDeleteAbsence(
                                                                  context,
                                                                  ref,
                                                                  absence,
                                                                ),
                                                      ),
                                                    )
                                                    .toList(),
                                          ),
                                        if (upcomingAbsences.length >
                                            upcomingPreview.length) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            'Sono presenti altre ${upcomingAbsences.length - upcomingPreview.length} assenze pianificate.',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                        if (pastAbsences.isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          Text(
                                            'Storico ${now.year}',
                                            style: theme.textTheme.labelLarge,
                                          ),
                                          const SizedBox(height: 6),
                                          Column(
                                            children:
                                                pastPreview
                                                    .map(
                                                      (absence) => _AbsenceTile(
                                                        absence: absence,
                                                        onEdit:
                                                            () => _openAbsenceForm(
                                                              context,
                                                              ref,
                                                              salons:
                                                                  staffSalons,
                                                              staff: staffPeers,
                                                              initial: absence,
                                                            ),
                                                        onDelete:
                                                            () =>
                                                                _confirmDeleteAbsence(
                                                                  context,
                                                                  ref,
                                                                  absence,
                                                                ),
                                                      ),
                                                    )
                                                    .toList(),
                                          ),
                                          if (pastAbsences.length >
                                              pastPreview.length) ...[
                                            const SizedBox(height: 12),
                                            Text(
                                              'Sono presenti altre ${pastAbsences.length - pastPreview.length} assenze concluse.',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            Widget buildRequestsTab() {
                              const pendingPreviewLimit = 6;
                              const historyPreviewLimit = 4;
                              final pendingPreview =
                                  pendingRequests
                                      .take(pendingPreviewLimit)
                                      .toList();
                              final resolvedPreview =
                                  resolvedRequests
                                      .take(historyPreviewLimit)
                                      .toList();

                              return Column(
                                children: [
                                  _StaffSectionCard(
                                    title: 'Richieste',
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (pendingRequests.isEmpty &&
                                            resolvedRequests.isEmpty)
                                          Text(
                                            'Nessuna richiesta ricevuta per questo membro.',
                                            style: theme.textTheme.bodySmall,
                                          )
                                        else ...[
                                          if (pendingRequests.isNotEmpty) ...[
                                            Text(
                                              'Da approvare',
                                              style: theme.textTheme.labelLarge,
                                            ),
                                            const SizedBox(height: 6),
                                            ...pendingPreview.map(
                                              (
                                                request,
                                              ) => _AbsenceRequestAdminTile(
                                                request: request,
                                                onApprove:
                                                    () =>
                                                        _handleAbsenceRequestDecision(
                                                          context,
                                                          ref,
                                                          request: request,
                                                          approve: true,
                                                        ),
                                                onReject:
                                                    () =>
                                                        _handleAbsenceRequestDecision(
                                                          context,
                                                          ref,
                                                          request: request,
                                                          approve: false,
                                                        ),
                                              ),
                                            ),
                                            if (pendingRequests.length >
                                                pendingPreview.length) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                'Sono presenti altre ${pendingRequests.length - pendingPreview.length} richieste in attesa.',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ],
                                          if (resolvedRequests.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Text(
                                              'Storico richieste',
                                              style: theme.textTheme.labelLarge,
                                            ),
                                            const SizedBox(height: 6),
                                            ...resolvedPreview.map(
                                              (request) =>
                                                  _AbsenceRequestAdminTile(
                                                    request: request,
                                                  ),
                                            ),
                                            if (resolvedRequests.length >
                                                resolvedPreview.length) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                'Sono presenti altre ${resolvedRequests.length - resolvedPreview.length} richieste nello storico.',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color:
                                        isLight
                                            ? theme.colorScheme.surfaceVariant
                                                .withOpacity(0.6)
                                            : _softSurface(
                                              context,
                                              blend: 0.18,
                                            ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: TabBar(
                                      indicator: BoxDecoration(
                                        color:
                                            isLight
                                                ? theme
                                                    .colorScheme
                                                    .primaryContainer
                                                : theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme
                                              .colorScheme
                                              .outlineVariant
                                              .withOpacity(isLight ? 0.6 : 0.4),
                                        ),
                                      ),
                                      indicatorSize: TabBarIndicatorSize.tab,
                                      dividerColor: Colors.transparent,
                                      dividerHeight: 0,
                                      labelColor:
                                          isLight
                                              ? theme
                                                  .colorScheme
                                                  .onPrimaryContainer
                                              : theme.colorScheme.onSurface,
                                      unselectedLabelColor: theme
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.8),
                                      labelStyle: theme.textTheme.labelLarge,
                                      tabs: const [
                                        Tab(text: 'Turni'),
                                        Tab(text: 'Assenze'),
                                        Tab(text: 'Richieste'),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AnimatedBuilder(
                                  animation: tabController,
                                  builder: (context, _) {
                                    final index = tabController.index;
                                    return AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      child: KeyedSubtree(
                                        key: ValueKey(index),
                                        child:
                                            index == 0
                                                ? buildShiftTab()
                                                : index == 1
                                                ? buildAbsencesTab()
                                                : buildRequestsTab(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Color _softSurface(BuildContext context, {double blend = 0.1}) {
    final scheme = Theme.of(context).colorScheme;
    return Color.lerp(scheme.surface, Colors.white, blend) ?? scheme.surface;
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime _startOfWeek(DateTime date) {
    final normalized = _dateOnly(date);
    final difference = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: difference));
  }

  static bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
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
      ScaffoldMessenger.of(context).showAppSnackBar(
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
    required bool canManageRoles,
    String? salonId,
  }) async {
    final selectedSalonId = salonId ?? ref.read(currentSalonIdProvider);
    await showAppModalSheet<void>(
      context: context,
      includeCloseButton: false,
      builder:
          (_) => StaffRoleManagerSheet(
            canManageRoles: canManageRoles,
            salonId: selectedSalonId,
          ),
    );
  }

  String _roleLabel({
    required Map<String, StaffRole> rolesById,
    required StaffMember staff,
  }) {
    final names = staff.roleIds
        .map((roleId) {
          final name = rolesById[roleId]?.displayName;
          return name?.trim();
        })
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (names.isNotEmpty) {
      return names.join(' • ');
    }
    final fallback = rolesById[staff.primaryRoleId]?.displayName;
    final fallbackName = fallback?.trim();
    if (fallbackName != null && fallbackName.isNotEmpty) {
      return fallbackName;
    }
    return 'Mansione';
  }

  Future<void> _openShiftForm(
    BuildContext context,
    WidgetRef ref, {
    required List<Salon> salons,
    required List<StaffMember> staff,
    String? defaultSalonId,
    String? defaultStaffId,
    Shift? initial,
    DateTime? defaultDay,
  }) async {
    if (salons.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
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
            defaultDay: defaultDay,
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
        ).showAppSnackBar(SnackBar(content: Text(label)));
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Non ci sono turni da eliminare.')),
      );
      return;
    }
    final ids = await showAppModalSheet<List<String>>(
      context: context,
      includeCloseButton: false,
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
      ).showAppSnackBar(SnackBar(content: Text(label)));
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('${staff.fullName} eliminato.')),
      );
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
      ScaffoldMessenger.of(context).showAppSnackBar(
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
        ).showAppSnackBar(SnackBar(content: Text(label)));
      }
    }
  }

  Future<void> _handleAbsenceRequestDecision(
    BuildContext context,
    WidgetRef ref, {
    required StaffAbsenceRequest request,
    required bool approve,
  }) async {
    final note = await _promptAbsenceRequestNote(context, approve: approve);
    if (!context.mounted || note == null) {
      return;
    }
    final trimmed = note.trim();
    final noteValue = trimmed.isEmpty ? null : trimmed;
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (approve) {
        await ref
            .read(appDataProvider.notifier)
            .approveStaffAbsenceRequest(request: request, adminNote: noteValue);
        messenger.showAppSnackBar(
          const SnackBar(content: Text('Richiesta approvata.')),
        );
      } else {
        await ref
            .read(appDataProvider.notifier)
            .rejectStaffAbsenceRequest(request: request, adminNote: noteValue);
        messenger.showAppSnackBar(
          const SnackBar(content: Text('Richiesta rifiutata.')),
        );
      }
    } catch (error) {
      messenger.showAppSnackBar(
        SnackBar(content: Text('Errore durante l\'operazione: $error')),
      );
    }
  }

  Future<String?> _promptAbsenceRequestNote(
    BuildContext context, {
    required bool approve,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(approve ? 'Approva richiesta' : 'Rifiuta richiesta'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    approve
                        ? 'Nota per lo staff (opzionale)'
                        : 'Motivazione (opzionale)',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(dialogContext).pop(controller.text),
                child: Text(approve ? 'Approva' : 'Rifiuta'),
              ),
            ],
          ),
    );
    controller.dispose();
    return result;
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
        ScaffoldMessenger.of(context).showAppSnackBar(
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
        ScaffoldMessenger.of(context).showAppSnackBar(
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

class _StaffSectionCard extends StatelessWidget {
  const _StaffSectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      color: StaffModule._softSurface(context, blend: 0.22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: trailing!,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ContactInfo extends StatelessWidget {
  const _ContactInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StaffModule._softSurface(context, blend: 0.28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final DateFormat _weekdayFormatter = DateFormat('EEE', 'it_IT');

String _capitalize(String value) {
  if (value.isEmpty) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}

String _weekdayLabel(int weekday) {
  final reference = DateTime(
    2024,
    1,
    1,
  ).add(Duration(days: weekday - DateTime.monday));
  final label = _weekdayFormatter.format(reference);
  return _capitalize(label);
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

class _ShiftWeekView extends StatelessWidget {
  const _ShiftWeekView({
    required this.weekStart,
    required this.shifts,
    required this.roomNames,
    required this.isCompact,
    required this.visibleWeekdays,
    required this.onAddShift,
    required this.onEditShift,
    required this.onDeleteShift,
  });

  final DateTime weekStart;
  final List<Shift> shifts;
  final Map<String, String> roomNames;
  final bool isCompact;
  final List<int> visibleWeekdays;
  final ValueChanged<DateTime> onAddShift;
  final ValueChanged<Shift> onEditShift;
  final ValueChanged<Shift> onDeleteShift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (visibleWeekdays.isEmpty) {
      return Text(
        'Nessun giorno di apertura configurato.',
        style: theme.textTheme.bodySmall,
      );
    }
    final shiftsByDay = groupBy<Shift, DateTime>(
      shifts,
      (shift) => StaffModule._dateOnly(shift.start),
    );
    final normalizedWeekdays = visibleWeekdays.toSet().toList()..sort();
    final days =
        normalizedWeekdays
            .map(
              (weekday) => StaffModule._dateOnly(
                weekStart.add(Duration(days: weekday - DateTime.monday)),
              ),
            )
            .toList();
    final cards =
        days
            .map(
              (day) => _ShiftWeekDayCard(
                day: day,
                shifts: (shiftsByDay[day] ?? const <Shift>[]).sortedBy(
                  (shift) => shift.start,
                ),
                roomNames: roomNames,
                onAddShift: () => onAddShift(day),
                onEditShift: onEditShift,
                onDeleteShift: onDeleteShift,
              ),
            )
            .toList();
    if (isCompact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              SizedBox(width: 180, child: cards[index]),
            ],
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: cards[index]),
        ],
      ],
    );
  }
}

class _ShiftWeekDayCard extends StatelessWidget {
  const _ShiftWeekDayCard({
    required this.day,
    required this.shifts,
    required this.roomNames,
    required this.onAddShift,
    required this.onEditShift,
    required this.onDeleteShift,
  });

  final DateTime day;
  final List<Shift> shifts;
  final Map<String, String> roomNames;
  final VoidCallback onAddShift;
  final ValueChanged<Shift> onEditShift;
  final ValueChanged<Shift> onDeleteShift;

  static final DateFormat _weekdayFormat = DateFormat('EEE', 'it_IT');
  static final DateFormat _dayLabel = DateFormat('dd MMM', 'it_IT');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header =
        '${_capitalize(_weekdayFormat.format(day))} ${_dayLabel.format(day)}';
    final isToday = StaffModule._isSameDay(day, DateTime.now());

    return DecoratedBox(
      decoration: BoxDecoration(
        color: StaffModule._softSurface(context, blend: 0.26),
        borderRadius: BorderRadius.circular(16),
        border:
            isToday
                ? Border.all(color: theme.colorScheme.primary.withOpacity(0.28))
                : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(header, style: theme.textTheme.labelLarge),
                ),
                IconButton(
                  tooltip: 'Aggiungi turno',
                  onPressed: onAddShift,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (shifts.isEmpty)
              Text('Nessun turno', style: theme.textTheme.bodySmall)
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    shifts
                        .map(
                          (shift) => _ShiftWeekChip(
                            shift: shift,
                            roomName: roomNames[shift.roomId],
                            onEdit: () => onEditShift(shift),
                            onDelete: () => onDeleteShift(shift),
                          ),
                        )
                        .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShiftWeekChip extends StatelessWidget {
  const _ShiftWeekChip({
    required this.shift,
    required this.roomName,
    required this.onEdit,
    required this.onDelete,
  });

  final Shift shift;
  final String? roomName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static final DateFormat _timeLabel = StaffModule._timeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeRange =
        '${_timeLabel.format(shift.start)} - ${_timeLabel.format(shift.end)}';
    final startLabel = _timeLabel.format(shift.start);
    final endLabel = _timeLabel.format(shift.end);

    final tooltipLines = <String>[
      StaffModule._dayLabel.format(shift.start),
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
        label: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(startLabel, style: theme.textTheme.labelSmall),
            Text(endLabel, style: theme.textTheme.labelSmall),
          ],
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        onPressed: onEdit,
        onDeleted: onDelete,
      ),
    );
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

class _AbsenceRequestAdminTile extends StatelessWidget {
  const _AbsenceRequestAdminTile({
    required this.request,
    this.onApprove,
    this.onReject,
  });

  final StaffAbsenceRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  static final _dayLabel = StaffModule._dayLabel;

  IconData get _icon {
    switch (request.type) {
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
    final startLabel = _dayLabel.format(request.start);
    final endLabel = _dayLabel.format(request.end);
    final isSingleDay = startLabel == endLabel;
    final isAllDay =
        request.start.hour == 0 &&
        request.start.minute == 0 &&
        request.end.hour == 23 &&
        request.end.minute == 59;
    final timeLabel =
        '${StaffModule._timeLabel.format(request.start)} - ${StaffModule._timeLabel.format(request.end)}';
    final range =
        isSingleDay
            ? (isAllDay ? startLabel : '$startLabel\n$timeLabel')
            : isAllDay
            ? '$startLabel → $endLabel'
            : '$startLabel → $endLabel\n$timeLabel';
    final notes = request.notes?.trim();
    final adminNote = request.adminNote?.trim();
    final showNotes = notes != null && notes.isNotEmpty;
    final showAdminNote = adminNote != null && adminNote.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.type.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(range, style: Theme.of(context).textTheme.bodySmall),
                if (showNotes) ...[
                  const SizedBox(height: 4),
                  Text(notes, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (showAdminNote) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Nota admin: $adminNote',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _absenceRequestStatusChip(request.status, context),
              if (onApprove != null || onReject != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (onApprove != null)
                      TextButton(
                        onPressed: onApprove,
                        child: const Text('Approva'),
                      ),
                    if (onReject != null)
                      TextButton(
                        onPressed: onReject,
                        child: const Text('Rifiuta'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

Widget _absenceRequestStatusChip(
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
