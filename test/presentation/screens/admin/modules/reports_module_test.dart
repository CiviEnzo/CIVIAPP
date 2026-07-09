import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/appointment.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/service.dart';
import 'package:you_book/domain/entities/service_category.dart';
import 'package:you_book/domain/entities/staff_member.dart';
import 'package:you_book/presentation/screens/admin/modules/reports_module.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('restores the export tab from query params', (tester) async {
    final router = await _pumpReportsModule(
      tester,
      initialLocation: '/?reports_tab=export',
    );

    expect(find.text('Executive PDF'), findsOneWidget);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('Report disponibili'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['reports_tab'],
      isNull,
    );
  });

  testWidgets('dashboard shortcut opens analytics and persists tab query', (
    tester,
  ) async {
    final router = await _pumpReportsModule(tester);

    await tester.ensureVisible(find.text('Performance staff'));
    await tester.tap(find.text('Performance staff'));
    await tester.pumpAndSettle();

    expect(
      find.text('Produttivita, ticket medio e occupazione per operatore.'),
      findsOneWidget,
    );
    expect(
      router.routeInformationProvider.value.uri.queryParameters['reports_tab'],
      'analytics',
    );
  });

  testWidgets('analytics shortcuts stay visible while scrolling', (
    tester,
  ) async {
    await _pumpReportsModule(tester);

    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();

    final venditeChip = find.widgetWithText(ChoiceChip, 'Vendite');
    expect(venditeChip, findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();

    final chipTop = tester.getTopLeft(venditeChip).dy;
    expect(chipTop, greaterThanOrEqualTo(0));
    expect(chipTop, lessThan(240));
  });

  testWidgets('changing channel filter refreshes dashboard metrics', (
    tester,
  ) async {
    final currency = NumberFormat.currency(
      locale: 'it_IT',
      symbol: '€',
      decimalDigits: 2,
    );
    final router = await _pumpReportsModule(
      tester,
      initialLocation: '/?reports_from=2026-06-01&reports_to=2026-06-30',
      state: _buildReportFilterState(),
      salonId: 'salon-1',
    );

    expect(find.text(currency.format(300)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reports_filters_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutti i canali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Instagram').last);
    await tester.pumpAndSettle();

    expect(find.text(currency.format(300)), findsNothing);
    expect(find.text(currency.format(200)), findsWidgets);
    expect(
      router
          .routeInformationProvider
          .value
          .uri
          .queryParameters['reports_channels'],
      'instagram',
    );
  });
}

Future<GoRouter> _pumpReportsModule(
  WidgetTester tester, {
  String initialLocation = '/',
  AppDataState? state,
  String? salonId,
}) async {
  tester.view.physicalSize = const Size(1440, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder:
            (context, state) => Scaffold(body: ReportsModule(salonId: salonId)),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDataProvider.overrideWith(
          (ref) =>
              _TestAppDataStore(state ?? AppDataStore(currentUser: null).state),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('it', 'IT'),
        supportedLocales: const [Locale('it', 'IT')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

AppDataState _buildReportFilterState() {
  return AppDataState.initial().copyWith(
    salons: const [
      Salon(
        id: 'salon-1',
        name: 'Salon Test',
        address: 'Via Roma 1',
        city: 'Roma',
        phone: '000',
        email: 'test@example.com',
      ),
    ],
    staff: [
      StaffMember(
        id: 'staff-1',
        salonId: 'salon-1',
        firstName: 'Giulia',
        lastName: 'Rossi',
      ),
    ],
    serviceCategories: const [
      ServiceCategory(id: 'cat-1', salonId: 'salon-1', name: 'Viso'),
    ],
    services: const [
      Service(
        id: 'service-1',
        salonId: 'salon-1',
        name: 'Trattamento viso',
        category: 'Viso',
        categoryId: 'cat-1',
        duration: Duration(minutes: 60),
        price: 100,
      ),
    ],
    clients: [
      Client(
        id: 'client-1',
        salonId: 'salon-1',
        firstName: 'Cliente',
        lastName: 'App',
        phone: '111',
        createdAt: DateTime(2026, 6, 1),
      ),
      Client(
        id: 'client-2',
        salonId: 'salon-1',
        firstName: 'Cliente',
        lastName: 'Instagram',
        phone: '222',
        createdAt: DateTime(2026, 6, 2),
      ),
    ],
    appointments: [
      Appointment(
        id: 'appt-app',
        salonId: 'salon-1',
        clientId: 'client-1',
        staffId: 'staff-1',
        serviceIds: const ['service-1'],
        start: DateTime(2026, 6, 5, 10),
        end: DateTime(2026, 6, 5, 11),
        status: AppointmentStatus.completed,
        bookingChannel: 'app',
      ),
      Appointment(
        id: 'appt-instagram',
        salonId: 'salon-1',
        clientId: 'client-2',
        staffId: 'staff-1',
        serviceIds: const ['service-1'],
        start: DateTime(2026, 6, 6, 10),
        end: DateTime(2026, 6, 6, 11),
        status: AppointmentStatus.completed,
        bookingChannel: 'instagram',
      ),
    ],
    sales: [
      Sale(
        id: 'sale-app',
        salonId: 'salon-1',
        clientId: 'client-1',
        staffId: 'staff-1',
        createdAt: DateTime(2026, 6, 5, 12),
        total: 100,
        items: [
          SaleItem(
            referenceId: 'service-1',
            referenceType: SaleReferenceType.service,
            description: 'Trattamento viso',
            quantity: 1,
            unitPrice: 100,
          ),
        ],
        metadata: const {'source': 'app'},
      ),
      Sale(
        id: 'sale-instagram',
        salonId: 'salon-1',
        clientId: 'client-2',
        staffId: 'staff-1',
        createdAt: DateTime(2026, 6, 6, 12),
        total: 200,
        items: [
          SaleItem(
            referenceId: 'service-1',
            referenceType: SaleReferenceType.service,
            description: 'Trattamento viso',
            quantity: 1,
            unitPrice: 200,
          ),
        ],
        metadata: const {'source': 'instagram'},
      ),
    ],
  );
}

class _TestAppDataStore extends AppDataStore {
  _TestAppDataStore(AppDataState initialState) : super(currentUser: null) {
    state = initialState;
  }
}
