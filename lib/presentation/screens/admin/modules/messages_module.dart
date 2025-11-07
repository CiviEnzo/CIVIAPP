import 'dart:async';

import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/last_minute_slot.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/reminder_settings.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/common/bottom_sheet_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/message_template_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/modules/messages/manual_notification_card.dart';
import 'package:you_book/presentation/screens/admin/promotions/promotion_editor_dialog.dart';
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

    Future<void> openTemplateForm({MessageTemplate? existing}) async {
      await _openForm(
        context,
        ref,
        salons: salons,
        defaultSalonId: selectedSalonId,
        existing: existing,
      );
    }

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template di compleanno aggiornato.')),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
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

    Future<void> deleteTemplate(MessageTemplate template) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Elimina template'),
            content: Text(
              'Sei sicuro di voler eliminare il template "${template.title}"?',
            ),
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
      try {
        await ref.read(appDataProvider.notifier).deleteTemplate(template.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template "${template.title}" eliminato.')),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile eliminare il template: $error')),
        );
      }
    }

    return DefaultTabController(
      length: 4,
      child: LayoutBuilder(
        builder: (context, _) {
          List<Widget> withSpacing(List<Widget> children) {
            final spaced = <Widget>[];
            for (var i = 0; i < children.length; i++) {
              if (i > 0) {
                spaced.add(const SizedBox(height: 24));
              }
              spaced.add(children[i]);
            }
            return spaced;
          }

          Widget buildTabContent(List<Widget> children, {String? emptyLabel}) {
            if (children.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    emptyLabel ?? 'Nessun contenuto disponibile.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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
            _TemplatesLibraryCard(
              templates: templates,
              onCreate: salons.isEmpty ? null : () => openTemplateForm(),
              onEdit:
                  salons.isEmpty
                      ? null
                      : (template) => openTemplateForm(existing: template),
              onDelete:
                  salons.isEmpty
                      ? null
                      : (template) => deleteTemplate(template),
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
                settings: effectiveSettings!,
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
              onToggleVisibility:
                  selectedSalonId == null
                      ? null
                      : (value) => toggleLastMinuteVisibility(value),
            ),
          ];

          return Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TabBar(
                  labelColor: theme.colorScheme.primary,
                  tabs: const [
                    Tab(text: 'Automazione'),
                    Tab(text: 'Manuali'),
                    Tab(text: 'Promozioni'),
                    Tab(text: 'Last-minute'),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
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
            ],
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
    ScaffoldMessenger.of(context).showSnackBar(
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
    ).showSnackBar(const SnackBar(content: Text('Promozione eliminata.')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Slot last-minute rimosso.')));
  }
}

class _TemplatesLibraryCard extends StatelessWidget {
  const _TemplatesLibraryCard({
    required this.templates,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MessageTemplate> templates;
  final Future<void> Function()? onCreate;
  final Future<void> Function(MessageTemplate template)? onEdit;
  final Future<void> Function(MessageTemplate template)? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Libreria template',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      onCreate == null ? null : () => unawaited(onCreate!()),
                  icon: const Icon(Icons.add_comment_rounded),
                  label: const Text('Nuovo template'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (templates.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Crea il primo messaggio predefinito per iniziare.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              )
            else
              Column(
                children: List.generate(templates.length, (index) {
                  final template = templates[index];
                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 24),
                      _TemplateTile(
                        template: template,
                        onEdit: onEdit,
                        onDelete: onDelete,
                      ),
                    ],
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  final MessageTemplate template;
  final Future<void> Function(MessageTemplate template)? onEdit;
  final Future<void> Function(MessageTemplate template)? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(template.title, style: theme.textTheme.titleMedium),
            ),
            Switch.adaptive(value: template.isActive, onChanged: null),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Badge(
              label: _channelLabel(template.channel),
              icon: Icons.chat_rounded,
            ),
            _Badge(
              label: _usageLabel(template.usage),
              icon: Icons.campaign_rounded,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(16),
          child: Text(template.body),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed:
                  onEdit == null ? null : () => unawaited(onEdit!(template)),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Modifica'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed:
                  onDelete == null
                      ? null
                      : () => unawaited(onDelete!(template)),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Elimina'),
            ),
          ],
        ),
      ],
    );
  }

  static String _channelLabel(MessageChannel channel) {
    switch (channel) {
      case MessageChannel.push:
        return 'Push';
      case MessageChannel.whatsapp:
        return 'WhatsApp';
      case MessageChannel.email:
        return 'Email';
      case MessageChannel.sms:
        return 'SMS';
    }
  }

  static String _usageLabel(TemplateUsage usage) {
    switch (usage) {
      case TemplateUsage.reminder:
        return 'Promemoria';
      case TemplateUsage.followUp:
        return 'Follow up';
      case TemplateUsage.promotion:
        return 'Promozione';
      case TemplateUsage.birthday:
        return 'Compleanno';
    }
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
    final theme = Theme.of(context);
    final hasSalon = salonId != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Campagne promozionali',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      hasSalon && onCreate != null
                          ? () => unawaited(onCreate!())
                          : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nuova promo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasSalon) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Promozioni visibili ai clienti'),
                subtitle: const Text(
                  'Mostra le campagne attive nella home dell’app cliente.',
                ),
                value: promotionsVisible,
                onChanged:
                    onToggleVisibility == null
                        ? null
                        : (value) => unawaited(onToggleVisibility!(value)),
              ),
              const SizedBox(height: 12),
            ],
            if (!hasSalon)
              Text(
                'Seleziona un salone per creare e gestire le promozioni.',
                style: theme.textTheme.bodyMedium,
              )
            else if (promotions.isEmpty)
              Text(
                'Nessuna promozione salvata. Crea una proposta irresistibile per i tuoi clienti.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Column(
                children: List.generate(promotions.length, (index) {
                  final promotion = promotions[index];
                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 24),
                      _PromotionTile(
                        promotion: promotion,
                        onEdit: onEdit,
                        onToggleActive: onToggleActive,
                        onDelete: onDelete,
                      ),
                    ],
                  );
                }),
              ),
          ],
        ),
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
    final chips = <Widget>[
      _Badge(label: _promotionPeriod(promotion), icon: Icons.schedule_rounded),
      _Badge(
        label: _statusLabel(promotion.status),
        icon: _statusIcon(promotion.status),
      ),
      if (promotion.discountPercentage > 0)
        _Badge(
          label: '-${promotion.discountPercentage.toStringAsFixed(0)}%',
          icon: Icons.local_offer_rounded,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(promotion.title, style: theme.textTheme.titleMedium),
            ),
            Switch.adaptive(
              value: promotion.isActive,
              onChanged:
                  onToggleActive == null
                      ? null
                      : (value) => unawaited(onToggleActive!(promotion, value)),
            ),
          ],
        ),
        if (promotion.subtitle?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(promotion.subtitle!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed:
                  onEdit == null ? null : () => unawaited(onEdit!(promotion)),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Modifica'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed:
                  onDelete == null
                      ? null
                      : () => unawaited(onDelete!(promotion)),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Elimina'),
            ),
          ],
        ),
      ],
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
}

class _LastMinuteDefaultsCard extends StatelessWidget {
  const _LastMinuteDefaultsCard({required this.settings, this.onChanged});

  final ReminderSettings settings;
  final Future<void> Function(ReminderSettings updated)? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Impostazioni last-minute',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LastMinuteNotificationAudience>(
              value: settings.lastMinuteNotificationAudience,
              decoration: const InputDecoration(
                labelText: 'Notifiche last-minute (predefinito)',
                helperText:
                    'Determina cosa proporre quando crei o modifichi uno slot express.',
              ),
              items:
                  LastMinuteNotificationAudience.values.map((audience) {
                    late final String label;
                    switch (audience) {
                      case LastMinuteNotificationAudience.none:
                        label = 'Chiedi ogni volta';
                        break;
                      case LastMinuteNotificationAudience.everyone:
                        label = 'Invia a tutti i clienti';
                        break;
                      case LastMinuteNotificationAudience.ownerSelection:
                        label = 'Scegli manualmente i destinatari';
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
          ],
        ),
      ),
    );
  }
}

class _LastMinuteSection extends StatelessWidget {
  const _LastMinuteSection({
    required this.salonId,
    required this.slots,
    required this.staff,
    required this.featureFlags,
    required this.dateFormat,
    required this.onDelete,
    this.onToggleVisibility,
  });

  final String? salonId;
  final List<LastMinuteSlot> slots;
  final List<StaffMember> staff;
  final SalonFeatureFlags featureFlags;
  final DateFormat dateFormat;
  final Future<void> Function(LastMinuteSlot slot)? onDelete;
  final Future<void> Function(bool value)? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSalon = salonId != null;
    final staffById = {for (final member in staff) member.id: member};
    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Slot last-minute',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasSalon) ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Slot last-minute visibili ai clienti'),
                subtitle: const Text(
                  'Permetti la prenotazione rapida delle offerte last-minute.',
                ),
                value: featureFlags.clientLastMinute,
                onChanged:
                    onToggleVisibility == null
                        ? null
                        : (value) => unawaited(onToggleVisibility!(value)),
              ),
              const SizedBox(height: 12),
            ],
            if (!hasSalon)
              Text(
                'Seleziona un salone per monitorare le offerte express.',
                style: theme.textTheme.bodyMedium,
              )
            else if (slots.isEmpty)
              Text(
                'Trasforma una disponibilità libera in offerta express dal calendario appuntamenti.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Column(
                children: List.generate(slots.length, (index) {
                  final slot = slots[index];
                  final staffName =
                      slot.operatorId != null
                          ? staffById[slot.operatorId!]?.fullName
                          : null;
                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 24),
                      _LastMinuteTile(
                        slot: slot,
                        staffName: staffName,
                        currency: currency,
                        dateFormat: dateFormat,
                        onDelete: onDelete,
                      ),
                    ],
                  );
                }),
              ),
          ],
        ),
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
  });

  final LastMinuteSlot slot;
  final String? staffName;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final Future<void> Function(LastMinuteSlot slot)? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel =
        '${dateFormat.format(slot.start)} · ${slot.duration.inMinutes} min';
    final operatorLabel = staffName ?? 'Operatore non assegnato';
    final priceLabel =
        '${currency.format(slot.priceNow)} · base ${currency.format(slot.basePrice)}';
    final paymentLabel =
        slot.paymentMode == LastMinutePaymentMode.online
            ? 'Pagamento online immediato'
            : 'Pagamento in sede';
    final availabilityLabel =
        slot.isAvailable
            ? 'Disponibile'
            : 'Prenotato da ${slot.bookedClientName?.isNotEmpty == true ? slot.bookedClientName : 'cliente'}';
    final availabilityColor =
        slot.isAvailable ? theme.colorScheme.primary : theme.colorScheme.error;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(slot.serviceName),
      subtitle: Text(
        [timeLabel, operatorLabel, priceLabel, paymentLabel].join('\n'),
      ),
      trailing: IconButton(
        tooltip: 'Rimuovi',
        onPressed: onDelete == null ? null : () => unawaited(onDelete!(slot)),
        icon: const Icon(Icons.delete_outline_rounded),
      ),
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
    this.onChanged,
    this.birthdayTemplate,
    this.onEditBirthdayTemplate,
  });

  final String? salonId;
  final String? salonName;
  final ReminderSettings? settings;
  final String defaultBirthdayTitle;
  final String defaultBirthdayBody;
  final Future<void> Function(ReminderSettings)? onChanged;
  final MessageTemplate? birthdayTemplate;
  final Future<void> Function()? onEditBirthdayTemplate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reminder = settings;
    if (salonId == null || reminder == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Promemoria appuntamenti',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Seleziona un salone per configurare i promemoria automatici.',
              ),
            ],
          ),
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
    final templateTitle =
        templatePresent ? template!.title : defaultBirthdayTitle;
    final templateBody = templatePresent ? template!.body : defaultBirthdayBody;
    final templateActive = template?.isActive ?? true;

    Future<void> emit(ReminderSettings updated) async {
      final callback = onChanged;
      if (callback == null) {
        return;
      }
      await callback(updated);
    }

    String formatOffsetLabel(int totalMinutes) {
      final days = totalMinutes ~/ 1440;
      final hours = (totalMinutes % 1440) ~/ 60;
      final minutes = totalMinutes % 60;
      final parts = <String>[];
      if (days > 0) {
        parts.add(days == 1 ? '1 giorno' : '$days giorni');
      }
      if (hours > 0) {
        parts.add(hours == 1 ? '1 ora' : '$hours ore');
      }
      if (minutes > 0) {
        parts.add('$minutes minuti');
      }
      if (parts.isEmpty) {
        return '$totalMinutes minuti prima';
      }
      if (parts.length == 1) {
        return '${parts.first} prima';
      }
      final last = parts.last;
      final head = parts.sublist(0, parts.length - 1).join(', ');
      return '$head e $last prima';
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

    Future<void> toggleBirthday(bool enabled) async {
      await emit(reminder.copyWith(birthdayEnabled: enabled));
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
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
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

    Future<void> toggleOffsetActive(int index, bool active) async {
      if (!canEditOffsets) {
        return;
      }
      final current = reminder.offsets;
      if (index < 0 || index >= current.length) {
        return;
      }
      await updateOffsetAt(index, current[index].copyWith(active: active));
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
              width: 480,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Promemoria appuntamenti', style: theme.textTheme.titleMedium),

            const SizedBox(height: 12),
            Text(
              'Seleziona fino a ${ReminderSettings.maxOffsetsCount} promemoria automatici. Gli offset sono espressi rispetto all\'inizio appuntamento.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (offsetsEntries.isEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Nessun promemoria automatico attivo'),
                subtitle: const Text(
                  'Aggiungi un orario per inviare promemoria prima dell\'appuntamento.',
                ),
                trailing:
                    canAddOffset
                        ? IconButton(
                          tooltip: 'Aggiungi promemoria',
                          onPressed: () => unawaited(addOffset()),
                          icon: const Icon(Icons.add_alarm),
                        )
                        : null,
              )
            else
              ...offsetsEntries.map((entry) {
                final originalIndex = entry.key;
                final config = entry.value;
                final minutes = config.minutesBefore;
                final parts = splitOffset(minutes);
                final daysValues = {...dayOptions, parts.days}.toList()..sort();
                final hoursValues =
                    {...hourOptions, parts.hours}.toList()..sort();
                final minutesValues =
                    {...minuteOptions, parts.minutes}.toList()..sort();
                final chips = <Widget>[
                  if (config.title != null)
                    Chip(
                      avatar: const Icon(Icons.text_fields, size: 18),
                      label: Text(config.title!),
                    ),
                ];
                return Padding(
                  padding: EdgeInsets.only(
                    top: entry == offsetsEntries.first ? 0 : 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: chips),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Giorni',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: parts.days,
                                  items:
                                      daysValues
                                          .map(
                                            (value) => DropdownMenuItem<int>(
                                              value: value,
                                              child: Text(
                                                value == 1
                                                    ? '1 giorno'
                                                    : '$value giorni',
                                              ),
                                            ),
                                          )
                                          .toList(),
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
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Ore',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: parts.hours,
                                  items:
                                      hoursValues
                                          .map(
                                            (value) => DropdownMenuItem<int>(
                                              value: value,
                                              child: Text(
                                                value == 1
                                                    ? '1 ora'
                                                    : '$value ore',
                                              ),
                                            ),
                                          )
                                          .toList(),
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
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Minuti',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: parts.minutes,
                                  items:
                                      minutesValues
                                          .map(
                                            (value) => DropdownMenuItem<int>(
                                              value: value,
                                              child: Text(
                                                value == 0
                                                    ? '0 minuti'
                                                    : '$value minuti',
                                              ),
                                            ),
                                          )
                                          .toList(),
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
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Modifica testo',
                            onPressed:
                                canEditOffsets
                                    ? () => unawaited(
                                      editOffsetMetadata(originalIndex),
                                    )
                                    : null,
                            icon: const Icon(Icons.edit_note_outlined),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Rimuovi promemoria',
                            onPressed:
                                canEditOffsets
                                    ? () =>
                                        unawaited(removeOffset(originalIndex))
                                    : null,
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            if (offsetsEntries.isNotEmpty) const SizedBox(height: 12),
            if (canAddOffset)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add_alarm),
                  label: const Text('Aggiungi promemoria'),
                  onPressed: () => unawaited(addOffset()),
                ),
              ),
            if (offsetsEntries.isNotEmpty || canAddOffset)
              const Divider(height: 24),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: reminder.birthdayEnabled,
              title: const Text('Auguri di compleanno'),
              subtitle: const Text(
                'Invia un messaggio push automatico il giorno del compleanno.',
              ),
              onChanged:
                  onChanged == null
                      ? null
                      : (value) => unawaited(toggleBirthday(value)),
            ),
            const SizedBox(height: 12),
            Text('Messaggio di auguri', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          templateTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(templateBody, style: theme.textTheme.bodyMedium),
                  if (!templatePresent) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Non hai ancora personalizzato il messaggio: verrà usato il testo predefinito.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.smartphone, size: 18),
                        label: const Text('Push'),
                      ),
                      Chip(
                        avatar: Icon(
                          templatePresent
                              ? (templateActive
                                  ? Icons.check_circle
                                  : Icons.cancel_outlined)
                              : Icons.info_outline,
                          size: 18,
                        ),
                        label: Text(
                          templatePresent
                              ? (templateActive ? 'Attivo' : 'Disattivato')
                              : 'Da configurare',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed:
                    onEditBirthdayTemplate == null
                        ? null
                        : () => unawaited(onEditBirthdayTemplate!()),
                icon: const Icon(Icons.edit_rounded),
                label: Text(
                  templatePresent
                      ? 'Modifica messaggio'
                      : 'Configura messaggio',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(updatedLabel, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

Future<void> _openForm(
  BuildContext context,
  WidgetRef ref, {
  required List<Salon> salons,
  String? defaultSalonId,
  MessageTemplate? existing,
}) async {
  if (salons.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crea un salone prima di definire i messaggi.'),
      ),
    );
    return;
  }
  final result = await showAppModalSheet<MessageTemplate>(
    context: context,
    builder:
        (ctx) => MessageTemplateFormSheet(
          salons: salons,
          defaultSalonId: defaultSalonId,
          initial: existing,
        ),
  );
  if (result != null) {
    await ref.read(appDataProvider.notifier).upsertTemplate(result);
  }
}
