import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/services/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CiviApp extends ConsumerWidget {
  const CiviApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appBootstrapProvider);
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

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
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('it'), Locale('en')],
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: isLight ? const Color(0xFFF48FB1) : const Color(0xFFAD1457),
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: 10,
        foregroundColor: colorScheme.onSurface,
      ),

      iconTheme: IconThemeData(
        color: isLight ? Colors.black87 : Colors.white70,
        size: 24,
      ),

      cardTheme: CardTheme(
        elevation: 6,
        margin: const EdgeInsets.all(12),
        color:
            isLight
                ? colorScheme.surface.withOpacity(0.6)
                : colorScheme.surface.withOpacity(0.4),
        shadowColor: Colors.black.withOpacity(0.2),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor:
              isLight ? const Color(0xFFF7ADC9) : const Color(0xFFCB8CA7),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor:
              isLight ? const Color(0xFFE57AA3) : const Color(0xFFF9B7CD),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isLight ? const Color(0xFFE57AA3) : const Color(0xFFF48FB1),
          side: BorderSide(
            color: isLight ? const Color(0xFFE57AA3) : const Color(0xFFF48FB1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor:
              isLight ? const Color(0xFFF48FB1) : const Color(0xFFC2185B),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isLight ? Colors.white.withOpacity(0.9) : Colors.white10,
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isLight ? Colors.white.withOpacity(0.9) : Colors.white10,
        ),
        menuStyle: MenuStyle(
          backgroundColor: MaterialStateProperty.all(
            isLight ? Colors.white : const Color(0xFF2D2D2D),
          ),
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor:
            isLight ? const Color(0xFFFDFDFD) : const Color(0xFF1F1F1F),
        elevation: 100,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
      ),
    );
  }
}
