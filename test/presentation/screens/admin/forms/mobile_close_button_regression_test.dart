import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/domain/entities/staff_role.dart';
import 'package:you_book/presentation/screens/admin/forms/inventory_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/staff_form_sheet.dart';
import 'package:you_book/presentation/screens/staff/forms/staff_absence_request_form_sheet.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('StaffFormSheet shows close icon on mobile', (tester) async {
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
    final role = StaffRole(
      id: 'estetista',
      name: 'Estetista',
      salonId: salon.id,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StaffFormSheet(
              salons: [salon],
              roles: [role],
              defaultSalonId: salon.id,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Nuovo membro dello staff'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('InventoryFormSheet shows close icon on mobile', (tester) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InventoryFormSheet(salons: [salon], defaultSalonId: salon.id),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Nuovo articolo'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('StaffAbsenceRequestFormSheet shows close icon on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final staff = StaffMember(
      id: 'staff-1',
      salonId: 'salon-1',
      firstName: 'Giulia',
      lastName: 'Rossi',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StaffAbsenceRequestFormSheet(
              staff: staff,
              salonId: staff.salonId,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Nuova richiesta'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });
}
