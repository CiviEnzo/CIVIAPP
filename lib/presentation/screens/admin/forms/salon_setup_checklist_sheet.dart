import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/salon_setup_progress.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_loyalty_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_operations_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_profile_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_social_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_equipment_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_rooms_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SalonSetupChecklistDialog extends StatelessWidget {
  const SalonSetupChecklistDialog({super.key, required this.salonId});

  final String salonId;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = (mediaQuery.size.width - 48).clamp(360.0, 720.0).toDouble();
    final height =
        (mediaQuery.size.height - 120).clamp(420.0, 640.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: SizedBox(
          width: width,
          height: height,
          child: SalonSetupChecklistSheet(salonId: salonId),
        ),
      ),
    );
  }
}

class SalonSetupChecklistSheet extends ConsumerStatefulWidget {
  const SalonSetupChecklistSheet({super.key, required this.salonId});

  final String salonId;

  @override
  ConsumerState<SalonSetupChecklistSheet> createState() =>
      _SalonSetupChecklistSheetState();
}

class _SalonSetupChecklistSheetState
    extends ConsumerState<SalonSetupChecklistSheet> {
  bool _isProcessing = false;

  Future<void> _markItemInProgress(String key) async {
    try {
      await ref
          .read(appDataProvider.notifier)
          .markSalonSetupItemInProgress(salonId: widget.salonId, itemKey: key);
    } catch (_) {
      // Silently ignore errors to avoid blocking the flow.
    }
  }

  Future<void> _markItemCompleted(
    String key, {
    Map<String, dynamic>? metadata,
    bool markRequiredCompleted = false,
    bool? pendingReminder,
    bool mergeMetadata = true,
  }) async {
    try {
      await ref
          .read(appDataProvider.notifier)
          .markSalonSetupItemCompleted(
            salonId: widget.salonId,
            itemKey: key,
            metadata: metadata,
            markRequiredCompleted: markRequiredCompleted ? true : null,
            pendingReminder: pendingReminder,
            mergeMetadata: mergeMetadata,
          );
    } catch (_) {
      // Silently ignore errors; UI will reflect eventual backend sync.
    }
  }

  Future<void> _updateSalon(Salon updated) async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(appDataProvider.notifier).upsertSalon(updated);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _editProfile(BuildContext context, Salon salon) async {
    await _markItemInProgress(SetupChecklistKeys.profile);
    final updated = await showAppModalSheet<Salon>(
      context: context,
      builder: (ctx) => SalonProfileSheet(salon: salon),
    );
    if (updated != null) {
      await _updateSalon(updated);
      await _markItemCompleted(
        SetupChecklistKeys.profile,
        metadata: {
          'hasAddress': updated.address.trim().isNotEmpty,
          'hasDescription': (updated.description ?? '').trim().isNotEmpty,
        },
      );
    }
  }

  bool _isItemSkipped(AdminSetupProgress? progress, String key) {
    final metadata = progress?.itemForKey(key)?.metadata;
    if (metadata == null) {
      return false;
    }
    final value = metadata['skipped'];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  Future<void> _skipItem(String key) async {
    if (_isProcessing) {
      return;
    }
    setState(() => _isProcessing = true);
    try {
      await ref
          .read(appDataProvider.notifier)
          .markSalonSetupItemCompleted(
            salonId: widget.salonId,
            itemKey: key,
            metadata: const {'skipped': true},
            pendingReminder: false,
          );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _confirmSkip(
    BuildContext context,
    String key, {
    required String sectionLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Completa senza configurare'),
            content: Text(
              'Confermi di contrassegnare "$sectionLabel" come completato senza '
              'configurarlo? Potrai sempre aggiornarlo in seguito.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).maybePop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).maybePop(true),
                child: const Text('Conferma'),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      await _skipItem(key);
    }
  }

  Future<void> _editOperations(BuildContext context, Salon salon) async {
    await _markItemInProgress(SetupChecklistKeys.operations);
    final updated = await showAppModalSheet<Salon>(
      context: context,
      builder: (ctx) => SalonOperationsSheet(salon: salon),
    );
    if (updated != null) {
      await _updateSalon(updated);
      await _markItemCompleted(
        SetupChecklistKeys.operations,
        metadata: {
          'hasSchedule': updated.schedule.any((entry) => entry.isOpen),
          'status': updated.status.name,
        },
        markRequiredCompleted: true,
      );
    }
  }

  Future<void> _editEquipment(BuildContext context, Salon salon) async {
    await _markItemInProgress(SetupChecklistKeys.equipment);
    final updated = await showAppModalSheet<List<SalonEquipment>>(
      context: context,
      builder: (ctx) => SalonEquipmentSheet(initialEquipment: salon.equipment),
    );
    if (updated != null) {
      final nextSalon = salon.copyWith(equipment: updated);
      await _updateSalon(nextSalon);
      await _markItemCompleted(
        SetupChecklistKeys.equipment,
        metadata: {'count': updated.length, 'skipped': updated.isEmpty},
      );
    }
  }

  Future<void> _editRooms(BuildContext context, Salon salon) async {
    await _markItemInProgress(SetupChecklistKeys.rooms);
    final updated = await showAppModalSheet<List<SalonRoom>>(
      context: context,
      builder: (ctx) => SalonRoomsSheet(initialRooms: salon.rooms),
    );
    if (updated != null) {
      final nextSalon = salon.copyWith(rooms: updated);
      await _updateSalon(nextSalon);
      await _markItemCompleted(
        SetupChecklistKeys.rooms,
        metadata: {'count': updated.length, 'skipped': updated.isEmpty},
      );
    }
  }

  Future<void> _editLoyalty(BuildContext context, Salon salon) async {
    await _markItemInProgress(SetupChecklistKeys.loyalty);
    final updated = await showAppModalSheet<Salon>(
      context: context,
      builder: (ctx) => SalonLoyaltySheet(salon: salon),
    );
    if (updated != null) {
      await _updateSalon(updated);
      await _markItemCompleted(
        SetupChecklistKeys.loyalty,
        metadata: {
          'enabled': updated.loyaltySettings.enabled,
          'skipped': !updated.loyaltySettings.enabled,
        },
      );
    }
  }

  Future<void> _editSocial(BuildContext context, Salon salon) async {
    await _markItemInProgress(SetupChecklistKeys.social);
    final updated = await showAppModalSheet<Salon>(
      context: context,
      builder: (ctx) => SalonSocialSheet(salon: salon),
    );
    if (updated != null) {
      await _updateSalon(updated);
      await _markItemCompleted(
        SetupChecklistKeys.social,
        metadata: {
          'count': updated.socialLinks.length,
          'skipped': updated.socialLinks.isEmpty,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final salons = ref.watch(appDataProvider).salons;
    final salon = salons.firstWhere(
      (element) => element.id == widget.salonId,
      orElse:
          () => const Salon(
            id: '',
            name: '',
            address: '',
            city: '',
            phone: '',
            email: '',
          ),
    );

    if (salon.id.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final progress = ref.watch(salonSetupProgressProvider(widget.salonId));
    final items = _buildChecklistItems(context, salon, progress);
    final completedCount = items.where((item) => item.isCompleted).length;
    final totalCount = items.length;
    final progressValue = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final pendingReminder = progress?.pendingReminder ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Completa la configurazione',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Chiudi',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hai creato il salone. Completa le aree seguenti per attivare tutte le funzionalità.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (_isProcessing) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],
          Container(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avanzamento checklist',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progressValue.clamp(0.0, 1.0),
                        minHeight: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$completedCount/$totalCount',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (pendingReminder) ...[
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ti restano ancora attività da completare prima di chiudere il setup.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = items[index];
                final statusColor = _checklistStatusColor(context, item.status);
                final statusLabel = _checklistStatusLabel(item.status);
                final trailingIcon = _checklistStatusIcon(item.status);
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.3),
                  leading: Icon(item.icon, color: statusColor),
                  title: Text(item.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.description),
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.note != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.note!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                      if (item.skipAction != null && item.skipLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: item.skipAction,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(item.skipLabel!),
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Icon(trailingIcon, color: statusColor),
                  onTap: item.onTap,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Salta per ora'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_ChecklistItem> _buildChecklistItems(
    BuildContext context,
    Salon salon,
    AdminSetupProgress? progress,
  ) {
    final profileCompleted =
        salon.address.trim().isNotEmpty || salon.city.trim().isNotEmpty;
    final operationsCompleted =
        salon.schedule.any((e) => e.isOpen) || salon.closures.isNotEmpty;
    final equipmentSkipped = _isItemSkipped(
      progress,
      SetupChecklistKeys.equipment,
    );
    final roomsSkipped = _isItemSkipped(progress, SetupChecklistKeys.rooms);
    final loyaltySkipped = _isItemSkipped(progress, SetupChecklistKeys.loyalty);
    final socialSkipped = _isItemSkipped(progress, SetupChecklistKeys.social);
    final equipmentCompleted = equipmentSkipped || salon.equipment.isNotEmpty;
    final roomsCompleted = roomsSkipped || salon.rooms.isNotEmpty;
    final loyaltyCompleted = loyaltySkipped || salon.loyaltySettings.enabled;
    final socialCompleted = socialSkipped || salon.socialLinks.isNotEmpty;
    SetupChecklistStatus statusFor(String key, bool fallbackCompleted) {
      final item = progress?.itemForKey(key);
      if (item != null) {
        return item.status;
      }
      final snapshotStatus = salon.setupChecklist[key];
      if (snapshotStatus != null) {
        return snapshotStatus;
      }
      return fallbackCompleted
          ? SetupChecklistStatus.completed
          : SetupChecklistStatus.notStarted;
    }

    return [
      _ChecklistItem(
        key: SetupChecklistKeys.profile,
        title: 'Profilo e indirizzo',
        description: 'Aggiungi indirizzo, descrizione e coordinate.',
        icon: Icons.home_work_rounded,
        status: statusFor(SetupChecklistKeys.profile, profileCompleted),
        onTap: () => _editProfile(context, salon),
      ),
      _ChecklistItem(
        key: SetupChecklistKeys.operations,
        title: 'Operatività',
        description: 'Imposta orari di apertura, chiusure e visibilità card.',
        icon: Icons.settings_applications_rounded,
        status: statusFor(SetupChecklistKeys.operations, operationsCompleted),
        onTap: () => _editOperations(context, salon),
      ),
      _ChecklistItem(
        key: SetupChecklistKeys.equipment,
        title: 'Macchinari',
        description: 'Registra i macchinari disponibili nel salone.',
        icon: Icons.precision_manufacturing_rounded,
        status: statusFor(SetupChecklistKeys.equipment, equipmentCompleted),
        note: equipmentSkipped ? 'Completato senza configurazione' : null,
        onTap: () => _editEquipment(context, salon),
        skipLabel: 'Completa senza configurare',
        skipAction:
            equipmentSkipped || _isProcessing
                ? null
                : () => _confirmSkip(
                  context,
                  SetupChecklistKeys.equipment,
                  sectionLabel: 'Macchinari',
                ),
      ),
      _ChecklistItem(
        key: SetupChecklistKeys.rooms,
        title: 'Cabine e stanze',
        description: 'Configura cabine e relative capienze.',
        icon: Icons.meeting_room_rounded,
        status: statusFor(SetupChecklistKeys.rooms, roomsCompleted),
        note: roomsSkipped ? 'Completato senza configurazione' : null,
        onTap: () => _editRooms(context, salon),
        skipLabel: 'Completa senza configurare',
        skipAction:
            roomsSkipped || _isProcessing
                ? null
                : () => _confirmSkip(
                  context,
                  SetupChecklistKeys.rooms,
                  sectionLabel: 'Cabine e stanze',
                ),
      ),
      _ChecklistItem(
        key: SetupChecklistKeys.loyalty,
        title: 'Programma fedeltà',
        description: 'Definisci regole di accrual e redemption dei punti.',
        icon: Icons.loyalty_rounded,
        status: statusFor(SetupChecklistKeys.loyalty, loyaltyCompleted),
        note: loyaltySkipped ? 'Completato senza configurazione' : null,
        onTap: () => _editLoyalty(context, salon),
        skipLabel: 'Completa senza configurare',
        skipAction:
            loyaltySkipped || _isProcessing
                ? null
                : () => _confirmSkip(
                  context,
                  SetupChecklistKeys.loyalty,
                  sectionLabel: 'Programma fedeltà',
                ),
      ),
      _ChecklistItem(
        key: SetupChecklistKeys.social,
        title: 'Presenza online & social',
        description: 'Aggiungi i link ai canali social.',
        icon: Icons.alternate_email_rounded,
        status: statusFor(SetupChecklistKeys.social, socialCompleted),
        note: socialSkipped ? 'Completato senza configurazione' : null,
        onTap: () => _editSocial(context, salon),
        skipLabel: 'Completa senza configurare',
        skipAction:
            socialSkipped || _isProcessing
                ? null
                : () => _confirmSkip(
                  context,
                  SetupChecklistKeys.social,
                  sectionLabel: 'Presenza online & social',
                ),
      ),
    ];
  }
}

class _ChecklistItem {
  const _ChecklistItem({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    this.onTap,
    this.note,
    this.skipLabel,
    this.skipAction,
  });

  final String key;
  final String title;
  final String description;
  final IconData icon;
  final SetupChecklistStatus status;
  final VoidCallback? onTap;
  final String? note;
  final String? skipLabel;
  final VoidCallback? skipAction;

  bool get isCompleted => status == SetupChecklistStatus.completed;
}

Color _checklistStatusColor(BuildContext context, SetupChecklistStatus status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case SetupChecklistStatus.completed:
      return scheme.primary;
    case SetupChecklistStatus.inProgress:
      return scheme.tertiary;
    case SetupChecklistStatus.postponed:
      return scheme.secondary;
    case SetupChecklistStatus.notStarted:
      return scheme.onSurfaceVariant;
  }
}

IconData _checklistStatusIcon(SetupChecklistStatus status) {
  switch (status) {
    case SetupChecklistStatus.completed:
      return Icons.check_circle_rounded;
    case SetupChecklistStatus.inProgress:
      return Icons.timelapse_rounded;
    case SetupChecklistStatus.postponed:
      return Icons.snooze_rounded;
    case SetupChecklistStatus.notStarted:
      return Icons.radio_button_unchecked;
  }
}

String _checklistStatusLabel(SetupChecklistStatus status) {
  switch (status) {
    case SetupChecklistStatus.completed:
      return 'Completato';
    case SetupChecklistStatus.inProgress:
      return 'In corso';
    case SetupChecklistStatus.postponed:
      return 'Posticipato';
    case SetupChecklistStatus.notStarted:
      return 'Da iniziare';
  }
}
