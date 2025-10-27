import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:you_book/domain/entities/user_role.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.role,
    required this.salonIds,
    this.staffId,
    this.clientId,
    this.displayName,
    this.email,
    this.availableRoles = const <UserRole>[],
    this.pendingSalonId,
    this.pendingFirstName,
    this.pendingLastName,
    this.pendingPhone,
    this.pendingDateOfBirth,
  });

  final String uid;
  final UserRole? role;
  final List<String> salonIds;
  final String? staffId;
  final String? clientId;
  final String? displayName;
  final String? email;
  final List<UserRole> availableRoles;
  final String? pendingSalonId;
  final String? pendingFirstName;
  final String? pendingLastName;
  final String? pendingPhone;
  final DateTime? pendingDateOfBirth;

  String? get defaultSalonId => salonIds.isNotEmpty ? salonIds.first : null;

  String? get linkedEntityId {
    switch (role) {
      case UserRole.admin:
      case null:
        return null;
      case UserRole.staff:
        return staffId;
      case UserRole.client:
        return clientId;
    }
  }

  bool get isProfileComplete {
    if (role == null) {
      return false;
    }
    if (role == UserRole.admin) {
      return true;
    }
    return salonIds.isNotEmpty;
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final roleName = (data['role'] as String?)?.toLowerCase().trim();
    UserRole? role;
    if (roleName != null) {
      try {
        role = UserRole.values.firstWhere((value) => value.name == roleName);
      } catch (_) {
        role = null;
      }
    }

    final salonIdsRaw = data['salonIds'];
    List<String> salonIds;
    if (salonIdsRaw is List) {
      salonIds = salonIdsRaw.map((e) => e.toString()).toList();
    } else {
      final singleSalon = data['salonId']?.toString();
      salonIds =
          singleSalon == null || singleSalon.isEmpty ? const [] : [singleSalon];
    }

    final availableRoles = _parseAvailableRoles(
      rawRoles: data['roles'] ?? data['availableRoles'] ?? data['allowedRoles'],
      fallbackRole: role,
    );
    final effectiveRole =
        role ?? (availableRoles.isNotEmpty ? availableRoles.first : null);

    return AppUser(
      uid: uid,
      role: effectiveRole,
      salonIds: salonIds,
      staffId: data['staffId'] as String?,
      clientId: data['clientId'] as String?,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      availableRoles: availableRoles,
      pendingSalonId: _stringOrNull(data['pendingSalonId']),
      pendingFirstName: _stringOrNull(data['pendingFirstName']),
      pendingLastName: _stringOrNull(data['pendingLastName']),
      pendingPhone: _stringOrNull(data['pendingPhone']),
      pendingDateOfBirth: _dateFromValue(data['pendingDateOfBirth']),
    );
  }

  factory AppUser.placeholder(
    String uid, {
    String? email,
    String? displayName,
  }) {
    return AppUser(
      uid: uid,
      role: null,
      salonIds: const [],
      email: email,
      displayName: displayName,
      availableRoles: const <UserRole>[],
      pendingSalonId: null,
      pendingFirstName: null,
      pendingLastName: null,
      pendingPhone: null,
      pendingDateOfBirth: null,
    );
  }
}

List<UserRole> _parseAvailableRoles({
  Object? rawRoles,
  UserRole? fallbackRole,
}) {
  final result = <UserRole>[];

  void addRole(UserRole? role) {
    if (role == null || result.contains(role)) {
      return;
    }
    result.add(role);
  }

  if (rawRoles is Iterable) {
    for (final entry in rawRoles) {
      if (entry == null) {
        continue;
      }
      addRole(_roleFromName(entry.toString()));
    }
  } else if (rawRoles is String && rawRoles.trim().isNotEmpty) {
    addRole(_roleFromName(rawRoles));
  }

  addRole(fallbackRole);

  return List<UserRole>.unmodifiable(result);
}

UserRole? _roleFromName(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  for (final role in UserRole.values) {
    if (role.name == normalized) {
      return role;
    }
  }
  return null;
}

String? _stringOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  final stringValue = value.toString().trim();
  if (stringValue.isEmpty) {
    return null;
  }
  return stringValue;
}

DateTime? _dateFromValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    return parsed;
  }
  return null;
}
