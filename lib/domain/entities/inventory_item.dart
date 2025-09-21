class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.salonId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    this.threshold = 0,
    this.cost = 0,
    this.sellingPrice = 0,
    this.updatedAt,
  });

  final String id;
  final String salonId;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final double threshold;
  final double cost;
  final double sellingPrice;
  final DateTime? updatedAt;
}
