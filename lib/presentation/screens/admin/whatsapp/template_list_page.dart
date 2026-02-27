import 'dart:async';

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
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = _wrapCardWidth(constraints.maxWidth);
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: templates
                      .map(
                        (template) => SizedBox(
                          width: cardWidth,
                          child: _TemplateCard(template: template),
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
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = _wrapCardWidth(constraints.maxWidth);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: templates
                          .map(
                            (template) => SizedBox(
                              width: cardWidth,
                              child: _MetaTemplateCard(
                                salonId: salonId,
                                template: template,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showMetaPreviewDialog(context, template),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                      await Clipboard.setData(
                        ClipboardData(text: template.name),
                      );
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
              const SizedBox(height: 8),
              Text(
                'Tocca la card per vedere l’anteprima',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMetaPreviewDialog(
    BuildContext context,
    MetaWhatsAppTemplate template,
  ) {
    final theme = Theme.of(context);
    final preview =
        (template.bodyPreview == null || template.bodyPreview!.trim().isEmpty)
            ? 'Anteprima non disponibile per questo template Meta.'
            : template.bodyPreview!.trim();

    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(template.name),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (template.language != null)
                        _buildMetaChip(theme, template.language!),
                      if (template.category != null)
                        _buildMetaChip(theme, template.category!),
                      if (template.status != null)
                        _buildMetaChip(theme, template.status!),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(preview, style: theme.textTheme.bodyMedium),
                  ),
                  if (template.rejectedReason != null &&
                      template.rejectedReason!.trim().isNotEmpty &&
                      template.rejectedReason!.trim().toUpperCase() !=
                          'NONE') ...[
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Chiudi'),
              ),
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
    final existingLocalTemplate = ref
        .read(appDataProvider)
        .messageTemplates
        .where(
          (item) =>
              item.salonId == widget.salonId &&
              item.channel == MessageChannel.whatsapp &&
              item.resolvedMetaTemplateName == template.name,
        )
        .cast<MessageTemplate?>()
        .firstWhere((item) => item != null, orElse: () => null);

    setState(() => _isSaving = true);
    try {
      final localTemplate = MessageTemplate(
        id: existingLocalTemplate?.id ?? 'wa_${template.name}',
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
        metaTemplateName: template.name,
        metaTemplateLanguage: template.language,
      );

      await ref.read(appDataProvider.notifier).upsertTemplate(localTemplate);

      if (!context.mounted) {
        return;
      }
      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            'Template salvato in YouBook. '
            'La lingua (${template.language ?? 'it'}) verrà usata automaticamente nel tab invio.',
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
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _showPreviewDialog(context, template),
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
                  const SizedBox(width: 8),
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
                  PopupMenuButton<TemplateUsage>(
                    tooltip: 'Cambia scope template',
                    onSelected:
                        (usage) => unawaited(
                          _changeTemplateUsage(context, ref, template, usage),
                        ),
                    itemBuilder:
                        (context) => TemplateUsage.values
                            .map(
                              (usage) => PopupMenuItem<TemplateUsage>(
                                value: usage,
                                child: Row(
                                  children: [
                                    if (usage == template.usage)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      )
                                    else
                                      const SizedBox(width: 18),
                                    const SizedBox(width: 8),
                                    Text(_usageLabel(usage)),
                                  ],
                                ),
                              ),
                            )
                            .toList(growable: false),
                    child: Chip(
                      label: Text(_usageLabel(template.usage)),
                      avatar: const Icon(Icons.sell_rounded, size: 16),
                    ),
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
              if ((template.resolvedMetaTemplateName ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Nome template Meta: ${template.resolvedMetaTemplateName}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Tocca la card per vedere l’anteprima',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: 'Copia nome template Meta',
                    onPressed: () => _copyTemplateId(context, template),
                    icon: const Icon(Icons.content_paste_go_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Elimina template',
                    onPressed: () => _deleteTemplate(context, ref, template),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
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

  Future<void> _changeTemplateUsage(
    BuildContext context,
    WidgetRef ref,
    MessageTemplate template,
    TemplateUsage usage,
  ) async {
    if (template.usage == usage) {
      return;
    }

    final updated = MessageTemplate(
      id: template.id,
      salonId: template.salonId,
      title: template.title,
      body: template.body,
      channel: template.channel,
      usage: usage,
      isActive: template.isActive,
      metaTemplateName: template.metaTemplateName,
      metaTemplateLanguage: template.metaTemplateLanguage,
    );

    try {
      await ref.read(appDataProvider.notifier).upsertTemplate(updated);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scope aggiornato: ${_usageLabel(usage)}')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aggiornare lo scope: $error')),
      );
    }
  }

  void _showPreviewDialog(BuildContext context, MessageTemplate template) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(template.title),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((template.resolvedMetaTemplateName ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Nome template Meta: ${template.resolvedMetaTemplateName}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
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
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Chiudi'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    MessageTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Elimina template'),
            content: Text(
              'Vuoi eliminare il template "${template.title}" da YouBook?',
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
          ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(appDataProvider.notifier).deleteTemplate(template.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template eliminato da YouBook.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile eliminare il template: $error')),
      );
    }
  }

  void _copyTemplateId(BuildContext context, MessageTemplate template) {
    final valueToCopy = template.resolvedMetaTemplateName ?? template.id;
    Clipboard.setData(ClipboardData(text: valueToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          template.resolvedMetaTemplateName != null
              ? 'Nome template Meta copiato.'
              : 'ID template locale copiato.',
        ),
      ),
    );
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

double _wrapCardWidth(double maxWidth) {
  const spacing = 12.0;
  if (maxWidth >= 1200) {
    return ((maxWidth - spacing * 2) / 3).clamp(280.0, 420.0).toDouble();
  }
  if (maxWidth >= 760) {
    return ((maxWidth - spacing) / 2).clamp(280.0, 520.0).toDouble();
  }
  return maxWidth;
}
