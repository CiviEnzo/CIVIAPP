enum ClientOnboardingStatus {
  notSent,
  invitationSent,
  firstLogin,
  onboardingCompleted,
}

const List<String> kClientReferralSourceOptions = [
  'Instagram',
  'Facebook',
  'Tik tok',
  'Amico titolare',
  'Amico dipendente',
  'Passaparola',
  'Passando davanti il centro',
  'Cliente passato',
  'Campagna lead',
  'Buono regalo',
  'Tramite App',
];

String nextSequentialClientNumber(Iterable<Client> clients) {
  final usedNumbers = <int>{};
  for (final client in clients) {
    final rawNumber = client.clientNumber;
    if (rawNumber == null) {
      continue;
    }
    final parsed = int.tryParse(rawNumber);
    if (parsed == null || parsed <= 0 || parsed >= 1000000) {
      continue;
    }
    usedNumbers.add(parsed);
  }
  var candidate = 1;
  while (usedNumbers.contains(candidate)) {
    candidate += 1;
  }
  return candidate.toString();
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
    this.loyaltyInitialPoints = 0,
    this.loyaltyPoints = 0,
    this.loyaltyUpdatedAt,
    this.loyaltyTotalEarned,
    this.loyaltyTotalRedeemed,
    this.marketedConsents = const [],
    this.fcmTokens = const [],
    this.channelPreferences = const ChannelPreferences(),
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
  final int loyaltyInitialPoints;
  final int loyaltyPoints;
  final DateTime? loyaltyUpdatedAt;
  final int? loyaltyTotalEarned;
  final int? loyaltyTotalRedeemed;
  final List<ClientConsent> marketedConsents;
  final List<String> fcmTokens;
  final ChannelPreferences channelPreferences;
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
    int? loyaltyInitialPoints,
    int? loyaltyPoints,
    Object? loyaltyUpdatedAt = _unset,
    Object? loyaltyTotalEarned = _unset,
    Object? loyaltyTotalRedeemed = _unset,
    List<ClientConsent>? marketedConsents,
    List<String>? fcmTokens,
    ClientOnboardingStatus? onboardingStatus,
    Object? invitationSentAt = _unset,
    Object? firstLoginAt = _unset,
    Object? onboardingCompletedAt = _unset,
    ChannelPreferences? channelPreferences,
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
      loyaltyInitialPoints: loyaltyInitialPoints ?? this.loyaltyInitialPoints,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      loyaltyUpdatedAt:
          loyaltyUpdatedAt == _unset
              ? this.loyaltyUpdatedAt
              : loyaltyUpdatedAt as DateTime?,
      loyaltyTotalEarned:
          loyaltyTotalEarned == _unset
              ? this.loyaltyTotalEarned
              : loyaltyTotalEarned as int?,
      loyaltyTotalRedeemed:
          loyaltyTotalRedeemed == _unset
              ? this.loyaltyTotalRedeemed
              : loyaltyTotalRedeemed as int?,
      marketedConsents: marketedConsents ?? this.marketedConsents,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      channelPreferences: channelPreferences ?? this.channelPreferences,
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

class ChannelPreferences {
  const ChannelPreferences({
    this.push = true,
    this.email = true,
    this.whatsapp = false,
    this.sms = false,
    this.updatedAt,
  });

  final bool push;
  final bool email;
  final bool whatsapp;
  final bool sms;
  final DateTime? updatedAt;

  ChannelPreferences copyWith({
    bool? push,
    bool? email,
    bool? whatsapp,
    bool? sms,
    DateTime? updatedAt,
  }) {
    return ChannelPreferences(
      push: push ?? this.push,
      email: email ?? this.email,
      whatsapp: whatsapp ?? this.whatsapp,
      sms: sms ?? this.sms,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
