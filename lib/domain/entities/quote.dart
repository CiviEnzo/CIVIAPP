import 'package:civiapp/domain/entities/message_template.dart';

enum QuoteStatus { draft, sent, accepted, declined, expired }

extension QuoteStatusX on QuoteStatus {
  String get label {
    switch (this) {
      case QuoteStatus.draft:
        return 'Bozza';
      case QuoteStatus.sent:
        return 'Inviato';
      case QuoteStatus.accepted:
        return 'Accettato';
      case QuoteStatus.declined:
        return 'Rifiutato';
      case QuoteStatus.expired:
        return 'Scaduto';
    }
  }
}

class Quote {
  Quote({
    required this.id,
    required this.salonId,
    required this.clientId,
    required List<QuoteItem> items,
    required this.createdAt,
    this.number,
    this.title,
    this.notes,
    this.status = QuoteStatus.draft,
    this.updatedAt,
    this.validUntil,
    this.sentAt,
    this.acceptedAt,
    this.declinedAt,
    this.ticketId,
    List<MessageChannel>? sentChannels,
    this.pdfStoragePath,
    this.saleId,
    this.stripePaymentIntentId,
  }) : items = List.unmodifiable(items),
       sentChannels = List.unmodifiable(
         sentChannels ?? const <MessageChannel>[],
       );

  static const Object _unset = Object();

  final String id;
  final String salonId;
  final String clientId;
  final List<QuoteItem> items;
  final DateTime createdAt;
  final String? number;
  final String? title;
  final String? notes;
  final QuoteStatus status;
  final DateTime? updatedAt;
  final DateTime? validUntil;
  final DateTime? sentAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final String? ticketId;
  final List<MessageChannel> sentChannels;
  final String? pdfStoragePath;
  final String? saleId;
  final String? stripePaymentIntentId;

  double get total {
    final rawTotal = items.fold<double>(0, (sum, item) => sum + item.total);
    return double.parse(rawTotal.toStringAsFixed(2));
  }

  bool get isEditable =>
      status == QuoteStatus.draft || status == QuoteStatus.sent;

  bool get isDecisionPending =>
      status == QuoteStatus.sent || status == QuoteStatus.draft;

  bool get hasBeenSent => sentAt != null || status != QuoteStatus.draft;

  bool get isExpired {
    final deadline = validUntil;
    if (deadline == null) {
      return false;
    }
    if (status == QuoteStatus.accepted || status == QuoteStatus.declined) {
      return false;
    }
    return DateTime.now().isAfter(deadline);
  }

  Quote copyWith({
    String? id,
    String? salonId,
    String? clientId,
    List<QuoteItem>? items,
    String? number,
    String? title,
    String? notes,
    QuoteStatus? status,
    DateTime? createdAt,
    Object? updatedAt = _unset,
    Object? validUntil = _unset,
    Object? sentAt = _unset,
    Object? acceptedAt = _unset,
    Object? declinedAt = _unset,
    Object? ticketId = _unset,
    List<MessageChannel>? sentChannels,
    Object? pdfStoragePath = _unset,
    Object? saleId = _unset,
    Object? stripePaymentIntentId = _unset,
  }) {
    return Quote(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      clientId: clientId ?? this.clientId,
      items: items ?? this.items,
      number: number ?? this.number,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
      validUntil:
          validUntil == _unset ? this.validUntil : validUntil as DateTime?,
      sentAt: sentAt == _unset ? this.sentAt : sentAt as DateTime?,
      acceptedAt:
          acceptedAt == _unset ? this.acceptedAt : acceptedAt as DateTime?,
      declinedAt:
          declinedAt == _unset ? this.declinedAt : declinedAt as DateTime?,
      ticketId: ticketId == _unset ? this.ticketId : ticketId as String?,
      sentChannels: sentChannels ?? this.sentChannels,
      pdfStoragePath:
          pdfStoragePath == _unset
              ? this.pdfStoragePath
              : pdfStoragePath as String?,
      saleId: saleId == _unset ? this.saleId : saleId as String?,
      stripePaymentIntentId:
          stripePaymentIntentId == _unset
              ? this.stripePaymentIntentId
              : stripePaymentIntentId as String?,
    );
  }
}

class QuoteItem {
  const QuoteItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.referenceType = QuoteItemReferenceType.manual,
    this.serviceId,
    this.packageId,
    this.inventoryItemId,
  });

  static const Object _unset = Object();

  final String id;
  final String description;
  final double quantity;
  final double unitPrice;
  final QuoteItemReferenceType referenceType;
  final String? serviceId;
  final String? packageId;
  final String? inventoryItemId;

  double get total => double.parse((quantity * unitPrice).toStringAsFixed(2));

  QuoteItem copyWith({
    String? id,
    String? description,
    double? quantity,
    double? unitPrice,
    QuoteItemReferenceType? referenceType,
    Object? serviceId = _unset,
    Object? packageId = _unset,
    Object? inventoryItemId = _unset,
  }) {
    return QuoteItem(
      id: id ?? this.id,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      referenceType: referenceType ?? this.referenceType,
      serviceId: serviceId == _unset ? this.serviceId : serviceId as String?,
      packageId: packageId == _unset ? this.packageId : packageId as String?,
      inventoryItemId:
          inventoryItemId == _unset
              ? this.inventoryItemId
              : inventoryItemId as String?,
    );
  }
}

enum QuoteItemReferenceType { manual, service, package, product }

QuoteItemReferenceType quoteItemReferenceTypeFromString(String? value) {
  if (value == null || value.isEmpty) {
    return QuoteItemReferenceType.manual;
  }
  return QuoteItemReferenceType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => QuoteItemReferenceType.manual,
  );
}

String nextQuoteNumber(Iterable<Quote> quotes, {DateTime? now}) {
  final referenceDate = now ?? DateTime.now();
  final year = referenceDate.year;
  final prefix = 'PR-$year-';
  final existingIndices = <int>{};
  for (final quote in quotes) {
    final number = quote.number;
    if (number == null || !number.startsWith(prefix)) {
      continue;
    }
    final rawCounter = number.substring(prefix.length);
    final parsed = int.tryParse(rawCounter);
    if (parsed != null && parsed > 0) {
      existingIndices.add(parsed);
    }
  }
  var counter = 1;
  while (existingIndices.contains(counter)) {
    counter += 1;
  }
  return '$prefix${counter.toString().padLeft(3, '0')}';
}
