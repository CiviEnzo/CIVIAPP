import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/message_template.dart';
import 'package:civiapp/domain/entities/reminder_settings.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/message_template_form_sheet.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MessagesModule extends ConsumerWidget {
  const MessagesModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final templates =
        data.messageTemplates
            .where((template) => salonId == null || template.salonId == salonId)
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    final salons = data.salons;
    final currentSalonId =
        salonId ?? (salons.length == 1 ? salons.first.id : null);
    final reminderSettings =
        currentSalonId == null
            ? null
            : data.reminderSettings.firstWhereOrNull(
              (settings) => settings.salonId == currentSalonId,
            );
    final effectiveSettings =
        currentSalonId == null
            ? null
            : (reminderSettings ?? ReminderSettings(salonId: currentSalonId));
    final salonName =
        currentSalonId == null
            ? null
            : salons
                .firstWhereOrNull((salon) => salon.id == currentSalonId)
                ?.name;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length + 2,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _ReminderSettingsCard(
            salonId: currentSalonId,
            salonName: salonName,
            settings: effectiveSettings,
            onChanged: (updated) async {
              await ref
                  .read(appDataProvider.notifier)
                  .upsertReminderSettings(updated);
            },
          );
        }
        if (index == 1) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed:
                  () => _openForm(
                    context,
                    ref,
                    salons: salons,
                    defaultSalonId: salonId,
                  ),
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Nuovo template'),
            ),
          );
        }
        final template = templates[index - 2];
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
                        template.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Switch(value: template.isActive, onChanged: (_) {}),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
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
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Text(template.body),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed:
                        () => _openForm(
                          context,
                          ref,
                          salons: salons,
                          defaultSalonId: salonId,
                          existing: template,
                        ),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Modifica template'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _channelLabel(MessageChannel channel) {
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

  String _usageLabel(TemplateUsage usage) {
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

class _ReminderSettingsCard extends StatelessWidget {
  const _ReminderSettingsCard({
    required this.salonId,
    required this.salonName,
    required this.settings,
    required this.onChanged,
  });

  final String? salonId;
  final String? salonName;
  final ReminderSettings? settings;
  final Future<void> Function(ReminderSettings) onChanged;

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

    Future<void> toggle(ReminderSettings updated) async {
      await onChanged(updated);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Promemoria appuntamenti', style: theme.textTheme.titleMedium),
            if (salonName != null) ...[
              const SizedBox(height: 4),
              Text(salonName!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: reminder.dayBeforeEnabled,
              title: const Text('1 giorno prima'),
              subtitle: const Text(
                'Promemoria il giorno precedente alle 24 ore dal servizio.',
              ),
              onChanged:
                  (value) => toggle(reminder.copyWith(dayBeforeEnabled: value)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: reminder.threeHoursEnabled,
              title: const Text('3 ore prima'),
              subtitle: const Text(
                'Avviso a 180 minuti dall\'inizio dell\'appuntamento.',
              ),
              onChanged:
                  (value) =>
                      toggle(reminder.copyWith(threeHoursEnabled: value)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: reminder.oneHourEnabled,
              title: const Text('1 ora prima'),
              subtitle: const Text(
                'Notifica finale a 60 minuti dal trattamento.',
              ),
              onChanged:
                  (value) => toggle(reminder.copyWith(oneHourEnabled: value)),
            ),
            const Divider(height: 24),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: reminder.birthdayEnabled,
              title: const Text('Auguri di compleanno'),
              subtitle: const Text(
                'Invia un messaggio push automatico il giorno del compleanno.',
              ),
              onChanged:
                  (value) => toggle(reminder.copyWith(birthdayEnabled: value)),
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
