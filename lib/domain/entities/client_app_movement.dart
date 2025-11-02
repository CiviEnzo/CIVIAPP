import 'package:collection/collection.dart';

enum ClientAppMovementType {
  registration,
  appointmentCreated,
  appointmentUpdated,
  appointmentCancelled,
  purchase,
  reviewClick,
  lastMinutePurchase,
}

ClientAppMovementType? clientAppMovementTypeFromName(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return ClientAppMovementType.values.firstWhereOrNull(
    (type) => type.name == value,
  );
}

extension ClientAppMovementTypeDisplay on ClientAppMovementType {
  String get label {
    switch (this) {
      case ClientAppMovementType.registration:
        return 'Registrazione';
      case ClientAppMovementType.appointmentCreated:
        return 'Appuntamento creato';
      case ClientAppMovementType.appointmentUpdated:
        return 'Appuntamento aggiornato';
      case ClientAppMovementType.appointmentCancelled:
        return 'Appuntamento annullato';
      case ClientAppMovementType.purchase:
        return 'Acquisto';
      case ClientAppMovementType.reviewClick:
        return 'Recensioni';
      case ClientAppMovementType.lastMinutePurchase:
        return 'Last minute';
    }
  }
}

class ClientAppMovement {
  ClientAppMovement({
    required this.id,
    required this.salonId,
    required this.clientId,
    required this.type,
    required this.timestamp,
    this.source,
    this.channel,
    this.label,
    this.description,
    this.appointmentId,
    this.saleId,
    this.lastMinuteSlotId,
    this.createdBy,
    Map<String, dynamic>? metadata,
  }) : metadata = Map.unmodifiable(metadata ?? const <String, dynamic>{});

  final String id;
  final String salonId;
  final String clientId;
  final ClientAppMovementType type;
  final DateTime timestamp;
  final String? source;
  final String? channel;
  final String? label;
  final String? description;
  final String? appointmentId;
  final String? saleId;
  final String? lastMinuteSlotId;
  final String? createdBy;
  final Map<String, dynamic> metadata;

  ClientAppMovement copyWith({
    String? id,
    String? salonId,
    String? clientId,
    ClientAppMovementType? type,
    DateTime? timestamp,
    String? source,
    Object? channel = _unset,
    Object? label = _unset,
    Object? description = _unset,
    Object? appointmentId = _unset,
    Object? saleId = _unset,
    Object? lastMinuteSlotId = _unset,
    Object? createdBy = _unset,
    Map<String, dynamic>? metadata,
  }) {
    return ClientAppMovement(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      clientId: clientId ?? this.clientId,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      channel: identical(channel, _unset) ? this.channel : channel as String?,
      label: identical(label, _unset) ? this.label : label as String?,
      description:
          identical(description, _unset)
              ? this.description
              : description as String?,
      appointmentId:
          identical(appointmentId, _unset)
              ? this.appointmentId
              : appointmentId as String?,
      saleId: identical(saleId, _unset) ? this.saleId : saleId as String?,
      lastMinuteSlotId:
          identical(lastMinuteSlotId, _unset)
              ? this.lastMinuteSlotId
              : lastMinuteSlotId as String?,
      createdBy:
          identical(createdBy, _unset) ? this.createdBy : createdBy as String?,
      metadata: metadata ?? this.metadata,
    );
  }

  static const Object _unset = Object();
}
