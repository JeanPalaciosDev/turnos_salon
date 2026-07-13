import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tokens.dart';
import '../application/tenant_providers.dart';
import '../data/tenant_repository.dart';
import '../domain/tenant.dart';
import '../../admin/presentation/manage_tenant_users_screen.dart';

/// Pantalla de administración de tenants (solo super-admin).
///
/// Muestra lista de todos los salones (tenants):
/// - Nombre, email del dueño, estado, fecha de creación
/// - Acciones: Editar, Ver usuarios, Eliminar
/// - FAB para crear nuevo tenant (navega a /crear-salon)
///
/// En Phase 5: implementa CRUD básico con UI Material 3.
/// Phase 6+: integrará actualización de branding en tiempo real.
class TenantsAdminScreen extends ConsumerWidget {
  const TenantsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(allTenantsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar salones'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Crear salón'),
        onPressed: () => context.goNamed('crear-salon'),
      ),
      body: tenantsAsync.when(
        data: (tenants) {
          if (tenants.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: Insets.lg),
                  const Text('No hay salones aún'),
                  const SizedBox(height: Insets.lg),
                  FilledButton.tonal(
                    onPressed: () => context.goNamed('crear-salon'),
                    child: const Text('Crear primer salón'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.lg,
            ),
            itemCount: tenants.length,
            itemBuilder: (context, idx) => TenantCard(
              tenant: tenants[idx],
              onEdit: () => _showEditForm(context, ref, tenants[idx]),
              onViewUsers: () => _showUsersDialog(context, tenants[idx]),
              onDelete: () => _showDeleteConfirmation(context, ref, tenants[idx]),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, _) => Center(
          child: Text('Error: ${err.toString()}'),
        ),
      ),
    );
  }

  void _showEditForm(
    BuildContext context,
    WidgetRef ref,
    Tenant tenant,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TenantEditSheet(
        tenant: tenant,
        onSave: (updatedTenant) {
          ref.read(tenantRepositoryProvider).actualizarTenant(
            tenant.id,
            {
              'name': updatedTenant.name,
              'estado': updatedTenant.estado,
              'branding': updatedTenant.branding.toMap(),
            },
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showUsersDialog(BuildContext context, Tenant tenant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageTenantUsersScreen(
          tenantId: tenant.id,
          tenantName: tenant.name,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Tenant tenant,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar salón'),
        content: Text(
          '¿Eliminar "${tenant.name}"? Esta acción es irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.delete),
            label: const Text('Eliminar'),
            onPressed: () {
              ref.read(tenantRepositoryProvider).actualizarTenant(
                tenant.id,
                {'estado': 'deleted'},
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Salón "${tenant.name}" eliminado'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Card que muestra info de un tenant.
class TenantCard extends StatelessWidget {
  const TenantCard({
    required this.tenant,
    required this.onEdit,
    required this.onViewUsers,
    required this.onDelete,
    super.key,
  });

  final Tenant tenant;
  final VoidCallback onEdit;
  final VoidCallback onViewUsers;
  final VoidCallback onDelete;

  Color _getEstadoColor(BuildContext context, String estado) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return switch (estado) {
      'activo' => cs.tertiary,
      'suspendido' => cs.tertiary.withValues(alpha: 0.7),
      'deleted' => cs.error,
      _ => cs.outlineVariant,
    };
  }

  String _getEstadoLabel(String estado) {
    return switch (estado) {
      'activo' => 'Activo',
      'suspendido' => 'Suspendido',
      'deleted' => 'Eliminado',
      _ => estado,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final createdAt = tenant.createdAt;
    final dateStr = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.lg),
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado: nombre + estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tenant.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(
                    _getEstadoLabel(tenant.estado),
                    style: TextStyle(
                      color: cs.onTertiary,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: _getEstadoColor(context, tenant.estado),
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),

            // Info: email + fecha
            Text(
              tenant.ownerEmail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'Creado el $dateStr',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.lg),

            // Acciones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                  onPressed: onEdit,
                ),
                const SizedBox(width: Insets.sm),
                TextButton.icon(
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Usuarios'),
                  onPressed: onViewUsers,
                ),
                const SizedBox(width: Insets.sm),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal para editar un tenant.
class TenantEditSheet extends StatefulWidget {
  const TenantEditSheet({
    required this.tenant,
    required this.onSave,
    super.key,
  });

  final Tenant tenant;
  final Function(Tenant) onSave;

  @override
  State<TenantEditSheet> createState() => _TenantEditSheetState();
}

class _TenantEditSheetState extends State<TenantEditSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _colorCtrl;
  late String _estado;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.tenant.name);
    _colorCtrl = TextEditingController(
      text: widget.tenant.branding.colorPrimary ?? '#534AB7',
    );
    _estado = widget.tenant.estado;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.tenant.copyWith(
      name: _nameCtrl.text.trim(),
      estado: _estado,
      branding: widget.tenant.branding.copyWith(
        colorPrimary: _colorCtrl.text.trim(),
      ),
    );
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollCtrl) => Scaffold(
        appBar: AppBar(
          title: const Text('Editar salón'),
          leading: const SizedBox.shrink(),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nombre
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del salón',
                  prefixIcon: Icon(Icons.store_outlined),
                ),
              ),
              const SizedBox(height: Insets.lg),

              // Estado
              DropdownButtonFormField<String>(
                value: _estado,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'activo', child: Text('Activo')),
                  DropdownMenuItem(
                    value: 'suspendido',
                    child: Text('Suspendido'),
                  ),
                  DropdownMenuItem(value: 'deleted', child: Text('Eliminado')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _estado = val);
                },
              ),
              const SizedBox(height: Insets.lg),

              // Color principal
              TextField(
                controller: _colorCtrl,
                decoration: InputDecoration(
                  labelText: 'Color principal',
                  prefixIcon: const Icon(Icons.palette_outlined),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(Insets.sm),
                    decoration: BoxDecoration(
                      color: _parseColor(_colorCtrl.text),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Insets.xl),

              // Botón guardar
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Guardar cambios'),
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final cleanHex = hex.replaceFirst('#', '');
      if (cleanHex.length == 6) {
        return Color(int.parse('FF$cleanHex', radix: 16));
      }
    } catch (_) {}
    return Colors.purple;
  }
}
