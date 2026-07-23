import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/domain/entities/public_promotion_landing.dart';
import 'package:you_book/presentation/screens/public/promotion_landing_template_layout.dart';

void main() {
  const templateIds = <String>[
    PromotionLandingTemplates.minimalGlow,
    PromotionLandingTemplates.studioPop,
    PromotionLandingTemplates.botanicalRitual,
  ];

  for (final templateId in templateIds) {
    testWidgets('$templateId renders the full desktop landing', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpTemplate(tester, templateId: templateId, embedded: false);

      expect(
        find.byKey(ValueKey<String>('landing-template-$templateId')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$templateId renders the mobile embed', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpTemplate(tester, templateId: templateId, embedded: true);

      expect(
        find.byKey(ValueKey<String>('landing-template-$templateId')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('test-lead-form')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpTemplate(
  WidgetTester tester, {
  required String templateId,
  required bool embedded,
}) async {
  final promotion = _promotion(templateId);
  final palette = PromotionLandingPalette.fromPromotion(promotion);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Theme(
        data: ThemeData(useMaterial3: true),
        child: PromotionLandingTemplateLayout(
          promotion: promotion,
          palette: palette,
          embedded: embedded,
          bookingKey: GlobalKey(),
          onPrimaryAction: () {},
          leadForm: const SizedBox(
            key: ValueKey<String>('test-lead-form'),
            height: 360,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

PublicPromotionLanding _promotion(String templateId) {
  return PublicPromotionLanding(
    id: 'promotion-1',
    salonId: 'salon-1',
    salonSlug: 'atelier-bellezza',
    promotionSlug: 'rituale-luminosita',
    title: 'Rituale luminosità',
    subtitle: 'Un momento dedicato alla tua pelle',
    tagline: 'Trattamento viso, consulenza e rituale relax.',
    themeColor: 0xFF48675D,
    discountPercentage: 25,
    salonName: 'Atelier Bellezza',
    salonPhone: '+39 0123 456789',
    salonEmail: 'ciao@atelier.it',
    salonCity: 'Milano',
    webLanding: PromotionWebLanding(
      enabled: true,
      slug: 'rituale-luminosita',
      eyebrow: 'Edizione limitata',
      formTitle: 'Prenota il tuo rituale',
      formDescription: 'Lascia i tuoi contatti e ti richiameremo presto.',
      submitLabel: 'Richiedi ora',
      interestOptions: const <String>['Viso', 'Corpo'],
      offerPrice: '79 €',
      originalPrice: '110 €',
      templateId: templateId,
    ),
    sections: const <PromotionSection>[
      PromotionSection(
        id: 'intro',
        type: PromotionSectionType.text,
        order: 0,
        title: 'Bellezza su misura',
        text: 'Un percorso studiato sulle esigenze della tua pelle.',
        layout: PromotionSectionLayout.split,
      ),
      PromotionSection(
        id: 'quote',
        type: PromotionSectionType.text,
        order: 1,
        title: 'Il tuo tempo, la tua luce',
        text: 'Un’esperienza da vivere con calma.',
        layout: PromotionSectionLayout.quote,
      ),
    ],
  );
}
