import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:you_book/presentation/common/auth_error_messages.dart';

void main() {
  test('translates invalid credentials without exposing technical details', () {
    final error = FirebaseAuthException(
      code: 'invalid-credential',
      message: 'The supplied auth credential is incorrect.',
    );

    expect(
      italianLoginErrorMessage(error),
      'Email o password non corrette. Controlla i dati e riprova.',
    );
  });

  test('translates login network errors', () {
    final error = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'A network error has occurred.',
    );

    expect(
      italianLoginErrorMessage(error),
      'Connessione assente o instabile. Controlla la rete e riprova.',
    );
  });

  test('uses a clear generic login fallback without the raw error', () {
    const rawError = 'Internal English authentication error';

    final message = italianLoginErrorMessage(Exception(rawError));

    expect(
      message,
      'Accesso non riuscito. Controlla i dati inseriti e riprova tra poco.',
    );
    expect(message, isNot(contains(rawError)));
  });
}
