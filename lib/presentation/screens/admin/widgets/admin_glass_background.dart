import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class AdminGlassBackground extends StatelessWidget {
  const AdminGlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors:
          isDark
              ? const [Color(0xFF050816), Color(0xFF0E1330), Color(0xFF111832)]
              : const [Color(0xFFF5F7FF), Color(0xFFF1F5FF), Color(0xFFFFF7FB)],
    );
    final overlayColor =
        isDark ? const Color(0x80FFFFFF) : Colors.white.withValues(alpha: 0.8);

    return DecoratedBox(
      decoration: BoxDecoration(gradient: baseGradient),
      child: Stack(
        children: [
          Positioned(
            left: -180,
            top: -120,
            child: _GlassBlob(
              diameter: isDark ? 280 : 320,
              colors: [
                overlayColor.withValues(alpha: isDark ? 0.08 : 0.18),
                overlayColor.withValues(alpha: isDark ? 0.03 : 0.08),
              ],
              blurSigma: 120,
            ),
          ),
          Positioned(
            right: -120,
            top: 200,
            child: _GlassBlob(
              diameter: 240,
              rotation: -20,
              colors: [
                const Color(0xFF34D399).withValues(alpha: isDark ? 0.2 : 0.25),
                const Color(0xFF60A5FA).withValues(alpha: isDark ? 0.12 : 0.18),
              ],
              blurSigma: 90,
            ),
          ),
          Positioned(
            left: -80,
            bottom: -120,
            child: _GlassBlob(
              diameter: 250,
              rotation: 24,
              colors: [
                const Color(0xFFF472B6).withValues(alpha: isDark ? 0.18 : 0.24),
                const Color(0xFFFB7185).withValues(alpha: isDark ? 0.1 : 0.18),
              ],
              blurSigma: 110,
            ),
          ),
          Positioned(
            right: -40,
            bottom: -60,
            child: _GlassBlob(
              diameter: 160,
              colors: [
                const Color(0xFFA855F7).withValues(alpha: isDark ? 0.22 : 0.28),
                const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.21),
              ],
              blurSigma: 70,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.03 : 0.14),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _GlassBlob extends StatelessWidget {
  const _GlassBlob({
    required this.diameter,
    required this.colors,
    this.rotation = 0,
    this.blurSigma = 60,
  });

  final double diameter;
  final List<Color> colors;
  final double rotation;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation * math.pi / 180,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            gradient: SweepGradient(colors: colors, center: Alignment.topLeft),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
