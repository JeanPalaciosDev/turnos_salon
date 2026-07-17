import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tokens.dart';
import '../../../shared/providers/tenant_providers.dart';
import '../application/clientes_providers.dart';
import '../domain/cliente.dart';
import 'cliente_form.dart';

/// Pantalla de gestión de clientes (Fase 3 · CRUD).
class ClientesScreen extends ConsumerWidget {
  const ClientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showClienteForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Cliente'),
      ),
      body: clientesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar clientes:\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (clientes) {
          if (clientes.isEmpty) return const _EmptyClientes();
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: clientes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _ClienteTile(clientes[i]),
          );
        },
      ),
    );
  }
}

class _ClienteTile extends ConsumerWidget {
  const _ClienteTile(this.cliente);

  final Cliente cliente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cliente;
    final inicial =
        c.nombre.isNotEmpty ? c.nombre.characters.first.toUpperCase() : '?';
    final theme = Theme.of(context);
    return ListTile(
      minVerticalPadding: Insets.md,
      leading: CircleAvatar(child: Text(inicial)),
      title: Text(
        c.nombre,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        c.telefono?.isNotEmpty == true ? c.telefono! : 'Sin teléfono',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Eliminar',
        onPressed: () => _confirmDelete(context, ref),
      ),
      onTap: () => context.push('/clientes/detalle', extra: c),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text(
            '¿Eliminar a "${cliente.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final tenantId = ref.read(currentTenantIdProvider).value;
      if (tenantId != null && tenantId.isNotEmpty) {
        await ref.read(clientesRepositoryProvider(tenantId)).delete(cliente.id);
      }
    }
  }
}

class _EmptyClientes extends StatelessWidget {
  const _EmptyClientes();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Todavía no hay clientes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tocá "Cliente" para agregar el primero.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
