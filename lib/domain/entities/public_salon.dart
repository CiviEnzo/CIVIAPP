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
    this.publicServices = const <PublicSalonService>[],
    this.publicPackages = const <PublicSalonPackage>[],
    this.status = SalonStatus.active,
    this.clientRegistration = const ClientRegistrationSettings(),
    this.isPublished = false,
    this.showPublicCatalog = true,
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
  final List<PublicSalonService> publicServices;
  final List<PublicSalonPackage> publicPackages;
  final SalonStatus status;
  final ClientRegistrationSettings clientRegistration;
  final bool isPublished;
  final bool showPublicCatalog;

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
    List<PublicSalonService>? publicServices,
    List<PublicSalonPackage>? publicPackages,
    SalonStatus? status,
    ClientRegistrationSettings? clientRegistration,
    bool? isPublished,
    bool? showPublicCatalog,
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
      publicServices:
          publicServices == null
              ? this.publicServices
              : List<PublicSalonService>.unmodifiable(publicServices),
      publicPackages:
          publicPackages == null
              ? this.publicPackages
              : List<PublicSalonPackage>.unmodifiable(publicPackages),
      status: status ?? this.status,
      clientRegistration: clientRegistration ?? this.clientRegistration,
      isPublished: isPublished ?? this.isPublished,
      showPublicCatalog: showPublicCatalog ?? this.showPublicCatalog,
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
      showPublicCatalog: salon.showPublicCatalog,
    );
  }

  factory PublicSalon.fromMap(String id, Map<String, dynamic> data) {
    Map<String, String> socialLinks = const <String, String>{};
    final socialRaw = data['socialLinks'];
    if (socialRaw is Map) {
      final entries = socialRaw.entries
          .where((entry) => entry.key != null && entry.value != null)
          .map<MapEntry<String, String>>(
            (entry) => MapEntry(entry.key.toString(), entry.value.toString()),
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
      publicServices: _mapPublicServices(data['publicServices']),
      publicPackages: _mapPublicPackages(data['publicPackages']),
      status: _stringToSalonStatus(data['status'] as String?),
      clientRegistration: _mapClientRegistration(data['clientRegistration']),
      isPublished: data['isPublished'] as bool? ?? true,
      showPublicCatalog: data['showPublicCatalog'] as bool? ?? true,
    );
  }
}

class PublicSalonService {
  const PublicSalonService({
    required this.id,
    required this.name,
    required this.category,
    required this.durationMinutes,
    required this.price,
    this.description,
  });

  final String id;
  final String name;
  final String category;
  final int durationMinutes;
  final double price;
  final String? description;

  factory PublicSalonService.fromMap(Map<String, dynamic> data) {
    return PublicSalonService(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      description: data['description'] as String?,
    );
  }
}

class PublicSalonPackage {
  const PublicSalonPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.fullPrice,
    this.discountPercentage,
    this.description,
    this.serviceIds = const <String>[],
    this.sessionCount,
    this.validDays,
  });

  final String id;
  final String name;
  final double price;
  final double fullPrice;
  final double? discountPercentage;
  final String? description;
  final List<String> serviceIds;
  final int? sessionCount;
  final int? validDays;

  factory PublicSalonPackage.fromMap(Map<String, dynamic> data) {
    return PublicSalonPackage(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      fullPrice:
          (data['fullPrice'] as num?)?.toDouble() ??
          (data['price'] as num?)?.toDouble() ??
          0,
      discountPercentage: (data['discountPercentage'] as num?)?.toDouble(),
      description: data['description'] as String?,
      serviceIds: (data['serviceIds'] as List<dynamic>? ?? const [])
          .map((entry) => entry.toString())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false),
      sessionCount: (data['sessionCount'] as num?)?.toInt(),
      validDays: (data['validDays'] as num?)?.toInt(),
    );
  }
}

const Object _sentinel = Object();

List<PublicSalonService> _mapPublicServices(Object? value) {
  if (value is! List) {
    return const <PublicSalonService>[];
  }
  return List<PublicSalonService>.unmodifiable(
    value.whereType<Map>().map((item) {
      return PublicSalonService.fromMap(Map<String, dynamic>.from(item));
    }),
  );
}

List<PublicSalonPackage> _mapPublicPackages(Object? value) {
  if (value is! List) {
    return const <PublicSalonPackage>[];
  }
  return List<PublicSalonPackage>.unmodifiable(
    value.whereType<Map>().map((item) {
      return PublicSalonPackage.fromMap(Map<String, dynamic>.from(item));
    }),
  );
}

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
    case 'gender':
      return ClientRegistrationExtraField.gender;
    default:
      return null;
  }
}
