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
    this.vacationAllowance = defaultVacationAllowance,
    this.permissionAllowance = defaultPermissionAllowance,
  }) : assert(roleIds.isNotEmpty);

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
  final int vacationAllowance;
  final int permissionAllowance;

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
    int? vacationAllowance,
    int? permissionAllowance,
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
      vacationAllowance: vacationAllowance ?? this.vacationAllowance,
      permissionAllowance: permissionAllowance ?? this.permissionAllowance,
    );
  }
}
