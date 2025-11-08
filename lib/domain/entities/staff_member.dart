class StaffMember {
  StaffMember({
    required this.id,
    required this.salonId,
    required this.firstName,
    required this.lastName,
    this.roleIds = const <String>['staff-role-unknown'],
    this.phone,
    this.email,
    this.dateOfBirth,
    this.isActive = true,
    this.isEquipment = false,
    this.vacationAllowance = defaultVacationAllowance,
    this.permissionAllowance = defaultPermissionAllowance,
    this.sortOrder = 0,
    this.avatarUrl,
    this.avatarStoragePath,
  }) : assert(roleIds.isNotEmpty);

  static const Object _unset = Object();
  static const int defaultVacationAllowance = 26;
  static const int defaultPermissionAllowance = 12;
  static const String unknownRoleId = 'staff-role-unknown';

  final String id;
  final String salonId;
  final String firstName;
  final String lastName;
  final List<String> roleIds;
  final String? phone;
  final String? email;
  final DateTime? dateOfBirth;
  final bool isActive;
  final bool isEquipment;
  final int vacationAllowance;
  final int permissionAllowance;
  final int sortOrder;
  final String? avatarUrl;
  final String? avatarStoragePath;

  String get primaryRoleId =>
      roleIds.isNotEmpty ? roleIds.first : unknownRoleId;

  String get fullName {
    final parts =
        <String>[
          firstName.trim(),
          lastName.trim(),
        ].where((value) => value.isNotEmpty).toList();
    return parts.join(' ');
  }

  String get displayName {
    final name = fullName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    if (firstName.trim().isNotEmpty) {
      return firstName.trim();
    }
    if (lastName.trim().isNotEmpty) {
      return lastName.trim();
    }
    return 'Staff member';
  }

  StaffMember copyWith({
    String? id,
    String? salonId,
    String? firstName,
    String? lastName,
    List<String>? roleIds,
    String? phone,
    String? email,
    DateTime? dateOfBirth,
    bool? isActive,
    bool? isEquipment,
    int? vacationAllowance,
    int? permissionAllowance,
    int? sortOrder,
    Object? avatarUrl = _unset,
    Object? avatarStoragePath = _unset,
  }) {
    List<String> resolvedRoleIds;
    if (roleIds != null && roleIds.isNotEmpty) {
      resolvedRoleIds = roleIds;
    } else if (roleIds != null && roleIds.isEmpty) {
      resolvedRoleIds = const <String>[unknownRoleId];
    } else {
      resolvedRoleIds = this.roleIds;
    }
    return StaffMember(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      roleIds: resolvedRoleIds,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      isActive: isActive ?? this.isActive,
      isEquipment: isEquipment ?? this.isEquipment,
      vacationAllowance: vacationAllowance ?? this.vacationAllowance,
      permissionAllowance: permissionAllowance ?? this.permissionAllowance,
      sortOrder: sortOrder ?? this.sortOrder,
      avatarUrl: avatarUrl == _unset ? this.avatarUrl : avatarUrl as String?,
      avatarStoragePath:
          avatarStoragePath == _unset
              ? this.avatarStoragePath
              : avatarStoragePath as String?,
    );
  }
}

extension StaffMemberListX on Iterable<StaffMember> {
  List<StaffMember> sortedByDisplayOrder() {
    return toList()..sort((a, b) {
      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
  }
}
