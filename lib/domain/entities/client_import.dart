import 'package:you_book/domain/entities/client.dart';

enum ClientImportIssueSeverity { warning, error }

class ClientImportIssue {
  const ClientImportIssue({required this.severity, required this.message});

  final ClientImportIssueSeverity severity;
  final String message;
}

class ClientImportDraft {
  const ClientImportDraft({
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    this.notes,
    this.existingClientId,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String? notes;
  final String? existingClientId;

  Client toClient({required String id, required String salonId}) {
    return Client(
      id: id,
      salonId: salonId,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: email,
      notes: notes,
      loyaltyInitialPoints: 0,
      loyaltyPoints: 0,
      marketedConsents: const [],
      fcmTokens: const [],
      channelPreferences: const ChannelPreferences(),
      createdAt: DateTime.now(),
    );
  }
}

class ClientImportFailure {
  ClientImportFailure({required this.draft, required this.message, this.error});

  final ClientImportDraft draft;
  final String message;
  final Object? error;
}

class ClientImportSuccess {
  const ClientImportSuccess({required this.client});

  final Client client;
}

class ClientImportResult {
  const ClientImportResult({required this.successes, required this.failures});

  final List<ClientImportSuccess> successes;
  final List<ClientImportFailure> failures;

  int get importedCount => successes.length;
  int get failedCount => failures.length;
}

class ClientImportCandidate {
  ClientImportCandidate({
    required this.index,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.rawName,
    this.email,
    this.notes,
    this.existingClientId,
    List<ClientImportIssue>? issues,
  }) : issues = List.unmodifiable(issues ?? const []);

  final int index;
  final String firstName;
  final String lastName;
  final String phone;
  final String rawName;
  final String? email;
  final String? notes;
  final String? existingClientId;
  final List<ClientImportIssue> issues;

  bool get hasErrors =>
      issues.any((issue) => issue.severity == ClientImportIssueSeverity.error);
  bool get hasWarnings => issues.any(
    (issue) => issue.severity == ClientImportIssueSeverity.warning,
  );

  ClientImportCandidate copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? rawName,
    String? email,
    String? notes,
    String? existingClientId,
    List<ClientImportIssue>? issues,
  }) {
    return ClientImportCandidate(
      index: index,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      rawName: rawName ?? this.rawName,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      existingClientId: existingClientId ?? this.existingClientId,
      issues: issues ?? this.issues,
    );
  }

  ClientImportDraft toDraft() {
    return ClientImportDraft(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: email,
      notes: notes,
      existingClientId: existingClientId,
    );
  }
}

class ClientImportParseResult {
  const ClientImportParseResult({
    required this.candidates,
    this.generalIssues = const [],
    this.duplicateGroups = const [],
  });

  final List<ClientImportCandidate> candidates;
  final List<ClientImportIssue> generalIssues;
  final List<ClientImportDuplicateGroup> duplicateGroups;

  bool get hasBlockingErrors =>
      candidates.any((candidate) => candidate.hasErrors) ||
      generalIssues.any(
        (issue) => issue.severity == ClientImportIssueSeverity.error,
      );
}

enum ClientImportDuplicateType { phone, email }

class ClientImportDuplicateGroup {
  const ClientImportDuplicateGroup({
    required this.indices,
    required this.type,
    required this.value,
  });

  final List<int> indices;
  final ClientImportDuplicateType type;
  final String value;
}
