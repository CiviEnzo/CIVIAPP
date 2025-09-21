enum ClientOnboardingStatus {
  notSent,
  invitationSent,
  firstLogin,
  onboardingCompleted,
}

class Client {
  const Client({
    required this.id,
    required this.salonId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.clientNumber,
    this.dateOfBirth,
    this.address,
    this.profession,
    this.referralSource,
    this.email,
    this.notes,
    this.loyaltyPoints = 0,
    this.marketedConsents = const [],
    this.onboardingStatus = ClientOnboardingStatus.notSent,
    this.invitationSentAt,
    this.firstLoginAt,
    this.onboardingCompletedAt,
  });

  static const Object _unset = Object();

  final String id;
  final String salonId;
  final String firstName;
  final String lastName;
  final String phone;
  final String? clientNumber;
  final DateTime? dateOfBirth;
  final String? address;
  final String? profession;
  final String? referralSource;
  final String? email;
  final String? notes;
  final int loyaltyPoints;
  final List<ClientConsent> marketedConsents;
  final ClientOnboardingStatus onboardingStatus;
  final DateTime? invitationSentAt;
  final DateTime? firstLoginAt;
  final DateTime? onboardingCompletedAt;

  String get fullName => '$firstName $lastName';

  Client copyWith({
    String? id,
    String? salonId,
    String? firstName,
    String? lastName,
    String? phone,
    Object? clientNumber = _unset,
    Object? dateOfBirth = _unset,
    Object? address = _unset,
    Object? profession = _unset,
    Object? referralSource = _unset,
    Object? email = _unset,
    Object? notes = _unset,
    int? loyaltyPoints,
    List<ClientConsent>? marketedConsents,
    ClientOnboardingStatus? onboardingStatus,
    Object? invitationSentAt = _unset,
    Object? firstLoginAt = _unset,
    Object? onboardingCompletedAt = _unset,
  }) {
    return Client(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      clientNumber:
          clientNumber == _unset ? this.clientNumber : clientNumber as String?,
      dateOfBirth:
          dateOfBirth == _unset ? this.dateOfBirth : dateOfBirth as DateTime?,
      address: address == _unset ? this.address : address as String?,
      profession:
          profession == _unset ? this.profession : profession as String?,
      referralSource:
          referralSource == _unset
              ? this.referralSource
              : referralSource as String?,
      email: email == _unset ? this.email : email as String?,
      notes: notes == _unset ? this.notes : notes as String?,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      marketedConsents: marketedConsents ?? this.marketedConsents,
      onboardingStatus: onboardingStatus ?? this.onboardingStatus,
      invitationSentAt:
          invitationSentAt == _unset
              ? this.invitationSentAt
              : invitationSentAt as DateTime?,
      firstLoginAt:
          firstLoginAt == _unset
              ? this.firstLoginAt
              : firstLoginAt as DateTime?,
      onboardingCompletedAt:
          onboardingCompletedAt == _unset
              ? this.onboardingCompletedAt
              : onboardingCompletedAt as DateTime?,
    );
  }
}

class ClientConsent {
  const ClientConsent({required this.type, required this.acceptedAt});

  final ConsentType type;
  final DateTime acceptedAt;
}

enum ConsentType { marketing, privacy, profilazione }
