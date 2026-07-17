import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../../../shared/models/tenant_user.dart';

/// Repositorio para gestionar usuarios de un tenant específico.
///
/// Los usuarios se almacenan en `_platform/usuarios/{tenant_id}/{uid}`.
/// Cada entrada representa un usuario con su email y estado en ese tenant.
class TenantUserRepository {
  TenantUserRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _getUsersCollection(
    String tenantId,
  ) =>
      _db
          .collection('_platform')
          .doc('usuarios')
          .collection(tenantId);

  /// Observa todos los usuarios de un tenant, ordenados por fecha de creación.
  ///
  /// Retorna los usuarios activos e inactivos. En caso de error, retorna lista vacía.
  Stream<List<TenantUser>> watchTenantUsers(String tenantId) {
    return _getUsersCollection(tenantId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TenantUser.fromJson(d.id, d.data()))
            .toList())
        .handleError((_) => []);
  }

  /// Observa un usuario específico de un tenant.
  ///
  /// Retorna null si el usuario no existe. En caso de error, también retorna null.
  Stream<TenantUser?> watchTenantUser(String tenantId, String uid) {
    return _getUsersCollection(tenantId)
        .doc(uid)
        .snapshots()
        .map((snap) {
          if (!snap.exists) return null;
          final data = snap.data();
          if (data == null) return null;
          return TenantUser.fromJson(snap.id, data);
        })
        .handleError((_) => null);
  }

  /// Crea un nuevo usuario en un tenant.
  ///
  /// Establece `created_at` con timestamp del servidor.
  Future<void> createTenantUser(
    String tenantId,
    TenantUser user,
  ) async {
    try {
      await _getUsersCollection(tenantId).doc(user.uid).set({
        'email': user.email,
        'nombre': user.nombre,
        'activo': user.activo,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Actualiza un usuario existente en un tenant.
  ///
  /// Solo actualiza los campos proporcionados. Establece `updated_at` automáticamente.
  Future<void> updateTenantUser(
    String tenantId,
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updated_at'] = FieldValue.serverTimestamp();
      await _getUsersCollection(tenantId).doc(uid).update(updates);
    } catch (e) {
      rethrow;
    }
  }

  /// Actualiza el último login de un usuario.
  ///
  /// Se llama cuando el usuario se autentica correctamente.
  Future<void> updateLastLogin(String tenantId, String uid) async {
    try {
      await _getUsersCollection(tenantId).doc(uid).update({
        'last_login': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Desactiva un usuario (sin eliminar).
  ///
  /// Establece `activo` a false y `updated_at` al timestamp actual.
  Future<void> deactivateTenantUser(String tenantId, String uid) async {
    try {
      await updateTenantUser(tenantId, uid, {'activo': false});
    } catch (e) {
      rethrow;
    }
  }

  /// Activa un usuario desactivado.
  ///
  /// Establece `activo` a true y `updated_at` al timestamp actual.
  Future<void> activateTenantUser(String tenantId, String uid) async {
    try {
      await updateTenantUser(tenantId, uid, {'activo': true});
    } catch (e) {
      rethrow;
    }
  }

  /// Elimina un usuario de un tenant (eliminación suave: solo Firestore).
  ///
  /// Nota: la eliminación de Firebase Auth debe hacerse desde un backend.
  Future<void> deleteTenantUser(String tenantId, String uid) async {
    try {
      await _getUsersCollection(tenantId).doc(uid).delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Obtiene un usuario específico de forma síncrona (future, no stream).
  ///
  /// Útil para operaciones one-shot que no necesitan observación.
  Future<TenantUser?> getTenantUser(String tenantId, String uid) async {
    try {
      final doc = await _getUsersCollection(tenantId).doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return TenantUser.fromJson(doc.id, data);
    } catch (e) {
      return null;
    }
  }
}

final tenantUserRepositoryProvider = Provider<TenantUserRepository>(
  (ref) => TenantUserRepository(ref.watch(firestoreProvider)),
);
