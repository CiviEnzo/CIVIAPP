import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/inventory_item.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/screens/admin/admin_dashboard_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  setUpAll(() async {
    await initializeDateFormatting('it_IT');
  });

  testWidgets('desktop sidebar shows figma section order and selected state', (
    tester,
  ) async {
    await _pumpAdminDashboard(tester, size: const Size(1440, 1200));

    expect(
      find.byKey(const ValueKey('admin_sidebar_section_business')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_sidebar_section_core')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_sidebar_section_sales')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_sidebar_section_promo')),
      findsOneWidget,
    );

    final overviewY =
        tester
            .getTopLeft(
              find.byKey(const ValueKey('admin_sidebar_item_overview')),
            )
            .dy;
    final businessY =
        tester
            .getTopLeft(
              find.byKey(const ValueKey('admin_sidebar_section_business')),
            )
            .dy;
    final coreY =
        tester
            .getTopLeft(
              find.byKey(const ValueKey('admin_sidebar_section_core')),
            )
            .dy;
    final salesY =
        tester
            .getTopLeft(
              find.byKey(const ValueKey('admin_sidebar_section_sales')),
            )
            .dy;
    final promoY =
        tester
            .getTopLeft(
              find.byKey(const ValueKey('admin_sidebar_section_promo')),
            )
            .dy;

    expect(overviewY, lessThan(businessY));
    expect(businessY, lessThan(coreY));
    expect(coreY, lessThan(salesY));
    expect(salesY, lessThan(promoY));

    final overviewVisual = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('admin_sidebar_visual_overview')),
    );
    final overviewDecoration = overviewVisual.decoration! as BoxDecoration;
    expect(overviewDecoration.color, const Color(0xFFD4AF37));

    expect(
      find.byKey(const ValueKey('admin_sidebar_item_app_movements')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('admin_sidebar_item_reports')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('admin_sidebar_item_services')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('admin_sidebar_item_inventory')),
      findsNothing,
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin_sidebar_item_whatsapp')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Icon && widget.icon == FontAwesomeIcons.whatsapp,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('desktop sidebar expands hidden modules from section toggles', (
    tester,
  ) async {
    await _pumpAdminDashboard(tester, size: const Size(1440, 1200));

    expect(
      find.byKey(const ValueKey('admin_sidebar_item_reports')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('admin_sidebar_item_inventory')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('admin_sidebar_toggle_business')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin_sidebar_item_app_movements')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_sidebar_item_reports')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('admin_sidebar_toggle_sales')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin_sidebar_item_services')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_sidebar_item_inventory')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('admin_sidebar_item_inventory')),
        matching: find.byType(Badge),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'desktop sidebar shows hover background together with aligned tooltip',
    (tester) async {
      await _pumpAdminDashboard(tester, size: const Size(1440, 1200));

      await tester.tap(
        find.byKey(const ValueKey('admin_sidebar_toggle_business')),
      );
      await tester.pumpAndSettle();

      final reportItem = find.byKey(
        const ValueKey('admin_sidebar_item_reports'),
      );
      final reportVisual = find.byKey(
        const ValueKey('admin_sidebar_visual_reports'),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await tester.pump();

      await mouse.moveTo(tester.getCenter(reportItem));
      await tester.pump(const Duration(milliseconds: 520));

      expect(
        find.byKey(const ValueKey('admin_sidebar_tooltip_reports')),
        findsOneWidget,
      );
      expect(_containerColor(tester, reportVisual), isNot(Colors.transparent));
      final tooltipRect = tester.getRect(
        find.byKey(const ValueKey('admin_sidebar_tooltip_reports')),
      );
      expect(tooltipRect.width, lessThan(260));
      final reportCenterY = tester.getCenter(reportVisual).dy;
      final tooltipCenterY =
          tester
              .getCenter(
                find.byKey(const ValueKey('admin_sidebar_tooltip_reports')),
              )
              .dy;
      expect((tooltipCenterY - reportCenterY).abs(), lessThanOrEqualTo(2));

      await mouse.moveTo(const Offset(400, 40));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('admin_sidebar_tooltip_reports')),
        findsNothing,
      );
      expect(_containerColor(tester, reportVisual), Colors.transparent);
    },
  );

  testWidgets('changing module dismisses active appointment hover preview', (
    tester,
  ) async {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('A RenderFlex overflowed by')) {
        return;
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await _pumpAdminDashboard(tester, size: const Size(1800, 1200));

    await tester.tap(
      find.byKey(const ValueKey('admin_sidebar_item_appointments')),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump();

    final appointmentCards = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'appointment-card-',
          ),
    );
    expect(appointmentCards, findsWidgets);
    await tester.ensureVisible(appointmentCards.first);
    await tester.pumpAndSettle();
    final appointmentCard = appointmentCards.hitTestable();
    expect(appointmentCard, findsWidgets);
    await mouse.moveTo(tester.getCenter(appointmentCard.first));
    await tester.pump(const Duration(milliseconds: 250));

    const hoverPreviewKey = ValueKey<String>('appointment_hover_preview');
    expect(find.byKey(hoverPreviewKey), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('admin_sidebar_item_clients')));
    await tester.pumpAndSettle();

    expect(find.byKey(hoverPreviewKey), findsNothing);
  });

  testWidgets('mobile drawer uses same grouping and closes after selection', (
    tester,
  ) async {
    await _pumpAdminDashboard(tester, size: const Size(800, 1200));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin_drawer_section_business')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_drawer_section_core')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_drawer_section_sales')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_drawer_section_promo')),
      findsOneWidget,
    );

    final overviewY =
        tester
            .getTopLeft(
              find.byKey(const ValueKey('admin_drawer_item_overview')),
            )
            .dy;
    final businessY =
        tester
            .getTopLeft(
              find.byKey(const ValueKey('admin_drawer_section_business')),
            )
            .dy;
    final coreY =
        tester
            .getTopLeft(find.byKey(const ValueKey('admin_drawer_section_core')))
            .dy;
    final salesY =
        tester
            .getTopLeft(
              find.byKey(const ValueKey('admin_drawer_section_sales')),
            )
            .dy;
    final promoY =
        tester
            .getTopLeft(
              find.byKey(const ValueKey('admin_drawer_section_promo')),
            )
            .dy;

    expect(overviewY, lessThan(businessY));
    expect(businessY, lessThan(coreY));
    expect(coreY, lessThan(salesY));
    expect(salesY, lessThan(promoY));

    expect(
      find.byKey(const ValueKey('admin_drawer_item_reports')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('admin_drawer_item_services')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('admin_drawer_toggle_business')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin_drawer_item_app_movements')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_drawer_item_reports')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('admin_drawer_item_reports')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin_drawer_section_business')),
      findsNothing,
    );
  });

  testWidgets('phone viewport keeps app bar and drawer usable', (tester) async {
    await _pumpAdminDashboard(tester, size: const Size(390, 844));

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text('Panoramica'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin_drawer_section_business')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin_drawer_section_sales')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('intent auto-expands section for hidden desktop module', (
    tester,
  ) async {
    final container = await _pumpAdminDashboard(
      tester,
      size: const Size(1440, 1200),
    );

    expect(
      find.byKey(const ValueKey('admin_sidebar_item_reports')),
      findsNothing,
    );

    container
        .read(adminDashboardIntentProvider.notifier)
        .state = const AdminDashboardIntent(moduleId: 'reports');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('admin_sidebar_item_reports')),
      findsOneWidget,
    );
    expect(
      _containerColor(
        tester,
        find.byKey(const ValueKey('admin_sidebar_visual_reports')),
      ),
      const Color(0xFFD4AF37),
    );
  });

  testWidgets('expanded sections are restored per admin uid', (tester) async {
    var container = await _pumpAdminDashboard(
      tester,
      size: const Size(1440, 1200),
      adminUid: 'admin-a',
    );

    await tester.tap(
      find.byKey(const ValueKey('admin_sidebar_toggle_business')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin_sidebar_item_reports')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    container.dispose();

    container = await _pumpAdminDashboard(
      tester,
      size: const Size(1440, 1200),
      adminUid: 'admin-a',
    );
    expect(
      find.byKey(const ValueKey('admin_sidebar_item_reports')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    container.dispose();

    await _pumpAdminDashboard(
      tester,
      size: const Size(1440, 1200),
      adminUid: 'admin-b',
    );
    expect(
      find.byKey(const ValueKey('admin_sidebar_item_reports')),
      findsNothing,
    );
  });
}

Future<ProviderContainer> _pumpAdminDashboard(
  WidgetTester tester, {
  required Size size,
  String adminUid = 'admin-test',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final baseStore = AppDataStore(currentUser: null);
  final baseState = baseStore.state;
  final salonId = baseState.salons.first.id;
  final state = baseState.copyWith(
    appointmentDayChecklists: const [],
    inventoryItems: [
      ...baseState.inventoryItems,
      InventoryItem(
        id: 'test-low-stock',
        salonId: salonId,
        name: 'Prodotto test',
        category: 'Test',
        quantity: 0,
        unit: 'pz',
        threshold: 1,
      ),
    ],
  );
  final sessionController =
      SessionController()..updateUser(
        AppUser(
          uid: adminUid,
          role: UserRole.admin,
          salonIds: [salonId],
          isEmailVerified: true,
          displayName: 'Admin Test',
        ),
      );

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );

  final container = ProviderContainer(
    overrides: [
      appDataProvider.overrideWith((ref) => _TestAppDataStore(state)),
      sessionControllerProvider.overrideWith((ref) => sessionController),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('it', 'IT'),
        supportedLocales: const [Locale('it', 'IT')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _TestAppDataStore extends AppDataStore {
  _TestAppDataStore(AppDataState initialState) : super(currentUser: null) {
    state = initialState;
  }
}

Color? _containerColor(WidgetTester tester, Finder finder) {
  final widget = tester.widget<AnimatedContainer>(finder);
  final decoration = widget.decoration! as BoxDecoration;
  return decoration.color;
}
