import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/audit_log.dart';
import '../data/audit_log_repository.dart';

/// Observa todos los audit logs de la plataforma (solo super-admin).
///
/// Emite una lista de AuditLog ordenada por timestamp descendente.
/// Mientras carga, emite AsyncLoading; en caso de error, emite AsyncError.
final allAuditLogsProvider = StreamProvider<List<AuditLog>>((ref) {
  final repo = ref.watch(auditLogRepositoryProvider);
  return repo.watchAllAuditLogs();
});

/// Observa los audit logs filtrados por tenant_id.
///
/// Param: tenantId - ID del tenant a filtrar.
/// Emite una lista de AuditLog ordenada por timestamp descendente.
/// Mientras carga, emite AsyncLoading; en caso de error, emite AsyncError.
final tenantAuditLogsProvider =
    StreamProvider.family<List<AuditLog>, String>((ref, tenantId) {
  final repo = ref.watch(auditLogRepositoryProvider);
  return repo.watchAuditLogsByTenant(tenantId);
});

/// Observa los audit logs filtrados por acción específica.
///
/// Param: action - Tipo de acción a filtrar (ej: 'crear_usuario').
/// Emite una lista de AuditLog ordenada por timestamp descendente.
/// Mientras carga, emite AsyncLoading; en caso de error, emite AsyncError.
final auditLogsByActionProvider =
    StreamProvider.family<List<AuditLog>, String>((ref, action) {
  final repo = ref.watch(auditLogRepositoryProvider);
  return repo.watchAuditLogsByAction(action);
});

/// Observa los audit logs filtrados por tenant_id y acción.
///
/// Param: (tenantId, action) - Tupla con tenant ID y acción.
/// Emite una lista de AuditLog ordenada por timestamp descendente.
/// Mientras carga, emite AsyncLoading; en caso de error, emite AsyncError.
final auditLogsByTenantAndActionProvider = StreamProvider
    .family<List<AuditLog>, (String, String)>((ref, params) {
  final repo = ref.watch(auditLogRepositoryProvider);
  final (tenantId, action) = params;
  return repo.watchAuditLogsByTenantAndAction(tenantId, action);
});

/// Estado del filtro de acción en la pantalla de audit logs.
///
/// Almacena la acción actualmente seleccionada para filtrar (null = sin filtro).
class AuditLogActionFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void setAction(String? action) => state = action;
}

final auditLogActionFilterProvider =
    NotifierProvider<AuditLogActionFilter, String?>(
        AuditLogActionFilter.new);
