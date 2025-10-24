import 'package:flutter/material.dart';

import 'package:you_book/domain/entities/promotion.dart';

class PromotionPalette {
  const PromotionPalette({
    required this.hasCustomAccent,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.highlight,
    required this.highlightContainer,
    required this.onHighlightContainer,
    required this.overlayGradientStart,
    required this.overlayGradientEnd,
    required this.fallbackGradientStart,
    required this.fallbackGradientEnd,
  });

  final bool hasCustomAccent;
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;
  final Color highlight;
  final Color highlightContainer;
  final Color onHighlightContainer;
  final Color overlayGradientStart;
  final Color overlayGradientEnd;
  final Color fallbackGradientStart;
  final Color fallbackGradientEnd;
}

PromotionPalette resolvePromotionPalette(
  Promotion promotion,
  ColorScheme scheme,
) {
  final int? customValue = promotion.themeColor;
  final bool hasCustomAccent = customValue != null;
  final Color accent =
      customValue != null ? Color(customValue) : scheme.primary;
  final Color onAccent =
      hasCustomAccent ? _onColor(accent, scheme.onPrimary) : scheme.onPrimary;

  final double containerBlendT =
      scheme.brightness == Brightness.dark ? 0.55 : 0.25;
  final Color accentContainer =
      hasCustomAccent
          ? Color.lerp(scheme.surface, accent, containerBlendT) ?? accent
          : scheme.primaryContainer;
  final Color onAccentContainer =
      hasCustomAccent
          ? _onColor(accentContainer, scheme.onPrimaryContainer)
          : scheme.onPrimaryContainer;

  final Color highlight =
      hasCustomAccent
          ? Color.lerp(accent, scheme.secondary, 0.35) ?? accent
          : scheme.secondary;
  final double highlightBlendT =
      scheme.brightness == Brightness.dark ? 0.5 : 0.22;
  final Color highlightContainer =
      hasCustomAccent
          ? Color.lerp(scheme.surface, highlight, highlightBlendT) ?? highlight
          : scheme.secondaryContainer;
  final Color onHighlightContainer =
      hasCustomAccent
          ? _onColor(highlightContainer, scheme.onSecondaryContainer)
          : scheme.onSecondaryContainer;

  final Color overlayGradientStart = Color.alphaBlend(
    accent.withValues(alpha: 0.45),
    scheme.scrim.withValues(alpha: 0.2),
  );
  final Color overlayGradientEnd = scheme.scrim.withValues(alpha: 0.05);

  final Color fallbackGradientStart =
      Color.lerp(
        accent,
        scheme.surface,
        scheme.brightness == Brightness.dark ? 0.3 : 0.85,
      ) ??
      accent;
  final Color fallbackGradientEnd = accent;

  return PromotionPalette(
    hasCustomAccent: hasCustomAccent,
    accent: accent,
    onAccent: onAccent,
    accentContainer: accentContainer,
    onAccentContainer: onAccentContainer,
    highlight: highlight,
    highlightContainer: highlightContainer,
    onHighlightContainer: onHighlightContainer,
    overlayGradientStart: overlayGradientStart,
    overlayGradientEnd: overlayGradientEnd,
    fallbackGradientStart: fallbackGradientStart,
    fallbackGradientEnd: fallbackGradientEnd,
  );
}

Color _onColor(Color background, Color fallback) {
  final brightness = ThemeData.estimateBrightnessForColor(background);
  if (brightness == Brightness.dark) {
    return Colors.white;
  }
  if (brightness == Brightness.light) {
    return const Color(0xFF1C1B1F);
  }
  return fallback;
}
