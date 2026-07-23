const Object _promotionSentinel = Object();

abstract final class PromotionLandingTemplates {
  static const String editorialBeauty = 'editorialBeauty';
  static const String minimalGlow = 'minimalGlow';
  static const String studioPop = 'studioPop';
  static const String botanicalRitual = 'botanicalRitual';
  static const List<String> values = <String>[
    editorialBeauty,
    minimalGlow,
    studioPop,
    botanicalRitual,
  ];

  static String normalize(String? value) {
    return values.contains(value) ? value! : editorialBeauty;
  }

  static String label(String value) {
    switch (normalize(value)) {
      case editorialBeauty:
        return 'Editorial Beauty';
      case minimalGlow:
        return 'Minimal Glow';
      case studioPop:
        return 'Studio Pop';
      case botanicalRitual:
        return 'Botanical Ritual';
      default:
        return 'Editorial Beauty';
    }
  }
}

enum PromotionCtaType { none, link, whatsapp, phone, booking, custom }

PromotionCtaType _promotionCtaTypeFromName(String? raw) {
  switch (raw) {
    case 'none':
      return PromotionCtaType.none;
    case 'link':
      return PromotionCtaType.link;
    case 'whatsapp':
      return PromotionCtaType.whatsapp;
    case 'phone':
      return PromotionCtaType.phone;
    case 'booking':
      return PromotionCtaType.booking;
    case 'custom':
      return PromotionCtaType.custom;
    default:
      return PromotionCtaType.link;
  }
}

enum PromotionStatus { draft, scheduled, published, expired }

class PromotionWebLanding {
  const PromotionWebLanding({
    this.enabled = false,
    this.slug = '',
    this.eyebrow = 'Offerta esclusiva',
    this.formTitle = 'Richiedi informazioni',
    this.formDescription =
        'Compila il modulo: il salone ti ricontatterà per fornirti tutti i dettagli.',
    this.submitLabel = 'Richiedi informazioni',
    this.interestOptions = const <String>[],
    this.offerPrice,
    this.originalPrice,
    this.fontFamily = 'playfairDmSans',
    this.templateId = PromotionLandingTemplates.editorialBeauty,
  });

  final bool enabled;
  final String slug;
  final String eyebrow;
  final String formTitle;
  final String formDescription;
  final String submitLabel;
  final List<String> interestOptions;
  final String? offerPrice;
  final String? originalPrice;
  final String fontFamily;
  final String templateId;

  PromotionWebLanding copyWith({
    bool? enabled,
    String? slug,
    String? eyebrow,
    String? formTitle,
    String? formDescription,
    String? submitLabel,
    List<String>? interestOptions,
    Object? offerPrice = _promotionSentinel,
    Object? originalPrice = _promotionSentinel,
    String? fontFamily,
    String? templateId,
  }) {
    return PromotionWebLanding(
      enabled: enabled ?? this.enabled,
      slug: slug ?? this.slug,
      eyebrow: eyebrow ?? this.eyebrow,
      formTitle: formTitle ?? this.formTitle,
      formDescription: formDescription ?? this.formDescription,
      submitLabel: submitLabel ?? this.submitLabel,
      interestOptions: interestOptions ?? this.interestOptions,
      offerPrice:
          identical(offerPrice, _promotionSentinel)
              ? this.offerPrice
              : offerPrice as String?,
      originalPrice:
          identical(originalPrice, _promotionSentinel)
              ? this.originalPrice
              : originalPrice as String?,
      fontFamily: fontFamily ?? this.fontFamily,
      templateId: templateId ?? this.templateId,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'enabled': enabled,
      'slug': slug,
      'eyebrow': eyebrow,
      'formTitle': formTitle,
      'formDescription': formDescription,
      'submitLabel': submitLabel,
      'interestOptions': interestOptions,
      if (offerPrice?.isNotEmpty == true) 'offerPrice': offerPrice,
      if (originalPrice?.isNotEmpty == true) 'originalPrice': originalPrice,
      'fontFamily': fontFamily,
      'templateId': templateId,
    };
  }

  factory PromotionWebLanding.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PromotionWebLanding();
    final options = map['interestOptions'];
    return PromotionWebLanding(
      enabled: map['enabled'] as bool? ?? false,
      slug: map['slug'] as String? ?? '',
      eyebrow: map['eyebrow'] as String? ?? 'Offerta esclusiva',
      formTitle: map['formTitle'] as String? ?? 'Richiedi informazioni',
      formDescription:
          map['formDescription'] as String? ??
          'Compila il modulo: il salone ti ricontatterà per fornirti tutti i dettagli.',
      submitLabel: map['submitLabel'] as String? ?? 'Richiedi informazioni',
      interestOptions:
          options is List
              ? options
                  .map((value) => value.toString().trim())
                  .where((value) => value.isNotEmpty)
                  .toList(growable: false)
              : const <String>[],
      offerPrice: map['offerPrice'] as String?,
      originalPrice: map['originalPrice'] as String?,
      fontFamily: map['fontFamily'] as String? ?? 'playfairDmSans',
      templateId: PromotionLandingTemplates.normalize(
        map['templateId'] as String?,
      ),
    );
  }
}

PromotionStatus promotionStatusFromName(String? raw) {
  switch (raw) {
    case 'draft':
      return PromotionStatus.draft;
    case 'scheduled':
      return PromotionStatus.scheduled;
    case 'published':
      return PromotionStatus.published;
    case 'expired':
      return PromotionStatus.expired;
    default:
      return PromotionStatus.published;
  }
}

enum PromotionSectionType { text, image }

PromotionSectionType _promotionSectionTypeFromName(String? raw) {
  switch (raw) {
    case 'image':
      return PromotionSectionType.image;
    case 'text':
    default:
      return PromotionSectionType.text;
  }
}

enum PromotionSectionLayout { full, split, quote }

PromotionSectionLayout _promotionSectionLayoutFromName(String? raw) {
  switch (raw) {
    case 'simple':
      return PromotionSectionLayout.full;
    case 'card':
      return PromotionSectionLayout.split;
    case 'split':
      return PromotionSectionLayout.split;
    case 'quote':
      return PromotionSectionLayout.quote;
    case 'full':
    default:
      return PromotionSectionLayout.full;
  }
}

class PromotionSection {
  const PromotionSection({
    required this.id,
    required this.type,
    this.order = 0,
    this.title,
    this.text,
    this.richText,
    this.imageUrl,
    this.imagePath,
    this.altText,
    this.caption,
    this.layout = PromotionSectionLayout.full,
    this.visible = true,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final PromotionSectionType type;
  final int order;
  final String? title;
  final String? text;
  final Map<String, dynamic>? richText;
  final String? imageUrl;
  final String? imagePath;
  final String? altText;
  final String? caption;
  final PromotionSectionLayout layout;
  final bool visible;
  final Map<String, dynamic> metadata;

  PromotionSection copyWith({
    String? id,
    PromotionSectionType? type,
    int? order,
    Object? title = _promotionSentinel,
    Object? text = _promotionSentinel,
    Object? richText = _promotionSentinel,
    Object? imageUrl = _promotionSentinel,
    Object? imagePath = _promotionSentinel,
    Object? altText = _promotionSentinel,
    Object? caption = _promotionSentinel,
    PromotionSectionLayout? layout,
    bool? visible,
    Map<String, dynamic>? metadata,
  }) {
    return PromotionSection(
      id: id ?? this.id,
      type: type ?? this.type,
      order: order ?? this.order,
      title:
          identical(title, _promotionSentinel) ? this.title : title as String?,
      text: identical(text, _promotionSentinel) ? this.text : text as String?,
      richText:
          identical(richText, _promotionSentinel)
              ? this.richText
              : richText as Map<String, dynamic>?,
      imageUrl:
          identical(imageUrl, _promotionSentinel)
              ? this.imageUrl
              : imageUrl as String?,
      imagePath:
          identical(imagePath, _promotionSentinel)
              ? this.imagePath
              : imagePath as String?,
      altText:
          identical(altText, _promotionSentinel)
              ? this.altText
              : altText as String?,
      caption:
          identical(caption, _promotionSentinel)
              ? this.caption
              : caption as String?,
      layout: layout ?? this.layout,
      visible: visible ?? this.visible,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'order': order,
      if (title != null && title!.isNotEmpty) 'title': title,
      if (text != null) 'text': text,
      if (richText != null && richText!.isNotEmpty) 'richText': richText,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (imagePath != null) 'imagePath': imagePath,
      if (altText != null) 'altText': altText,
      if (caption != null) 'caption': caption,
      'layout': layout.name,
      'visible': visible,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  factory PromotionSection.fromMap(Map<String, dynamic> map) {
    final metadataRaw = map['metadata'];
    final richTextRaw = map['richText'];
    return PromotionSection(
      id: map['id']?.toString() ?? '',
      type: _promotionSectionTypeFromName(map['type'] as String?),
      order: (map['order'] as num?)?.toInt() ?? 0,
      title: map['title'] as String?,
      text: map['text'] as String?,
      richText:
          richTextRaw is Map<String, dynamic>
              ? Map<String, dynamic>.from(richTextRaw)
              : null,
      imageUrl: map['imageUrl'] as String?,
      imagePath: map['imagePath'] as String?,
      altText: map['altText'] as String?,
      caption: map['caption'] as String?,
      layout: _promotionSectionLayoutFromName(map['layout'] as String?),
      visible: map['visible'] is bool ? map['visible'] as bool : true,
      metadata:
          metadataRaw is Map<String, dynamic>
              ? Map<String, dynamic>.from(metadataRaw)
              : const <String, dynamic>{},
    );
  }
}

class PromotionAnalytics {
  const PromotionAnalytics({
    this.viewCount = 0,
    this.ctaClickCount = 0,
    this.extra = const <String, dynamic>{},
  });

  final int viewCount;
  final int ctaClickCount;
  final Map<String, dynamic> extra;

  PromotionAnalytics copyWith({
    int? viewCount,
    int? ctaClickCount,
    Map<String, dynamic>? extra,
  }) {
    return PromotionAnalytics(
      viewCount: viewCount ?? this.viewCount,
      ctaClickCount: ctaClickCount ?? this.ctaClickCount,
      extra: extra ?? this.extra,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'viewCount': viewCount,
      'ctaClickCount': ctaClickCount,
      if (extra.isNotEmpty) 'extra': extra,
    };
  }

  factory PromotionAnalytics.fromMap(Map<String, dynamic> map) {
    final extraRaw = map['extra'];
    return PromotionAnalytics(
      viewCount: (map['viewCount'] as num?)?.toInt() ?? 0,
      ctaClickCount: (map['ctaClickCount'] as num?)?.toInt() ?? 0,
      extra:
          extraRaw is Map<String, dynamic>
              ? Map<String, dynamic>.from(extraRaw)
              : const <String, dynamic>{},
    );
  }
}

class PromotionCta {
  const PromotionCta({
    required this.type,
    this.label,
    this.url,
    this.phoneNumber,
    this.messageTemplate,
    this.bookingUrl,
    this.serviceId,
    this.enabled = true,
    this.metadata = const <String, dynamic>{},
    this.customData,
  });

  final PromotionCtaType type;
  final String? label;
  final String? url;
  final String? phoneNumber;
  final String? messageTemplate;
  final String? bookingUrl;
  final String? serviceId;
  final bool enabled;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic>? customData;

  PromotionCta copyWith({
    PromotionCtaType? type,
    String? label,
    Object? url = _promotionSentinel,
    Object? phoneNumber = _promotionSentinel,
    Object? messageTemplate = _promotionSentinel,
    Object? bookingUrl = _promotionSentinel,
    Object? serviceId = _promotionSentinel,
    bool? enabled,
    Map<String, dynamic>? metadata,
    Object? customData = _promotionSentinel,
  }) {
    return PromotionCta(
      type: type ?? this.type,
      label: label ?? this.label,
      url: identical(url, _promotionSentinel) ? this.url : url as String?,
      phoneNumber:
          identical(phoneNumber, _promotionSentinel)
              ? this.phoneNumber
              : phoneNumber as String?,
      messageTemplate:
          identical(messageTemplate, _promotionSentinel)
              ? this.messageTemplate
              : messageTemplate as String?,
      bookingUrl:
          identical(bookingUrl, _promotionSentinel)
              ? this.bookingUrl
              : bookingUrl as String?,
      serviceId:
          identical(serviceId, _promotionSentinel)
              ? this.serviceId
              : serviceId as String?,
      enabled: enabled ?? this.enabled,
      metadata: metadata ?? this.metadata,
      customData:
          identical(customData, _promotionSentinel)
              ? this.customData
              : customData as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    final payload = <String, dynamic>{
      if (url != null) 'url': url,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (messageTemplate != null) 'messageTemplate': messageTemplate,
      if (bookingUrl != null) 'bookingUrl': bookingUrl,
      if (serviceId != null) 'serviceId': serviceId,
      if (customData != null && customData!.isNotEmpty)
        'customData': customData,
    };
    return <String, dynamic>{
      'type': type.name,
      if (label != null) 'label': label,
      if (url != null) 'url': url,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (messageTemplate != null) 'messageTemplate': messageTemplate,
      if (bookingUrl != null) 'bookingUrl': bookingUrl,
      if (serviceId != null) 'serviceId': serviceId,
      if (payload.isNotEmpty) 'payload': payload,
      'enabled': enabled,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  factory PromotionCta.fromMap(Map<String, dynamic> map) {
    final payloadRaw = map['payload'];
    final payload =
        payloadRaw is Map<String, dynamic>
            ? Map<String, dynamic>.from(payloadRaw)
            : const <String, dynamic>{};
    Map<String, dynamic>? metadata;
    final metadataRaw = map['metadata'];
    if (metadataRaw is Map<String, dynamic>) {
      metadata = Map<String, dynamic>.from(metadataRaw);
    }
    return PromotionCta(
      type: _promotionCtaTypeFromName(map['type'] as String?),
      label: map['label'] as String?,
      url: (map['url'] ?? payload['url']) as String?,
      phoneNumber: (map['phoneNumber'] ?? payload['phoneNumber']) as String?,
      messageTemplate:
          (map['messageTemplate'] ??
                  map['message'] ??
                  payload['messageTemplate'])
              as String?,
      bookingUrl: (map['bookingUrl'] ?? payload['bookingUrl']) as String?,
      serviceId: (map['serviceId'] ?? payload['serviceId']) as String?,
      enabled:
          map['enabled'] is bool
              ? map['enabled'] as bool
              : payload['enabled'] as bool? ?? true,
      metadata: metadata ?? const <String, dynamic>{},
      customData:
          payload['customData'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                payload['customData'] as Map<String, dynamic>,
              )
              : null,
    );
  }
}

class Promotion {
  Promotion({
    required this.id,
    required this.salonId,
    required this.title,
    this.subtitle,
    this.tagline,
    this.themeColor,
    String? coverImageUrl,
    String? coverImagePath,
    String? imageUrl,
    String? imageStoragePath,
    this.cta,
    this.ctaUrl,
    List<PromotionSection> sections = const <PromotionSection>[],
    this.startsAt,
    this.endsAt,
    this.discountPercentage = 0,
    this.priority = 0,
    this.status = PromotionStatus.draft,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.analytics,
    this.webLanding = const PromotionWebLanding(),
  }) : coverImageUrl = coverImageUrl ?? imageUrl,
       coverImagePath = coverImagePath ?? imageStoragePath,
       sections = List.unmodifiable(sections);

  final String id;
  final String salonId;
  final String title;
  final String? subtitle;
  final String? tagline;
  final String? coverImageUrl;
  final String? coverImagePath;
  final int? themeColor;
  final PromotionCta? cta;
  final String? ctaUrl;
  final List<PromotionSection> sections;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final double discountPercentage;
  final int priority;
  final PromotionStatus status;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final PromotionAnalytics? analytics;
  final PromotionWebLanding webLanding;

  @Deprecated('Use coverImageUrl instead')
  String? get imageUrl => coverImageUrl;

  @Deprecated('Use coverImagePath instead')
  String? get imageStoragePath => coverImagePath;

  Promotion copyWith({
    String? id,
    String? salonId,
    String? title,
    String? subtitle,
    String? tagline,
    Object? coverImageUrl = _promotionSentinel,
    Object? coverImagePath = _promotionSentinel,
    Object? imageUrl = _promotionSentinel,
    Object? imageStoragePath = _promotionSentinel,
    Object? themeColor = _promotionSentinel,
    Object? cta = _promotionSentinel,
    Object? ctaUrl = _promotionSentinel,
    List<PromotionSection>? sections,
    DateTime? startsAt,
    DateTime? endsAt,
    double? discountPercentage,
    int? priority,
    PromotionStatus? status,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? createdBy = _promotionSentinel,
    Object? updatedBy = _promotionSentinel,
    Object? analytics = _promotionSentinel,
    PromotionWebLanding? webLanding,
  }) {
    return Promotion(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      tagline: tagline ?? this.tagline,
      coverImageUrl:
          identical(coverImageUrl, _promotionSentinel)
              ? (identical(imageUrl, _promotionSentinel)
                  ? this.coverImageUrl
                  : imageUrl as String?)
              : coverImageUrl as String?,
      coverImagePath:
          identical(coverImagePath, _promotionSentinel)
              ? (identical(imageStoragePath, _promotionSentinel)
                  ? this.coverImagePath
                  : imageStoragePath as String?)
              : coverImagePath as String?,
      themeColor:
          identical(themeColor, _promotionSentinel)
              ? this.themeColor
              : themeColor as int?,
      cta: identical(cta, _promotionSentinel) ? this.cta : cta as PromotionCta?,
      ctaUrl:
          identical(ctaUrl, _promotionSentinel)
              ? this.ctaUrl
              : ctaUrl as String?,
      sections: sections != null ? List.unmodifiable(sections) : this.sections,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy:
          identical(createdBy, _promotionSentinel)
              ? this.createdBy
              : createdBy as String?,
      updatedBy:
          identical(updatedBy, _promotionSentinel)
              ? this.updatedBy
              : updatedBy as String?,
      analytics:
          identical(analytics, _promotionSentinel)
              ? this.analytics
              : analytics as PromotionAnalytics?,
      webLanding: webLanding ?? this.webLanding,
    );
  }

  bool get isPublished => status == PromotionStatus.published;

  bool isLiveAt(DateTime moment) {
    if (!isActive || status == PromotionStatus.expired) {
      return false;
    }
    if (status == PromotionStatus.draft) {
      return false;
    }
    final start = startsAt;
    final end = endsAt;
    if (start != null && moment.isBefore(start)) {
      return false;
    }
    if (end != null && moment.isAfter(end)) {
      return false;
    }
    return true;
  }
}
