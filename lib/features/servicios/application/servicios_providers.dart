import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../../../shared/providers/tenant_providers.dart';
import '../data/servicios_repository.dart';
import '../domain/servicio.dart';

/// Provider lazy de ServiciosRepository que depende del tenant_id actual.
///
/// Cada vez que cambia currentTenantIdProvider, se crea una nueva instancia
/// del repositorio (automáticamente re-dispara los StreamProviders que dependen).
final serviciosRepositoryProvider =
    Provider.family<ServiciosRepository, String?>((ref, tenantId) {
  if (tenantId == null || tenantId.isEmpty) {
    throw Exception('Tenant ID requerido');
  }
  return ServiciosRepository(ref.watch(firestoreProvider), tenantId);
});

/// Stream de todos los servicios del tenant actual, ordenados alfabéticamente.
///
/// Depende de [currentTenantIdProvider]. Si el tenant_id no está disponible,
/// emite lista vacía.
final serviciosStreamProvider = StreamProvider<List<Servicio>>((ref) async* {
  final tenantId = await ref.watch(currentTenantIdProvider.future);

  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  final repo = ref.watch(serviciosRepositoryProvider(tenantId));
  yield* repo.watchAll();
});
