import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:you_book/domain/entities/promotion.dart';

class PublicPromotionLanding {
  const PublicPromotionLanding({
    required this.id,
    required this.salonId,
    required this.salonSlug,
    required this.promotionSlug,
    required this.title,
    required this.salonName,
    required this.webLanding,
    this.subtitle,
    this.tagline,
    this.coverImageUrl,
    this.themeColor,
    this.discountPercentage = 0,
    this.sections = const <PromotionSection>[],
    this.salonPhone = '',
    this.salonEmail = '',
    this.salonCity = '',
    this.salonLogoImageUrl,
    this.privacyPolicyUrl,
    this.privacyVersion = '1',
  });

  final String id;
  final String salonId;
  final String salonSlug;
  final String promotionSlug;
  final String title;
  final String? subtitle;
  final String? tagline;
  final String? coverImageUrl;
  final int? themeColor;
  final double discountPercentage;
  final List<PromotionSection> sections;
  final PromotionWebLanding webLanding;
  final String salonName;
  final String salonPhone;
  final String salonEmail;
  final String salonCity;
  final String? salonLogoImageUrl;
  final String? privacyPolicyUrl;
  final String privacyVersion;

  factory PublicPromotionLanding.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final landingRaw = data['webLanding'];
    final salonRaw = data['salon'];
    final sectionsRaw = data['sections'];
    return PublicPromotionLanding(
      id: doc.id,
      salonId: data['salonId'] as String? ?? '',
      salonSlug: data['salonSlug'] as String? ?? '',
      promotionSlug: data['promotionSlug'] as String? ?? '',
      title: data['title'] as String? ?? '',
      subtitle: data['subtitle'] as String?,
      tagline: data['tagline'] as String?,
      coverImageUrl: data['coverImageUrl'] as String?,
      themeColor: (data['themeColor'] as num?)?.toInt(),
      discountPercentage: (data['discountPercentage'] as num?)?.toDouble() ?? 0,
      sections:
          sectionsRaw is List
              ? sectionsRaw
                  .whereType<Map>()
                  .map(
                    (value) => PromotionSection.fromMap(
                      Map<String, dynamic>.from(value),
                    ),
                  )
                  .where((section) => section.visible)
                  .toList(growable: false)
              : const <PromotionSection>[],
      webLanding: PromotionWebLanding.fromMap(
        landingRaw is Map
            ? Map<String, dynamic>.from(landingRaw)
            : const <String, dynamic>{},
      ),
      salonName: salonRaw is Map ? salonRaw['name'] as String? ?? '' : '',
      salonPhone: salonRaw is Map ? salonRaw['phone'] as String? ?? '' : '',
      salonEmail: salonRaw is Map ? salonRaw['email'] as String? ?? '' : '',
      salonCity: salonRaw is Map ? salonRaw['city'] as String? ?? '' : '',
      salonLogoImageUrl:
          salonRaw is Map ? salonRaw['logoImageUrl'] as String? : null,
      privacyPolicyUrl:
          salonRaw is Map ? salonRaw['privacyPolicyUrl'] as String? : null,
      privacyVersion:
          salonRaw is Map ? salonRaw['privacyVersion'] as String? ?? '1' : '1',
    );
  }
}
