import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/services/whatsapp_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

final whatsappMetaTemplatesProvider =
    FutureProvider.family<List<MetaWhatsAppTemplate>, String>((ref, salonId) {
      final service = ref.watch(whatsappServiceProvider);
      return service.listMetaTemplates(salonId: salonId);
    });

class WhatsAppTemplateListPage extends ConsumerWidget {
  const WhatsAppTemplateListPage({super.key, required this.salonId});

  final String salonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appDataProvider);
    final metaTemplatesAsync = ref.watch(
      whatsappMetaTemplatesProvider(salonId),
    );
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(whatsappMetaTemplatesProvider(salonId));
        await ref.read(whatsappMetaTemplatesProvider(salonId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _MetaTemplatesSection(
            salonId: salonId,
            asyncValue: metaTemplatesAsync,
            onRefresh:
                () => ref.invalidate(whatsappMetaTemplatesProvider(salonId)),
          ),
          const SizedBox(height: 16),
          Text(
            'Template configurati in YouBook',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (templates.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nessun template WhatsApp locale configurato per questo salone. '
                  'Puoi usare i modelli Meta sopra come riferimento e creare il mapping in YouBook.',
                ),
              ),
            )
          else
            ...templates.map((template) => _TemplateCard(template: template)),
        ],
      ),
    );
  }
}

class _MetaTemplatesSection extends StatelessWidget {
  const _MetaTemplatesSection({
    required this.salonId,
    required this.asyncValue,
    required this.onRefresh,
  });

  final String salonId;
  final AsyncValue<List<MetaWhatsAppTemplate>> asyncValue;
  final VoidCallback onRefresh;

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
                    'Modelli Meta (WhatsApp Manager)',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Aggiorna da Meta',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Lista letta dal WABA collegato. Usa il nome modello Meta per il mapping/invio.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            asyncValue.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (error, _) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Errore nel caricamento dei template Meta: $error',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
              data: (templates) {
                if (templates.isEmpty) {
                  return const Text(
                    'Nessun modello trovato sul WABA collegato.',
                  );
                }
                return Column(
                  children: templates
                      .map(
                        (template) => _MetaTemplateCard(
                          salonId: salonId,
                          template: template,
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaTemplateCard extends ConsumerStatefulWidget {
  const _MetaTemplateCard({required this.salonId, required this.template});

  final String salonId;
  final MetaWhatsAppTemplate template;

  @override
  ConsumerState<_MetaTemplateCard> createState() => _MetaTemplateCardState();
}

class _MetaTemplateCardState extends ConsumerState<_MetaTemplateCard> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final template = widget.template;
    final subtitleParts = <String>[
      if (template.language != null) template.language!,
      if (template.category != null) template.category!,
      if (template.status != null) template.status!,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton.outlined(
                tooltip: 'Salva in YouBook (mapping locale)',
                onPressed:
                    _isSaving ? null : () => _saveAsLocalTemplate(context),
                icon: const Icon(Icons.download_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Copia nome modello',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: template.name));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nome modello Meta copiato.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.content_copy_rounded),
              ),
            ],
          ),
          if (subtitleParts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: subtitleParts
                  .map((item) => _buildMetaChip(theme, item))
                  .toList(growable: false),
            ),
          ],
          if (template.bodyPreview != null &&
              template.bodyPreview!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Tooltip(
              message: template.bodyPreview!,
              waitDuration: const Duration(milliseconds: 350),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  template.bodyPreview!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
          if (template.rejectedReason != null &&
              template.rejectedReason!.trim().isNotEmpty &&
              template.rejectedReason!.trim().toUpperCase() != 'NONE') ...[
            const SizedBox(height: 8),
            Text(
              'Motivo rifiuto: ${template.rejectedReason}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChip(ThemeData theme, String raw) {
    final value = raw.trim();
    final upper = value.toUpperCase();

    Color? background;
    Color? foreground;

    if (upper == 'APPROVED' || upper == 'ACTIVE') {
      background = Colors.green.withOpacity(0.12);
      foreground = Colors.green.shade800;
    } else if (upper == 'PENDING' || upper == 'IN_REVIEW') {
      background = Colors.orange.withOpacity(0.12);
      foreground = Colors.orange.shade900;
    } else if (upper == 'REJECTED' || upper == 'PAUSED') {
      background = theme.colorScheme.errorContainer;
      foreground = theme.colorScheme.onErrorContainer;
    } else {
      background = theme.colorScheme.surfaceVariant;
      foreground = theme.colorScheme.onSurfaceVariant;
    }

    return Chip(
      label: Text(value),
      backgroundColor: background,
      labelStyle: theme.textTheme.labelLarge?.copyWith(color: foreground),
      side: BorderSide(color: foreground.withOpacity(0.15)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    );
  }

  Future<void> _saveAsLocalTemplate(BuildContext context) async {
    final template = widget.template;
    final scaffold = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      final localTemplate = MessageTemplate(
        // Il campaign editor usa template.id come templateName Meta.
        id: template.name,
        salonId: widget.salonId,
        title: _buildLocalTitle(template),
        body:
            (template.bodyPreview == null ||
                    template.bodyPreview!.trim().isEmpty)
                ? 'Template Meta: ${template.name}'
                : template.bodyPreview!.trim(),
        channel: MessageChannel.whatsapp,
        usage: _guessUsage(template.category),
        isActive: _isMetaTemplateUsable(template.status),
      );

      await ref.read(appDataProvider.notifier).upsertTemplate(localTemplate);

      if (!context.mounted) {
        return;
      }
      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            'Template salvato in YouBook. '
            'Per il test usa lingua ${template.language ?? 'it'} nel tab invio.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Impossibile salvare il template locale: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _buildLocalTitle(MetaWhatsAppTemplate template) {
    final humanized = template.name
        .split('_')
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
          final trimmed = part.trim();
          return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
        })
        .join(' ');
    final language = template.language;
    if (language == null || language.isEmpty) {
      return humanized;
    }
    return '$humanized [$language]';
  }

  TemplateUsage _guessUsage(String? category) {
    final normalized = (category ?? '').trim().toUpperCase();
    switch (normalized) {
      case 'MARKETING':
        return TemplateUsage.promotion;
      case 'AUTHENTICATION':
        return TemplateUsage.followUp;
      case 'UTILITY':
        return TemplateUsage.reminder;
      default:
        return TemplateUsage.reminder;
    }
  }

  bool _isMetaTemplateUsable(String? status) {
    final normalized = (status ?? '').trim().toUpperCase();
    return normalized == 'APPROVED' || normalized == 'ACTIVE';
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
