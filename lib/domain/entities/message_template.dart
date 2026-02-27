class MessageTemplate {
  const MessageTemplate({
    required this.id,
    required this.salonId,
    required this.title,
    required this.body,
    required this.channel,
    required this.usage,
    this.isActive = true,
    this.metaTemplateName,
    this.metaTemplateLanguage,
  });

  final String id;
  final String salonId;
  final String title;
  final String body;
  final MessageChannel channel;
  final TemplateUsage usage;
  final bool isActive;
  final String? metaTemplateName;
  final String? metaTemplateLanguage;

  String? get resolvedMetaTemplateName {
    final explicit = metaTemplateName?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    if (channel == MessageChannel.whatsapp) {
      final legacy = id.trim();
      return legacy.isEmpty ? null : legacy;
    }
    return null;
  }

  String? get resolvedMetaTemplateLanguage {
    final explicit = metaTemplateLanguage?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    if (channel == MessageChannel.whatsapp) {
      return 'it';
    }
    return null;
  }
}

enum MessageChannel { push, whatsapp, email, sms }

enum TemplateUsage { reminder, followUp, promotion, birthday }
