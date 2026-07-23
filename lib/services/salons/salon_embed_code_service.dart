class SalonEmbedCodeService {
  const SalonEmbedCodeService._();

  static const String productionOrigin = 'https://youbook.civiapp.it';

  static String publicFormUrl({
    required String origin,
    required String salonId,
    bool embedded = false,
  }) {
    final normalizedOrigin = origin.trim().replaceFirst(RegExp(r'/$'), '');
    final encodedSalonId = Uri.encodeComponent(salonId.trim());
    final route = embedded ? 'embed/registrazione' : 'registrazione';
    return '$normalizedOrigin/$route/$encodedSalonId';
  }

  static String iframeCode({
    required String origin,
    required String salonId,
    required String salonName,
    int height = 820,
  }) {
    final source = publicFormUrl(
      origin: origin,
      salonId: salonId,
      embedded: true,
    );
    final safeSource = _escapeHtmlAttribute(source);
    final safeTitle = _escapeHtmlAttribute('Registrazione $salonName');

    return '''<iframe
  src="$safeSource"
  title="$safeTitle"
  width="100%"
  height="$height"
  style="border: 0; width: 100%;"
  loading="lazy">
</iframe>''';
  }

  static String _escapeHtmlAttribute(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
