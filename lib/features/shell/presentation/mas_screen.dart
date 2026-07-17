import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/auth_repository.dart';

/// Pantalla "Más": agrupa las opciones que antes vivían en el `AppDrawer`,
/// excepto Agenda y Clientes (que ahora son destinos de la barra inferior).
class MasScreen extends ConsumerWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Super-admin: gestión de tenants (salones).
            ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('Gestionar salones'),
              onTap: () => context.goNamed('tenants-admin'),
            ),
            const Divider(),
            // Servicios, Trabajadores y Usuarios (matriz de permisos §7).
            // Se apilan sobre la barra (root navigator).
            ...[
              ListTile(
                leading: const Icon(Icons.design_services_outlined),
                title: const Text('Servicios'),
                onTap: () => context.push('/servicios'),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Trabajadores'),
                onTap: () => context.push('/trabajadores'),
              ),
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Usuarios'),
                onTap: () => context.push('/usuarios'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.insights_outlined),
                title: const Text('Dashboard'),
                onTap: () => context.push('/dashboard'),
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () {
                // El redirect del router lleva a /login; no navegamos manual.
                ref.read(authRepositoryProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
