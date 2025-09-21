class Sale {
  const Sale({
    required this.id,
    required this.salonId,
    required this.clientId,
    required this.items,
    required this.total,
    required this.createdAt,
    this.paymentMethod = PaymentMethod.pos,
    this.invoiceNumber,
    this.notes,
  });

  final String id;
  final String salonId;
  final String clientId;
  final List<SaleItem> items;
  final double total;
  final DateTime createdAt;
  final PaymentMethod paymentMethod;
  final String? invoiceNumber;
  final String? notes;

  Sale copyWith({
    String? id,
    String? salonId,
    String? clientId,
    List<SaleItem>? items,
    double? total,
    DateTime? createdAt,
    PaymentMethod? paymentMethod,
    String? invoiceNumber,
    String? notes,
  }) {
    return Sale(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      clientId: clientId ?? this.clientId,
      items: items ?? this.items,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      notes: notes ?? this.notes,
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

enum SaleReferenceType { service, package, product }

enum PaymentMethod { cash, pos, transfer, giftCard }
