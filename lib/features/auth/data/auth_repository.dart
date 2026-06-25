import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/auth.dart';

/// Acceso a Firebase Auth (login/logout y estado de sesión).
///
/// API verificada en FlutterFire:
/// https://firebase.google.com/docs/auth/flutter/start
/// https://firebase.google.com/docs/auth/flutter/manage-users
class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  /// `authStateChanges()` → `Stream<User?>` (emite null al cerrar sesión).
  Stream<User?> authState() => _auth.authStateChanges();

  /// Usuario actual (sincrónico). Ya está actualizado cuando dispara cualquier
  /// listener de `authStateChanges`, por eso el redirect del router lo usa para
  /// evitar la race con `authStateProvider` (ver router.dart).
  User? get currentUser => _auth.currentUser;

  /// Lanza [Exception] con mensaje legible en español si falla.
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mensajeError(e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Mapea `FirebaseAuthException.code` a mensajes en español.
  String _mensajeError(String code) => switch (code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Correo o contraseña incorrectos.',
        'invalid-email' => 'El correo no es válido.',
        'user-disabled' => 'Esta cuenta está deshabilitada.',
        'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
        'weak-password' => 'La contraseña es demasiado débil.',
        'network-request-failed' =>
          'Sin conexión. Verifica tu red e intenta de nuevo.',
        'too-many-requests' =>
          'Demasiados intentos. Espera un momento e intenta de nuevo.',
        _ => 'No se pudo completar la operación. Intenta de nuevo.',
      };
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider)),
);
