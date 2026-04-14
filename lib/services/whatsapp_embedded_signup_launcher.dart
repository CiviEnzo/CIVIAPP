import 'whatsapp_embedded_signup_models.dart';

abstract class WhatsAppEmbeddedSignupLauncher {
  Future<WhatsAppEmbeddedSignupLaunchResult> launch(
    WhatsAppEmbeddedSignupSession session,
  );
}
