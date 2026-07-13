import 'package:flutter/material.dart';

/// Pantalla de administración de tenants (super-admin only).
///
/// Phase 4 (minimal): placeholder para la UI de gestión.
/// Phase 5 agregará la lista de tenants, crear, editar, suspender.
class TenantsAdminScreen extends StatelessWidget {
  const TenantsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Salones'),
      ),
      body: const Center(
        child: Text('Gestión de Tenants - En desarrollo'),
      ),
    );
  }
}
