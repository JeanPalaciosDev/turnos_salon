import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../../trabajadores/domain/trabajador.dart';
import '../domain/usuario.dart';

/// Acceso a la colección `usuarios` (cuenta + rol por uid de Auth).
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

  /// Crea/sobrescribe `usuarios/{u.uid}`. Sin await en el llamador de UI
  /// (patrón offline del proyecto). `created_at` con timestamp del servidor.
  Future<void> crearUsuario(Usuario u) => _col.doc(u.uid).set({
        ...u.toMap(),
        'created_at': FieldValue.serverTimestamp(),
      });

  Future<void> setActivo(String uid, bool activo) =>
      _col.doc(uid).update({'activo': activo});

  Future<void> actualizarRol(String uid, RolTrabajador rol) =>
      _col.doc(uid).update({'rol': rolToDb(rol)});
}

final usuariosRepositoryProvider = Provider<UsuariosRepository>(
  (ref) => UsuariosRepository(ref.watch(firestoreProvider)),
);
