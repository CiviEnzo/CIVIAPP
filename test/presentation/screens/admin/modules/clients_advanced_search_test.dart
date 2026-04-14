import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/presentation/screens/admin/modules/clients/advanced_search/advanced_search_tab.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('uses mobile cards for advanced search results', (tester) async {
    await _pumpAdvancedSearchTab(tester, size: const Size(390, 844));

    await tester.tap(
      find.byKey(const ValueKey('clients_advanced_search_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('clients_advanced_results_toolbar_mobile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('clients_advanced_mobile_results')),
      findsOneWidget,
    );
    expect(find.text('Sara Verdi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps desktop table for advanced search results', (
    tester,
  ) async {
    await _pumpAdvancedSearchTab(tester, size: const Size(1280, 1000));

    await tester.tap(
      find.byKey(const ValueKey('clients_advanced_search_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('clients_advanced_results_toolbar_desktop')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('clients_advanced_desktop_results')),
      findsOneWidget,
    );
    expect(find.text('Cliente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAdvancedSearchTab(
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
        home: Scaffold(
          body: AdvancedSearchTab(
            salonId: null,
            onCreateClient: () async {},
            onImportClients: () async {},
            onEditClient: (Client client) async {},
            onSendInvite: (Client client) async {},
            isSendingInvite: (_) => false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
