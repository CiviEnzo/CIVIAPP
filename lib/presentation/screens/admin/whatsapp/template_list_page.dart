import 'dart:async';

import 'package:collection/collection.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/domain/entities/promotion.dart';
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
    final linkedTemplatesByMetaName = <String, List<MessageTemplate>>{};
    for (final template in templates) {
      final metaName = _trimToNullLocal(template.resolvedMetaTemplateName);
      if (metaName == null) {
        continue;
      }
      linkedTemplatesByMetaName.putIfAbsent(
        metaName,
        () => <MessageTemplate>[],
      );
      linkedTemplatesByMetaName[metaName]!.add(template);
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(whatsappMetaTemplatesProvider(salonId));
        await ref.read(whatsappMetaTemplatesProvider(salonId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 1100;
              final leftColumn = _MetaTemplatesSection(
                salonId: salonId,
                asyncValue: metaTemplatesAsync,
                onRefresh:
                    () =>
                        ref.invalidate(whatsappMetaTemplatesProvider(salonId)),
                linkedTemplatesByMetaName: linkedTemplatesByMetaName,
              );
              final rightColumn = _LocalTemplatesSection(
                templates: templates,
                metaTemplatesAsync: metaTemplatesAsync,
              );
              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftColumn,
                    const SizedBox(height: 16),
                    rightColumn,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: leftColumn),
                  const SizedBox(width: 16),
                  Expanded(flex: 7, child: rightColumn),
                ],
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
    required this.linkedTemplatesByMetaName,
  });

  final String salonId;
  final AsyncValue<List<MetaWhatsAppTemplate>> asyncValue;
  final VoidCallback onRefresh;
  final Map<String, List<MessageTemplate>> linkedTemplatesByMetaName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _TemplateBoardSectionCard(
      title: 'Modelli Meta',
      subtitle:
          'Lista letta dal WABA collegato. Ogni card mostra i template YouBook collegati allo stesso nome Meta.',
      action: IconButton(
        tooltip: 'Aggiorna da Meta',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: asyncValue.when(
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
            return const Text('Nessun modello trovato sul WABA collegato.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: templates
                .map(
                  (template) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MetaTemplateCard(
                      salonId: salonId,
                      template: template,
                      linkedLocalTemplates:
                          linkedTemplatesByMetaName[template.name.trim()] ??
                          const <MessageTemplate>[],
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _LocalTemplatesSection extends StatelessWidget {
  const _LocalTemplatesSection({
    required this.templates,
    required this.metaTemplatesAsync,
  });

  final List<MessageTemplate> templates;
  final AsyncValue<List<MetaWhatsAppTemplate>> metaTemplatesAsync;

  @override
  Widget build(BuildContext context) {
    final metaTemplatesByName = metaTemplatesAsync.maybeWhen(
      data:
          (items) => {
            for (final item in items)
              if (item.name.trim().isNotEmpty) item.name.trim(): item,
          },
      orElse: () => const <String, MetaWhatsAppTemplate>{},
    );

    return _TemplateBoardSectionCard(
      title: 'Template configurati in YouBook',
      subtitle:
          'Template locali, mapping verso Meta e stato del collegamento in evidenza.',
      child:
          templates.isEmpty
              ? const Text(
                'Nessun template WhatsApp locale configurato per questo salone. '
                'Puoi usare i modelli Meta a sinistra per creare il mapping in YouBook.',
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: templates
                    .map(
                      (template) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TemplateCard(
                          template: template,
                          linkedMetaTemplate:
                              metaTemplatesByName[template
                                      .resolvedMetaTemplateName
                                      ?.trim() ??
                                  ''],
                          metaTemplatesAsync: metaTemplatesAsync,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
    );
  }
}

class _TemplateBoardSectionCard extends StatelessWidget {
  const _TemplateBoardSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 12), action!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetaTemplateCard extends ConsumerStatefulWidget {
  const _MetaTemplateCard({
    required this.salonId,
    required this.template,
    required this.linkedLocalTemplates,
  });

  final String salonId;
  final MetaWhatsAppTemplate template;
  final List<MessageTemplate> linkedLocalTemplates;

  @override
  ConsumerState<_MetaTemplateCard> createState() => _MetaTemplateCardState();
}

class _MetaTemplateCardState extends ConsumerState<_MetaTemplateCard> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final template = widget.template;
    final linkedLocalTemplates = widget.linkedLocalTemplates;
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
                        ScaffoldMessenger.of(context).showAppSnackBar(
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
              const SizedBox(height: 12),
              _buildCorrelationSection(theme, linkedLocalTemplates),
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

  Widget _buildCorrelationSection(
    ThemeData theme,
    List<MessageTemplate> linkedLocalTemplates,
  ) {
    final hasLinks = linkedLocalTemplates.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            hasLinks
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Collegamenti YouBook',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Chip(
                label: Text(
                  hasLinks
                      ? '${linkedLocalTemplates.length} collegati'
                      : 'Nessun collegamento',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!hasLinks)
            Text(
              'Nessun template locale usa ancora questo modello Meta.',
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: linkedLocalTemplates
                  .map(
                    (template) => Chip(
                      label: Text(
                        template.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                      avatar: const Icon(Icons.link_rounded, size: 16),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
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
      scaffold.showAppSnackBar(
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
      scaffold.showAppSnackBar(
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
  const _TemplateCard({
    required this.template,
    required this.linkedMetaTemplate,
    required this.metaTemplatesAsync,
  });

  final MessageTemplate template;
  final MetaWhatsAppTemplate? linkedMetaTemplate;
  final AsyncValue<List<MetaWhatsAppTemplate>> metaTemplatesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resolvedMetaName = _trimToNullLocal(
      template.resolvedMetaTemplateName,
    );
    final metaLookupLoading = metaTemplatesAsync.isLoading;
    final metaLookupError = metaTemplatesAsync.hasError;
    final hasMetaLink = resolvedMetaName != null;
    final missingMetaTemplate =
        hasMetaLink &&
        !metaLookupLoading &&
        !metaLookupError &&
        linkedMetaTemplate == null;

    return Card(
      clipBehavior: Clip.antiAlias,
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
                  if (template.usage == TemplateUsage.promotion)
                    Chip(
                      label: Text(
                        (template.whatsappConfig?.promotionId ?? '')
                                .trim()
                                .isEmpty
                            ? 'Promozione da associare'
                            : 'Promozione collegata',
                      ),
                      avatar: Icon(
                        (template.whatsappConfig?.promotionId ?? '')
                                .trim()
                                .isEmpty
                            ? Icons.warning_amber_rounded
                            : Icons.local_offer_outlined,
                        size: 16,
                      ),
                    ),
                  if (linkedMetaTemplate != null)
                    Chip(
                      label: Text(
                        linkedMetaTemplate!.status?.trim().isNotEmpty == true
                            ? 'Meta ${linkedMetaTemplate!.status}'
                            : 'Meta collegato',
                      ),
                      avatar: const Icon(Icons.verified_outlined, size: 16),
                    )
                  else if (missingMetaTemplate)
                    Chip(
                      label: const Text('Modello Meta non trovato'),
                      avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                    )
                  else if (!hasMetaLink)
                    Chip(
                      label: const Text('Template non collegato a Meta'),
                      avatar: const Icon(Icons.link_off_rounded, size: 16),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMetaLinkSection(
                theme,
                resolvedMetaName: resolvedMetaName,
                metaLookupLoading: metaLookupLoading,
                metaLookupError: metaLookupError,
                missingMetaTemplate: missingMetaTemplate,
              ),
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

  Widget _buildMetaLinkSection(
    ThemeData theme, {
    required String? resolvedMetaName,
    required bool metaLookupLoading,
    required bool metaLookupError,
    required bool missingMetaTemplate,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            missingMetaTemplate
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Correlazione Meta', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          if (resolvedMetaName == null)
            Text(
              'Template non collegato a un modello Meta.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            Text(
              'Modello Meta associato: $resolvedMetaName',
              style: theme.textTheme.bodySmall,
            ),
            if (linkedMetaTemplate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Stato Meta: ${linkedMetaTemplate!.status ?? 'n/d'}'
                '${linkedMetaTemplate!.language?.trim().isNotEmpty == true ? ' • ${linkedMetaTemplate!.language}' : ''}'
                '${linkedMetaTemplate!.category?.trim().isNotEmpty == true ? ' • ${linkedMetaTemplate!.category}' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ] else if (metaLookupLoading) ...[
              const SizedBox(height: 4),
              Text(
                'Verifica del modello Meta in corso...',
                style: theme.textTheme.bodySmall,
              ),
            ] else if (metaLookupError) ...[
              const SizedBox(height: 4),
              Text(
                'Stato Meta non disponibile: impossibile verificare il collegamento ora.',
                style: theme.textTheme.bodySmall,
              ),
            ] else if (missingMetaTemplate) ...[
              const SizedBox(height: 4),
              Text(
                'Il nome Meta salvato non esiste piu tra i modelli restituiti dal WABA collegato.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ],
          ],
        ],
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
      scaffold.showAppSnackBar(
        SnackBar(
          content: Text(
            isActive ? 'Template attivato' : 'Template disattivato',
          ),
        ),
      );
    } catch (error) {
      scaffold.showAppSnackBar(
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
      whatsappConfig:
          usage == TemplateUsage.promotion
              ? template.whatsappConfig
              : template.whatsappConfig?.copyWith(promotionId: ''),
    );

    try {
      await ref.read(appDataProvider.notifier).upsertTemplate(updated);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Scope aggiornato: ${_usageLabel(usage)}')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
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
      ScaffoldMessenger.of(context).showAppSnackBar(
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Configurazione template salvata.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
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
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Template eliminato da YouBook.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Impossibile eliminare il template: $error')),
      );
    }
  }

  void _copyTemplateId(BuildContext context, MessageTemplate template) {
    final valueToCopy = template.resolvedMetaTemplateName ?? template.id;
    Clipboard.setData(ClipboardData(text: valueToCopy));
    ScaffoldMessenger.of(context).showAppSnackBar(
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

enum _TemplateBindingSourceMode { youBookField, fixedValue }

class _TemplateConfigDialogState extends ConsumerState<_TemplateConfigDialog> {
  static const int _maxHeaderImageBytes = 5 * 1024 * 1024;

  late final List<String> _metaSlots;
  late final List<String> _availableParams;
  late final List<String?> _bodyBindings;
  late final List<TextEditingController> _customValueControllers;
  late final List<_TemplateBindingSourceMode> _bodySourceModes;
  late final TextEditingController _headerImageUrlController;
  late final String? _resolvedHeaderFormat;
  late _TemplateBindingSourceMode _headerSourceMode;
  String? _headerBinding;
  String? _selectedPromotionId;
  bool _isUploadingHeaderImage = false;
  String? _validationError;

  bool get _isPromotionUsage => widget.usage == TemplateUsage.promotion;
  bool get _hasHeaderSlot => (_resolvedHeaderFormat ?? '').isNotEmpty;

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
    _selectedPromotionId = _trimToNullLocal(initial.promotionId);
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
    _bodySourceModes = List<_TemplateBindingSourceMode>.filled(
      _metaSlots.length,
      _TemplateBindingSourceMode.youBookField,
      growable: false,
    );
    _bodyBindings = List<String?>.generate(_metaSlots.length, (index) {
      if (index >= initialBodyBindings.length) {
        return null;
      }
      final value = initialBodyBindings[index].trim();
      final customValue = _decodeCustomBindingValue(value);
      if (customValue != null) {
        _bodySourceModes[index] = _TemplateBindingSourceMode.fixedValue;
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
        initialHeaderBindings.isEmpty
            ? null
            : initialHeaderBindings.first.trim();
    final headerCustom = _decodeCustomBindingValue(_headerBinding ?? '');
    if (headerCustom != null) {
      _headerImageUrlController.text = headerCustom;
      _headerBinding = null;
      _headerSourceMode = _TemplateBindingSourceMode.fixedValue;
    } else {
      _headerSourceMode = _TemplateBindingSourceMode.youBookField;
      if ((_headerBinding ?? '').isNotEmpty &&
          !_availableParams.contains(_headerBinding)) {
        _availableParams.add(_headerBinding!);
        _availableParams.sort();
      }
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
    final data = ref.watch(appDataProvider);
    final salonName =
        data.salons
            .firstWhereOrNull((salon) => salon.id == widget.salonId)
            ?.name
            .trim();
    final promotions =
        data.promotions
            .where((promotion) => promotion.salonId == widget.salonId)
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    final selectedPromotion = promotions.firstWhereOrNull(
      (promotion) => promotion.id == _selectedPromotionId,
    );
    final previewContext = _buildPreviewContext(
      selectedPromotion,
      salonName: salonName,
    );
    final parameterGroups = _buildParameterGroups(
      previewContext: previewContext,
      selectedPromotion: selectedPromotion,
    );
    final bodyOptions = _buildBodySelectableParams(parameterGroups);
    final headerOptions = _buildHeaderSelectableParams(
      parameterGroups,
      currentBinding: _headerBinding,
    );
    final previewText = _buildPreviewText(previewContext);
    final totalParametersToConfigure =
        _metaSlots.length + (_hasHeaderSlot ? 1 : 0);

    return AlertDialog(
      title: Text('Configura template: ${widget.title}'),
      content: SizedBox(
        width: 980,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPreviewSection(
                theme,
                previewText: previewText,
                totalParametersToConfigure: totalParametersToConfigure,
                selectedPromotion: selectedPromotion,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 840;
                  final leftColumn = _buildAvailableValuesColumn(
                    theme,
                    promotions: promotions,
                    selectedPromotion: selectedPromotion,
                    parameterGroups: parameterGroups,
                  );
                  final rightColumn = _buildBindingsColumn(
                    theme,
                    bodyOptions: bodyOptions,
                    headerOptions: headerOptions,
                  );
                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftColumn,
                        const SizedBox(height: 16),
                        rightColumn,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: leftColumn),
                      const SizedBox(width: 16),
                      Expanded(child: rightColumn),
                    ],
                  );
                },
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
          onPressed:
              () => _submit(
                bodyOptions: bodyOptions,
                headerOptions: headerOptions,
              ),
          child: const Text('Salva configurazione'),
        ),
      ],
    );
  }

  Widget _buildPreviewSection(
    ThemeData theme, {
    required String previewText,
    required int totalParametersToConfigure,
    required Promotion? selectedPromotion,
  }) {
    final headerConfigured = _hasConfiguredHeaderSource;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Anteprima messaggio', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.tune_rounded, size: 16),
                label: Text(
                  '$totalParametersToConfigure elementi da configurare',
                ),
              ),
              Chip(
                avatar: const Icon(Icons.sell_outlined, size: 16),
                label: Text(_usageLabel(widget.usage)),
              ),
              if (_hasHeaderSlot)
                Chip(
                  avatar: const Icon(Icons.view_headline_rounded, size: 16),
                  label: Text('Header $_resolvedHeaderFormat'),
                ),
              if (_isPromotionUsage)
                Chip(
                  avatar: const Icon(Icons.local_offer_outlined, size: 16),
                  label: Text(
                    selectedPromotion?.title ?? 'Promozione non associata',
                  ),
                ),
            ],
          ),
          if (_hasHeaderSlot && !headerConfigured) ...[
            const SizedBox(height: 10),
            Text(
              'Header non configurato: il salvataggio resta consentito, ma Meta potrebbe rifiutare l\'invio se il template richiede davvero un header.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              previewText.isEmpty
                  ? 'Anteprima non disponibile: corpo template vuoto.'
                  : previewText,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableValuesColumn(
    ThemeData theme, {
    required List<Promotion> promotions,
    required Promotion? selectedPromotion,
    required List<_TemplateParameterGroup> parameterGroups,
  }) {
    return _buildSectionCard(
      theme,
      title: 'Parametri e associazioni',
      subtitle:
          'Anteprima sopra, poi dati disponibili e associazione della promozione al template.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isPromotionUsage) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              value:
                  promotions.any((item) => item.id == _selectedPromotionId)
                      ? _selectedPromotionId
                      : null,
              decoration: const InputDecoration(
                labelText: 'Promozione collegata al template',
                border: OutlineInputBorder(),
              ),
              items: promotions
                  .map(
                    (promotion) => DropdownMenuItem<String>(
                      value: promotion.id,
                      child: Text(promotion.title),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() {
                  _selectedPromotionId = value;
                  _validationError = null;
                });
              },
            ),
            const SizedBox(height: 12),
            if (promotions.isEmpty)
              Text(
                'Nessuna promozione disponibile nel modulo Promozioni.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              )
            else if (selectedPromotion == null)
              Text(
                'Seleziona una promozione per mostrare i campi realmente popolati.',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
          ],
          if (parameterGroups.isEmpty)
            Text(
              'Nessun parametro disponibile per questo template.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final group in parameterGroups) ...[
              Text(group.title, style: theme.textTheme.titleSmall),
              if ((group.subtitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(group.subtitle!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              ...group.entries.map(
                (entry) => _buildParameterPreviewTile(theme, entry),
              ),
              const SizedBox(height: 14),
            ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'CTA non configurabile qui: il bottone resta gestito direttamente in WhatsApp Manager.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterPreviewTile(
    ThemeData theme,
    _TemplateParameterPreview entry,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.key, style: theme.textTheme.labelLarge),
              ),
              Chip(label: Text(entry.isRuntime ? 'Runtime' : 'Promozione')),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.value,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if ((entry.sourceHint ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(entry.sourceHint!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildBindingsColumn(
    ThemeData theme, {
    required List<String> bodyOptions,
    required List<String> headerOptions,
  }) {
    return _buildSectionCard(
      theme,
      title: 'Binding Meta',
      subtitle:
          'Ogni slot sceglie una sola sorgente: campo YouBook o valore fisso.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_metaSlots.isEmpty)
            Text(
              'Nessun placeholder rilevato nel corpo template.',
              style: theme.textTheme.bodySmall,
            )
          else
            ...List.generate(
              _metaSlots.length,
              (index) => Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                child: _buildBodyBindingCard(
                  theme,
                  index: index,
                  selectableParams: _mergeSelectableParams(
                    bodyOptions,
                    _bodyBindings[index],
                  ),
                ),
              ),
            ),
          if (_hasHeaderSlot) ...[
            const SizedBox(height: 16),
            _buildHeaderBindingCard(theme, selectableParams: headerOptions),
          ],
        ],
      ),
    );
  }

  Widget _buildBodyBindingCard(
    ThemeData theme, {
    required int index,
    required List<String> selectableParams,
  }) {
    final mode = _bodySourceModes[index];
    final slot = _metaSlots[index];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parametro ${index + 1} (Meta {{$slot}})',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          _buildSourceModeSelector(
            mode: mode,
            onSelected: (value) {
              setState(() {
                _bodySourceModes[index] = value;
                _validationError = null;
              });
            },
          ),
          const SizedBox(height: 10),
          if (mode == _TemplateBindingSourceMode.youBookField)
            DropdownButtonFormField<String>(
              isExpanded: true,
              value:
                  selectableParams.contains(_bodyBindings[index])
                      ? _bodyBindings[index]
                      : null,
              decoration: const InputDecoration(
                labelText: 'Campo YouBook',
                border: OutlineInputBorder(),
              ),
              items: selectableParams
                  .map(
                    (param) => DropdownMenuItem<String>(
                      value: param,
                      child: Text(param),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() {
                  _bodyBindings[index] = value;
                  _validationError = null;
                });
              },
            )
          else
            TextField(
              controller: _customValueControllers[index],
              decoration: const InputDecoration(
                labelText: 'Valore fisso',
                hintText: 'Testo inviato a Meta',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {
                  _validationError = null;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderBindingCard(
    ThemeData theme, {
    required List<String> selectableParams,
  }) {
    final isImage = (_resolvedHeaderFormat ?? '').toUpperCase() == 'IMAGE';
    final customUrl = _headerImageUrlController.text.trim();
    final showPreview = _isLikelyHttpUrl(customUrl);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Header Meta ${_resolvedHeaderFormat ?? ''}',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            isImage
                ? 'Configurazione opzionale: usa un campo URL di YouBook oppure un URL fisso HTTPS.'
                : 'Configurazione opzionale: usa un campo YouBook oppure un testo fisso.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          _buildSourceModeSelector(
            mode: _headerSourceMode,
            onSelected: (value) {
              setState(() {
                _headerSourceMode = value;
                _validationError = null;
              });
            },
          ),
          const SizedBox(height: 10),
          if (_headerSourceMode == _TemplateBindingSourceMode.youBookField)
            DropdownButtonFormField<String>(
              isExpanded: true,
              value:
                  selectableParams.contains(_headerBinding)
                      ? _headerBinding
                      : null,
              decoration: const InputDecoration(
                labelText: 'Campo YouBook',
                border: OutlineInputBorder(),
              ),
              items: selectableParams
                  .map(
                    (param) => DropdownMenuItem<String>(
                      value: param,
                      child: Text(param),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() {
                  _headerBinding = value;
                  _validationError = null;
                });
              },
            )
          else
            TextField(
              controller: _headerImageUrlController,
              decoration: InputDecoration(
                labelText: isImage ? 'URL fisso HTTPS' : 'Testo fisso',
                hintText: isImage ? 'https://...' : 'Testo header',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {
                  _validationError = null;
                });
              },
            ),
          if (isImage) ...[
            const SizedBox(height: 10),
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
                    onPressed: () => _showHeaderImagePreview(customUrl),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Anteprima immagine'),
                  ),
              ],
            ),
          ],
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceModeSelector({
    required _TemplateBindingSourceMode mode,
    required ValueChanged<_TemplateBindingSourceMode> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Campo YouBook'),
          selected: mode == _TemplateBindingSourceMode.youBookField,
          onSelected:
              (_) => onSelected(_TemplateBindingSourceMode.youBookField),
        ),
        ChoiceChip(
          label: const Text('Valore fisso'),
          selected: mode == _TemplateBindingSourceMode.fixedValue,
          onSelected: (_) => onSelected(_TemplateBindingSourceMode.fixedValue),
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  List<_TemplateParameterGroup> _buildParameterGroups({
    required Map<String, String> previewContext,
    required Promotion? selectedPromotion,
  }) {
    final params =
        _availableParams.toSet()
          ..addAll(_bodyBindings.whereType<String>())
          ..addAll(
            (_headerBinding ?? '').trim().isEmpty
                ? const <String>{}
                : {_headerBinding!},
          );
    final runtimeKeys =
        params
            .where(_isRuntimeTemplateParam)
            .map((item) => item.trim())
            .toSet();

    final groups = <_TemplateParameterGroup>[];
    if (_isPromotionUsage) {
      final promotionEntries = params
        .where((item) => !runtimeKeys.contains(item))
        .map(
          (item) => _TemplateParameterPreview(
            key: item,
            value: _resolvePreviewContextValue(previewContext, item),
            sourceHint: _parameterSourceHint(widget.usage, item),
            isRuntime: false,
          ),
        )
        .where((entry) => entry.value.trim().isNotEmpty)
        .toList(growable: false)..sort((a, b) => a.key.compareTo(b.key));
      groups.add(
        _TemplateParameterGroup(
          title: 'Dati dalla promozione',
          subtitle:
              selectedPromotion == null
                  ? 'Seleziona una promozione per vedere i campi valorizzati.'
                  : 'Sono mostrati solo i valori realmente popolati nella promozione selezionata.',
          entries: promotionEntries,
        ),
      );
    }

    final runtimeEntries = runtimeKeys
      .map(
        (item) => _TemplateParameterPreview(
          key: item,
          value: _resolvePreviewContextValue(previewContext, item),
          sourceHint: _parameterSourceHint(widget.usage, item),
          isRuntime: true,
        ),
      )
      .where((entry) => entry.value.trim().isNotEmpty)
      .toList(growable: false)..sort((a, b) => a.key.compareTo(b.key));
    if (runtimeEntries.isNotEmpty) {
      groups.add(
        _TemplateParameterGroup(
          title: 'Dati runtime',
          subtitle: 'Valori compilati al momento dell\'invio.',
          entries: runtimeEntries,
        ),
      );
    }

    if (!_isPromotionUsage) {
      final otherEntries = params
        .where((item) => !runtimeKeys.contains(item))
        .map(
          (item) => _TemplateParameterPreview(
            key: item,
            value: _resolvePreviewContextValue(previewContext, item),
            sourceHint: _parameterSourceHint(widget.usage, item),
            isRuntime: false,
          ),
        )
        .where((entry) => entry.value.trim().isNotEmpty)
        .toList(growable: false)..sort((a, b) => a.key.compareTo(b.key));
      if (otherEntries.isNotEmpty) {
        groups.insert(
          0,
          _TemplateParameterGroup(
            title: 'Valori disponibili',
            subtitle: 'Anteprima dei parametri risolti per questo scope.',
            entries: otherEntries,
          ),
        );
      }
    }

    return groups
        .where((group) => group.entries.isNotEmpty || _isPromotionUsage)
        .toList(growable: false);
  }

  List<String> _buildBodySelectableParams(
    List<_TemplateParameterGroup> parameterGroups,
  ) {
    final values = <String>{
      for (final group in parameterGroups)
        for (final entry in group.entries) entry.key,
    };
    final result = values.toList()..sort();
    return result;
  }

  List<String> _buildHeaderSelectableParams(
    List<_TemplateParameterGroup> parameterGroups, {
    required String? currentBinding,
  }) {
    final candidates = <String>{};
    for (final group in parameterGroups) {
      for (final entry in group.entries) {
        if (_isLikelyHeaderParam(entry.key, entry.value)) {
          candidates.add(entry.key);
        }
      }
    }
    final binding = _trimToNullLocal(currentBinding);
    if (binding != null) {
      candidates.add(binding);
    }
    final result = candidates.toList()..sort();
    return result;
  }

  List<String> _mergeSelectableParams(List<String> values, String? current) {
    final merged = <String>{...values};
    final binding = _trimToNullLocal(current);
    if (binding != null) {
      merged.add(binding);
    }
    final result = merged.toList()..sort();
    return result;
  }

  bool get _hasConfiguredHeaderSource {
    if (!_hasHeaderSlot) {
      return false;
    }
    if (_headerSourceMode == _TemplateBindingSourceMode.fixedValue) {
      return _headerImageUrlController.text.trim().isNotEmpty;
    }
    return (_headerBinding ?? '').trim().isNotEmpty;
  }

  Map<String, String> _buildPreviewContext(
    Promotion? selectedPromotion, {
    String? salonName,
  }) {
    final base = _buildDefaultPreviewContext(
      widget.usage,
      salonName: salonName,
    );
    if (!_isPromotionUsage) {
      return base;
    }
    return {
      ...base,
      ..._buildPromotionPreviewContext(selectedPromotion, salonName: salonName),
    };
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
        _headerSourceMode = _TemplateBindingSourceMode.fixedValue;
        _headerImageUrlController.text = upload.downloadUrl;
        _validationError = null;
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

  void _showHeaderImagePreview(String imageUrl) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Anteprima header image'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 360),
              child: Image.network(
                imageUrl,
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
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Chiudi'),
              ),
            ],
          ),
    );
  }

  String _buildPreviewText(Map<String, String> previewContext) {
    final body = widget.bodyTemplate.trim();
    if (body.isEmpty) {
      return '';
    }
    var preview = body;
    for (var index = 0; index < _metaSlots.length; index++) {
      final slotToken = _metaSlots[index];
      final replacement = _resolveBodyPreviewValue(index, previewContext);
      final pattern = RegExp(
        r'\{\{\s*' + RegExp.escape(slotToken) + r'\s*\}\}',
      );
      preview = preview.replaceAll(pattern, replacement);
    }
    if (_hasHeaderSlot) {
      final headerPreview = _resolveHeaderPreviewValue(previewContext);
      preview =
          '$preview\n\n[Header ${_resolvedHeaderFormat ?? ''}: ${headerPreview ?? 'non configurato'}]';
    }
    return preview;
  }

  String _resolveBodyPreviewValue(
    int index,
    Map<String, String> previewContext,
  ) {
    if (_bodySourceModes[index] == _TemplateBindingSourceMode.fixedValue) {
      final custom = _customValueControllers[index].text.trim();
      return custom.isEmpty ? '{{${_metaSlots[index]}}}' : custom;
    }
    final binding = _bodyBindings[index]?.trim() ?? '';
    if (binding.isEmpty) {
      return '{{${_metaSlots[index]}}}';
    }
    final resolved = _resolvePreviewContextValue(previewContext, binding);
    return resolved.isEmpty ? '[${binding.trim()}]' : resolved;
  }

  String? _resolveHeaderPreviewValue(Map<String, String> previewContext) {
    if (_headerSourceMode == _TemplateBindingSourceMode.fixedValue) {
      final value = _headerImageUrlController.text.trim();
      return value.isEmpty ? null : value;
    }
    final binding = _headerBinding?.trim() ?? '';
    if (binding.isEmpty) {
      return null;
    }
    final resolved = _resolvePreviewContextValue(previewContext, binding);
    return resolved.isEmpty ? '[${binding.trim()}]' : resolved;
  }

  void _submit({
    required List<String> bodyOptions,
    required List<String> headerOptions,
  }) {
    if (_isPromotionUsage && (_selectedPromotionId ?? '').trim().isEmpty) {
      setState(() {
        _validationError =
            'Associa una promozione al template prima di salvare.';
      });
      return;
    }

    final allowedParams =
        <String>{
            ..._availableParams,
            ...bodyOptions,
            ...headerOptions,
            ..._bodyBindings.whereType<String>().map((item) => item.trim()),
            if ((_headerBinding ?? '').trim().isNotEmpty)
              _headerBinding!.trim(),
          }.toList()
          ..sort();

    final bodyBindings = <String>[];
    for (var index = 0; index < _metaSlots.length; index++) {
      if (_bodySourceModes[index] == _TemplateBindingSourceMode.fixedValue) {
        final customValue = _customValueControllers[index].text.trim();
        if (customValue.isEmpty) {
          setState(() {
            _validationError =
                'Compila tutti gli slot Meta oppure seleziona un campo YouBook.';
          });
          return;
        }
        bodyBindings.add(_encodeCustomBinding(customValue));
        continue;
      }

      final assigned = _bodyBindings[index]?.trim() ?? '';
      if (assigned.isEmpty) {
        setState(() {
          _validationError =
              'Compila tutti gli slot Meta oppure seleziona un campo YouBook.';
        });
        return;
      }
      bodyBindings.add(assigned);
    }

    final headerBindings = <String>[];
    if (_hasHeaderSlot) {
      if (_headerSourceMode == _TemplateBindingSourceMode.fixedValue) {
        final fixedValue = _headerImageUrlController.text.trim();
        if (fixedValue.isNotEmpty) {
          if ((_resolvedHeaderFormat ?? '').toUpperCase() == 'IMAGE' &&
              !_isHttpsUrl(fixedValue)) {
            setState(() {
              _validationError =
                  'L\'URL header immagine deve iniziare con https://';
            });
            return;
          }
          headerBindings.add(_encodeCustomBinding(fixedValue));
        }
      } else {
        final binding = _headerBinding?.trim() ?? '';
        if (binding.isNotEmpty) {
          headerBindings.add(binding);
        }
      }
    }

    final config = WhatsAppTemplateConfig(
      schemaVersion: 3,
      allowedParams: List<String>.unmodifiable(allowedParams),
      headerFormat: _resolvedHeaderFormat,
      promotionId: _isPromotionUsage ? _selectedPromotionId?.trim() : null,
      bindings: WhatsAppTemplateBindings(
        body: List<String>.unmodifiable(bodyBindings),
        header: List<String>.unmodifiable(headerBindings),
        buttons: const <WhatsAppTemplateButtonBinding>[],
      ),
    );

    Navigator.of(context).pop(config);
  }
}

class _TemplateParameterGroup {
  const _TemplateParameterGroup({
    required this.title,
    required this.entries,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<_TemplateParameterPreview> entries;
}

class _TemplateParameterPreview {
  const _TemplateParameterPreview({
    required this.key,
    required this.value,
    required this.isRuntime,
    this.sourceHint,
  });

  final String key;
  final String value;
  final String? sourceHint;
  final bool isRuntime;
}

String? _trimToNullLocal(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _normalizePlaceholderKey(String raw) {
  return raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

bool _isRuntimeTemplateParam(String value) {
  switch (value.trim()) {
    case 'firstName':
    case 'lastName':
    case 'clientName':
    case 'salonName':
    case 'serviceName':
    case 'staffName':
    case 'dateTimeFull':
    case 'date':
    case 'time':
      return true;
    default:
      return false;
  }
}

bool _isLikelyHeaderParam(String key, String value) {
  final normalizedKey = key.trim().toLowerCase();
  if (normalizedKey.contains('image') || normalizedKey.contains('url')) {
    return true;
  }
  return _isLikelyHttpUrl(value);
}

String _resolvePreviewContextValue(Map<String, String> values, String key) {
  final trimmed = key.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return values[trimmed] ?? values[_normalizePlaceholderKey(trimmed)] ?? '';
}

Map<String, String> _buildDefaultPreviewContext(
  TemplateUsage usage, {
  String? salonName,
}) {
  final base = <String, String>{
    'firstName': 'Giulia',
    'lastName': 'Rossi',
    'clientName': 'Giulia Rossi',
    'salonName': (salonName ?? 'YouBook Studio').trim(),
  };

  switch (usage) {
    case TemplateUsage.reminder:
      base.addAll(const <String, String>{
        'serviceName': 'Piega Glow',
        'staffName': 'Marta',
        'dateTimeFull': '18 aprile alle 15:00',
        'date': '18 aprile',
        'time': '15:00',
      });
      break;
    case TemplateUsage.followUp:
      base.addAll(const <String, String>{'serviceName': 'Trattamento viso'});
      break;
    case TemplateUsage.birthday:
      base.addAll(const <String, String>{'date': '18 aprile'});
      break;
    case TemplateUsage.promotion:
      break;
  }

  final expanded = <String, String>{};
  for (final entry in base.entries) {
    expanded[entry.key] = entry.value;
    expanded[_normalizePlaceholderKey(entry.key)] = entry.value;
  }
  return expanded;
}

Map<String, String> _buildPromotionPreviewContext(
  Promotion? promotion, {
  String? salonName,
}) {
  final context = <String, String>{
    'firstName': 'Giulia',
    'clientName': 'Giulia Rossi',
    'salonName': (salonName ?? '').trim(),
  };
  if (promotion == null) {
    final expanded = <String, String>{};
    for (final entry in context.entries) {
      expanded[entry.key] = entry.value;
      expanded[_normalizePlaceholderKey(entry.key)] = entry.value;
    }
    return expanded;
  }

  final landingUrl = (promotion.ctaUrl ?? promotion.cta?.url ?? '').trim();
  final promotionImageUrl = _resolvePromotionPreviewImageUrl(promotion);
  context.addAll(<String, String>{
    'promotionTitle': promotion.title.trim(),
    'promotionSubtitle': promotion.subtitle?.trim() ?? '',
    'discountPercentage': _formatPromotionPreviewDiscount(
      promotion.discountPercentage,
    ),
    'startsAtDateTimeFull': _formatPromotionPreviewDateTime(promotion.startsAt),
    'startsAtDate': _formatPromotionPreviewDateOnly(promotion.startsAt),
    'startsAtTime': _formatPromotionPreviewTimeOnly(promotion.startsAt),
    'endsAtDateTimeFull': _formatPromotionPreviewDateTime(promotion.endsAt),
    'endsAtDate': _formatPromotionPreviewDateOnly(promotion.endsAt),
    'endsAtTime': _formatPromotionPreviewTimeOnly(promotion.endsAt),
    'startsAt': _formatPromotionPreviewDateTime(promotion.startsAt),
    'endsAt': _formatPromotionPreviewDateTime(promotion.endsAt),
    'landingUrl': landingUrl,
    'ctaLabel': (promotion.cta?.label ?? 'Scopri di piu').trim(),
    'promotionCoverImageUrl': promotionImageUrl,
    'promotionImageUrl': promotionImageUrl,
    'coverImageUrl': promotionImageUrl,
    'imageUrl': promotionImageUrl,
  });

  final aliases = <String, String>{
    'client_name': 'clientName',
    'first_name': 'firstName',
    'promotion_title': 'promotionTitle',
    'promotion_subtitle': 'promotionSubtitle',
    'discount_percentage': 'discountPercentage',
    'starts_at': 'startsAtDateTimeFull',
    'ends_at': 'endsAtDateTimeFull',
    'landing_url': 'landingUrl',
    'cta_label': 'ctaLabel',
    'promotion_cover_image_url': 'promotionCoverImageUrl',
    'promotion_image_url': 'promotionImageUrl',
    'cover_image_url': 'coverImageUrl',
    'image_url': 'imageUrl',
  };

  final expanded = <String, String>{};
  for (final entry in context.entries) {
    expanded[entry.key] = entry.value;
    expanded[_normalizePlaceholderKey(entry.key)] = entry.value;
  }
  for (final alias in aliases.entries) {
    final target = context[alias.value];
    if (target == null) {
      continue;
    }
    expanded[alias.key] = target;
    expanded[_normalizePlaceholderKey(alias.key)] = target;
  }
  return expanded;
}

String _resolvePromotionPreviewImageUrl(Promotion promotion) {
  final cover = (promotion.coverImageUrl ?? '').trim();
  if (cover.isNotEmpty) {
    return cover;
  }
  for (final section in promotion.sections) {
    final image = (section.imageUrl ?? '').trim();
    if (image.isNotEmpty) {
      return image;
    }
  }
  return '';
}

String _formatPromotionPreviewDateTime(DateTime? value) {
  if (value == null) {
    return '';
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _formatPromotionPreviewDateOnly(DateTime? value) {
  if (value == null) {
    return '';
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _formatPromotionPreviewTimeOnly(DateTime? value) {
  if (value == null) {
    return '';
  }
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _formatPromotionPreviewDiscount(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.0001) {
    return rounded.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
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
