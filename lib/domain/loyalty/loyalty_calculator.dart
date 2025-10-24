import 'package:you_book/domain/entities/loyalty_settings.dart';
import 'package:you_book/domain/entities/sale.dart';

class LoyaltyQuote {
  const LoyaltyQuote({
    required this.summary,
    required this.maxRedeemablePoints,
    required this.maxRedeemableValue,
    required this.eligibleAmount,
  });

  final SaleLoyaltySummary summary;
  final int maxRedeemablePoints;
  final double maxRedeemableValue;
  final double eligibleAmount;
}

class LoyaltyCalculator {
  const LoyaltyCalculator._();

  static LoyaltyQuote compute({
    required LoyaltySettings settings,
    required double subtotal,
    required double manualDiscount,
    required int availablePoints,
    required int selectedRedeemPoints,
  }) {
    if (!settings.enabled || subtotal <= 0) {
      return LoyaltyQuote(
        summary: SaleLoyaltySummary(eligibleAmount: 0),
        maxRedeemablePoints: 0,
        maxRedeemableValue: 0,
        eligibleAmount: 0,
      );
    }

    final sanitizedDiscount = manualDiscount.clamp(0, subtotal);
    final eligibleAmount = _roundCurrency(subtotal - sanitizedDiscount);
    if (eligibleAmount <= 0) {
      return LoyaltyQuote(
        summary: SaleLoyaltySummary(eligibleAmount: eligibleAmount),
        maxRedeemablePoints: 0,
        maxRedeemableValue: 0,
        eligibleAmount: eligibleAmount,
      );
    }

    final pointValue =
        settings.redemption.pointValueEuro <= 0
            ? 1.0
            : settings.redemption.pointValueEuro;
    final maxPercent =
        settings.redemption.maxPercent.clamp(0.0, 1.0).toDouble();
    final rawMaxRedeemableValue = eligibleAmount * maxPercent;
    final maxRedeemableValue = _roundCurrency(
      rawMaxRedeemableValue.clamp(0.0, eligibleAmount).toDouble(),
    );
    final maxPointsByValue =
        maxRedeemableValue <= 0 ? 0 : (maxRedeemableValue / pointValue).floor();
    final maxRedeemablePoints = [
      availablePoints,
      maxPointsByValue,
    ].reduce((a, b) => a < b ? a : b);

    final redeemPoints =
        selectedRedeemPoints < 0
            ? 0
            : selectedRedeemPoints > maxRedeemablePoints
            ? maxRedeemablePoints
            : selectedRedeemPoints;
    final redeemedValue = _roundCurrency(redeemPoints * pointValue);
    final earningBase = _roundCurrency(eligibleAmount - redeemedValue);

    final earningPoints = _applyRounding(
      value:
          earningBase /
          (settings.earning.euroPerPoint <= 0
              ? 10
              : settings.earning.euroPerPoint),
      mode: settings.earning.rounding,
    );
    final earningValue = _roundCurrency(earningPoints * pointValue);

    final summary = SaleLoyaltySummary(
      redeemedPoints: redeemPoints,
      redeemedValue: redeemedValue,
      eligibleAmount: eligibleAmount,
      requestedEarnPoints: earningPoints,
      requestedEarnValue: earningValue,
      earnedPoints: earningPoints,
      earnedValue: earningValue,
      netPoints: earningPoints - redeemPoints,
    );

    return LoyaltyQuote(
      summary: summary,
      maxRedeemablePoints: maxRedeemablePoints,
      maxRedeemableValue: maxRedeemableValue,
      eligibleAmount: eligibleAmount,
    );
  }

  static int _applyRounding({
    required double value,
    required LoyaltyRoundingMode mode,
  }) {
    switch (mode) {
      case LoyaltyRoundingMode.round:
        return value.round();
      case LoyaltyRoundingMode.ceil:
        return value.ceil();
      case LoyaltyRoundingMode.floor:
        return value.floor();
    }
  }

  static double _roundCurrency(double value) {
    if (!value.isFinite) {
      return 0;
    }
    final rounded = double.parse(value.toStringAsFixed(2));
    if (rounded < 0 && rounded > -0.005) {
      return 0;
    }
    return rounded;
  }
}
