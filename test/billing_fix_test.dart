import 'package:civiapp/app/providers.dart';
import 'package:civiapp/data/models/app_user.dart';
import 'package:civiapp/data/repositories/app_data_store.dart';
import 'package:civiapp/domain/entities/payment_ticket.dart';
import 'package:civiapp/domain/entities/sale.dart';
import 'package:civiapp/domain/entities/user_role.dart';
import 'package:civiapp/presentation/screens/admin/modules/client_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  test('closing ticket removes it from open list', () async {
    final store = AppDataStore(currentUser: null);
    expect(store.state.paymentTickets.where((t) => t.status == PaymentTicketStatus.open).length, 1);
    final ticket = store.state.paymentTickets.first;

    final sale = Sale(
      id: 'sale-test',
      salonId: ticket.salonId,
      clientId: ticket.clientId,
      items: ticket.expectedTotal == null
          ? const []
          : [
              SaleItem(
                referenceId: 'srv',
                referenceType: SaleReferenceType.service,
                description: 'Test service',
                quantity: 1,
                unitPrice: ticket.expectedTotal!,
              ),
            ],
      total: ticket.expectedTotal ?? 0,
      createdAt: DateTime.now(),
    );
    await store.upsertSale(sale);
    await store.closePaymentTicket(ticket.id, saleId: sale.id);

    expect(store.state.paymentTickets.first.status, PaymentTicketStatus.closed);
  });

  test('upserting sale updates outstanding amount', () async {
    final store = AppDataStore(currentUser: null);
    final sale = Sale(
      id: 'sale-outstanding',
      salonId: 'salon-001',
      clientId: 'client-001',
      items: [
        SaleItem(
          referenceId: 'srv-test',
          referenceType: SaleReferenceType.service,
          description: 'Servizio test',
          quantity: 1,
          unitPrice: 100,
        ),
      ],
      total: 100,
      createdAt: DateTime.now(),
      paymentStatus: SalePaymentStatus.deposit,
      paidAmount: 0,
    );

    await store.upsertSale(sale);
    final before = store.state.sales.firstWhere((s) => s.id == sale.id);
    expect(before.outstandingAmount, 100);

    final updated = sale.copyWith(
      paidAmount: 60,
      paymentStatus: SalePaymentStatus.deposit,
    );
    await store.upsertSale(updated);

    final after = store.state.sales.firstWhere((s) => s.id == sale.id);
    expect(after.outstandingAmount, 40);

    final settled = updated.copyWith(
      paidAmount: 100,
      paymentStatus: SalePaymentStatus.paid,
    );
    await store.upsertSale(settled);

    final finalSale = store.state.sales.firstWhere((s) => s.id == sale.id);
    expect(finalSale.outstandingAmount, 0);
    expect(finalSale.paymentStatus, SalePaymentStatus.paid);
  });

  testWidgets('settling open ticket removes it from outstanding list', (tester) async {
    final store = AppDataStore(currentUser: null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataProvider.overrideWith((ref) => store),
        ],
        child: const MaterialApp(
          home: ClientDetailPage(clientId: 'client-001'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to "Fatturazione" tab.
    await tester.tap(find.text('Fatturazione'));
    await tester.pumpAndSettle();

    expect(find.text('Ticket aperti'), findsOneWidget);

    // Open the outstanding ticket entry.
    final ticketTile = find.textContaining('Trattamento Viso Rigenerante');
    expect(ticketTile, findsWidgets);
    await tester.tap(ticketTile.first);
    await tester.pumpAndSettle();

    // Confirm the modal is shown and submit full amount.
    final amountField = find.byType(TextFormField);
    expect(amountField, findsOneWidget);
    await tester.enterText(amountField, '75');
    await tester.pump();

    await tester.tap(find.text('Registra'));
    await tester.pumpAndSettle();

    // The outstanding ticket tile should disappear.
    expect(find.text('Residuo da incassare'), findsNothing);
  });

  testWidgets('payment history exposes deposit breakdown', (tester) async {
    final store = AppDataStore(currentUser: null);
    final now = DateTime.now();
    final sale = Sale(
      id: 'sale-with-deposit',
      salonId: 'salon-001',
      clientId: 'client-001',
      items: [
        SaleItem(
          referenceId: 'pkg-relax-02',
          referenceType: SaleReferenceType.package,
          description: 'Pacchetto Relax',
          quantity: 1,
          unitPrice: 200,
          deposits: [
            PackageDeposit(
              id: 'dep-1',
              amount: 80,
              date: now.subtract(const Duration(days: 5)),
              note: 'Primo acconto',
              paymentMethod: PaymentMethod.cash,
            ),
            PackageDeposit(
              id: 'dep-2',
              amount: 40,
              date: now.subtract(const Duration(days: 2)),
              note: 'Secondo acconto',
              paymentMethod: PaymentMethod.pos,
            ),
          ],
          packagePaymentStatus: PackagePaymentStatus.deposit,
        ),
      ],
      total: 200,
      createdAt: now,
      paymentStatus: SalePaymentStatus.deposit,
      paidAmount: 120,
    );

    await store.upsertSale(sale);
    expect(store.state.sales.any((s) => s.id == sale.id), isTrue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataProvider.overrideWith((ref) => store),
        ],
        child: const MaterialApp(
          home: ClientDetailPage(clientId: 'client-001'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Fatturazione'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Storico pagamenti'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Pacchetto Relax'), findsWidgets);

    final tileFinder =
        find.byKey(const ValueKey('payment-history-tile-sale-with-deposit'));
    expect(tileFinder, findsOneWidget);
    await tester.ensureVisible(tileFinder);
    await tester.pumpAndSettle();

    await tester.tap(tileFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('Primo acconto'), findsOneWidget);
    expect(find.textContaining('Secondo acconto'), findsOneWidget);
    expect(find.textContaining('Pacchetto Relax'), findsWidgets);
  });

  testWidgets('package deposit appears in history without restart', (tester) async {
    final store = AppDataStore(currentUser: null);
    final sale = Sale(
      id: 'sale-package-outstanding',
      salonId: 'salon-001',
      clientId: 'client-001',
      items: [
        SaleItem(
          referenceId: 'pkg-relax-01',
          referenceType: SaleReferenceType.package,
          description: 'Percorso Relax Trimestrale',
          quantity: 1,
          unitPrice: 240,
          packagePaymentStatus: PackagePaymentStatus.deposit,
        ),
      ],
      total: 240,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      paymentMethod: PaymentMethod.pos,
      paymentStatus: SalePaymentStatus.deposit,
      paidAmount: 0,
    );

    await store.upsertSale(sale);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataProvider.overrideWith((ref) => store),
        ],
        child: const MaterialApp(
          home: ClientDetailPage(clientId: 'client-001'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Fatturazione'));
    await tester.pumpAndSettle();

    final outstandingPackageTile = find.text('Percorso Relax Trimestrale');
    expect(outstandingPackageTile, findsWidgets);
    await tester.tap(outstandingPackageTile.first);
    await tester.pumpAndSettle();

    final amountField = find.byType(TextFormField);
    expect(amountField, findsOneWidget);
    await tester.enterText(amountField, '100');
    await tester.pump();
    await tester.tap(find.text('Registra'));
    await tester.pumpAndSettle();

    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    expect(
      find.text('Acconto versato: ${currency.format(100)}'),
      findsOneWidget,
    );

    // Registra un secondo acconto da 40€.
    await tester.tap(outstandingPackageTile.first);
    await tester.pumpAndSettle();

    final secondAmountField = find.byType(TextFormField);
    await tester.enterText(secondAmountField, '40');
    await tester.pump();
    await tester.tap(find.text('Registra'));
    await tester.pumpAndSettle();

    expect(
      find.text('Acconto versato: ${currency.format(140)}'),
      findsOneWidget,
    );

    await tester.dragUntilVisible(
      find.text('Storico pagamenti'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    final historyTileFinder =
        find.byKey(const ValueKey('payment-history-tile-sale-package-outstanding'));
    expect(historyTileFinder, findsOneWidget);

    await tester.tap(historyTileFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('Acconto registrato'), findsWidgets);
  });

  testWidgets('legacy package deposit stays cumulative in outstanding view', (tester) async {
    final store = AppDataStore(currentUser: null);
    final legacyDate = DateTime.now().subtract(const Duration(days: 2));
    final sale = Sale(
      id: 'legacy-package-sale',
      salonId: 'salon-001',
      clientId: 'client-001',
      items: [
        SaleItem(
          referenceId: 'pkg-legacy',
          referenceType: SaleReferenceType.package,
          description: 'Pacchetto Legacy',
          quantity: 1,
          unitPrice: 200,
          depositAmount: 50,
          packagePaymentStatus: PackagePaymentStatus.deposit,
        ),
      ],
      total: 200,
      createdAt: legacyDate,
      paymentMethod: PaymentMethod.pos,
      paymentStatus: SalePaymentStatus.deposit,
      paidAmount: 50,
      paymentHistory: const [],
    );

    await store.upsertSale(sale);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataProvider.overrideWith((ref) => store),
        ],
        child: const MaterialApp(
          home: ClientDetailPage(clientId: 'client-001'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Fatturazione'));
    await tester.pumpAndSettle();

    final currency = NumberFormat.simpleCurrency(locale: 'it_IT');
    expect(
      find.text('Acconto versato: ${currency.format(50)}'),
      findsOneWidget,
    );

    final outstandingPackageTile = find.text('Pacchetto Legacy');
    expect(outstandingPackageTile, findsWidgets);
    await tester.tap(outstandingPackageTile.first);
    await tester.pumpAndSettle();

    final amountField = find.byType(TextFormField);
    await tester.enterText(amountField, '20');
    await tester.pump();
    await tester.tap(find.text('Registra'));
    await tester.pumpAndSettle();

    expect(
      find.text('Acconto versato: ${currency.format(70)}'),
      findsOneWidget,
    );
  });

  testWidgets('service deposit movements are tracked in history', (tester) async {
    const currentUser = AppUser(
      uid: 'admin-test',
      role: UserRole.admin,
      salonIds: ['salon-001'],
      displayName: 'Admin Test',
      availableRoles: [UserRole.admin],
    );
    final store = AppDataStore(currentUser: currentUser);
    final initialDate = DateTime.now().subtract(const Duration(days: 1));
    final sale = Sale(
      id: 'sale-history-tracking',
      salonId: 'salon-001',
      clientId: 'client-001',
      items: [
        SaleItem(
          referenceId: 'srv-test',
          referenceType: SaleReferenceType.service,
          description: 'Massaggio relax',
          quantity: 1,
          unitPrice: 200,
        ),
      ],
      total: 200,
      createdAt: initialDate,
      paymentMethod: PaymentMethod.pos,
      paymentStatus: SalePaymentStatus.deposit,
      paidAmount: 50,
    );

    await store.upsertSale(sale);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDataProvider.overrideWith((ref) => store),
        ],
        child: const MaterialApp(
          home: ClientDetailPage(clientId: 'client-001'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Fatturazione'));
    await tester.pumpAndSettle();

    final historyTileFinder =
        find.byKey(const ValueKey('payment-history-tile-sale-history-tracking'));

    await tester.tap(find.textContaining('Massaggio relax').first);
    await tester.pumpAndSettle();
    expect(find.text('Registra incasso'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '150');
    await tester.tap(find.text('Registra'));
    await tester.pumpAndSettle();

    final updatedSale =
        store.state.sales.firstWhere((element) => element.id == sale.id);
    expect(updatedSale.paymentHistory.length, 2);
    expect(updatedSale.paymentHistory.last.amount, 150);
    expect(updatedSale.paymentHistory.last.type, SalePaymentType.settlement);
    expect(updatedSale.paymentHistory.last.recordedBy, 'Admin Test');
    expect(updatedSale.paymentStatus, SalePaymentStatus.paid);
    expect(updatedSale.outstandingAmount, 0);

    await tester.dragUntilVisible(
      find.text('Storico pagamenti'),
      find.byType(Scrollable).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(historyTileFinder);
    expect(historyTileFinder, findsOneWidget);
    await tester.tap(historyTileFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('Acconto iniziale'), findsOneWidget);
    expect(find.textContaining('Saldo registrato'), findsOneWidget);
    expect(find.textContaining('Operatore: Admin Test'), findsWidgets);
  });
}
