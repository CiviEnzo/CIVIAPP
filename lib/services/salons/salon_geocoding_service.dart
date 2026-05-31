import 'package:cloud_functions/cloud_functions.dart';

class SalonGeocodingService {
  SalonGeocodingService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<List<SalonGeocodingCandidate>> geocodeAddress({
    String? salonId,
    required String address,
    required String city,
    String? postalCode,
  }) async {
    final callable = _functions.httpsCallable('geocodeSalonAddress');
    final response = await callable.call({
      if (salonId != null && salonId.trim().isNotEmpty)
        'salonId': salonId.trim(),
      'address': address.trim(),
      'city': city.trim(),
      if (postalCode != null && postalCode.trim().isNotEmpty)
        'postalCode': postalCode.trim(),
      'country': 'Italia',
    });

    final responseData = response.data;
    final rawCandidates =
        responseData is Map ? responseData['candidates'] : null;
    if (rawCandidates is! List) {
      return const <SalonGeocodingCandidate>[];
    }
    return rawCandidates
        .whereType<Map>()
        .map(SalonGeocodingCandidate.fromMap)
        .whereType<SalonGeocodingCandidate>()
        .toList(growable: false);
  }
}

class SalonGeocodingCandidate {
  const SalonGeocodingCandidate({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.locationType,
  });

  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? placeId;
  final String? locationType;

  static SalonGeocodingCandidate? fromMap(Map<dynamic, dynamic> map) {
    final latitude = _readDouble(map['latitude']);
    final longitude = _readDouble(map['longitude']);
    if (latitude == null || longitude == null) {
      return null;
    }
    return SalonGeocodingCandidate(
      formattedAddress: (map['formattedAddress'] as String?)?.trim() ?? '',
      latitude: latitude,
      longitude: longitude,
      placeId: (map['placeId'] as String?)?.trim(),
      locationType: (map['locationType'] as String?)?.trim(),
    );
  }

  static double? _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
