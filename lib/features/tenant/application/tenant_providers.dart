import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
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
