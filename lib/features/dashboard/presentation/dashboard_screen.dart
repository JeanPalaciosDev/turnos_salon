import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tokens.dart';
import '../../../core/util/moneda.dart';
import '../../admin/application/admin_providers.dart';
import '../../trabajadores/application/trabajadores_providers.dart';
import '../../trabajadores/domain/trabajador.dart';
import '../application/dashboard_providers.dart';
import '../domain/dashboard_metrics.dart';

/// Pantalla de métricas agregadas del salón (solo dueño). Filtrable por
/// rango de fechas y trabajador; listas rankeadas sin librería de gráficos.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turnosAsync = ref.watch(dashboardTurnosProvider);
    final metrics = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Column(
        children: [
          const _FiltrosHeader(),
          const Divider(height: 1),
          Expanded(
            child: turnosAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : turnosAsync.hasError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Error: ${turnosAsync.error}',
                              textAlign: TextAlign.center),
                        ),
                      )
                    : (turnosAsync.value?.isEmpty ?? true)
                        ? const _SinTurnos()
                        : _DashboardBody(metrics: metrics),
          ),
        ],
      ),
    );
  }
}

class _FiltrosHeader extends ConsumerWidget {
  const _FiltrosHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rango = ref.watch(rangoDashboardProvider);
    final trabajadores =
        ref.watch(trabajadoresStreamProvider).value ?? const <Trabajador>[];
    final filtro = ref.watch(dashboardTrabajadorFiltroProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.md, Insets.sm, Insets.md, Insets.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fmtRango(rango),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.xs,
            children: [
              ActionChip(
                label: const Text('Este mes'),
                onPressed: () =>
                    ref.read(rangoDashboardProvider.notifier).esteMes(),
              ),
              ActionChip(
                label: const Text('Mes anterior'),
                onPressed: () =>
                    ref.read(rangoDashboardProvider.notifier).mesAnterior(),
              ),
              ActionChip(
                label: const Text('Esta semana'),
                onPressed: () =>
                    ref.read(rangoDashboardProvider.notifier).estaSemana(),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          DropdownButton<String?>(
            value: filtro,
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todos'),
              ),
              for (final t in trabajadores)
                DropdownMenuItem<String?>(
                  value: t.id,
                  child: Text(t.nombre),
                ),
            ],
            onChanged: (id) =>
                ref.read(dashboardTrabajadorFiltroProvider.notifier).set(id),
          ),
        ],
      ),
    );
  }

  String _fmtRango(DateTimeRange rango) {
    String dd(DateTime d) => d.day.toString().padLeft(2, '0');
    String mm(DateTime d) => d.month.toString().padLeft(2, '0');
    return '${dd(rango.start)}/${mm(rango.start)} - '
        '${dd(rango.end)}/${mm(rango.end)}/${rango.end.year}';
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.metrics});

  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentLogsAsync = ref.watch(allAuditLogsProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Recent Activity Section
        _RecentActivitySection(logsAsync: recentLogsAsync),

        _Seccion<String, int>(
          titulo: 'Servicios más solicitados',
          filas: metrics.porServicioConteo,
          formatoValor: (v) => v.toString(),
        ),
        _Seccion<String, num>(
          titulo: 'Servicios de mayor ingreso',
          filas: metrics.porServicioIngreso,
          formatoValor: fmtMoneda,
        ),
        _Seccion<String, int>(
          titulo: 'Trabajadores — más turnos',
          filas: metrics.porTrabajadorConteo,
          formatoValor: (v) => v.toString(),
        ),
        _Seccion<String, num>(
          titulo: 'Trabajadores — mayor ingreso',
          filas: metrics.porTrabajadorIngreso,
          formatoValor: fmtMoneda,
        ),
        _Seccion<String, int>(
          titulo: 'Días con más turnos',
          filas: metrics.porDiaConteo,
          formatoValor: (v) => v.toString(),
        ),
        _Seccion<String, num>(
          titulo: 'Días con mayor ingreso',
          filas: metrics.porDiaIngreso,
          formatoValor: fmtMoneda,
        ),
        _Seccion<int, int>(
          titulo: 'Horarios con más turnos',
          filas: metrics.porHoraConteo,
          formatoValor: (v) => v.toString(),
          formatoEtiqueta: _fmtHora,
        ),
        _Seccion<int, num>(
          titulo: 'Horarios con mayor ingreso',
          filas: metrics.porHoraIngreso,
          formatoValor: fmtMoneda,
          formatoEtiqueta: _fmtHora,
        ),
      ],
    );
  }

  static String _fmtHora(int hora) => '${hora.toString().padLeft(2, '0')}:00';
}

/// Sección genérica: título + top 5 filas con barra de progreso relativa.
/// [E] es el tipo de la etiqueta (String o int), [V] el tipo del valor
/// (int o num).
class _Seccion<E, V extends num> extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.filas,
    required this.formatoValor,
    this.formatoEtiqueta,
  });

  final String titulo;
  final List<(E, V)> filas;
  final String Function(V) formatoValor;
  final String Function(E)? formatoEtiqueta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = filas.take(5).toList();
    final maxValor =
        top.isEmpty ? 0 : top.map((f) => f.$2).reduce((a, b) => a > b ? a : b);

    return Card(
      margin: const EdgeInsets.fromLTRB(
          Insets.md, Insets.xs, Insets.md, Insets.xs),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: theme.textTheme.titleSmall),
            const SizedBox(height: Insets.sm),
            if (top.isEmpty)
              Text(
                'Sin datos en este rango',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              for (final fila in top)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatoEtiqueta != null
                                  ? formatoEtiqueta!(fila.$1)
                                  : fila.$1.toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Text(
                            formatoValor(fila.$2),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        child: LinearProgressIndicator(
                          value: maxValor > 0 ? fila.$2 / maxValor : 0,
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SinTurnos extends StatelessWidget {
  const _SinTurnos();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Sin turnos en este rango',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Probá cambiar el rango de fechas o el filtro de trabajador.',
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

/// Sección de actividad reciente en el dashboard (solo super-admin).
class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({required this.logsAsync});

  final AsyncValue logsAsync;

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
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return logsAsync.when(
      data: (logs) {
        // Mostrar solo los últimos 5
        final recentLogs = logs.take(5).toList();

        if (recentLogs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.fromLTRB(
              Insets.md, Insets.xs, Insets.md, Insets.xs),
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Actividad Reciente',
                      style: theme.textTheme.titleSmall,
                    ),
                    TextButton(
                      onPressed: () {
                        context.goNamed('audit-logs');
                      },
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                ...recentLogs.map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getActionLabel(log.accion),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${log.superAdminEmail} • ${_formatTimestamp(log.timestamp)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Card(
        margin: const EdgeInsets.fromLTRB(
            Insets.md, Insets.xs, Insets.md, Insets.xs),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
