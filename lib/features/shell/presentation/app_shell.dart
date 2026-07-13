import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/data/auth_repository.dart';
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

    // Observar usuario actual y su rol
    final usuarioAsync = ref.watch(usuarioActualProvider);
    final usuario = usuarioAsync.value;
    final rol = usuario?.rol;

    // Construir subtítulo con rol del usuario
    String? subtitulo;
    if (usuario != null && rol != null) {
      final rolLabel = _getRolLabel(rol);
      subtitulo = rol.name == 'dueno' ? 'Dueño' : rolLabel;
    }

    return Scaffold(
      appBar: salonName != null
          ? AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(salonName),
                  if (subtitulo != null)
                    Text(
                      subtitulo,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
              elevation: 0,
              actions: [
                // Botón de logout
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    if (value == 'logout') {
                      // Mostrar diálogo de confirmación
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cerrar sesión'),
                          content:
                              const Text('¿Deseas cerrar la sesión actual?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Cerrar sesión'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        await ref
                            .read(authRepositoryProvider)
                            .signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'logout',
                      child: Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ],
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

  /// Convierte el rol a una etiqueta legible en español.
  static String _getRolLabel(dynamic rol) {
    final rolName = rol.toString().split('.').last;
    return switch (rolName) {
      'dueno' => 'Dueño',
      'recepcion' => 'Recepcionista',
      'estilista' => 'Estilista',
      _ => rolName,
    };
  }
}
