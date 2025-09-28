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
  }) : paidAmount = double.parse(
         ((paidAmount ?? total).clamp(0, total)).toStringAsFixed(2),
        ),
       paymentHistory = List.unmodifiable(paymentHistory ?? const []);

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
  }) : deposits =
           deposits == null
               ? const <PackageDeposit>[]
               : List.unmodifiable(deposits),
       depositAmount =
           depositAmount ?? _sumDeposits(deposits ?? const <PackageDeposit>[]),
       packageServiceSessions = Map.unmodifiable(
         packageServiceSessions ?? const <String, int>{},
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
  }) {
    final nextDeposits = deposits ?? this.deposits;
    final nextPackageServices =
        packageServiceSessions ?? this.packageServiceSessions;
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

enum SalePaymentStatus { deposit, paid }

extension SalePaymentStatusX on SalePaymentStatus {
  String get label {
    switch (this) {
      case SalePaymentStatus.deposit:
        return 'Acconto';
      case SalePaymentStatus.paid:
        return 'Saldato';
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
          recordedBy == _unset
              ? this.recordedBy
              : recordedBy as String?,
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

enum PaymentMethod { cash, pos, transfer, giftCard }
