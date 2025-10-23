class AppointmentServiceAllocation {
  const AppointmentServiceAllocation({
    required this.serviceId,
    this.quantity = 1,
    this.packageConsumptions = const <AppointmentPackageConsumption>[],
  }) : assert(quantity >= 0, 'quantity must be non-negative');

  final String serviceId;
  final int quantity;
  final List<AppointmentPackageConsumption> packageConsumptions;

  AppointmentServiceAllocation copyWith({
    String? serviceId,
    int? quantity,
    List<AppointmentPackageConsumption>? packageConsumptions,
  }) {
    return AppointmentServiceAllocation(
      serviceId: serviceId ?? this.serviceId,
      quantity: quantity ?? this.quantity,
      packageConsumptions: packageConsumptions ?? this.packageConsumptions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serviceId': serviceId,
      'quantity': quantity,
      if (packageConsumptions.isNotEmpty)
        'packageConsumptions':
            packageConsumptions
                .map((consumption) => consumption.toMap())
                .toList(),
    };
  }

  static AppointmentServiceAllocation fromMap(Map<String, dynamic> map) {
    final serviceId = map['serviceId'] as String? ?? '';
    final quantity = (map['quantity'] as num?)?.toInt() ?? 1;
    final consumptionsRaw =
        map['packageConsumptions'] as List<dynamic>? ?? const [];
    final consumptions = consumptionsRaw
        .whereType<Map<String, dynamic>>()
        .map(AppointmentPackageConsumption.fromMap)
        .toList(growable: false);
    return AppointmentServiceAllocation(
      serviceId: serviceId,
      quantity: quantity,
      packageConsumptions: consumptions,
    );
  }
}

class AppointmentPackageConsumption {
  const AppointmentPackageConsumption({
    required this.packageReferenceId,
    this.sessionTypeId,
    this.quantity = 1,
  }) : assert(quantity >= 0, 'quantity must be non-negative');

  final String packageReferenceId;
  final String? sessionTypeId;
  final int quantity;

  AppointmentPackageConsumption copyWith({
    String? packageReferenceId,
    String? sessionTypeId,
    int? quantity,
  }) {
    return AppointmentPackageConsumption(
      packageReferenceId: packageReferenceId ?? this.packageReferenceId,
      sessionTypeId: sessionTypeId ?? this.sessionTypeId,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageReferenceId': packageReferenceId,
      'sessionTypeId': sessionTypeId,
      'quantity': quantity,
    }..removeWhere((_, value) => value == null);
  }

  static AppointmentPackageConsumption fromMap(Map<String, dynamic> map) {
    final packageReferenceId = map['packageReferenceId'] as String? ?? '';
    final sessionTypeId = map['sessionTypeId'] as String?;
    final quantity = (map['quantity'] as num?)?.toInt() ?? 1;
    return AppointmentPackageConsumption(
      packageReferenceId: packageReferenceId,
      sessionTypeId: sessionTypeId,
      quantity: quantity,
    );
  }
}
