import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientTheme {
  const ClientTheme._();

  static const Color _brandPrimary = Color(0xFF921625);
  static const Color _brandOnPrimary = Colors.white;
  static const Color _lightBackground = Color(0xFFFFFAE8);
  static const Color _lightCard = Colors.white;
  static const Color _lightOnSurface = Color(0xFF2C2A28);
  static const Color _darkBackground = Color(0xFF0F1012);
  static const Color _darkCard = Color(0xFF1B1D21);
  static const Color _darkOnSurface = Color(0xFFE6E6EA);

  static ThemeData resolve(ThemeData base) {
    final scheme = base.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final background = isDark ? _darkBackground : _lightBackground;
    final card = isDark ? _darkCard : _lightCard;
    final onSurface = isDark ? _darkOnSurface : _lightOnSurface;
    final onSurfaceMuted = _alpha(onSurface, isDark ? 0.6 : 0.72);
    final outline = _alpha(onSurface, 0.12);
    final cardShadow = _alpha(Colors.black, isDark ? 0.3 : 0.15);
    final inactiveIconColor = _alpha(onSurface, isDark ? 0.7 : 0.52);
    final iconShadowColor = _alpha(Colors.black, isDark ? 0.45 : 0.2);

    final clientScheme = scheme.copyWith(
      primary: _brandPrimary,
      onPrimary: _brandOnPrimary,
      secondary: _brandPrimary,
      onSecondary: _brandOnPrimary,
      background: background,
      surface: background,
      onSurface: onSurface,
      surfaceTint: Colors.transparent,
      surfaceVariant: card,
      onSurfaceVariant: onSurfaceMuted,
      outline: outline,
      outlineVariant: outline,
    );

    final baseInter = GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: onSurface, displayColor: onSurface);

    final textTheme = baseInter.copyWith(
      displayLarge: baseInter.displayLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      displayMedium: baseInter.displayMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      displaySmall: baseInter.displaySmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: baseInter.headlineLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      headlineMedium: baseInter.headlineMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      headlineSmall: baseInter.headlineSmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      titleLarge: baseInter.titleLarge?.copyWith(fontWeight: FontWeight.w500),
      titleMedium: baseInter.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      titleSmall: baseInter.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      bodyLarge: baseInter.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: baseInter.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      bodySmall: baseInter.bodySmall?.copyWith(fontWeight: FontWeight.w500),
      labelLarge: baseInter.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      labelMedium: baseInter.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      labelSmall: baseInter.labelSmall?.copyWith(fontWeight: FontWeight.w500),
    );

    final roundedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    return base.copyWith(
      colorScheme: clientScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: card,
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: card,
        elevation: 6,
        shadowColor: cardShadow,
        surfaceTintColor: Colors.transparent,
        shape: roundedShape,
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _brandPrimary,
          foregroundColor: _brandOnPrimary,
          minimumSize: const Size(0, 48),
          textStyle: textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ).copyWith(iconSize: WidgetStateProperty.all(22.0)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: card,
          foregroundColor: onSurface,
          textStyle: textTheme.titleSmall,
          shape: roundedShape,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onSurface,
          textStyle: textTheme.titleSmall,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _brandPrimary, width: 1.4),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: onSurfaceMuted),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: card,
        selectedColor: _alpha(_brandPrimary, 0.14),
        shape: roundedShape,
        labelStyle: textTheme.labelLarge,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorColor: Colors.transparent,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.w500,
            color:
                states.contains(WidgetState.selected)
                    ? _brandPrimary
                    : inactiveIconColor,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color:
                states.contains(WidgetState.selected)
                    ? _brandPrimary
                    : inactiveIconColor,
            shadows:
                states.contains(WidgetState.selected)
                    ? [
                      Shadow(
                        color: iconShadowColor,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : const <Shadow>[],
          ),
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: _brandPrimary,
        foregroundColor: _brandOnPrimary,
        shape: roundedShape,
      ),
    );
  }

  static Color _alpha(Color color, double opacity) {
    final alpha = (opacity.clamp(0, 1) * 255).round();
    return color.withAlpha(alpha);
  }
}
