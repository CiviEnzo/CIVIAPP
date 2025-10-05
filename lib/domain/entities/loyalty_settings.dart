enum LoyaltyRoundingMode { floor, round, ceil }

class LoyaltyEarningRules {
  const LoyaltyEarningRules({
    this.euroPerPoint = 10,
    this.rounding = LoyaltyRoundingMode.floor,
  });

  final double euroPerPoint;
  final LoyaltyRoundingMode rounding;

  LoyaltyEarningRules copyWith({
    double? euroPerPoint,
    LoyaltyRoundingMode? rounding,
  }) {
    return LoyaltyEarningRules(
      euroPerPoint: euroPerPoint ?? this.euroPerPoint,
      rounding: rounding ?? this.rounding,
    );
  }
}

class LoyaltyRedemptionRules {
  const LoyaltyRedemptionRules({
    this.pointValueEuro = 1,
    this.maxPercent = 0.3,
    this.autoSuggest = true,
  });

  final double pointValueEuro;
  final double maxPercent;
  final bool autoSuggest;

  LoyaltyRedemptionRules copyWith({
    double? pointValueEuro,
    double? maxPercent,
    bool? autoSuggest,
  }) {
    return LoyaltyRedemptionRules(
      pointValueEuro: pointValueEuro ?? this.pointValueEuro,
      maxPercent: maxPercent ?? this.maxPercent,
      autoSuggest: autoSuggest ?? this.autoSuggest,
    );
  }
}

class LoyaltyExpirationRules {
  const LoyaltyExpirationRules({
    this.resetMonth = 1,
    this.resetDay = 1,
    this.timezone = 'Europe/Rome',
  });

  final int resetMonth;
  final int resetDay;
  final String timezone;

  LoyaltyExpirationRules copyWith({
    int? resetMonth,
    int? resetDay,
    String? timezone,
  }) {
    return LoyaltyExpirationRules(
      resetMonth: resetMonth ?? this.resetMonth,
      resetDay: resetDay ?? this.resetDay,
      timezone: timezone ?? this.timezone,
    );
  }
}

class LoyaltySettings {
  const LoyaltySettings({
    this.enabled = false,
    this.earning = const LoyaltyEarningRules(),
    this.redemption = const LoyaltyRedemptionRules(),
    this.expiration = const LoyaltyExpirationRules(),
    this.initialBalance = 0,
    this.updatedAt,
  });

  final bool enabled;
  final LoyaltyEarningRules earning;
  final LoyaltyRedemptionRules redemption;
  final LoyaltyExpirationRules expiration;
  final int initialBalance;
  final DateTime? updatedAt;

  LoyaltySettings copyWith({
    bool? enabled,
    LoyaltyEarningRules? earning,
    LoyaltyRedemptionRules? redemption,
    LoyaltyExpirationRules? expiration,
    int? initialBalance,
    Object? updatedAt = _unset,
  }) {
    return LoyaltySettings(
      enabled: enabled ?? this.enabled,
      earning: earning ?? this.earning,
      redemption: redemption ?? this.redemption,
      expiration: expiration ?? this.expiration,
      initialBalance: initialBalance ?? this.initialBalance,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
    );
  }

  static const LoyaltySettings disabled = LoyaltySettings(enabled: false);
}

const Object _unset = Object();
