import 'dart:async';

import 'package:you_book/data/models/app_user.dart';
import 'package:you_book/domain/entities/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = Firebase.apps.isNotEmpty ? (auth ?? FirebaseAuth.instance) : null,
      _firestore =
          Firebase.apps.isNotEmpty
              ? (firestore ?? FirebaseFirestore.instance)
              : null;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

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
          return AppUser.placeholder(
            firebaseUser.uid,
            email: firebaseUser.email,
            displayName: firebaseUser.displayName,
            isEmailVerified: firebaseUser.emailVerified,
          );
        }
        final data = doc.data() ?? <String, dynamic>{};
        data.putIfAbsent('email', () => firebaseUser.email);
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
    if (user != null && !user.emailVerified) {
      final primaryRole = await _fetchPrimaryRole(user.uid);
      if (primaryRole == UserRole.admin) {
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

  Future<void> registerClient({
    required String email,
    required String password,
    String? displayName,
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? dateOfBirth,
  }) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) {
      throw StateError('Firebase non inizializzato.');
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
      'pendingFirstName': sanitizedFirstName?.isEmpty ?? true
          ? null
          : sanitizedFirstName,
      'pendingLastName': sanitizedLastName?.isEmpty ?? true
          ? null
          : sanitizedLastName,
      'pendingPhone': sanitizedPhone?.isEmpty ?? true ? null : sanitizedPhone,
      'pendingDateOfBirth':
          dateOfBirth != null ? Timestamp.fromDate(dateOfBirth) : null,
    };
    userData.removeWhere((key, value) => value == null);
    await firestore.collection('users').doc(uid).set(userData);
    final firebaseUser = credential.user;
    if (firebaseUser != null && !firebaseUser.emailVerified) {
      await firebaseUser.sendEmailVerification();
    }
    await auth.signOut();
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

  Future<UserRole?> _fetchPrimaryRole(String uid) async {
    final firestore = _firestore;
    if (firestore == null) {
      return null;
    }
    try {
      final doc = await firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        return null;
      }
      final data = doc.data();
      if (data == null) {
        return null;
      }
      final directRole = _roleFromValue(data['role']);
      if (directRole != null) {
        return directRole;
      }
      final availableRoles = data['roles'];
      if (availableRoles is Iterable) {
        for (final entry in availableRoles) {
          final resolved = _roleFromValue(entry);
          if (resolved != null) {
            return resolved;
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
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
      androidPackageName: 'com.example.civiapp',
      androidInstallApp: true,
      androidMinimumVersion: '21',
      iOSBundleId: 'com.cividevops.civiapp',
    );

    await auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: settings,
    );
    return ClientInviteOutcome.emailLink;
  }
}

enum ClientInviteOutcome { passwordReset, emailLink }
