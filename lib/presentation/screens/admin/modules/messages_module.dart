import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/message_template.dart';
import 'package:civiapp/domain/entities/salon.dart';
import 'package:civiapp/presentation/common/bottom_sheet_utils.dart';
import 'package:civiapp/presentation/screens/admin/forms/message_template_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MessagesModule extends ConsumerWidget {
  const MessagesModule({super.key, this.salonId});

  final String? salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final templates = data.messageTemplates
        .where((template) => salonId == null || template.salonId == salonId)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    final salons = data.salons;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _openForm(context, ref, salons: salons, defaultSalonId: salonId),
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Nuovo template'),
            ),
          );
        }
        final template = templates[index - 1];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(template.title, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Switch(
                      value: template.isActive,
                      onChanged: (_) {},
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    _Badge(label: _channelLabel(template.channel), icon: Icons.chat_rounded),
                    _Badge(label: _usageLabel(template.usage), icon: Icons.campaign_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Text(template.body),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _openForm(
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
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
      const SnackBar(content: Text('Crea un salone prima di definire i messaggi.')),
    );
    return;
  }
  final result = await showAppModalSheet<MessageTemplate>(
    context: context,
    builder: (ctx) => MessageTemplateFormSheet(
      salons: salons,
      defaultSalonId: defaultSalonId,
      initial: existing,
    ),
  );
  if (result != null) {
    await ref.read(appDataProvider.notifier).upsertTemplate(result);
  }
}
