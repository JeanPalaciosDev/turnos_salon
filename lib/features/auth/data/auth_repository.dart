import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/auth.dart';
import '../../../core/firebase/firestore.dart';

/// Acceso a Firebase Auth (login/logout y estado de sesión).
///
/// API verificada en FlutterFire:
/// https://firebase.google.com/docs/auth/flutter/start
/// https://firebase.google.com/docs/auth/flutter/manage-users
class AuthRepository {
  AuthRepository(this._auth, this._db);
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// `authStateChanges()` → `Stream<User?>` (emite null al cerrar sesión).
  Stream<User?> authState() => _auth.authStateChanges();

  /// Usuario actual (sincrónico). Ya está actualizado cuando dispara cualquier
  /// listener de `authStateChanges`, por eso el redirect del router lo usa para
  /// evitar la race con `authStateProvider` (ver router.dart).
  User? get currentUser => _auth.currentUser;

  /// Lanza [Exception] con mensaje legible en español si falla.
  ///
  /// Después del login exitoso en Firebase Auth, verifica que:
  /// 1. El usuario tiene tenant_id en Custom Claims
  /// 2. El tenant existe en `_platform/tenants/{tenant_id}`
  /// 3. El tenant estado = 'activo'
  ///
  /// Si alguna verificación falla, hace signOut() y lanza excepción.
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Verificar que el usuario tiene tenant_id y que el tenant es válido
      await _verifyTenantAfterLogin();
    } on FirebaseAuthException catch (e) {
      await _auth.signOut();
      throw Exception(_mensajeError(e.code));
    } catch (e) {
      // Si la verificación de tenant falla, hacer signOut y relanzar
      await _auth.signOut();
      rethrow;
    }
  }

  /// Verifica que el tenant del usuario actual es válido y está activo.
  ///
  /// Extrae tenant_id de los Custom Claims y verifica en Firestore que:
  /// 1. El tenant existe en `_platform/tenants/{tenant_id}`
  /// 2. El tenant estado = 'activo'
  ///
  /// Lanza excepción con mensaje en español si falla.
  Future<void> _verifyTenantAfterLogin() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    // Obtener Custom Claims
    final idToken = await user.getIdTokenResult(true); // true = forzar refresh
    final claims = idToken.claims;

    if (claims == null) {
      throw Exception('No se pudo obtener información del usuario');
    }

    final tenantId = claims['tenant_id'] as String?;
    if (tenantId == null || tenantId.isEmpty) {
      throw Exception('Usuario sin asignar a salón');
    }

    // Verificar que el tenant existe y está activo
    try {
      final tenantDoc = await _db
          .collection('tenants')
          .doc(tenantId)
          .get();

      if (!tenantDoc.exists) {
        throw Exception('Salón no encontrado');
      }

      final estado = tenantDoc.data()?['estado'] as String?;
      if (estado != 'activo') {
        throw Exception('Tu salón ha sido suspendido');
      }
    } on FirebaseException catch (e) {
      // Errores de Firestore (permisos, red, etc.)
      if (e.code == 'permission-denied') {
        throw Exception('Permiso denegado al acceder al salón');
      }
      throw Exception('Error al verificar el salón: ${e.message}');
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
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);
