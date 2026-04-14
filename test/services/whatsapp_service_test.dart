import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/services/whatsapp_service.dart';

void main() {
  test('WhatsAppConfig flags legacy connections for reconnect', () {
    final config = WhatsAppConfig.fromMap(
      <String, dynamic>{
        'mode': 'own',
        'businessId': 'business-1',
        'wabaId': 'waba-1',
        'phoneNumberId': 'phone-1',
        'tokenSecretId': 'legacy-token',
      },
      salonId: 'salon-1',
    );

    expect(config.needsReconnect, isTrue);
    expect(config.isConfigured, isFalse);
  });

  test('WhatsAppConfig is configured only when number is ready and registered', () {
    final config = WhatsAppConfig.fromMap(
      <String, dynamic>{
        'mode': 'own',
        'businessId': 'business-1',
        'wabaId': 'waba-1',
        'phoneNumberId': 'phone-1',
        'connectionMethod': 'embedded_signup',
        'onboardingStatus': 'ready',
        'registrationStatus': 'registered',
      },
      salonId: 'salon-1',
    );

    expect(config.needsReconnect, isFalse);
    expect(config.needsVerification, isFalse);
    expect(config.isConfigured, isTrue);
  });
}
