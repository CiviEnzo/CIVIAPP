class CashFlowEntry {
  const CashFlowEntry({
    required this.id,
    required this.salonId,
    required this.type,
    required this.amount,
    required this.date,
    this.description,
    this.category,
    this.staffId,
  });

  final String id;
  final String salonId;
  final CashFlowType type;
  final double amount;
  final DateTime date;
  final String? description;
  final String? category;
  final String? staffId;
}

enum CashFlowType {
  income,
  expense,
}
