import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../../../core/util/horas.dart';
import '../../../shared/providers/tenant_providers.dart';
import '../data/turnos_repository.dart';
import '../domain/turno.dart';

/// Provider lazy de TurnosRepository que depende del tenant_id actual.
///
/// Cada vez que cambia currentTenantIdProvider, se crea una nueva instancia
/// del repositorio (automáticamente re-dispara los StreamProviders que dependen).
final turnosRepositoryProvider =
    Provider.family<TurnosRepository, String?>((ref, tenantId) {
  if (tenantId == null || tenantId.isEmpty) {
    throw Exception('Tenant ID requerido');
  }
  return TurnosRepository(ref.watch(firestoreProvider), tenantId);
});

/// Stream de los turnos de un día ('yyyy-MM-dd'), filtrados por tenant.
///
/// Depende de [currentTenantIdProvider]. Si el tenant_id no está disponible,
/// emite lista vacía.
final turnosPorFechaProvider = StreamProvider.family<List<Turno>, String>(
  (ref, fecha) async* {
    final tenantId = await ref.watch(currentTenantIdProvider.future);

    if (tenantId == null || tenantId.isEmpty) {
      yield [];
      return;
    }

    final repo = ref.watch(turnosRepositoryProvider(tenantId));
    yield* repo.watchByFecha(fecha);
  },
);

/// Stream del historial de turnos de un cliente, filtrados por tenant
/// (más reciente primero).
///
/// Depende de [currentTenantIdProvider]. Si el tenant_id no está disponible,
/// emite lista vacía.
final turnosPorClienteProvider = StreamProvider.family<List<Turno>, String>(
  (ref, clienteId) async* {
    final tenantId = await ref.watch(currentTenantIdProvider.future);

    if (tenantId == null || tenantId.isEmpty) {
      yield [];
      return;
    }

    final repo = ref.watch(turnosRepositoryProvider(tenantId));
    yield* repo.watchByCliente(clienteId);
  },
);

/// Turnos de la semana cuyo lunes es [lunesFecha] ('yyyy-MM-dd'),
/// filtrados por tenant.
///
/// Depende de [currentTenantIdProvider]. Si el tenant_id no está disponible,
/// emite lista vacía.
final turnosPorSemanaProvider = StreamProvider.family<List<Turno>, String>(
  (ref, lunesFecha) async* {
    final tenantId = await ref.watch(currentTenantIdProvider.future);

    if (tenantId == null || tenantId.isEmpty) {
      yield [];
      return;
    }

    final lunes = parseFecha(lunesFecha);
    final domingo = lunes.add(const Duration(days: 6));
    final repo = ref.watch(turnosRepositoryProvider(tenantId));
    yield* repo.watchByRango(lunesFecha, fmtFecha(domingo));
  },
);
