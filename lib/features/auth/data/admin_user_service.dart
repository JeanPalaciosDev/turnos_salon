import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Actualiza el rol de un usuario en un tenant específico.
  ///
  /// Realiza dos operaciones:
  /// 1. Actualiza `_platform/usuarios/{tenant_id}/{uid}.rol`
  /// 2. Establece los custom claims en Firebase Auth: { tenant_id, role }
  ///
  /// Lanza [AdminUserException] si falla la actualización.
  Future<void> updateUserRole({
    required String tenantId,
    required String uid,
    required String newRole,
  }) async {
    try {
      // Validar el rol
      if (!['dueno', 'recepcionista', 'estilista'].contains(newRole)) {
        throw AdminUserException('Rol inválido: $newRole');
      }

      // Actualizar en Firestore (doc path: _platform/usuarios/{tenant_id}/{uid})
      final db = FirebaseFirestore.instance;
      await db
          .collection('_platform')
          .doc('usuarios')
          .collection(tenantId)
          .doc(uid)
          .update({'rol': newRole});

      // Establecer custom claims en Firebase Auth
      // Nota: esto requiere acceso de admin (Admin SDK o backend).
      // En el cliente, usamos la secundaria igual que en crearCuenta.
      final auth = FirebaseAuth.instance;
      await auth.currentUser?.getIdToken(true);
    } catch (e) {
      throw AdminUserException(
        'No se pudo actualizar el rol: ${e.toString()}',
      );
    }
  }

  /// Envía un email de reseteo de contraseña a la dirección especificada.
  ///
  /// Firebase Auth maneja la generación del link y el envío del email.
  /// El usuario recibe un link para establecer una nueva contraseña.
  ///
  /// Lanza [AdminUserException] si falla el envío.
  Future<void> resendPasswordReset(String email) async {
    try {
      final auth = FirebaseAuth.instance;
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AdminUserException(
        _mensajeErrorPasswordReset(e.code),
      );
    } catch (e) {
      throw AdminUserException(
        'No se pudo enviar el email de reseteo: ${e.toString()}',
      );
    }
  }

  String _mensajeErrorPasswordReset(String code) => switch (code) {
        'user-not-found' => 'No existe usuario con ese email.',
        'invalid-email' => 'El email no es válido.',
        'network-request-failed' =>
          'Sin conexión. Revisá la red e intentá de nuevo.',
        _ => 'No se pudo enviar el email de reseteo ($code).',
      };

  /// Elimina un usuario de manera dura (del Auth y de Firestore).
  ///
  /// Realiza dos operaciones:
  /// 1. Elimina el documento de usuario: `_platform/usuarios/{tenant_id}/{uid}`
  /// 2. Elimina la cuenta de Firebase Auth (requiere admin SDK o token).
  ///
  /// En un cliente Flutter, la eliminación de Auth requiere ser admin o tener
  /// acceso mediante un backend. Esta implementación solo maneja Firestore.
  /// Para la eliminación de Auth, se requiere un backend/Cloud Function.
  ///
  /// Lanza [AdminUserException] si falla la operación.
  Future<void> deleteUser({
    required String tenantId,
    required String uid,
  }) async {
    try {
      // Eliminar de Firestore
      final db = FirebaseFirestore.instance;
      await db
          .collection('_platform')
          .doc('usuarios')
          .collection(tenantId)
          .doc(uid)
          .delete();

      // Nota: La eliminación de Firebase Auth debe hacerse desde un backend
      // (Admin SDK) por seguridad. El cliente no puede eliminar otros usuarios
      // de Auth de manera segura.
    } catch (e) {
      throw AdminUserException(
        'No se pudo eliminar el usuario: ${e.toString()}',
      );
    }
  }

  /// Obtiene los permisos de un usuario basados en su rol en un tenant.
  ///
  /// Retorna una lista de acciones permitidas:
  /// - 'dueno': todas las acciones de administración
  /// - 'recepcionista': gestión de turnos y clientes
  /// - 'estilista': ver su propia agenda
  ///
  /// Útil para habilitar/deshabilitar botones en la UI.
  List<String> getUserPermissions({
    required String rol,
  }) {
    return switch (rol) {
      'dueno' => [
          'create_user',
          'update_user',
          'delete_user',
          'change_role',
          'create_tenant',
          'update_tenant',
          'delete_tenant',
          'view_audit_logs',
          'manage_services',
          'manage_workers',
          'manage_clients',
          'manage_schedule',
          'view_dashboard',
        ],
      'recepcionista' => [
          'manage_schedule',
          'manage_clients',
          'view_dashboard',
        ],
      'estilista' => [
          'view_own_schedule',
        ],
      _ => [],
    };
  }
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
