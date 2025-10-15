class ClientRegistrationDraft {
  const ClientRegistrationDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.dateOfBirth,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime? dateOfBirth;

  ClientRegistrationDraft copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
  }) {
    return ClientRegistrationDraft(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}
