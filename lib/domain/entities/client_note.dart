import 'package:you_book/domain/entities/user_role.dart';

class ClientNote {
  const ClientNote({
    required this.id,
    required this.salonId,
    required this.clientId,
    required this.text,
    required this.createdAt,
    required this.createdById,
    required this.createdByRole,
    this.createdByName,
    this.updatedAt,
    this.updatedById,
    this.updatedByRole,
    this.updatedByName,
  });

  static const Object _unset = Object();

  final String id;
  final String salonId;
  final String clientId;
  final String text;
  final DateTime createdAt;
  final String createdById;
  final UserRole createdByRole;
  final String? createdByName;
  final DateTime? updatedAt;
  final String? updatedById;
  final UserRole? updatedByRole;
  final String? updatedByName;

  DateTime get lastModifiedAt => updatedAt ?? createdAt;

  UserRole get lastModifiedRole => updatedByRole ?? createdByRole;

  String? get lastModifiedName => updatedByName ?? createdByName;

  ClientNote copyWith({
    String? id,
    String? salonId,
    String? clientId,
    String? text,
    DateTime? createdAt,
    Object? createdById = _unset,
    Object? createdByRole = _unset,
    Object? createdByName = _unset,
    Object? updatedAt = _unset,
    Object? updatedById = _unset,
    Object? updatedByRole = _unset,
    Object? updatedByName = _unset,
  }) {
    return ClientNote(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      clientId: clientId ?? this.clientId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      createdById:
          createdById == _unset ? this.createdById : createdById as String,
      createdByRole:
          createdByRole == _unset
              ? this.createdByRole
              : createdByRole as UserRole,
      createdByName:
          createdByName == _unset
              ? this.createdByName
              : createdByName as String?,
      updatedAt:
          updatedAt == _unset ? this.updatedAt : updatedAt as DateTime?,
      updatedById:
          updatedById == _unset ? this.updatedById : updatedById as String?,
      updatedByRole:
          updatedByRole == _unset
              ? this.updatedByRole
              : updatedByRole as UserRole?,
      updatedByName:
          updatedByName == _unset
              ? this.updatedByName
              : updatedByName as String?,
    );
  }
}
