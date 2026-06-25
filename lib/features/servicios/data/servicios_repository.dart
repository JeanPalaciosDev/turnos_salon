import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../domain/servicio.dart';

/// Acceso a la colección `servicios`.
class ServiciosRepository {
  ServiciosRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('servicios');

  Stream<List<Servicio>> watchAll() =>
      _col.orderBy('nombre').snapshots().map((snap) =>
          snap.docs.map((d) => Servicio.fromMap(d.id, d.data())).toList());

  /// Crea (si `id` vacío) o actualiza. Devuelve el id resultante.
  Future<String> upsert(Servicio servicio) async {
    if (servicio.id.isEmpty) {
      final ref = await _col.add(servicio.toMap());
      return ref.id;
    }
    await _col.doc(servicio.id).set(servicio.toMap(), SetOptions(merge: true));
    return servicio.id;
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}

final serviciosRepositoryProvider = Provider<ServiciosRepository>(
  (ref) => ServiciosRepository(ref.watch(firestoreProvider)),
);

final serviciosStreamProvider = StreamProvider<List<Servicio>>(
  (ref) => ref.watch(serviciosRepositoryProvider).watchAll(),
);
