class Shift {
  const Shift({
    required this.id,
    required this.salonId,
    required this.staffId,
    required this.start,
    required this.end,
    this.roomId,
    this.notes,
    this.breakStart,
    this.breakEnd,
    this.seriesId,
    this.recurrence,
  });

  static const Object _roomIdUnset = Object();

  final String id;
  final String salonId;
  final String staffId;
  final DateTime start;
  final DateTime end;
  final String? roomId;
  final String? notes;
  final DateTime? breakStart;
  final DateTime? breakEnd;
  final String? seriesId;
  final ShiftRecurrence? recurrence;

  Shift copyWith({
    String? id,
    String? salonId,
    String? staffId,
    DateTime? start,
    DateTime? end,
    Object? roomId = _roomIdUnset,
    String? notes,
    DateTime? breakStart,
    DateTime? breakEnd,
    bool clearBreak = false,
    String? seriesId,
    ShiftRecurrence? recurrence,
  }) {
    return Shift(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      staffId: staffId ?? this.staffId,
      start: start ?? this.start,
      end: end ?? this.end,
      roomId: roomId == _roomIdUnset ? this.roomId : roomId as String?,
      notes: notes ?? this.notes,
      breakStart: clearBreak ? null : (breakStart ?? this.breakStart),
      breakEnd: clearBreak ? null : (breakEnd ?? this.breakEnd),
      seriesId: seriesId ?? this.seriesId,
      recurrence: recurrence ?? this.recurrence,
    );
  }
}

enum ShiftRecurrenceFrequency { daily, weekly, monthly, yearly }

class ShiftRecurrence {
  const ShiftRecurrence({
    required this.frequency,
    this.interval = 1,
    required this.until,
    this.weekdays,
    this.activeWeeks,
    this.inactiveWeeks,
  }) : assert(interval >= 1, 'interval must be at least 1');

  final ShiftRecurrenceFrequency frequency;
  final int interval;
  final DateTime until;
  final List<int>? weekdays;
  final int? activeWeeks;
  final int? inactiveWeeks;

  factory ShiftRecurrence.fromMap(Map<String, dynamic> data) {
    final frequencyName = data['frequency'] as String?;
    final frequency = ShiftRecurrenceFrequency.values.firstWhere(
      (value) => value.name == frequencyName,
      orElse: () => ShiftRecurrenceFrequency.weekly,
    );
    final intervalValue = data['interval'] as int? ?? 1;
    final untilTimestamp = data['until'];
    if (untilTimestamp is! DateTime) {
      throw ArgumentError('ShiftRecurrence.until must be a DateTime instance');
    }
    final weekdaysData = data['weekdays'];
    final weekdays =
        weekdaysData is Iterable
            ? weekdaysData
                .map((day) => day is int ? day : null)
                .whereType<int>()
                .where(
                  (day) => day >= DateTime.monday && day <= DateTime.sunday,
                )
                .toList()
            : null;
    final normalizedWeekdays =
        weekdays != null && weekdays.isNotEmpty
            ? List<int>.unmodifiable(weekdays)
            : null;
    final activeWeeks = (data['activeWeeks'] as num?)?.toInt();
    final inactiveWeeks = (data['inactiveWeeks'] as num?)?.toInt();
    return ShiftRecurrence(
      frequency: frequency,
      interval: intervalValue,
      until: untilTimestamp,
      weekdays: normalizedWeekdays,
      activeWeeks: activeWeeks,
      inactiveWeeks: inactiveWeeks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'frequency': frequency.name,
      'interval': interval,
      'until': until,
      if (weekdays != null && weekdays!.isNotEmpty) 'weekdays': weekdays,
      if (activeWeeks != null) 'activeWeeks': activeWeeks,
      if (inactiveWeeks != null) 'inactiveWeeks': inactiveWeeks,
    };
  }
}
