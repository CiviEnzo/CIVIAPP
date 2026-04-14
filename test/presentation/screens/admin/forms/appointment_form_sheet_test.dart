import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/screens/admin/forms/appointment_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/client_search_utils.dart';

class _TestAppDataStore extends AppDataStore {
  _TestAppDataStore(AppDataState testState) : super() {
    state = testState;
  }
}

void main() {
  testWidgets('AppointmentFormSheet copy excludes appointment notes', (
    tester,
  ) async {
    await initializeDateFormatting('it_IT');
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
      firstName: 'Manuela',
      lastName: 'Scarlata',
      phone: '+393660000000',
    );

    final operator = StaffMember(
      id: 'staff-1',
      salonId: salon.id,
      firstName: 'Giulia',
      lastName: 'Rossi',
    );

    final service = Service(
      id: 'service-1',
      salonId: salon.id,
      name: 'Massaggio',
      category: 'Benessere',
      duration: const Duration(minutes: 30),
      price: 30,
    );

    final appointment = Appointment(
      id: 'appointment-1',
      salonId: salon.id,
      clientId: client.id,
      staffId: operator.id,
      serviceIds: [service.id],
      start: DateTime(2026, 3, 9, 9, 0),
      end: DateTime(2026, 3, 9, 9, 30),
      notes: 'Queste note non vanno copiate',
    );

    final testState = AppDataState.initial().copyWith(
      salons: [salon],
      clients: [client],
      staff: [operator],
      services: [service],
      serviceCategories: const <ServiceCategory>[],
      appointments: [appointment],
    );

    final container = ProviderContainer(
      overrides: [
        appDataProvider.overrideWith((ref) => _TestAppDataStore(testState)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: AppointmentFormSheet(
              salons: [salon],
              clients: [client],
              staff: [operator],
              services: [service],
              serviceCategories: const <ServiceCategory>[],
              initial: appointment,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Copia'));
    await tester.pump();

    final clipboard = container.read(appointmentClipboardProvider);
    expect(clipboard, isNotNull);
    expect(clipboard!.appointment.notes, isNull);
    expect(clipboard.appointment.id, isNot(appointment.id));
  });

  testWidgets(
    'AppointmentFormSheet keeps operator editable when modifying an appointment',
    (tester) async {
      await initializeDateFormatting('it_IT');
      tester.view.physicalSize = const Size(1440, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
        firstName: 'Manuela',
        lastName: 'Scarlata',
        phone: '+393660000000',
      );

      final equipment = StaffMember(
        id: 'equipment-1',
        salonId: salon.id,
        firstName: 'Vacu',
        lastName: 'Fit',
        isEquipment: true,
      );
      final operator = StaffMember(
        id: 'staff-1',
        salonId: salon.id,
        firstName: 'Giulia',
        lastName: 'Rossi',
      );

      final service = Service(
        id: 'service-1',
        salonId: salon.id,
        name: 'Massaggio',
        category: 'Benessere',
        duration: const Duration(minutes: 30),
        price: 30,
      );

      final appointment = Appointment(
        id: 'appointment-1',
        salonId: salon.id,
        clientId: client.id,
        staffId: equipment.id,
        serviceIds: [service.id],
        start: DateTime(2026, 3, 9, 9, 0),
        end: DateTime(2026, 3, 9, 9, 30),
      );

      final testState = AppDataState.initial().copyWith(
        salons: [salon],
        clients: [client],
        staff: [operator, equipment],
        services: [service],
        serviceCategories: const <ServiceCategory>[],
        appointments: [appointment],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDataProvider.overrideWith((ref) => _TestAppDataStore(testState)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AppointmentFormSheet(
                salons: [salon],
                clients: [client],
                staff: [operator, equipment],
                services: [service],
                serviceCategories: const <ServiceCategory>[],
                initial: appointment,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Modifica appuntamento'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.text('Vacu Fit'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Giulia Rossi', skipOffstage: false), findsWidgets);
    },
  );

  testWidgets('AppointmentFormSheet keeps inline client search on desktop', (
    tester,
  ) async {
    await initializeDateFormatting('it_IT');
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
      firstName: 'Manuela',
      lastName: 'Scarlata',
      phone: '+393660000000',
      clientNumber: '202',
    );

    final operator = StaffMember(
      id: 'staff-1',
      salonId: salon.id,
      firstName: 'Giulia',
      lastName: 'Rossi',
    );

    final service = Service(
      id: 'service-1',
      salonId: salon.id,
      name: 'Massaggio',
      category: 'Benessere',
      duration: const Duration(minutes: 30),
      price: 30,
    );

    final testState = AppDataState.initial().copyWith(
      salons: [salon],
      clients: [client],
      staff: [operator],
      services: [service],
      serviceCategories: const <ServiceCategory>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataProvider.overrideWith((ref) => _TestAppDataStore(testState)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AppointmentFormSheet(
              salons: [salon],
              clients: [client],
              staff: [operator],
              services: [service],
              serviceCategories: const <ServiceCategory>[],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Numero cliente'), findsWidgets);
    expect(find.text('Seleziona cliente'), findsNothing);
    expect(find.text('Nuovo cliente'), findsOneWidget);
  });

  testWidgets(
    'AppointmentFormSheet uses mobile page layout without duplicate header',
    (tester) async {
      await initializeDateFormatting('it_IT');
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
        firstName: 'Manuela',
        lastName: 'Scarlata',
        phone: '+393660000000',
      );

      final operator = StaffMember(
        id: 'staff-1',
        salonId: salon.id,
        firstName: 'Giulia',
        lastName: 'Rossi',
      );

      final service = Service(
        id: 'service-1',
        salonId: salon.id,
        name: 'Massaggio',
        category: 'Benessere',
        duration: const Duration(minutes: 30),
        price: 30,
      );

      final testState = AppDataState.initial().copyWith(
        salons: [salon],
        clients: [client],
        staff: [operator],
        services: [service],
        serviceCategories: const <ServiceCategory>[],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDataProvider.overrideWith((ref) => _TestAppDataStore(testState)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AppointmentFormSheet(
                salons: [salon],
                clients: [client],
                staff: [operator],
                services: [service],
                serviceCategories: const <ServiceCategory>[],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Nuovo appuntamento'), findsOneWidget);
      expect(find.text('Stato appuntamento'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AppointmentFormSheet uses dark theme surfaces on mobile', (
    tester,
  ) async {
    await initializeDateFormatting('it_IT');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final salon = Salon(
      id: 'salon-1',
      name: 'Salon Test',
      address: 'Via Roma 1',
      city: 'Roma',
      phone: '+39000000000',
      email: 'salon@test.com',
    );

    final operator = StaffMember(
      id: 'staff-1',
      salonId: salon.id,
      firstName: 'Giulia',
      lastName: 'Rossi',
    );

    final service = Service(
      id: 'service-1',
      salonId: salon.id,
      name: 'Massaggio',
      category: 'Benessere',
      duration: const Duration(minutes: 30),
      price: 30,
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.amber,
        brightness: Brightness.dark,
      ),
    );

    final testState = AppDataState.initial().copyWith(
      salons: [salon],
      clients: const <Client>[],
      staff: [operator],
      services: [service],
      serviceCategories: const <ServiceCategory>[],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataProvider.overrideWith((ref) => _TestAppDataStore(testState)),
        ],
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: AppointmentFormSheet(
              salons: [salon],
              clients: const <Client>[],
              staff: [operator],
              services: [service],
              serviceCategories: const <ServiceCategory>[],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final innerScaffold =
        tester.widgetList<Scaffold>(find.byType(Scaffold)).last;
    final operatorDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).first,
    );

    expect(innerScaffold.backgroundColor, theme.colorScheme.surface);
    expect(
      operatorDropdown.decoration.fillColor,
      theme.colorScheme.surfaceContainerHigh,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AppointmentFormSheet waits for 3 characters before showing client suggestions',
    (tester) async {
      await initializeDateFormatting('it_IT');
      tester.view.physicalSize = const Size(1440, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
        firstName: 'Manuela',
        lastName: 'Scarlata',
        phone: '+393660000000',
        clientNumber: '202',
      );

      final operator = StaffMember(
        id: 'staff-1',
        salonId: salon.id,
        firstName: 'Giulia',
        lastName: 'Rossi',
      );

      final service = Service(
        id: 'service-1',
        salonId: salon.id,
        name: 'Massaggio',
        category: 'Benessere',
        duration: const Duration(minutes: 30),
        price: 30,
      );

      final testState = AppDataState.initial().copyWith(
        salons: [salon],
        clients: [client],
        staff: [operator],
        services: [service],
        serviceCategories: const <ServiceCategory>[],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDataProvider.overrideWith((ref) => _TestAppDataStore(testState)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AppointmentFormSheet(
                salons: [salon],
                clients: [client],
                staff: [operator],
                services: [service],
                serviceCategories: const <ServiceCategory>[],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final clientField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Cliente',
      );

      await tester.enterText(clientField, 'ma');
      await tester.pumpAndSettle();

      expect(find.text('Manuela Scarlata'), findsNothing);
      expect(
        find.text(ClientSearchUtils.minSearchCriteriaMessage),
        findsOneWidget,
      );

      await tester.enterText(clientField, 'man');
      await tester.pumpAndSettle();

      expect(
        find.text(ClientSearchUtils.minSearchCriteriaMessage),
        findsNothing,
      );
      expect(find.text('Manuela Scarlata'), findsOneWidget);
    },
  );
}
