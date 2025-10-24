import 'package:you_book/domain/entities/message_template.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class MessageTemplateFormSheet extends StatefulWidget {
  const MessageTemplateFormSheet({
    super.key,
    required this.salons,
    this.initial,
    this.defaultSalonId,
  });

  final List<Salon> salons;
  final MessageTemplate? initial;
  final String? defaultSalonId;

  @override
  State<MessageTemplateFormSheet> createState() =>
      _MessageTemplateFormSheetState();
}

class _MessageTemplateFormSheetState extends State<MessageTemplateFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  late TextEditingController _title;
  late TextEditingController _body;
  MessageChannel _channel = MessageChannel.whatsapp;
  TemplateUsage _usage = TemplateUsage.reminder;
  bool _active = true;
  String? _salonId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.title ?? '');
    _body = TextEditingController(text: initial?.body ?? '');
    _channel = initial?.channel ?? MessageChannel.whatsapp;
    _usage = initial?.usage ?? TemplateUsage.reminder;
    _active = initial?.isActive ?? true;
    _salonId =
        initial?.salonId ??
        widget.defaultSalonId ??
        (widget.salons.isNotEmpty ? widget.salons.first.id : null);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null
                  ? 'Nuovo template messaggio'
                  : 'Modifica template',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titolo'),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci un titolo'
                          : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MessageChannel>(
              value: _channel,
              decoration: const InputDecoration(labelText: 'Canale'),
              items:
                  MessageChannel.values
                      .map(
                        (channel) => DropdownMenuItem(
                          value: channel,
                          child: Text(_channelLabel(channel)),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(
                    () => _channel = value ?? MessageChannel.whatsapp,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TemplateUsage>(
              value: _usage,
              decoration: const InputDecoration(labelText: 'Uso'),
              items:
                  TemplateUsage.values
                      .map(
                        (usage) => DropdownMenuItem(
                          value: usage,
                          child: Text(_usageLabel(usage)),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) =>
                      setState(() => _usage = value ?? TemplateUsage.reminder),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _body,
              decoration: const InputDecoration(labelText: 'Corpo messaggio'),
              maxLines: 6,
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Inserisci il contenuto'
                          : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              title: const Text('Template attivo'),
              onChanged: (value) => setState(() => _active = value),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Salva'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_salonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nessun salone disponibile. Verifica la configurazione.',
          ),
        ),
      );
      return;
    }

    final template = MessageTemplate(
      id: widget.initial?.id ?? _uuid.v4(),
      salonId: _salonId!,
      title: _title.text.trim(),
      body: _body.text.trim(),
      channel: _channel,
      usage: _usage,
      isActive: _active,
    );

    Navigator.of(context).pop(template);
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
