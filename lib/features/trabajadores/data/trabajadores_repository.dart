import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/ausencia.dart';
import '../domain/trabajador.dart';

/// Acceso a la colección `trabajadores` en un tenant específico.
///
/// Todas las queries usan la ruta: `tenants/{tenantId}/trabajadores/{trabajador_id}`
/// para mantener aislamiento de datos multi-tenant.
class TrabajadoresRepository {
  TrabajadoresRepository(this._db, this.tenantId);
  final FirebaseFirestore _db;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get _col => _db
      .collection('tenants')
      .doc(tenantId)
      .collection('trabajadores');

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

// NOTE: Providers moved to lib/features/trabajadores/application/trabajadores_providers.dart
// to allow dependency on currentTenantIdProvider for multi-tenant queries.
