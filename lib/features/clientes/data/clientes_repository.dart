import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../domain/cliente.dart';

/// Acceso a la colección `clientes`.
class ClientesRepository {
  ClientesRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('clientes');

  Stream<List<Cliente>> watchAll() =>
      _col.orderBy('nombre').snapshots().map((snap) =>
          snap.docs.map((d) => Cliente.fromMap(d.id, d.data())).toList());

  Future<String> upsert(Cliente cliente) async {
    if (cliente.id.isEmpty) {
      final ref = await _col.add(cliente.toMap());
      return ref.id;
    }
    await _col.doc(cliente.id).set(cliente.toMap(), SetOptions(merge: true));
    return cliente.id;
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}

final clientesRepositoryProvider = Provider<ClientesRepository>(
  (ref) => ClientesRepository(ref.watch(firestoreProvider)),
);

final clientesStreamProvider = StreamProvider<List<Cliente>>(
  (ref) => ref.watch(clientesRepositoryProvider).watchAll(),
);
