import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../core/firebase/firestore.dart';
import '../models/branding.dart';
import '../models/tenant.dart';

/// tenant_id del usuario actual extraído de Custom Claims (como FutureProvider).
///
/// Se basa en [tenantIdProvider] que ya existe en auth_providers.dart.
/// Extrae el primer valor (non-null) del stream y lo devuelve como Future.
/// Este provider sirve como punto de acceso centralizado para el tenant_id
/// en toda la app de cliente.
final currentTenantIdProvider = FutureProvider<String?>((ref) async {
  final tenantAsync = ref.watch(tenantIdProvider);
  return tenantAsync.when(
    data: (tenantId) => tenantId,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Tenant completo del usuario actual.
///
/// Depende de [currentTenantIdProvider]. Si el usuario no tiene tenant_id
/// o el tenant no existe/está suspendido, lanza una excepción.
///
/// Valores emitidos:
/// - AsyncValue.loading: mientras carga el documento
/// - AsyncValue.data(Tenant): cuando se carga exitosamente
/// - AsyncValue.error(Exception): si el tenant no existe, está suspendido,
///   o el usuario no tiene tenant_id
final currentTenantProvider = FutureProvider<Tenant>((ref) async {
  final tenantId = await ref.watch(currentTenantIdProvider.future);

  if (tenantId == null || tenantId.isEmpty) {
    throw Exception('Usuario sin asignar a salón');
  }

  final db = ref.watch(firestoreProvider);
  final doc = await db
      .collection('tenants')
      .doc(tenantId)
      .get();

  if (!doc.exists) {
    throw Exception('Salón no encontrado');
  }

  final data = doc.data();
  if (data == null) {
    throw Exception('Salón no encontrado');
  }

  final tenant = Tenant.fromJson(doc.id, data);

  // Verificar que el tenant está activo
  if (tenant.estado != 'activo') {
    throw Exception('Tu salón ha sido suspendido');
  }

  return tenant;
});

/// Configuración de marca del usuario actual.
///
/// Extrae la configuración de branding del tenant actual.
/// Si no hay tenant o el tenant no tiene branding, devuelve
/// una Branding vacía (con valores por defecto).
final currentBrandingProvider = FutureProvider<Branding>((ref) async {
  try {
    final tenant = await ref.watch(currentTenantProvider.future);
    return tenant.branding;
  } catch (_) {
    // Si no hay tenant, devolver branding vacía
    return const Branding();
  }
});
