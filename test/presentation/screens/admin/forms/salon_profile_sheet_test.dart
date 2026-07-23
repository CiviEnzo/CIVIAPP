import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_profile_sheet.dart';

class _TestAppDataStore extends AppDataStore {
  _TestAppDataStore(AppDataState testState) : super() {
    state = testState;
  }
}

void main() {
  testWidgets('SalonProfileSheet saves edited name and contacts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final salon = _salon(name: 'Salon Test');
    Salon? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<Salon>(
                    context: context,
                    builder: (context) => SalonProfileSheet(salon: salon),
                  );
                },
                child: const Text('Apri profilo'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Apri profilo'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nome salone'),
      'Nuovo Salone',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Telefono'),
      '+390612345678',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'nuovo@salon.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Link prenotazioni'),
      'https://salon.test/prenota',
    );
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.name, 'Nuovo Salone');
    expect(result!.phone, '+390612345678');
    expect(result!.email, 'nuovo@salon.test');
    expect(result!.bookingLink, 'https://salon.test/prenota');
    expect(result!.address, salon.address);
  });

  test('updateSalonProfileSection persists edited name and contacts', () async {
    final current = _salon(name: 'Salon Test');
    final source = current.copyWith(
      name: 'Nuovo Salone',
      phone: '+390612345678',
      email: 'nuovo@salon.test',
      bookingLink: 'https://salon.test/prenota',
    );
    final store = _TestAppDataStore(
      AppDataState.initial().copyWith(salons: <Salon>[current]),
    );

    final updated = await store.updateSalonProfileSection(
      salonId: current.id,
      source: source,
    );

    expect(updated.name, 'Nuovo Salone');
    expect(updated.phone, '+390612345678');
    expect(updated.email, 'nuovo@salon.test');
    expect(updated.bookingLink, 'https://salon.test/prenota');
    expect(store.state.salons.single.name, 'Nuovo Salone');
    expect(store.state.salons.single.phone, '+390612345678');
    expect(store.state.salons.single.email, 'nuovo@salon.test');
    expect(store.state.salons.single.bookingLink, 'https://salon.test/prenota');
  });
}

Salon _salon({required String name}) {
  return Salon(
    id: 'salon-1',
    name: name,
    address: 'Via Roma 1',
    city: 'Roma',
    phone: '+39000000000',
    email: 'salon@test.com',
  );
}
