import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../../../shared/providers/tenant_providers.dart';
import '../data/clientes_repository.dart';
import '../domain/cliente.dart';

/// Provider lazy de ClientesRepository que depende del tenant_id actual.
///
/// Cada vez que cambia currentTenantIdProvider, se crea una nueva instancia
/// del repositorio (automáticamente re-dispara los StreamProviders que dependen).
final clientesRepositoryProvider =
    Provider.family<ClientesRepository, String?>((ref, tenantId) {
  if (tenantId == null || tenantId.isEmpty) {
    throw Exception('Tenant ID requerido');
  }
  return ClientesRepository(ref.watch(firestoreProvider), tenantId);
});

/// Stream de todos los clientes del tenant actual, ordenados alfabéticamente.
///
/// Depende de [currentTenantIdProvider]. Si el tenant_id no está disponible,
/// emite lista vacía.
final clientesStreamProvider = StreamProvider<List<Cliente>>((ref) async* {
  final tenantId = await ref.watch(currentTenantIdProvider.future);

  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  final repo = ref.watch(clientesRepositoryProvider(tenantId));
  yield* repo.watchAll();
});
