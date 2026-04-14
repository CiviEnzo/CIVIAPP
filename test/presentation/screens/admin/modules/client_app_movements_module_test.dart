import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/presentation/screens/admin/modules/client_app_movements_module.dart';

void main() {
  testWidgets('renders mobile filters without overflow', (tester) async {
    await _pumpModule(
      tester,
      state: AppDataState.initial(),
      size: const Size(390, 844),
    );

    expect(
      find.byKey(const ValueKey('client_app_movements_filters_bar')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.text('Nessun movimento disponibile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpModule(
  WidgetTester tester, {
  required AppDataState state,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDataProvider.overrideWith((ref) => _TestAppDataStore(state)),
      ],
      child: MaterialApp(
        locale: const Locale('it', 'IT'),
        supportedLocales: const [Locale('it', 'IT')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(body: ClientAppMovementsModule()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestAppDataStore extends AppDataStore {
  _TestAppDataStore(AppDataState initialState) : super(currentUser: null) {
    state = initialState;
  }
}
