import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/presentation/common/app_notice.dart';
import 'package:you_book/presentation/screens/auth/sign_in_screen.dart';

void main() {
  testWidgets('shows an app notice in the top viewport and auto dismisses', (
    tester,
  ) async {
    final controller = AppNoticeController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppNoticeViewport(
          controller: controller,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    controller.show(const AppNoticeRequest(message: 'Funzionalita in arrivo'));
    await tester.pump();

    expect(find.text('Funzionalita in arrivo'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Funzionalita in arrivo'), findsNothing);
  });

  test('controller replaces the current notice instead of stacking', () {
    final controller = AppNoticeController();
    addTearDown(controller.dispose);

    controller.show(const AppNoticeRequest(message: 'Primo notice'));
    controller.show(const AppNoticeRequest(message: 'Secondo notice'));

    expect(controller.currentRequest?.message, 'Secondo notice');
  });

  testWidgets('keeps multiline messages intact', (tester) async {
    final controller = AppNoticeController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppNoticeViewport(
          controller: controller,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    controller.show(const AppNoticeRequest(message: 'Linea uno\nLinea due'));
    await tester.pump();

    expect(find.text('Linea uno\nLinea due'), findsOneWidget);

    controller.hide();
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('sign in notice uses app notice instead of material snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: AppNoticeScope(
          child: MaterialApp(
            builder: (context, child) {
              return AppNoticeViewport(
                controller: AppNoticeScope.of(context),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const SignInScreen(notice: 'Registrazione completata.'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Registrazione completata.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('cta snackbars still use Material SnackBar', (tester) async {
    await tester.pumpWidget(
      AppNoticeScope(
        child: MaterialApp(
          builder: (context, child) {
            return AppNoticeViewport(
              controller: AppNoticeScope.of(context),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showAppSnackBar(
                      SnackBar(
                        content: const Text('Pacchetto rimosso'),
                        action: SnackBarAction(
                          label: 'Annulla',
                          onPressed: () {},
                        ),
                      ),
                    );
                  },
                  child: const Text('Mostra CTA'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostra CTA'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(SnackBarAction), findsOneWidget);
    expect(find.text('Annulla'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
