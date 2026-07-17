import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../domain/usuario.dart';

/// Acceso a la colección `usuarios` (cuenta por uid de Auth).
///
/// Patrón copiado de `trabajadores_repository.dart`.
class UsuariosRepository {
  UsuariosRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('usuarios');

  /// Doc `usuarios/{uid}`; emite null si no existe.
  Stream<Usuario?> watchUsuario(String uid) =>
      _col.doc(uid).snapshots().map((snap) {
        final data = snap.data();
        if (!snap.exists || data == null) return null;
        return Usuario.fromMap(snap.id, data);
      });

  Stream<List<Usuario>> watchUsuarios() =>
      _col.orderBy('nombre').snapshots().map((snap) =>
          snap.docs.map((d) => Usuario.fromMap(d.id, d.data())).toList());

  /// Observa usuarios de un tenant específico (Phase 4: multi-tenant filtering).
  ///
  /// Filtra por tenant_id y ordena alfabéticamente por nombre.
  /// Usado por administrador de tenant para listar sus usuarios.
  /// Emite lista vacía si hay error (red, permisos, etc.).
  Stream<List<Usuario>> watchUsuariosDelTenant(String tenantId) =>
      _col
          .where('tenant_id', isEqualTo: tenantId)
          .orderBy('nombre')
          .snapshots()
          .map((snap) =>
              snap.docs.map((d) => Usuario.fromMap(d.id, d.data())).toList())
          .handleError((_) => []);

  /// Crea/sobrescribe `usuarios/{u.uid}`. Sin await en el llamador de UI
  /// (patrón offline del proyecto). `created_at` con timestamp del servidor.
  ///
  /// Si [tenantId] está disponible, asigna el tenant_id al usuario.
  Future<void> crearUsuario(Usuario u, {String? tenantId}) => _col.doc(u.uid).set({
        ...u.toMap(),
        if (tenantId != null) 'tenant_id': tenantId,
        'created_at': FieldValue.serverTimestamp(),
      });

  Future<void> setActivo(String uid, bool activo) =>
      _col.doc(uid).update({'activo': activo});
}

final usuariosRepositoryProvider = Provider<UsuariosRepository>(
  (ref) => UsuariosRepository(ref.watch(firestoreProvider)),
);
