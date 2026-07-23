import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/domain/entities/public_salon.dart';
import 'package:you_book/domain/entities/salon.dart';

void main() {
  test('parses public web registration configuration', () {
    final salon = PublicSalon.fromMap('salon-1', <String, dynamic>{
      'name': 'Salon Test',
      'address': 'Via Roma 1',
      'city': 'Roma',
      'phone': '0612345678',
      'email': 'salon@example.com',
      'status': 'active',
      'clientRegistration': <String, dynamic>{
        'accessMode': 'approval',
        'extraFields': <String>['profession', 'referralSource'],
        'webFormEnabled': true,
        'webFormTitle': 'Entra nel nostro mondo',
        'webFormDescription': 'Lasciaci i tuoi dati.',
        'webFormConfirmationMessage': 'Richiesta ricevuta.',
        'privacyPolicyUrl': 'https://example.com/privacy',
        'privacyVersion': '2026-07',
        'marketingConsentEnabled': false,
        'webThemeColor': '#8A493A',
        'webFontFamily': 'playfairDmSans',
      },
    });

    final settings = salon.clientRegistration;
    expect(settings.webFormEnabled, isTrue);
    expect(settings.webFormTitle, 'Entra nel nostro mondo');
    expect(settings.webFormDescription, 'Lasciaci i tuoi dati.');
    expect(settings.webFormConfirmationMessage, 'Richiesta ricevuta.');
    expect(settings.privacyPolicyUrl, 'https://example.com/privacy');
    expect(settings.privacyVersion, '2026-07');
    expect(settings.marketingConsentEnabled, isFalse);
    expect(settings.webThemeColor, '#8A493A');
    expect(settings.webFontFamily, 'playfairDmSans');
    expect(settings.accessMode, ClientRegistrationAccessMode.approval);
    expect(
      settings.extraFields,
      containsAll(<ClientRegistrationExtraField>[
        ClientRegistrationExtraField.profession,
        ClientRegistrationExtraField.referralSource,
      ]),
    );
  });

  test('web registration is disabled for legacy public salon data', () {
    final salon = PublicSalon.fromMap('legacy', <String, dynamic>{
      'name': 'Legacy',
      'address': '',
      'city': '',
      'phone': '',
      'email': '',
    });

    expect(salon.clientRegistration.webFormEnabled, isFalse);
    expect(salon.clientRegistration.privacyVersion, '1');
    expect(salon.clientRegistration.webThemeColor, '#6750A4');
    expect(salon.clientRegistration.webFontFamily, 'system');
  });
}
