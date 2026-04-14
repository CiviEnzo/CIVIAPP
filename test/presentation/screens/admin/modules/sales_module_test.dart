import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/cash_flow_entry.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/payment_ticket.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/screens/admin/modules/sales_module.dart';

void main() {
  testWidgets('renders compact card lists on phone viewport', (tester) async {
    final now = DateTime.now();
    final state = AppDataState.initial().copyWith(
      salons: const <Salon>[_salon],
      clients: const <Client>[_client],
      sales: <Sale>[
        Sale(
          id: 'sale-1',
          salonId: _salonId,
          clientId: _clientId,
          items: [
            SaleItem(
              referenceId: 'svc-1',
              referenceType: SaleReferenceType.service,
              description: 'Piega',
              quantity: 1,
              unitPrice: 45,
            ),
          ],
          total: 45,
          createdAt: now,
          paymentMethod: PaymentMethod.cash,
        ),
      ],
      paymentTickets: <PaymentTicket>[
        PaymentTicket(
          id: 'ticket-1',
          salonId: _salonId,
          appointmentId: 'appt-1',
          clientId: _clientId,
          serviceId: 'svc-1',
          serviceName: 'Colore',
          appointmentStart: now,
          appointmentEnd: now.add(const Duration(hours: 1)),
          createdAt: now,
          expectedTotal: 80,
        ),
      ],
      cashFlowEntries: <CashFlowEntry>[
        CashFlowEntry(
          id: 'cash-1',
          salonId: _salonId,
          type: CashFlowType.income,
          amount: 45,
          date: now,
        ),
      ],
    );

    await _pumpSalesModule(tester, state: state, size: const Size(390, 844));

    expect(
      find.byKey(const ValueKey('sales_open_tickets_mobile_list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('sales_completed_mobile_list')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('sales_open_tickets_table')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('sales_completed_table')), findsNothing);
    expect(find.text('Ticket aperti'), findsOneWidget);
    expect(find.text('Vendite concluse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const String _salonId = 'salon-1';
const String _clientId = 'client-1';

const Salon _salon = Salon(
  id: _salonId,
  name: 'Civi Salon',
  address: 'Via Roma 1',
  city: 'Roma',
  phone: '+39061234567',
  email: 'test@civisalon.it',
);

const Client _client = Client(
  id: _clientId,
  salonId: _salonId,
  firstName: 'Anna',
  lastName: 'Rossi',
  phone: '+3906000000',
);

Future<void> _pumpSalesModule(
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
        home: const Scaffold(body: SalesModule(salonId: _salonId)),
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
