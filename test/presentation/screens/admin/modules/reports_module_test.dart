import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/presentation/screens/admin/modules/reports_module.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('restores the export tab from query params', (tester) async {
    final router = await _pumpReportsModule(
      tester,
      initialLocation: '/?reports_tab=export',
    );

    expect(find.text('Executive PDF'), findsOneWidget);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Report disponibili'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['reports_tab'],
      isNull,
    );
  });

  testWidgets('dashboard shortcut opens analytics and persists tab query', (
    tester,
  ) async {
    final router = await _pumpReportsModule(tester);

    await tester.ensureVisible(find.text('Performance staff'));
    await tester.tap(find.text('Performance staff'));
    await tester.pumpAndSettle();

    expect(
      find.text('Produttivita, ticket medio e occupazione per operatore.'),
      findsOneWidget,
    );
    expect(
      router.routeInformationProvider.value.uri.queryParameters['reports_tab'],
      'analytics',
    );
  });

  testWidgets('analytics shortcuts stay visible while scrolling', (
    tester,
  ) async {
    await _pumpReportsModule(tester);

    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();

    final venditeChip = find.widgetWithText(ChoiceChip, 'Vendite');
    expect(venditeChip, findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();

    final chipTop = tester.getTopLeft(venditeChip).dy;
    expect(chipTop, greaterThanOrEqualTo(0));
    expect(chipTop, lessThan(240));
  });
}

Future<GoRouter> _pumpReportsModule(
  WidgetTester tester, {
  String initialLocation = '/',
}) async {
  tester.view.physicalSize = const Size(1440, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: ReportsModule()),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDataProvider.overrideWith((ref) => AppDataStore(currentUser: null)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('it', 'IT'),
        supportedLocales: const [Locale('it', 'IT')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
