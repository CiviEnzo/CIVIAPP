import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/services/whatsapp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _languageController = TextEditingController(text: 'it');
  MessageTemplate? _selectedTemplate;
  List<String> _placeholders = const [];
  List<TextEditingController> _parameterControllers = const [];
  bool _allowPreviewUrl = true;
  bool _isSending = false;

  @override
  void dispose() {
    _recipientController.dispose();
    _languageController.dispose();
    for (final controller in _parameterControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(appDataProvider);
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
              onChanged: (value) => _onTemplateChanged(value),
              validator:
                  (value) =>
                      value == null ? 'Seleziona un template approvato' : null,
            ),
            const SizedBox(height: 16),
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
            TextFormField(
              controller: _languageController,
              decoration: const InputDecoration(
                labelText: 'Lingua del template (es. it, en)',
                border: OutlineInputBorder(),
              ),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Specifica la lingua approvata del template'
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
                          child: TextFormField(
                            controller: _parameterControllers[i],
                            decoration: InputDecoration(
                              labelText: _placeholders[i],
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator:
                                (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Inserisci un valore per ${_placeholders[i]}'
                                        : null,
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
                'Disattiva per template con link dinamici che non devono mostrare l’anteprima.',
              ),
            ),
            const SizedBox(height: 16),
            _PreviewCard(
              template: _selectedTemplate,
              placeholders: _placeholders,
              controllers: _parameterControllers,
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _isSending ? null : () => _sendCampaign(context),
                icon:
                    _isSending
                        ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send_rounded),
                label: Text(
                  _isSending ? 'Invio in corso...' : 'Invia anteprima',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTemplateChanged(MessageTemplate? template) {
    setState(() {
      _selectedTemplate = template;
      _placeholders =
          template == null ? const [] : _extractPlaceholders(template.body);
      for (final controller in _parameterControllers) {
        controller.dispose();
      }
      _parameterControllers = _placeholders
          .map((_) => TextEditingController())
          .toList(growable: false);
    });
  }

  Future<void> _sendCampaign(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final template = _selectedTemplate;
    if (template == null) {
      return;
    }

    setState(() => _isSending = true);
    final scaffold = ScaffoldMessenger.of(context);

    final components =
        _placeholders.isEmpty
            ? <Map<String, dynamic>>[]
            : [
              {
                'type': 'body',
                'parameters':
                    _parameterControllers
                        .map(
                          (controller) => {
                            'type': 'text',
                            'text': controller.text.trim(),
                          },
                        )
                        .toList(),
              },
            ];

    try {
      final result = await ref
          .read(whatsappServiceProvider)
          .sendTemplate(
            salonId: widget.salonId,
            to: _recipientController.text.trim(),
            templateName: template.id,
            lang: _languageController.text.trim(),
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
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.template,
    required this.placeholders,
    required this.controllers,
  });

  final MessageTemplate? template;
  final List<String> placeholders;
  final List<TextEditingController> controllers;

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
                child: Text(
                  'ID template: ${template!.id}',
                  style: Theme.of(context).textTheme.bodySmall,
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

List<String> _extractPlaceholders(String body) {
  final regex = RegExp(r'\{\{([^}]+)\}\}');
  return regex
      .allMatches(body)
      .map((match) => match.group(1)?.trim() ?? '')
      .where((placeholder) => placeholder.isNotEmpty)
      .toList(growable: false);
}
