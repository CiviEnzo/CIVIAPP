import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/screens/admin/forms/client_form_sheet.dart';

void main() {
  testWidgets('ClientFormSheet uses mobile page layout on phone', (
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientFormSheet(
            salons: [salon],
            clients: const <Client>[],
            defaultSalonId: salon.id,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Nuovo cliente'), findsOneWidget);
    expect(find.text('Salva'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ClientFormSheet uses dark theme surfaces on mobile', (
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
          body: ClientFormSheet(
            salons: [salon],
            clients: [client],
            initial: client,
            defaultSalonId: salon.id,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final innerScaffold =
        tester.widgetList<Scaffold>(find.byType(Scaffold)).last;
    final clientTheme =
        tester
            .widgetList<Theme>(
              find.descendant(
                of: find.byType(ClientFormSheet),
                matching: find.byType(Theme),
              ),
            )
            .first;

    expect(innerScaffold.backgroundColor, theme.colorScheme.surface);
    expect(
      clientTheme.data.inputDecorationTheme.fillColor,
      theme.colorScheme.surfaceContainerHigh,
    );
    expect(tester.takeException(), isNull);
  });
}
