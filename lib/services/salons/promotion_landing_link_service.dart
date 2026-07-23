class PromotionLandingLinkService {
  const PromotionLandingLinkService._();

  static const productionOrigin = 'https://youbook.civiapp.it';

  static String slugify(String value, {String fallback = 'promozione'}) {
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'è': 'e',
      'é': 'e',
      'ì': 'i',
      'í': 'i',
      'ò': 'o',
      'ó': 'o',
      'ù': 'u',
      'ú': 'u',
    };
    var normalized = value.trim().toLowerCase();
    replacements.forEach((key, replacement) {
      normalized = normalized.replaceAll(key, replacement);
    });
    normalized = normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty ? fallback : normalized;
  }

  static String salonSlug({
    required String salonName,
    required String salonId,
  }) {
    final suffix = salonId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final shortSuffix =
        suffix.length <= 6
            ? suffix.toLowerCase()
            : suffix.substring(suffix.length - 6).toLowerCase();
    final base = slugify(salonName, fallback: 'salone');
    return shortSuffix.isEmpty ? base : '$base-$shortSuffix';
  }

  static String landingUrl({
    required String origin,
    required String salonSlug,
    required String promotionSlug,
  }) {
    final base = origin.trim().replaceFirst(RegExp(r'/$'), '');
    return '$base/s/${Uri.encodeComponent(salonSlug)}/promozioni/${Uri.encodeComponent(promotionSlug)}';
  }

  static String embedUrl({
    required String origin,
    required String salonSlug,
    required String promotionSlug,
  }) {
    final base = origin.trim().replaceFirst(RegExp(r'/$'), '');
    return '$base/embed/s/${Uri.encodeComponent(salonSlug)}/promozioni/${Uri.encodeComponent(promotionSlug)}';
  }

  static String iframeCode({
    required String origin,
    required String salonSlug,
    required String promotionSlug,
    required String title,
  }) {
    final source = embedUrl(
      origin: origin,
      salonSlug: salonSlug,
      promotionSlug: promotionSlug,
    );
    final safeTitle = title
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '''<iframe
  src="$source"
  title="$safeTitle"
  width="100%"
  height="760"
  style="border: 0; width: 100%;"
  loading="lazy">
</iframe>''';
  }
}
