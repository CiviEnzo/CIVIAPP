import 'package:civiapp/domain/entities/loyalty_settings.dart';
import 'package:civiapp/domain/loyalty/loyalty_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseSettings = LoyaltySettings(
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
    initialBalance: 0,
  );

  group('LoyaltyCalculator.compute', () {
    test('earns points when no redemption occurs', () {
      final quote = LoyaltyCalculator.compute(
        settings: baseSettings,
        subtotal: 120,
        manualDiscount: 0,
        availablePoints: 0,
        selectedRedeemPoints: 0,
      );

      expect(quote.eligibleAmount, 120);
      expect(quote.summary.redeemedPoints, 0);
      expect(quote.summary.earnedPoints, 12);
      expect(quote.summary.netPoints, 12);
      expect(quote.maxRedeemablePoints, 0);
    });

    test('clamps redemption to 30 percent of eligible amount', () {
      final quote = LoyaltyCalculator.compute(
        settings: baseSettings,
        subtotal: 100,
        manualDiscount: 0,
        availablePoints: 80,
        selectedRedeemPoints: 80,
      );

      expect(quote.maxRedeemablePoints, 30);
      expect(quote.summary.redeemedPoints, 30);
      expect(quote.summary.earnedPoints, 7);
      expect(quote.summary.netPoints, -23);
    });

    test('honours manual discounts before calculating earnings', () {
      final quote = LoyaltyCalculator.compute(
        settings: baseSettings,
        subtotal: 200,
        manualDiscount: 50,
        availablePoints: 100,
        selectedRedeemPoints: 0,
      );

      expect(quote.eligibleAmount, 150);
      expect(quote.summary.earnedPoints, 15);
      expect(quote.summary.redeemedPoints, 0);
    });

    test('rounding mode ceil allocates extra point', () {
      const customSettings = LoyaltySettings(
        enabled: true,
        earning: LoyaltyEarningRules(
          euroPerPoint: 12,
          rounding: LoyaltyRoundingMode.ceil,
        ),
        redemption: LoyaltyRedemptionRules(
          pointValueEuro: 1,
          maxPercent: 0.5,
          autoSuggest: false,
        ),
      );

      final quote = LoyaltyCalculator.compute(
        settings: customSettings,
        subtotal: 25,
        manualDiscount: 0,
        availablePoints: 0,
        selectedRedeemPoints: 0,
      );

      expect(quote.summary.earnedPoints, 3); // ceil(25 / 12)
    });
  });
}
