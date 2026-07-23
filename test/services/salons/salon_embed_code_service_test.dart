import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/services/salons/salon_embed_code_service.dart';

void main() {
  group('SalonEmbedCodeService', () {
    test('creates public and embedded registration URLs', () {
      expect(
        SalonEmbedCodeService.publicFormUrl(
          origin: 'https://example.com/',
          salonId: 'salone test',
        ),
        'https://example.com/registrazione/salone%20test',
      );
      expect(
        SalonEmbedCodeService.publicFormUrl(
          origin: 'https://example.com',
          salonId: 'salon-1',
          embedded: true,
        ),
        'https://example.com/embed/registrazione/salon-1',
      );
    });

    test('creates paste-ready iframe and escapes the salon name', () {
      final code = SalonEmbedCodeService.iframeCode(
        origin: 'https://example.com',
        salonId: 'salon-1',
        salonName: 'Beauty "A&B"',
      );

      expect(
        code,
        contains('src="https://example.com/embed/registrazione/salon-1"'),
      );
      expect(
        code,
        contains('title="Registrazione Beauty &quot;A&amp;B&quot;"'),
      );
      expect(code, contains('style="border: 0; width: 100%;"'));
      expect(code, contains('height="820"'));
    });
  });
}
