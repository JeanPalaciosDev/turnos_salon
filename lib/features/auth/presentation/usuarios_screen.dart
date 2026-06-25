import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tokens.dart';
import '../../trabajadores/domain/trabajador.dart';
import '../data/usuarios_repository.dart';
import '../domain/usuario.dart';
import 'usuario_form.dart';

/// Pantalla admin de gestión de staff/usuarios (Fase 2D · solo dueño).
///
/// Lista en vivo de `usuarios`, con rol, email y un switch activo/inactivo.
/// El FAB abre el formulario de alta (crea cuenta Auth + doc `usuarios`).
class UsuariosScreen extends ConsumerWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync =
        ref.watch(usuariosRepositoryProvider).watchUsuarios();

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showUsuarioForm(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Usuario'),
      ),
      body: StreamBuilder<List<Usuario>>(
        stream: usuariosAsync,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error al cargar usuarios:\n${snap.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final usuarios = snap.data!;
          if (usuarios.isEmpty) return const _EmptyUsuarios();
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: usuarios.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _UsuarioTile(usuarios[i]),
          );
        },
      ),
    );
  }
}

class _UsuarioTile extends ConsumerWidget {
  const _UsuarioTile(this.usuario);

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = usuario;
    final subtitle = <String>[
      rolLabel(u.rol),
      if (u.email.isNotEmpty) u.email,
    ].join('  ·  ');

    final theme = Theme.of(context);
    return ListTile(
      minVerticalPadding: Insets.md,
      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
      title: Text(
        u.nombre.isEmpty ? '(sin nombre)' : u.nombre,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Switch(
        value: u.activo,
        onChanged: (v) =>
            ref.read(usuariosRepositoryProvider).setActivo(u.uid, v),
      ),
      onTap: () => _editarRol(context, ref),
    );
  }

  /// Menú simple para cambiar el rol de un usuario existente.
  Future<void> _editarRol(BuildContext context, WidgetRef ref) async {
    final nuevo = await showModalBottomSheet<RolTrabajador>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Rol de ${usuario.nombre}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final r in RolTrabajador.values)
              ListTile(
                title: Text(rolLabel(r)),
                trailing: r == usuario.rol ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, r),
              ),
          ],
        ),
      ),
    );
    if (nuevo != null && nuevo != usuario.rol) {
      await ref
          .read(usuariosRepositoryProvider)
          .actualizarRol(usuario.uid, nuevo);
    }
  }
}

class _EmptyUsuarios extends StatelessWidget {
  const _EmptyUsuarios();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_accounts_outlined,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Todavía no hay usuarios',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tocá "Usuario" para dar de alta al equipo\n(cuenta de acceso + rol).',
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
