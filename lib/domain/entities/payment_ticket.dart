class PaymentTicket {
  const PaymentTicket({
    required this.id,
    required this.salonId,
    required this.appointmentId,
    required this.clientId,
    required this.serviceId,
    required this.appointmentStart,
    required this.appointmentEnd,
    required this.createdAt,
    this.staffId,
    this.status = PaymentTicketStatus.open,
    this.closedAt,
    this.saleId,
    this.expectedTotal,
    this.serviceName,
    this.notes,
  });

  final String id;
  final String salonId;
  final String appointmentId;
  final String clientId;
  final String serviceId;
  final String? staffId;
  final DateTime appointmentStart;
  final DateTime appointmentEnd;
  final DateTime createdAt;
  final PaymentTicketStatus status;
  final DateTime? closedAt;
  final String? saleId;
  final double? expectedTotal;
  final String? serviceName;
  final String? notes;

  PaymentTicket copyWith({
    String? id,
    String? salonId,
    String? appointmentId,
    String? clientId,
    String? serviceId,
    Object? staffId = _unset,
    DateTime? appointmentStart,
    DateTime? appointmentEnd,
    DateTime? createdAt,
    PaymentTicketStatus? status,
    Object? closedAt = _unset,
    Object? saleId = _unset,
    Object? expectedTotal = _unset,
    Object? serviceName = _unset,
    Object? notes = _unset,
  }) {
    return PaymentTicket(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      appointmentId: appointmentId ?? this.appointmentId,
      clientId: clientId ?? this.clientId,
      serviceId: serviceId ?? this.serviceId,
      staffId: staffId == _unset ? this.staffId : staffId as String?,
      appointmentStart: appointmentStart ?? this.appointmentStart,
      appointmentEnd: appointmentEnd ?? this.appointmentEnd,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      closedAt: closedAt == _unset ? this.closedAt : closedAt as DateTime?,
      saleId: saleId == _unset ? this.saleId : saleId as String?,
      expectedTotal:
          expectedTotal == _unset
              ? this.expectedTotal
              : (expectedTotal as double?),
      serviceName:
          serviceName == _unset ? this.serviceName : serviceName as String?,
      notes: notes == _unset ? this.notes : notes as String?,
    );
  }
}

enum PaymentTicketStatus { open, closed }

extension PaymentTicketStatusX on PaymentTicketStatus {
  String get label {
    switch (this) {
      case PaymentTicketStatus.open:
        return 'Aperto';
      case PaymentTicketStatus.closed:
        return 'Chiuso';
    }
  }
}

const Object _unset = Object();
