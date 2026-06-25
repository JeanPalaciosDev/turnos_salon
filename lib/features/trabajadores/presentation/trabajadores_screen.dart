import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tokens.dart';
import '../../../core/util/colores.dart';
import '../data/trabajadores_repository.dart';
import '../domain/trabajador.dart';
import 'trabajador_detalle_screen.dart';
import 'trabajador_form.dart';

/// Pantalla de gestión de trabajadores (Fase 3 · CRUD).
class TrabajadoresScreen extends ConsumerWidget {
  const TrabajadoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trabajadoresAsync = ref.watch(trabajadoresStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trabajadores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTrabajadorForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Trabajador'),
      ),
      body: trabajadoresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar trabajadores:\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (trabajadores) {
          if (trabajadores.isEmpty) return const _EmptyTrabajadores();
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: trabajadores.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _TrabajadorTile(trabajadores[i]),
          );
        },
      ),
    );
  }
}

class _TrabajadorTile extends StatelessWidget {
  const _TrabajadorTile(this.trabajador);

  final Trabajador trabajador;

  @override
  Widget build(BuildContext context) {
    final t = trabajador;
    final theme = Theme.of(context);
    final subtitle = <String>[
      rolLabel(t.rol),
      if (t.horario.isNotEmpty) '${t.horario.length} franja(s)',
      if (!t.activo) 'inactivo',
    ].join('  ·  ');
    final inicial =
        t.nombre.isNotEmpty ? t.nombre.characters.first.toUpperCase() : '?';

    return ListTile(
      minVerticalPadding: Insets.md,
      leading: CircleAvatar(
        backgroundColor: colorFromHex(t.color),
        child: Text(
          inicial,
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        t.nombre,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrabajadorDetalleScreen(trabajadorId: t.id),
        ),
      ),
    );
  }
}

class _EmptyTrabajadores extends StatelessWidget {
  const _EmptyTrabajadores();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Todavía no hay trabajadores',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tocá "Trabajador" para agregar al equipo.',
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
