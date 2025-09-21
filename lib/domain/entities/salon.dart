class Salon {
  const Salon({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    this.rooms = const [],
    this.description,
    this.schedule = const [],
  });

  final String id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final String email;
  final List<SalonRoom> rooms;
  final String? description;
  final List<SalonDailySchedule> schedule;

  Salon copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    String? phone,
    String? email,
    List<SalonRoom>? rooms,
    String? description,
    List<SalonDailySchedule>? schedule,
  }) {
    return Salon(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      rooms: rooms ?? this.rooms,
      description: description ?? this.description,
      schedule: schedule ?? this.schedule,
    );
  }
}

class SalonRoom {
  const SalonRoom({
    required this.id,
    required this.name,
    required this.capacity,
    this.services = const [],
  });

  final String id;
  final String name;
  final int capacity;
  final List<String> services;
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
