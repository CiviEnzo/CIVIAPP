import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientTheme {
  const ClientTheme._();

  // Palette clienti: bianco / nero / oro (stile elegante-lussuoso).
  static const Color _brandPrimary = Color(0xFFBF9A43);
  static const Color _brandOnPrimary = Color(0xFF101010);
  static const Color _brandSecondary = Color(0xFF8B6A24);
  static const Color _brandTertiary = Color(0xFFE6D5A4);
  static const Color _lightBackground = Color(0xFFFFFFFF);
  static const Color _lightCard = Color(0xFFFFFFFF);
  static const Color _lightOnSurface = Color(0xFF111111);
  static const Color _lightPrimaryContainer = Color(0xFFF7EED8);
  static const Color _lightOnPrimaryContainer = Color(0xFF2B2210);
  static const Color _lightSecondaryContainer = Color(0xFFFFF8E8);
  static const Color _lightOnSecondaryContainer = Color(0xFF2A200A);
  static const Color _lightTertiaryContainer = Color(0xFFF3F1EA);
  static const Color _lightOnTertiaryContainer = Color(0xFF1C1A14);
  static const Color _darkBackground = Color(0xFF0A0A0A);
  static const Color _darkCard = Color(0xFF141414);
  static const Color _darkOnSurface = Color(0xFFF3F3F3);
  static const Color _darkPrimaryContainer = Color(0xFF3A2D10);
  static const Color _darkOnPrimaryContainer = Color(0xFFF9EFD6);
  static const Color _darkSecondaryContainer = Color(0xFF2B220E);
  static const Color _darkOnSecondaryContainer = Color(0xFFF6E7BE);
  static const Color _darkTertiaryContainer = Color(0xFF20201B);
  static const Color _darkOnTertiaryContainer = Color(0xFFECE8DA);

  static ThemeData resolve(ThemeData base) {
    final scheme = base.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final background = isDark ? _darkBackground : _lightBackground;
    final card = isDark ? _darkCard : _lightCard;
    final onSurface = isDark ? _darkOnSurface : _lightOnSurface;
    final onSurfaceMuted = _alpha(onSurface, isDark ? 0.6 : 0.72);
    final outline = _alpha(onSurface, isDark ? 0.16 : 0.1);
    final accentOutline = _alpha(_brandPrimary, isDark ? 0.42 : 0.26);
    final cardBorder = _blend(outline, _brandPrimary, isDark ? 0.35 : 0.22);
    final cardShadow = _alpha(Colors.black, isDark ? 0.36 : 0.09);
    final inactiveIconColor = _alpha(onSurface, isDark ? 0.7 : 0.52);
    final iconShadowColor = _alpha(_brandPrimary, isDark ? 0.34 : 0.22);
    final fieldFill =
        isDark
            ? _blend(card, _brandPrimary, 0.06)
            : _blend(card, _brandPrimary, 0.035);
    final chipFill =
        isDark
            ? _blend(card, Colors.white, 0.02)
            : _blend(card, _brandPrimary, 0.018);
    final indicatorColor = _alpha(_brandPrimary, isDark ? 0.2 : 0.12);
    final surfaceVariant =
        isDark
            ? _blend(card, _brandPrimary, 0.08)
            : _blend(card, _brandPrimary, 0.03);

    final clientScheme = scheme.copyWith(
      primary: _brandPrimary,
      onPrimary: _brandOnPrimary,
      secondary: _brandSecondary,
      onSecondary: _brandOnPrimary,
      tertiary: _brandTertiary,
      onTertiary: _brandOnPrimary,
      primaryContainer: isDark ? _darkPrimaryContainer : _lightPrimaryContainer,
      onPrimaryContainer:
          isDark ? _darkOnPrimaryContainer : _lightOnPrimaryContainer,
      secondaryContainer:
          isDark ? _darkSecondaryContainer : _lightSecondaryContainer,
      onSecondaryContainer:
          isDark ? _darkOnSecondaryContainer : _lightOnSecondaryContainer,
      tertiaryContainer:
          isDark ? _darkTertiaryContainer : _lightTertiaryContainer,
      onTertiaryContainer:
          isDark ? _darkOnTertiaryContainer : _lightOnTertiaryContainer,
      background: background,
      surface: card,
      onSurface: onSurface,
      surfaceTint: Colors.transparent,
      surfaceVariant: surfaceVariant,
      onSurfaceVariant: onSurfaceMuted,
      outline: outline,
      outlineVariant: cardBorder,
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
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: card,
        elevation: isDark ? 0 : 2,
        shadowColor: cardShadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cardBorder),
        ),
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
          side: BorderSide(color: cardBorder),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: accentOutline),
          textStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _brandSecondary,
          textStyle: textTheme.titleSmall,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: fieldFill,
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
          borderSide: BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _brandPrimary, width: 1.4),
        ),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: _brandSecondary,
          fontWeight: FontWeight.w600,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: onSurfaceMuted),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: chipFill,
        selectedColor: _blend(chipFill, _brandPrimary, isDark ? 0.28 : 0.18),
        disabledColor: _alpha(onSurface, 0.04),
        side: BorderSide(color: cardBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cardBorder),
        ),
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: onSurface),
      ),
      dividerTheme: DividerThemeData(color: cardBorder, space: 1, thickness: 1),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: cardBorder),
        ),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        modalBarrierColor: _alpha(Colors.black, isDark ? 0.66 : 0.34),
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: _brandPrimary,
        circularTrackColor: _alpha(_brandPrimary, 0.14),
        linearTrackColor: _alpha(_brandPrimary, 0.14),
      ),
      checkboxTheme: base.checkboxTheme.copyWith(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _brandPrimary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(_brandOnPrimary),
        side: BorderSide(color: cardBorder, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: base.radioTheme.copyWith(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _brandPrimary;
          }
          return onSurfaceMuted;
        }),
      ),
      switchTheme: base.switchTheme.copyWith(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _brandPrimary;
          }
          return isDark ? const Color(0xFFCBCBCB) : const Color(0xFFF7F7F7);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _alpha(_brandPrimary, isDark ? 0.5 : 0.38);
          }
          return _alpha(onSurface, isDark ? 0.25 : 0.12);
        }),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorColor: indicatorColor,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.w500,
            color:
                states.contains(WidgetState.selected)
                    ? onSurface
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
        elevation: isDark ? 1 : 3,
      ),
    );
  }

  static Color _blend(Color base, Color overlay, double opacity) {
    return Color.alphaBlend(overlay.withValues(alpha: opacity), base);
  }

  static Color _alpha(Color color, double opacity) {
    final alpha = (opacity.clamp(0, 1) * 255).round();
    return color.withAlpha(alpha);
  }
}
