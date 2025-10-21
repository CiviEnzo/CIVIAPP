import 'dart:async';

import 'package:civiapp/app/providers.dart';
import 'package:civiapp/data/models/app_user.dart';
import 'package:civiapp/domain/entities/loyalty_settings.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/domain/entities/salon_setup_progress.dart';
import 'package:civiapp/domain/entities/user_role.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/admin_theme.dart';
import 'package:civiapp/presentation/screens/admin/forms/salon_create_essential_dialog.dart';
import 'package:civiapp/presentation/screens/admin/forms/salon_equipment_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/salon_profile_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/salon_operations_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/salon_rooms_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/salon_loyalty_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/salon_social_sheet.dart';
import 'package:civiapp/presentation/screens/admin/forms/salon_setup_checklist_sheet.dart';
import 'package:civiapp/services/whatsapp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SalonManagementModule extends ConsumerWidget {
  const SalonManagementModule({super.key, this.selectedSalonId});

  final String? selectedSalonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final data = ref.watch(appDataProvider);
    final theme = Theme.of(context);
    final allSalons = data.salons;
    final availableSalonIds = session.availableSalonIds.toSet();
    final salons =
        availableSalonIds.isEmpty
            ? allSalons
            : allSalons
                .where((salon) => availableSalonIds.contains(salon.id))
                .toList(growable: false);

    if (salons.isEmpty) {
      if (session.selectedSalonId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(sessionControllerProvider.notifier).setSalon(null);
        });
      }
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
              onPressed: () => _startCreateFlow(context, ref),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Crea salone'),
            ),
          ],
        ),
      );
    }

    final currentSalonId = session.selectedSalonId;
    String? effectiveSalonId = currentSalonId ?? selectedSalonId;
    if (effectiveSalonId != null &&
        !salons.any((salon) => salon.id == effectiveSalonId)) {
      effectiveSalonId = salons.first.id;
      if (effectiveSalonId != currentSalonId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(sessionControllerProvider.notifier).setSalon(effectiveSalonId);
        });
      }
    } else if (effectiveSalonId == null && salons.length == 1) {
      effectiveSalonId = salons.first.id;
      if (effectiveSalonId != currentSalonId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(sessionControllerProvider.notifier).setSalon(effectiveSalonId);
        });
      }
    }
    final selected =
        effectiveSalonId == null
            ? salons
            : salons.where((salon) => salon.id == effectiveSalonId).toList();

    Widget? salonSelector;
    if (salons.length > 1) {
      salonSelector = DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: effectiveSalonId,
          hint: const Text('Tutti i saloni'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Tutti i saloni'),
            ),
            ...salons.map(
              (salon) => DropdownMenuItem<String?>(
                value: salon.id,
                child: Text(salon.name),
              ),
            ),
          ],
          onChanged: (value) {
            ref.read(sessionControllerProvider.notifier).setSalon(value);
          },
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => _startCreateFlow(context, ref),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Nuovo salone'),
            ),
            if (salonSelector != null) ...[
              const Spacer(),
              Flexible(child: Align(alignment: Alignment.centerRight, child: salonSelector)),
            ],
          ],
        ),
        const SizedBox(height: 24),
        for (final salon in selected) ...[
          _SalonDashboard(salon: salon),
          const SizedBox(height: 32),
        ],
      ],
    );
  }
}

class _SalonDashboard extends ConsumerWidget {
  const _SalonDashboard({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(salonSetupProgressProvider(salon.id));
    final progressItems = progress?.items ?? const <SetupChecklistItem>[];
    final filteredProgressItems = progressItems
        .where((item) => SetupChecklistKeys.defaults.contains(item.key))
        .toList(growable: false);
    final completedItems =
        filteredProgressItems.isNotEmpty
            ? filteredProgressItems
                .where((item) => item.status == SetupChecklistStatus.completed)
                .length
            : salon.setupChecklist.values
                .where((status) => status == SetupChecklistStatus.completed)
                .length;
    final totalItems =
        filteredProgressItems.isNotEmpty
            ? filteredProgressItems.length
            : (salon.setupChecklist.isNotEmpty
                ? salon.setupChecklist.length
                : SetupChecklistKeys.defaults.length);
    final pendingReminder =
        (progress?.pendingReminder ?? false) &&
        filteredProgressItems.any(
          (item) => item.status != SetupChecklistStatus.completed,
        );

    Future<void> _openChecklist() async {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => SalonSetupChecklistDialog(salonId: salon.id),
      );
    }

    Future<void> _handleProfileEdit() async {
      final store = ref.read(appDataProvider.notifier);
      await store.markSalonSetupItemInProgress(
        salonId: salon.id,
        itemKey: SetupChecklistKeys.profile,
      );
      final updated = await showAppModalSheet<Salon>(
        context: context,
        builder: (ctx) => SalonProfileSheet(salon: salon),
      );
      if (updated != null) {
        await store.upsertSalon(updated);
        await store.markSalonSetupItemCompleted(
          salonId: salon.id,
          itemKey: SetupChecklistKeys.profile,
          metadata: {
            'hasAddress': updated.address.trim().isNotEmpty,
            'hasDescription': (updated.description ?? '').trim().isNotEmpty,
          },
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendingReminder) ...[
          _SetupReminderBanner(
            completed: completedItems,
            total: totalItems,
            onTap: _openChecklist,
          ),
          const SizedBox(height: 16),
        ],
        _SalonOverviewCard(salon: salon, onEdit: _handleProfileEdit),
        const SizedBox(height: 16),
        _SalonOperationsOverviewCard(salon: salon),
        const SizedBox(height: 16),
        _ResponsiveCardWrap(
          items: [
            _ResponsiveCardItem(
              span: 2,
              child: _StripeConnectCard(salon: salon),
            ),
            _ResponsiveCardItem(
              span: 2,
              child: _WhatsAppSettingsCard(salonId: salon.id),
            ),
            if (salon.closures.isNotEmpty)
              _ResponsiveCardItem(
                child: _ClosuresCard(closures: salon.closures),
              ),
          ],
        ),
      ],
    );
  }
}

class _SetupReminderBanner extends StatelessWidget {
  const _SetupReminderBanner({
    required this.completed,
    required this.total,
    required this.onTap,
  });

  final int completed;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressValue = total == 0 ? 0.0 : completed / total;

    return Card(
      color: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Completa il setup del salone',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text('$completed/$total', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progressValue.clamp(0.0, 1.0),
              minHeight: 4,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Alcune sezioni richiedono ancora configurazione.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(onPressed: onTap, child: const Text('Completa ora')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SalonOverviewCard extends StatelessWidget {
  const _SalonOverviewCard({required this.salon, required this.onEdit});

  final Salon salon;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final contactChips = <Widget>[
      _InfoBadge(icon: Icons.phone, label: salon.phone),
      _InfoBadge(icon: Icons.email, label: salon.email),
    ];
    if (salon.postalCode != null && salon.postalCode!.isNotEmpty) {
      contactChips.add(
        _InfoBadge(
          icon: Icons.local_post_office_rounded,
          label: 'CAP ${salon.postalCode}',
        ),
      );
    }
    if (salon.latitude != null && salon.longitude != null) {
      contactChips.add(
        _InfoBadge(
          icon: Icons.location_on_rounded,
          label:
              '${salon.latitude!.toStringAsFixed(4)}, ${salon.longitude!.toStringAsFixed(4)}',
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                      Text(salon.name, style: textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        '${salon.address}, ${salon.city}',
                        style: textTheme.bodyLarge,
                      ),
                      if (salon.description != null &&
                          salon.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(salon.description!, style: textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusChip(status: salon.status),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifica dettagli'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, children: contactChips),
            if (salon.bookingLink != null && salon.bookingLink!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Tooltip(
                message: salon.bookingLink!,
                child: TextButton.icon(
                  onPressed:
                      () => launchUrl(
                        Uri.parse(salon.bookingLink!),
                        mode: LaunchMode.externalApplication,
                      ),
                  icon: const Icon(Icons.link),
                  label: const Text('Apri pagina prenotazioni'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SalonOperationsOverviewCard extends ConsumerWidget {
  const _SalonOperationsOverviewCard({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final adminTheme = AdminTheme.of(context);
    final textTheme = theme.textTheme;
    final data = ref.watch(appDataProvider);
    final staffCount =
        data.staff.where((member) => member.salonId == salon.id).length;
    final clientsCount =
        data.clients.where((client) => client.salonId == salon.id).length;
    final upcomingCount =
        data.appointments
            .where(
              (appointment) =>
                  appointment.salonId == salon.id &&
                  appointment.start.isAfter(DateTime.now()),
            )
            .length;

    Future<void> updateSections(SalonDashboardSections newPrefs) async {
      await ref
          .read(appDataProvider.notifier)
          .upsertSalon(salon.copyWith(dashboardSections: newPrefs));
    }

    Future<void> editOperationsAsync() async {
      final store = ref.read(appDataProvider.notifier);
      final updated = await showAppModalSheet<Salon>(
        context: context,
        builder: (ctx) => SalonOperationsSheet(salon: salon),
      );
      if (updated == null) {
        return;
      }
      await store.upsertSalon(updated);
      await store.markSalonSetupItemCompleted(
        salonId: salon.id,
        itemKey: SetupChecklistKeys.operations,
        metadata: {
          'hasSchedule': updated.schedule.any((entry) => entry.isOpen),
          'status': updated.status.name,
        },
        markRequiredCompleted: true,
      );
    }

    Future<void> editEquipmentAsync() async {
      final store = ref.read(appDataProvider.notifier);
      final updated = await showAppModalSheet<List<SalonEquipment>>(
        context: context,
        builder:
            (ctx) => SalonEquipmentSheet(initialEquipment: salon.equipment),
      );
      if (updated == null) {
        return;
      }
      final nextSalon = salon.copyWith(equipment: updated);
      await store.upsertSalon(nextSalon);
      await store.markSalonSetupItemCompleted(
        salonId: salon.id,
        itemKey: SetupChecklistKeys.equipment,
        metadata: {'count': updated.length},
      );
    }

    Future<void> editRoomsAsync() async {
      final store = ref.read(appDataProvider.notifier);
      final updated = await showAppModalSheet<List<SalonRoom>>(
        context: context,
        builder: (ctx) => SalonRoomsSheet(initialRooms: salon.rooms),
      );
      if (updated == null) {
        return;
      }
      final nextSalon = salon.copyWith(rooms: updated);
      await store.upsertSalon(nextSalon);
      await store.markSalonSetupItemCompleted(
        salonId: salon.id,
        itemKey: SetupChecklistKeys.rooms,
        metadata: {'count': updated.length},
      );
    }

    Future<void> editSocialAsync() async {
      final store = ref.read(appDataProvider.notifier);
      final updated = await showAppModalSheet<Salon>(
        context: context,
        builder: (ctx) => SalonSocialSheet(salon: salon),
      );
      if (updated == null) {
        return;
      }
      await store.upsertSalon(updated);
      await store.markSalonSetupItemCompleted(
        salonId: salon.id,
        itemKey: SetupChecklistKeys.social,
        metadata: {'count': updated.socialLinks.length},
      );
    }

    Future<void> editLoyaltyAsync() async {
      final store = ref.read(appDataProvider.notifier);
      final updated = await showAppModalSheet<Salon>(
        context: context,
        builder: (ctx) => SalonLoyaltySheet(salon: salon),
      );
      if (updated == null) {
        return;
      }
      await store.upsertSalon(updated);
      await store.markSalonSetupItemCompleted(
        salonId: salon.id,
        itemKey: SetupChecklistKeys.loyalty,
        metadata: {'enabled': updated.loyaltySettings.enabled},
      );
    }

    void onEditOperations() {
      unawaited(editOperationsAsync());
    }

    void onEditEquipment() {
      unawaited(editEquipmentAsync());
    }

    void onEditRooms() {
      unawaited(editRoomsAsync());
    }

    void onEditSocial() {
      unawaited(editSocialAsync());
    }

    void onEditLoyalty() {
      unawaited(editLoyaltyAsync());
    }

    Future<void> showSectionsFilter() async {
      var prefsDraft = salon.dashboardSections;
      await showAppModalSheet<void>(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: StatefulBuilder(
                builder: (ctx, setModalState) {
                  Widget buildToggle({
                    required String title,
                    required String subtitle,
                    required bool value,
                    required SalonDashboardSections Function(
                      SalonDashboardSections,
                    )
                    updater,
                  }) {
                    return SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(title),
                      subtitle: Text(subtitle),
                      value: value,
                      onChanged: (enabled) {
                        final updated = updater(prefsDraft);
                        setModalState(() => prefsDraft = updated);
                        updateSections(updated);
                      },
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.filter_list_rounded, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              'Personalizza card visibili',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        buildToggle(
                          title: 'KPI giornalieri',
                          subtitle: 'Staff, clienti e appuntamenti futuri',
                          value: prefsDraft.showKpis,
                          updater:
                              (prefs) =>
                                  prefs.copyWith(showKpis: !prefs.showKpis),
                        ),
                        buildToggle(
                          title: 'Stato operativo',
                          subtitle: 'Stato salone, slot orari e overview',
                          value: prefsDraft.showOperational,
                          updater:
                              (prefs) => prefs.copyWith(
                                showOperational: !prefs.showOperational,
                              ),
                        ),
                        buildToggle(
                          title: 'Macchinari',
                          subtitle: 'Elenco macchinari e stato operativo',
                          value: prefsDraft.showEquipment,
                          updater:
                              (prefs) => prefs.copyWith(
                                showEquipment: !prefs.showEquipment,
                              ),
                        ),
                        buildToggle(
                          title: 'Cabine e stanze',
                          subtitle: 'Disponibilità e capienza',
                          value: prefsDraft.showRooms,
                          updater:
                              (prefs) =>
                                  prefs.copyWith(showRooms: !prefs.showRooms),
                        ),
                        buildToggle(
                          title: 'Programma fedeltà',
                          subtitle: 'Regole e configurazione punti',
                          value: prefsDraft.showLoyalty,
                          updater:
                              (prefs) => prefs.copyWith(
                                showLoyalty: !prefs.showLoyalty,
                              ),
                        ),
                        buildToggle(
                          title: 'Presenza online e social',
                          subtitle: 'Canali social collegati',
                          value: prefsDraft.showSocial,
                          updater:
                              (prefs) =>
                                  prefs.copyWith(showSocial: !prefs.showSocial),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
    }

    final equipmentChildren =
        salon.equipment.isEmpty
            ? [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Nessun macchinario configurato.',
                  style: textTheme.bodyMedium,
                ),
              ),
            ]
            : salon.equipment.map((item) {
              final color = _equipmentStatusColor(context, item.status);
              return _DataRowTile(
                leadingIcon: Icons.precision_manufacturing_rounded,
                leadingColor: color,
                label: item.name,
                value: '${item.quantity}x · ${item.status.label}',
                tooltip: item.notes,
              );
            }).toList();

    final roomsChildren =
        salon.rooms.isEmpty
            ? [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Nessuna cabina configurata.',
                  style: textTheme.bodyMedium,
                ),
              ),
            ]
            : salon.rooms
                .map(
                  (room) => _DataRowTile(
                    leadingIcon: Icons.meeting_room_rounded,
                    label: room.name,
                    value: 'Capienza ${room.capacity}',
                  ),
                )
                .toList();

    final loyaltyChildren =
        salon.loyaltySettings.enabled
            ? <Widget>[
              _DataRowTile(
                leadingIcon: Icons.verified_outlined,
                label: 'Stato programma',
                value: 'Attivo',
              ),
              _DataRowTile(
                leadingIcon: Icons.star_rate_rounded,
                label: 'Saldo iniziale clienti',
                value: '${salon.loyaltySettings.initialBalance} pt',
              ),
              _DataRowTile(
                leadingIcon: Icons.trending_up_rounded,
                label:
                    'Earning: 1 punto ogni ${salon.loyaltySettings.earning.euroPerPoint.toStringAsFixed(0)} €',
                value: _loyaltyRoundingLabel(
                  salon.loyaltySettings.earning.rounding,
                ),
              ),
              _DataRowTile(
                leadingIcon: Icons.redeem_rounded,
                label:
                    'Redemption: ${salon.loyaltySettings.redemption.pointValueEuro.toStringAsFixed(2)} € per punto',
                value:
                    'Max ${(salon.loyaltySettings.redemption.maxPercent * 100).toStringAsFixed(0)}%',
              ),
              _DataRowTile(
                leadingIcon: Icons.lightbulb_outline_rounded,
                label: 'Suggerimento automatico',
                value:
                    salon.loyaltySettings.redemption.autoSuggest
                        ? 'Abilitato'
                        : 'Disabilitato',
              ),
              _DataRowTile(
                leadingIcon: Icons.event_repeat_rounded,
                label: 'Reset annuale punti',
                value:
                    '${salon.loyaltySettings.expiration.resetDay.toString().padLeft(2, '0')}/${salon.loyaltySettings.expiration.resetMonth.toString().padLeft(2, '0')} (${salon.loyaltySettings.expiration.timezone})',
              ),
            ]
            : <Widget>[
              _DataRowTile(
                leadingIcon: Icons.loyalty_rounded,
                label: 'Stato programma',
                value: 'Non abilitato',
              ),
            ];

    final socialChildren =
        salon.socialLinks.isEmpty
            ? [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Nessun canale social collegato.',
                  style: textTheme.bodyMedium,
                ),
              ),
            ]
            : <Widget>[
              _DataRowTile(
                leadingIcon: Icons.public_rounded,
                label: 'Canali collegati',
                value: salon.socialLinks.length.toString(),
              ),
              ...salon.socialLinks.entries.map(
                (entry) => _DataRowTile(
                  leadingIcon: _socialIconFor(entry.key),
                  label: entry.key,
                  value: entry.value,
                  tooltip: entry.value,
                ),
              ),
            ];

    final prefs = salon.dashboardSections;
    final sectionWidgets = <Widget>[];
    final highlightedCardColor = adminTheme.layer(2);
    final highlightedShadowColor = adminTheme.mediumShadowColor;
    final highlightedElevation = adminTheme.baseCardElevation + 2;

    if (prefs.showKpis) {
      sectionWidgets.add(
        _SectionBlock(
          title: 'KPI giornalieri',
          icon: Icons.analytics_rounded,
          backgroundColor: highlightedCardColor,
          shadowColor: highlightedShadowColor,
          elevation: highlightedElevation,
          children: [
            _DataRowTile(
              leadingIcon: Icons.groups_rounded,
              label: 'Staff attivo',
              value: staffCount.toString(),
            ),
            _DataRowTile(
              leadingIcon: Icons.people_alt_rounded,
              label: 'Clienti associati',
              value: clientsCount.toString(),
            ),
            _DataRowTile(
              leadingIcon: Icons.event_available_rounded,
              label: 'Appuntamenti futuri',
              value: upcomingCount.toString(),
            ),
          ],
        ),
      );
    }

    if (prefs.showOperational) {
      sectionWidgets.add(
        _SectionBlock(
          title: 'Stato operativo',
          icon: Icons.settings_input_component_rounded,
          onEdit: onEditOperations,
          editLabel: 'Gestisci operatività',
          backgroundColor: highlightedCardColor,
          shadowColor: highlightedShadowColor,
          elevation: highlightedElevation,
          children: [
            _DataRowTile(
              leadingIcon: _statusIcon(salon.status),
              leadingColor: _statusColor(context, salon.status),
              label: 'Stato salone',
              value: salon.status.label,
            ),
            _DataRowTile(
              leadingIcon: Icons.schedule_rounded,
              label: 'Slot orari configurati',
              value: salon.schedule.length.toString(),
            ),
            _DataRowTile(
              leadingIcon: Icons.precision_manufacturing_rounded,
              label: 'Macchinari',
              value: salon.equipment.length.toString(),
            ),
            _DataRowTile(
              leadingIcon: Icons.meeting_room_rounded,
              label: 'Cabine e stanze',
              value: salon.rooms.length.toString(),
            ),
          ],
        ),
      );
    }

    if (prefs.showEquipment) {
      sectionWidgets.add(
        _SectionBlock(
          title: 'Macchinari',
          icon: Icons.precision_manufacturing_rounded,
          onEdit: onEditEquipment,
          editLabel: 'Gestisci macchinari',
          backgroundColor: highlightedCardColor,
          shadowColor: highlightedShadowColor,
          elevation: highlightedElevation,
          children: equipmentChildren,
        ),
      );
    }

    if (prefs.showRooms) {
      sectionWidgets.add(
        _SectionBlock(
          title: 'Cabine e stanze',
          icon: Icons.meeting_room_rounded,
          onEdit: onEditRooms,
          editLabel: 'Gestisci cabine',
          backgroundColor: highlightedCardColor,
          shadowColor: highlightedShadowColor,
          elevation: highlightedElevation,
          children: roomsChildren,
        ),
      );
    }

    if (prefs.showLoyalty) {
      sectionWidgets.add(
        _SectionBlock(
          title: 'Programma fedeltà',
          icon: Icons.loyalty_rounded,
          onEdit: onEditLoyalty,
          editLabel: 'Configura fedeltà',
          backgroundColor: highlightedCardColor,
          shadowColor: highlightedShadowColor,
          elevation: highlightedElevation,
          children: loyaltyChildren,
        ),
      );
    }

    if (prefs.showSocial) {
      sectionWidgets.add(
        _SectionBlock(
          title: 'Presenza online e social',
          icon: Icons.alternate_email_rounded,
          onEdit: onEditSocial,
          editLabel: 'Gestisci social',
          backgroundColor: highlightedCardColor,
          shadowColor: highlightedShadowColor,
          elevation: highlightedElevation,
          children: socialChildren,
        ),
      );
    }

    const spacing = 20.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.dashboard_customize_rounded,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operatività e risorse',
                        style: textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Visione sintetica su stato, risorse e capacità operative del salone.',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Filtra sezioni',
                  onPressed: showSectionsFilter,
                  icon: const Icon(Icons.filter_list_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (sectionWidgets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Nessuna sezione selezionata. Aggiorna le preferenze del dashboard per mostrare i moduli di interesse.',
                  style: textTheme.bodyMedium,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final columns = _resolveColumnCount(maxWidth);
                  final itemWidth =
                      columns == 1
                          ? maxWidth
                          : (maxWidth - spacing * (columns - 1)) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children:
                        sectionWidgets
                            .map(
                              (section) => SizedBox(
                                width: columns == 1 ? maxWidth : itemWidth,
                                child: section,
                              ),
                            )
                            .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveCardWrap extends StatelessWidget {
  const _ResponsiveCardWrap({required this.items});

  final List<_ResponsiveCardItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    const spacing = 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = _resolveColumnCount(maxWidth);
        final columnWidth =
            columns == 1
                ? maxWidth
                : (maxWidth - spacing * (columns - 1)) / columns;

        final children =
            items.map((item) {
              final span = columns == 1 ? 1 : item.span.clamp(1, columns);
              final width =
                  columns == 1
                      ? maxWidth
                      : columnWidth * span + spacing * (span - 1);
              return SizedBox(width: width, child: item.child);
            }).toList();

        return Wrap(spacing: spacing, runSpacing: spacing, children: children);
      },
    );
  }
}

class _ResponsiveCardItem {
  const _ResponsiveCardItem({required this.child, this.span = 1});

  final Widget child;
  final int span;
}

int _resolveColumnCount(double maxWidth) {
  if (maxWidth >= 1280) return 3;
  if (maxWidth >= 920) return 2;
  return 1;
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.icon,
    required this.children,
    this.onEdit,
    this.editLabel,
    this.backgroundColor,
    this.shadowColor,
    this.elevation,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final VoidCallback? onEdit;
  final String? editLabel;
  final Color? backgroundColor;
  final Color? shadowColor;
  final double? elevation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final effectiveChildren = children.whereType<Widget>().toList();
    if (effectiveChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    final dividerColor = theme.dividerColor.withOpacity(0.14);

    final content = <Widget>[];
    for (var i = 0; i < effectiveChildren.length; i++) {
      content.add(effectiveChildren[i]);
      if (i < effectiveChildren.length - 1) {
        content.add(const SizedBox(height: 12));
        content.add(Divider(height: 1, color: dividerColor));
        content.add(const SizedBox(height: 12));
      }
    }

    final hasCustomColor = backgroundColor != null;
    final defaultShadow =
        theme.cardTheme.shadowColor ??
        Colors.black.withOpacity(
          theme.brightness == Brightness.dark ? 0.4 : 0.12,
        );
    final borderSide = BorderSide(
      color: theme.colorScheme.outlineVariant.withOpacity(
        hasCustomColor ? 0.22 : 0.18,
      ),
      width: 1.1,
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: hasCustomColor ? backgroundColor : null,
      elevation: elevation ?? 2,
      shadowColor: shadowColor ?? defaultShadow,
      surfaceTintColor: hasCustomColor ? Colors.transparent : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: borderSide,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(foregroundColor: primaryColor),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(editLabel ?? 'Modifica'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...content,
          ],
        ),
      ),
    );
  }
}

class _DataRowTile extends StatelessWidget {
  const _DataRowTile({
    required this.leadingIcon,
    required this.label,
    required this.value,
    this.leadingColor,
    this.tooltip,
  });

  final IconData leadingIcon;
  final String label;
  final String value;
  final Color? leadingColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveValue = value.isEmpty ? '—' : value;
    final valueText = Text(
      effectiveValue,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      textAlign: TextAlign.right,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          leadingIcon,
          size: 26,
          color: leadingColor ?? theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child:
              tooltip != null && tooltip!.isNotEmpty
                  ? Tooltip(
                    message: tooltip!,
                    waitDuration: const Duration(milliseconds: 400),
                    child: valueText,
                  )
                  : valueText,
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adminTheme = AdminTheme.of(context);
    final accentColor = adminTheme.colorScheme.secondary;
    final background = accentColor.withOpacity(
      theme.brightness == Brightness.dark ? 0.28 : 0.12,
    );
    final borderColor = accentColor.withOpacity(0.22);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: accentColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: adminTheme.colorScheme.onSecondaryContainer,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripeConnectCard extends ConsumerStatefulWidget {
  const _StripeConnectCard({required this.salon});

  final Salon salon;

  @override
  ConsumerState<_StripeConnectCard> createState() => _StripeConnectCardState();
}

class _StripeConnectCardState extends ConsumerState<_StripeConnectCard> {
  bool _isCreatingAccount = false;
  bool _isGeneratingLink = false;

  static const _defaultReturnUrl =
      'https://civiapp.app/stripe/onboarding/success';
  static const _defaultRefreshUrl =
      'https://civiapp.app/stripe/onboarding/retry';

  @override
  Widget build(BuildContext context) {
    final salon = widget.salon;
    final theme = Theme.of(context);
    final accountId = salon.stripeAccountId;
    final accountSnapshot = salon.stripeAccount;
    final chargesEnabled = accountSnapshot.chargesEnabled;
    final payoutsEnabled = accountSnapshot.payoutsEnabled;
    final detailsSubmitted = accountSnapshot.detailsSubmitted;

    final statusText =
        accountId == null
            ? 'Account non collegato'
            : chargesEnabled
            ? 'Pagamenti attivi'
            : 'In attesa di verifica';

    final statusColor =
        accountId == null
            ? theme.colorScheme.error
            : chargesEnabled
            ? theme.colorScheme.primary
            : theme.colorScheme.secondary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Pagamenti Stripe', style: theme.textTheme.titleMedium),
                const SizedBox(width: 12),
                Chip(
                  label: Text(statusText),
                  avatar: Icon(
                    chargesEnabled
                        ? Icons.verified_rounded
                        : accountId == null
                        ? Icons.warning_amber_rounded
                        : Icons.pending_actions_rounded,
                  ),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (accountId != null)
                  ActionChip(
                    avatar: const Icon(Icons.copy, size: 16),
                    label: Text(accountId),
                    tooltip: 'Copia ID account',
                    onPressed: () => _copyToClipboard(context, accountId),
                  ),
                ActionChip(
                  avatar: Icon(
                    chargesEnabled
                        ? Icons.check_circle_outline
                        : Icons.payment_rounded,
                  ),
                  label: Text(
                    chargesEnabled
                        ? 'Transazioni abilitate'
                        : 'Transazioni disabilitate',
                  ),
                  onPressed: null,
                ),
                if (accountId != null)
                  ActionChip(
                    avatar: Icon(
                      payoutsEnabled
                          ? Icons.account_balance_wallet_rounded
                          : Icons.savings_rounded,
                    ),
                    label: Text(
                      payoutsEnabled
                          ? 'Bonifici attivi'
                          : 'Bonifici da abilitare',
                    ),
                    onPressed: null,
                  ),
                if (accountId != null)
                  ActionChip(
                    avatar: Icon(
                      detailsSubmitted
                          ? Icons.assignment_turned_in_rounded
                          : Icons.assignment_late_rounded,
                    ),
                    label: Text(
                      detailsSubmitted
                          ? 'Dati fiscali completi'
                          : 'Completa l\'onboarding',
                    ),
                    onPressed: null,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (accountId == null)
                  FilledButton.icon(
                    onPressed:
                        _isCreatingAccount
                            ? null
                            : () => _handleCreateAccount(context),
                    icon:
                        _isCreatingAccount
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.link_rounded),
                    label: Text(
                      _isCreatingAccount
                          ? 'Creazione in corso...'
                          : 'Crea account Stripe Connect',
                    ),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed:
                        _isGeneratingLink
                            ? null
                            : () => _handleOnboardingLink(context),
                    icon:
                        _isGeneratingLink
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.login_rounded),
                    label: Text(
                      _isGeneratingLink
                          ? 'Generazione link...'
                          : 'Apri onboarding Stripe',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        accountId.isEmpty
                            ? null
                            : () => _copyToClipboard(context, accountId),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copia ID account'),
                  ),
                ],
                TextButton.icon(
                  onPressed:
                      () => launchUrl(
                        Uri.parse(
                          'https://support.stripe.com/questions/express-dashboard-overview',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                  icon: const Icon(Icons.help_outline_rounded),
                  label: const Text('Guida Stripe Connect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreateAccount(BuildContext context) async {
    final salon = widget.salon;
    final messenger = ScaffoldMessenger.of(context);
    final email = await _promptForEmail(context, salon.email);
    if (!mounted) {
      return;
    }
    if (email == null) {
      return;
    }
    setState(() => _isCreatingAccount = true);
    try {
      final service = ref.read(stripeConnectServiceProvider);
      await service.createAccount(email: email, salonId: salon.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Account Stripe creato per $email. Completa l\'onboarding.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Errore durante la creazione dell\'account: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingAccount = false);
      }
    }
  }

  Future<void> _handleOnboardingLink(BuildContext context) async {
    final salon = widget.salon;
    final accountId = salon.stripeAccountId;
    if (accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun account Stripe collegato.')),
      );
      return;
    }
    setState(() => _isGeneratingLink = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(stripeConnectServiceProvider);
      final url = await service.createOnboardingLink(
        salonId: salon.id,
        accountId: accountId,
        returnUrl: _defaultReturnUrl,
        refreshUrl: _defaultRefreshUrl,
      );
      if (!mounted) return;
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!launched) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Impossibile aprire il link Stripe.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Errore durante la generazione del link: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingLink = false);
      }
    }
  }

  Future<String?> _promptForEmail(
    BuildContext context,
    String? defaultEmail,
  ) async {
    final controller = TextEditingController(text: defaultEmail);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Collega Stripe Connect'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Email a cui intestare l\'account Stripe',
              ),
              autofocus: true,
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'Inserisci un indirizzo email valido';
                }
                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                if (!emailRegex.hasMatch(text)) {
                  return 'Formato email non valido';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                }
              },
              child: const Text('Continua'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('ID account copiato negli appunti')),
    );
  }
}

class _WhatsAppSettingsCard extends ConsumerStatefulWidget {
  const _WhatsAppSettingsCard({required this.salonId});

  final String salonId;

  @override
  ConsumerState<_WhatsAppSettingsCard> createState() =>
      _WhatsAppSettingsCardState();
}

class _WhatsAppSettingsCardState extends ConsumerState<_WhatsAppSettingsCard> {
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(whatsappConfigProvider(widget.salonId));

    return configAsync.when(
      data: (config) => _buildConfiguredCard(context, config),
      loading: () => _buildLoadingCard(context),
      error: (error, stack) => _buildErrorCard(context, error),
    );
  }

  Widget _buildConfiguredCard(BuildContext context, WhatsAppConfig? config) {
    final theme = Theme.of(context);
    final isConfigured = config?.isConfigured ?? false;
    final statusColor =
        isConfigured ? theme.colorScheme.primary : theme.colorScheme.secondary;
    final updatedAt = config?.updatedAt?.toLocal();
    final updatedAtLabel =
        updatedAt != null
            ? DateFormat('dd MMM yyyy HH:mm', 'it').format(updatedAt)
            : 'Mai aggiornato';

    final summaryBadges = <Widget>[
      _InfoBadge(
        icon: Icons.settings_rounded,
        label: 'Modalità ${config?.mode ?? '—'}',
      ),
      _InfoBadge(icon: Icons.history_rounded, label: 'Agg. $updatedAtLabel'),
      _InfoBadge(
        icon: Icons.phone_iphone_rounded,
        label: config?.displayPhoneNumber ?? 'Numero non collegato',
      ),
    ];

    final details = <Widget>[
      _WhatsAppDetailRow(
        icon: Icons.dns_rounded,
        label: 'Phone Number ID',
        value: config?.phoneNumberId ?? '—',
      ),
      _WhatsAppDetailRow(
        icon: Icons.business_rounded,
        label: 'Business Manager ID',
        value: _maskSecret(config?.businessId),
      ),
      _WhatsAppDetailRow(
        icon: Icons.apps_rounded,
        label: 'WABA ID',
        value: _maskSecret(config?.wabaId),
      ),
      _WhatsAppDetailRow(
        icon: Icons.vpn_key_rounded,
        label: 'Secret token',
        value: _maskSecret(config?.tokenSecretId),
      ),
      _WhatsAppDetailRow(
        icon: Icons.lock_outline_rounded,
        label: 'Verify token',
        value: _maskSecret(config?.verifyTokenSecretId),
      ),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'WhatsApp Business',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(isConfigured ? 'Collegato' : 'Da configurare'),
                  avatar: Icon(
                    isConfigured
                        ? Icons.check_circle_rounded
                        : Icons.link_off_rounded,
                    color: statusColor,
                    size: 18,
                  ),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: summaryBadges),
            const SizedBox(height: 16),
            ...details,
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed:
                      _isConnecting ? null : () => _handleConnect(context),
                  icon:
                      _isConnecting
                          ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.bolt_rounded),
                  label: Text(
                    _isConnecting
                        ? 'Apertura...'
                        : isConfigured
                        ? 'Aggiorna collegamento'
                        : 'Collega WhatsApp',
                  ),
                ),
                if (isConfigured)
                  OutlinedButton.icon(
                    onPressed:
                        _isDisconnecting
                            ? null
                            : () => _handleDisconnect(context),
                    icon:
                        _isDisconnecting
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.link_off_rounded),
                    label: Text(
                      _isDisconnecting ? 'Disconnessione...' : 'Disconnetti',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Caricamento impostazioni WhatsApp...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, Object error) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WhatsApp Business',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Impossibile recuperare la configurazione: $error',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed:
                  () => ref.invalidate(whatsappConfigProvider(widget.salonId)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConnect(BuildContext context) async {
    setState(() => _isConnecting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(whatsappServiceProvider).openOAuthFlow(widget.salonId);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Collegamento avviato: completa il flow nel browser.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Errore durante il collegamento: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _handleDisconnect(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Disconnetti WhatsApp'),
            content: const Text(
              'Il numero collegato verrà scollegato. Continuare?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Disconnetti'),
              ),
            ],
          ),
    );

    if (confirm != true || !mounted) {
      return;
    }
    setState(() => _isDisconnecting = true);
    try {
      await ref.read(whatsappServiceProvider).disconnect(widget.salonId);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Account WhatsApp scollegato.')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Errore durante la disconnessione: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isDisconnecting = false);
      }
    }
  }
}

class _ClosuresCard extends StatelessWidget {
  const _ClosuresCard({required this.closures});

  final List<SalonClosure> closures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = DateFormat('dd MMM yyyy', 'it');
    final sorted =
        closures.toList()..sort((a, b) => a.start.compareTo(b.start));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chiusure programmate', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
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
        ),
      ),
    );
  }
}

class _WhatsAppDetailRow extends StatelessWidget {
  const _WhatsAppDetailRow({
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon),
      title: Text(value),
      subtitle: Text(label, style: theme.textTheme.bodySmall),
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
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      backgroundColor: color.withValues(alpha: 0.12),
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

String _maskSecret(String? value) {
  if (value == null || value.isEmpty) {
    return '—';
  }
  if (value.length <= 6) {
    return value;
  }
  final suffix = value.substring(value.length - 4);
  return '•••$suffix';
}

IconData _socialIconFor(String label) {
  final normalized = label.toLowerCase();
  if (normalized.contains('instagram')) {
    return Icons.camera_alt_rounded;
  }
  if (normalized.contains('facebook')) {
    return Icons.facebook_rounded;
  }
  if (normalized.contains('tiktok')) {
    return Icons.play_circle_filled_rounded;
  }
  if (normalized.contains('youtube')) {
    return Icons.ondemand_video_rounded;
  }
  if (normalized.contains('linkedin')) {
    return Icons.business_center_rounded;
  }
  if (normalized.contains('twitter') || normalized.contains('x ')) {
    return Icons.chat_bubble_outline_rounded;
  }
  if (normalized.contains('whatsapp')) {
    return Icons.chat_rounded;
  }
  return Icons.link_rounded;
}

String _loyaltyRoundingLabel(LoyaltyRoundingMode mode) {
  switch (mode) {
    case LoyaltyRoundingMode.floor:
      return 'Arrotonda per difetto';
    case LoyaltyRoundingMode.round:
      return 'Arrotondamento standard';
    case LoyaltyRoundingMode.ceil:
      return 'Arrotonda per eccesso';
  }
}

Future<void> _startCreateFlow(BuildContext context, WidgetRef ref) async {
  final created = await showDialog<Salon>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const SalonCreateEssentialDialog(),
  );
  if (created == null) {
    return;
  }

  final store = ref.read(appDataProvider.notifier);
  await store.upsertSalon(created);
  await store.initializeSalonSetupProgress(salonId: created.id);

  final session = ref.read(sessionControllerProvider);
  final currentUser = session.user;
  if (currentUser != null &&
      currentUser.role == UserRole.admin &&
      !currentUser.salonIds.contains(created.id)) {
    final updatedUser = AppUser(
      uid: currentUser.uid,
      role: currentUser.role,
      salonIds: [...currentUser.salonIds, created.id],
      staffId: currentUser.staffId,
      clientId: currentUser.clientId,
      displayName: currentUser.displayName,
      email: currentUser.email,
      availableRoles: currentUser.availableRoles,
    );
    ref.read(sessionControllerProvider.notifier).updateUser(updatedUser);
  }

  ref.read(sessionControllerProvider.notifier).setSalon(created.id);

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => SalonSetupChecklistDialog(salonId: created.id),
  );
}
