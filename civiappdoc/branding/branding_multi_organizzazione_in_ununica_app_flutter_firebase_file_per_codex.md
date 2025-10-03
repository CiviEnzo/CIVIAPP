# Obiettivo

Portare un **branding dinamico per salone** (logo, colori, tema) in **un’unica app Flutter** che serve amministratori, staff e clienti. Il tema deve cambiare:
- per l’admin sul salone che ha creato e gestisce;
- per lo staff sul salone assegnato;
- per i clienti sul salone correntemente selezionato, pur potendo averne più di uno tra i preferiti.

L’esperienza deve rimanere fluida su iOS, Android, macOS e web, senza duplicare l’app sugli store.

---

## Architettura dati (Firestore)

```
/salons/{salonId}
  name: string
  ownerUid: string                  // uid admin creatore
  staffIds: string[]                // opzionale, utile per le regole
  clientIds: string[]               // opzionale, per membership esplicite
  branding:
    primaryColor: string            // es. "#1F2937"
    accentColor: string             // es. "#A855F7"
    themeMode: "light" | "dark" | "system"
    logoStoragePath: string?        // es. branding/salon_123/logo.png
    logoUrl: string?                // download URL firmato
    appBarStyle: string?            // opzionale (compact, elevated, ecc.)
  createdAt: serverTimestamp
  updatedAt: serverTimestamp

/users/{uid}
  role: "admin" | "staff" | "client"
  managedSalonIds: string[]         // replica custom claim per UI admin
  joinedSalonIds: string[]          // saloni a cui il client/staff ha accesso
  activeSalonId: string?            // ultimo salone selezionato (per client)
  ... altri campi già esistenti
```

**Note**
- `ownerUid` è l’ancora per vincolare ogni admin ai saloni che ha creato.
- Mantieni `managedSalonIds` e `joinedSalonIds` come array in Auth custom claims (stesso casing) per usarli nelle regole.
- `activeSalonId` serve per inizializzare il branding senza flash dopo il login.
- Se preferisci evitare array direttamente nel documento principale, sposta `staffIds`/`clientIds` in subcollection (`/salons/{salonId}/members/{uid}`) ma replica almeno un indice (es. `membership` con ruoli) per query e regole.

---

## Custom Claims & sincronizzazione

1. **Al login** una Cloud Function aggiorna i custom claims con:
   - `role`
   - `managedSalonIds` (per admin coincide con i saloni creati)
   - `joinedSalonIds` (per staff/client) e **`activeSalonId` opzionale se vuoi precalcolarlo**.
2. **Firestore trigger** mantiene `ownerUid` e `managedSalonIds` allineati:
   - alla creazione del salone imposta `ownerUid = request.auth.uid`;
   - se l’owner elimina il salone, rimuovi l’id da `managedSalonIds` nelle claims.
3. **Sync lato client** (Riverpod): quando `SessionController.setSalon` cambia salone, aggiorna `/users/{uid}.activeSalonId` con una `callable` o un `update` limitato.

---

## Regole Firestore (v2)

> Inserisci in `firestore.rules` e deploya con `firebase deploy --only firestore:rules`.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    function isSignedIn() { return request.auth != null; }
    function role() { return request.auth.token.role; }
    function managedSalonIds() {
      return request.auth.token.managedSalonIds != null
        ? request.auth.token.managedSalonIds
        : [];
    }
    function joinedSalonIds() {
      return request.auth.token.joinedSalonIds != null
        ? request.auth.token.joinedSalonIds
        : [];
    }
    function isSalonOwner(salonId) {
      return role() == 'admin'
        && request.auth.uid == resource.data.ownerUid
        && managedSalonIds().hasAny([salonId]);
    }
    function isSalonOwnerOnCreate() {
      return role() == 'admin'
        && request.auth.uid == request.resource.data.ownerUid;
    }
    function isSalonStaff() {
      return resource.data.staffIds != null
        && resource.data.staffIds.hasAny([request.auth.uid]);
    }
    function canViewSalon(salonId) {
      if (!isSignedIn()) return false;
      if (isSalonOwner(salonId) || isSalonStaff()) {
        return true;
      }
      return joinedSalonIds().hasAny([salonId]);
    }

    match /users/{uid} {
      allow read: if isSignedIn() && (request.auth.uid == uid || role() in ['admin', 'staff']);
      allow create: if request.auth != null && request.auth.uid == uid;
      allow update: if request.auth != null && request.auth.uid == uid
        && !['role', 'managedSalonIds', 'joinedSalonIds']
          .hasAny(request.resource.data.diff(resource.data).affectedKeys());
    }

    match /salons/{salonId} {
      allow read: if canViewSalon(salonId);
      allow create: if isSignedIn() && isSalonOwnerOnCreate();
      allow update, delete: if isSignedIn() && role() == 'admin'
        && resource.data.ownerUid == request.auth.uid;

      match /members/{uid} {
        allow read: if canViewSalon(salonId);
        allow write: if isSignedIn() && get(/databases/$(db)/documents/salons/$(salonId)).data.ownerUid == request.auth.uid;
      }
    }
  }
}
```

**Perché `hasAny`**: restituisce `true` se l’array contiene almeno uno dei valori passati. Garantisce che l’admin non possa accedere a saloni che non ha creato, mentre staff/client vedono solo quelli assegnati o scelti.

---

## Regole Storage (logo e asset del brand)

> Inserisci in `storage.rules`.

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSignedIn() { return request.auth != null; }
    function role() { return request.auth.token.role; }
    function managedSalonIds() {
      return request.auth.token.managedSalonIds != null
        ? request.auth.token.managedSalonIds
        : [];
    }
    function canReadSalonBranding(salonId) {
      if (!isSignedIn()) return false;
      if (role() == 'admin' && managedSalonIds().hasAny([salonId])) return true;
      return request.auth.token.joinedSalonIds != null
        && request.auth.token.joinedSalonIds.hasAny([salonId]);
    }

    match /branding/{salonId}/{fileName} {
      allow read: if canReadSalonBranding(salonId);
      allow write: if isSignedIn()
        && role() == 'admin'
        && request.auth.token.managedSalonIds.hasAny([salonId])
        && request.resource.size < 5 * 1024 * 1024
        && request.resource.contentType.matches('image/.*');
    }
  }
}
```

Percorso consigliato: `branding/{salonId}/logo.png` o `branding/{salonId}/assets/<file>`. Usa URL firmati con scadenza per il logo pubblico lato client.

---

## Flutter: struttura e provider

Allinea la feature al nostro stack (Riverpod + GoRouter). Proposta:

```
lib/
  data/
    branding/
      branding_model.dart
      branding_repository.dart
  domain/
    branding/
      branding_service.dart               // logica di caching/offline
  presentation/
    branding/
      widgets/branded_app_shell.dart
      admin/branding_admin_page.dart
  app/
    providers.dart                        // nuovi provider per branding
```

### Modello e trasformazioni

```dart
// lib/data/branding/branding_model.dart
import 'package:flutter/material.dart';

class BrandingModel {
  const BrandingModel({
    required this.primaryColor,
    required this.accentColor,
    required this.themeMode,
    this.logoUrl,
    this.appBarStyle,
  });

  final String primaryColor;
  final String accentColor;
  final String themeMode;
  final String? logoUrl;
  final String? appBarStyle;

  factory BrandingModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const BrandingModel(
        primaryColor: '#1F2937',
        accentColor: '#A855F7',
        themeMode: 'system',
      );
    }
    return BrandingModel(
      primaryColor: data['primaryColor'] as String? ?? '#1F2937',
      accentColor: data['accentColor'] as String? ?? '#A855F7',
      themeMode: data['themeMode'] as String? ?? 'system',
      logoUrl: data['logoUrl'] as String?,
      appBarStyle: data['appBarStyle'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'primaryColor': primaryColor,
      'accentColor': accentColor,
      'themeMode': themeMode,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (appBarStyle != null) 'appBarStyle': appBarStyle,
    };
  }

  ColorScheme toColorScheme(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: _parseColor(primaryColor),
      secondary: _parseColor(accentColor),
      brightness: brightness,
    );
  }

  ThemeMode resolveThemeMode() {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Color _parseColor(String value) {
    final buffer = StringBuffer();
    if (!value.startsWith('#')) buffer.write('#');
    buffer.write(value.replaceAll('#', ''));
    final hex = int.parse(buffer.toString().substring(1), radix: 16);
    return Color(0xFF000000 | hex);
  }
}
```

### Repository + Riverpod

```dart
// lib/data/branding/branding_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'branding_model.dart';

class BrandingRepository {
  BrandingRepository(this._firestore);
  final FirebaseFirestore _firestore;

  Stream<BrandingModel> watchSalonBranding(String salonId) {
    return _firestore.collection('salons').doc(salonId).snapshots().map(
      (snapshot) => BrandingModel.fromMap(snapshot.data()?['branding'] as Map<String, dynamic>?),
    );
  }

  Future<void> saveSalonBranding({
    required String salonId,
    required BrandingModel data,
  }) async {
    await _firestore.collection('salons').doc(salonId).set(
      {
        'branding': data.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
```

Provider in `app/providers.dart`:

```dart
final brandingRepositoryProvider = Provider<BrandingRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  return BrandingRepository(firestore);
});

final currentSalonIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionControllerProvider).salonId;
});

final salonBrandingProvider = StreamProvider<BrandingModel>((ref) {
  final salonId = ref.watch(currentSalonIdProvider);
  final repository = ref.watch(brandingRepositoryProvider);
  if (salonId == null) {
    return Stream.value(const BrandingModel(
      primaryColor: '#1F2937',
      accentColor: '#A855F7',
      themeMode: 'system',
    ));
  }
  return repository.watchSalonBranding(salonId);
});
```

Aggiungi un provider derivato per tradurre in `ThemeData`:

```dart
final salonThemeProvider = Provider.autoDispose((ref) {
  final brandingAsync = ref.watch(salonBrandingProvider);
  final base = brandingAsync.valueOrNull ?? const BrandingModel(
    primaryColor: '#1F2937',
    accentColor: '#A855F7',
    themeMode: 'system',
  );
  final lightScheme = base.toColorScheme(Brightness.light);
  final darkScheme = base.toColorScheme(Brightness.dark);

  ThemeData buildTheme(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: base.appBarStyle == 'elevated' ? 4 : 0,
      ),
    );
  }

  return (
    theme: buildTheme(lightScheme),
    darkTheme: buildTheme(darkScheme),
    mode: base.resolveThemeMode(),
    branding: base,
  );
});
```

### Wrapping dell’app

```dart
// lib/presentation/branding/widgets/branded_app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:civiapp/app/providers.dart';

class BrandedAppShell extends ConsumerWidget {
  const BrandedAppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(salonThemeProvider);

    return MaterialApp.router(
      title: 'Civi App Gestionale',
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
      theme: theme.theme,
      darkTheme: theme.darkTheme,
      themeMode: theme.mode,
      builder: (context, widget) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: widget ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
```

In `main.dart` sostituisci `CiviApp` con `BrandedAppShell` (o integra la logica direttamente in `CiviApp`). Mantieni `ProviderScope` e l’inizializzazione di Firebase come già presente.

### Selezione salone e cambio tema

- L’admin vede solo i saloni con `ownerUid == uid`.
- Il client/staff può avere più saloni, ma `SessionController.salonId` è l’unico attivo. Quando cambia, Riverpod rivaluta `salonBrandingProvider` e il tema si aggiorna.
- Salva la scelta su `/users/{uid}.activeSalonId` e ricarica le claims se serve (o leggi direttamente dal documento utente all’avvio).

### Cache locale e offline

Usa `SharedPreferences` o `Hive` per memorizzare l’ultimo branding per `salonId`:

```dart
final brandingCacheProvider = Provider<BrandingCache>((_) => BrandingCache());

class BrandingCache {
  final _preferences = SharedPreferences.getInstance();

  Future<void> save(String salonId, BrandingModel data) async {
    final prefs = await _preferences;
    await prefs.setString('branding_$salonId', jsonEncode(data.toMap()));
  }

  Future<BrandingModel?> read(String salonId) async {
    final prefs = await _preferences;
    final stored = prefs.getString('branding_$salonId');
    if (stored == null) return null;
    return BrandingModel.fromMap(jsonDecode(stored) as Map<String, dynamic>);
  }
}
```

Nel `StreamProvider` avvia subito il valore della cache, poi aggiorna con Firestore.

---

## Pagina admin per il branding

Funzionalità minime:
- Anteprima logo e colori in tempo reale (usa `StreamBuilder`/`Consumer` sul provider);
- `FilePicker` → `FirebaseStorageService.uploadSalonLogo` → aggiorna la mappa `branding` con il nuovo `logoUrl`;
- due text field per i colori (regex `^#?[0-9a-fA-F]{6}$`, normalizza con `#`);
- dropdown per `themeMode` (`light`, `dark`, `system`);
- bottone “Salva” che chiama `BrandingRepository.saveSalonBranding`.

Snippet storage service:

```dart
class FirebaseStorageService {
  FirebaseStorageService(this._storage);
  final FirebaseStorage _storage;

  Future<String> uploadSalonLogo({
    required String salonId,
    required File file,
  }) async {
    final ref = _storage.ref().child('branding/$salonId/logo.png');
    final metadata = SettableMetadata(contentType: 'image/png');
    await ref.putFile(file, metadata);
    return ref.getDownloadURL();
  }
}
```

---

## Fallback pre-login

Se usi deep-link o slug del salone prima dell’autenticazione:
1. Recupera `salonId` dal link;
2. Fetch `salons/{salonId}` in modalità anonima (Cloud Function che restituisce solo branding pubblico) e applica una palette minimale a livello di `MaterialApp`; 
3. Dopo il login, sincronizza con il salone attivo dalle claims.

---

## Test e checklist

- **Regole Firestore**: verifica che un admin non riesca a leggere/scrivere saloni creati da altri. Testa anche staff/client.
- **Cambio salone cliente**: seleziona più saloni, cambia da UI → il tema deve aggiornarsi senza riavviare l’app.
- **Cache offline**: simula modalità aereo. Il brand applica l’ultimo valore salvato? Mostra un placeholder se mancano dati.
- **Storage**: impedisci upload >5MB o file non immagine. Verifica che staff/client non possano riscrivere loghi.
- **AppBar e routing**: assicurati che il router non perda stato durante il rebuild del `MaterialApp` (l’uso di `MaterialApp.router` dentro `BrandedAppShell` mantiene la configurazione).

---

## Comandi utili

```bash
# Deploy regole Firestore e Storage
firebase deploy --only firestore:rules,storage:rules

# Dipendenze Flutter
flutter pub add cloud_firestore firebase_storage shared_preferences file_picker
```

Con questo setup il branding per salone rimane centrale nel dominio di CiviApp: ogni admin gestisce solo le strutture create, i clienti possono scegliere tra più saloni ma visualizzarne uno alla volta, e il tema dell’app segue sempre il contesto corrente.
