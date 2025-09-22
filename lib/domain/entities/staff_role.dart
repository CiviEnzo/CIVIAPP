import 'package:flutter/foundation.dart';

@immutable
class StaffRole {
  const StaffRole({
    required this.id,
    required this.name,
    this.salonId,
    this.description,
    this.color,
    this.isDefault = false,
    this.sortPriority = 0,
  });

  final String id;
  final String name;
  final String? salonId;
  final String? description;
  final int? color;
  final bool isDefault;
  final int sortPriority;

  String get displayName => name;

  StaffRole copyWith({
    String? id,
    String? name,
    String? salonId,
    String? description,
    int? color,
    bool? isDefault,
    int? sortPriority,
  }) {
    return StaffRole(
      id: id ?? this.id,
      name: name ?? this.name,
      salonId: salonId ?? this.salonId,
      description: description ?? this.description,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      sortPriority: sortPriority ?? this.sortPriority,
    );
  }
}
