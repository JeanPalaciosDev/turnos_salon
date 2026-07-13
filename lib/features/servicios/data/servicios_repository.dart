import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/servicio.dart';

/// Acceso a la colección `servicios` en un tenant específico.
///
/// Todas las queries usan la ruta: `tenants/{tenantId}/servicios/{servicio_id}`
/// para mantener aislamiento de datos multi-tenant.
class ServiciosRepository {
  ServiciosRepository(this._db, this.tenantId);
  final FirebaseFirestore _db;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get _col => _db
      .collection('tenants')
      .doc(tenantId)
      .collection('servicios');

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

// NOTE: Providers moved to lib/features/servicios/application/servicios_providers.dart
// to allow dependency on currentTenantIdProvider for multi-tenant queries.
