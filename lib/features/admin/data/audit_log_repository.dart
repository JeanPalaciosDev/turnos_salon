import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../../../shared/models/audit_log.dart';

/// Repositorio para acceder a los audit logs de la plataforma.
///
/// Los logs se almacenan en `_platform/audit_logs` y son visibles solo
/// para super_admins. Cada entrada registra una acción realizada por un
/// super_admin sobre un tenant específico.
class AuditLogRepository {
  AuditLogRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('_platform').doc('audit_logs').collection('logs');

  /// Observa todos los audit logs de la plataforma (solo super-admin).
  ///
  /// Retorna los logs ordenados por timestamp descendente (más recientes primero).
  /// En caso de error, retorna lista vacía.
  Stream<List<AuditLog>> watchAllAuditLogs() {
    return _col
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AuditLog.fromJson(d.id, d.data()))
            .toList())
        .handleError((_) => []);
  }

  /// Observa los audit logs filtrados por tenant_id.
  ///
  /// Útil para que un tenant vea sus propias acciones (creación de usuarios, etc.).
  /// Retorna los logs ordenados por timestamp descendente.
  /// En caso de error, retorna lista vacía.
  Stream<List<AuditLog>> watchAuditLogsByTenant(String tenantId) {
    return _col
        .where('tenant_id', isEqualTo: tenantId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AuditLog.fromJson(d.id, d.data()))
            .toList())
        .handleError((_) => []);
  }

  /// Observa los audit logs filtrados por acción específica.
  ///
  /// Ejemplos de acciones: 'crear_usuario', 'cambiar_rol', 'eliminar_usuario'.
  /// Retorna los logs ordenados por timestamp descendente.
  /// En caso de error, retorna lista vacía.
  Stream<List<AuditLog>> watchAuditLogsByAction(String action) {
    return _col
        .where('accion', isEqualTo: action)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AuditLog.fromJson(d.id, d.data()))
            .toList())
        .handleError((_) => []);
  }

  /// Observa los audit logs filtrados por tenant_id y acción.
  ///
  /// Combina dos filtros para obtener logs más específicos.
  /// En caso de error, retorna lista vacía.
  Stream<List<AuditLog>> watchAuditLogsByTenantAndAction(
    String tenantId,
    String action,
  ) {
    return _col
        .where('tenant_id', isEqualTo: tenantId)
        .where('accion', isEqualTo: action)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AuditLog.fromJson(d.id, d.data()))
            .toList())
        .handleError((_) => []);
  }

  /// Crea un nuevo audit log.
  ///
  /// Se usa desde el backend (Cloud Functions) para registrar acciones de admin.
  /// El cliente no debería crear logs directamente, pero se proporciona para completitud.
  Future<String> createAuditLog(
    String accion,
    String superAdminEmail,
    String tenantId, {
    Map<String, dynamic>? detalles,
  }) async {
    try {
      final doc = await _col.add({
        'accion': accion,
        'super_admin_email': superAdminEmail,
        'tenant_id': tenantId,
        'timestamp': FieldValue.serverTimestamp(),
        if (detalles != null) 'detalles': detalles,
      });
      return doc.id;
    } catch (e) {
      rethrow;
    }
  }
}

final auditLogRepositoryProvider = Provider<AuditLogRepository>(
  (ref) => AuditLogRepository(ref.watch(firestoreProvider)),
);
