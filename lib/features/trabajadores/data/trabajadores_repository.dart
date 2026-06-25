import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../domain/ausencia.dart';
import '../domain/trabajador.dart';

/// Acceso a la colección `trabajadores` y su subcolección `ausencias`.
class TrabajadoresRepository {
  TrabajadoresRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('trabajadores');

  Stream<List<Trabajador>> watchAll() =>
      _col.orderBy('nombre').snapshots().map((snap) =>
          snap.docs.map((d) => Trabajador.fromMap(d.id, d.data())).toList());

  Future<String> upsert(Trabajador trabajador) async {
    if (trabajador.id.isEmpty) {
      final ref = await _col.add(trabajador.toMap());
      return ref.id;
    }
    await _col
        .doc(trabajador.id)
        .set(trabajador.toMap(), SetOptions(merge: true));
    return trabajador.id;
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  // --- Ausencias (subcolección) ---

  Stream<List<Ausencia>> watchAusencias(String trabajadorId) => _col
      .doc(trabajadorId)
      .collection('ausencias')
      .orderBy('fecha_inicio')
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Ausencia.fromMap(d.id, d.data())).toList());

  Future<void> addAusencia(String trabajadorId, Ausencia ausencia) =>
      _col.doc(trabajadorId).collection('ausencias').add(ausencia.toMap());

  Future<void> deleteAusencia(String trabajadorId, String ausenciaId) => _col
      .doc(trabajadorId)
      .collection('ausencias')
      .doc(ausenciaId)
      .delete();
}

final trabajadoresRepositoryProvider = Provider<TrabajadoresRepository>(
  (ref) => TrabajadoresRepository(ref.watch(firestoreProvider)),
);

final trabajadoresStreamProvider = StreamProvider<List<Trabajador>>(
  (ref) => ref.watch(trabajadoresRepositoryProvider).watchAll(),
);

/// Stream de las ausencias de un trabajador.
final ausenciasProvider = StreamProvider.family<List<Ausencia>, String>(
  (ref, trabajadorId) =>
      ref.watch(trabajadoresRepositoryProvider).watchAusencias(trabajadorId),
);
