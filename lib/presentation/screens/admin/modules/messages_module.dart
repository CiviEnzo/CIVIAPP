import 'dart:async';
import 'dart:math' as math;

import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/last_minute_slot.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/reminder_settings.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/express_slot_sheet.dart';
import 'package:you_book/presentation/screens/admin/modules/messages/manual_notification_card.dart';
import 'package:you_book/presentation/screens/admin/promotions/promotion_editor_dialog.dart';
import 'package:you_book/presentation/screens/admin/widgets/admin_responsive_helpers.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class MessagesMarketingModule extends ConsumerStatefulWidget {
  const MessagesMarketingModule({super.key, this.salonId});

  final String? salonId;

  @override
  ConsumerState<MessagesMarketingModule> createState() =>
      _MessagesMarketingModuleState();
}

class _MessagesMarketingModuleState
    extends ConsumerState<MessagesMarketingModule> {
  final DateFormat _slotDateFormat = DateFormat('dd/MM HH:mm', 'it_IT');
  final Uuid _uuid = const Uuid();
  static const String _defaultBirthdayTitle = 'Auguri di buon compleanno';

  String _defaultBirthdayBody(String? salonName) {
    if (salonName != null && salonName.trim().isNotEmpty) {
      return 'Lo staff di $salonName ti augura un felice compleanno!';
    }
    return 'Tutto lo staff ti augura un felice compleanno!';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = ref.watch(appDataProvider);
    final session = ref.watch(sessionControllerProvider);
    final salons = data.salons;

    final selectedSalonId =
        widget.salonId ?? (salons.length == 1 ? salons.first.id : null);
    final salon =
        selectedSalonId == null
            ? null
            : salons.firstWhereOrNull(
              (element) => element.id == selectedSalonId,
            );
    final salonName = salon?.name;
    final featureFlags = salon?.featureFlags ?? const SalonFeatureFlags();

    final templates =
        data.messageTemplates
            .where(
              (template) =>
                  selectedSalonId == null ||
                  template.salonId == selectedSalonId,
            )
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    final birthdayTemplate = templates.firstWhereOrNull(
      (template) =>
          template.usage == TemplateUsage.birthday &&
          template.channel == MessageChannel.push,
    );
    final reminderWhatsAppTemplates = templates
        .where(
          (template) =>
              template.channel == MessageChannel.whatsapp &&
              template.usage == TemplateUsage.reminder &&
              template.isActive,
        )
        .toList(growable: false);
    final birthdayWhatsAppTemplates = templates
        .where(
          (template) =>
              template.channel == MessageChannel.whatsapp &&
              template.usage == TemplateUsage.birthday &&
              template.isActive,
        )
        .toList(growable: false);
    final reminderSettings =
        selectedSalonId == null
            ? null
            : data.reminderSettings.firstWhereOrNull(
              (settings) => settings.salonId == selectedSalonId,
            );
    final effectiveSettings =
        selectedSalonId == null
            ? null
            : (reminderSettings ?? ReminderSettings(salonId: selectedSalonId));
    final clients =
        data.clients
            .where(
              (client) =>
                  selectedSalonId == null || client.salonId == selectedSalonId,
            )
            .toList()
          ..sort(
            (a, b) =>
                a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          );

    final promotions =
        selectedSalonId == null
            ? <Promotion>[]
            : (data.promotions
                .where((promotion) => promotion.salonId == selectedSalonId)
                .toList()
              ..sort((a, b) {
                final aEnds = a.endsAt ?? DateTime.utc(2100);
                final bEnds = b.endsAt ?? DateTime.utc(2100);
                return aEnds.compareTo(bEnds);
              }));
    final lastMinuteSlots =
        selectedSalonId == null
            ? <LastMinuteSlot>[]
            : (data.lastMinuteSlots
                .where((slot) => slot.salonId == selectedSalonId)
                .toList()
              ..sort((a, b) => a.start.compareTo(b.start)));
    final salonStaff =
        selectedSalonId == null
            ? <StaffMember>[]
            : data.staff
                .where(
                  (member) =>
                      member.salonId == selectedSalonId && member.isActive,
                )
                .sortedBy((member) => member.fullName.toLowerCase())
                .toList();
    final salonServices =
        selectedSalonId == null
            ? <Service>[]
            : data.services
                .where(
                  (service) =>
                      service.salonId == selectedSalonId && service.isActive,
                )
                .sortedBy((service) => service.name.toLowerCase())
                .toList();

    final canViewReminderSettings =
        selectedSalonId != null &&
        session.role != null &&
        (session.role == UserRole.admin ||
            session.role == UserRole.staff ||
            session.role == UserRole.client);
    final canEditReminderSettings =
        selectedSalonId != null &&
        session.role != null &&
        (session.role == UserRole.admin || session.role == UserRole.staff);

    Future<void> editBirthdayTemplate() async {
      final currentSalonId = selectedSalonId;
      if (currentSalonId == null) {
        return;
      }
      final existingTemplate = birthdayTemplate;
      final initialTitle =
          existingTemplate == null || existingTemplate.title.trim().isEmpty
              ? _defaultBirthdayTitle
              : existingTemplate.title;
      final initialBody =
          existingTemplate == null || existingTemplate.body.trim().isEmpty
              ? _defaultBirthdayBody(salonName)
              : existingTemplate.body;
      final titleController = TextEditingController(text: initialTitle);
      final bodyController = TextEditingController(text: initialBody);
      var isActive = existingTemplate?.isActive ?? true;
      String? validationError;

      final updated = await showDialog<MessageTemplate>(
        context: context,
        builder:
            (dialogContext) => StatefulBuilder(
              builder: (context, setState) {
                final dialogTheme = Theme.of(context);
                return AlertDialog(
                  title: const Text('Messaggio di auguri'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Titolo',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: bodyController,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: 'Testo del messaggio',
                            helperText:
                                'Viene inviato automaticamente il giorno del compleanno.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Template attivo'),
                          value: isActive,
                          onChanged:
                              (value) => setState(() => isActive = value),
                        ),
                        if (validationError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            validationError!,
                            style: TextStyle(
                              color: dialogTheme.colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Annulla'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final title = titleController.text.trim();
                        final body = bodyController.text.trim();
                        if (title.isEmpty || body.isEmpty) {
                          setState(() {
                            validationError = 'Compila titolo e testo.';
                          });
                          return;
                        }
                        Navigator.of(dialogContext).pop(
                          MessageTemplate(
                            id: existingTemplate?.id ?? _uuid.v4(),
                            salonId: currentSalonId,
                            title: title,
                            body: body,
                            channel: MessageChannel.push,
                            usage: TemplateUsage.birthday,
                            isActive: isActive,
                          ),
                        );
                      },
                      child: const Text('Salva'),
                    ),
                  ],
                );
              },
            ),
      );
      titleController.dispose();
      bodyController.dispose();

      if (updated == null) {
        return;
      }
      try {
        await ref.read(appDataProvider.notifier).upsertTemplate(updated);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(content: Text('Template di compleanno aggiornato.')),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text('Impossibile salvare il template: $error')),
        );
      }
    }

    Future<void> togglePromotionVisibility(bool value) async {
      final currentSalon = salon;
      if (currentSalon == null) {
        return;
      }
      final AppDataStore store = ref.read(appDataProvider.notifier);
      await store.updateSalonFeatureFlags(
        currentSalon.id,
        featureFlags.copyWith(clientPromotions: value),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Le promozioni sono ora visibili nella dashboard cliente.'
                : 'Promozioni nascoste alla dashboard cliente.',
          ),
        ),
      );
    }

    Future<void> toggleLastMinuteVisibility(bool value) async {
      final currentSalon = salon;
      if (currentSalon == null) {
        return;
      }
      final AppDataStore store = ref.read(appDataProvider.notifier);
      await store.updateSalonFeatureFlags(
        currentSalon.id,
        featureFlags.copyWith(clientLastMinute: value),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Gli slot last-minute sono visibili ai clienti.'
                : 'Slot last-minute nascosti ai clienti.',
          ),
        ),
      );
    }

    Future<void> togglePromotionActive(
      Promotion promotion,
      bool isActive,
    ) async {
      await ref
          .read(appDataProvider.notifier)
          .upsertPromotion(promotion.copyWith(isActive: isActive));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            isActive ? 'Promozione attivata.' : 'Promozione disattivata.',
          ),
        ),
      );
    }

    Future<void> openPromotionForm({Promotion? existing}) async {
      final currentSalon = salon;
      final salonId = selectedSalonId;
      if (currentSalon == null || salonId == null) {
        return;
      }
      await _openPromotionForm(
        context,
        ref,
        salonId: salonId,
        salon: currentSalon,
        existing: existing,
      );
    }

    Future<void> deletePromotion(Promotion promotion) async {
      await _confirmPromotionDeletion(context, ref, promotion);
    }

    Future<void> deleteSlot(LastMinuteSlot slot) async {
      await _confirmSlotDeletion(context, ref, slot);
    }

    Future<void> openLastMinuteSlotForm() async {
      final salonId = selectedSalonId;
      if (salonId == null) {
        return;
      }
      final now = DateTime.now();
      final initialStart = DateTime(now.year, now.month, now.day, now.hour + 1);
      final result = await showAppModalSheet<ExpressSlotSheetResult>(
        context: context,
        desktopMaxWidth: 1120,
        builder: (sheetContext) {
          return ExpressSlotSheet(
            salonId: salonId,
            initialStart: initialStart,
            initialEnd: initialStart.add(const Duration(minutes: 60)),
            services: salonServices,
            staff: salonStaff,
            clients: clients,
            reminderSettings: effectiveSettings,
          );
        },
      );
      if (result == null) {
        return;
      }

      final store = ref.read(appDataProvider.notifier);
      await store.upsertLastMinuteSlot(result.slot);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Slot last-minute creato.')),
      );
      final notification = result.notification;
      if (notification == null) {
        return;
      }
      try {
        final dispatchResult = await store.sendLastMinuteNotification(
          slot: result.slot,
          request: notification,
        );
        if (!mounted) {
          return;
        }
        final buffer =
            StringBuffer()
              ..write('Notifica slot inviata: ')
              ..write('${dispatchResult.successCount} ok');
        if (dispatchResult.failureCount > 0) {
          buffer.write(', ${dispatchResult.failureCount} errori');
        }
        if (dispatchResult.skippedCount > 0) {
          buffer.write(', ${dispatchResult.skippedCount} esclusi');
        }
        ScaffoldMessenger.of(
          context,
        ).showAppSnackBar(SnackBar(content: Text(buffer.toString())));
      } catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text('Invio notifica non riuscito: $error')),
        );
      }
    }

    return DefaultTabController(
      length: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = isAdminPhoneWidth(constraints.maxWidth);
          final pagePadding = isPhone ? 16.0 : 28.0;
          final sectionPadding = isPhone ? 14.0 : 18.0;
          final outerSpacing = isPhone ? 14.0 : 18.0;

          List<Widget> withSpacing(List<Widget> children) {
            final spaced = <Widget>[];
            for (var i = 0; i < children.length; i++) {
              if (i > 0) {
                spaced.add(SizedBox(height: isPhone ? 18 : 24));
              }
              spaced.add(children[i]);
            }
            return spaced;
          }

          Widget buildTabContent(List<Widget> children, {String? emptyLabel}) {
            if (children.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    emptyLabel ?? 'Nessun contenuto disponibile.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.all(sectionPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: withSpacing(children),
              ),
            );
          }

          final automationContent = <Widget>[
            if (canViewReminderSettings)
              _ReminderSettingsCard(
                salonId: selectedSalonId,
                salonName: salonName,
                settings: effectiveSettings,
                birthdayTemplate: birthdayTemplate,
                reminderWhatsAppTemplates: reminderWhatsAppTemplates,
                birthdayWhatsAppTemplates: birthdayWhatsAppTemplates,
                defaultBirthdayTitle: _defaultBirthdayTitle,
                defaultBirthdayBody: _defaultBirthdayBody(salonName),
                onEditBirthdayTemplate:
                    canEditReminderSettings ? editBirthdayTemplate : null,
                onChanged:
                    canEditReminderSettings
                        ? (updated) async {
                          await ref
                              .read(appDataProvider.notifier)
                              .upsertReminderSettings(updated);
                        }
                        : null,
              ),
          ];

          final manualContent = <Widget>[
            ManualNotificationCard(
              salonId: selectedSalonId,
              salonName: salonName,
              clients: clients,
              templates: templates,
            ),
          ];

          final promotionsContent = <Widget>[
            _PromotionsSection(
              salonId: selectedSalonId,
              promotions: promotions,
              promotionsVisible: featureFlags.clientPromotions,
              onCreate:
                  selectedSalonId == null ? null : () => openPromotionForm(),
              onEdit:
                  selectedSalonId == null
                      ? null
                      : (promotion) => openPromotionForm(existing: promotion),
              onToggleActive:
                  selectedSalonId == null ? null : togglePromotionActive,
              onDelete: selectedSalonId == null ? null : deletePromotion,
              onToggleVisibility:
                  selectedSalonId == null
                      ? null
                      : (value) => togglePromotionVisibility(value),
            ),
          ];

          final lastMinuteContent = <Widget>[
            if (canViewReminderSettings && effectiveSettings != null)
              _LastMinuteDefaultsCard(
                settings: effectiveSettings,
                onChanged:
                    canEditReminderSettings
                        ? (updated) async {
                          await ref
                              .read(appDataProvider.notifier)
                              .upsertReminderSettings(updated);
                        }
                        : null,
              ),
            _LastMinuteSection(
              salonId: selectedSalonId,
              slots: lastMinuteSlots,
              staff: salonStaff,
              featureFlags: featureFlags,
              dateFormat: _slotDateFormat,
              onDelete: selectedSalonId == null ? null : deleteSlot,
              onCreateSlot:
                  selectedSalonId == null ? null : openLastMinuteSlotForm,
              onToggleVisibility:
                  selectedSalonId == null
                      ? null
                      : (value) => toggleLastMinuteVisibility(value),
            ),
          ];

          final tabDefinitions = _messagesTabDefinitions;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              pagePadding,
              isPhone ? 16 : 22,
              pagePadding,
              isPhone ? 16 : 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isPhone) ...[
                  Text(
                    'Messaggi & Marketing',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestione comunicazioni e campagne',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: outerSpacing),
                ],
                _buildTabBar(theme, tabDefinitions),
                SizedBox(height: outerSpacing),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(isPhone ? 16 : 18),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: TabBarView(
                      children: [
                        buildTabContent(
                          automationContent,
                          emptyLabel:
                              canViewReminderSettings
                                  ? 'Nessuna automazione disponibile.'
                                  : 'Seleziona un salone o verifica i permessi per configurare le automazioni.',
                        ),
                        buildTabContent(manualContent),
                        buildTabContent(promotionsContent),
                        buildTabContent(lastMinuteContent),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPromotionForm(
    BuildContext context,
    WidgetRef ref, {
    required String salonId,
    required Salon salon,
    Promotion? existing,
  }) async {
    final result = await showDialog<Promotion>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PromotionEditorDialog(
          salonId: salonId,
          salon: salon,
          initialPromotion: existing,
        );
      },
    );
    if (result == null) {
      return;
    }
    await ref.read(appDataProvider.notifier).upsertPromotion(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? 'Promozione creata con successo.'
              : 'Promozione aggiornata con successo.',
        ),
      ),
    );
  }

  Future<void> _confirmPromotionDeletion(
    BuildContext context,
    WidgetRef ref,
    Promotion promotion,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Elimina promozione'),
          content: Text('Vuoi eliminare la promozione "${promotion.title}"?'),
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
    if (shouldDelete != true) {
      return;
    }
    await ref.read(appDataProvider.notifier).deletePromotion(promotion.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showAppSnackBar(const SnackBar(content: Text('Promozione eliminata.')));
  }

  Future<void> _confirmSlotDeletion(
    BuildContext context,
    WidgetRef ref,
    LastMinuteSlot slot,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rimuovi slot last-minute'),
          content: Text(
            'Vuoi rimuovere lo slot last-minute delle ${_slotDateFormat.format(slot.start)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Rimuovi'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }
    await ref.read(appDataProvider.notifier).deleteLastMinuteSlot(slot.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showAppSnackBar(
      const SnackBar(content: Text('Slot last-minute rimosso.')),
    );
  }
}

class _PromotionsSection extends StatelessWidget {
  const _PromotionsSection({
    required this.salonId,
    required this.promotions,
    required this.promotionsVisible,
    required this.onCreate,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    this.onToggleVisibility,
  });

  final String? salonId;
  final List<Promotion> promotions;
  final bool promotionsVisible;
  final Future<void> Function()? onCreate;
  final Future<void> Function(Promotion promotion)? onEdit;
  final Future<void> Function(Promotion promotion, bool isActive)?
  onToggleActive;
  final Future<void> Function(Promotion promotion)? onDelete;
  final Future<void> Function(bool value)? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final hasSalon = salonId != null;
    return _MarketingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MarketingSectionHeading(
            title: 'Campagne promozionali',
            subtitle: 'Promozioni visibili ai clienti nell\'app',
            trailing: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              children: [
                if (hasSalon && onToggleVisibility != null)
                  _MarketingSwitchPill(
                    label: 'Visibili ai clienti',
                    value: promotionsVisible,
                    onChanged: (value) => unawaited(onToggleVisibility!(value)),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed:
                      hasSalon && onCreate != null
                          ? () => unawaited(onCreate!())
                          : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nuova promo'),
                ),
              ],
            ),
          ),
          if (!promotionsVisible && hasSalon) ...[
            const SizedBox(height: 16),
            const _MarketingInlineNotice(
              message: 'Promozioni nascoste nella dashboard cliente.',
              isError: true,
            ),
          ],
          const SizedBox(height: 18),
          if (!hasSalon)
            const _MarketingEmptyState(
              message:
                  'Seleziona un salone per creare e gestire le promozioni.',
            )
          else if (promotions.isEmpty)
            const _MarketingEmptyState(
              message: 'Nessuna promozione salvata. Crea una nuova promo.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 860;
                if (!isWide) {
                  return Column(
                    children: List.generate(promotions.length, (index) {
                      final promotion = promotions[index];
                      return Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                        child: _PromotionTile(
                          promotion: promotion,
                          onEdit: onEdit,
                          onToggleActive: onToggleActive,
                          onDelete: onDelete,
                        ),
                      );
                    }),
                  );
                }

                final tileWidth = (constraints.maxWidth - 14) / 2;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: promotions
                      .map(
                        (promotion) => SizedBox(
                          width: tileWidth,
                          child: _PromotionTile(
                            promotion: promotion,
                            onEdit: onEdit,
                            onToggleActive: onToggleActive,
                            onDelete: onDelete,
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PromotionTile extends StatelessWidget {
  const _PromotionTile({
    required this.promotion,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Promotion promotion;
  final Future<void> Function(Promotion promotion)? onEdit;
  final Future<void> Function(Promotion promotion, bool isActive)?
  onToggleActive;
  final Future<void> Function(Promotion promotion)? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(theme, promotion.status);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackHeader = constraints.maxWidth < 460;
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promotion.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (promotion.subtitle?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    promotion.subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            );
            final toggle = Switch.adaptive(
              value: promotion.isActive,
              onChanged:
                  onToggleActive == null
                      ? null
                      : (value) => unawaited(onToggleActive!(promotion, value)),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stackHeader) ...[
                  titleBlock,
                  const SizedBox(height: 10),
                  toggle,
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleBlock),
                      const SizedBox(width: 12),
                      toggle,
                    ],
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MarketingMetaChip(
                      label: _promotionPeriod(promotion),
                      icon: Icons.calendar_today_outlined,
                    ),
                    _MarketingMetaChip(
                      label: _statusLabel(promotion.status),
                      icon: _statusIcon(promotion.status),
                      foregroundColor: statusColor,
                      backgroundColor: statusColor.withValues(alpha: 0.10),
                      borderColor: statusColor.withValues(alpha: 0.22),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: theme.colorScheme.outlineVariant, height: 1),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed:
                          onEdit == null
                              ? null
                              : () => unawaited(onEdit!(promotion)),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Modifica'),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed:
                          onDelete == null
                              ? null
                              : () => unawaited(onDelete!(promotion)),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Elimina'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _promotionPeriod(Promotion promotion) {
    final start = promotion.startsAt;
    final end = promotion.endsAt;
    if (start == null && end == null) {
      return promotion.isActive ? 'Attiva senza scadenza' : 'Inattiva';
    }
    final buffer = StringBuffer();
    if (start != null) {
      buffer.write('Dal ${DateFormat('dd/MM').format(start)}');
    }
    if (end != null) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write('al ${DateFormat('dd/MM').format(end)}');
    }
    return buffer.toString();
  }

  String _statusLabel(PromotionStatus status) {
    switch (status) {
      case PromotionStatus.draft:
        return 'Bozza';
      case PromotionStatus.scheduled:
        return 'Programmato';
      case PromotionStatus.published:
        return 'Pubblicato';
      case PromotionStatus.expired:
        return 'Scaduto';
    }
  }

  IconData _statusIcon(PromotionStatus status) {
    switch (status) {
      case PromotionStatus.draft:
        return Icons.pending_outlined;
      case PromotionStatus.scheduled:
        return Icons.schedule_rounded;
      case PromotionStatus.published:
        return Icons.play_arrow_rounded;
      case PromotionStatus.expired:
        return Icons.history_rounded;
    }
  }

  Color _statusColor(ThemeData theme, PromotionStatus status) {
    switch (status) {
      case PromotionStatus.draft:
        return theme.colorScheme.onSurfaceVariant;
      case PromotionStatus.scheduled:
        return const Color(0xFFC98700);
      case PromotionStatus.published:
        return const Color(0xFF16A34A);
      case PromotionStatus.expired:
        return theme.colorScheme.error;
    }
  }
}

class _LastMinuteDefaultsCard extends StatelessWidget {
  const _LastMinuteDefaultsCard({required this.settings, this.onChanged});

  final ReminderSettings settings;
  final Future<void> Function(ReminderSettings updated)? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _MarketingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MarketingSectionHeading(
            title: 'Impostazioni last-minute',
            subtitle: 'Configura le notifiche last-minute predefinite',
          ),
          const SizedBox(height: 18),
          _MarketingFieldLabel(label: 'Seleziona destinatari', theme: theme),
          const SizedBox(height: 8),
          DropdownButtonFormField<LastMinuteNotificationAudience>(
            key: ValueKey(settings.lastMinuteNotificationAudience),
            isExpanded: true,
            initialValue: settings.lastMinuteNotificationAudience,
            decoration: const InputDecoration(
              hintText: 'Seleziona destinatari',
            ),
            items:
                LastMinuteNotificationAudience.values.map((audience) {
                  late final String label;
                  switch (audience) {
                    case LastMinuteNotificationAudience.none:
                      label = 'Chiedi ogni volta';
                      break;
                    case LastMinuteNotificationAudience.everyone:
                      label = 'Tutti i clienti';
                      break;
                    case LastMinuteNotificationAudience.ownerSelection:
                      label = 'Selezione manuale';
                      break;
                  }
                  return DropdownMenuItem<LastMinuteNotificationAudience>(
                    value: audience,
                    child: Text(label),
                  );
                }).toList(),
            onChanged:
                onChanged == null
                    ? null
                    : (value) {
                      if (value != null) {
                        unawaited(
                          onChanged!(
                            settings.copyWith(
                              lastMinuteNotificationAudience: value,
                            ),
                          ),
                        );
                      }
                    },
          ),
          const SizedBox(height: 10),
          Text(
            'Determina cosa proporre quando crei o modifichi uno slot express.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LastMinuteSection extends StatefulWidget {
  const _LastMinuteSection({
    required this.salonId,
    required this.slots,
    required this.staff,
    required this.featureFlags,
    required this.dateFormat,
    required this.onDelete,
    this.onCreateSlot,
    this.onToggleVisibility,
  });

  final String? salonId;
  final List<LastMinuteSlot> slots;
  final List<StaffMember> staff;
  final SalonFeatureFlags featureFlags;
  final DateFormat dateFormat;
  final Future<void> Function(LastMinuteSlot slot)? onDelete;
  final Future<void> Function()? onCreateSlot;
  final Future<void> Function(bool value)? onToggleVisibility;

  @override
  State<_LastMinuteSection> createState() => _LastMinuteSectionState();
}

class _LastMinuteSectionState extends State<_LastMinuteSection> {
  bool _historyExpanded = false;

  @override
  Widget build(BuildContext context) {
    final hasSalon = widget.salonId != null;
    final staffById = {for (final member in widget.staff) member.id: member};
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    final now = DateTime.now();
    final activeSlots = widget.slots
        .where((slot) => slot.effectiveWindowEnd.isAfter(now))
        .toList(growable: false);
    final historicalSlots =
        widget.slots
            .where((slot) => !slot.effectiveWindowEnd.isAfter(now))
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));

    return _MarketingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MarketingSectionHeading(
            title: 'Slot last-minute',
            subtitle: 'Prenotazioni rapide visibili ai clienti',
            trailing:
                hasSalon
                    ? Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.end,
                      children: [
                        Switch.adaptive(
                          value: widget.featureFlags.clientLastMinute,
                          onChanged:
                              widget.onToggleVisibility == null
                                  ? null
                                  : (value) => unawaited(
                                    widget.onToggleVisibility!(value),
                                  ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed:
                              widget.onCreateSlot == null
                                  ? null
                                  : () => unawaited(widget.onCreateSlot!()),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Aggiungi slot'),
                        ),
                      ],
                    )
                    : null,
          ),
          const SizedBox(height: 16),
          if (!hasSalon)
            const _MarketingEmptyState(
              message: 'Seleziona un salone per monitorare le offerte express.',
            )
          else if (widget.slots.isEmpty)
            const _MarketingEmptyState(
              message:
                  'Trasforma una disponibilità libera in offerta express dal calendario appuntamenti.',
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LastMinuteGroupHeader(
                  title: 'Attivi',
                  count: activeSlots.length,
                ),
                const SizedBox(height: 10),
                if (activeSlots.isEmpty)
                  const _MarketingEmptyState(
                    message: 'Nessuno slot attivo al momento.',
                  )
                else
                  Column(
                    children: List.generate(activeSlots.length, (index) {
                      final slot = activeSlots[index];
                      final staffName =
                          slot.operatorId != null
                              ? staffById[slot.operatorId!]?.fullName
                              : null;
                      return Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                        child: _LastMinuteTile(
                          slot: slot,
                          staffName: staffName,
                          currency: currency,
                          dateFormat: widget.dateFormat,
                          onDelete: widget.onDelete,
                        ),
                      );
                    }),
                  ),
                if (historicalSlots.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: ExpansionTile(
                      key: const PageStorageKey<String>(
                        'messages_last_minute_history',
                      ),
                      initiallyExpanded: _historyExpanded,
                      onExpansionChanged:
                          (expanded) =>
                              setState(() => _historyExpanded = expanded),
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      title: _LastMinuteGroupHeader(
                        title: 'Storico',
                        count: historicalSlots.length,
                        compact: true,
                      ),
                      children: [
                        Column(
                          children: List.generate(historicalSlots.length, (
                            index,
                          ) {
                            final slot = historicalSlots[index];
                            final staffName =
                                slot.operatorId != null
                                    ? staffById[slot.operatorId!]?.fullName
                                    : null;
                            return Padding(
                              padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                              child: _LastMinuteTile(
                                slot: slot,
                                staffName: staffName,
                                currency: currency,
                                dateFormat: widget.dateFormat,
                                onDelete: widget.onDelete,
                                compact: true,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _LastMinuteTile extends StatelessWidget {
  const _LastMinuteTile({
    required this.slot,
    required this.staffName,
    required this.currency,
    required this.dateFormat,
    required this.onDelete,
    this.compact = false,
  });

  final LastMinuteSlot slot;
  final String? staffName;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final Future<void> Function(LastMinuteSlot slot)? onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel =
        '${dateFormat.format(slot.start)} · ${slot.duration.inMinutes} min';
    final operatorLabel =
        staffName ?? slot.operatorName ?? 'Operatore non assegnato';
    final priceLabel =
        '${currency.format(slot.priceNow)} - base ${currency.format(slot.basePrice)}';
    final paymentLabel =
        slot.paymentMode == LastMinutePaymentMode.online
            ? 'Pagamento online immediato'
            : 'Pagamento in sede';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding:
            compact
                ? const EdgeInsets.fromLTRB(12, 12, 12, 10)
                : const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    slot.serviceName,
                    style:
                        compact
                            ? theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            )
                            : theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                ),
                IconButton(
                  tooltip: 'Rimuovi',
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      onDelete == null
                          ? null
                          : () => unawaited(onDelete!(slot)),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            Text(
              timeLabel,
              style:
                  compact
                      ? theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )
                      : theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
            ),
            const SizedBox(height: 6),
            if (compact)
              LayoutBuilder(
                builder: (context, constraints) {
                  final stackCompactMeta = constraints.maxWidth < 300;
                  final operatorText = Text(
                    operatorLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                  final priceText = Text(
                    priceLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                  if (stackCompactMeta) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        operatorText,
                        const SizedBox(height: 4),
                        priceText,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: operatorText),
                      const SizedBox(width: 10),
                      Flexible(child: priceText),
                    ],
                  );
                },
              )
            else ...[
              Row(
                children: [
                  Icon(
                    Icons.person_rounded,
                    size: 17,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      operatorLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                priceLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              paymentLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastMinuteGroupHeader extends StatelessWidget {
  const _LastMinuteGroupHeader({
    required this.title,
    required this.count,
    this.compact = false,
  });

  final String title;
  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle =
        compact
            ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
            : theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            );
    return Row(
      children: [
        Expanded(child: Text(title, style: textStyle)),
        _MarketingMetaChip(label: '$count', icon: Icons.layers_outlined),
      ],
    );
  }
}

class _ReminderSettingsCard extends StatelessWidget {
  const _ReminderSettingsCard({
    required this.salonId,
    required this.salonName,
    required this.settings,
    required this.defaultBirthdayTitle,
    required this.defaultBirthdayBody,
    required this.reminderWhatsAppTemplates,
    required this.birthdayWhatsAppTemplates,
    this.onChanged,
    this.birthdayTemplate,
    this.onEditBirthdayTemplate,
  });

  final String? salonId;
  final String? salonName;
  final ReminderSettings? settings;
  final String defaultBirthdayTitle;
  final String defaultBirthdayBody;
  final List<MessageTemplate> reminderWhatsAppTemplates;
  final List<MessageTemplate> birthdayWhatsAppTemplates;
  final Future<void> Function(ReminderSettings)? onChanged;
  final MessageTemplate? birthdayTemplate;
  final Future<void> Function()? onEditBirthdayTemplate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminder = settings;
    if (salonId == null || reminder == null) {
      return const _MarketingPanel(
        child: _MarketingEmptyState(
          message:
              'Seleziona un salone per configurare i promemoria automatici.',
        ),
      );
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final updatedLabel =
        reminder.updatedAt != null
            ? 'Ultimo aggiornamento: ${dateFormat.format(reminder.updatedAt!)}'
            : 'Mai configurato';
    final template = birthdayTemplate;
    final templatePresent =
        template != null &&
        template.title.trim().isNotEmpty &&
        template.body.trim().isNotEmpty;
    final templateTitle = template?.title ?? defaultBirthdayTitle;
    final templateBody = template?.body ?? defaultBirthdayBody;
    final templateActive = template?.isActive ?? true;
    final reminderWhatsAppTemplatesById = {
      for (final item in reminderWhatsAppTemplates) item.id: item,
    };
    final birthdayWhatsAppTemplatesById = {
      for (final item in birthdayWhatsAppTemplates) item.id: item,
    };
    final selectedBirthdayWhatsappTemplate =
        reminder.birthdayWhatsappTemplateId != null
            ? birthdayWhatsAppTemplatesById[reminder
                .birthdayWhatsappTemplateId!]
            : null;
    final birthdayWhatsappTemplateMissing =
        reminder.birthdaySendsWhatsapp &&
        reminder.birthdayWhatsappTemplateId != null &&
        selectedBirthdayWhatsappTemplate == null;

    Future<void> emit(ReminderSettings updated) async {
      final callback = onChanged;
      if (callback == null) {
        return;
      }
      await callback(updated);
    }

    Future<void> updateOffsets(List<ReminderOffsetConfig> newOffsets) async {
      await emit(reminder.copyWith(offsets: newOffsets));
    }

    Future<void> updateOffsetAt(int index, ReminderOffsetConfig updated) async {
      final current = reminder.offsets;
      if (index < 0 || index >= current.length) {
        return;
      }
      final next = List<ReminderOffsetConfig>.from(current)..[index] = updated;
      await updateOffsets(next);
    }

    Future<void> updateOffsetDeliveryMode(
      int index,
      ReminderOffsetConfig config,
      ReminderDeliveryMode mode,
    ) async {
      if (onChanged == null) {
        return;
      }
      if (config.deliveryMode == mode) {
        return;
      }
      if ((mode == ReminderDeliveryMode.whatsapp ||
              mode == ReminderDeliveryMode.both) &&
          reminderWhatsAppTemplates.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentAppSnackBar()
          ..showAppSnackBar(
            const SnackBar(
              content: Text(
                'Nessun template WhatsApp (uso Promemoria) disponibile. Crea o importa prima un template reminder.',
              ),
            ),
          );
        return;
      }

      final selectedTemplate =
          config.whatsappTemplateId != null
              ? reminderWhatsAppTemplatesById[config.whatsappTemplateId!]
              : null;
      final fallbackTemplate =
          selectedTemplate ?? reminderWhatsAppTemplates.firstOrNull;

      await updateOffsetAt(
        index,
        config.copyWith(
          deliveryMode: mode,
          whatsappTemplateId:
              (mode == ReminderDeliveryMode.whatsapp ||
                      mode == ReminderDeliveryMode.both)
                  ? (fallbackTemplate?.id ?? config.whatsappTemplateId)
                  : config.whatsappTemplateId,
          whatsappTemplateName:
              (mode == ReminderDeliveryMode.whatsapp ||
                      mode == ReminderDeliveryMode.both)
                  ? (fallbackTemplate?.title ??
                      config.whatsappTemplateName ??
                      config.whatsappTemplateId)
                  : config.whatsappTemplateName,
        ),
      );
    }

    Future<void> updateOffsetWhatsappTemplate(
      int index,
      ReminderOffsetConfig config,
      String templateId,
    ) async {
      if (onChanged == null) {
        return;
      }
      final template = reminderWhatsAppTemplatesById[templateId];
      if (template == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentAppSnackBar()
          ..showAppSnackBar(
            const SnackBar(content: Text('Template WhatsApp non disponibile.')),
          );
        return;
      }
      await updateOffsetAt(
        index,
        config.copyWith(
          whatsappTemplateId: template.id,
          whatsappTemplateName: template.title,
        ),
      );
    }

    Future<void> toggleBirthday(bool enabled) async {
      await emit(reminder.copyWith(birthdayEnabled: enabled));
    }

    Future<void> updateBirthdayDeliveryMode(ReminderDeliveryMode mode) async {
      if (onChanged == null || reminder.birthdayDeliveryMode == mode) {
        return;
      }
      if ((mode == ReminderDeliveryMode.whatsapp ||
              mode == ReminderDeliveryMode.both) &&
          birthdayWhatsAppTemplates.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentAppSnackBar()
          ..showAppSnackBar(
            const SnackBar(
              content: Text(
                'Nessun template WhatsApp (uso Compleanno) disponibile. Crea o importa prima un template compleanno.',
              ),
            ),
          );
        return;
      }
      final fallbackTemplate =
          selectedBirthdayWhatsappTemplate ??
          birthdayWhatsAppTemplates.firstOrNull;
      await emit(
        reminder.copyWith(
          birthdayDeliveryMode: mode,
          birthdayWhatsappTemplateId:
              mode == ReminderDeliveryMode.whatsapp ||
                      mode == ReminderDeliveryMode.both
                  ? (fallbackTemplate?.id ??
                      reminder.birthdayWhatsappTemplateId)
                  : reminder.birthdayWhatsappTemplateId,
          birthdayWhatsappTemplateName:
              mode == ReminderDeliveryMode.whatsapp ||
                      mode == ReminderDeliveryMode.both
                  ? (fallbackTemplate?.title ??
                      reminder.birthdayWhatsappTemplateName ??
                      reminder.birthdayWhatsappTemplateId)
                  : reminder.birthdayWhatsappTemplateName,
        ),
      );
    }

    Future<void> updateBirthdayWhatsappTemplate(String templateId) async {
      if (onChanged == null) {
        return;
      }
      final template = birthdayWhatsAppTemplatesById[templateId];
      if (template == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentAppSnackBar()
          ..showAppSnackBar(
            const SnackBar(content: Text('Template WhatsApp non disponibile.')),
          );
        return;
      }
      await emit(
        reminder.copyWith(
          birthdayWhatsappTemplateId: template.id,
          birthdayWhatsappTemplateName: template.title,
        ),
      );
    }

    Future<void> toggleOffsetActive(int index, bool enabled) async {
      final current = reminder.offsets;
      if (index < 0 || index >= current.length) {
        return;
      }
      await updateOffsetAt(index, current[index].copyWith(active: enabled));
    }

    final offsetsEntries =
        reminder.offsets.asMap().entries.toList()..sort(
          (a, b) => b.value.minutesBefore.compareTo(a.value.minutesBefore),
        );
    final canEditOffsets = onChanged != null;
    final canAddOffset =
        canEditOffsets &&
        reminder.offsets.length < ReminderSettings.maxOffsetsCount;

    const dayOptions = <int>[0, 1, 2, 3, 4, 5, 6, 7];
    const hourOptions = <int>[
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
    ];
    const minuteOptions = <int>[0, 15, 30, 45];

    void showValidationMessage(String message) {
      ScaffoldMessenger.of(context)
        ..hideCurrentAppSnackBar()
        ..showAppSnackBar(SnackBar(content: Text(message)));
    }

    ({int days, int hours, int minutes}) splitOffset(int totalMinutes) {
      final days = totalMinutes ~/ 1440;
      final hours = (totalMinutes % 1440) ~/ 60;
      final minutes = totalMinutes % 60;
      return (days: days, hours: hours, minutes: minutes);
    }

    Future<void> changeOffset({
      required int index,
      required ReminderOffsetConfig config,
      int? days,
      int? hours,
      int? minutes,
    }) async {
      final parts = splitOffset(config.minutesBefore);
      final newDays = days ?? parts.days;
      final newHours = hours ?? parts.hours;
      final newMinutes = minutes ?? parts.minutes;
      final total = (newDays * 1440) + (newHours * 60) + newMinutes;
      if (total == config.minutesBefore) {
        return;
      }
      if (total < ReminderSettings.minOffsetMinutes) {
        showValidationMessage(
          'Imposta almeno ${ReminderSettings.minOffsetMinutes} minuti.',
        );
        return;
      }
      if (total > ReminderSettings.maxOffsetMinutes) {
        showValidationMessage(
          'Il massimo consentito è di ${ReminderSettings.maxOffsetMinutes ~/ 1440} giorni.',
        );
        return;
      }
      if (total == 0) {
        showValidationMessage('Seleziona un intervallo valido.');
        return;
      }
      final duplicates = reminder.offsets.asMap().entries.any((entry) {
        if (entry.key == index) {
          return false;
        }
        return entry.value.minutesBefore == total;
      });
      if (duplicates) {
        showValidationMessage('Questo intervallo è già presente.');
        return;
      }
      final autoManagedSlug = config.id == 'M${config.minutesBefore}';
      await updateOffsetAt(
        index,
        config.copyWith(
          minutesBefore: total,
          id: autoManagedSlug ? 'M$total' : config.id,
        ),
      );
    }

    Future<void> addOffset() async {
      if (!canAddOffset) {
        return;
      }
      final existing =
          reminder.offsets.map((offset) => offset.minutesBefore).toSet();
      var candidate = ReminderSettings.minOffsetMinutes;
      while (existing.contains(candidate) &&
          candidate <= ReminderSettings.maxOffsetMinutes) {
        candidate += ReminderSettings.minOffsetMinutes;
      }
      if (candidate > ReminderSettings.maxOffsetMinutes) {
        showValidationMessage('Non ci sono altri intervalli disponibili.');
        return;
      }
      final newOffset = ReminderOffsetConfig(
        id: 'M$candidate',
        minutesBefore: candidate,
      );
      await updateOffsets(<ReminderOffsetConfig>[
        ...reminder.offsets,
        newOffset,
      ]);
    }

    Future<void> removeOffset(int index) async {
      if (!canEditOffsets) {
        return;
      }
      final current = reminder.offsets;
      if (index < 0 || index >= current.length) {
        return;
      }
      final next = List<ReminderOffsetConfig>.from(current)..removeAt(index);
      await updateOffsets(next);
    }

    Future<void> editOffsetMetadata(int index) async {
      if (!canEditOffsets) {
        return;
      }
      final current = reminder.offsets;
      if (index < 0 || index >= current.length) {
        return;
      }
      final offset = current[index];
      final titleController = TextEditingController(text: offset.title ?? '');
      final bodyController = TextEditingController(
        text: offset.bodyTemplate ?? '',
      );
      const defaultBodyTemplate =
          'Promemoria per {{service_name}} il {{date}} alle {{time}} presso {{salon_name}}.';
      if (bodyController.text.trim().isEmpty) {
        bodyController.text = defaultBodyTemplate;
      }

      final updated = await showDialog<ReminderOffsetConfig>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            title: const Text('Dettagli promemoria'),
            content: SizedBox(
              width: math.min(
                480,
                math.max(280, MediaQuery.sizeOf(dialogContext).width - 48),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Titolo (facoltativo)',
                        hintText: 'Inserisci il titolo del promemoria',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Testo (facoltativo)',
                        hintText:
                            'Es. Promemoria per {{service_name}} il {{date}} alle {{time}} presso {{salon_name}}',
                        helperText:
                            'Segnaposto disponibili: {{date}}, {{time}}, {{service_name}}, {{salon_name}}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(
                    offset.copyWith(
                      title:
                          titleController.text.trim().isEmpty
                              ? null
                              : titleController.text.trim(),
                      bodyTemplate:
                          bodyController.text.trim().isEmpty
                              ? null
                              : bodyController.text.trim(),
                    ),
                  );
                },
                child: const Text('Salva'),
              ),
            ],
          );
        },
      );

      if (updated != null) {
        await updateOffsetAt(index, updated);
      }
    }

    String reminderModeLabel(ReminderDeliveryMode mode) {
      switch (mode) {
        case ReminderDeliveryMode.push:
          return 'Push';
        case ReminderDeliveryMode.whatsapp:
          return 'WhatsApp';
        case ReminderDeliveryMode.both:
          return 'Push + WhatsApp';
      }
    }

    String durationLabel(({int days, int hours, int minutes}) parts) {
      return '${parts.days} giorni · ${parts.hours} ore · ${parts.minutes} minuti';
    }

    String optionLabel(String label, int option) {
      if (label == 'Minuti' && option == 0) {
        return '0 minuti';
      }
      if (label == 'Giorni' && option == 1) {
        return '1 giorno';
      }
      if (label == 'Ore' && option == 1) {
        return '1 ora';
      }
      return '$option ${label.toLowerCase()}';
    }

    Widget buildIntDropdown({
      required String label,
      required List<int> values,
      required int value,
      required ValueChanged<int?>? onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MarketingFieldLabel(label: label, theme: theme),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: values
                .map(
                  (option) => DropdownMenuItem<int>(
                    value: option,
                    child: Text(optionLabel(label, option)),
                  ),
                )
                .toList(growable: false),
            onChanged: onChanged,
          ),
        ],
      );
    }

    Widget buildOffsetCard(MapEntry<int, ReminderOffsetConfig> entry) {
      final originalIndex = entry.key;
      final config = entry.value;
      final parts = splitOffset(config.minutesBefore);
      final daysValues = {...dayOptions, parts.days}.toList()..sort();
      final hoursValues = {...hourOptions, parts.hours}.toList()..sort();
      final minutesValues = {...minuteOptions, parts.minutes}.toList()..sort();
      final selectedWaTemplate =
          config.whatsappTemplateId != null
              ? reminderWhatsAppTemplatesById[config.whatsappTemplateId!]
              : null;
      final chips = <Widget>[
        _MarketingMetaChip(
          label: reminderModeLabel(config.deliveryMode),
          icon:
              config.deliveryMode == ReminderDeliveryMode.push
                  ? Icons.smartphone_rounded
                  : config.deliveryMode == ReminderDeliveryMode.whatsapp
                  ? Icons.chat_rounded
                  : Icons.sync_alt_rounded,
        ),
        if (config.title != null && config.title!.trim().isNotEmpty)
          _MarketingMetaChip(
            label: config.title!.trim(),
            icon: Icons.text_fields_rounded,
          ),
        if (config.sendsWhatsapp &&
            (selectedWaTemplate != null ||
                (config.whatsappTemplateName ?? '').trim().isNotEmpty))
          _MarketingMetaChip(
            label:
                selectedWaTemplate?.title ??
                config.whatsappTemplateName!.trim(),
            icon: Icons.article_outlined,
          ),
      ];

      return Container(
        margin: EdgeInsets.only(top: entry == offsetsEntries.first ? 0 : 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackTopControls = constraints.maxWidth < 460;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stackTopControls) ...[
                  Wrap(spacing: 8, runSpacing: 8, children: chips),
                  const SizedBox(height: 10),
                  Switch.adaptive(
                    value: config.active,
                    onChanged:
                        canEditOffsets
                            ? (value) => unawaited(
                              toggleOffsetActive(originalIndex, value),
                            )
                            : null,
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
                      ),
                      const SizedBox(width: 12),
                      Switch.adaptive(
                        value: config.active,
                        onChanged:
                            canEditOffsets
                                ? (value) => unawaited(
                                  toggleOffsetActive(originalIndex, value),
                                )
                                : null,
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Text(
                  durationLabel(parts),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 520;
                    final daysDropdown = buildIntDropdown(
                      label: 'Giorni',
                      values: daysValues,
                      value: parts.days,
                      onChanged:
                          canEditOffsets
                              ? (value) {
                                if (value != null) {
                                  unawaited(
                                    changeOffset(
                                      index: originalIndex,
                                      config: config,
                                      days: value,
                                    ),
                                  );
                                }
                              }
                              : null,
                    );
                    final hoursDropdown = buildIntDropdown(
                      label: 'Ore',
                      values: hoursValues,
                      value: parts.hours,
                      onChanged:
                          canEditOffsets
                              ? (value) {
                                if (value != null) {
                                  unawaited(
                                    changeOffset(
                                      index: originalIndex,
                                      config: config,
                                      hours: value,
                                    ),
                                  );
                                }
                              }
                              : null,
                    );
                    final minutesDropdown = buildIntDropdown(
                      label: 'Minuti',
                      values: minutesValues,
                      value: parts.minutes,
                      onChanged:
                          canEditOffsets
                              ? (value) {
                                if (value != null) {
                                  unawaited(
                                    changeOffset(
                                      index: originalIndex,
                                      config: config,
                                      minutes: value,
                                    ),
                                  );
                                }
                              }
                              : null,
                    );
                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: daysDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: hoursDropdown),
                          const SizedBox(width: 8),
                          Expanded(child: minutesDropdown),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        daysDropdown,
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: hoursDropdown),
                            const SizedBox(width: 8),
                            Expanded(child: minutesDropdown),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _MarketingFieldLabel(label: 'Tipo messaggio', theme: theme),
                const SizedBox(height: 6),
                DropdownButtonFormField<ReminderDeliveryMode>(
                  isExpanded: true,
                  initialValue: config.deliveryMode,
                  decoration: const InputDecoration(isDense: true),
                  items: const [
                    DropdownMenuItem(
                      value: ReminderDeliveryMode.push,
                      child: Text('Push'),
                    ),
                    DropdownMenuItem(
                      value: ReminderDeliveryMode.whatsapp,
                      child: Text('WhatsApp'),
                    ),
                    DropdownMenuItem(
                      value: ReminderDeliveryMode.both,
                      child: Text('Push + WhatsApp'),
                    ),
                  ],
                  onChanged:
                      canEditOffsets
                          ? (value) {
                            if (value != null) {
                              unawaited(
                                updateOffsetDeliveryMode(
                                  originalIndex,
                                  config,
                                  value,
                                ),
                              );
                            }
                          }
                          : null,
                ),
                if (config.sendsWhatsapp) ...[
                  const SizedBox(height: 12),
                  _MarketingFieldLabel(
                    label: 'Template WhatsApp',
                    theme: theme,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: selectedWaTemplate?.id,
                    decoration: const InputDecoration(isDense: true),
                    hint: const Text('Seleziona template WhatsApp'),
                    items: reminderWhatsAppTemplates
                        .map(
                          (template) => DropdownMenuItem<String>(
                            value: template.id,
                            child: Text(template.title),
                          ),
                        )
                        .toList(growable: false),
                    onChanged:
                        canEditOffsets && reminderWhatsAppTemplates.isNotEmpty
                            ? (value) {
                              if (value != null) {
                                unawaited(
                                  updateOffsetWhatsappTemplate(
                                    originalIndex,
                                    config,
                                    value,
                                  ),
                                );
                              }
                            }
                            : null,
                  ),
                  if (reminderWhatsAppTemplates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Nessun template WhatsApp con uso Promemoria disponibile.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    )
                  else if (selectedWaTemplate == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Template selezionato non disponibile o non piu attivo. Selezionane uno nuovo.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Modifica testo',
                        onPressed:
                            canEditOffsets
                                ? () =>
                                    unawaited(editOffsetMetadata(originalIndex))
                                : null,
                        icon: const Icon(Icons.edit_note_outlined),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Rimuovi promemoria',
                        onPressed:
                            canEditOffsets
                                ? () => unawaited(removeOffset(originalIndex))
                                : null,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    final remindersColumn = _MarketingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Promemoria appuntamenti',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Seleziona fino a ${ReminderSettings.maxOffsetsCount} promemoria automatici. Gli offset sono espressi rispetto all\'inizio appuntamento.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (offsetsEntries.isEmpty)
            const _MarketingEmptyState(
              message:
                  'Nessun promemoria automatico attivo. Aggiungi un orario per inviare promemoria prima dell\'appuntamento.',
            )
          else
            ...offsetsEntries.map(buildOffsetCard),
          if (canAddOffset) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => unawaited(addOffset()),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Aggiungi promemoria'),
              ),
            ),
          ],
        ],
      ),
    );

    final birthdayColumn = _MarketingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stackHeader = constraints.maxWidth < 460;
              final description = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auguri di compleanno',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Configura l\'invio automatico del compleanno su push, WhatsApp o entrambi.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
              final toggle = Switch.adaptive(
                value: reminder.birthdayEnabled,
                onChanged:
                    onChanged == null
                        ? null
                        : (value) => unawaited(toggleBirthday(value)),
              );
              if (stackHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [description, const SizedBox(height: 10), toggle],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: description),
                  const SizedBox(width: 12),
                  toggle,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _MarketingFieldLabel(label: 'Tipo messaggio', theme: theme),
          const SizedBox(height: 6),
          DropdownButtonFormField<ReminderDeliveryMode>(
            key: const ValueKey('birthday_delivery_mode_field'),
            isExpanded: true,
            initialValue: reminder.birthdayDeliveryMode,
            decoration: const InputDecoration(isDense: true),
            items: const [
              DropdownMenuItem(
                value: ReminderDeliveryMode.push,
                child: Text('Push'),
              ),
              DropdownMenuItem(
                value: ReminderDeliveryMode.whatsapp,
                child: Text('WhatsApp'),
              ),
              DropdownMenuItem(
                value: ReminderDeliveryMode.both,
                child: Text('Push + WhatsApp'),
              ),
            ],
            onChanged:
                onChanged == null
                    ? null
                    : (value) {
                      if (value != null) {
                        unawaited(updateBirthdayDeliveryMode(value));
                      }
                    },
          ),
          if (reminder.birthdaySendsWhatsapp) ...[
            const SizedBox(height: 12),
            _MarketingFieldLabel(label: 'Template WhatsApp', theme: theme),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: const ValueKey('birthday_whatsapp_template_field'),
              isExpanded: true,
              initialValue: selectedBirthdayWhatsappTemplate?.id,
              decoration: const InputDecoration(isDense: true),
              hint: const Text('Seleziona template WhatsApp'),
              items: birthdayWhatsAppTemplates
                  .map(
                    (template) => DropdownMenuItem<String>(
                      value: template.id,
                      child: Text(template.title),
                    ),
                  )
                  .toList(growable: false),
              onChanged:
                  onChanged != null && birthdayWhatsAppTemplates.isNotEmpty
                      ? (value) {
                        if (value != null) {
                          unawaited(updateBirthdayWhatsappTemplate(value));
                        }
                      }
                      : null,
            ),
            if (birthdayWhatsAppTemplates.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Nessun template WhatsApp con uso Compleanno disponibile.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              )
            else if (birthdayWhatsappTemplateMissing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Template compleanno selezionato non disponibile o non piu attivo. Selezionane uno nuovo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 14),
          _MarketingFieldLabel(label: 'Messaggio di auguri', theme: theme),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  templateTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(templateBody, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (reminder.birthdaySendsPush)
                const _MarketingMetaChip(
                  label: 'Push',
                  icon: Icons.smartphone_rounded,
                ),
              if (reminder.birthdaySendsWhatsapp)
                const _MarketingMetaChip(
                  label: 'WhatsApp',
                  icon: Icons.chat_rounded,
                ),
              if (reminder.birthdaySendsWhatsapp &&
                  selectedBirthdayWhatsappTemplate != null)
                _MarketingMetaChip(
                  label: selectedBirthdayWhatsappTemplate.title,
                  icon: Icons.article_outlined,
                ),
              if (reminder.birthdaySendsWhatsapp &&
                  reminder.birthdayWhatsappTemplateName != null &&
                  selectedBirthdayWhatsappTemplate == null)
                _MarketingMetaChip(
                  label: reminder.birthdayWhatsappTemplateName!,
                  icon: Icons.article_outlined,
                ),
              _MarketingMetaChip(
                label:
                    reminder.birthdayDeliveryMode == ReminderDeliveryMode.push
                        ? 'Solo push'
                        : reminder.birthdayDeliveryMode ==
                            ReminderDeliveryMode.whatsapp
                        ? 'Solo WhatsApp'
                        : 'Push + WhatsApp',
                icon:
                    reminder.birthdayDeliveryMode == ReminderDeliveryMode.push
                        ? Icons.smartphone_rounded
                        : reminder.birthdayDeliveryMode ==
                            ReminderDeliveryMode.whatsapp
                        ? Icons.chat_rounded
                        : Icons.sync_alt_rounded,
              ),
              _MarketingMetaChip(
                label:
                    templatePresent
                        ? (templateActive ? 'Attivo' : 'Disattivato')
                        : 'Da configurare',
                icon:
                    templatePresent
                        ? (templateActive
                            ? Icons.check_circle_outline_rounded
                            : Icons.cancel_outlined)
                        : Icons.info_outline_rounded,
                foregroundColor:
                    templatePresent && templateActive
                        ? const Color(0xFF16A34A)
                        : templatePresent
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          if (!templatePresent) ...[
            const SizedBox(height: 10),
            Text(
              'Non hai ancora personalizzato il messaggio: verrà usato il testo predefinito.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed:
                onEditBirthdayTemplate == null
                    ? null
                    : () => unawaited(onEditBirthdayTemplate!()),
            icon: const Icon(Icons.edit_rounded),
            label: Text(
              templatePresent ? 'Modifica messaggio' : 'Configura messaggio',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            updatedLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              remindersColumn,
              const SizedBox(height: 16),
              birthdayColumn,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 11, child: remindersColumn),
            const SizedBox(width: 16),
            Expanded(flex: 8, child: birthdayColumn),
          ],
        );
      },
    );
  }
}

class _MarketingPanel extends StatelessWidget {
  const _MarketingPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = isAdminPhoneWidth(constraints.maxWidth) ? 14.0 : 18.0;
          return Padding(padding: EdgeInsets.all(padding), child: child);
        },
      ),
    );
  }
}

class _MarketingSectionHeading extends StatelessWidget {
  const _MarketingSectionHeading({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackVertically = constraints.maxWidth < 720;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
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
        );
        if (trailing == null) {
          return heading;
        }
        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 16),
            trailing!,
          ],
        );
      },
    );
  }
}

class _MarketingFieldLabel extends StatelessWidget {
  const _MarketingFieldLabel({required this.label, required this.theme});

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _MarketingMetaChip extends StatelessWidget {
  const _MarketingMetaChip({
    required this.label,
    required this.icon,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foregroundColor ?? theme.colorScheme.onSurface;
    final bg =
        backgroundColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final border =
        borderColor ?? theme.colorScheme.outlineVariant.withValues(alpha: 0.9);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.hasBoundedWidth
                ? math.min(320.0, constraints.maxWidth)
                : 320.0;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MarketingInlineNotice extends StatelessWidget {
  const _MarketingInlineNotice({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError ? theme.colorScheme.error : theme.colorScheme.primary;
    return Text(
      message,
      style: theme.textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MarketingEmptyState extends StatelessWidget {
  const _MarketingEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MarketingSwitchPill extends StatelessWidget {
  const _MarketingSwitchPill({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

const _messagesTabDefinitions = [
  _MessagesTabDefinition(label: 'Automazione', icon: Icons.autorenew_rounded),
  _MessagesTabDefinition(label: 'Manuali', icon: Icons.mail_outline_rounded),
  _MessagesTabDefinition(label: 'Promozioni', icon: Icons.sell_outlined),
  _MessagesTabDefinition(label: 'Last-minute', icon: Icons.bolt_rounded),
];

Widget _buildTabBar(ThemeData theme, List<_MessagesTabDefinition> tabs) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: theme.colorScheme.outlineVariant),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = isAdminPhoneWidth(constraints.maxWidth);
        return TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: isPhone ? 8 : 10,
            vertical: isPhone ? 6 : 8,
          ),
          labelPadding: EdgeInsets.symmetric(horizontal: isPhone ? 8 : 10),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onSurface,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          tabs:
              tabs
                  .map(
                    (tab) => Tab(
                      icon: Icon(tab.icon, size: 16),
                      text: tab.label,
                      height: isPhone ? 60 : null,
                    ),
                  )
                  .toList(),
        );
      },
    ),
  );
}

class _MessagesTabDefinition {
  const _MessagesTabDefinition({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
