import 'package:cloud_functions/cloud_functions.dart';

class WebClientRequestService {
  WebClientRequestService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<String?> submit({
    required String salonId,
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required bool privacyAccepted,
    required bool marketingAccepted,
    DateTime? dateOfBirth,
    Map<String, dynamic> extraData = const <String, dynamic>{},
    String? sourceUrl,
    String? referrer,
    String? utmSource,
    String? utmMedium,
    String? utmCampaign,
    String website = '',
    String? promotionId,
  }) async {
    final callable = _functions.httpsCallable('submitWebClientRequest');
    final response = await callable.call(<String, dynamic>{
      'salonId': salonId,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'email': email,
      'privacyAccepted': privacyAccepted,
      'marketingAccepted': marketingAccepted,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
      'extraData': extraData,
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
      if (referrer != null) 'referrer': referrer,
      if (utmSource != null) 'utmSource': utmSource,
      if (utmMedium != null) 'utmMedium': utmMedium,
      if (utmCampaign != null) 'utmCampaign': utmCampaign,
      'website': website,
      if (promotionId != null) 'promotionId': promotionId,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['requestId'] as String?;
  }

  Future<String?> process({
    required String requestId,
    required String action,
    String? linkedClientId,
  }) async {
    final callable = _functions.httpsCallable('processWebClientRequest');
    final response = await callable.call(<String, dynamic>{
      'requestId': requestId,
      'action': action,
      if (linkedClientId != null) 'linkedClientId': linkedClientId,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['clientId'] as String?;
  }
}
