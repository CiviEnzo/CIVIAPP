enum LastMinutePaymentMode { online, onSite }

extension LastMinutePaymentModeDisplay on LastMinutePaymentMode {
  String get label {
    switch (this) {
      case LastMinutePaymentMode.online:
        return 'Pagamento online';
      case LastMinutePaymentMode.onSite:
        return 'Paga in sede';
    }
  }

  bool get requiresImmediatePayment => this == LastMinutePaymentMode.online;
}

LastMinutePaymentMode lastMinutePaymentModeFromName(String? value) {
  if (value == null || value.isEmpty) {
    return LastMinutePaymentMode.online;
  }
  return LastMinutePaymentMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => LastMinutePaymentMode.online,
  );
}

class LastMinuteSlot {
  static const Object _undefined = Object();

  const LastMinuteSlot({
    required this.id,
    required this.salonId,
    this.serviceId,
    required this.serviceName,
    this.imageUrl,
    this.imageStoragePath,
    required this.start,
    required this.duration,
    required this.basePrice,
    required this.discountPercentage,
    required this.priceNow,
    this.roomId,
    this.roomName,
    this.operatorId,
    this.operatorName,
    this.availableSeats = 1,
    this.loyaltyPoints = 0,
    this.createdAt,
    this.updatedAt,
    this.windowStart,
    this.windowEnd,
    this.bookedClientId,
    this.bookedClientName,
    this.paymentMode = LastMinutePaymentMode.online,
  });

  static const Duration _defaultWindowLead = Duration(minutes: 60);

  final String id;
  final String salonId;
  final String? serviceId;
  final String serviceName;
  final String? imageUrl;
  final String? imageStoragePath;
  final DateTime start;
  final Duration duration;
  final double basePrice;
  final double discountPercentage;
  final double priceNow;
  final String? roomId;
  final String? roomName;
  final String? operatorId;
  final String? operatorName;
  final int availableSeats;
  final int loyaltyPoints;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final String? bookedClientId;
  final String? bookedClientName;
  final LastMinutePaymentMode paymentMode;

  DateTime get end => start.add(duration);

  DateTime get effectiveWindowStart =>
      windowStart ?? start.subtract(_defaultWindowLead);

  DateTime get effectiveWindowEnd => windowEnd ?? start;

  bool get isAvailable => availableSeats > 0;

  bool get isBooked => !isAvailable && bookedClientId != null;

  bool get requiresImmediatePayment => paymentMode.requiresImmediatePayment;

  LastMinuteSlot copyWith({
    String? id,
    String? salonId,
    String? serviceId,
    String? serviceName,
    Object? imageUrl = _undefined,
    Object? imageStoragePath = _undefined,
    DateTime? start,
    Duration? duration,
    double? basePrice,
    double? discountPercentage,
    double? priceNow,
    String? roomId,
    String? roomName,
    String? operatorId,
    String? operatorName,
    int? availableSeats,
    int? loyaltyPoints,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? windowStart,
    DateTime? windowEnd,
    Object? bookedClientId = _undefined,
    Object? bookedClientName = _undefined,
    LastMinutePaymentMode? paymentMode,
  }) {
    return LastMinuteSlot(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      imageUrl:
          identical(imageUrl, _undefined)
              ? this.imageUrl
              : imageUrl as String?,
      imageStoragePath:
          identical(imageStoragePath, _undefined)
              ? this.imageStoragePath
              : imageStoragePath as String?,
      start: start ?? this.start,
      duration: duration ?? this.duration,
      basePrice: basePrice ?? this.basePrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      priceNow: priceNow ?? this.priceNow,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      operatorId: operatorId ?? this.operatorId,
      operatorName: operatorName ?? this.operatorName,
      availableSeats: availableSeats ?? this.availableSeats,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      windowStart: windowStart ?? this.windowStart,
      windowEnd: windowEnd ?? this.windowEnd,
      bookedClientId:
          identical(bookedClientId, _undefined)
              ? this.bookedClientId
              : bookedClientId as String?,
      bookedClientName:
          identical(bookedClientName, _undefined)
              ? this.bookedClientName
              : bookedClientName as String?,
      paymentMode: paymentMode ?? this.paymentMode,
    );
  }

  bool isActiveAt(DateTime moment) {
    final windowStart = effectiveWindowStart;
    final windowEnd = effectiveWindowEnd;
    if (moment.isBefore(windowStart)) {
      return false;
    }
    if (moment.isAfter(windowEnd)) {
      return false;
    }
    if (!isAvailable) {
      return false;
    }
    return moment.isBefore(end);
  }
}
