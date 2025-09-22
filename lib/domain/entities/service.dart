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
  });

  final String id;
  final String salonId;
  final String name;
  final String category;
  final Duration duration;
  final double price;
  final String? description;
  final List<String> staffRoles;

  Service copyWith({
    String? id,
    String? salonId,
    String? name,
    String? category,
    Duration? duration,
    double? price,
    String? description,
    List<String>? staffRoles,
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
    );
  }
}
