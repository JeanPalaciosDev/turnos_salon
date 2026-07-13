import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/cliente.dart';

/// Acceso a la colección `clientes` en un tenant específico.
///
/// Todas las queries usan la ruta: `tenants/{tenantId}/clientes/{cliente_id}`
/// para mantener aislamiento de datos multi-tenant.
class ClientesRepository {
  ClientesRepository(this._db, this.tenantId);
  final FirebaseFirestore _db;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get _col => _db
      .collection('tenants')
      .doc(tenantId)
      .collection('clientes');

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

// NOTE: Providers moved to lib/features/clientes/application/clientes_providers.dart
// to allow dependency on currentTenantIdProvider for multi-tenant queries.
