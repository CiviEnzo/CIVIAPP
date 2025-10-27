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
    this.showOnClientDashboard = true,
    this.isGeneratedFromServiceBuilder = false,
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
  final bool showOnClientDashboard;
  final bool isGeneratedFromServiceBuilder;

  int? get totalConfiguredSessions {
    if (serviceSessionCounts.isEmpty) {
      return sessionCount;
    }
    return serviceSessionCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
  }

  ServicePackage copyWith({
    String? id,
    String? salonId,
    String? name,
    double? price,
    double? fullPrice,
    double? discountPercentage,
    Object? description = _sentinel,
    List<String>? serviceIds,
    int? sessionCount,
    int? validDays,
    Map<String, int>? serviceSessionCounts,
    bool? showOnClientDashboard,
    bool? isGeneratedFromServiceBuilder,
  }) {
    return ServicePackage(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      name: name ?? this.name,
      price: price ?? this.price,
      fullPrice: fullPrice ?? this.fullPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      description:
          identical(description, _sentinel)
              ? this.description
              : description as String?,
      serviceIds: serviceIds ?? this.serviceIds,
      sessionCount: sessionCount ?? this.sessionCount,
      validDays: validDays ?? this.validDays,
      serviceSessionCounts:
          serviceSessionCounts ??
          Map<String, int>.from(this.serviceSessionCounts),
      showOnClientDashboard:
          showOnClientDashboard ?? this.showOnClientDashboard,
      isGeneratedFromServiceBuilder:
          isGeneratedFromServiceBuilder ?? this.isGeneratedFromServiceBuilder,
    );
  }
}

const Object _sentinel = Object();
