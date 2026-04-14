import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/presentation/screens/admin/forms/client_search_sheet.dart';
import 'package:you_book/presentation/screens/admin/forms/client_search_utils.dart';

void main() {
  testWidgets(
    'showClientSearchSheet filters live and returns the tapped client',
    (tester) async {
      Client? selectedClient;
      final clients = [
        Client(
          id: 'client-1',
          salonId: 'salon-1',
          firstName: 'Mario',
          lastName: 'Rossi',
          phone: '+393401111111',
          clientNumber: '101',
        ),
        Client(
          id: 'client-2',
          salonId: 'salon-2',
          firstName: 'Anna',
          lastName: 'Bianchi',
          phone: '+393402222222',
          clientNumber: '202',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => Center(
                    child: FilledButton(
                      onPressed: () async {
                        selectedClient = await showClientSearchSheet(
                          context: context,
                          clients: clients,
                          activeSalonId: 'salon-1',
                        );
                      },
                      child: const Text('Apri ricerca'),
                    ),
                  ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Apri ricerca'));
      await tester.pumpAndSettle();

      expect(find.text('Cerca un cliente'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'mar');
      await tester.pumpAndSettle();

      expect(find.text('Mario Rossi'), findsOneWidget);
      expect(find.text('Anna Bianchi'), findsNothing);

      await tester.tap(find.text('Mario Rossi'));
      await tester.pumpAndSettle();

      expect(selectedClient?.id, 'client-1');
    },
  );

  testWidgets(
    'showClientSearchSheet waits for 3 characters before general search',
    (tester) async {
      final clients = [
        Client(
          id: 'client-1',
          salonId: 'salon-1',
          firstName: 'Mario',
          lastName: 'Rossi',
          phone: '+393401111111',
          clientNumber: '101',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => Center(
                    child: FilledButton(
                      onPressed:
                          () => showClientSearchSheet(
                            context: context,
                            clients: clients,
                          ),
                      child: const Text('Apri ricerca'),
                    ),
                  ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Apri ricerca'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'ma');
      await tester.pumpAndSettle();

      expect(find.text('Mario Rossi'), findsNothing);
      expect(
        find.text(ClientSearchUtils.minSearchCriteriaMessage),
        findsWidgets,
      );

      await tester.enterText(find.byType(TextField).first, 'mar');
      await tester.pumpAndSettle();

      expect(
        find.text(ClientSearchUtils.minSearchCriteriaMessage),
        findsNothing,
      );
      expect(find.text('Mario Rossi'), findsOneWidget);
    },
  );

  testWidgets('showClientSearchSheet uses page layout on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final clients = [
      Client(
        id: 'client-1',
        salonId: 'salon-1',
        firstName: 'Mario',
        lastName: 'Rossi',
        phone: '+393401111111',
        clientNumber: '101',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => Center(
                  child: FilledButton(
                    onPressed:
                        () => showClientSearchSheet(
                          context: context,
                          clients: clients,
                          activeSalonId: 'salon-1',
                          allowCreate: true,
                        ),
                    child: const Text('Apri ricerca'),
                  ),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Apri ricerca'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Seleziona cliente'), findsOneWidget);
    expect(find.text('Nuovo'), findsOneWidget);

    await tester.showKeyboard(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField).last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
