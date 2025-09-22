class StaffMember {
  const StaffMember({
    required this.id,
    required this.salonId,
    required this.firstName,
    required this.lastName,
    required this.roleId,
    this.phone,
    this.email,
    this.dateOfBirth,
    this.skills = const [],
    this.isActive = true,
    this.vacationAllowance = defaultVacationAllowance,
    this.permissionAllowance = defaultPermissionAllowance,
  });

  static const int defaultVacationAllowance = 26;
  static const int defaultPermissionAllowance = 12;

  final String id;
  final String salonId;
  final String firstName;
  final String lastName;
  final String roleId;
  final String? phone;
  final String? email;
  final DateTime? dateOfBirth;
  final List<String> skills;
  final bool isActive;
  final int vacationAllowance;
  final int permissionAllowance;

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
    String? roleId,
    String? phone,
    String? email,
    DateTime? dateOfBirth,
    List<String>? skills,
    bool? isActive,
    int? vacationAllowance,
    int? permissionAllowance,
  }) {
    return StaffMember(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      roleId: roleId ?? this.roleId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      skills: skills ?? this.skills,
      isActive: isActive ?? this.isActive,
      vacationAllowance: vacationAllowance ?? this.vacationAllowance,
      permissionAllowance: permissionAllowance ?? this.permissionAllowance,
    );
  }
}
