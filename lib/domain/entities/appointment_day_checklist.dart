import 'package:collection/collection.dart';

class AppointmentChecklistItem {
  const AppointmentChecklistItem({
    required this.id,
    required this.label,
    required this.position,
    this.isCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String label;
  final int position;
  final bool isCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppointmentChecklistItem copyWith({
    String? id,
    String? label,
    int? position,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
  }) {
    return AppointmentChecklistItem(
      id: id ?? this.id,
      label: label ?? this.label,
      position: position ?? this.position,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }
}

class AppointmentDayChecklist {
  AppointmentDayChecklist({
    required this.id,
    required this.salonId,
    required DateTime date,
    List<AppointmentChecklistItem>? items,
    this.createdAt,
    this.updatedAt,
  }) : date = DateTime(date.year, date.month, date.day),
       items = List.unmodifiable(
         (items ?? const <AppointmentChecklistItem>[]).sortedBy<num>(
           (item) => item.position,
         ),
       );

  final String id;
  final String salonId;
  final DateTime date;
  final List<AppointmentChecklistItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppointmentDayChecklist copyWith({
    String? id,
    String? salonId,
    DateTime? date,
    List<AppointmentChecklistItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentDayChecklist(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      date: date ?? this.date,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
