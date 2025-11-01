import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_book/services/notifications/notification_service.dart';

const ColorScheme _lightAdminColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color.fromARGB(255, 60, 206, 199),
  onPrimary: Colors.white,
  primaryContainer: Color.fromARGB(194, 255, 244, 221),
  onPrimaryContainer: Color(0xFF23005A),
  secondary: Color.fromARGB(226, 209, 175, 102),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFC5F4E6),
  onSecondaryContainer: Color(0xFF062E24),
  tertiary: Color(0xFFE8873A),
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFFFE3C6),
  onTertiaryContainer: Color(0xFF301500),
  error: Color(0xFFBA1A1A),
  onError: Colors.white,
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  background: Color(0xFFF6F4FB),
  onBackground: Color(0xFF1D1B20),
  surface: Color(0xFFFCFAFF),
  onSurface: Color(0xFF1D1B20),
  surfaceVariant: Color(0xFFE5E0EC),
  onSurfaceVariant: Color(0xFF49454F),
  outline: Color(0xFF7A7580),
  outlineVariant: Color(0xFFCBC4D0),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFF312F35),
  onInverseSurface: Color(0xFFF4EFF5),
  inversePrimary: Color(0xFFD3C1FF),
  surfaceTint: Color(0xFF7F56D9),
);

const ColorScheme _darkAdminColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFD3C1FF),
  onPrimary: Color(0xFF381E72),
  primaryContainer: Color(0xFF4F3790),
  onPrimaryContainer: Color(0xFFE9DDFF),
  secondary: Color(0xFF7FD8C4),
  onSecondary: Color(0xFF00382C),
  secondaryContainer: Color(0xFF005143),
  onSecondaryContainer: Color(0xFFC5F4E6),
  tertiary: Color(0xFFFFB77C),
  onTertiary: Color(0xFF4F1F00),
  tertiaryContainer: Color(0xFF6C3200),
  onTertiaryContainer: Color(0xFFFFE3C6),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  background: Color(0xFF15131A),
  onBackground: Color(0xFFE5E1EA),
  surface: Color(0xFF1A1721),
  onSurface: Color(0xFFE5E1EA),
  surfaceVariant: Color(0xFF4A4453),
  onSurfaceVariant: Color(0xFFCAC4D3),
  outline: Color(0xFF958F9F),
  outlineVariant: Color(0xFF4A4453),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFFE5E1EA),
  onInverseSurface: Color(0xFF2E2B33),
  inversePrimary: Color(0xFF7F56D9),
  surfaceTint: Color(0xFFD3C1FF),
);

Color _blendColor(Color base, Color overlay, double opacity) {
  return Color.alphaBlend(overlay.withOpacity(opacity), base);
}

class _AdminPalette {
  const _AdminPalette({
    required this.scheme,
    required this.background,
    required this.surface,
    required this.card,
    required this.icon,
    required this.iconMuted,
    required this.shadow,
    required this.fieldFill,
    required this.drawerBackground,
    required this.menuBackground,
  });

  final ColorScheme scheme;
  final Color background;
  final Color surface;
  final Color card;
  final Color icon;
  final Color iconMuted;
  final Color shadow;
  final Color fieldFill;
  final Color drawerBackground;
  final Color menuBackground;

  static _AdminPalette resolve(Brightness brightness) {
    if (brightness == Brightness.light) {
      const scheme = _lightAdminColorScheme;
      return _AdminPalette(
        scheme: scheme,
        background: scheme.background,
        surface: scheme.surface,
        card: Colors.white,
        icon: scheme.onSurface,
        iconMuted: scheme.onSurfaceVariant,
        shadow: Colors.black.withOpacity(0.14),
        fieldFill: _blendColor(Colors.white, scheme.primary, 0.06),
        drawerBackground: _blendColor(
          scheme.background,
          scheme.secondaryContainer,
          0.12,
        ),
        menuBackground: _blendColor(
          scheme.surface,
          scheme.surfaceVariant,
          0.08,
        ),
      );
    }

    const scheme = _darkAdminColorScheme;
    return _AdminPalette(
      scheme: scheme,
      background: scheme.background,
      surface: scheme.surface,
      card: _blendColor(scheme.surface, scheme.onSurface, 0.08),
      icon: scheme.onSurface,
      iconMuted: scheme.onSurfaceVariant,
      shadow: Colors.black.withOpacity(0.46),
      fieldFill: _blendColor(scheme.surface, scheme.surfaceVariant, 0.18),
      drawerBackground: _blendColor(
        scheme.surface,
        scheme.secondaryContainer,
        0.16,
      ),
      menuBackground: _blendColor(scheme.surface, scheme.surfaceVariant, 0.18),
    );
  }
}

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
        router.go('/client/dashboard');
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
    final palette = _AdminPalette.resolve(brightness);
    final colorScheme = palette.scheme;

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,

      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        elevation: 4,
        scrolledUnderElevation: 8,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: palette.shadow,
      ),

      iconTheme: IconThemeData(color: palette.icon, size: 24),

      cardTheme: CardTheme(
        elevation: 6,
        margin: const EdgeInsets.all(12),
        color: palette.card,
        shadowColor: palette.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colorScheme.onSecondaryContainer,
          backgroundColor: colorScheme.secondaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: brightness == Brightness.light ? 2 : 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.fieldFill,
        labelStyle: TextStyle(color: palette.iconMuted),
        floatingLabelStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
          filled: true,
          fillColor: palette.fieldFill,
        ),
        menuStyle: MenuStyle(
          backgroundColor: MaterialStateProperty.all(palette.menuBackground),
          shadowColor: MaterialStateProperty.all(palette.shadow),
          surfaceTintColor: MaterialStateProperty.all(Colors.transparent),
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: palette.drawerBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        scrimColor: colorScheme.scrim.withOpacity(0.55),
      ),
    );
  }
}
