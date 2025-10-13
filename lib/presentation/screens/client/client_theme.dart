import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientTheme {
  const ClientTheme._();

  static const Color background = Color.fromARGB(255, 255, 250, 232);
  static const Color card = Colors.white;
  static const Color primary = Color(0xFF415047);
  static const Color onPrimary = Colors.white;
  static const Color surfaceText = Color(0xFF2C2A28);

  static ThemeData resolve(ThemeData base) {
    final colorScheme = base.colorScheme;
    final clientScheme = colorScheme.copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: primary,
      onSecondary: onPrimary,
      surface: background,
      onSurface: surfaceText,
      surfaceTint: Colors.transparent,
      surfaceVariant: card,
      onSurfaceVariant: surfaceText.withOpacity(0.72),
      outline: surfaceText.withOpacity(0.12),
      outlineVariant: surfaceText.withOpacity(0.12),
      background: background,
    );

    final baseInterTextTheme = GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: surfaceText, displayColor: surfaceText);
    final textTheme = baseInterTextTheme.copyWith(
      displayLarge: baseInterTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      displayMedium: baseInterTextTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      displaySmall: baseInterTextTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: baseInterTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      headlineMedium: baseInterTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      headlineSmall: baseInterTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      titleLarge: baseInterTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      titleMedium: baseInterTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      titleSmall: baseInterTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: baseInterTextTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: baseInterTextTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      bodySmall: baseInterTextTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      labelLarge: baseInterTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      labelMedium: baseInterTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      labelSmall: baseInterTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
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
        foregroundColor: surfaceText,
        elevation: 0,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: card,
        elevation: 0,
        shape: roundedShape,
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(0, 54),
          textStyle: textTheme.titleMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: card,
          foregroundColor: surfaceText,
          textStyle: textTheme.titleSmall,
          shape: roundedShape,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: surfaceText,
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
          borderSide: BorderSide(color: surfaceText.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: surfaceText.withOpacity(0.7),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: card,
        selectedColor: primary.withOpacity(0.1),
        shape: roundedShape,
        labelStyle: textTheme.labelLarge,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorColor: primary.withOpacity(0.12),
        backgroundColor: background,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontWeight:
                states.contains(MaterialState.selected)
                    ? FontWeight.w600
                    : FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: roundedShape,
      ),
    );
  }
}
