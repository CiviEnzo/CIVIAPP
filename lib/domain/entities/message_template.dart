class MessageTemplate {
  const MessageTemplate({
    required this.id,
    required this.salonId,
    required this.title,
    required this.body,
    required this.channel,
    required this.usage,
    this.isActive = true,
  });

  final String id;
  final String salonId;
  final String title;
  final String body;
  final MessageChannel channel;
  final TemplateUsage usage;
  final bool isActive;
}

enum MessageChannel {
  whatsapp,
  email,
  sms,
}

enum TemplateUsage {
  reminder,
  followUp,
  promotion,
  birthday,
}
