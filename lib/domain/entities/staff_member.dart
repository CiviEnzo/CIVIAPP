class StaffMember {
  const StaffMember({
    required this.id,
    required this.salonId,
    required this.fullName,
    required this.role,
    this.phone,
    this.email,
    this.skills = const [],
    this.isActive = true,
  });

  final String id;
  final String salonId;
  final String fullName;
  final StaffRole role;
  final String? phone;
  final String? email;
  final List<String> skills;
  final bool isActive;
}

enum StaffRole {
  receptionist,
  estetista,
  massaggiatore,
  nailArtist,
  manager,
}

extension StaffRoleX on StaffRole {
  String get label {
    switch (this) {
      case StaffRole.receptionist:
        return 'Receptionist';
      case StaffRole.estetista:
        return 'Estetista';
      case StaffRole.massaggiatore:
        return 'Massaggiatore';
      case StaffRole.nailArtist:
        return 'Nail Artist';
      case StaffRole.manager:
        return 'Manager';
    }
  }
}
