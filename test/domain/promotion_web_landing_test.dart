import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/domain/entities/promotion.dart';

void main() {
  const templates = <({String id, String label})>[
    (id: PromotionLandingTemplates.editorialBeauty, label: 'Editorial Beauty'),
    (id: PromotionLandingTemplates.minimalGlow, label: 'Minimal Glow'),
    (id: PromotionLandingTemplates.studioPop, label: 'Studio Pop'),
    (id: PromotionLandingTemplates.botanicalRitual, label: 'Botanical Ritual'),
  ];

  group('PromotionLandingTemplates', () {
    test('exposes every approved template in display order', () {
      expect(
        PromotionLandingTemplates.values,
        templates.map((template) => template.id),
      );
    });

    test('returns the approved labels', () {
      for (final template in templates) {
        expect(
          PromotionLandingTemplates.label(template.id),
          template.label,
          reason: template.id,
        );
      }
    });

    for (final fallback in <({String description, String? value})>[
      (description: 'null', value: null),
      (description: 'invalid', value: 'not-approved'),
    ]) {
      test('normalizes ${fallback.description} to Editorial Beauty', () {
        expect(
          PromotionLandingTemplates.normalize(fallback.value),
          PromotionLandingTemplates.editorialBeauty,
        );
      });
    }
  });

  group('PromotionWebLanding', () {
    for (final template in templates) {
      test('round-trips ${template.id}', () {
        final landing = PromotionWebLanding(
          enabled: true,
          slug: 'beauty-reset',
          eyebrow: 'Il tuo primo passo',
          formTitle: 'Prenota il tuo Beauty Reset',
          formDescription: 'Ti ricontatteremo.',
          submitLabel: 'Richiedi ora',
          interestOptions: const ['Viso', 'Corpo'],
          offerPrice: '79 €',
          originalPrice: '120 €',
          fontFamily: 'playfairDmSans',
          templateId: template.id,
        );

        final decoded = PromotionWebLanding.fromMap(landing.toMap());

        expect(decoded.enabled, isTrue);
        expect(decoded.slug, 'beauty-reset');
        expect(decoded.interestOptions, ['Viso', 'Corpo']);
        expect(decoded.offerPrice, '79 €');
        expect(decoded.originalPrice, '120 €');
        expect(decoded.fontFamily, 'playfairDmSans');
        expect(decoded.templateId, template.id);
      });
    }

    for (final fallback in <({String description, String? value})>[
      (description: 'null', value: null),
      (description: 'invalid', value: 'not-approved'),
    ]) {
      test(
        'uses Editorial Beauty for ${fallback.description} template data',
        () {
          final decoded = PromotionWebLanding.fromMap(<String, dynamic>{
            'templateId': fallback.value,
          });

          expect(decoded.templateId, PromotionLandingTemplates.editorialBeauty);
        },
      );
    }
  });
}
