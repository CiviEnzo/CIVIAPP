const String expenseAgendaUserPreferenceKeyPrefix =
    'admin_expenses_show_in_agenda_user';

String expenseAgendaUserPreferenceKey(String? salonId) {
  final normalized = salonId?.trim();
  if (normalized == null || normalized.isEmpty) {
    return expenseAgendaUserPreferenceKeyPrefix;
  }
  return '$expenseAgendaUserPreferenceKeyPrefix::$normalized';
}
