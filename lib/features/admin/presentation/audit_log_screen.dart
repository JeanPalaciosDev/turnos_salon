import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tokens.dart';
import '../../../shared/models/audit_log.dart';
import '../application/admin_providers.dart';

/// Pantalla para visualizar el audit log de la plataforma.
///
/// Muestra:
/// - Dos tabs: "Todos los logs" (super-admin) y "Logs del Tenant"
/// - Tabla con: Timestamp, Acción, Usuario/Super-Admin, Tenant, Detalles
/// - Filtros: Por tipo de acción, por rango de fechas (opcional)
/// - Ordenamiento: Por timestamp (más recientes primero)
/// - Estado vacío
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({
    this.tenantId,
    super.key,
  });

  final String? tenantId;

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedAction;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tenantId != null ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getActionLabel(String action) => switch (action) {
        'crear_tenant' => 'Crear Tenant',
        'actualizar_tenant' => 'Actualizar Tenant',
        'suspender_tenant' => 'Suspender Tenant',
        'eliminar_tenant' => 'Eliminar Tenant',
        'crear_usuario' => 'Crear Usuario',
        'actualizar_usuario' => 'Actualizar Usuario',
        'cambiar_rol' => 'Cambiar Rol',
        'eliminar_usuario' => 'Eliminar Usuario',
        'resetear_contraseña' => 'Resetear Contraseña',
        _ => action,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Tabs
              if (widget.tenantId != null)
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Logs del Tenant'),
                    Tab(text: 'Todos los Logs'),
                  ],
                ),

              // Filter: Action
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedAction,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por acción',
                    prefixIcon: const Icon(Icons.filter_list),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.sm,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Todas las acciones'),
                    ),
                    ...const [
                      'crear_usuario',
                      'cambiar_rol',
                      'eliminar_usuario',
                      'crear_tenant',
                      'suspender_tenant',
                    ].map(
                      (action) => DropdownMenuItem(
                        value: action,
                        child: Text(_getActionLabel(action)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedAction = value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: widget.tenantId != null
          ? TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Tenant-specific logs
                _AuditLogContent(
                  provider: _selectedAction == null
                      ? tenantAuditLogsProvider(widget.tenantId!)
                      : auditLogsByTenantAndActionProvider(
                          (widget.tenantId!, _selectedAction!),
                        ),
                ),

                // Tab 2: All logs
                _AuditLogContent(
                  provider: _selectedAction == null
                      ? allAuditLogsProvider
                      : auditLogsByActionProvider(_selectedAction!),
                ),
              ],
            )
          : _AuditLogContent(
              provider: _selectedAction == null
                  ? allAuditLogsProvider
                  : auditLogsByActionProvider(_selectedAction!),
            ),
    );
  }
}

/// Widget que muestra el contenido actual del audit log.
class _AuditLogContent extends ConsumerWidget {
  const _AuditLogContent({
    required this.provider,
  });

  final Object provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Usar el provider dinámico
    final logsAsync = ref.watch(provider as dynamic);

    return logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 64,
                  color: cs.outlineVariant,
                ),
                const SizedBox(height: Insets.lg),
                const Text('Sin registros de auditoría'),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: logs.length,
          padding: const EdgeInsets.symmetric(vertical: Insets.sm),
          itemBuilder: (context, idx) {
            final log = logs[idx];
            return _AuditLogCard(log: log);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Text(
            'Error: ${err.toString()}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Card que muestra un audit log individual.
class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.log});

  final AuditLog log;

  String _getActionLabel(String action) => switch (action) {
        'crear_tenant' => 'Crear Tenant',
        'actualizar_tenant' => 'Actualizar Tenant',
        'suspender_tenant' => 'Suspender Tenant',
        'eliminar_tenant' => 'Eliminar Tenant',
        'crear_usuario' => 'Crear Usuario',
        'actualizar_usuario' => 'Actualizar Usuario',
        'cambiar_rol' => 'Cambiar Rol',
        'eliminar_usuario' => 'Eliminar Usuario',
        'resetear_contraseña' => 'Resetear Contraseña',
        _ => action,
      };

  Color _getActionColor(BuildContext context, String action) {
    final cs = Theme.of(context).colorScheme;
    return switch (action) {
      'eliminar_usuario' || 'eliminar_tenant' => cs.error,
      'suspender_tenant' => cs.tertiaryContainer,
      _ => cs.primary,
    };
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'Hace ${diff.inSeconds}s';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado: Acción + Timestamp
            Row(
              children: [
                Chip(
                  label: Text(_getActionLabel(log.accion)),
                  backgroundColor: _getActionColor(context, log.accion),
                  labelStyle: TextStyle(
                    color: cs.onError,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text(
                    _formatTimestamp(log.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),

            // Usuario y Tenant
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Por: ${log.superAdminEmail}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Tenant: ${log.tenantId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Detalles adicionales si existen
            if (log.detalles != null && log.detalles!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: Insets.md),
                  Text(
                    'Detalles:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  ...(log.detalles!.entries.map(
                    (entry) => Text(
                      '${entry.key}: ${entry.value}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
