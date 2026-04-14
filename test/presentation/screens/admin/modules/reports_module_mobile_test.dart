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

  testWidgets('compresses filters on mobile without overflow', (tester) async {
    await _pumpReportsModule(tester, size: const Size(390, 844));

    expect(
      find.byKey(const ValueKey('reports_mobile_filters_bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports_filters_toggle')),
      findsOneWidget,
    );
    expect(find.text('Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses advanced filters summary on desktop without overflow', (
    tester,
  ) async {
    await _pumpReportsModule(tester, size: const Size(1280, 1000));

    expect(
      find.byKey(const ValueKey('reports_desktop_filters_bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('reports_filters_toggle')),
      findsOneWidget,
    );
    expect(find.text('Dashboard'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpReportsModule(
  WidgetTester tester, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
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
}
