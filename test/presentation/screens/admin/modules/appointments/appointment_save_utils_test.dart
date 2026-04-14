import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/appointment_save_utils.dart';

class _TestAppDataStore extends AppDataStore {
  _TestAppDataStore(AppDataState testState) : super() {
    state = testState;
  }
}

void main() {
  final salon = Salon(
    id: 'salon-1',
    name: 'Salon Test',
    address: 'Via Roma 1',
    city: 'Roma',
    phone: '+39000000000',
    email: 'salon@test.com',
  );

  final client = Client(
    id: 'client-1',
    salonId: salon.id,
    firstName: 'Mario',
    lastName: 'Bianchi',
    phone: '+393330000000',
  );

  final staff = StaffMember(
    id: 'staff-1',
    salonId: salon.id,
    firstName: 'Giulia',
    lastName: 'Rossi',
  );

  final service = Service(
    id: 'service-1',
    salonId: salon.id,
    name: 'Taglio',
    category: 'Capelli',
    duration: const Duration(minutes: 30),
    price: 35,
  );

  Appointment buildAppointment() {
    return Appointment(
      id: 'appt-1',
      salonId: salon.id,
      clientId: client.id,
      staffId: staff.id,
      serviceIds: <String>[service.id],
      start: DateTime(2026, 2, 17, 10),
      end: DateTime(2026, 2, 17, 10, 30),
      status: AppointmentStatus.scheduled,
    );
  }

  Future<void> pumpHarness(
    WidgetTester tester, {
    required _TestAppDataStore store,
    required Future<void> Function(WidgetRef ref, BuildContext context)
    onTrigger,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDataProvider.overrideWith((ref) => store)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => onTrigger(ref, context),
                    child: const Text('Salva'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('validateAndSaveAppointment asks confirmation on warning', (
    tester,
  ) async {
    final store = _TestAppDataStore(
      AppDataState.initial().copyWith(
        salons: <Salon>[salon],
        clients: <Client>[client],
        staff: <StaffMember>[staff],
        services: <Service>[service],
        serviceCategories: const <ServiceCategory>[],
      ),
    );
    bool? saveResult;

    await pumpHarness(
      tester,
      store: store,
      onTrigger: (ref, context) async {
        saveResult = await validateAndSaveAppointment(
          context: context,
          ref: ref,
          appointment: buildAppointment(),
          fallbackServices: <Service>[service],
          fallbackSalons: <Salon>[salon],
        );
      },
    );

    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('Conferma posizionamento'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(saveResult, isFalse);
    expect(store.state.appointments, isEmpty);
  });

  testWidgets('validateAndSaveAppointment saves after warning confirmation', (
    tester,
  ) async {
    final store = _TestAppDataStore(
      AppDataState.initial().copyWith(
        salons: <Salon>[salon],
        clients: <Client>[client],
        staff: <StaffMember>[staff],
        services: <Service>[service],
        serviceCategories: const <ServiceCategory>[],
      ),
    );
    bool? saveResult;

    await pumpHarness(
      tester,
      store: store,
      onTrigger: (ref, context) async {
        saveResult = await validateAndSaveAppointment(
          context: context,
          ref: ref,
          appointment: buildAppointment(),
          fallbackServices: <Service>[service],
          fallbackSalons: <Salon>[salon],
        );
      },
    );

    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('Conferma posizionamento'), findsOneWidget);

    await tester.tap(find.text('Conferma'));
    await tester.pumpAndSettle();

    expect(saveResult, isTrue);
    expect(store.state.appointments, hasLength(1));
    expect(store.state.appointments.single.id, equals('appt-1'));
  });
}
