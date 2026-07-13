import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../../../shared/providers/tenant_providers.dart';
import '../data/trabajadores_repository.dart';
import '../domain/ausencia.dart';
import '../domain/trabajador.dart';

/// Provider lazy de TrabajadoresRepository que depende del tenant_id actual.
///
/// Cada vez que cambia currentTenantIdProvider, se crea una nueva instancia
/// del repositorio (automáticamente re-dispara los StreamProviders que dependen).
final trabajadoresRepositoryProvider =
    Provider.family<TrabajadoresRepository, String?>((ref, tenantId) {
  if (tenantId == null || tenantId.isEmpty) {
    throw Exception('Tenant ID requerido');
  }
  return TrabajadoresRepository(ref.watch(firestoreProvider), tenantId);
});

/// Stream de todos los trabajadores del tenant actual, ordenados alfabéticamente.
///
/// Depende de [currentTenantIdProvider]. Si el tenant_id no está disponible,
/// emite lista vacía.
final trabajadoresStreamProvider = StreamProvider<List<Trabajador>>((ref) async* {
  final tenantId = await ref.watch(currentTenantIdProvider.future);

  if (tenantId == null || tenantId.isEmpty) {
    yield [];
    return;
  }

  final repo = ref.watch(trabajadoresRepositoryProvider(tenantId));
  yield* repo.watchAll();
});

/// Stream de las ausencias de un trabajador específico.
///
/// Depende de [currentTenantIdProvider]. Si el tenant_id no está disponible,
/// emite lista vacía.
final ausenciasProvider = StreamProvider.family<List<Ausencia>, String>(
  (ref, trabajadorId) async* {
    final tenantId = await ref.watch(currentTenantIdProvider.future);

    if (tenantId == null || tenantId.isEmpty) {
      yield [];
      return;
    }

    final repo = ref.watch(trabajadoresRepositoryProvider(tenantId));
    yield* repo.watchAusencias(trabajadorId);
  },
);
