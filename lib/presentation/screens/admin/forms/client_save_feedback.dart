import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

String formatClientSaveError(Object error) {
  if (error is TimeoutException) {
    return 'Il salvataggio del cliente sta impiegando troppo tempo. Riprova.';
  }
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'Non hai i permessi per salvare questo cliente.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'I servizi online non rispondono. Riprova tra poco.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          return 'Errore durante il salvataggio: $message';
        }
    }
  }

  final message = error.toString();
  if (message.contains('network-request-failed')) {
    return 'Connessione non disponibile. Il cliente non e stato salvato.';
  }
  if (message.contains('permission-denied')) {
    return 'Non hai i permessi per salvare questo cliente.';
  }
  return 'Errore durante il salvataggio: $message';
}
