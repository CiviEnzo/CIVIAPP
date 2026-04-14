import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/screens/admin/forms/package_deposit_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/shift_form_sheet.dart';
import 'package:you_book/presentation/screens/admin/modules/appointments/express_slot_sheet.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('ExpressSlotSheet uses mobile page scaffold on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final salonId = 'salon-1';
    final service = Service(
      id: 'service-1',
      salonId: salonId,
      name: 'Massaggio express',
      category: 'Benessere',
      duration: const Duration(minutes: 30),
      price: 49,
    );
    final operator = StaffMember(
      id: 'staff-1',
      salonId: salonId,
      firstName: 'Giulia',
      lastName: 'Rossi',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ExpressSlotSheet(
              salonId: salonId,
              initialStart: DateTime(2026, 4, 8, 10, 0),
              initialEnd: DateTime(2026, 4, 8, 10, 30),
              services: [service],
              staff: [operator],
              initialStaffId: operator.id,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Crea slot express'), findsOneWidget);
    expect(find.text('Annulla'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ShiftFormSheet uses mobile page scaffold on phone', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftFormSheet(
            salons: [salon],
            staff: [operator],
            defaultSalonId: salon.id,
            defaultStaffId: operator.id,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Nuovo turno'), findsOneWidget);
    expect(find.text('Salva turno'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PackageDepositFormSheet uses mobile page scaffold on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PackageDepositFormSheet(maxAmount: 120)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Nuovo acconto'), findsOneWidget);
    expect(find.text('Salva'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<PaymentMethod>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
