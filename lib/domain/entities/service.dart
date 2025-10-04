class Service {
  const Service({
    required this.id,
    required this.salonId,
    required this.name,
    required this.category,
    this.categoryId,
    required this.duration,
    required this.price,
    this.description,
    this.staffRoles = const [],
    this.requiredEquipmentIds = const [],
    this.extraDuration = Duration.zero,
    this.isActive = true,
  });

  final String id;
  final String salonId;
  final String name;
  final String category;
  final String? categoryId;
  final Duration duration;
  final double price;
  final String? description;
  final List<String> staffRoles;
  final List<String> requiredEquipmentIds;
  final Duration extraDuration;
  final bool isActive;

  Service copyWith({
    String? id,
    String? salonId,
    String? name,
    String? category,
    String? categoryId,
    Duration? duration,
    double? price,
    String? description,
    List<String>? staffRoles,
    List<String>? requiredEquipmentIds,
    Duration? extraDuration,
    bool? isActive,
  }) {
    return Service(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      name: name ?? this.name,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      duration: duration ?? this.duration,
      price: price ?? this.price,
      description: description ?? this.description,
      staffRoles: staffRoles ?? this.staffRoles,
      requiredEquipmentIds: requiredEquipmentIds ?? this.requiredEquipmentIds,
      extraDuration: extraDuration ?? this.extraDuration,
      isActive: isActive ?? this.isActive,
    );
  }
}

extension ServiceX on Service {
  Duration get totalDuration => duration + extraDuration;
}
