import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/screens/admin/forms/salon_operations_sheet.dart';

void main() {
  testWidgets('SalonOperationsSheet does not offer archived status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalonOperationsSheet(salon: _salon(status: SalonStatus.active)),
        ),
      ),
    );

    expect(find.byType(DropdownButtonFormField<SalonStatus>), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<SalonStatus>));
    await tester.pumpAndSettle();

    expect(find.text('Attivo'), findsWidgets);
    expect(find.text('Sospeso'), findsOneWidget);
    expect(find.text('Archiviato'), findsNothing);
  });

  testWidgets('SalonOperationsSheet shows notice for archived salons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SalonOperationsSheet(
            salon: _salon(status: SalonStatus.archived),
          ),
        ),
      ),
    );

    expect(find.byType(DropdownButtonFormField<SalonStatus>), findsNothing);
    expect(find.text('Stato del salone: Archiviato'), findsOneWidget);
    expect(
      find.text(
        'Questo salone è archiviato. Lo stato può essere modificato solo da un amministratore di piattaforma.',
      ),
      findsOneWidget,
    );
  });

  test('updateSalonOperationsSection does not archive a salon', () async {
    final current = _salon(status: SalonStatus.active);
    final source = current.copyWith(status: SalonStatus.archived);
    final store = _TestAppDataStore(
      AppDataState.initial().copyWith(salons: <Salon>[current]),
    );

    final updated = await store.updateSalonOperationsSection(
      salonId: current.id,
      source: source,
    );

    expect(updated.status, SalonStatus.active);
    expect(store.state.salons.single.status, SalonStatus.active);
  });

  test('updateSalonOperationsSection keeps archived salons locked', () async {
    final current = _salon(status: SalonStatus.archived);
    final source = current.copyWith(status: SalonStatus.active);
    final store = _TestAppDataStore(
      AppDataState.initial().copyWith(salons: <Salon>[current]),
    );

    final updated = await store.updateSalonOperationsSection(
      salonId: current.id,
      source: source,
    );

    expect(updated.status, SalonStatus.archived);
    expect(store.state.salons.single.status, SalonStatus.archived);
  });
}

class _TestAppDataStore extends AppDataStore {
  _TestAppDataStore(AppDataState testState) : super() {
    state = testState;
  }
}

Salon _salon({required SalonStatus status}) {
  return Salon(
    id: 'salon-1',
    name: 'Salon Test',
    address: 'Via Roma 1',
    city: 'Roma',
    phone: '+39000000000',
    email: 'salon@test.com',
    status: status,
  );
}
