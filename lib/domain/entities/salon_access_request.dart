enum SalonAccessRequestStatus { pending, approved, rejected }

class SalonAccessRequest {
  const SalonAccessRequest({
    required this.id,
    required this.salonId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.dateOfBirth,
    this.clientId,
    this.extraData = const {},
    this.status = SalonAccessRequestStatus.pending,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String salonId;
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime? dateOfBirth;
  final String? clientId;
  final Map<String, dynamic> extraData;
  final SalonAccessRequestStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == SalonAccessRequestStatus.pending;

  SalonAccessRequest copyWith({
    String? id,
    String? salonId,
    String? userId,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    Object? clientId = _sentinel,
    Map<String, dynamic>? extraData,
    SalonAccessRequestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SalonAccessRequest(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      clientId:
          identical(clientId, _sentinel) ? this.clientId : clientId as String?,
      extraData: extraData ?? this.extraData,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _sentinel = Object();
