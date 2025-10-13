import 'package:cloud_firestore/cloud_firestore.dart';

enum CartItemType { package, service, lastMinute }

extension CartItemTypeX on CartItemType {
  String get label {
    switch (this) {
      case CartItemType.package:
        return 'package';
      case CartItemType.service:
        return 'service';
      case CartItemType.lastMinute:
        return 'lastMinute';
    }
  }

  static CartItemType fromLabel(String label) {
    switch (label) {
      case 'package':
        return CartItemType.package;
      case 'service':
        return CartItemType.service;
      case 'lastMinute':
        return CartItemType.lastMinute;
      default:
        return CartItemType.service;
    }
  }
}

class CartItem {
  const CartItem({
    required this.id,
    required this.referenceId,
    required this.type,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.metadata = const <String, dynamic>{},
  }) : assert(quantity > 0, 'quantity must be positive');

  final String id;
  final String referenceId;
  final CartItemType type;
  final String name;
  final double unitPrice;
  final int quantity;
  final Map<String, dynamic> metadata;

  double get totalAmount => unitPrice * quantity;

  int get totalAmountCents => (totalAmount * 100).round();

  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      'id': id,
      'referenceId': referenceId,
      'type': type.label,
      'name': name,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'totalAmount': totalAmount,
      'totalAmountCents': totalAmountCents,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  CartItem copyWith({
    String? id,
    String? referenceId,
    CartItemType? type,
    String? name,
    double? unitPrice,
    int? quantity,
    Map<String, dynamic>? metadata,
  }) {
    return CartItem(
      id: id ?? this.id,
      referenceId: referenceId ?? this.referenceId,
      type: type ?? this.type,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      metadata: metadata ?? this.metadata,
    );
  }
}

class CartSnapshot {
  CartSnapshot({
    required this.id,
    required this.clientId,
    required this.salonId,
    required this.currency,
    required List<CartItem> items,
    Map<String, dynamic>? metadata,
  }) : items = List<CartItem>.unmodifiable(items),
       metadata = Map<String, dynamic>.unmodifiable(
         metadata ?? const <String, dynamic>{},
       );

  final String id;
  final String clientId;
  final String salonId;
  final String currency;
  final List<CartItem> items;
  final Map<String, dynamic> metadata;

  double get totalAmount =>
      items.fold<double>(0, (sum, item) => sum + item.totalAmount);

  int get totalAmountCents => (totalAmount * 100).round();

  bool get isEmpty => items.isEmpty;

  List<String> get itemReferenceIds =>
      items.map((item) => item.referenceId).toList(growable: false);

  List<String> get itemTypeLabels =>
      items.map((item) => item.type.label).toList(growable: false);

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'cartId': id,
      'clientId': clientId,
      'salonId': salonId,
      'currency': currency.toLowerCase(),
      'items': items
          .map((item) => item.toFirestoreMap())
          .toList(growable: false),
      'totalAmount': totalAmount,
      'totalAmountCents': totalAmountCents,
      'status': 'pending',
      'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, String> toStripeMetadata({bool includeCounts = true}) {
    final meta = <String, String>{
      'cartId': id,
      'salonId': salonId,
      'types': itemTypeLabels.join('|'),
      'refs': itemReferenceIds.join('|'),
    };

    if (includeCounts) {
      meta['itemCount'] = items.length.toString();
    }

    if (metadata.isNotEmpty) {
      final entries = metadata.entries
          .where((entry) => entry.value != null)
          .map((entry) => MapEntry(entry.key, entry.value.toString()))
          .toList(growable: false);
      for (final entry in entries) {
        meta['cart_${entry.key}'] = entry.value;
      }
    }

    final perTypeCounts = items.fold<Map<CartItemType, int>>(
      <CartItemType, int>{},
      (acc, item) {
        acc.update(
          item.type,
          (value) => value + item.quantity,
          ifAbsent: () => item.quantity,
        );
        return acc;
      },
    );

    for (final entry in perTypeCounts.entries) {
      meta['qty_${entry.key.label}'] = entry.value.toString();
    }

    return meta;
  }
}

class CartState {
  const CartState({
    this.items = const <CartItem>[],
    this.isProcessing = false,
    this.lastError,
    this.lastPaymentIntentId,
    this.lastCartId,
  });

  final List<CartItem> items;
  final bool isProcessing;
  final String? lastError;
  final String? lastPaymentIntentId;
  final String? lastCartId;

  bool get isEmpty => items.isEmpty;

  double get totalAmount =>
      items.fold<double>(0, (sum, item) => sum + item.totalAmount);

  int get totalAmountCents => (totalAmount * 100).round();

  CartState copyWith({
    List<CartItem>? items,
    bool? isProcessing,
    String? lastError,
    Object? lastPaymentIntentId = _sentinel,
    Object? lastCartId = _sentinel,
  }) {
    return CartState(
      items: items ?? this.items,
      isProcessing: isProcessing ?? this.isProcessing,
      lastError: lastError,
      lastPaymentIntentId:
          identical(lastPaymentIntentId, _sentinel)
              ? this.lastPaymentIntentId
              : lastPaymentIntentId as String?,
      lastCartId:
          identical(lastCartId, _sentinel)
              ? this.lastCartId
              : lastCartId as String?,
    );
  }

  CartState clearTransient() {
    return CartState(
      items: items,
      isProcessing: false,
      lastError: null,
      lastPaymentIntentId: null,
      lastCartId: null,
    );
  }
}

const Object _sentinel = Object();
