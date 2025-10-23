import 'package:flutter/material.dart';

import '../theme/glass_palette.dart';
import 'glass_container.dart';

enum GlassCardStyle { glass, solid }

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius,
    this.backgroundOpacity,
    this.highlightOpacity,
    this.blur,
    this.showBorder,
    this.boxShadow,
    this.tintColor,
    this.shape,
    this.color,
    this.surfaceTintColor,
    this.shadowColor,
    this.elevation,
    this.clipBehavior,
    this.style = GlassCardStyle.glass,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double? backgroundOpacity;
  final double? highlightOpacity;
  final double? blur;
  final bool? showBorder;
  final List<BoxShadow>? boxShadow;
  final Color? tintColor;
  final ShapeBorder? shape;
  final Color? color;
  final Color? surfaceTintColor;
  final Color? shadowColor;
  final double? elevation;
  final Clip? clipBehavior;
  final GlassCardStyle style;

  @override
  Widget build(BuildContext context) {
    BorderRadius resolveBorderRadius() {
      if (borderRadius != null) {
        return borderRadius!;
      }
      final resolvedShape = shape;
      if (resolvedShape is RoundedRectangleBorder) {
        return resolvedShape.borderRadius.resolve(Directionality.of(context));
      }
      if (resolvedShape is ContinuousRectangleBorder) {
        return resolvedShape.borderRadius.resolve(Directionality.of(context));
      }
      return const BorderRadius.all(Radius.circular(28));
    }

    final effectiveBorderRadius = resolveBorderRadius();
    final effectiveMargin = margin ?? const EdgeInsets.symmetric(vertical: 4);
    final effectivePadding = padding ?? EdgeInsets.zero;

    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool isSolid = style == GlassCardStyle.solid;
    final double resolvedElevation =
        (elevation ?? (isSolid ? (isDark ? 10 : 6) : (isDark ? 8 : 4)))
            .toDouble();
    final double elevationFactor = resolvedElevation.clamp(0, 18);
    final Color resolvedShadowColor = (shadowColor ?? Colors.black).withValues(
      alpha: isSolid ? (isDark ? 0.32 : 0.12) : (isDark ? 0.22 : 0.08),
    );
    final List<BoxShadow> effectiveShadow =
        boxShadow ??
        [
          BoxShadow(
            color: resolvedShadowColor,
            blurRadius: 18 + elevationFactor * 1.1,
            offset: Offset(0, 8 + elevationFactor * 0.4),
            spreadRadius: -6 + elevationFactor * -0.15,
          ),
        ];
    final Clip resolvedClip = clipBehavior ?? Clip.antiAlias;
    final Color? requestedTint = tintColor ?? color ?? surfaceTintColor;

    final double defaultBackgroundOpacity =
        backgroundOpacity ??
        (isSolid ? (isDark ? 0.38 : 0.26) : (isDark ? 0.24 : 0.16));
    final double defaultHighlightOpacity =
        highlightOpacity ??
        (isSolid ? (isDark ? 0.52 : 0.36) : (isDark ? 0.32 : 0.22));
    final double defaultBlur = blur ?? (isSolid ? 22 : 16);
    final bool effectiveBorder = showBorder ?? isSolid;

    return GlassContainer(
      tone: GlassToneType.card,
      margin: effectiveMargin,
      padding: effectivePadding,
      borderRadius: effectiveBorderRadius,
      backgroundOpacity: defaultBackgroundOpacity,
      highlightOpacity: defaultHighlightOpacity,
      blur: defaultBlur,
      showBorder: effectiveBorder,
      boxShadow: effectiveShadow,
      tintColor: requestedTint,
      clipBehavior: resolvedClip,
      child: child,
    );
  }
}
