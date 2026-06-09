# Primo accesso admin salone

## Obiettivo
Gestire il primo accesso di un admin salone mantenendo il controllo sulla creazione dell'account, evitando registrazioni libere e obbligando il cambio password al primo login.

## Decisione consigliata
Usare sempre Firebase Authentication per l'accesso e Firestore `/users/{uid}` per autorizzazione, ruolo e stato account.

Non salvare mai password temporanee in Firestore.

Firestore deve contenere solo metadati di accesso:

```json
{
  "email": "admin@salone.it",
  "displayName": "Nome Admin",
  "role": "admin",
  "roles": ["admin"],
  "availableRoles": ["admin"],
  "salonId": "salon_123",
  "salonIds": ["salon_123"],
  "enabled": true,
  "status": "active",
  "mustChangePassword": true,
  "createdAt": "serverTimestamp"
}
```

## Risposta alle domande

### Devo creare una mail con password temporanea su Firestore?
No. Per fare login serve un utente in Firebase Authentication. Firestore da solo non autentica l'utente.

La password temporanea deve stare solo in Firebase Auth, mai dentro `/users`. Il documento Firestore serve per dire: questo UID esiste, questa email e' autorizzata, questo utente e' admin, questo salone puo' gestire.

### Conviene configurare a mano `/users` e inserire il ruolo admin?
Per il controllo totale, si. Pero' il documento deve essere creato con ID uguale allo UID dell'utente Firebase Auth, non con la mail.

Flusso manuale accettabile per il primo salone:

1. Creare l'utente in Firebase Authentication con email e password temporanea.
2. Copiare lo UID generato da Firebase Auth.
3. Creare `/users/{uid}` in Firestore con `role: "admin"`, `salonIds`, `enabled: true`, `mustChangePassword: true`.
4. Creare o collegare il documento `/salons/{salonId}`.
5. Comunicare la password temporanea all'admin fuori dall'app.
6. Al primo login l'app obbliga il cambio password.

Soluzione piu' robusta dopo la fase manuale: creare uno script o una callable admin-only che crea insieme utente Auth, documento `/users/{uid}` e salone, cosi' non si rischiano mismatch tra UID, email e salone.

## Flusso login consigliato

1. L'admin inserisce email e password temporanea.
2. Firebase Auth autentica l'utente.
3. L'app legge `/users/{uid}`.
4. Se il documento non esiste: logout immediato e messaggio "Account non autorizzato".
5. Se `email` nel documento non coincide con l'email Auth: logout immediato.
6. Se `role != "admin"`: usare il routing del ruolo corretto o bloccare se il contesto e' admin.
7. Se `enabled != true`: logout e messaggio "Account in attesa di abilitazione".
8. Se `mustChangePassword == true`: mostrare schermata obbligatoria di cambio password.
9. Dopo cambio password riuscito: aggiornare `/users/{uid}.mustChangePassword` a `false`.
10. Solo dopo, entrare nella dashboard admin.

## Cambio password obbligatorio

Schermata dedicata consigliata: `/first-password-change`.

Regole UX:

- Non mostrare dashboard, moduli, salone, staff o dati prima del cambio password.
- Richiedere password attuale temporanea e nuova password.
- Validare nuova password con requisiti minimi.
- Chiamare `reauthenticateWithCredential(...)`.
- Chiamare `updatePassword(newPassword)`.
- Aggiornare Firestore con:

```json
{
  "mustChangePassword": false,
  "passwordChangedAt": "serverTimestamp"
}
```

Nota: lato client non si puo' dimostrare nelle Firestore Rules che la password sia stata davvero cambiata. Per maggiore sicurezza, si puo' usare una callable Cloud Function `completeFirstPasswordChange` che aggiorna password e flag nello stesso flusso.

## Impatto sulle permission denied attuali

Il problema visto al login nasce quando l'utente Auth esiste ma il documento `/users/{uid}` manca, e quindi le Firestore Rules non riescono a riconoscere ruolo e saloni autorizzati.

La correzione proposta e':

- non creare sessione applicativa valida se `/users/{uid}` non esiste;
- bloccare il login se la mail Auth non coincide con `users/{uid}.email`;
- non inizializzare listener admin/staff prima di avere ruolo e `salonIds`;
- lasciare disponibili solo dati pubblici quando l'utente non e' autenticato o non autorizzato.

## Checklist implementazione app

- [x] Aggiungere `mustChangePassword` al modello `AppUser`.
- [x] Rendere robusto il parsing liste (`salonIds`, `roles`, `availableRoles`) da Firestore, evitando cast diretti `List<dynamic>` -> `List<String>`.
- [x] In `AuthRepository.signInWithEmail`, dopo Firebase Auth, leggere `/users/{uid}`.
- [x] Se `/users/{uid}` manca, fare logout e mostrare "Account non autorizzato".
- [x] Se `users/{uid}.email` non coincide con `FirebaseAuth.currentUser.email`, fare logout.
- [x] Se admin `enabled == false`, fare logout.
- [x] Esporre in `SessionState` una property `requiresPasswordChange`.
- [x] Aggiungere route `/first-password-change`.
- [x] Nel router, se `requiresPasswordChange == true`, permettere solo `/first-password-change` e logout.
- [x] Dopo cambio password, aggiornare `mustChangePassword: false` tramite callable `completeFirstPasswordChange`.
- [ ] Verificare che i listener Firestore non partano per utenti senza profilo valido.

## Checklist operativa primo admin salone

- [ ] Creare o identificare il documento `/salons/{salonId}`.
- [ ] Creare utente in Firebase Authentication con email admin e password temporanea.
- [ ] Copiare lo UID dell'utente Auth.
- [ ] Creare `/users/{uid}` con ruolo admin e `salonIds`.
- [ ] Impostare `enabled: true`.
- [ ] Impostare `mustChangePassword: true`.
- [ ] Consegnare password temporanea all'admin fuori dall'app.
- [ ] L'admin accede e cambia password obbligatoriamente.
- [ ] Verificare che `mustChangePassword` diventi `false`.
- [ ] Verificare accesso dashboard admin e assenza di `permission-denied` ripetuti.

## Variante consigliata per produzione

Creare uno script interno o una Cloud Function admin-only `provisionSalonAdmin` che riceve:

- email admin;
- display name;
- salonId o dati nuovo salone;
- eventuale password temporanea generata.

La funzione deve:

1. creare utente Firebase Auth;
2. creare o collegare `/salons/{salonId}`;
3. creare `/users/{uid}`;
4. impostare `mustChangePassword: true`;
5. restituire esito provisioning.

Questo evita errori manuali su UID, mail, ruolo e salone.

## Script disponibile

E' stato aggiunto lo script:

```bash
functions/scripts/provision_salon_admin.js
```

Template di configurazione:

```bash
functions/scripts/provision_salon_admin.example.json
```

Uso consigliato:

```bash
cp functions/scripts/provision_salon_admin.example.json /tmp/provision_salon_admin.json
```

Modificare `/tmp/provision_salon_admin.json` con:

- email admin;
- nome admin;
- password temporanea;
- dati salone;
- `salon.id` stabile;
- `mustChangePassword: true`.

Prima simulare:

```bash
node functions/scripts/provision_salon_admin.js --config=/tmp/provision_salon_admin.json --dryRun
```

Poi applicare:

```bash
node functions/scripts/provision_salon_admin.js --config=/tmp/provision_salon_admin.json
```

Opzionale, se l'utente Auth esiste gia' e vuoi rigenerare la password temporanea:

```bash
node functions/scripts/provision_salon_admin.js --config=/tmp/provision_salon_admin.json --forcePassword
```

Lo script crea o aggiorna:

- Firebase Auth user;
- `/users/{uid}`;
- `/salons/{salonId}`;
- `/salon_setup_progress/{salonId}`;
- custom claims `role` e `salonIds`.

Nota sicurezza: non committare mai file JSON reali con password temporanee.
