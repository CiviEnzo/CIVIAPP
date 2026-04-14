import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/presentation/screens/admin/modules/clients_module.dart';

void main() {
  testWidgets('hides summary cards on mobile after search', (tester) async {
    await _pumpClientsModule(tester, size: const Size(390, 844));

    expect(
      find.byKey(const ValueKey('clients_search_summary_cards')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('clients_search_general_field')),
      'Sara',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('clients_search_summary_cards')),
      findsNothing,
    );
    expect(find.text('Elenco clienti'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps summary cards visible on desktop after search', (
    tester,
  ) async {
    await _pumpClientsModule(tester, size: const Size(1280, 1000));

    await tester.enterText(
      find.byKey(const ValueKey('clients_search_general_field')),
      'Sara',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('clients_search_summary_cards')),
      findsOneWidget,
    );
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Sara Verdi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpClientsModule(
  WidgetTester tester, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDataProvider.overrideWith((ref) => AppDataStore(currentUser: null)),
      ],
      child: MaterialApp(
        locale: const Locale('it', 'IT'),
        supportedLocales: const [Locale('it', 'IT')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(body: ClientsModule()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
