import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/tenant_creation_service.dart';
import '../data/tenant_repository.dart';
import '../domain/tenant.dart';

/// Observa el tenant del usuario actual.
///
/// Combina:
/// 1. [tenantIdProvider] - extrae tenant_id de los Custom Claims
/// 2. [tenantRepositoryProvider] - fetch del documento tenants/{tenant_id}
///
/// Emite null si:
/// - Usuario no autenticado
/// - Usuario sin tenant_id asignado (edge case: super_admin)
/// - El documento tenant no existe
///
/// Usado para leer la configuración de branding e información general del salon.
final currentTenantProvider = StreamProvider<Tenant?>((ref) {
  final tenantIdAsync = ref.watch(tenantIdProvider);

  // Mientras se resuelve el tenant_id, emite null.
  final tenantId = tenantIdAsync.value;
  if (tenantId == null) {
    return Stream<Tenant?>.value(null);
  }

  // Una vez resuelto el tenant_id, fetch el documento.
  return ref.watch(tenantRepositoryProvider).watchTenant(tenantId);
});

/// Observa todos los tenants de la plataforma (solo super-admin).
///
/// Retorna lista de Tenant ordenados por fecha de creación descendente.
/// Emite lista vacía si hay error.
final allTenantsProvider = StreamProvider<List<Tenant>>((ref) {
  return ref.watch(tenantRepositoryProvider).watchAllTenants();
});

/// Servicio para crear nuevos tenants vía Cloud Function.
///
/// Inyectable para testeo. En producción, llama al endpoint
/// configurado en [kCloudFunctionCreateTenant].
final tenantCreationServiceProvider = Provider<TenantCreationService>((ref) {
  return TenantCreationService();
});
