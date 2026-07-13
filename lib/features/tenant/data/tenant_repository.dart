import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../domain/tenant.dart';

/// Acceso a la colección `tenants` (configuración de salones).
///
/// Métodos para leer, crear y actualizar tenants. Cada tenant es una
/// organización independiente con sus propios usuarios, clientes, servicios y turnos.
class TenantRepository {
  TenantRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('tenants');

  /// Observa un tenant por su ID.
  ///
  /// Emite null si el documento no existe o en caso de error.
  Stream<Tenant?> watchTenant(String tenantId) =>
      _col.doc(tenantId).snapshots().map((snap) {
        final data = snap.data();
        if (!snap.exists || data == null) return null;
        return Tenant.fromMap(snap.id, data);
      }).handleError((_) => null);

  /// Observa todos los tenants (ordenados por fecha de creación, descendente).
  ///
  /// Usado por super-admin para listar todas las organizaciones.
  /// En caso de error, retorna lista vacía.
  Stream<List<Tenant>> watchAllTenants() =>
      _col.orderBy('created_at', descending: true).snapshots().map((snap) =>
          snap.docs.map((d) => Tenant.fromMap(d.id, d.data())).toList()).handleError((_) => []);

  /// Crea un nuevo tenant.
  ///
  /// Si [tenantId] es null, Firestore genera automáticamente la ID.
  /// Retorna el ID del tenant creado.
  /// Establece `created_at` con timestamp del servidor.
  Future<String> crearTenant(
    Tenant tenant, {
    String? tenantId,
  }) async {
    final tenantMap = tenant.toMap();

    if (tenantId != null && tenantId.isNotEmpty) {
      // ID proporcionada: usa doc()
      await _col.doc(tenantId).set(tenantMap);
      return tenantId;
    } else {
      // Sin ID: deja que Firestore genere una
      final ref = await _col.add(tenantMap);
      return ref.id;
    }
  }

  /// Actualiza campos de un tenant existente.
  ///
  /// No permite actualizar campos inmutables (id, owner_email, created_at).
  /// Los campos permitidos son: name, estado, branding.
  Future<void> actualizarTenant(
    String tenantId,
    Map<String, dynamic> updates,
  ) async {
    // Sanitizar: remover campos inmutables si fueron pasados.
    updates.removeWhere(
      (key, _) => ['id', 'owner_email', 'created_at'].contains(key),
    );

    if (updates.isEmpty) {
      return;
    }

    await _col.doc(tenantId).update(updates);
  }
}

final tenantRepositoryProvider = Provider<TenantRepository>(
  (ref) => TenantRepository(ref.watch(firestoreProvider)),
);
