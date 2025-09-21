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
}
