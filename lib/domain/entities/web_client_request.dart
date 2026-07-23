enum WebClientRequestStatus { newRequest, accepted, rejected, archived }

class WebClientRequestConsent {
  const WebClientRequestConsent({
    required this.privacyAccepted,
    required this.privacyVersion,
    this.privacyAcceptedAt,
    this.marketingAccepted = false,
    this.marketingAcceptedAt,
  });

  final bool privacyAccepted;
  final String privacyVersion;
  final DateTime? privacyAcceptedAt;
  final bool marketingAccepted;
  final DateTime? marketingAcceptedAt;
}

class WebClientRequest {
  const WebClientRequest({
    required this.id,
    required this.salonId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.status,
    required this.consents,
    this.dateOfBirth,
    this.extraData = const <String, dynamic>{},
    this.source = 'website',
    this.sourceUrl,
    this.referrer,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.duplicateCandidateClientIds = const <String>[],
    this.linkedClientId,
    this.createdAt,
    this.updatedAt,
    this.processedAt,
    this.processedBy,
    this.promotionId,
    this.promotionTitle,
  });

  final String id;
  final String salonId;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final DateTime? dateOfBirth;
  final Map<String, dynamic> extraData;
  final WebClientRequestStatus status;
  final String source;
  final String? sourceUrl;
  final String? referrer;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final WebClientRequestConsent consents;
  final List<String> duplicateCandidateClientIds;
  final String? linkedClientId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String? promotionId;
  final String? promotionTitle;

  String get fullName => '$firstName $lastName'.trim();
  bool get isNew => status == WebClientRequestStatus.newRequest;
  bool get hasPossibleDuplicates => duplicateCandidateClientIds.isNotEmpty;
}
