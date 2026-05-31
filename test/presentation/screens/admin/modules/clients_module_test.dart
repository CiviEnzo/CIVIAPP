import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/app/providers.dart';
import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/data/repositories/app_data_state.dart';
import 'package:you_book/data/repositories/app_data_store.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/client_app_movement.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/presentation/screens/admin/modules/clients_module.dart';

const String _salonId = 'salon-1';

void main() {
  testWidgets('hides summary cards on mobile after search', (tester) async {
    await _pumpClientsModule(
      tester,
      state: _buildState(
        clients: <Client>[
          _buildClient(
            id: 'client-sara',
            firstName: 'Sara',
            lastName: 'Verdi',
            phone: '3331111111',
            clientNumber: '101',
          ),
        ],
      ),
      size: const Size(390, 844),
    );

    expect(
      find.byKey(const ValueKey('clients_search_summary_cards')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('clients_search_general_field')),
      'Sara',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('clients_search_summary_cards')),
      findsNothing,
    );
    expect(find.text('Elenco clienti'), findsOneWidget);
    expect(find.text('Cliente #101'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses real app activity for client badge and app KPI', (
    tester,
  ) async {
    final clients = <Client>[
      _buildClient(
        id: 'client-no-activity',
        firstName: 'Anna',
        lastName: 'Cliente',
        phone: '3330000001',
        email: 'anna@example.com',
        clientNumber: '1001',
        onboardingStatus: ClientOnboardingStatus.firstLogin,
        firstLoginAt: DateTime(2026, 4, 10),
      ),
      _buildClient(
        id: 'client-invited',
        firstName: 'Bianca',
        lastName: 'Cliente',
        phone: '3330000002',
        email: 'bianca@example.com',
        clientNumber: '1002',
        onboardingStatus: ClientOnboardingStatus.invitationSent,
        invitationSentAt: DateTime(2026, 4, 11),
      ),
      _buildClient(
        id: 'client-movement',
        firstName: 'Carla',
        lastName: 'Cliente',
        phone: '3330000003',
        email: 'carla@example.com',
        clientNumber: '1003',
      ),
      _buildClient(
        id: 'client-token',
        firstName: 'Daria',
        lastName: 'Cliente',
        phone: '3330000004',
        email: 'daria@example.com',
        clientNumber: '1004',
        fcmTokens: const <String>['token-1'],
      ),
    ];

    await _pumpClientsModule(
      tester,
      state: _buildState(
        clients: clients,
        clientAppMovements: <ClientAppMovement>[
          _buildMovement(clientId: 'client-movement', id: 'movement-1'),
        ],
      ),
      size: const Size(1800, 1200),
    );

    await tester.enterText(
      find.byKey(const ValueKey('clients_search_general_field')),
      'Cliente',
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: _summaryCardFinder('App Attiva'),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.text('Non scaricata'), findsOneWidget);
    expect(find.text('Link inviato'), findsOneWidget);
    expect(find.text('Scaricata'), findsNWidgets(2));
    expect(find.text('Anna Cliente'), findsOneWidget);
    expect(find.text('Bianca Cliente'), findsOneWidget);
    expect(find.text('Carla Cliente'), findsOneWidget);
    expect(find.text('Daria Cliente'), findsOneWidget);
    expect(find.text('Cliente #1001'), findsOneWidget);
    expect(find.text('Cliente #1004'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'adding email without real app activity does not change badge or KPI',
    (tester) async {
      final store = _TestAppDataStore(
        _buildState(
          clients: <Client>[
            _buildClient(
              id: 'client-regression',
              firstName: 'Giulia',
              lastName: 'Cliente',
              phone: '3339999999',
            ),
          ],
        ),
      );

      await _pumpClientsModule(
        tester,
        store: store,
        size: const Size(1800, 1200),
      );

      await tester.enterText(
        find.byKey(const ValueKey('clients_search_general_field')),
        'Giulia',
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: _summaryCardFinder('App Attiva'),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(find.text('Non scaricata'), findsOneWidget);

      final updatedClient = _buildClient(
        id: 'client-regression',
        firstName: 'Giulia',
        lastName: 'Cliente',
        phone: '3339999999',
        email: 'giulia@example.com',
        onboardingStatus: ClientOnboardingStatus.firstLogin,
        firstLoginAt: DateTime(2026, 4, 12),
      );
      store.setAppState(
        _buildState(
          clients: <Client>[updatedClient],
          users: <AppUser>[
            AppUser(
              uid: 'user-giulia',
              role: UserRole.client,
              salonIds: const <String>[_salonId],
              clientId: updatedClient.id,
              email: updatedClient.email,
              displayName: updatedClient.fullName,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('giulia@example.com'), findsOneWidget);
      expect(
        find.descendant(
          of: _summaryCardFinder('App Attiva'),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(find.text('Scaricata'), findsNothing);
      expect(find.text('Non scaricata'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpClientsModule(
  WidgetTester tester, {
  AppDataState? state,
  _TestAppDataStore? store,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final effectiveStore = store ?? _TestAppDataStore(state ?? _buildState());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDataProvider.overrideWith((ref) => effectiveStore)],
      child: MaterialApp(
        locale: const Locale('it', 'IT'),
        supportedLocales: const <Locale>[Locale('it', 'IT')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(body: ClientsModule()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AppDataState _buildState({
  List<Client> clients = const <Client>[],
  List<ClientAppMovement> clientAppMovements = const <ClientAppMovement>[],
  List<AppUser> users = const <AppUser>[],
}) {
  return AppDataState.initial().copyWith(
    salons: const <Salon>[_salon],
    clients: clients,
    clientAppMovements: clientAppMovements,
    users: users,
  );
}

Client _buildClient({
  required String id,
  required String firstName,
  required String lastName,
  required String phone,
  String? clientNumber,
  String? email,
  List<String> fcmTokens = const <String>[],
  ClientOnboardingStatus onboardingStatus = ClientOnboardingStatus.notSent,
  DateTime? invitationSentAt,
  DateTime? firstLoginAt,
  DateTime? createdAt,
}) {
  return Client(
    id: id,
    salonId: _salonId,
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    clientNumber: clientNumber,
    email: email,
    fcmTokens: fcmTokens,
    onboardingStatus: onboardingStatus,
    invitationSentAt: invitationSentAt,
    firstLoginAt: firstLoginAt,
    createdAt: createdAt ?? DateTime(2026, 4, 1),
  );
}

ClientAppMovement _buildMovement({
  required String id,
  required String clientId,
}) {
  return ClientAppMovement(
    id: id,
    salonId: _salonId,
    clientId: clientId,
    type: ClientAppMovementType.purchase,
    timestamp: DateTime(2026, 4, 13, 10),
  );
}

Finder _summaryCardFinder(String title) {
  return find.ancestor(of: find.text(title), matching: find.byType(Card)).first;
}

class _TestAppDataStore extends AppDataStore {
  _TestAppDataStore(AppDataState initialState) : super(currentUser: null) {
    state = initialState;
  }

  void setAppState(AppDataState nextState) {
    state = nextState;
  }
}

const Salon _salon = Salon(
  id: _salonId,
  name: 'Salon Test',
  address: 'Via Roma 1',
  city: 'Roma',
  phone: '0612345678',
  email: 'salon@example.com',
);
