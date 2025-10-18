enum SetupChecklistStatus { notStarted, inProgress, completed, postponed }

SetupChecklistStatus? setupChecklistStatusFromName(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  for (final status in SetupChecklistStatus.values) {
    if (status.name == normalized) {
      return status;
    }
  }
  return null;
}

String setupChecklistStatusToName(SetupChecklistStatus status) {
  return status.name;
}

class SetupChecklistKeys {
  const SetupChecklistKeys._();

  static const String profile = 'profile';
  static const String operations = 'operations';
  static const String equipment = 'equipment';
  static const String rooms = 'rooms';
  static const String loyalty = 'loyalty';
  static const String social = 'social';

  static const List<String> defaults = <String>[
    profile,
    operations,
    equipment,
    rooms,
    loyalty,
    social,
  ];
}

class SetupChecklistItem {
  const SetupChecklistItem({
    required this.key,
    this.status = SetupChecklistStatus.notStarted,
    this.metadata = const <String, dynamic>{},
    this.updatedAt,
    this.updatedBy,
  });

  final String key;
  final SetupChecklistStatus status;
  final Map<String, dynamic> metadata;
  final DateTime? updatedAt;
  final String? updatedBy;

  SetupChecklistItem copyWith({
    SetupChecklistStatus? status,
    Map<String, dynamic>? metadata,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return SetupChecklistItem(
      key: key,
      status: status ?? this.status,
      metadata: metadata ?? this.metadata,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

class AdminSetupProgress {
  const AdminSetupProgress({
    required this.id,
    required this.salonId,
    this.tenantId,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.pendingReminder = true,
    this.requiredCompleted = false,
    this.items = const <SetupChecklistItem>[],
  });

  final String id;
  final String salonId;
  final String? tenantId;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool pendingReminder;
  final bool requiredCompleted;
  final List<SetupChecklistItem> items;

  bool get isCompleted =>
      items.isNotEmpty &&
      items.every((item) => item.status == SetupChecklistStatus.completed);

  SetupChecklistItem? itemForKey(String key) {
    for (final item in items) {
      if (item.key == key) {
        return item;
      }
    }
    return null;
  }

  AdminSetupProgress copyWith({
    String? id,
    String? salonId,
    String? tenantId,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? pendingReminder,
    bool? requiredCompleted,
    List<SetupChecklistItem>? items,
  }) {
    return AdminSetupProgress(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      tenantId: tenantId ?? this.tenantId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      pendingReminder: pendingReminder ?? this.pendingReminder,
      requiredCompleted: requiredCompleted ?? this.requiredCompleted,
      items: items ?? this.items,
    );
  }
}
