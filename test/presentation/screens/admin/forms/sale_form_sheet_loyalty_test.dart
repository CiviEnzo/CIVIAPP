import 'package:you_book/domain/entities/client.dart';
import 'package:you_book/domain/entities/loyalty_settings.dart';
import 'package:you_book/domain/entities/sale.dart';
import 'package:you_book/domain/entities/salon.dart';
import 'package:you_book/presentation/screens/admin/forms/sale_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'SaleFormSheet auto-suggests loyalty redemption and returns summary',
    (tester) async {
      Sale? capturedSale;

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

      final initialItem = SaleItem(
        referenceId: 'manual-1',
        referenceType: SaleReferenceType.product,
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
                                  staff: const [],
                                  services: const [],
                                  packages: const [],
                                  inventoryItems: const [],
                                  sales: const [],
                                  initialItems: [initialItem],
                                  initialClientId: client.id,
                                  defaultSalonId: salon.id,
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

      final loyaltyField = tester.widget<TextFormField>(
        find.byKey(saleFormLoyaltyRedeemFieldKey),
      );
      expect(loyaltyField.controller?.text, '30');

      await tester.tap(find.text('Salva'));
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
}
