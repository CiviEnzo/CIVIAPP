# Registrazione Cliente – Metodi Avanzati

Questo documento raccoglie i passaggi consigliati per arricchire il flusso di creazione account cliente con i provider Apple, Google, email con verifica e numero di telefono. Gli esempi fanno riferimento a un'architettura Flutter con `AuthenticationRepository` + `AuthController`, ma i concetti si applicano a qualunque stack.

## Struttura consigliata

1. **Dominio** – definire un'interfaccia unica (`AuthRepository`) con metodi come `signInWithApple()`, `signUpWithEmail()`, `verifyEmailLink()`, `signInWithPhone()` ecc. In questo modo il livello di presentazione dipende da un'unica API.
2. **Use case / controller** – incapsulare la logica asincrona (loading, errori, routing). Nel caso di Flutter, un `Notifier`/`Cubit` deve esporre `registerWithEmail`, `registerWithApple`, ecc., così la UI chiama solo funzioni ad alto livello.
3. **UI** – creare una lista di azioni (`RegistrationMethod`, icona + label + callback). Questo permette di aggiungere/rimuovere provider senza toccare il layout principale (`services_module.dart` o i widget del login).

```dart
class RegistrationMethod {
  final String label;
  final IconData icon;
  final Future<void> Function() action;
}
```

## Apple Sign-In

1. **Prerequisiti** – configurare il bundle ID Apple, aggiungere Sign in with Apple nel portale developer e nel file `Runner/Info.plist`.
2. **Pacchetto Flutter** – `sign_in_with_apple`. Dal repository chiamare `SignInWithApple.getAppleIDCredential(scopes: [...])` e usare l'`authorizationCode` per creare la `OAuthCredential` di Firebase (`OAuthProvider("apple.com")`).
3. **Onboarding** – Apple fornisce solo nome/cognome alla prima autorizzazione; salvarli subito nel profilo e prevedere un fallback UI per completarli se mancanti.
4. **Testing** – provare sia con account reali sia con "Sign in with Apple" sandbox. Verificare i casi in cui l'utente annulla la finestra e gestire `SignInWithAppleAuthorizationException`.

## Email + Password con verifica

1. **Registrazione** – `createUserWithEmailAndPassword`. Subito dopo inviare l'email di verifica (`user.sendEmailVerification()`).
2. **Blocco accesso** – impedire la navigazione oltre lo step successivo se `user.emailVerified` è `false`. Mostrare CTA "Ho già verificato" che richiama `user.reload()` e controlla nuovamente il flag.
3. **Resend** – consentire l'invio di un nuovo link dopo un cooldown (es. 60 s) per evitare abuso.
4. **Deep link** – configurare Firebase Dynamic Links / App Links per intercettare la verifica direttamente nell'app e completare il flusso senza ri-apertura manuale.

## Numero di telefono (OTP SMS)

1. **Verifica** – usare `FirebaseAuth.verifyPhoneNumber`. Gestire i callback:
   - `codeSent` → mostrare input OTP.
   - `verificationCompleted` → login automatico se Android auto-retrieval.
   - `codeAutoRetrievalTimeout` → permettere reinvio.
2. **UI/UX** – validare il prefisso internazionale, mostrare timer, offrire alternativa "Chiamata vocale" se disponibile.
3. **Protezione** – attivare reCAPTCHA v3 (Android) e SafetyNet/DeviceCheck per limitare abuso.
4. **Account linking** – se l'utente ha già email/Apple, linkare il telefono (`user.linkWithCredential`) per evitare duplicati.

## Google Sign-In

1. **Setup** – creare OAuth Client ID per i pacchetti Android/iOS, aggiungere file `GoogleService-Info.plist` e aggiornare `android/app/google-services.json`.
2. **Pacchetto** – `google_sign_in`. Recuperare il `GoogleSignInAccount`, quindi `GoogleAuthProvider.credential(idToken, accessToken)` per autenticarsi.
3. **Consistenza dati** – utilizzare la stessa pipeline profilo (avatar, name) degli altri provider per evitare difformità nell'UI cliente.

## Considerazioni comuni

- **Gestione errori** – normalizzare gli errori (`AuthFailure.invalidCredential`, `network`, `cancelled`) in modo che la UI mostri messaggi uniformi.
- **Linking provider** – consentire all'utente di aggiungere provider secondari dalla schermata profilo, richiamando `linkWithCredential`.
- **Analytics** – tracciare quale metodo viene scelto per misurare conversioni e abbandoni.
- **Test end-to-end** – utilizzare Firebase Emulator Suite o account di test per ogni provider per non consumare traffico reale.

## Prossimi passi operativi

1. Aggiornare `pubspec.yaml` con i pacchetti necessari (`sign_in_with_apple`, `google_sign_in`, `firebase_auth` >= 4, eventuali helper OTP).
2. Implementare nel repository le nuove funzioni e coprirle con unit test mockando FirebaseAuth.
3. Adeguare la UI (`lib/presentation/screens/.../services_module.dart`) sostituendo la lista statica di pulsanti con i `RegistrationMethod`.
4. Aggiornare la documentazione di QA includendo checklist per ogni provider (login, logout, linking, errori).
