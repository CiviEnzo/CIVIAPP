import 'dart:async';

import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:you_book/domain/legal/legal_documents.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth =
           Firebase.apps.isNotEmpty ? (auth ?? FirebaseAuth.instance) : null,
       _firestore =
           Firebase.apps.isNotEmpty
               ? (firestore ?? FirebaseFirestore.instance)
               : null,
       _functions =
           Firebase.apps.isNotEmpty
               ? (functions ??
                   FirebaseFunctions.instanceFor(region: 'europe-west3'))
               : null;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  Stream<AppUser?> authStateChanges() {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) {
      return const Stream<AppUser?>.empty();
    }
    return auth.authStateChanges().asyncExpand((firebaseUser) {
      if (firebaseUser == null) {
        return Stream<AppUser?>.value(null);
      }
      final docRef = firestore.collection('users').doc(firebaseUser.uid);
      return docRef.snapshots().map((doc) {
        if (!doc.exists) {
          return null;
        }
        final data = doc.data() ?? <String, dynamic>{};
        final authEmail = _normalizedEmail(firebaseUser.email);
        final profileEmail = _normalizedEmail(data['email']);
        if (authEmail == null ||
            profileEmail == null ||
            authEmail != profileEmail) {
          return null;
        }
        data.putIfAbsent('displayName', () => firebaseUser.displayName);
        data['emailVerified'] = firebaseUser.emailVerified;
        return AppUser.fromMap(firebaseUser.uid, data);
      });
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase non inizializzato.');
    }
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final signedInUser = credential.user;
    if (signedInUser != null) {
      try {
        await signedInUser.reload();
      } catch (_) {
        // Ignora errori di reload: user.emailVerified verrà comunque verificato.
      }
    }
    final user = auth.currentUser ?? signedInUser;
    if (user == null) {
      return;
    }

    late final _UserAccessSnapshot access;
    try {
      access = await _fetchUserAccess(user.uid, authEmail: user.email);
    } on FirebaseException {
      await auth.signOut();
      throw FirebaseAuthException(
        code: 'user-profile-check-failed',
        message: 'Impossibile verificare il profilo utente.',
      );
    }
    if (!access.exists) {
      await auth.signOut();
      throw FirebaseAuthException(
        code: 'user-profile-not-found',
        message: 'Account non autorizzato.',
      );
    }
    if (!access.emailMatches) {
      await auth.signOut();
      throw FirebaseAuthException(
        code: 'user-profile-email-mismatch',
        message: 'Account non autorizzato per questa email.',
      );
    }
    if (access.role == UserRole.admin && !access.isEnabled) {
      await auth.signOut();
      throw FirebaseAuthException(
        code: 'admin-not-enabled',
        message: 'Account in attesa di abilitazione.',
      );
    }

    if (!user.emailVerified) {
      if (access.role == UserRole.admin) {
        return;
      }
      if (access.role == UserRole.staff && access.emailVerifiedOverride) {
        return;
      }
      try {
        await user.sendEmailVerification();
      } catch (_) {
        // Ignora errori di resend: l'utente potrà riprovare più tardi.
      } finally {
        await auth.signOut();
      }
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Email non verificata.',
      );
    }
  }

  Future<void> completeRequiredPasswordChange({
    required String currentPassword,
    required String newPassword,
    required bool acceptedLegalTerms,
  }) async {
    final auth = _auth;
    final functions = _functions;
    if (auth == null || functions == null) {
      throw StateError('Firebase non inizializzato.');
    }
    if (!acceptedLegalTerms) {
      throw StateError('Accetta termini e privacy per continuare.');
    }
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.trim().isEmpty) {
      throw StateError('Nessun utente email autenticato.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
    await user.reload();
    await auth.currentUser?.getIdToken(true);

    final callable = functions.httpsCallable('completeFirstPasswordChange');
    try {
      await callable.call(<String, dynamic>{
        'acceptedLegalTerms': true,
        'termsVersion': legalTermsVersion,
        'privacyVersion': legalPrivacyVersion,
      });
    } on FirebaseFunctionsException {
      await _completePasswordChangeFromClient(user.uid);
    }
  }

  Future<void> _completePasswordChangeFromClient(String uid) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firestore non inizializzato.');
    }
    await firestore.collection('users').doc(uid).set({
      'mustChangePassword': false,
      'forcePasswordChange': FieldValue.delete(),
      'requiresPasswordChange': FieldValue.delete(),
      'passwordChangedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      ..._legalAcceptancePayload(),
    }, SetOptions(merge: true));
  }

  Future<void> registerClient({
    required String email,
    required String password,
    String? displayName,
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? dateOfBirth,
    required bool acceptedLegalTerms,
  }) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) {
      throw StateError('Firebase non inizializzato.');
    }
    if (!acceptedLegalTerms) {
      throw StateError('Accetta termini e privacy per continuare.');
    }
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    if (displayName != null && displayName.trim().isNotEmpty) {
      await credential.user!.updateDisplayName(displayName.trim());
    }
    final sanitizedFirstName = firstName?.trim();
    final sanitizedLastName = lastName?.trim();
    final sanitizedPhone = phone?.trim();
    final userData = {
      'role': UserRole.client.name,
      'salonIds': const <String>[],
      'displayName': displayName ?? credential.user?.displayName,
      'email': email,
      'pendingFirstName':
          sanitizedFirstName?.isEmpty ?? true ? null : sanitizedFirstName,
      'pendingLastName':
          sanitizedLastName?.isEmpty ?? true ? null : sanitizedLastName,
      'pendingPhone': sanitizedPhone?.isEmpty ?? true ? null : sanitizedPhone,
      'pendingDateOfBirth':
          dateOfBirth != null ? Timestamp.fromDate(dateOfBirth) : null,
      ..._legalAcceptancePayload(),
    };
    userData.removeWhere((key, value) => value == null);
    await firestore.collection('users').doc(uid).set(userData);
    final firebaseUser = credential.user;
    if (firebaseUser != null && !firebaseUser.emailVerified) {
      await firebaseUser.sendEmailVerification();
    }
    await auth.signOut();
  }

  Future<void> registerCenterAdmin({
    required String email,
    required String password,
    required String displayName,
    required String salonName,
    required String salonAddress,
    required String salonCity,
    required String salonPhone,
    required bool acceptedLegalTerms,
  }) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) {
      throw StateError('Firebase non inizializzato.');
    }
    if (!acceptedLegalTerms) {
      throw StateError('Accetta termini e privacy per continuare.');
    }

    final sanitizedEmail = email.trim();
    final sanitizedName = displayName.trim();
    final sanitizedSalonName = salonName.trim();
    final sanitizedSalonAddress = salonAddress.trim();
    final sanitizedSalonCity = salonCity.trim();
    final sanitizedSalonPhone = salonPhone.trim();
    final salonRef = firestore.collection('salons').doc();

    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: sanitizedEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Impossibile creare l\'utente.');
      }
      if (sanitizedName.isNotEmpty) {
        await user.updateDisplayName(sanitizedName);
      }

      final userData = {
        'role': UserRole.admin.name,
        'roles': <String>[UserRole.admin.name],
        'availableRoles': <String>[UserRole.admin.name],
        'salonIds': <String>[salonRef.id],
        'salonId': salonRef.id,
        'displayName': sanitizedName.isEmpty ? null : sanitizedName,
        'email': sanitizedEmail,
        'enabled': false,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        ..._legalAcceptancePayload(),
      };
      userData.removeWhere((key, value) => value == null);
      await firestore.collection('users').doc(user.uid).set(userData);

      await salonRef.set({
        'name': sanitizedSalonName,
        'address': sanitizedSalonAddress,
        'city': sanitizedSalonCity,
        'phone': sanitizedSalonPhone,
        'email': sanitizedEmail,
        'status': 'active',
        'isPublished': false,
      });
    } finally {
      await auth.signOut();
    }
  }

  Future<void> completeUserProfile({
    required UserRole role,
    required List<String> salonIds,
    String? staffId,
    String? clientId,
    String? displayName,
  }) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) {
      throw StateError('Firebase non inizializzato.');
    }
    final user = auth.currentUser;
    if (user == null) {
      throw StateError('Nessun utente autenticato.');
    }
    final docData = {
      'role': role.name,
      'salonIds': salonIds,
      'salonId': salonIds.isNotEmpty ? salonIds.first : null,
      'staffId': staffId,
      'clientId': clientId,
      'displayName': displayName ?? user.displayName,
      'email': user.email,
      'roles': FieldValue.arrayUnion(<String>[role.name]),
    };

    docData.removeWhere((key, value) => value == null);

    await firestore
        .collection('users')
        .doc(user.uid)
        .set(docData, SetOptions(merge: true));
  }

  Future<_UserAccessSnapshot> _fetchUserAccess(
    String uid, {
    String? authEmail,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return const _UserAccessSnapshot();
    }
    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      return const _UserAccessSnapshot();
    }
    final data = doc.data();
    if (data == null) {
      return const _UserAccessSnapshot();
    }
    final normalizedAuthEmail = _normalizedEmail(authEmail);
    final normalizedProfileEmail = _normalizedEmail(data['email']);
    final emailMatches =
        normalizedAuthEmail != null &&
        normalizedProfileEmail != null &&
        normalizedAuthEmail == normalizedProfileEmail;
    return _UserAccessSnapshot(
      exists: true,
      emailMatches: emailMatches,
      role: _roleFromData(data),
      isEnabled: (data['enabled'] as bool?) ?? true,
      emailVerifiedOverride: (data['emailVerifiedOverride'] as bool?) ?? false,
    );
  }

  static String? _normalizedEmail(Object? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  UserRole? _roleFromValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is UserRole) {
      return value;
    }
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) {
      return null;
    }
    for (final role in UserRole.values) {
      if (role.name == text) {
        return role;
      }
    }
    return null;
  }

  UserRole? _roleFromData(Map<String, dynamic> data) {
    final directRole = _roleFromValue(data['role']);
    if (directRole != null) {
      return directRole;
    }
    final availableRoles =
        data['roles'] ?? data['availableRoles'] ?? data['allowedRoles'];
    if (availableRoles is Iterable) {
      for (final entry in availableRoles) {
        final resolved = _roleFromValue(entry);
        if (resolved != null) {
          return resolved;
        }
      }
    } else if (availableRoles is String) {
      return _roleFromValue(availableRoles);
    }
    return null;
  }

  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) {
      return;
    }
    await auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase non inizializzato.');
    }
    await auth.sendPasswordResetEmail(email: email);
  }

  Future<ClientInviteOutcome> sendClientInviteEmail(String email) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase non inizializzato.');
    }

    try {
      await auth.sendPasswordResetEmail(email: email);
      return ClientInviteOutcome.passwordReset;
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') {
        rethrow;
      }
      // Continues with email link invite when the user is not yet in Authentication.
    }

    final inviteUrl =
        Uri(
          scheme: 'https',
          host: 'civiapp-38b51.firebaseapp.com',
          path: 'client-invite',
          queryParameters: {'email': email},
        ).toString();

    final settings = ActionCodeSettings(
      url: inviteUrl,
      handleCodeInApp: true,
      androidPackageName: 'com.civiapp.youbook',
      androidInstallApp: true,
      androidMinimumVersion: '21',
      iOSBundleId: 'com.civiapp.youbook',
    );

    await auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: settings,
    );
    return ClientInviteOutcome.emailLink;
  }
}

Map<String, dynamic> _legalAcceptancePayload() {
  return {
    'termsAcceptedAt': FieldValue.serverTimestamp(),
    'privacyAcceptedAt': FieldValue.serverTimestamp(),
    'termsVersion': legalTermsVersion,
    'privacyVersion': legalPrivacyVersion,
    'legalConsent': {
      'accepted': true,
      'acceptedAt': FieldValue.serverTimestamp(),
      'termsVersion': legalTermsVersion,
      'privacyVersion': legalPrivacyVersion,
      'source': 'auth',
    },
  };
}

enum ClientInviteOutcome { passwordReset, emailLink }

class _UserAccessSnapshot {
  const _UserAccessSnapshot({
    this.exists = false,
    this.emailMatches = false,
    this.role,
    this.isEnabled = true,
    this.emailVerifiedOverride = false,
  });

  final bool exists;
  final bool emailMatches;
  final UserRole? role;
  final bool isEnabled;
  final bool emailVerifiedOverride;
}
