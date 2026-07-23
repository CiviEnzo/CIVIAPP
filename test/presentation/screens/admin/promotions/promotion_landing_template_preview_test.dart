import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/domain/entities/promotion.dart';
import 'package:you_book/presentation/screens/admin/promotions/promotion_editor_dialog.dart';

void main() {
  const templateIds = <String>[
    PromotionLandingTemplates.editorialBeauty,
    PromotionLandingTemplates.minimalGlow,
    PromotionLandingTemplates.studioPop,
    PromotionLandingTemplates.botanicalRitual,
  ];

  for (final templateId in templateIds) {
    testWidgets('editor renders the $templateId landing preview', (
      tester,
    ) async {
      final reportedErrors = <FlutterErrorDetails>[];
      final previousErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        reportedErrors.add(details);
        previousErrorHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = previousErrorHandler);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PromotionEditorDialog(
                salonId: 'salon-1',
                initialPromotion: _promotion(templateId),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Landing web'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey<String>('landing-preview-$templateId')),
        findsOneWidget,
      );
      final exception = tester.takeException();
      if (exception is FlutterError) {
        final diagnostics = reportedErrors
            .map((details) => details.toString())
            .join('\n\n');
        fail(diagnostics.isEmpty ? exception.toStringDeep() : diagnostics);
      }
      expect(exception, isNull);
    });
  }

  testWidgets('template selector exposes four options and switches preview', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PromotionEditorDialog(
              salonId: 'salon-1',
              initialPromotion: _promotion(
                PromotionLandingTemplates.editorialBeauty,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Landing web'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('landing-template-selector-editorialBeauty'),
      ),
    );
    await tester.pumpAndSettle();

    for (final templateId in templateIds) {
      expect(
        find.text(PromotionLandingTemplates.label(templateId)),
        findsWidgets,
      );
    }

    await tester.tap(find.text('Botanical Ritual').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('landing-preview-botanicalRitual')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Promotion _promotion(String templateId) {
  return Promotion(
    id: 'promotion-1',
    salonId: 'salon-1',
    title: 'Rituale luminosità',
    subtitle: 'Un momento dedicato alla tua pelle',
    tagline: 'Trattamento viso, consulenza e rituale relax.',
    themeColor: 0xFF48675D,
    discountPercentage: 25,
    status: PromotionStatus.published,
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
  );
}
