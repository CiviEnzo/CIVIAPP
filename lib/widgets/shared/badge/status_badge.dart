import 'package:flutter/material.dart';

enum BadgeStatus { success, pending, cancelled, info, active, inactive }

enum BadgeSize { sm, md }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    required this.label,
    this.size = BadgeSize.md,
  });

  final BadgeStatus status;
  final String label;
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _resolvePalette(theme.colorScheme);
    final padding = switch (size) {
      BadgeSize.sm => const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      BadgeSize.md => const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    };
    final textStyle = (size == BadgeSize.sm
            ? theme.textTheme.labelSmall
            : theme.textTheme.labelMedium)
        ?.copyWith(
          color: palette.foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        );

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(label, style: textStyle),
    );
  }

  _BadgePalette _resolvePalette(ColorScheme scheme) {
    switch (status) {
      case BadgeStatus.success:
      case BadgeStatus.active:
        return _BadgePalette(
          background: const Color(0x1A22C55E),
          foreground: const Color(0xFF15803D),
          border: const Color(0x6622C55E),
        );
      case BadgeStatus.pending:
        return _BadgePalette(
          background: const Color(0x1AF59E0B),
          foreground: const Color(0xFFB45309),
          border: const Color(0x66F59E0B),
        );
      case BadgeStatus.cancelled:
        return _BadgePalette(
          background: const Color(0x1AEF4444),
          foreground: scheme.error,
          border: const Color(0x66EF4444),
        );
      case BadgeStatus.inactive:
        return _BadgePalette(
          background: scheme.surfaceVariant,
          foreground: scheme.onSurfaceVariant,
          border: scheme.outlineVariant,
        );
      case BadgeStatus.info:
        return _BadgePalette(
          background: const Color(0x1A3B82F6),
          foreground: const Color(0xFF1D4ED8),
          border: const Color(0x663B82F6),
        );
    }
  }
}

class _BadgePalette {
  const _BadgePalette({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
