import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../tenant/application/tenant_providers.dart';

/// Contenedor de la navegación primaria: muestra la rama activa del
/// `StatefulShellRoute.indexedStack` y una `NavigationBar` inferior (M3).
///
/// Opcionalmente muestra el nombre del salón (tenant) en la AppBar si el
/// usuario está autenticado y tiene un tenant asignado.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Shell provisto por `StatefulShellRoute.indexedStack`. Conserva el estado
  /// de cada rama (Agenda / Clientes / Más) entre cambios de pestaña.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observar tenant actual para mostrar nombre del salón
    final tenantAsync = ref.watch(currentTenantProvider);
    final tenant = tenantAsync.value;
    final salonName = tenant?.name;

    return Scaffold(
      appBar: salonName != null
          ? AppBar(
              title: Text(salonName),
              elevation: 0,
            )
          : null,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          // initialLocation: al re-tocar la pestaña ya activa, reseteamos a su
          // ubicación inicial (comportamiento recomendado por go_router).
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}
