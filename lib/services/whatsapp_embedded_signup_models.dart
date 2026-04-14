enum WhatsAppEmbeddedSignupPhase {
  idle,
  sessionCreated,
  signupCompleted,
  registering,
  awaitingVerification,
  ready,
  error,
}

enum WhatsAppVerificationCodeMethod { sms, voice }

class WhatsAppEmbeddedSignupSession {
  const WhatsAppEmbeddedSignupSession({
    required this.salonId,
    required this.sessionId,
    required this.sessionToken,
    required this.appId,
    required this.configId,
    required this.graphApiVersion,
  });

  final String salonId;
  final String sessionId;
  final String sessionToken;
  final String appId;
  final String configId;
  final String graphApiVersion;
}

class WhatsAppEmbeddedSignupLaunchResult {
  const WhatsAppEmbeddedSignupLaunchResult({
    required this.code,
    this.businessId,
    this.wabaId,
    this.phoneNumberId,
    this.displayPhoneNumber,
    this.verifiedName,
    this.rawPayload,
  });

  final String code;
  final String? businessId;
  final String? wabaId;
  final String? phoneNumberId;
  final String? displayPhoneNumber;
  final String? verifiedName;
  final Map<String, dynamic>? rawPayload;
}

class WhatsAppEmbeddedSignupResult {
  const WhatsAppEmbeddedSignupResult({
    required this.phase,
    required this.onboardingStatus,
    required this.registrationStatus,
    this.phoneNumberId,
    this.displayPhoneNumber,
    this.sessionId,
    this.codeMethod,
  });

  final WhatsAppEmbeddedSignupPhase phase;
  final String onboardingStatus;
  final String registrationStatus;
  final String? phoneNumberId;
  final String? displayPhoneNumber;
  final String? sessionId;
  final WhatsAppVerificationCodeMethod? codeMethod;
}
