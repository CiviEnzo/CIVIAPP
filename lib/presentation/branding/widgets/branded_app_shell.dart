import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:civiapp/app/providers.dart';

class BrandedAppShell extends ConsumerWidget {
  const BrandedAppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appBootstrapProvider);
    final theme = ref.watch(salonThemeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Civi App Gestionale',
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: theme.theme,
      darkTheme: theme.darkTheme,
      themeMode: theme.mode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('it'), Locale('en')],
      builder: (context, widget) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: widget ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
