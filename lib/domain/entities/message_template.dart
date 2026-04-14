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
    this.whatsappConfig,
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
  final WhatsAppTemplateConfig? whatsappConfig;

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

class WhatsAppTemplateConfig {
  const WhatsAppTemplateConfig({
    this.schemaVersion = 2,
    this.allowedParams = const <String>[],
    this.bindings,
    this.headerFormat,
    this.promotionId,
  });

  final int schemaVersion;
  final List<String> allowedParams;
  final WhatsAppTemplateBindings? bindings;
  final String? headerFormat;
  final String? promotionId;

  WhatsAppTemplateConfig copyWith({
    int? schemaVersion,
    List<String>? allowedParams,
    WhatsAppTemplateBindings? bindings,
    String? headerFormat,
    String? promotionId,
  }) {
    return WhatsAppTemplateConfig(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      allowedParams: allowedParams ?? this.allowedParams,
      bindings: bindings ?? this.bindings,
      headerFormat: headerFormat ?? this.headerFormat,
      promotionId: promotionId ?? this.promotionId,
    );
  }
}

class WhatsAppTemplateBindings {
  const WhatsAppTemplateBindings({
    this.body = const <String>[],
    this.header = const <String>[],
    this.buttons = const <WhatsAppTemplateButtonBinding>[],
  });

  final List<String> body;
  final List<String> header;
  final List<WhatsAppTemplateButtonBinding> buttons;

  WhatsAppTemplateBindings copyWith({
    List<String>? body,
    List<String>? header,
    List<WhatsAppTemplateButtonBinding>? buttons,
  }) {
    return WhatsAppTemplateBindings(
      body: body ?? this.body,
      header: header ?? this.header,
      buttons: buttons ?? this.buttons,
    );
  }
}

class WhatsAppTemplateButtonBinding {
  const WhatsAppTemplateButtonBinding({
    required this.index,
    this.type = 'url',
    this.linkTargetType = WhatsAppLinkTargetType.landing,
    this.valueSource = WhatsAppButtonValueSource.placeholder,
    this.staticValue,
    this.placeholder,
  });

  final int index;
  final String type;
  final WhatsAppLinkTargetType linkTargetType;
  final WhatsAppButtonValueSource valueSource;
  final String? staticValue;
  final String? placeholder;

  WhatsAppTemplateButtonBinding copyWith({
    int? index,
    String? type,
    WhatsAppLinkTargetType? linkTargetType,
    WhatsAppButtonValueSource? valueSource,
    String? staticValue,
    String? placeholder,
  }) {
    return WhatsAppTemplateButtonBinding(
      index: index ?? this.index,
      type: type ?? this.type,
      linkTargetType: linkTargetType ?? this.linkTargetType,
      valueSource: valueSource ?? this.valueSource,
      staticValue: staticValue ?? this.staticValue,
      placeholder: placeholder ?? this.placeholder,
    );
  }
}

enum WhatsAppLinkTargetType { landing }

enum WhatsAppButtonValueSource { staticValue, placeholder }
