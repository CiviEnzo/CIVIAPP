import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/glass_palette.dart';

/// Glassmorphism container used to reproduce the iOS liquid glass look.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    BorderRadius? borderRadius,
    this.blur = 18, // da 26 → 18 per meno "nebbia"
    this.backgroundOpacity = 0.12, // da 0.08 → 0.12
    this.highlightOpacity = 0.28, // da 0.24 → 0.28
    this.showBorder = true,
    this.boxShadow,
    this.tintColor,
    this.clipBehavior = Clip.antiAlias,
    this.tone = GlassToneType.container,
  }) : borderRadius =
           borderRadius ?? const BorderRadius.all(Radius.circular(20));

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final double blur;
  final double backgroundOpacity;
  final double highlightOpacity;
  final bool showBorder;
  final List<BoxShadow>? boxShadow;
  final Color? tintColor;
  final Clip clipBehavior;
  final GlassToneType tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final toneSpec = GlassPalette.toneFor(tone);
    final overlayBase = tintColor ?? toneSpec.base;
    final highlightBase =
        tintColor == null
            ? toneSpec.highlight
            : Color.lerp(
                  overlayBase,
                  toneSpec.highlight,
                  isDark ? 0.6 : 0.85,
                ) ??
                toneSpec.highlight;
    final backgroundBase =
        tintColor == null
            ? toneSpec.base
            : Color.lerp(overlayBase, toneSpec.base, isDark ? 0.4 : 0.9) ??
                toneSpec.base;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        highlightBase.withValues(
          alpha: isDark ? highlightOpacity * 0.6 : highlightOpacity + 0.06,
        ),
        backgroundBase.withValues(
          alpha: isDark ? backgroundOpacity * 0.65 : backgroundOpacity + 0.05,
        ),
      ],
    );
    final borderColor = toneSpec.border;
    final effectiveShadows = boxShadow ?? [toneSpec.shadow.toBoxShadow()];

    Widget content = ClipRRect(
      clipBehavior: clipBehavior,
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: gradient,
            border:
                showBorder
                    ? Border.all(
                      color: borderColor.withOpacity(isDark ? 0.28 : 0.12),
                      width: 1.2,
                    )
                    : null,
            borderRadius: borderRadius,
            boxShadow: effectiveShadows,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ),
      ),
    );

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
