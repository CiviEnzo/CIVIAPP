class Service {
  const Service({
    required this.id,
    required this.salonId,
    required this.name,
    required this.category,
    required this.duration,
    required this.price,
    this.description,
    this.staffRoles = const [],
    this.requiredEquipmentIds = const [],
    this.extraDuration = Duration.zero,
  });

  final String id;
  final String salonId;
  final String name;
  final String category;
  final Duration duration;
  final double price;
  final String? description;
  final List<String> staffRoles;
  final List<String> requiredEquipmentIds;
  final Duration extraDuration;

  Service copyWith({
    String? id,
    String? salonId,
    String? name,
    String? category,
    Duration? duration,
    double? price,
    String? description,
    List<String>? staffRoles,
    List<String>? requiredEquipmentIds,
    Duration? extraDuration,
  }) {
    return Service(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      name: name ?? this.name,
      category: category ?? this.category,
      duration: duration ?? this.duration,
      price: price ?? this.price,
      description: description ?? this.description,
      staffRoles: staffRoles ?? this.staffRoles,
      requiredEquipmentIds: requiredEquipmentIds ?? this.requiredEquipmentIds,
      extraDuration: extraDuration ?? this.extraDuration,
    );
  }
}

extension ServiceX on Service {
  Duration get totalDuration => duration + extraDuration;
}
