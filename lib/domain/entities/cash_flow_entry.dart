class CashFlowEntry {
  const CashFlowEntry({
    required this.id,
    required this.salonId,
    required this.type,
    required this.amount,
    required this.date,
    DateTime? createdAt,
    this.description,
    this.category,
    this.staffId,
  }) : createdAt = createdAt ?? date;

  final String id;
  final String salonId;
  final CashFlowType type;
  final double amount;
  final DateTime date;
  final DateTime createdAt;
  final String? description;
  final String? category;
  final String? staffId;
}

enum CashFlowType { income, expense }
