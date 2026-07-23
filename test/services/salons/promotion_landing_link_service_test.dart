import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/services/salons/promotion_landing_link_service.dart';

void main() {
  group('PromotionLandingLinkService', () {
    test('creates stable salon and promotion slugs', () {
      expect(
        PromotionLandingLinkService.slugify('Beauty Réset Estate!'),
        'beauty-reset-estate',
      );
      expect(
        PromotionLandingLinkService.salonSlug(
          salonName: 'Centro Élite',
          salonId: 'salon-ABC123',
        ),
        'centro-elite-abc123',
      );
    });

    test('creates clean landing and iframe URLs', () {
      expect(
        PromotionLandingLinkService.landingUrl(
          origin: 'https://youbook.civiapp.it/',
          salonSlug: 'centro-elite-abc123',
          promotionSlug: 'beauty-reset',
        ),
        'https://youbook.civiapp.it/s/centro-elite-abc123/promozioni/beauty-reset',
      );

      final iframe = PromotionLandingLinkService.iframeCode(
        origin: 'https://youbook.civiapp.it',
        salonSlug: 'centro-elite-abc123',
        promotionSlug: 'beauty-reset',
        title: 'Beauty "Reset"',
      );
      expect(
        iframe,
        contains(
          'src="https://youbook.civiapp.it/embed/s/centro-elite-abc123/promozioni/beauty-reset"',
        ),
      );
      expect(iframe, contains('title="Beauty &quot;Reset&quot;"'));
    });
  });
}
