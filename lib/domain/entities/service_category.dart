class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.salonId,
    required this.name,
    this.description,
    this.sortOrder = 0,
    this.color,
  });

  final String id;
  final String salonId;
  final String name;
  final String? description;
  final int sortOrder;
  final int? color;

  ServiceCategory copyWith({
    String? id,
    String? salonId,
    String? name,
    String? description,
    int? sortOrder,
    int? color,
  }) {
    return ServiceCategory(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      name: name ?? this.name,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      color: color ?? this.color,
    );
  }
}

extension ServiceCategoryListX on Iterable<ServiceCategory> {
  List<ServiceCategory> sortedByDisplayOrder() {
    return toList()..sort((a, b) {
      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }
}
