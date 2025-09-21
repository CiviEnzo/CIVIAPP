import 'dart:async';

import 'package:civiapp/data/models/app_user.dart';
import 'package:civiapp/domain/entities/user_role.dart';
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
    return auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        return null;
      }
      final doc =
          await firestore.collection('users').doc(firebaseUser.uid).get();
      if (!doc.exists) {
        return AppUser.placeholder(
          firebaseUser.uid,
          email: firebaseUser.email,
          displayName: firebaseUser.displayName,
        );
      }
      final data = doc.data() ?? <String, dynamic>{};
      data.putIfAbsent('email', () => firebaseUser.email);
      data.putIfAbsent('displayName', () => firebaseUser.displayName);
      return AppUser.fromMap(firebaseUser.uid, data);
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase non inizializzato.');
    }
    await auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> registerClient({
    required String email,
    required String password,
    String? displayName,
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
    final userData = {
      'role': UserRole.client.name,
      'salonIds': const <String>[],
      'displayName': displayName ?? credential.user?.displayName,
      'email': email,
    };
    userData.removeWhere((key, value) => value == null);
    await firestore.collection('users').doc(uid).set(userData);
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
