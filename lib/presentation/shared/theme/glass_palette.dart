import 'package:flutter/material.dart';

enum GlassToneType { container, card, button }

class GlassShadowSpec {
  const GlassShadowSpec({
    required this.color,
    required this.blurRadius,
    required this.offset,
    required this.spreadRadius,
  });

  final Color color;
  final double blurRadius;
  final Offset offset;
  final double spreadRadius;

  BoxShadow toBoxShadow() => BoxShadow(
    color: color,
    blurRadius: blurRadius,
    offset: offset,
    spreadRadius: spreadRadius,
  );
}

class GlassTone {
  const GlassTone({
    required this.base,
    required this.highlight,
    required this.border,
    required this.shadow,
  });

  final Color base;
  final Color highlight;
  final Color border;
  final GlassShadowSpec shadow;

  GlassTone copyWith({
    Color? base,
    Color? highlight,
    Color? border,
    GlassShadowSpec? shadow,
  }) {
    return GlassTone(
      base: base ?? this.base,
      highlight: highlight ?? this.highlight,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
    );
  }
}

class GlassPalette {
  GlassPalette._();

  static GlassTone _container = GlassTone(
    base: const Color(0xFFF8FAFF),
    highlight: Colors.white,
    border: Colors.black.withOpacity(0.08),
    shadow: GlassShadowSpec(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 28,
      offset: const Offset(0, 14),
      spreadRadius: -12,
    ),
  );

  static GlassTone _card = GlassTone(
    base: Colors.white,
    highlight: const Color(0xFFF0F4FF),
    border: Colors.black.withOpacity(0.1),
    shadow: GlassShadowSpec(
      color: Colors.black.withOpacity(0.14),
      blurRadius: 24,
      offset: const Offset(0, 12),
      spreadRadius: -10,
    ),
  );
  static GlassTone _button = GlassTone(
    base: const Color(0xFFE2ECFF),
    highlight: Colors.white,
    border: Colors.white.withValues(alpha: 0.36),
    shadow: GlassShadowSpec(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 22,
      offset: const Offset(0, 14),
      spreadRadius: -10,
    ),
  );

  static GlassTone toneFor(GlassToneType tone) {
    switch (tone) {
      case GlassToneType.container:
        return _container;
      case GlassToneType.card:
        return _card;
      case GlassToneType.button:
        return _button;
    }
  }

  static void configure({
    GlassTone? containerTone,
    GlassTone? cardTone,
    GlassTone? buttonTone,
  }) {
    if (containerTone != null) {
      _container = containerTone;
    }
    if (cardTone != null) {
      _card = cardTone;
    }
    if (buttonTone != null) {
      _button = buttonTone;
    }
  }
}
