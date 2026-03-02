import 'package:collection/collection.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class WhatsAppCampaignEditorPage extends ConsumerStatefulWidget {
  const WhatsAppCampaignEditorPage({super.key, required this.salonId});

  final String salonId;

  @override
  ConsumerState<WhatsAppCampaignEditorPage> createState() =>
      _WhatsAppCampaignEditorPageState();
}

class _WhatsAppCampaignEditorPageState
    extends ConsumerState<WhatsAppCampaignEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final Set<String> _selectedClientIds = <String>{};
  final DateFormat _promotionDateTimeFullFormat = DateFormat(
    "d MMMM 'alle' HH:mm",
    'it_IT',
  );
  final DateFormat _promotionDateOnlyFormat = DateFormat('d MMMM', 'it_IT');
  final DateFormat _promotionTimeOnlyFormat = DateFormat('HH:mm');
  MessageTemplate? _selectedTemplate;
  String? _selectedPromotionId;
  List<String> _placeholders = const [];
  List<String> _headerBindings = const [];
  List<TextEditingController> _parameterControllers = const [];
  bool _allowPreviewUrl = true;
  bool _isSending = false;

  bool get _isPromotionTemplateSelected =>
      _selectedTemplate?.usage == TemplateUsage.promotion;

  @override
  void dispose() {
    _recipientController.dispose();
    for (final controller in _parameterControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
    final salonClients =
        data.clients
            .where((client) => client.salonId == widget.salonId)
            .toList()
          ..sort(
            (a, b) =>
                a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          );
    final promotionEligibleRecipients = salonClients
        .where((client) => client.phone.trim().isNotEmpty)
        .toList(growable: false);
    final selectedPromotionRecipients = promotionEligibleRecipients
        .where((client) => _selectedClientIds.contains(client.id))
        .toList(growable: false);
    final previewRecipient = _resolvePreviewClient(promotionEligibleRecipients);
    final clientsWithoutPhoneCount =
        salonClients.length - promotionEligibleRecipients.length;
    final templates =
        data.messageTemplates
            .where(
              (template) =>
                  template.salonId == widget.salonId &&
                  template.channel == MessageChannel.whatsapp &&
                  template.isActive,
            )
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    final promotions =
        data.promotions
            .where((promotion) => promotion.salonId == widget.salonId)
            .toList()
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
    final salonName =
        data.salons
            .firstWhereOrNull((salon) => salon.id == widget.salonId)
            ?.name;

    if (_selectedTemplate != null &&
        templates.every((template) => template.id != _selectedTemplate!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _onTemplateChanged(
          templates.firstOrNull,
          promotions: promotions,
          promotionEligibleRecipients: promotionEligibleRecipients,
          salonName: salonName,
        );
      });
    }

    if (_selectedTemplate == null && templates.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedTemplate != null) {
          return;
        }
        _onTemplateChanged(
          templates.first,
          promotions: promotions,
          promotionEligibleRecipients: promotionEligibleRecipients,
          salonName: salonName,
        );
      });
    }

    if (_isPromotionTemplateSelected &&
        promotions.isNotEmpty &&
        promotions.every((promotion) => promotion.id != _selectedPromotionId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || promotions.isEmpty) {
          return;
        }
        _onPromotionChanged(
          promotions.first.id,
          promotions: promotions,
          promotionEligibleRecipients: promotionEligibleRecipients,
          salonName: salonName,
        );
      });
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invia campagna WhatsApp',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MessageTemplate>(
              isExpanded: true,
              value: _selectedTemplate,
              decoration: const InputDecoration(
                labelText: 'Template approvato',
                border: OutlineInputBorder(),
              ),
              items:
                  templates
                      .map(
                        (template) => DropdownMenuItem(
                          value: template,
                          child: Text(template.title),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) => _onTemplateChanged(
                    value,
                    promotions: promotions,
                    promotionEligibleRecipients: promotionEligibleRecipients,
                    salonName: salonName,
                  ),
              validator:
                  (value) =>
                      value == null ? 'Seleziona un template approvato' : null,
            ),
            if (_isPromotionTemplateSelected) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value:
                    promotions.any(
                          (promotion) => promotion.id == _selectedPromotionId,
                        )
                        ? _selectedPromotionId
                        : null,
                decoration: const InputDecoration(
                  labelText: 'Promozione (modulo Messaggi & marketing)',
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
                onChanged:
                    promotions.isEmpty
                        ? null
                        : (value) => _onPromotionChanged(
                          value,
                          promotions: promotions,
                          promotionEligibleRecipients:
                              promotionEligibleRecipients,
                          salonName: salonName,
                        ),
                validator: (value) {
                  if (!_isPromotionTemplateSelected) {
                    return null;
                  }
                  if (promotions.isEmpty) {
                    return 'Nessuna promozione disponibile nel tab Promozioni.';
                  }
                  return value == null ? 'Seleziona una promozione.' : null;
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Destinatari promozione',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${selectedPromotionRecipients.length}/${promotionEligibleRecipients.length} selezionati',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (clientsWithoutPhoneCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$clientsWithoutPhoneCount clienti esclusi: telefono non disponibile.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                promotionEligibleRecipients.isEmpty ||
                                        _isSending
                                    ? null
                                    : () => _showPromotionRecipientSelector(
                                      promotionEligibleRecipients,
                                      promotions: promotions,
                                      salonName: salonName,
                                    ),
                            icon: const Icon(Icons.group_add_rounded),
                            label: const Text('Seleziona destinatari'),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                _selectedClientIds.isEmpty || _isSending
                                    ? null
                                    : () {
                                      setState(() {
                                        _selectedClientIds.clear();
                                      });
                                      _prefillPromotionValues(
                                        promotions: promotions,
                                        promotionEligibleRecipients:
                                            promotionEligibleRecipients,
                                        salonName: salonName,
                                      );
                                    },
                            icon: const Icon(Icons.clear_all_rounded),
                            label: const Text('Svuota'),
                          ),
                        ],
                      ),
                      if (selectedPromotionRecipients.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedPromotionRecipients
                              .take(8)
                              .map(
                                (client) => InputChip(
                                  label: Text(client.fullName),
                                  onDeleted:
                                      _isSending
                                          ? null
                                          : () {
                                            setState(() {
                                              _selectedClientIds.remove(
                                                client.id,
                                              );
                                            });
                                            _prefillPromotionValues(
                                              promotions: promotions,
                                              promotionEligibleRecipients:
                                                  promotionEligibleRecipients,
                                              salonName: salonName,
                                            );
                                          },
                                ),
                              )
                              .toList(growable: false),
                        ),
                        if (selectedPromotionRecipients.length > 8)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '+${selectedPromotionRecipients.length - 8} altri destinatari',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (!_isPromotionTemplateSelected)
              TextFormField(
                controller: _recipientController,
                decoration: const InputDecoration(
                  labelText: 'Numero destinatario (E.164)',
                  hintText: '+393331234567',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Inserisci il numero del destinatario'
                            : null,
              ),
            const SizedBox(height: 16),
            if (_placeholders.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parametri del template',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < _placeholders.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Builder(
                            builder: (context) {
                              final placeholder = _placeholders[i];
                              final customValue = _decodeCustomBindingValue(
                                placeholder,
                              );
                              final isCustom = customValue != null;
                              return TextFormField(
                                controller: _parameterControllers[i],
                                readOnly:
                                    _isPromotionTemplateSelected || isCustom,
                                decoration: InputDecoration(
                                  labelText:
                                      isCustom
                                          ? 'Custom ${i + 1}'
                                          : placeholder,
                                  border: const OutlineInputBorder(),
                                  helperText:
                                      isCustom
                                          ? 'Valore custom fisso impostato nel configuratore'
                                          : _isPromotionTemplateSelected
                                          ? 'Valore letto dal tab Promozioni'
                                          : null,
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (value) {
                                  if (_isPromotionTemplateSelected ||
                                      isCustom) {
                                    return null;
                                  }
                                  return value == null || value.trim().isEmpty
                                      ? 'Inserisci un valore per $placeholder'
                                      : null;
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _allowPreviewUrl,
              onChanged: (value) => setState(() => _allowPreviewUrl = value),
              title: const Text('Consenti anteprima link'),
              subtitle: const Text(
                'Disattiva per template con link dinamici che non devono mostrare l\'anteprima.',
              ),
            ),
            const SizedBox(height: 16),
            _PreviewCard(
              template: _selectedTemplate,
              placeholders: _placeholders,
              controllers: _parameterControllers,
              previewRecipientName:
                  _isPromotionTemplateSelected
                      ? previewRecipient?.fullName
                      : null,
              showPromotionRecipientHint:
                  _isPromotionTemplateSelected && previewRecipient == null,
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed:
                    _isSending
                        ? null
                        : () => _sendCampaign(
                          context,
                          promotions: promotions,
                          promotionEligibleRecipients:
                              promotionEligibleRecipients,
                          salonName: salonName,
                        ),
                icon:
                    _isSending
                        ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send_rounded),
                label: Text(
                  _isSending
                      ? 'Invio in corso...'
                      : _isPromotionTemplateSelected
                      ? 'Invia promozione ai selezionati'
                      : 'Invia anteprima',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTemplateChanged(
    MessageTemplate? template, {
    required List<Promotion> promotions,
    required List<Client> promotionEligibleRecipients,
    String? salonName,
  }) {
    setState(() {
      _selectedTemplate = template;
      _placeholders =
          template == null
              ? const []
              : _resolveBodyPlaceholdersForTemplate(template);
      _headerBindings =
          template == null
              ? const []
              : _resolveHeaderBindingsForTemplate(template);
      for (final controller in _parameterControllers) {
        controller.dispose();
      }
      _parameterControllers = _placeholders
          .map((_) => TextEditingController())
          .toList(growable: false);
      for (var i = 0; i < _placeholders.length; i++) {
        final customValue = _decodeCustomBindingValue(_placeholders[i]);
        if (customValue != null) {
          _parameterControllers[i].text = customValue;
        }
      }

      if (template?.usage != TemplateUsage.promotion) {
        _selectedPromotionId = null;
      } else if (promotions.isNotEmpty) {
        final selectedStillValid = promotions.any(
          (promotion) => promotion.id == _selectedPromotionId,
        );
        _selectedPromotionId =
            selectedStillValid ? _selectedPromotionId : promotions.first.id;
      } else {
        _selectedPromotionId = null;
      }
    });

    if (template?.usage == TemplateUsage.promotion) {
      _prefillPromotionValues(
        promotions: promotions,
        promotionEligibleRecipients: promotionEligibleRecipients,
        salonName: salonName,
      );
    }
  }

  void _onPromotionChanged(
    String? promotionId, {
    required List<Promotion> promotions,
    required List<Client> promotionEligibleRecipients,
    String? salonName,
  }) {
    setState(() {
      _selectedPromotionId = promotionId;
    });
    _prefillPromotionValues(
      promotions: promotions,
      promotionEligibleRecipients: promotionEligibleRecipients,
      salonName: salonName,
    );
  }

  void _prefillPromotionValues({
    required List<Promotion> promotions,
    required List<Client> promotionEligibleRecipients,
    String? salonName,
  }) {
    if (!_isPromotionTemplateSelected ||
        _selectedPromotionId == null ||
        _parameterControllers.isEmpty) {
      return;
    }
    final promotion = promotions.firstWhereOrNull(
      (entry) => entry.id == _selectedPromotionId,
    );
    if (promotion == null) {
      return;
    }

    final previewClient = _resolvePreviewClient(promotionEligibleRecipients);
    final context = _buildPromotionContext(
      promotion,
      salonName: salonName,
      client: previewClient,
    );
    for (var i = 0; i < _placeholders.length; i++) {
      final customValue = _decodeCustomBindingValue(_placeholders[i]);
      if (customValue != null) {
        _parameterControllers[i].text = customValue;
        continue;
      }
      _parameterControllers[i].text = _resolveContextValue(
        key: _placeholders[i],
        fromPrimary: const <String, String>{},
        fromSecondary: context,
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendCampaign(
    BuildContext context, {
    required List<Promotion> promotions,
    required List<Client> promotionEligibleRecipients,
    String? salonName,
  }) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final template = _selectedTemplate;
    if (template == null) {
      return;
    }
    if (_isPromotionTemplateSelected && _selectedPromotionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seleziona una promozione da usare come sorgente dati.',
          ),
        ),
      );
      return;
    }
    if (_isPromotionTemplateSelected &&
        !promotionEligibleRecipients.any(
          (client) => _selectedClientIds.contains(client.id),
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona almeno un destinatario per la promozione.'),
        ),
      );
      return;
    }

    final metaTemplateName = template.resolvedMetaTemplateName;
    if (metaTemplateName == null || metaTemplateName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Template WhatsApp senza nome Meta configurato. Modifica il template locale e imposta il mapping.',
          ),
        ),
      );
      return;
    }
    final templateLanguage = template.resolvedMetaTemplateLanguage ?? 'it';

    setState(() => _isSending = true);
    final scaffold = ScaffoldMessenger.of(context);
    final fromPrimary = _buildCurrentPlaceholderValues();

    try {
      if (_isPromotionTemplateSelected) {
        final selectedRecipients = promotionEligibleRecipients
            .where((client) => _selectedClientIds.contains(client.id))
            .toList(growable: false);
        final promotion = promotions.firstWhereOrNull(
          (entry) => entry.id == _selectedPromotionId,
        );
        if (promotion == null) {
          scaffold.showSnackBar(
            const SnackBar(
              content: Text(
                'Promozione non trovata. Seleziona nuovamente la promozione.',
              ),
            ),
          );
          return;
        }

        var successCount = 0;
        var failureCount = 0;
        var skippedCount = 0;
        for (final recipient in selectedRecipients) {
          final to = _normalizeWhatsappRecipient(recipient.phone);
          if (to.isEmpty) {
            skippedCount += 1;
            continue;
          }
          final personalizedContext = _buildPromotionContext(
            promotion,
            salonName: salonName,
            client: recipient,
          );
          final components = _buildTemplateComponents(
            fromPrimary: const <String, String>{},
            fromSecondary: personalizedContext,
          );
          if (_requiresImageHeader && !_containsHeaderComponent(components)) {
            failureCount += 1;
            continue;
          }

          try {
            final result = await ref
                .read(whatsappServiceProvider)
                .sendTemplate(
                  salonId: widget.salonId,
                  to: to,
                  templateName: metaTemplateName,
                  lang: templateLanguage,
                  components: components,
                  allowPreviewUrl: _allowPreviewUrl,
                );
            if (result.success) {
              successCount += 1;
            } else {
              failureCount += 1;
            }
          } on Exception {
            failureCount += 1;
          }
        }

        scaffold.showSnackBar(
          SnackBar(
            content: Text(
              'Invio completato: $successCount ok, $failureCount errori, $skippedCount saltati.',
            ),
          ),
        );
      } else {
        final components = _buildTemplateComponents(
          fromPrimary: fromPrimary,
          fromSecondary: const <String, String>{},
        );
        if (_requiresImageHeader && !_containsHeaderComponent(components)) {
          scaffold.showSnackBar(
            const SnackBar(
              content: Text(
                'Header immagine richiesto ma non configurato. Apri il configuratore template e imposta l\'immagine.',
              ),
            ),
          );
          return;
        }
        final result = await ref
            .read(whatsappServiceProvider)
            .sendTemplate(
              salonId: widget.salonId,
              to: _normalizeWhatsappRecipient(_recipientController.text.trim()),
              templateName: metaTemplateName,
              lang: templateLanguage,
              components: components,
              allowPreviewUrl: _allowPreviewUrl,
            );

        scaffold.showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Template inviato! messageId=${result.messageId ?? 'n/d'}'
                  : 'Invio completato con warning',
            ),
          ),
        );
      }
    } on Exception catch (error) {
      scaffold.showSnackBar(
        SnackBar(content: Text('Errore durante l\'invio: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Map<String, String> _buildPromotionContext(
    Promotion promotion, {
    String? salonName,
    Client? client,
  }) {
    final landingUrl = (promotion.ctaUrl ?? promotion.cta?.url ?? '').trim();
    final promotionImageUrl = _resolvePromotionImageUrl(promotion);
    final startsAtDateTimeFull = _formatPromotionDateTimeFull(
      promotion.startsAt,
    );
    final startsAtDate = _formatPromotionDateOnly(promotion.startsAt);
    final startsAtTime = _formatPromotionTimeOnly(promotion.startsAt);
    final endsAtDateTimeFull = _formatPromotionDateTimeFull(promotion.endsAt);
    final endsAtDate = _formatPromotionDateOnly(promotion.endsAt);
    final endsAtTime = _formatPromotionTimeOnly(promotion.endsAt);

    final context = <String, String>{
      'firstName':
          client?.firstName.trim().isNotEmpty == true
              ? client!.firstName.trim()
              : 'Cliente',
      'clientName':
          client?.fullName.trim().isNotEmpty == true
              ? client!.fullName.trim()
              : 'Cliente',
      'promotionTitle': promotion.title.trim(),
      'promotionSubtitle': promotion.subtitle?.trim() ?? '',
      'discountPercentage': _formatDiscount(promotion.discountPercentage),
      'startsAtDateTimeFull': startsAtDateTimeFull,
      'startsAtDate': startsAtDate,
      'startsAtTime': startsAtTime,
      'endsAtDateTimeFull': endsAtDateTimeFull,
      'endsAtDate': endsAtDate,
      'endsAtTime': endsAtTime,
      'startsAt': startsAtDateTimeFull, // legacy
      'endsAt': endsAtDateTimeFull, // legacy
      'salonName': (salonName ?? '').trim(),
      'landingUrl': landingUrl,
      'ctaLabel': (promotion.cta?.label ?? 'Scopri di piu').trim(),
      'promotionCoverImageUrl': promotionImageUrl,
      'promotionImageUrl': promotionImageUrl,
      'coverImageUrl': promotionImageUrl,
      'imageUrl': promotionImageUrl,
    };

    final aliases = <String, String>{
      'client_name': 'clientName',
      'first_name': 'firstName',
      'firstname': 'firstName',
      'promotion_title': 'promotionTitle',
      'promo_title': 'promotionTitle',
      'promotion_subtitle': 'promotionSubtitle',
      'promo_subtitle': 'promotionSubtitle',
      'discount': 'discountPercentage',
      'discount_percentage': 'discountPercentage',
      'starts_at': 'startsAtDateTimeFull',
      'starts_at_full': 'startsAtDateTimeFull',
      'starts_at_datetime': 'startsAtDateTimeFull',
      'starts_at_datetime_full': 'startsAtDateTimeFull',
      'start_date': 'startsAtDate',
      'start_time': 'startsAtTime',
      'ends_at': 'endsAtDateTimeFull',
      'ends_at_full': 'endsAtDateTimeFull',
      'ends_at_datetime': 'endsAtDateTimeFull',
      'ends_at_datetime_full': 'endsAtDateTimeFull',
      'expiry_date': 'endsAtDate',
      'end_date': 'endsAtDate',
      'end_time': 'endsAtTime',
      'salon_name': 'salonName',
      'booking_link': 'landingUrl',
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
      final targetValue = context[alias.value];
      if (targetValue == null) {
        continue;
      }
      expanded[alias.key] = targetValue;
      expanded[_normalizePlaceholderKey(alias.key)] = targetValue;
    }

    return expanded;
  }

  Client? _resolvePreviewClient(List<Client> promotionEligibleRecipients) {
    return promotionEligibleRecipients.firstWhereOrNull(
      (client) => _selectedClientIds.contains(client.id),
    );
  }

  String _formatPromotionDateTimeFull(DateTime? value) {
    if (value == null) {
      return '';
    }
    return _promotionDateTimeFullFormat.format(value);
  }

  String _formatPromotionDateOnly(DateTime? value) {
    if (value == null) {
      return '';
    }
    return _promotionDateOnlyFormat.format(value);
  }

  String _formatPromotionTimeOnly(DateTime? value) {
    if (value == null) {
      return '';
    }
    return _promotionTimeOnlyFormat.format(value);
  }

  String _formatDiscount(double value) {
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 0.0001) {
      return rounded.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _resolvePromotionImageUrl(Promotion promotion) {
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

  String _resolveContextValue({
    required String key,
    required Map<String, String> fromPrimary,
    required Map<String, String> fromSecondary,
  }) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final customValue = _decodeCustomBindingValue(trimmed);
    if (customValue != null) {
      return customValue;
    }
    final normalized = _normalizePlaceholderKey(trimmed);
    return fromPrimary[trimmed] ??
        fromPrimary[normalized] ??
        fromSecondary[trimmed] ??
        fromSecondary[normalized] ??
        '';
  }

  Map<String, String> _buildCurrentPlaceholderValues() {
    final values = <String, String>{};
    for (var i = 0; i < _placeholders.length; i++) {
      final key = _placeholders[i].trim();
      final value = _parameterControllers[i].text.trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      values[key] = value;
      values[_normalizePlaceholderKey(key)] = value;
    }
    return values;
  }

  List<Map<String, dynamic>> _buildTemplateComponents({
    required Map<String, String> fromPrimary,
    required Map<String, String> fromSecondary,
  }) {
    final components = <Map<String, dynamic>>[];
    final headerComponent = _buildHeaderComponent(
      fromPrimary: fromPrimary,
      fromSecondary: fromSecondary,
    );
    if (headerComponent != null) {
      components.add(headerComponent);
    }
    if (_placeholders.isNotEmpty) {
      components.add({
        'type': 'body',
        'parameters': _placeholders
            .map(
              (placeholder) => <String, String>{
                'type': 'text',
                'text': _resolveContextValue(
                  key: placeholder,
                  fromPrimary: fromPrimary,
                  fromSecondary: fromSecondary,
                ),
              },
            )
            .toList(growable: false),
      });
    }
    return components;
  }

  Map<String, dynamic>? _buildHeaderComponent({
    required Map<String, String> fromPrimary,
    required Map<String, String> fromSecondary,
  }) {
    if (_headerBindings.isEmpty) {
      return null;
    }
    final format =
        _selectedTemplate?.whatsappConfig?.headerFormat?.trim().toUpperCase() ??
        '';
    final rawBinding = _headerBindings.first.trim();
    if (rawBinding.isEmpty) {
      return null;
    }
    final resolved = _resolveContextValue(
      key: rawBinding,
      fromPrimary: fromPrimary,
      fromSecondary: fromSecondary,
    );
    if (resolved.isEmpty) {
      return null;
    }
    if (format == 'IMAGE') {
      if (!_isLikelyHttpUrl(resolved)) {
        return null;
      }
      return {
        'type': 'header',
        'parameters': [
          {
            'type': 'image',
            'image': {'link': resolved},
          },
        ],
      };
    }
    return {
      'type': 'header',
      'parameters': [
        {'type': 'text', 'text': resolved},
      ],
    };
  }

  bool get _requiresImageHeader {
    final format =
        _selectedTemplate?.whatsappConfig?.headerFormat?.trim().toUpperCase() ??
        '';
    return format == 'IMAGE';
  }

  bool _containsHeaderComponent(List<Map<String, dynamic>> components) {
    for (final component in components) {
      final type = (component['type'] as String?)?.trim().toLowerCase();
      if (type == 'header') {
        return true;
      }
    }
    return false;
  }

  String _normalizeWhatsappRecipient(String raw) {
    var value = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (value.startsWith('00')) {
      value = '+${value.substring(2)}';
    }
    if (value.startsWith('+')) {
      final digits = value.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
      return digits.isEmpty ? '' : '+$digits';
    }
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _showPromotionRecipientSelector(
    List<Client> clients, {
    required List<Promotion> promotions,
    String? salonName,
  }) async {
    if (!mounted) {
      return;
    }
    final initialSelected = _selectedClientIds.where(
      clients.map((client) => client.id).toSet().contains,
    );
    final selected = Set<String>.from(initialSelected);
    final queryController = TextEditingController();

    Set<String>? result;
    try {
      result = await showDialog<Set<String>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final query = queryController.text.trim().toLowerCase();
              final filtered =
                  query.isEmpty
                      ? clients
                      : clients
                          .where((client) {
                            final fullName = client.fullName.toLowerCase();
                            final phone = client.phone.toLowerCase();
                            final email = (client.email ?? '').toLowerCase();
                            return fullName.contains(query) ||
                                phone.contains(query) ||
                                email.contains(query);
                          })
                          .toList(growable: false);

              final filteredIds = filtered.map((client) => client.id).toSet();
              final selectedInFilter =
                  selected.where(filteredIds.contains).length;
              final allFilteredSelected =
                  filtered.isNotEmpty && selectedInFilter == filtered.length;

              return AlertDialog(
                title: Text('Seleziona destinatari (${selected.length})'),
                content: SizedBox(
                  width: 560,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: queryController,
                        decoration: const InputDecoration(
                          labelText: 'Cerca cliente',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                            onPressed:
                                filtered.isEmpty
                                    ? null
                                    : () {
                                      setDialogState(() {
                                        if (allFilteredSelected) {
                                          selected.removeAll(filteredIds);
                                        } else {
                                          selected.addAll(filteredIds);
                                        }
                                      });
                                    },
                            child: Text(
                              allFilteredSelected
                                  ? 'Deseleziona filtrati'
                                  : 'Seleziona filtrati',
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed:
                                selected.isEmpty
                                    ? null
                                    : () {
                                      setDialogState(() {
                                        selected.clear();
                                      });
                                    },
                            child: const Text('Azzera'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final client = filtered[index];
                            final isSelected = selected.contains(client.id);
                            return CheckboxListTile(
                              value: isSelected,
                              dense: true,
                              title: Text(client.fullName),
                              subtitle: Text(client.phone),
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selected.add(client.id);
                                  } else {
                                    selected.remove(client.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
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
                      Navigator.of(
                        dialogContext,
                      ).pop(Set<String>.from(selected));
                    },
                    child: const Text('Conferma'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      queryController.dispose();
    }

    if (result == null) {
      return;
    }
    setState(() {
      _selectedClientIds
        ..clear()
        ..addAll(result!);
    });
    _prefillPromotionValues(
      promotions: promotions,
      promotionEligibleRecipients: clients,
      salonName: salonName,
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.template,
    required this.placeholders,
    required this.controllers,
    required this.previewRecipientName,
    required this.showPromotionRecipientHint,
  });

  final MessageTemplate? template;
  final List<String> placeholders;
  final List<TextEditingController> controllers;
  final String? previewRecipientName;
  final bool showPromotionRecipientHint;

  @override
  Widget build(BuildContext context) {
    final previewText = _buildPreview();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anteprima messaggio',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (previewRecipientName != null) ...[
              const SizedBox(height: 6),
              Text(
                'Anteprima cliente: $previewRecipientName',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (showPromotionRecipientHint) ...[
              const SizedBox(height: 6),
              Text(
                'Seleziona almeno un destinatario per personalizzare clientName.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if ((template?.whatsappConfig?.headerFormat ?? '')
                    .trim()
                    .toUpperCase() ==
                'IMAGE') ...[
              const SizedBox(height: 6),
              Text(
                'Template con header immagine: verifica che la configurazione template abbia un URL immagine valido.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceVariant,
              ),
              child: Text(
                previewText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (template != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nome template Meta: ${template!.resolvedMetaTemplateName ?? 'NON CONFIGURATO'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'ID locale: ${template!.id}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _buildPreview() {
    final base =
        template?.body ??
        'Seleziona un template approvato per visualizzare l\'anteprima.';
    var preview = base;
    for (var i = 0; i < placeholders.length; i++) {
      final value = controllers[i].text.trim();
      preview = preview.replaceAll(
        '{{${placeholders[i]}}}',
        value.isEmpty ? placeholders[i] : value,
      );
    }
    return preview;
  }
}

List<String> _resolveBodyPlaceholdersForTemplate(MessageTemplate template) {
  final configured = template.whatsappConfig?.bindings?.body
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }
  return _extractPlaceholders(template.body);
}

List<String> _resolveHeaderBindingsForTemplate(MessageTemplate template) {
  final configured = template.whatsappConfig?.bindings?.header
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }
  return const <String>[];
}

List<String> _extractPlaceholders(String body) {
  final regex = RegExp(r'\{\{([^}]+)\}\}');
  return regex
      .allMatches(body)
      .map((match) => match.group(1)?.trim() ?? '')
      .where((placeholder) => placeholder.isNotEmpty)
      .toList(growable: false);
}

String _normalizePlaceholderKey(String raw) {
  return raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}

bool _isLikelyHttpUrl(String raw) {
  final normalized = raw.trim().toLowerCase();
  return normalized.startsWith('http://') || normalized.startsWith('https://');
}

const String _customBindingPrefix = 'custom:';

String? _decodeCustomBindingValue(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (!trimmed.toLowerCase().startsWith(_customBindingPrefix)) {
    return null;
  }
  return trimmed.substring(_customBindingPrefix.length);
}
