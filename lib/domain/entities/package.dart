class ServicePackage {
  const ServicePackage({
    required this.id,
    required this.salonId,
    required this.name,
    required this.price,
    required this.fullPrice,
    this.discountPercentage,
    this.description,
    this.serviceIds = const [],
    this.sessionCount,
    this.validDays,
    this.serviceSessionCounts = const {},
  });

  final String id;
  final String salonId;
  final String name;
  final double price;
  final double fullPrice;
  final double? discountPercentage;
  final String? description;
  final List<String> serviceIds;
  final int? sessionCount;
  final int? validDays;
  final Map<String, int> serviceSessionCounts;

  int? get totalConfiguredSessions {
    if (serviceSessionCounts.isEmpty) {
      return sessionCount;
    }
    return serviceSessionCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
  }
}
