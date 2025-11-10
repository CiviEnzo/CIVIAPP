class Sale {
  Sale({
    required this.id,
    required this.salonId,
    required this.clientId,
    required this.items,
    required this.total,
    required this.createdAt,
    this.paymentMethod = PaymentMethod.pos,
    this.paymentStatus = SalePaymentStatus.paid,
    double? paidAmount,
    this.invoiceNumber,
    this.notes,
    this.discountAmount = 0,
    this.staffId,
    List<SalePaymentMovement>? paymentHistory,
    SaleLoyaltySummary? loyalty,
    Map<String, dynamic>? metadata,
  }) : paidAmount = double.parse(
         ((paidAmount ?? total).clamp(0, total)).toStringAsFixed(2),
       ),
       paymentHistory = List.unmodifiable(paymentHistory ?? const []),
       loyalty = loyalty ?? SaleLoyaltySummary(),
       metadata = Map.unmodifiable(metadata ?? const <String, dynamic>{});

  final String id;
  final String salonId;
  final String clientId;
  final List<SaleItem> items;
  final double total;
  final DateTime createdAt;
  final PaymentMethod paymentMethod;
  final SalePaymentStatus paymentStatus;
  final double paidAmount;
  final String? invoiceNumber;
  final String? notes;
  final double discountAmount;
  final String? staffId;
  final List<SalePaymentMovement> paymentHistory;
  final SaleLoyaltySummary loyalty;
  final Map<String, dynamic> metadata;

  String? get source {
    final value = metadata['source'];
    return value is String && value.isNotEmpty ? value : null;
  }

  double get subtotal {
    return items.fold<double>(0, (sum, item) => sum + item.amount);
  }

  double get outstandingAmount {
    final remaining = total - paidAmount;
    if (remaining <= 0) {
      return 0;
    }
    return double.parse(remaining.toStringAsFixed(2));
  }

  Sale copyWith({
    String? id,
    String? salonId,
    String? clientId,
    List<SaleItem>? items,
    double? total,
    DateTime? createdAt,
    PaymentMethod? paymentMethod,
    SalePaymentStatus? paymentStatus,
    double? paidAmount,
    String? invoiceNumber,
    String? notes,
    double? discountAmount,
    Object? staffId = _unset,
    List<SalePaymentMovement>? paymentHistory,
    SaleLoyaltySummary? loyalty,
    Map<String, dynamic>? metadata,
  }) {
    return Sale(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      clientId: clientId ?? this.clientId,
      items: items ?? this.items,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAmount: paidAmount ?? this.paidAmount,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      notes: notes ?? this.notes,
      discountAmount: discountAmount ?? this.discountAmount,
      staffId: staffId == _unset ? this.staffId : staffId as String?,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      loyalty: loyalty ?? this.loyalty,
      metadata: metadata ?? this.metadata,
    );
  }
}

class SaleLoyaltySummary {
  SaleLoyaltySummary({
    this.redeemedPoints = 0,
    this.redeemedValue = 0,
    this.eligibleAmount = 0,
    this.requestedEarnPoints = 0,
    this.requestedEarnValue = 0,
    List<String>? processedMovementIds,
    this.earnedPoints = 0,
    this.earnedValue = 0,
    this.netPoints = 0,
    this.computedAt,
    this.version = 1,
  }) : processedMovementIds =
           processedMovementIds == null
               ? const <String>[]
               : List.unmodifiable(processedMovementIds);

  final int redeemedPoints;
  final double redeemedValue;
  final double eligibleAmount;
  final int requestedEarnPoints;
  final double requestedEarnValue;
  final List<String> processedMovementIds;
  final int earnedPoints;
  final double earnedValue;
  final int netPoints;
  final DateTime? computedAt;
  final int version;

  bool get hasRedemption => redeemedPoints > 0 && redeemedValue > 0;

  int get resolvedEarnedPoints {
    if (earnedPoints != 0) {
      return earnedPoints;
    }
    if (requestedEarnPoints != 0) {
      return requestedEarnPoints;
    }
    if (netPoints != 0) {
      return netPoints + redeemedPoints;
    }
    return 0;
  }

  SaleLoyaltySummary copyWith({
    int? redeemedPoints,
    double? redeemedValue,
    double? eligibleAmount,
    int? requestedEarnPoints,
    double? requestedEarnValue,
    List<String>? processedMovementIds,
    int? earnedPoints,
    double? earnedValue,
    int? netPoints,
    Object? computedAt = _unset,
    int? version,
  }) {
    return SaleLoyaltySummary(
      redeemedPoints: redeemedPoints ?? this.redeemedPoints,
      redeemedValue: redeemedValue ?? this.redeemedValue,
      eligibleAmount: eligibleAmount ?? this.eligibleAmount,
      requestedEarnPoints: requestedEarnPoints ?? this.requestedEarnPoints,
      requestedEarnValue: requestedEarnValue ?? this.requestedEarnValue,
      processedMovementIds: processedMovementIds ?? this.processedMovementIds,
      earnedPoints: earnedPoints ?? this.earnedPoints,
      earnedValue: earnedValue ?? this.earnedValue,
      netPoints: netPoints ?? this.netPoints,
      computedAt:
          computedAt == _unset ? this.computedAt : computedAt as DateTime?,
      version: version ?? this.version,
    );
  }
}

class SaleItem {
  SaleItem({
    required this.referenceId,
    required this.referenceType,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.expirationDate,
    this.totalSessions,
    this.remainingSessions,
    this.packageStatus,
    this.packagePaymentStatus,
    double? depositAmount,
    List<PackageDeposit>? deposits,
    Map<String, int>? packageServiceSessions,
    Map<String, int>? remainingPackageServiceSessions,
  }) : deposits =
           deposits == null
               ? const <PackageDeposit>[]
               : List.unmodifiable(deposits),
       depositAmount =
           depositAmount ?? _sumDeposits(deposits ?? const <PackageDeposit>[]),
       packageServiceSessions = Map.unmodifiable(
         packageServiceSessions ?? const <String, int>{},
       ),
       remainingPackageServiceSessions = Map.unmodifiable(
         remainingPackageServiceSessions ?? const <String, int>{},
       );

  final String referenceId;
  final SaleReferenceType referenceType;
  final String description;
  final double quantity;
  final double unitPrice;
  final DateTime? expirationDate;
  final int? totalSessions;
  final int? remainingSessions;
  final PackagePurchaseStatus? packageStatus;
  final PackagePaymentStatus? packagePaymentStatus;
  final double depositAmount;
  final List<PackageDeposit> deposits;
  final Map<String, int> packageServiceSessions;
  final Map<String, int> remainingPackageServiceSessions;

  double get amount => quantity * unitPrice;

  SaleItem copyWith({
    String? referenceId,
    SaleReferenceType? referenceType,
    String? description,
    double? quantity,
    double? unitPrice,
    Object? expirationDate = _unset,
    Object? totalSessions = _unset,
    Object? remainingSessions = _unset,
    Object? packageStatus = _unset,
    Object? packagePaymentStatus = _unset,
    Object? depositAmount = _unset,
    List<PackageDeposit>? deposits,
    Map<String, int>? packageServiceSessions,
    Map<String, int>? remainingPackageServiceSessions,
  }) {
    final nextDeposits = deposits ?? this.deposits;
    final nextPackageServices =
        packageServiceSessions ?? this.packageServiceSessions;
    final nextRemainingServices =
        remainingPackageServiceSessions ??
        this.remainingPackageServiceSessions;
    return SaleItem(
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      expirationDate:
          expirationDate == _unset
              ? this.expirationDate
              : expirationDate as DateTime?,
      totalSessions:
          totalSessions == _unset ? this.totalSessions : totalSessions as int?,
      remainingSessions:
          remainingSessions == _unset
              ? this.remainingSessions
              : remainingSessions as int?,
      packageStatus:
          packageStatus == _unset
              ? this.packageStatus
              : packageStatus as PackagePurchaseStatus?,
      packagePaymentStatus:
          packagePaymentStatus == _unset
              ? this.packagePaymentStatus
              : packagePaymentStatus as PackagePaymentStatus?,
      depositAmount:
          depositAmount == _unset
              ? _sumDeposits(nextDeposits)
              : depositAmount as double,
      deposits: nextDeposits,
      packageServiceSessions: nextPackageServices,
      remainingPackageServiceSessions: nextRemainingServices,
    );
  }
}

const Object _unset = Object();

enum PackagePurchaseStatus { active, completed, cancelled }

extension PackagePurchaseStatusX on PackagePurchaseStatus {
  String get label {
    switch (this) {
      case PackagePurchaseStatus.active:
        return 'Attivo';
      case PackagePurchaseStatus.completed:
        return 'Completato';
      case PackagePurchaseStatus.cancelled:
        return 'Annullato';
    }
  }
}

enum PackagePaymentStatus { deposit, paid }

extension PackagePaymentStatusX on PackagePaymentStatus {
  String get label {
    switch (this) {
      case PackagePaymentStatus.deposit:
        return 'Acconto';
      case PackagePaymentStatus.paid:
        return 'Saldato';
    }
  }
}

enum SalePaymentStatus { deposit, paid, posticipated }

extension SalePaymentStatusX on SalePaymentStatus {
  String get label {
    switch (this) {
      case SalePaymentStatus.deposit:
        return 'Acconto';
      case SalePaymentStatus.paid:
        return 'Saldato';
      case SalePaymentStatus.posticipated:
        return 'Posticipato';
    }
  }
}

class PackageDeposit {
  const PackageDeposit({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
    this.paymentMethod = PaymentMethod.pos,
  });

  final String id;
  final double amount;
  final DateTime date;
  final String? note;
  final PaymentMethod paymentMethod;

  PackageDeposit copyWith({
    String? id,
    double? amount,
    DateTime? date,
    String? note,
    PaymentMethod? paymentMethod,
  }) {
    return PackageDeposit(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

double _sumDeposits(List<PackageDeposit> deposits) {
  return deposits.fold<double>(0, (sum, entry) => sum + entry.amount);
}

class SalePaymentMovement {
  const SalePaymentMovement({
    required this.id,
    required this.amount,
    required this.type,
    required this.date,
    required this.paymentMethod,
    this.recordedBy,
    this.note,
  });

  final String id;
  final double amount;
  final SalePaymentType type;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final String? recordedBy;
  final String? note;

  SalePaymentMovement copyWith({
    String? id,
    double? amount,
    SalePaymentType? type,
    DateTime? date,
    PaymentMethod? paymentMethod,
    Object? recordedBy = _unset,
    Object? note = _unset,
  }) {
    return SalePaymentMovement(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      recordedBy:
          recordedBy == _unset ? this.recordedBy : recordedBy as String?,
      note: note == _unset ? this.note : note as String?,
    );
  }
}

enum SalePaymentType { deposit, settlement }

extension SalePaymentTypeX on SalePaymentType {
  String get label {
    switch (this) {
      case SalePaymentType.deposit:
        return 'Acconto';
      case SalePaymentType.settlement:
        return 'Saldo';
    }
  }
}

enum SaleReferenceType { service, package, product }

enum PaymentMethod { cash, pos, transfer, giftCard, posticipated }
