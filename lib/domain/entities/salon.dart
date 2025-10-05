import 'loyalty_settings.dart';

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
    this.rooms = const [],
    this.equipment = const [],
    this.closures = const [],
    this.description,
    this.schedule = const [],
    this.status = SalonStatus.active,
    this.loyaltySettings = const LoyaltySettings(),
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
  final List<SalonRoom> rooms;
  final List<SalonEquipment> equipment;
  final List<SalonClosure> closures;
  final String? description;
  final List<SalonDailySchedule> schedule;
  final SalonStatus status;
  final LoyaltySettings loyaltySettings;

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
    List<SalonRoom>? rooms,
    List<SalonEquipment>? equipment,
    List<SalonClosure>? closures,
    String? description,
    List<SalonDailySchedule>? schedule,
    SalonStatus? status,
    LoyaltySettings? loyaltySettings,
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
      rooms: rooms ?? this.rooms,
      equipment: equipment ?? this.equipment,
      closures: closures ?? this.closures,
      description: description ?? this.description,
      schedule: schedule ?? this.schedule,
      status: status ?? this.status,
      loyaltySettings: loyaltySettings ?? this.loyaltySettings,
    );
  }
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
