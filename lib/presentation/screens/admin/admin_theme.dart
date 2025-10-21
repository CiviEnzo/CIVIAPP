import 'package:flutter/material.dart';

class AdminPalette {
  const AdminPalette({required this.primary, required this.accent});

  final Color primary;
  final Color accent;

  static const AdminPalette defaults = AdminPalette(
    primary: Color.fromARGB(255, 255, 255, 255),
    accent: Color.fromARGB(255, 104, 38, 38),
  );
}

class AdminThemeData {
  const AdminThemeData({
    required this.theme,
    required this.colorScheme,
    required this.palette,
    required this.layer0,
    required this.layer1,
    required this.layer2,
    required this.layer3,
    required this.layer4,
    required this.moduleBackground,
    required this.softShadowColor,
    required this.mediumShadowColor,
    required this.strongShadowColor,
    required this.baseCardElevation,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final AdminPalette palette;
  final Color layer0;
  final Color layer1;
  final Color layer2;
  final Color layer3;
  final Color layer4;
  final Color moduleBackground;
  final Color softShadowColor;
  final Color mediumShadowColor;
  final Color strongShadowColor;
  final double baseCardElevation;

  Color layer(int depth) {
    switch (depth) {
      case 0:
        return layer0;
      case 1:
        return layer1;
      case 2:
        return layer2;
      case 3:
        return layer3;
      default:
        return layer4;
    }
  }
}

class AdminTheme extends StatelessWidget {
  const AdminTheme({
    required this.child,
    this.palette = AdminPalette.defaults,
    super.key,
  });

  final Widget child;
  final AdminPalette palette;

  static AdminThemeData of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_AdminThemeScope>();
    assert(
      scope != null,
      'AdminTheme.of() called with a context that does '
      'not contain an AdminTheme.',
    );
    return scope!.data;
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final brightness = baseTheme.brightness;
    final seedScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      secondary: palette.accent,
      tertiary: palette.accent,
    );

    const lightSectionBackground = Color(0xFFF4F5F7);
    final isLight = brightness == Brightness.light;

    ColorScheme tintForDark(ColorScheme scheme) {
      if (!isLight) {
        Color tintSurface(Color target, double darkElevation) =>
            ElevationOverlay.applySurfaceTint(
              target,
              scheme.surfaceTint,
              darkElevation,
            );

        return scheme.copyWith(
          surface: tintSurface(scheme.surface, 1),
          surfaceContainerLowest: tintSurface(scheme.surfaceContainerLowest, 1),
          surfaceContainerLow: tintSurface(scheme.surfaceContainerLow, 2),
          surfaceContainer: tintSurface(scheme.surfaceContainer, 4),
          surfaceContainerHigh: tintSurface(scheme.surfaceContainerHigh, 6),
          surfaceContainerHighest: tintSurface(
            scheme.surfaceContainerHighest,
            8,
          ),
        );
      }
      return scheme;
    }

    final adminSchemeBase = seedScheme.copyWith(
      surface: isLight ? Colors.white : seedScheme.surface,
      background: isLight ? Colors.white : seedScheme.background,
      surfaceContainerLowest:
          isLight ? Colors.white : seedScheme.surfaceContainerLowest,
      surfaceContainerLow:
          isLight ? lightSectionBackground : seedScheme.surfaceContainerLow,
      surfaceContainer:
          isLight ? lightSectionBackground : seedScheme.surfaceContainer,
      surfaceContainerHigh:
          isLight ? Colors.white : seedScheme.surfaceContainerHigh,
      surfaceContainerHighest:
          isLight ? Colors.white : seedScheme.surfaceContainerHighest,
      surfaceTint: isLight ? Colors.transparent : seedScheme.surfaceTint,
    );
    final adminScheme = tintForDark(adminSchemeBase);

    final scaffoldBackground =
        isLight
            ? Colors.white
            : ElevationOverlay.applySurfaceTint(
              adminScheme.surface,
              adminScheme.surfaceTint,
              1,
            );
    final canvasColor = scaffoldBackground;
    final cardBaseColor =
        isLight ? Colors.white : adminScheme.surfaceContainerHigh;
    final double baseCardElevation = isLight ? 2 : 6;

    final shadowOpacity = isLight ? 0.12 : 0.65;
    final mediumShadowOpacity = isLight ? 0.08 : 0.48;
    final softShadowOpacity = isLight ? 0.04 : 0.36;
    final moduleBackground =
        isLight
            ? lightSectionBackground
            : ElevationOverlay.applySurfaceTint(
              adminScheme.surface,
              adminScheme.surfaceTint,
              2,
            );

    final adminTheme = baseTheme.copyWith(
      colorScheme: adminScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: canvasColor,
      cardTheme: baseTheme.cardTheme.copyWith(
        color: cardBaseColor,
        elevation: baseCardElevation + (isLight ? 0 : 2),
        shadowColor: Colors.black.withOpacity(shadowOpacity),
        surfaceTintColor: isLight ? Colors.transparent : adminScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
      ),
      cardColor: cardBaseColor,
      dividerTheme: baseTheme.dividerTheme.copyWith(
        color: adminScheme.outlineVariant.withOpacity(
          brightness == Brightness.dark ? 0.6 : 0.35,
        ),
        thickness: 1,
        space: 0.8,
      ),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: adminScheme.surfaceContainerLowest,
        foregroundColor: adminScheme.onSurface,
        elevation: 0,
      ),
      navigationRailTheme: baseTheme.navigationRailTheme.copyWith(
        backgroundColor: adminScheme.surfaceContainerLowest,
        indicatorColor: adminScheme.primary.withOpacity(
          brightness == Brightness.dark ? 0.24 : 0.18,
        ),
        elevation: 0,
        selectedIconTheme: IconThemeData(color: adminScheme.primary),
        selectedLabelTextStyle: baseTheme.textTheme.labelLarge?.copyWith(
          color: adminScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: baseTheme.textTheme.labelLarge?.copyWith(
          color: adminScheme.onSurfaceVariant.withOpacity(0.7),
        ),
      ),
      drawerTheme: baseTheme.drawerTheme.copyWith(
        backgroundColor:
            isLight ? Colors.white : adminScheme.surfaceContainerLow,
      ),
      dialogTheme: baseTheme.dialogTheme.copyWith(
        backgroundColor: adminScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: adminScheme.surfaceContainerHighest,
        side: BorderSide(color: adminScheme.outlineVariant.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(softShadowOpacity),
      ),
    );

    final data = AdminThemeData(
      theme: adminTheme,
      colorScheme: adminScheme,
      palette: palette,
      layer0: adminScheme.surfaceContainerLowest,
      layer1:
          isLight ? lightSectionBackground : adminScheme.surfaceContainerLow,
      layer2: cardBaseColor,
      layer3: isLight ? Colors.white : adminScheme.surfaceContainerHigh,
      layer4: isLight ? Colors.white : adminScheme.surfaceContainerHighest,
      moduleBackground: moduleBackground,
      softShadowColor: Colors.black.withOpacity(softShadowOpacity),
      mediumShadowColor: Colors.black.withOpacity(mediumShadowOpacity),
      strongShadowColor: Colors.black.withOpacity(shadowOpacity),
      baseCardElevation: baseCardElevation,
    );

    return _AdminThemeScope(
      data: data,
      child: Theme(data: adminTheme, child: child),
    );
  }
}

class _AdminThemeScope extends InheritedWidget {
  const _AdminThemeScope({required this.data, required super.child});

  final AdminThemeData data;

  @override
  bool updateShouldNotify(_AdminThemeScope oldWidget) => data != oldWidget.data;
}
