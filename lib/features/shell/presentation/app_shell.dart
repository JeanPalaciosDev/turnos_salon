import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Contenedor de la navegación primaria: muestra la rama activa del
/// `StatefulShellRoute.indexedStack` y una `NavigationBar` inferior (M3).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Shell provisto por `StatefulShellRoute.indexedStack`. Conserva el estado
  /// de cada rama (Agenda / Clientes / Más) entre cambios de pestaña.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
