import 'package:firebase_auth/firebase_auth.dart';

String italianLoginErrorMessage(Object error) {
  final code =
      error is FirebaseAuthException ? error.code.trim().toLowerCase() : '';
  final rawMessage =
      error is FirebaseAuthException
          ? '${error.code} ${error.message ?? ''}'
          : error.toString();
  final normalized = rawMessage.toLowerCase();

  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'Email o password non corrette. Controlla i dati e riprova.';
    case 'invalid-email':
      return 'L’indirizzo email non è valido. Controllalo e riprova.';
    case 'user-disabled':
      return 'Questo account è stato disabilitato. Contatta l’assistenza.';
    case 'too-many-requests':
      return 'Hai effettuato troppi tentativi. Attendi qualche minuto e riprova.';
    case 'network-request-failed':
      return 'Connessione assente o instabile. Controlla la rete e riprova.';
    case 'operation-not-allowed':
      return 'L’accesso con email e password non è disponibile. Contatta l’assistenza.';
    case 'email-not-verified':
      return 'Email non ancora verificata. Apri il messaggio ricevuto e conferma il tuo indirizzo.';
    case 'admin-not-enabled':
      return 'Il tuo account è in attesa di abilitazione.';
    case 'user-profile-not-found':
    case 'user-profile-email-mismatch':
      return 'L’account non è associato a un profilo autorizzato. Contatta il salone.';
    case 'user-profile-check-failed':
      return 'Non riusciamo a verificare il tuo profilo. Controlla la connessione e riprova.';
  }

  if (_containsAny(normalized, const [
    'invalid-credential',
    'wrong-password',
    'user-not-found',
    'invalid login credentials',
    'incorrect password',
  ])) {
    return 'Email o password non corrette. Controlla i dati e riprova.';
  }
  if (_containsAny(normalized, const [
    'network-request-failed',
    'network error',
    'socketexception',
    'failed host lookup',
    'timeout',
  ])) {
    return 'Connessione assente o instabile. Controlla la rete e riprova.';
  }
  if (normalized.contains('too-many-requests')) {
    return 'Hai effettuato troppi tentativi. Attendi qualche minuto e riprova.';
  }
  if (normalized.contains('email-not-verified')) {
    return 'Email non ancora verificata. Apri il messaggio ricevuto e conferma il tuo indirizzo.';
  }
  if (normalized.contains('admin-not-enabled')) {
    return 'Il tuo account è in attesa di abilitazione.';
  }

  return 'Accesso non riuscito. Controlla i dati inseriti e riprova tra poco.';
}

bool _containsAny(String value, List<String> patterns) {
  return patterns.any(value.contains);
}
