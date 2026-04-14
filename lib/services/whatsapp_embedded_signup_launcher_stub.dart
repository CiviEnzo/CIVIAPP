import 'whatsapp_embedded_signup_launcher.dart';
import 'whatsapp_embedded_signup_models.dart';

class UnsupportedWhatsAppEmbeddedSignupLauncher
    implements WhatsAppEmbeddedSignupLauncher {
  @override
  Future<WhatsAppEmbeddedSignupLaunchResult> launch(
    WhatsAppEmbeddedSignupSession session,
  ) {
    throw UnsupportedError(
      'Embedded Signup e supportato solo nel pannello admin web.',
    );
  }
}

WhatsAppEmbeddedSignupLauncher createWhatsAppEmbeddedSignupLauncher() {
  return UnsupportedWhatsAppEmbeddedSignupLauncher();
}
