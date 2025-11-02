import 'package:you_book/domain/entities/salon.dart';

class PublicSalon {
  const PublicSalon({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    this.description,
    this.bookingLink,
    this.googlePlaceId,
    this.coverImageUrl,
    this.logoImageUrl,
    this.latitude,
    this.longitude,
    this.socialLinks = const <String, String>{},
    this.status = SalonStatus.active,
    this.clientRegistration = const ClientRegistrationSettings(),
    this.isPublished = false,
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final String email;
  final String? description;
  final String? bookingLink;
  final String? googlePlaceId;
  final String? coverImageUrl;
  final String? logoImageUrl;
  final double? latitude;
  final double? longitude;
  final Map<String, String> socialLinks;
  final SalonStatus status;
  final ClientRegistrationSettings clientRegistration;
  final bool isPublished;

  PublicSalon copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    String? phone,
    String? email,
    Object? description = _sentinel,
    Object? bookingLink = _sentinel,
    Object? googlePlaceId = _sentinel,
    Object? coverImageUrl = _sentinel,
    Object? logoImageUrl = _sentinel,
    double? latitude,
    double? longitude,
    Map<String, String>? socialLinks,
    SalonStatus? status,
    ClientRegistrationSettings? clientRegistration,
    bool? isPublished,
  }) {
    return PublicSalon(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      description:
          identical(description, _sentinel)
              ? this.description
              : description as String?,
      bookingLink:
          identical(bookingLink, _sentinel)
              ? this.bookingLink
              : bookingLink as String?,
      googlePlaceId:
          identical(googlePlaceId, _sentinel)
              ? this.googlePlaceId
              : googlePlaceId as String?,
      coverImageUrl:
          identical(coverImageUrl, _sentinel)
              ? this.coverImageUrl
              : coverImageUrl as String?,
      logoImageUrl:
          identical(logoImageUrl, _sentinel)
              ? this.logoImageUrl
              : logoImageUrl as String?,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      socialLinks:
          socialLinks == null
              ? this.socialLinks
              : Map<String, String>.unmodifiable(socialLinks),
      status: status ?? this.status,
      clientRegistration: clientRegistration ?? this.clientRegistration,
      isPublished: isPublished ?? this.isPublished,
    );
  }

  factory PublicSalon.fromSalon(Salon salon) {
    return PublicSalon(
      id: salon.id,
      name: salon.name,
      address: salon.address,
      city: salon.city,
      phone: salon.phone,
      email: salon.email,
      description: salon.description,
      bookingLink: salon.bookingLink,
      googlePlaceId: salon.googlePlaceId,
      latitude: salon.latitude,
      longitude: salon.longitude,
      socialLinks: Map<String, String>.unmodifiable(salon.socialLinks),
      status: salon.status,
      clientRegistration: salon.clientRegistration,
      isPublished: salon.isPublished,
    );
  }

  factory PublicSalon.fromMap(String id, Map<String, dynamic> data) {
    Map<String, String> socialLinks = const <String, String>{};
    final socialRaw = data['socialLinks'];
    if (socialRaw is Map) {
      final entries = socialRaw.entries
          .where((entry) => entry.key != null && entry.value != null)
          .map<MapEntry<String, String>>(
            (entry) => MapEntry(
              entry.key.toString(),
              entry.value.toString(),
            ),
          );
      socialLinks = Map<String, String>.unmodifiable(
        Map<String, String>.fromEntries(entries),
      );
    }

    return PublicSalon(
      id: id,
      name: (data['name'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      city: (data['city'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      description: data['description'] as String?,
      bookingLink: data['bookingLink'] as String?,
      googlePlaceId: data['googlePlaceId'] as String?,
      coverImageUrl: data['coverImageUrl'] as String?,
      logoImageUrl: data['logoImageUrl'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      socialLinks: socialLinks,
      status: _stringToSalonStatus(data['status'] as String?),
      clientRegistration: _mapClientRegistration(data['clientRegistration']),
      isPublished: data['isPublished'] as bool? ?? true,
    );
  }
}

const Object _sentinel = Object();

SalonStatus _stringToSalonStatus(String? value) {
  switch (value) {
    case 'active':
      return SalonStatus.active;
    case 'suspended':
      return SalonStatus.suspended;
    case 'archived':
      return SalonStatus.archived;
    default:
      return SalonStatus.active;
  }
}

ClientRegistrationSettings _mapClientRegistration(Object? value) {
  if (value is Map<String, dynamic>) {
    final accessMode = value['accessMode'] as String?;
    final extraRaw = value['extraFields'] as List<dynamic>? ?? const [];
    final extraFields = extraRaw
        .whereType<String>()
        .map(_stringToClientRegistrationExtraField)
        .whereType<ClientRegistrationExtraField>()
        .toList(growable: false);
    return ClientRegistrationSettings(
      accessMode: _stringToClientRegistrationAccessMode(accessMode),
      extraFields: extraFields,
    );
  }
  return const ClientRegistrationSettings();
}

ClientRegistrationAccessMode _stringToClientRegistrationAccessMode(
  String? value,
) {
  switch (value) {
    case 'approval':
      return ClientRegistrationAccessMode.approval;
    case 'open':
    default:
      return ClientRegistrationAccessMode.open;
  }
}

ClientRegistrationExtraField? _stringToClientRegistrationExtraField(
  String? value,
) {
  switch (value) {
    case 'address':
      return ClientRegistrationExtraField.address;
    case 'profession':
      return ClientRegistrationExtraField.profession;
    case 'referralSource':
      return ClientRegistrationExtraField.referralSource;
    case 'notes':
      return ClientRegistrationExtraField.notes;
    default:
      return null;
  }
}
