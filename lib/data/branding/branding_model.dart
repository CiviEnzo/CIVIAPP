import 'package:flutter/material.dart';

class BrandingModel {
  const BrandingModel({
    required this.primaryColor,
    required this.accentColor,
    required this.themeMode,
    this.logoUrl,
    this.appBarStyle,
  });

  final String primaryColor;
  final String accentColor;
  final String themeMode;
  final String? logoUrl;
  final String? appBarStyle;

  factory BrandingModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const BrandingModel(
        primaryColor: '#1F2937',
        accentColor: '#A855F7',
        themeMode: 'system',
      );
    }
    return BrandingModel(
      primaryColor: data['primaryColor'] as String? ?? '#1F2937',
      accentColor: data['accentColor'] as String? ?? '#A855F7',
      themeMode: data['themeMode'] as String? ?? 'system',
      logoUrl: data['logoUrl'] as String?,
      appBarStyle: data['appBarStyle'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'primaryColor': primaryColor,
      'accentColor': accentColor,
      'themeMode': themeMode,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (appBarStyle != null) 'appBarStyle': appBarStyle,
    };
  }

  ColorScheme toColorScheme(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: _parseColor(primaryColor),
      secondary: _parseColor(accentColor),
      brightness: brightness,
    );
  }

  ThemeMode resolveThemeMode() {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Color _parseColor(String value) {
    final buffer = StringBuffer();
    if (!value.startsWith('#')) buffer.write('#');
    buffer.write(value.replaceAll('#', ''));
    final hex = int.parse(buffer.toString().substring(1), radix: 16);
    return Color(0xFF000000 | hex);
  }
}
