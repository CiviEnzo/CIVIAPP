import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/message_template.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

class WhatsAppTemplateListPage extends ConsumerWidget {
  const WhatsAppTemplateListPage({super.key, required this.salonId});

  final String salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final templates =
        data.messageTemplates
            .where(
              (template) =>
                  template.salonId == salonId &&
                  template.channel == MessageChannel.whatsapp,
            )
            .where((template) => template.title.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));

    if (templates.isEmpty) {
      return const Center(
        child: Text('Nessun template WhatsApp configurato per questo salone.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _TemplateCard(template: template);
      },
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.template});

  final MessageTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    template.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Switch.adaptive(
                  value: template.isActive,
                  onChanged: (value) => _toggleTemplate(context, ref, value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(_usageLabel(template.usage)),
                  avatar: const Icon(Icons.sell_rounded, size: 16),
                ),
                Chip(
                  label: Text(template.isActive ? 'Attivo' : 'Disattivato'),
                  avatar: Icon(
                    template.isActive
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                template.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Duplica template',
                  onPressed: () => _duplicateTemplate(context, template),
                  icon: const Icon(Icons.copy_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Copia ID template',
                  onPressed: () => _copyTemplateId(context, template),
                  icon: const Icon(Icons.content_paste_go_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTemplate(
    BuildContext context,
    WidgetRef ref,
    bool isActive,
  ) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('salons')
          .doc(template.salonId)
          .collection('message_templates')
          .doc(template.id)
          .update({'isActive': isActive});
      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            isActive ? 'Template attivato' : 'Template disattivato',
          ),
        ),
      );
    } catch (error) {
      scaffold.showSnackBar(
        SnackBar(content: Text('Impossibile aggiornare il template: $error')),
      );
    }
  }

  void _duplicateTemplate(BuildContext context, MessageTemplate template) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Duplicazione non ancora disponibile'),
            content: const Text(
              'Questo è uno stub: implementa la duplicazione e l’approvazione dei template direttamente dal backoffice Meta.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Capito'),
              ),
            ],
          ),
    );
  }

  void _copyTemplateId(BuildContext context, MessageTemplate template) {
    Clipboard.setData(ClipboardData(text: template.id));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ID template copiato.')));
  }
}

String _usageLabel(TemplateUsage usage) {
  switch (usage) {
    case TemplateUsage.reminder:
      return 'Reminder';
    case TemplateUsage.followUp:
      return 'Follow-up';
    case TemplateUsage.promotion:
      return 'Promozione';
    case TemplateUsage.birthday:
      return 'Compleanno';
  }
}
