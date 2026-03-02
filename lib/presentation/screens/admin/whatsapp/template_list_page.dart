import 'dart:async';

import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/presentation/common/hybrid_image_picker.dart';
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
              if (template.hasMediaHeader || template.headerFormat != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (template.hasImageHeader)
                      _buildMetaChip(theme, 'HEADER_IMAGE')
                    else if (template.headerFormat != null)
                      _buildMetaChip(
                        theme,
                        'HEADER_${template.headerFormat!.toUpperCase()}',
                      ),
                  ],
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
                      if (template.headerFormat != null)
                        _buildMetaChip(
                          theme,
                          'HEADER_${template.headerFormat!.toUpperCase()}',
                        ),
                    ],
                  ),
                  if (template.headerTextPreview != null &&
                      template.headerTextPreview!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Header: ${template.headerTextPreview}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
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
      final existingConfig = existingLocalTemplate?.whatsappConfig;
      final mergedConfig =
          existingConfig == null
              ? _defaultWhatsAppConfigForUsage(
                _guessUsage(template.category),
                body:
                    (template.bodyPreview == null ||
                            template.bodyPreview!.trim().isEmpty)
                        ? null
                        : template.bodyPreview!.trim(),
                headerFormat: template.headerFormat,
              )
              : (existingConfig.headerFormat == null &&
                  template.headerFormat != null)
              ? existingConfig.copyWith(headerFormat: template.headerFormat)
              : existingConfig;
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
        whatsappConfig: mergedConfig,
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
                    tooltip: 'Configura parametri template',
                    onPressed: () => _configureTemplate(context, ref, template),
                    icon: const Icon(Icons.tune_rounded),
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
      whatsappConfig: template.whatsappConfig,
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

  Future<void> _configureTemplate(
    BuildContext context,
    WidgetRef ref,
    MessageTemplate template,
  ) async {
    if (template.channel != MessageChannel.whatsapp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La configurazione avanzata e disponibile solo per template WhatsApp.',
          ),
        ),
      );
      return;
    }

    final initialConfig =
        template.whatsappConfig ??
        _defaultWhatsAppConfigForUsage(template.usage, body: template.body);
    String? detectedHeaderFormat = initialConfig.headerFormat;
    final metaTemplateName = template.resolvedMetaTemplateName;
    if ((detectedHeaderFormat ?? '').isEmpty &&
        metaTemplateName != null &&
        metaTemplateName.isNotEmpty) {
      final metaTemplates = ref
          .read(whatsappMetaTemplatesProvider(template.salonId))
          .maybeWhen(
            data: (items) => items,
            orElse: () => const <MetaWhatsAppTemplate>[],
          );
      for (final metaTemplate in metaTemplates) {
        if (metaTemplate.name == metaTemplateName) {
          detectedHeaderFormat = metaTemplate.headerFormat;
          break;
        }
      }
    }

    final configured = await showDialog<WhatsAppTemplateConfig>(
      context: context,
      builder:
          (dialogContext) => _TemplateConfigDialog(
            salonId: template.salonId,
            templateName: template.resolvedMetaTemplateName ?? template.id,
            title: template.title,
            usage: template.usage,
            bodyTemplate: template.body,
            initialConfig: initialConfig,
            detectedHeaderFormat: detectedHeaderFormat,
          ),
    );

    if (configured == null) {
      return;
    }

    final updated = MessageTemplate(
      id: template.id,
      salonId: template.salonId,
      title: template.title,
      body: template.body,
      channel: template.channel,
      usage: template.usage,
      isActive: template.isActive,
      metaTemplateName: template.metaTemplateName,
      metaTemplateLanguage: template.metaTemplateLanguage,
      whatsappConfig: configured,
    );

    try {
      await ref.read(appDataProvider.notifier).upsertTemplate(updated);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurazione template salvata.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossibile salvare la configurazione: $error'),
        ),
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

class _TemplateConfigDialog extends ConsumerStatefulWidget {
  const _TemplateConfigDialog({
    required this.salonId,
    required this.templateName,
    required this.title,
    required this.usage,
    required this.bodyTemplate,
    required this.initialConfig,
    this.detectedHeaderFormat,
  });

  final String salonId;
  final String templateName;
  final String title;
  final TemplateUsage usage;
  final String bodyTemplate;
  final WhatsAppTemplateConfig initialConfig;
  final String? detectedHeaderFormat;

  @override
  ConsumerState<_TemplateConfigDialog> createState() =>
      _TemplateConfigDialogState();
}

class _TemplateConfigDialogState extends ConsumerState<_TemplateConfigDialog> {
  late final List<String> _metaSlots;
  late final List<String> _availableParams;
  late final List<String?> _bodyBindings;
  late final List<TextEditingController> _customValueControllers;
  late final TextEditingController _headerImageUrlController;
  String? _headerBinding;
  late final String? _resolvedHeaderFormat;
  bool _isUploadingHeaderImage = false;
  String? _validationError;
  static const int _maxHeaderImageBytes = 5 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    final defaultConfig = _defaultWhatsAppConfigForUsage(
      widget.usage,
      body: widget.bodyTemplate,
    );
    final initial = widget.initialConfig;
    _resolvedHeaderFormat = _normalizeHeaderFormat(
      initial.headerFormat ?? widget.detectedHeaderFormat,
    );
    final initialBodyBindings = initial.bindings?.body ?? const <String>[];
    final initialHeaderBindings = initial.bindings?.header ?? const <String>[];
    final slotsFromTemplate = _extractMetaPlaceholderSlots(widget.bodyTemplate);
    final fallbackSlots = List<String>.generate(
      initialBodyBindings.length,
      (index) => '${index + 1}',
      growable: false,
    );
    _metaSlots =
        slotsFromTemplate.isNotEmpty ? slotsFromTemplate : fallbackSlots;

    final available = <String>{
      ...defaultConfig.allowedParams,
      ...initial.allowedParams,
    };
    _availableParams =
        available
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .where((item) => !_isNumericMetaToken(item))
            .where((item) => !_isDisabledParamForUsage(widget.usage, item))
            .toSet()
            .toList()
          ..sort();
    _ensureHeaderImageParams(widget.usage, _availableParams);

    _customValueControllers = List<TextEditingController>.generate(
      _metaSlots.length,
      (_) => TextEditingController(),
      growable: false,
    );
    _bodyBindings = List<String?>.generate(_metaSlots.length, (index) {
      if (index >= initialBodyBindings.length) {
        return null;
      }
      final value = initialBodyBindings[index].trim();
      final customValue = _decodeCustomBindingValue(value);
      if (customValue != null) {
        _customValueControllers[index].text = customValue;
        return null;
      }
      if (value.isEmpty ||
          _isNumericMetaToken(value) ||
          _isDisabledParamForUsage(widget.usage, value)) {
        return null;
      }
      if (!_availableParams.contains(value)) {
        _availableParams.add(value);
        _availableParams.sort();
      }
      return value;
    }, growable: false);

    _headerImageUrlController = TextEditingController();
    _headerBinding =
        initialHeaderBindings.isEmpty ? null : initialHeaderBindings.first;
    final headerCustom = _decodeCustomBindingValue(_headerBinding ?? '');
    if (headerCustom != null) {
      _headerImageUrlController.text = headerCustom;
      _headerBinding = null;
    } else if (_headerBinding != null &&
        !_availableParams.contains(_headerBinding)) {
      _availableParams.add(_headerBinding!);
      _availableParams.sort();
    }
  }

  @override
  void dispose() {
    for (final controller in _customValueControllers) {
      controller.dispose();
    }
    _headerImageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewText = _buildPreviewText();
    final hasSlots = _metaSlots.isNotEmpty;
    final hasImageHeader = _resolvedHeaderFormat == 'IMAGE';
    final totalParametersToConfigure =
        _metaSlots.length + (hasImageHeader ? 1 : 0);

    return AlertDialog(
      title: Text('Configura template: ${widget.title}'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Anteprima messaggio', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Parametri da configurare: $totalParametersToConfigure',
                style: theme.textTheme.bodySmall,
              ),
              if ((_resolvedHeaderFormat ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Header Meta rilevato: $_resolvedHeaderFormat',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  previewText.isEmpty
                      ? 'Anteprima non disponibile: corpo template vuoto.'
                      : previewText,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Parametri YouBook disponibili (${_usageLabel(widget.usage)})',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableParams
                    .map((param) => _buildDraggableParamChip(theme, param))
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              Text(
                'Associazione parametri Meta -> parametri YouBook',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Il numero dei parametri e bloccato dal template Meta. Trascina un parametro YouBook su ogni posizione oppure inserisci un testo custom per quel parametro.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (!hasSlots)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Nessun placeholder rilevato nel corpo template. Non ci sono parametri da mappare.',
                  ),
                )
              else
                Column(
                  children: List.generate(
                    _metaSlots.length,
                    (index) => _buildSlotRow(theme, index),
                    growable: false,
                  ),
                ),
              if (hasImageHeader) ...[
                const SizedBox(height: 16),
                _buildHeaderImageSection(theme),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'CTA non configurabile in Fase 2: il bottone resta gestito direttamente in WhatsApp Manager.',
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _validationError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salva configurazione'),
        ),
      ],
    );
  }

  Widget _buildDraggableParamChip(ThemeData theme, String param) {
    final sourceHint = _parameterSourceHint(widget.usage, param);
    return Draggable<String>(
      data: param,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      maxSimultaneousDrags: 1,
      onDragStarted: () {
        setState(() {
          _validationError = null;
        });
      },
      feedback: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(999),
        child: Chip(
          label: Text(param),
          side: BorderSide(color: theme.colorScheme.primary),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: Chip(label: Text(param)),
      ),
      child: Tooltip(
        message: sourceHint ?? 'Parametro custom',
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Chip(
            label: Text(param),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotRow(ThemeData theme, int index) {
    final assigned = _bodyBindings[index];
    final customValue = _customValueControllers[index].text.trim();
    final hasCustomValue = customValue.isNotEmpty;
    final slotToken = _metaSlots[index];

    return Padding(
      padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DragTarget<String>(
              onWillAcceptWithDetails: (details) {
                return !hasCustomValue &&
                    _availableParams.contains(details.data);
              },
              onAcceptWithDetails: (details) {
                setState(() {
                  _bodyBindings[index] = details.data;
                  _customValueControllers[index].clear();
                  _validationError = null;
                });
              },
              builder: (context, candidateData, rejectedData) {
                final isActive = candidateData.isNotEmpty;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                    ),
                    color:
                        isActive
                            ? theme.colorScheme.primaryContainer.withOpacity(
                              0.2,
                            )
                            : theme.colorScheme.surface,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Parametro ${index + 1} (Meta {{$slotToken}})',
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if (assigned != null || hasCustomValue)
                            IconButton(
                              tooltip: 'Svuota mapping',
                              onPressed: () {
                                setState(() {
                                  _bodyBindings[index] = null;
                                  _customValueControllers[index].clear();
                                });
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasCustomValue
                            ? 'Custom: "$customValue"'
                            : assigned == null
                            ? 'Trascina qui un parametro YouBook'
                            : 'YouBook: $assigned',
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (hasCustomValue)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Modalita custom attiva: viene inviato testo fisso.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _customValueControllers[index],
              decoration: InputDecoration(
                labelText: 'Testo custom (opzionale)',
                hintText: 'Valore fisso inviato',
                border: const OutlineInputBorder(),
                isDense: true,
                helperText:
                    'Se compilato, sostituisce il parametro YouBook e aggiorna l\'anteprima.',
              ),
              onChanged: (_) {
                setState(() {
                  if (_customValueControllers[index].text.trim().isNotEmpty) {
                    _bodyBindings[index] = null;
                  }
                  _validationError = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderImageSection(ThemeData theme) {
    final assigned = _headerBinding;
    final customUrl = _headerImageUrlController.text.trim();
    final hasCustomUrl = customUrl.isNotEmpty;
    final hasBinding = assigned != null && assigned.trim().isNotEmpty;
    final showPreview = _isLikelyHttpUrl(customUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Header immagine (Meta)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          'Template con HEADER IMAGE: configura una sorgente URL HTTPS. '
          'Puoi mappare un parametro YouBook oppure caricare l\'immagine da YouBook.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DragTarget<String>(
                onWillAcceptWithDetails:
                    (details) =>
                        !hasCustomUrl &&
                        _availableParams.contains(details.data),
                onAcceptWithDetails: (details) {
                  setState(() {
                    _headerBinding = details.data;
                    _headerImageUrlController.clear();
                    _validationError = null;
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  final isActive = candidateData.isNotEmpty;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                      ),
                      color:
                          isActive
                              ? theme.colorScheme.primaryContainer.withOpacity(
                                0.2,
                              )
                              : theme.colorScheme.surface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Parametro header (Meta IMAGE)',
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            if (hasBinding || hasCustomUrl)
                              IconButton(
                                tooltip: 'Svuota sorgente header',
                                onPressed: () {
                                  setState(() {
                                    _headerBinding = null;
                                    _headerImageUrlController.clear();
                                    _validationError = null;
                                  });
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasCustomUrl
                              ? 'URL custom: $customUrl'
                              : hasBinding
                              ? 'YouBook: $assigned'
                              : 'Trascina qui un parametro URL da YouBook',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _headerImageUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL immagine HTTPS (opzionale)',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText:
                      'Se compilato, sovrascrive il mapping YouBook e viene salvato nel template.',
                ),
                onChanged: (_) {
                  setState(() {
                    if (_headerImageUrlController.text.trim().isNotEmpty) {
                      _headerBinding = null;
                    }
                    _validationError = null;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed:
                  _isUploadingHeaderImage
                      ? null
                      : _uploadHeaderImageFromYouBook,
              icon:
                  _isUploadingHeaderImage
                      ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.upload_file_rounded),
              label: const Text('Carica immagine da YouBook'),
            ),
            if (showPreview)
              OutlinedButton.icon(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder:
                        (dialogContext) => AlertDialog(
                          title: const Text('Anteprima header image'),
                          content: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 480,
                              maxHeight: 360,
                            ),
                            child: Image.network(
                              customUrl,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (context, error, stackTrace) => const Center(
                                    child: Text(
                                      'Impossibile caricare l\'anteprima immagine.',
                                    ),
                                  ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(),
                              child: const Text('Chiudi'),
                            ),
                          ],
                        ),
                  );
                },
                icon: const Icon(Icons.image_outlined),
                label: const Text('Anteprima immagine'),
              ),
          ],
        ),
        if (showPreview) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anteprima URL selezionato',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: Image.network(
                      customUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => Container(
                            height: 120,
                            alignment: Alignment.center,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Text(
                              'Impossibile caricare l\'anteprima immagine.',
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(customUrl, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _uploadHeaderImageFromYouBook() async {
    final selected = await pickSingleImageFile(confirmButtonText: 'Seleziona');
    if (!mounted || selected == null) {
      return;
    }
    final fileSize = await _resolveSelectedFileLength(selected);
    if (fileSize > _maxHeaderImageBytes) {
      final maxMb = (_maxHeaderImageBytes / (1024 * 1024)).toStringAsFixed(1);
      setState(() {
        _validationError = 'L\'immagine supera il limite di $maxMb MB.';
      });
      return;
    }
    final bytes = await _resolveSelectedFileBytes(selected);
    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _validationError = 'Impossibile leggere il file selezionato.';
      });
      return;
    }

    setState(() {
      _isUploadingHeaderImage = true;
      _validationError = null;
    });

    try {
      final storage = ref.read(firebaseStorageServiceProvider);
      final session = ref.read(sessionControllerProvider);
      final upload = await storage.uploadWhatsAppTemplateImage(
        salonId: widget.salonId,
        templateName: widget.templateName,
        data: bytes,
        fileName: selected.name,
        uploaderId: session.uid ?? 'unknown',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _headerImageUrlController.text = upload.downloadUrl;
        _headerBinding = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _validationError = 'Upload immagine non riuscito: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingHeaderImage = false);
      }
    }
  }

  Future<int> _resolveSelectedFileLength(dynamic selected) async {
    try {
      final value = await selected.length();
      return value is int ? value : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<Uint8List?> _resolveSelectedFileBytes(dynamic selected) async {
    try {
      final bytes = await selected.readAsBytes();
      if (bytes is! Uint8List) {
        return null;
      }
      if (bytes.lengthInBytes > _maxHeaderImageBytes) {
        return null;
      }
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  String _buildPreviewText() {
    final body = widget.bodyTemplate.trim();
    if (body.isEmpty) {
      return '';
    }
    var preview = body;
    for (var index = 0; index < _metaSlots.length; index++) {
      final slotToken = _metaSlots[index];
      final assigned = _bodyBindings[index];
      final customValue = _customValueControllers[index].text.trim();
      final fallback =
          assigned != null && assigned.trim().isNotEmpty
              ? '[${assigned.trim()}]'
              : '{{${slotToken.trim()}}}';
      final replacement = customValue.isEmpty ? fallback : customValue;
      final pattern = RegExp(
        r'\{\{\s*' + RegExp.escape(slotToken) + r'\s*\}\}',
      );
      preview = preview.replaceAll(pattern, replacement);
    }
    if (_resolvedHeaderFormat == 'IMAGE') {
      final headerCustom = _headerImageUrlController.text.trim();
      final headerSource =
          headerCustom.isNotEmpty
              ? 'custom image'
              : (_headerBinding?.trim().isNotEmpty ?? false)
              ? _headerBinding!.trim()
              : 'non configurata';
      preview = '$preview\n\n[Header image: $headerSource]';
    }
    return preview;
  }

  void _submit() {
    final allowedParams = _availableParams.toList()..sort();
    final bodyBindings = <String>[];
    var hasIncompleteMapping = false;
    for (var index = 0; index < _metaSlots.length; index++) {
      final customValue = _customValueControllers[index].text.trim();
      if (customValue.isNotEmpty) {
        bodyBindings.add(_encodeCustomBinding(customValue));
        continue;
      }
      final assigned = _bodyBindings[index]?.trim() ?? '';
      if (assigned.isNotEmpty) {
        bodyBindings.add(assigned);
        continue;
      }
      hasIncompleteMapping = true;
      break;
    }
    if (hasIncompleteMapping) {
      setState(() {
        _validationError =
            'Completa il drag and drop o inserisci un testo custom su tutti i parametri Meta prima di salvare.';
      });
      return;
    }

    final headerBindings = <String>[];
    final headerCustomUrl = _headerImageUrlController.text.trim();
    final hasHeaderMapping = (_headerBinding?.trim().isNotEmpty ?? false);
    final requiresImageHeader = _resolvedHeaderFormat == 'IMAGE';
    if (headerCustomUrl.isNotEmpty) {
      if (!_isHttpsUrl(headerCustomUrl)) {
        setState(() {
          _validationError =
              'L\'URL header immagine deve iniziare con https://';
        });
        return;
      }
      headerBindings.add(_encodeCustomBinding(headerCustomUrl));
    } else if (hasHeaderMapping) {
      final binding = _headerBinding!.trim();
      if (!allowedParams.contains(binding)) {
        setState(() {
          _validationError =
              'Il parametro header selezionato non e presente nei parametri disponibili.';
        });
        return;
      }
      headerBindings.add(binding);
    } else if (requiresImageHeader) {
      setState(() {
        _validationError =
            'Questo template richiede un header immagine: carica un\'immagine o mappa un parametro URL.';
      });
      return;
    }

    final hasInvalidMapping = bodyBindings.any(
      (item) => !_isCustomBinding(item) && !allowedParams.contains(item),
    );
    if (hasInvalidMapping) {
      setState(() {
        _validationError =
            'Uno o piu parametri body non sono presenti nei parametri disponibili.';
      });
      return;
    }

    final config = WhatsAppTemplateConfig(
      schemaVersion: 3,
      allowedParams: List<String>.unmodifiable(allowedParams),
      headerFormat: _resolvedHeaderFormat,
      bindings: WhatsAppTemplateBindings(
        body: List<String>.unmodifiable(bodyBindings),
        header: List<String>.unmodifiable(headerBindings),
        buttons: const <WhatsAppTemplateButtonBinding>[],
      ),
    );

    Navigator.of(context).pop(config);
  }
}

WhatsAppTemplateConfig _defaultWhatsAppConfigForUsage(
  TemplateUsage usage, {
  String? body,
  String? headerFormat,
}) {
  final defaults = _defaultAllowedParamsForUsage(usage);
  final fallbackBody =
      body != null && body.trim().isNotEmpty
          ? _extractPlaceholdersInOrder(body)
          : const <String>[];
  final fallbackHasNumericSlots =
      fallbackBody.isNotEmpty && fallbackBody.every(_isNumericMetaToken);
  final bodyBindings =
      fallbackBody.isNotEmpty && !fallbackHasNumericSlots
          ? fallbackBody
          : const <String>[];
  return WhatsAppTemplateConfig(
    schemaVersion: 2,
    allowedParams: List<String>.unmodifiable(defaults),
    headerFormat: _normalizeHeaderFormat(headerFormat),
    bindings: WhatsAppTemplateBindings(
      body: List<String>.unmodifiable(bodyBindings),
      header: const <String>[],
      buttons: const <WhatsAppTemplateButtonBinding>[],
    ),
  );
}

List<String> _defaultAllowedParamsForUsage(TemplateUsage usage) {
  switch (usage) {
    case TemplateUsage.reminder:
      return const <String>[
        'firstName',
        'lastName',
        'clientName',
        'serviceName',
        'staffName',
        'dateTimeFull',
        'date',
        'time',
        'salonName',
      ];
    case TemplateUsage.promotion:
      return const <String>[
        'clientName',
        'promotionTitle',
        'promotionSubtitle',
        'discountPercentage',
        'startsAtDateTimeFull',
        'startsAtDate',
        'startsAtTime',
        'endsAtDateTimeFull',
        'endsAtDate',
        'endsAtTime',
        'startsAt',
        'endsAt',
        'salonName',
        'landingUrl',
        'ctaLabel',
        'promotionCoverImageUrl',
        'promotionImageUrl',
        'coverImageUrl',
        'imageUrl',
      ];
    case TemplateUsage.followUp:
      return const <String>[
        'firstName',
        'clientName',
        'salonName',
        'serviceName',
      ];
    case TemplateUsage.birthday:
      return const <String>['firstName', 'clientName', 'date', 'salonName'];
  }
}

List<String> _extractPlaceholdersInOrder(String body) {
  if (body.trim().isEmpty) {
    return const <String>[];
  }
  final matches = RegExp(r'\{\{\s*([^}]+?)\s*\}\}').allMatches(body);
  return matches
      .map((match) => (match.group(1) ?? '').trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<String> _extractMetaPlaceholderSlots(String body) {
  final tokens = _extractPlaceholdersInOrder(body);
  if (tokens.isEmpty) {
    return const <String>[];
  }

  final isNumericOnly = tokens.every(_isNumericMetaToken);
  if (isNumericOnly) {
    final indices = <int>{};
    for (final token in tokens) {
      indices.add(int.parse(token));
    }
    final sorted = indices.toList()..sort();
    return sorted.map((item) => '$item').toList(growable: false);
  }

  final seen = <String>{};
  final ordered = <String>[];
  for (final token in tokens) {
    if (seen.add(token)) {
      ordered.add(token);
    }
  }
  return ordered;
}

bool _isNumericMetaToken(String value) {
  return RegExp(r'^\d+$').hasMatch(value.trim());
}

const String _customBindingPrefix = 'custom:';

bool _isCustomBinding(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.startsWith(_customBindingPrefix);
}

String _encodeCustomBinding(String value) {
  return '$_customBindingPrefix$value';
}

String? _decodeCustomBindingValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (!_isCustomBinding(trimmed)) {
    return null;
  }
  return trimmed.substring(_customBindingPrefix.length);
}

String? _normalizeHeaderFormat(String? raw) {
  if (raw == null) {
    return null;
  }
  final normalized = raw.trim().toUpperCase();
  return normalized.isEmpty ? null : normalized;
}

void _ensureHeaderImageParams(TemplateUsage usage, List<String> values) {
  if (usage != TemplateUsage.promotion) {
    return;
  }
  const required = <String>[
    'promotionCoverImageUrl',
    'promotionImageUrl',
    'coverImageUrl',
    'imageUrl',
  ];
  var changed = false;
  for (final item in required) {
    if (!values.contains(item)) {
      values.add(item);
      changed = true;
    }
  }
  if (changed) {
    values.sort();
  }
}

bool _isLikelyHttpUrl(String raw) {
  final value = raw.trim().toLowerCase();
  return value.startsWith('http://') || value.startsWith('https://');
}

bool _isHttpsUrl(String raw) {
  return raw.trim().toLowerCase().startsWith('https://');
}

bool _isDisabledParamForUsage(TemplateUsage usage, String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return false;
  }
  if (usage == TemplateUsage.reminder && normalized == 'reminderOffsetLabel') {
    return true;
  }
  return false;
}

String? _parameterSourceHint(TemplateUsage usage, String parameter) {
  switch (usage) {
    case TemplateUsage.reminder:
      const reminderSources = <String, String>{
        'firstName': 'Cliente.nome',
        'lastName': 'Cliente.cognome',
        'clientName': 'Cliente.nomeCompleto',
        'serviceName': 'Appuntamento.servizio.nome',
        'staffName': 'Appuntamento.staff.nome',
        'dateTimeFull': 'Appuntamento data+ora (es. 15 aprile alle 15:00)',
        'date': 'Appuntamento solo data (es. 15 aprile)',
        'time': 'Appuntamento solo ora (es. 15:00)',
        'appointmentLabel':
            'Legacy: Appuntamento data+ora (es. 15 aprile alle 15:00)',
        'salonName': 'Salone.nome',
      };
      return reminderSources[parameter];
    case TemplateUsage.promotion:
      const promotionSources = <String, String>{
        'clientName': 'Cliente.nomeCompleto',
        'promotionTitle': 'Promotion.title (Tab Promozioni)',
        'promotionSubtitle': 'Promotion.subtitle (Tab Promozioni)',
        'discountPercentage': 'Promotion.discountPercentage',
        'startsAtDateTimeFull':
            'Promotion.startsAt completa (es. 15 aprile alle 15:00)',
        'startsAtDate': 'Promotion.startsAt solo data (es. 15 aprile)',
        'startsAtTime': 'Promotion.startsAt solo ora (es. 15:00)',
        'endsAtDateTimeFull':
            'Promotion.endsAt completa (es. 20 aprile alle 18:30)',
        'endsAtDate': 'Promotion.endsAt solo data (es. 20 aprile)',
        'endsAtTime': 'Promotion.endsAt solo ora (es. 18:30)',
        'startsAt': 'Legacy: Promotion.startsAt completa',
        'endsAt': 'Legacy: Promotion.endsAt completa',
        'salonName': 'Salone.nome',
        'landingUrl': 'Promotion.ctaUrl o Promotion.cta.url',
        'ctaLabel': 'Promotion.cta.label',
        'promotionCoverImageUrl':
            'Promotion.coverImageUrl (Tab Promozioni / media salvata)',
        'promotionImageUrl': 'Alias: Promotion.coverImageUrl',
        'coverImageUrl': 'Alias: Promotion.coverImageUrl',
        'imageUrl': 'Alias: Promotion.coverImageUrl',
      };
      return promotionSources[parameter];
    case TemplateUsage.followUp:
      const followUpSources = <String, String>{
        'firstName': 'Cliente.nome',
        'clientName': 'Cliente.nomeCompleto',
        'salonName': 'Salone.nome',
        'serviceName': 'Appuntamento.servizio.nome',
      };
      return followUpSources[parameter];
    case TemplateUsage.birthday:
      const birthdaySources = <String, String>{
        'firstName': 'Cliente.nome',
        'clientName': 'Cliente.nomeCompleto',
        'date': 'Cliente.birthDate formattata',
        'salonName': 'Salone.nome',
      };
      return birthdaySources[parameter];
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
