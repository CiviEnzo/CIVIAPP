import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/screens/admin/modules/salon_management_module.dart';
import 'package:you_book/services/whatsapp_service.dart';

void main() {
  testWidgets('selects salons only through salon cards', (tester) async {
    final salons = <Salon>[
      _salon(id: 'salon-1', name: 'Estetica Lentini'),
      _salon(id: 'salon-2', name: 'Civi salon'),
    ];
    final store = _TestAppDataStore(
      AppDataState.initial().copyWith(salons: salons),
    );
    final sessionController =
        SessionController()..updateUser(
          const AppUser(
            uid: 'admin-1',
            role: UserRole.admin,
            salonIds: <String>['salon-1', 'salon-2'],
            isEmailVerified: true,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataProvider.overrideWith((ref) => store),
          sessionControllerProvider.overrideWith((ref) => sessionController),
          whatsappConfigProvider.overrideWith(
            (ref, salonId) => const Stream<WhatsAppConfig?>.empty(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SalonManagementModule(selectedSalonId: 'salon-1'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DropdownButton<String?>), findsNothing);
    expect(find.text('Crea salone'), findsNothing);
    expect(find.text('Aggiungi Salone'), findsNothing);
    expect(sessionController.state.selectedSalonId, 'salon-1');

    await tester.tap(find.byKey(const ValueKey('salon_tab_salon-2')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(sessionController.state.selectedSalonId, 'salon-2');
    expect(find.text('Cambio salone in corso'), findsOneWidget);
    expect(find.text('Sto caricando Civi salon.'), findsOneWidget);
  });

  testWidgets('shows loading instead of falling back while target loads', (
    tester,
  ) async {
    final store = _TestAppDataStore(
      AppDataState.initial().copyWith(
        salons: <Salon>[_salon(id: 'salon-1', name: 'Estetica Lentini')],
      ),
    );
    final sessionController =
        SessionController()
          ..updateUser(
            const AppUser(
              uid: 'admin-1',
              role: UserRole.admin,
              salonIds: <String>['salon-1', 'salon-2'],
              isEmailVerified: true,
            ),
          )
          ..setSalon('salon-2');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataProvider.overrideWith((ref) => store),
          sessionControllerProvider.overrideWith((ref) => sessionController),
          whatsappConfigProvider.overrideWith(
            (ref, salonId) => const Stream<WhatsAppConfig?>.empty(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SalonManagementModule(selectedSalonId: 'salon-2'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(sessionController.state.selectedSalonId, 'salon-2');
    expect(find.text('Cambio salone in corso'), findsOneWidget);
    expect(find.text('Sto caricando salon-2.'), findsOneWidget);
  });
}

Salon _salon({required String id, required String name}) {
  return Salon(
    id: id,
    name: name,
    address: 'Via Roma 1',
    city: 'Roma',
    phone: '+39000000000',
    email: 'salon@test.com',
  );
}

class _TestAppDataStore extends AppDataStore {
  _TestAppDataStore(AppDataState initialState) : super(currentUser: null) {
    state = initialState;
  }
}
