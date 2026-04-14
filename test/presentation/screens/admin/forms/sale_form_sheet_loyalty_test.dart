import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/loyalty_settings.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/screens/admin/forms/client_search_utils.dart';
import 'package:you_book/presentation/screens/admin/forms/sale_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets(
    'SaleFormSheet auto-suggests loyalty redemption and returns summary',
    (tester) async {
      Sale? capturedSale;
      tester.view.physicalSize = const Size(1400, 1600);
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
        loyaltySettings: LoyaltySettings(
          enabled: true,
          earning: LoyaltyEarningRules(
            euroPerPoint: 10,
            rounding: LoyaltyRoundingMode.floor,
          ),
          redemption: LoyaltyRedemptionRules(
            pointValueEuro: 1,
            maxPercent: 0.3,
            autoSuggest: true,
          ),
        ),
      );

      final client = Client(
        id: 'client-1',
        salonId: salon.id,
        firstName: 'Mario',
        lastName: 'Rossi',
        phone: '+393400000000',
        loyaltyPoints: 50,
      );
      final operator = StaffMember(
        id: 'staff-1',
        salonId: salon.id,
        firstName: 'Giulia',
        lastName: 'Rossi',
      );

      final initialItem = SaleItem(
        referenceId: 'manual-1',
        referenceType: SaleReferenceType.service,
        description: 'Prodotto test',
        quantity: 1,
        unitPrice: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        capturedSale = await Navigator.of(context).push<Sale>(
                          MaterialPageRoute(
                            builder:
                                (_) => SaleFormSheet(
                                  salons: [salon],
                                  clients: [client],
                                  staff: [operator],
                                  services: const [],
                                  packages: const [],
                                  inventoryItems: const [],
                                  sales: const [],
                                  initialItems: [initialItem],
                                  initialClientId: client.id,
                                  defaultSalonId: salon.id,
                                  initialStaffId: operator.id,
                                  initialPaymentMethod: PaymentMethod.cash,
                                  initialPaymentStatus: SalePaymentStatus.paid,
                                ),
                          ),
                        );
                      },
                      child: const Text('Apri scheda'),
                    ),
                  ),
                ),
          ),
        ),
      );

      await tester.tap(find.text('Apri scheda'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Programma fedeltà'));
      await tester.pumpAndSettle();

      final loyaltyField = tester.widget<TextFormField>(
        find.byKey(saleFormLoyaltyRedeemFieldKey),
      );
      expect(loyaltyField.controller?.text, '30');

      await tester.tap(find.text('Conferma vendita'));
      await tester.pumpAndSettle();

      expect(find.text('Riepilogo vendita'), findsOneWidget);

      await tester.tap(find.text('Salva vendita'));
      await tester.pumpAndSettle();

      expect(capturedSale, isNotNull);
      final sale = capturedSale!;
      expect(sale.loyalty.redeemedPoints, 30);
      expect(sale.loyalty.redeemedValue, 30);
      expect(sale.loyalty.earnedPoints, 7);
      expect(sale.loyalty.netPoints, -23);
      expect(sale.discountAmount, 30);
      expect(sale.total, 70);
    },
  );

  testWidgets(
    'SaleFormSheet allows equipment as service provider but not as recorder',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
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
        firstName: 'Mario',
        lastName: 'Rossi',
        phone: '+393400000000',
      );

      final operator = StaffMember(
        id: 'staff-1',
        salonId: salon.id,
        firstName: 'Giulia',
        lastName: 'Rossi',
      );
      final equipment = StaffMember(
        id: 'equipment-1',
        salonId: salon.id,
        firstName: 'VacuFIT',
        lastName: '',
        isEquipment: true,
      );

      final initialItem = SaleItem(
        referenceId: 'manual-1',
        referenceType: SaleReferenceType.service,
        description: 'Prodotto test',
        quantity: 1,
        unitPrice: 30,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaleFormSheet(
              salons: [salon],
              clients: [client],
              staff: [operator, equipment],
              services: const [],
              packages: const [],
              inventoryItems: const [],
              sales: const [],
              initialItems: [initialItem],
              initialClientId: client.id,
              defaultSalonId: salon.id,
              initialStaffId: equipment.id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('VacuFIT (Macchinario)', skipOffstage: false),
        findsOneWidget,
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Giulia Rossi', skipOffstage: false), findsWidgets);
      expect(
        find.text('VacuFIT (Macchinario)', skipOffstage: false),
        findsNWidgets(2),
      );

      await tester.tap(
        find.text('VacuFIT (Macchinario)', skipOffstage: false).last,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Conferma vendita'));
      await tester.pumpAndSettle();

      expect(
        find.text('VacuFIT (Macchinario)', skipOffstage: false),
        findsOneWidget,
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Giulia Rossi', skipOffstage: false), findsWidgets);
      expect(
        find.text('VacuFIT (Macchinario)', skipOffstage: false),
        findsAtLeastNWidgets(1),
      );
    },
  );

  testWidgets(
    'SaleFormSheet routes zero-total sales through review and assigns imp0 on submit',
    (tester) async {
      Sale? capturedSale;
      tester.view.physicalSize = const Size(1400, 1600);
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
        firstName: 'Mario',
        lastName: 'Rossi',
        phone: '+393400000000',
      );

      final operator = StaffMember(
        id: 'staff-1',
        salonId: salon.id,
        firstName: 'Giulia',
        lastName: 'Rossi',
      );

      final initialItem = SaleItem(
        referenceId: 'manual-1',
        referenceType: SaleReferenceType.service,
        description: 'Prodotto promo',
        quantity: 1,
        unitPrice: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SaleFormSheet(
              salons: [salon],
              clients: [client],
              staff: [operator],
              services: const [],
              packages: const [],
              inventoryItems: const [],
              sales: const [],
              initialItems: [initialItem],
              initialClientId: client.id,
              defaultSalonId: salon.id,
              initialStaffId: operator.id,
              onSaved: (sale) => capturedSale = sale,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Riepilogo vendita'), findsNothing);

      await tester.tap(find.text('Conferma vendita'));
      await tester.pumpAndSettle();

      expect(find.text('Riepilogo vendita'), findsOneWidget);
      expect(find.text('Stato pagamento'), findsNothing);
      expect(find.text('Metodo di pagamento'), findsNothing);
      expect(find.text('REGISTRATO DA'), findsOneWidget);

      await tester.tap(find.text('Salva vendita'));
      await tester.pumpAndSettle();

      expect(capturedSale, isNotNull);
      expect(capturedSale!.paymentMethod, PaymentMethod.imp0);
      expect(capturedSale!.paymentStatus, SalePaymentStatus.paid);
      expect(capturedSale!.paidAmount, 0);
      expect(capturedSale!.paymentHistory, isEmpty);
    },
  );

  testWidgets('SaleFormSheet keeps inline client search on desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1600);
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
      firstName: 'Mario',
      lastName: 'Rossi',
      phone: '+393400000000',
      clientNumber: '101',
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
          body: SaleFormSheet(
            salons: [salon],
            clients: [client],
            staff: [operator],
            services: const [],
            packages: const [],
            inventoryItems: const [],
            sales: const [],
            defaultSalonId: salon.id,
            initialStaffId: operator.id,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Numero cliente'), findsWidgets);
    expect(find.text('Seleziona cliente'), findsNothing);
  });

  testWidgets('SaleFormSheet uses mobile page layout without footer buttons', (
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

    final client = Client(
      id: 'client-1',
      salonId: salon.id,
      firstName: 'Mario',
      lastName: 'Rossi',
      phone: '+393400000000',
      clientNumber: '101',
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
          body: SaleFormSheet(
            salons: [salon],
            clients: [client],
            staff: [operator],
            services: const [],
            packages: const [],
            inventoryItems: const [],
            sales: const [],
            defaultSalonId: salon.id,
            initialStaffId: operator.id,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Registra una vendita'), findsOneWidget);
    expect(find.text('Avanti'), findsOneWidget);
    expect(find.text('Annulla'), findsNothing);
  });

  testWidgets('SaleFormSheet uses dark theme surfaces on mobile', (
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

    final client = Client(
      id: 'client-1',
      salonId: salon.id,
      firstName: 'Mario',
      lastName: 'Rossi',
      phone: '+393400000000',
      clientNumber: '101',
    );

    final operator = StaffMember(
      id: 'staff-1',
      salonId: salon.id,
      firstName: 'Giulia',
      lastName: 'Rossi',
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.amber,
        brightness: Brightness.dark,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SaleFormSheet(
            salons: [salon],
            clients: [client],
            staff: [operator],
            services: const [],
            packages: const [],
            inventoryItems: const [],
            sales: const [],
            defaultSalonId: salon.id,
            initialStaffId: operator.id,
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
      theme.colorScheme.surfaceContainerHighest,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SaleFormSheet waits for 3 characters before showing client suggestions',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1600);
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
        firstName: 'Mario',
        lastName: 'Rossi',
        phone: '+393400000000',
        clientNumber: '101',
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
            body: SaleFormSheet(
              salons: [salon],
              clients: [client],
              staff: [operator],
              services: const [],
              packages: const [],
              inventoryItems: const [],
              sales: const [],
              defaultSalonId: salon.id,
              initialStaffId: operator.id,
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

      expect(find.text('Mario Rossi'), findsNothing);
      expect(
        find.text(ClientSearchUtils.minSearchCriteriaMessage),
        findsOneWidget,
      );

      await tester.enterText(clientField, 'mar');
      await tester.pumpAndSettle();

      expect(
        find.text(ClientSearchUtils.minSearchCriteriaMessage),
        findsNothing,
      );
      expect(find.text('Mario Rossi'), findsOneWidget);
    },
  );
}
