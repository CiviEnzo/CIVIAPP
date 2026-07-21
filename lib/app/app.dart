import 'dart:async';

import 'package:you_book/app/providers.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:you_book/services/notifications/notification_service.dart';

const ColorScheme _lightAdminColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFD4AF37),
  onPrimary: Color(0xFF000000),
  primaryContainer: Color(0xFFF5F0DC),
  onPrimaryContainer: Color(0xFF2E260C),
  secondary: Color(0xFF000000),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFF262626),
  onSecondaryContainer: Color(0xFFFFFFFF),
  tertiary: Color(0xFFD4AF37),
  onTertiary: Color(0xFF000000),
  tertiaryContainer: Color(0xFFEBE1B9),
  onTertiaryContainer: Color(0xFF2E260C),
  error: Color(0xFFEF4444),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFCA5A5),
  onErrorContainer: Color(0xFF000000),
  background: Color(0xFFFFFFFF),
  onBackground: Color(0xFF000000),
  surface: Color(0xFFFAFAFA),
  onSurface: Color(0xFF000000),
  surfaceVariant: Color(0xFFF5F5F5),
  onSurfaceVariant: Color(0xFF525252),
  outline: Color(0xFFD4D4D4),
  outlineVariant: Color(0xFFE5E5E5),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFF000000),
  onInverseSurface: Color(0xFFFFFFFF),
  inversePrimary: Color(0xFFD4AF37),
  surfaceTint: Color(0xFFD4AF37),
);

const ColorScheme _darkAdminColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFD4AF37),
  onPrimary: Color(0xFF000000),
  primaryContainer: Color(0xFF8A7123),
  onPrimaryContainer: Color(0xFFFFFFFF),
  secondary: Color(0xFFFFFFFF),
  onSecondary: Color(0xFF000000),
  secondaryContainer: Color(0xFF404040),
  onSecondaryContainer: Color(0xFFFFFFFF),
  tertiary: Color(0xFFD4AF37),
  onTertiary: Color(0xFF000000),
  tertiaryContainer: Color(0xFF5C4C18),
  onTertiaryContainer: Color(0xFFFFFFFF),
  error: Color(0xFFEF4444),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFF7F1D1D),
  onErrorContainer: Color(0xFFFFFFFF),
  background: Color(0xFF000000),
  onBackground: Color(0xFFFFFFFF),
  surface: Color(0xFF171717),
  onSurface: Color(0xFFFFFFFF),
  surfaceVariant: Color(0xFF262626),
  onSurfaceVariant: Color(0xFFA3A3A3),
  outline: Color(0xFF525252),
  outlineVariant: Color(0xFF404040),
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: Color(0xFFFFFFFF),
  onInverseSurface: Color(0xFF000000),
  inversePrimary: Color(0xFFD4AF37),
  surfaceTint: Color(0xFFD4AF37),
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

    ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
      unawaited(
        ref
            .read(appTelemetryServiceProvider)
            .setUserContext(
              uid: next.uid,
              role: next.user?.role?.name,
              selectedSalonId: next.salonId,
              entityId: next.userId,
            ),
      );
    });

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

    return AppNoticeScope(
      child: MaterialApp.router(
        title: 'YouBook',
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
          return AppNoticeViewport(
            controller: AppNoticeScope.of(context),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final palette = _AdminPalette.resolve(brightness);
    final colorScheme = palette.scheme;
    final baseTextTheme =
        brightness == Brightness.light
            ? ThemeData.light().textTheme
            : ThemeData.dark().textTheme;
    final textTheme = GoogleFonts.manropeTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        textStyle: baseTextTheme.displayLarge,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        textStyle: baseTextTheme.displayMedium,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        textStyle: baseTextTheme.displaySmall,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        textStyle: baseTextTheme.headlineLarge,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        textStyle: baseTextTheme.headlineMedium,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        textStyle: baseTextTheme.headlineSmall,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        textStyle: baseTextTheme.titleLarge,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        textStyle: baseTextTheme.titleMedium,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.spaceGrotesk(
        textStyle: baseTextTheme.titleSmall,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: GoogleFonts.manrope(textStyle: baseTextTheme.bodySmall),
      bodyMedium: GoogleFonts.manrope(textStyle: baseTextTheme.bodyMedium),
      bodyLarge: GoogleFonts.manrope(textStyle: baseTextTheme.bodyLarge),
    );
    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      brightness: brightness,
      textTheme: textTheme,
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: palette.surface,
        elevation: 4,
        scrolledUnderElevation: 8,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: palette.shadow,
      ),
      iconTheme: baseTheme.iconTheme.copyWith(color: palette.icon, size: 24),
      cardTheme: baseTheme.cardTheme.copyWith(
        elevation: 6,
        margin: const EdgeInsets.all(10),
        color: palette.card,
        shadowColor: palette.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.75),
          ),
        ),
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
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
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
      drawerTheme: baseTheme.drawerTheme.copyWith(
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
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.surface,
        modalBarrierColor: colorScheme.scrim.withValues(alpha: 0.58),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        dragHandleColor: colorScheme.outline,
        dragHandleSize: const Size(44, 4),
        showDragHandle: true,
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: colorScheme.outlineVariant),
        backgroundColor: colorScheme.surfaceVariant,
        selectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.onPrimaryContainer,
        labelStyle: baseTheme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          colorScheme.surfaceVariant.withValues(alpha: 0.65),
        ),
        dataRowMinHeight: 52,
        dataRowMaxHeight: 72,
        horizontalMargin: 16,
        columnSpacing: 18,
        dividerThickness: 0.6,
        headingTextStyle: baseTheme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        dataTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      listTileTheme: baseTheme.listTileTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        subtitleTextStyle: baseTheme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      navigationRailTheme: baseTheme.navigationRailTheme.copyWith(
        backgroundColor: palette.surface,
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: baseTheme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: baseTheme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
