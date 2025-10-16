import 'package:civiapp/app/providers.dart';
import 'package:civiapp/domain/entities/user_role.dart';
import 'package:civiapp/services/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BrandedAppShell extends ConsumerWidget {
  const BrandedAppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appBootstrapProvider);
    final theme = ref.watch(salonThemeProvider);
    final router = ref.watch(appRouterProvider);

    ref.listen<AsyncValue<NotificationTap>>(notificationTapStreamProvider, (
      previous,
      next,
    ) {
      next.whenData((tap) {
        final session = ref.read(sessionControllerProvider);
        if (session.role != UserRole.client) {
          return;
        }
        final payload = Map<String, Object?>.from(tap.payload);
        final type = payload['type']?.toString();
        var targetTab = -1;
        if (type == 'last_minute_slot') {
          targetTab = 0;
        }
        ref.read(clientDashboardIntentProvider.notifier).state =
            ClientDashboardIntent(tabIndex: targetTab, payload: payload);
        router.go('/client');
      });
    });

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
