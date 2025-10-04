import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:civiapp/data/branding/branding_model.dart';

final brandingCacheProvider = Provider<BrandingCache>((_) => BrandingCache());

class BrandingCache {
  final _preferences = SharedPreferences.getInstance();

  Future<void> save(String salonId, BrandingModel data) async {
    final prefs = await _preferences;
    await prefs.setString('branding_$salonId', jsonEncode(data.toMap()));
  }

  Future<BrandingModel?> read(String salonId) async {
    final prefs = await _preferences;
    final stored = prefs.getString('branding_$salonId');
    if (stored == null) return null;
    return BrandingModel.fromMap(jsonDecode(stored) as Map<String, dynamic>);
  }
}
