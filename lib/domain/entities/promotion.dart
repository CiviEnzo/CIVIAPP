class Promotion {
  const Promotion({
    required this.id,
    required this.salonId,
    required this.title,
    this.subtitle,
    this.tagline,
    this.imageUrl,
    this.ctaUrl,
    this.startsAt,
    this.endsAt,
    this.discountPercentage = 0,
    this.priority = 0,
    this.isActive = true,
  });

  final String id;
  final String salonId;
  final String title;
  final String? subtitle;
  final String? tagline;
  final String? imageUrl;
  final String? ctaUrl;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final double discountPercentage;
  final int priority;
  final bool isActive;

  Promotion copyWith({
    String? id,
    String? salonId,
    String? title,
    String? subtitle,
    String? tagline,
    String? imageUrl,
    String? ctaUrl,
    DateTime? startsAt,
    DateTime? endsAt,
    double? discountPercentage,
    int? priority,
    bool? isActive,
  }) {
    return Promotion(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      tagline: tagline ?? this.tagline,
      imageUrl: imageUrl ?? this.imageUrl,
      ctaUrl: ctaUrl ?? this.ctaUrl,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
    );
  }

  bool isLiveAt(DateTime moment) {
    if (!isActive) {
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
