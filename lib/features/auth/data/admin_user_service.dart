import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/emulator.dart';

/// Servicio de alta de cuentas Auth para el panel admin (Fase 2D).
///
/// Crea una cuenta SIN desloguear al admin actual usando una instancia
/// SECUNDARIA de [FirebaseApp]. Si se creara con `FirebaseAuth.instance`
/// (la principal), Firebase cambiaría el `currentUser` al recién creado y
/// el dueño perdería su sesión.
///
/// Patrón documentado:
/// https://firebase.google.com/docs/auth/flutter/manage-users
class AdminUserService {
  const AdminUserService();

  /// Crea la cuenta Auth (email/password) en una app secundaria y devuelve el
  /// `uid`. El caller debe escribir luego `usuarios/{uid}` vía
  /// `UsuariosRepository.crearUsuario`.
  ///
  /// Esta operación SÍ se espera (requiere red): es la excepción al patrón
  /// offline del proyecto, igual que la transacción de cobro.
  ///
  /// Lanza [AdminUserException] con mensaje en español si Auth falla.
  Future<String> crearCuenta({
    required String email,
    required String password,
  }) async {
    // Instancia secundaria aislada: el alta no toca la sesión del admin.
    final app = await Firebase.initializeApp(
      name: 'admin_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final secAuth = FirebaseAuth.instanceFor(app: app);
    // La secundaria debe apuntar también al emulador si está activo.
    if (kUseEmulator) {
      await secAuth.useAuthEmulator(kEmulatorHost, 9099);
    }
    try {
      final cred = await secAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      throw AdminUserException(_mensajeError(e.code));
    } finally {
      // Cerrar sesión y destruir la app secundaria pase lo que pase.
      await secAuth.signOut();
      await app.delete();
    }
  }

  String _mensajeError(String code) => switch (code) {
        'email-already-in-use' => 'Ese email ya tiene una cuenta.',
        'weak-password' =>
          'La contraseña es demasiado débil (mínimo 6 caracteres).',
        'invalid-email' => 'El email no es válido.',
        'network-request-failed' =>
          'Sin conexión. Revisá la red e intentá de nuevo.',
        _ => 'No se pudo crear la cuenta ($code).',
      };
}

/// Error de alta de cuenta con mensaje listo para mostrar al usuario.
class AdminUserException implements Exception {
  const AdminUserException(this.message);
  final String message;

  @override
  String toString() => message;
}

final adminUserServiceProvider = Provider<AdminUserService>(
  (ref) => const AdminUserService(),
);
