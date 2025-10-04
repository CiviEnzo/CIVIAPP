class ReminderSettings {
  const ReminderSettings({
    required this.salonId,
    this.dayBeforeEnabled = true,
    this.threeHoursEnabled = true,
    this.oneHourEnabled = true,
    this.birthdayEnabled = true,
    this.updatedAt,
    this.updatedBy,
  });

  final String salonId;
  final bool dayBeforeEnabled;
  final bool threeHoursEnabled;
  final bool oneHourEnabled;
  final bool birthdayEnabled;
  final DateTime? updatedAt;
  final String? updatedBy;

  ReminderSettings copyWith({
    String? salonId,
    bool? dayBeforeEnabled,
    bool? threeHoursEnabled,
    bool? oneHourEnabled,
    bool? birthdayEnabled,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return ReminderSettings(
      salonId: salonId ?? this.salonId,
      dayBeforeEnabled: dayBeforeEnabled ?? this.dayBeforeEnabled,
      threeHoursEnabled: threeHoursEnabled ?? this.threeHoursEnabled,
      oneHourEnabled: oneHourEnabled ?? this.oneHourEnabled,
      birthdayEnabled: birthdayEnabled ?? this.birthdayEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
