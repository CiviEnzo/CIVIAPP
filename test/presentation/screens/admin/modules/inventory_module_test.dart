import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/screens/admin/modules/inventory_module.dart';

void main() {
  testWidgets('renders compact inventory cards on phone viewport', (
    tester,
  ) async {
    final state = AppDataState.initial().copyWith(
      salons: const <Salon>[_salon],
      inventoryItems: const <InventoryItem>[
        InventoryItem(
          id: 'inventory-1',
          salonId: _salonId,
          name: 'Shampoo test',
          category: 'Haircare',
          quantity: 2,
          unit: 'pz',
          threshold: 1,
          sellingPrice: 19.9,
        ),
      ],
    );

    await _pumpInventoryModule(
      tester,
      state: state,
      size: const Size(390, 844),
    );

    expect(find.byKey(const ValueKey('inventory_mobile_list')), findsOneWidget);
    expect(find.byKey(const ValueKey('inventory_table_view')), findsNothing);
    expect(find.text('Shampoo test'), findsOneWidget);
    expect(find.text('Aggiungi Prodotto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const String _salonId = 'salon-1';

const Salon _salon = Salon(
  id: _salonId,
  name: 'Civi Salon',
  address: 'Via Roma 1',
  city: 'Roma',
  phone: '+39061234567',
  email: 'test@civisalon.it',
);

Future<void> _pumpInventoryModule(
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
        home: const Scaffold(body: InventoryModule(salonId: _salonId)),
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
