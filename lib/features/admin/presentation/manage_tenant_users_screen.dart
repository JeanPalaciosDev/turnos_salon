import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tokens.dart';
import '../../../shared/models/tenant_user.dart';
import '../../auth/data/admin_user_service.dart';
import '../data/tenant_user_repository.dart';

/// Pantalla para gestionar los usuarios de un tenant específico.
///
/// Muestra:
/// - Tabla con usuarios (email, nombre, fecha creación, último login)
/// - Acciones: enviar reseteo, desactivar, eliminar
/// - Bulk actions: seleccionar múltiples usuarios
/// - Filtros y búsqueda (opcional)
class ManageTenantUsersScreen extends ConsumerStatefulWidget {
  const ManageTenantUsersScreen({
    required this.tenantId,
    required this.tenantName,
    super.key,
  });

  final String tenantId;
  final String tenantName;

  @override
  ConsumerState<ManageTenantUsersScreen> createState() =>
      _ManageTenantUsersScreenState();
}

class _ManageTenantUsersScreenState
    extends ConsumerState<ManageTenantUsersScreen> {
  final Set<String> _selectedUserIds = {};
  String _searchQuery = '';
  bool _isProcessing = false;

  Future<void> _resendPasswordReset(TenantUser user) async {
    setState(() => _isProcessing = true);

    try {
      final adminService = ref.read(adminUserServiceProvider);
      await adminService.resendPasswordReset(user.email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Email de reseteo enviado a ${user.email}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleUserActive(TenantUser user) async {
    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(tenantUserRepositoryProvider);
      if (user.activo) {
        await repo.deactivateTenantUser(widget.tenantId, user.uid);
      } else {
        await repo.activateTenantUser(widget.tenantId, user.uid);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.activo
                ? '${user.nombre} desactivado'
                : '${user.nombre} activado',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteUser(TenantUser user) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar usuario'),
            content: Text(
              '¿Eliminar a ${user.nombre}? Esta acción es irreversible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.delete),
                label: const Text('Eliminar'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _isProcessing = true);

    try {
      final adminService = ref.read(adminUserServiceProvider);
      await adminService.deleteUser(
        tenantId: widget.tenantId,
        uid: user.uid,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.nombre} eliminado'),
          duration: const Duration(seconds: 2),
        ),
      );

      _selectedUserIds.remove(user.uid);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _bulkDeactivate() async {
    if (_selectedUserIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Desactivar usuarios'),
            content: Text(
              '¿Desactivar ${_selectedUserIds.length} usuarios seleccionados?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.lock),
                label: const Text('Desactivar'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(tenantUserRepositoryProvider);
      for (final uid in _selectedUserIds) {
        await repo.deactivateTenantUser(widget.tenantId, uid);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedUserIds.length} usuarios desactivados'),
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() => _selectedUserIds.clear());
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedUserIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar usuarios'),
            content: Text(
              '¿Eliminar ${_selectedUserIds.length} usuarios seleccionados? Esta acción es irreversible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.delete),
                label: const Text('Eliminar'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _isProcessing = true);

    try {
      final adminService = ref.read(adminUserServiceProvider);
      for (final uid in _selectedUserIds) {
        await adminService.deleteUser(
          tenantId: widget.tenantId,
          uid: uid,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedUserIds.length} usuarios eliminados'),
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() => _selectedUserIds.clear());
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Crear un provider dinámico para los usuarios del tenant
    final usersProvider = StreamProvider<List<TenantUser>>((ref) {
      final repo = ref.watch(tenantUserRepositoryProvider);
      return repo.watchTenantUsers(widget.tenantId);
    });

    final usersAsync = ref.watch(usersProvider);

    return usersAsync.when(
      data: (users) {
        // Filtrar por búsqueda
        final filteredUsers = _searchQuery.isEmpty
            ? users
            : users
                .where((u) =>
                    u.nombre.toLowerCase().contains(_searchQuery) ||
                    u.email.toLowerCase().contains(_searchQuery))
                .toList();

        if (filteredUsers.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Usuarios de ${widget.tenantName}'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: cs.outlineVariant,
                  ),
                  const SizedBox(height: Insets.lg),
                  const Text('No hay usuarios aún'),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Usuarios de ${widget.tenantName}'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o email...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.sm,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              // Bulk actions bar
              if (_selectedUserIds.isNotEmpty)
                Container(
                  color: cs.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedUserIds.length} seleccionados',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isProcessing ? null : _bulkDeactivate,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Desactivar'),
                      ),
                      TextButton.icon(
                        onPressed: _isProcessing ? null : _bulkDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, idx) {
                    final user = filteredUsers[idx];
                    final isSelected = _selectedUserIds.contains(user.uid);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: Insets.xs,
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: _isProcessing
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedUserIds.add(user.uid);
                                    } else {
                                      _selectedUserIds.remove(user.uid);
                                    }
                                  });
                                },
                        ),
                        title: Text(user.nombre),
                        subtitle: Text(user.email),
                        trailing: SizedBox(
                          width: 200,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Creado: ${_formatDate(user.createdAt)}',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                  if (user.lastLogin != null)
                                    Text(
                                      'Último login: ${_formatDate(user.lastLogin!)}',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                ],
                              ),
                              PopupMenuButton<String>(
                                enabled: !_isProcessing,
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'reset_password',
                                    child: const Row(
                                      children: [
                                        Icon(Icons.vpn_key_outlined),
                                        SizedBox(width: Insets.md),
                                        Text('Resetear Contraseña'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle_active',
                                    child: Row(
                                      children: [
                                        Icon(
                                          user.activo
                                              ? Icons.lock_outline
                                              : Icons.lock_open_outlined,
                                        ),
                                        const SizedBox(width: Insets.md),
                                        Text(
                                          user.activo ? 'Desactivar' : 'Activar',
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete_outline),
                                        SizedBox(width: Insets.md),
                                        Text('Eliminar'),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'reset_password':
                                      await _resendPasswordReset(user);
                                    case 'toggle_active':
                                      await _toggleUserActive(user);
                                    case 'delete':
                                      await _deleteUser(user);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text('Usuarios de ${widget.tenantName}'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          title: Text('Usuarios de ${widget.tenantName}'),
        ),
        body: Center(
          child: Text('Error: ${err.toString()}'),
        ),
      ),
    );
  }
}
