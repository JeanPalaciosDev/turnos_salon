import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tokens.dart';
import '../../../shared/providers/tenant_providers.dart';
import '../application/servicios_providers.dart';
import '../domain/servicio.dart';
import 'servicio_form.dart';

/// Pantalla de gestión de servicios (Fase 3 · CRUD).
class ServiciosScreen extends ConsumerWidget {
  const ServiciosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviciosAsync = ref.watch(serviciosStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showServicioForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Servicio'),
      ),
      body: serviciosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar servicios:\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (servicios) {
          if (servicios.isEmpty) return const _EmptyServicios();
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: servicios.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _ServicioTile(servicios[i]),
          );
        },
      ),
    );
  }
}

class _ServicioTile extends ConsumerWidget {
  const _ServicioTile(this.servicio);

  final Servicio servicio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = servicio;
    final subtitle = <String>[
      'ref. \$${s.precioReferencia}',
      '${s.duracionMin} min',
      if (s.categoria != null && s.categoria!.isNotEmpty) s.categoria!,
      if (!s.activo) 'inactivo',
    ].join('  ·  ');

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListTile(
      minVerticalPadding: Insets.md,
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        child: Icon(Icons.content_cut, color: scheme.onSecondaryContainer),
      ),
      title: Text(
        s.nombre,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Eliminar',
        onPressed: () => _confirmDelete(context, ref),
      ),
      onTap: () => showServicioForm(context, servicio: s),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text(
            '¿Eliminar "${servicio.nombre}"? Esta acción no se puede deshacer.'),
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
        await ref.read(serviciosRepositoryProvider(tenantId)).delete(servicio.id);
      }
    }
  }
}

class _EmptyServicios extends StatelessWidget {
  const _EmptyServicios();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.design_services_outlined,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Todavía no hay servicios',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tocá "Servicio" para agregar el primero\n(corte, color, brushing, etc).',
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
