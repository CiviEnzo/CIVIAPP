enum UserRole {
  admin,
  staff,
  client,
}

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.staff:
        return 'Staff';
      case UserRole.client:
        return 'Cliente';
    }
  }
}
