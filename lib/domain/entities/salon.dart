import 'loyalty_settings.dart';

const Object _sentinel = Object();

enum SalonStatus { active, suspended, archived }

extension SalonStatusDisplay on SalonStatus {
  String get label {
    switch (this) {
      case SalonStatus.active:
        return 'Attivo';
      case SalonStatus.suspended:
        return 'Sospeso';
      case SalonStatus.archived:
        return 'Archiviato';
    }
  }
}

enum SalonEquipmentStatus { operational, maintenance, outOfOrder }

extension SalonEquipmentStatusDisplay on SalonEquipmentStatus {
  String get label {
    switch (this) {
      case SalonEquipmentStatus.operational:
        return 'Operativo';
      case SalonEquipmentStatus.maintenance:
        return 'In manutenzione';
      case SalonEquipmentStatus.outOfOrder:
        return 'Fuori servizio';
    }
  }
}

class StripeAccountSnapshot {
  const StripeAccountSnapshot({
    this.chargesEnabled = false,
    this.payoutsEnabled = false,
    this.detailsSubmitted = false,
    this.currentlyDue = const <String>[],
    this.pastDue = const <String>[],
    this.eventuallyDue = const <String>[],
    this.disabledReason,
    this.createdAt,
    this.updatedAt,
  });

  final bool chargesEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;
  final List<String> currentlyDue;
  final List<String> pastDue;
  final List<String> eventuallyDue;
  final String? disabledReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isReadyForPayments => chargesEnabled && detailsSubmitted;

  StripeAccountSnapshot copyWith({
    bool? chargesEnabled,
    bool? payoutsEnabled,
    bool? detailsSubmitted,
    List<String>? currentlyDue,
    List<String>? pastDue,
    List<String>? eventuallyDue,
    Object? disabledReason = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StripeAccountSnapshot(
      chargesEnabled: chargesEnabled ?? this.chargesEnabled,
      payoutsEnabled: payoutsEnabled ?? this.payoutsEnabled,
      detailsSubmitted: detailsSubmitted ?? this.detailsSubmitted,
      currentlyDue: currentlyDue ?? this.currentlyDue,
      pastDue: pastDue ?? this.pastDue,
      eventuallyDue: eventuallyDue ?? this.eventuallyDue,
      disabledReason:
          identical(disabledReason, _sentinel)
              ? this.disabledReason
              : disabledReason as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Salon {
  const Salon({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    this.postalCode,
    this.bookingLink,
    this.latitude,
    this.longitude,
    this.socialLinks = const <String, String>{},
    this.rooms = const [],
    this.equipment = const [],
    this.closures = const [],
    this.description,
    this.schedule = const [],
    this.status = SalonStatus.active,
    this.loyaltySettings = const LoyaltySettings(),
    this.featureFlags = const SalonFeatureFlags(),
    this.clientRegistration = const ClientRegistrationSettings(),
    this.stripeAccountId,
    this.stripeAccount = const StripeAccountSnapshot(),
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final String email;
  final String? postalCode;
  final String? bookingLink;
  final double? latitude;
  final double? longitude;
  final Map<String, String> socialLinks;
  final List<SalonRoom> rooms;
  final List<SalonEquipment> equipment;
  final List<SalonClosure> closures;
  final String? description;
  final List<SalonDailySchedule> schedule;
  final SalonStatus status;
  final LoyaltySettings loyaltySettings;
  final SalonFeatureFlags featureFlags;
  final ClientRegistrationSettings clientRegistration;
  final String? stripeAccountId;
  final StripeAccountSnapshot stripeAccount;

  bool get canAcceptOnlinePayments =>
      stripeAccountId != null && stripeAccount.isReadyForPayments;

  Salon copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    String? phone,
    String? email,
    String? postalCode,
    String? bookingLink,
    double? latitude,
    double? longitude,
    Map<String, String>? socialLinks,
    List<SalonRoom>? rooms,
    List<SalonEquipment>? equipment,
    List<SalonClosure>? closures,
    String? description,
    List<SalonDailySchedule>? schedule,
    SalonStatus? status,
    LoyaltySettings? loyaltySettings,
    SalonFeatureFlags? featureFlags,
    ClientRegistrationSettings? clientRegistration,
    Object? stripeAccountId = _sentinel,
    StripeAccountSnapshot? stripeAccount,
  }) {
    return Salon(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      postalCode: postalCode ?? this.postalCode,
      bookingLink: bookingLink ?? this.bookingLink,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      socialLinks: socialLinks ?? this.socialLinks,
      rooms: rooms ?? this.rooms,
      equipment: equipment ?? this.equipment,
      closures: closures ?? this.closures,
      description: description ?? this.description,
      schedule: schedule ?? this.schedule,
      status: status ?? this.status,
      loyaltySettings: loyaltySettings ?? this.loyaltySettings,
      featureFlags: featureFlags ?? this.featureFlags,
      clientRegistration: clientRegistration ?? this.clientRegistration,
      stripeAccountId:
          identical(stripeAccountId, _sentinel)
              ? this.stripeAccountId
              : stripeAccountId as String?,
      stripeAccount: stripeAccount ?? this.stripeAccount,
    );
  }
}

enum ClientRegistrationAccessMode { open, approval }

enum ClientRegistrationExtraField { address, profession, referralSource, notes }

class ClientRegistrationSettings {
  const ClientRegistrationSettings({
    this.accessMode = ClientRegistrationAccessMode.open,
    this.extraFields = const <ClientRegistrationExtraField>[],
  });

  final ClientRegistrationAccessMode accessMode;
  final List<ClientRegistrationExtraField> extraFields;

  bool get requiresApproval =>
      accessMode == ClientRegistrationAccessMode.approval;

  ClientRegistrationSettings copyWith({
    ClientRegistrationAccessMode? accessMode,
    List<ClientRegistrationExtraField>? extraFields,
  }) {
    return ClientRegistrationSettings(
      accessMode: accessMode ?? this.accessMode,
      extraFields: extraFields ?? this.extraFields,
    );
  }
}

class SalonFeatureFlags {
  const SalonFeatureFlags({
    this.clientPromotions = false,
    this.clientLastMinute = false,
  });

  final bool clientPromotions;
  final bool clientLastMinute;

  SalonFeatureFlags copyWith({bool? clientPromotions, bool? clientLastMinute}) {
    return SalonFeatureFlags(
      clientPromotions: clientPromotions ?? this.clientPromotions,
      clientLastMinute: clientLastMinute ?? this.clientLastMinute,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clientPromotions': clientPromotions,
      'clientLastMinute': clientLastMinute,
    };
  }

  factory SalonFeatureFlags.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const SalonFeatureFlags();
    }
    return SalonFeatureFlags(
      clientPromotions: _readFlag(data['clientPromotions']),
      clientLastMinute: _readFlag(data['clientLastMinute']),
    );
  }
}

bool _readFlag(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

class SalonRoom {
  const SalonRoom({
    required this.id,
    required this.name,
    required this.capacity,
    this.category,
    this.services = const [],
  });

  final String id;
  final String name;
  final int capacity;
  final String? category;
  final List<String> services;
}

class SalonEquipment {
  const SalonEquipment({
    required this.id,
    required this.name,
    required this.quantity,
    this.status = SalonEquipmentStatus.operational,
    this.notes,
  });

  final String id;
  final String name;
  final int quantity;
  final SalonEquipmentStatus status;
  final String? notes;

  SalonEquipment copyWith({
    String? id,
    String? name,
    int? quantity,
    SalonEquipmentStatus? status,
    String? notes,
  }) {
    return SalonEquipment(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

class SalonClosure {
  SalonClosure({
    required this.id,
    required this.start,
    required this.end,
    this.reason,
  }) : assert(
         !end.isBefore(start),
         'La chiusura deve terminare dopo l\'inizio.',
       );

  final String id;
  final DateTime start;
  final DateTime end;
  final String? reason;

  SalonClosure copyWith({
    String? id,
    DateTime? start,
    DateTime? end,
    String? reason,
  }) {
    return SalonClosure(
      id: id ?? this.id,
      start: start ?? this.start,
      end: end ?? this.end,
      reason: reason ?? this.reason,
    );
  }

  bool get isSingleDay {
    return start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
  }
}

class SalonDailySchedule {
  const SalonDailySchedule({
    required this.weekday,
    this.isOpen = false,
    this.openMinuteOfDay,
    this.closeMinuteOfDay,
  }) : assert(
         !isOpen ||
             (openMinuteOfDay != null &&
                 closeMinuteOfDay != null &&
                 openMinuteOfDay < closeMinuteOfDay),
         'Opening and closing times must be set and valid when the day is open.',
       );

  final int weekday;
  final bool isOpen;
  final int? openMinuteOfDay;
  final int? closeMinuteOfDay;

  int? get durationMinutes =>
      isOpen && openMinuteOfDay != null && closeMinuteOfDay != null
          ? closeMinuteOfDay! - openMinuteOfDay!
          : null;

  SalonDailySchedule copyWith({
    bool? isOpen,
    int? openMinuteOfDay,
    int? closeMinuteOfDay,
  }) {
    return SalonDailySchedule(
      weekday: weekday,
      isOpen: isOpen ?? this.isOpen,
      openMinuteOfDay: openMinuteOfDay ?? this.openMinuteOfDay,
      closeMinuteOfDay: closeMinuteOfDay ?? this.closeMinuteOfDay,
    );
  }
}
