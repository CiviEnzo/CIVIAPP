enum LastMinuteNotificationAudience { none, everyone, ownerSelection }

class ReminderOffsetConfig {
  const ReminderOffsetConfig({
    required this.id,
    required this.minutesBefore,
    this.active = true,
    this.title,
    this.bodyTemplate,
  });

  final String id;
  final int minutesBefore;
  final bool active;
  final String? title;
  final String? bodyTemplate;

  ReminderOffsetConfig copyWith({
    String? id,
    int? minutesBefore,
    bool? active,
    String? title,
    String? bodyTemplate,
  }) {
    return ReminderOffsetConfig(
      id: id ?? this.id,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      active: active ?? this.active,
      title: title ?? this.title,
      bodyTemplate: bodyTemplate ?? this.bodyTemplate,
    );
  }
}

class ReminderSettings {
  ReminderSettings({
    required this.salonId,
    List<ReminderOffsetConfig>? offsets,
    this.birthdayEnabled = true,
    this.lastMinuteNotificationAudience = LastMinuteNotificationAudience.none,
    this.updatedAt,
    this.updatedBy,
  }) : offsets = _normalizeOffsets(offsets);

  static const int minOffsetMinutes = 15;
  static const int maxOffsetMinutes = 43200; // 30 giorni.
  static const int maxOffsetsCount = 5;

  final String salonId;
  final List<ReminderOffsetConfig> offsets;
  final bool birthdayEnabled;
  final LastMinuteNotificationAudience lastMinuteNotificationAudience;
  final DateTime? updatedAt;
  final String? updatedBy;

  List<ReminderOffsetConfig> get activeOffsets =>
      offsets.where((offset) => offset.active).toList(growable: false);

  List<int> get activeOffsetsMinutes =>
      activeOffsets.map((offset) => offset.minutesBefore).toList(growable: false);

  ReminderSettings copyWith({
    String? salonId,
    List<ReminderOffsetConfig>? offsets,
    bool? birthdayEnabled,
    LastMinuteNotificationAudience? lastMinuteNotificationAudience,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return ReminderSettings(
      salonId: salonId ?? this.salonId,
      offsets: offsets ?? this.offsets,
      birthdayEnabled: birthdayEnabled ?? this.birthdayEnabled,
      lastMinuteNotificationAudience:
          lastMinuteNotificationAudience ?? this.lastMinuteNotificationAudience,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  static List<ReminderOffsetConfig> _normalizeOffsets(
    Iterable<ReminderOffsetConfig>? rawOffsets,
  ) {
    if (rawOffsets == null || rawOffsets.isEmpty) {
      return List<ReminderOffsetConfig>.unmodifiable(
        const <ReminderOffsetConfig>[],
      );
    }

    final normalized = <ReminderOffsetConfig>[];
    final usedIds = <String>{};
    const defaultSlugHints = {'T24H', 'T3H', 'T30M', 'T60M'};
    const defaultTitleHints = {
      'Promemoria 24h',
      'Promemoria 3h',
      'Promemoria 30 minuti',
    };

    String _sanitizeId(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return '';
      }
      final upper = trimmed.toUpperCase();
      final sanitized = upper.replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
      return sanitized.replaceAll(RegExp(r'_+'), '_');
    }

    String _ensureUniqueId(String base, int minutes) {
      var candidate = base.isEmpty ? 'M$minutes' : base;
      var suffix = 1;
      while (usedIds.contains(candidate)) {
        candidate = '${base.isEmpty ? 'OFFSET' : base}_$suffix';
        suffix += 1;
      }
      usedIds.add(candidate);
      return candidate;
    }

    int _clampMinutes(int minutes) {
      if (minutes < minOffsetMinutes) {
        return minOffsetMinutes;
      }
      if (minutes > maxOffsetMinutes) {
        return maxOffsetMinutes;
      }
      return minutes;
    }

    final entries = rawOffsets.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      var sanitizedId = _sanitizeId(entry.id);
      if (defaultSlugHints.contains(sanitizedId)) {
        sanitizedId = '';
      }
      final minutes = _clampMinutes(entry.minutesBefore);
      var normalizedTitle = entry.title?.trim();
      if (normalizedTitle != null &&
          (normalizedTitle.isEmpty || defaultTitleHints.contains(normalizedTitle))) {
        normalizedTitle = null;
      }
      final normalizedBody = entry.bodyTemplate?.trim();
      final uniqueId = _ensureUniqueId(sanitizedId, minutes);
      normalized.add(
        ReminderOffsetConfig(
          id: uniqueId,
          minutesBefore: minutes,
          active: entry.active,
          title: normalizedTitle?.isEmpty == true ? null : normalizedTitle,
          bodyTemplate: normalizedBody?.isEmpty == true ? null : normalizedBody,
        ),
      );
    }

    normalized.sort(
      (a, b) => a.minutesBefore.compareTo(b.minutesBefore),
    );

    return List<ReminderOffsetConfig>.unmodifiable(normalized);
  }
}
