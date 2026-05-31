import 'package:flutter/material.dart';

const String appVersionLabel = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0+1',
);

class AppVersionBadge extends StatelessWidget {
  const AppVersionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      right: 12,
      bottom: 8,
      child: SafeArea(
        minimum: const EdgeInsets.only(right: 4, bottom: 4),
        child: IgnorePointer(
          child: Text(
            'v$appVersionLabel',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.58),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
