import 'package:civiapp/app/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeModeAction extends ConsumerWidget {
  const ThemeModeAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);
    final isDark = themeMode == ThemeMode.dark;
    return IconButton(
      tooltip: isDark ? 'Disattiva tema scuro' : 'Attiva tema scuro',
      onPressed: () => controller.setDarkEnabled(!isDark),
      icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
    );
  }
}
