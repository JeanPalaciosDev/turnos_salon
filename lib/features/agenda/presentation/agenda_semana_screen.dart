import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/util/horas.dart';
import '../../auth/application/auth_providers.dart';
import '../../config/data/config_repository.dart';
import '../../config/domain/salon_config.dart';
import '../../trabajadores/application/trabajadores_providers.dart';
import '../../trabajadores/domain/trabajador.dart';
import '../../turnos/application/turno_providers.dart';
import '../../turnos/domain/turno.dart';
import '../../turnos/presentation/estado_ui.dart';
import '../application/agenda_providers.dart';
import 'chips_trabajadores.dart';

/// Vista semanal de la agenda (pantalla inicial). Muestra los 7 días de la
/// semana con poco detalle; al tocar un día se abre la vista diaria (`/agenda/dia`).
class AgendaSemanaScreen extends ConsumerStatefulWidget {
  const AgendaSemanaScreen({super.key});

  @override
  ConsumerState<AgendaSemanaScreen> createState() =>
      _AgendaSemanaScreenState();
}

class _AgendaSemanaScreenState extends ConsumerState<AgendaSemanaScreen> {
  @override
  Widget build(BuildContext context) {
    // Prefiltro del estilista (copiado verbatim de la vista diaria): el
    // estilista solo ve SU agenda y no puede cambiar de trabajador.
    ref.listen(usuarioActualProvider, (prev, next) {
      final usuario = next.value;
      if (usuario != null &&
          usuario.rol == RolTrabajador.estilista &&
          usuario.trabajadorId.isNotEmpty) {
        final actual = ref.read(trabajadorFiltroProvider);
        if (actual != usuario.trabajadorId) {
          ref
              .read(trabajadorFiltroProvider.notifier)
              .set(usuario.trabajadorId);
        }
      }
    });

    final usuarioActual = ref.watch(usuarioActualProvider).value;
    final esEstilista = usuarioActual?.rol == RolTrabajador.estilista;
    final trabajadorIdEstilista = usuarioActual?.trabajadorId;

    final fecha = ref.watch(fechaSeleccionadaProvider);
    final filtroRaw = ref.watch(trabajadorFiltroProvider);
    final filtro = esEstilista && (trabajadorIdEstilista?.isNotEmpty ?? false)
        ? trabajadorIdEstilista
        : filtroRaw;

    final lunesFecha = fmtFecha(lunesDeSemana(fecha));
    final turnosAsync = ref.watch(turnosPorSemanaProvider(lunesFecha));
    final config = ref.watch(configStreamProvider).value;
    final trabajadores =
        ref.watch(trabajadoresStreamProvider).value ?? const <Trabajador>[];

    void abrirDia(DateTime dia) {
      ref.read(fechaSeleccionadaProvider.notifier).set(dia);
      context.push('/agenda/dia');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          TextButton(
            onPressed: () => ref.read(fechaSeleccionadaProvider.notifier).hoy(),
            child: const Text('Hoy'),
          ),
        ],
      ),
      body: Column(
        children: [
          _BarraSemana(fecha: fecha),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Tocá un día para ver el detalle',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          if (!esEstilista)
            ChipsTrabajadores(trabajadores: trabajadores, filtro: filtro),
          const Divider(height: 1),
          Expanded(
            child: turnosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: $e', textAlign: TextAlign.center),
                ),
              ),
              data: (turnos) {
                final visibles = filtro == null
                    ? turnos
                    : turnos.where((t) => t.trabajadorId == filtro).toList();
                final dias = semanaDe(fecha);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 600) {
                      return _GrillaSemana(
                        dias: dias,
                        turnos: visibles,
                        config: config,
                        onTapDia: abrirDia,
                      );
                    }
                    return _ListaSemana(
                      dias: dias,
                      fecha: fecha,
                      turnos: visibles,
                      config: config,
                      onSelectDia: (d) =>
                          ref.read(fechaSeleccionadaProvider.notifier).set(d),
                      onAbrirDia: abrirDia,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraSemana extends ConsumerWidget {
  const _BarraSemana({required this.fecha});

  final DateTime fecha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void mover(int s) =>
        ref.read(fechaSeleccionadaProvider.notifier).moverSemana(s);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => mover(-1),
          ),
          Expanded(
            child: Text(
              fmtRangoSemana(fecha),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => mover(1),
          ),
        ],
      ),
    );
  }
}

/// Agrupa turnos por fecha ('yyyy-MM-dd').
Map<String, List<Turno>> _porFecha(List<Turno> turnos) {
  final m = <String, List<Turno>>{};
  for (final t in turnos) {
    m.putIfAbsent(t.fecha, () => []).add(t);
  }
  return m;
}

/// Grilla de 7 columnas (lunes→domingo). Cada día es una lista compacta de
/// chips (hora · cliente) ordenados por hora de inicio: sin posicionamiento
/// absoluto por hora, así nunca se solapan ni se cortan. El detalle con la
/// escala horaria real vive en la vista diaria (al tocar el día).
class _GrillaSemana extends StatelessWidget {
  const _GrillaSemana({
    required this.dias,
    required this.turnos,
    required this.config,
    required this.onTapDia,
  });

  final List<DateTime> dias;
  final List<Turno> turnos;
  final SalonConfig? config;
  final void Function(DateTime) onTapDia;

  @override
  Widget build(BuildContext context) {
    final porFecha = _porFecha(turnos);
    final diasLab = config?.diasLaborables;

    final columnas = <Widget>[];
    for (final d in dias) {
      final delDia = porFecha[fmtFecha(d)] ?? const <Turno>[];
      final esLaborable = diasLab == null || diasLab.contains(d.weekday);
      columnas.add(
        SizedBox(
          width: 140,
          child: _ColumnaDia(
            dia: d,
            turnos: delDia,
            esLaborable: esLaborable,
            onTap: () => onTapDia(d),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: columnas,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColumnaDia extends StatelessWidget {
  const _ColumnaDia({
    required this.dia,
    required this.turnos,
    required this.esLaborable,
    required this.onTap,
  });

  final DateTime dia;
  final List<Turno> turnos;
  final bool esLaborable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ordenados = [...turnos]
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: esLaborable
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.fromLTRB(5, 6, 5, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fmtDiaCorto(dia),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: esLaborable
                            ? null
                            : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    if (ordenados.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        '· ${ordenados.length}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (ordenados.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Sin turnos',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                )
              else
                for (final t in ordenados) _ChipTurno(t),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip compacto de un turno en la lista semanal: franja de color por estado +
/// hora + nombre del cliente (con elipsis). Una línea, sin solapamientos.
class _ChipTurno extends StatelessWidget {
  const _ChipTurno(this.turno);

  final Turno turno;

  @override
  Widget build(BuildContext context) {
    final color = estadoColor(turno.estado);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border(left: BorderSide(color: color, width: 3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text(
            turno.horaInicio,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              turno.clienteNombre,
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Vista móvil (< 600px): tira horizontal de los 7 días + detalle (chips) del
/// día seleccionado. Tocar un día en la tira lo selecciona sin navegar; tocar
/// el encabezado o un turno abre la vista diaria completa (`/agenda/dia`).
class _ListaSemana extends StatelessWidget {
  const _ListaSemana({
    required this.dias,
    required this.fecha,
    required this.turnos,
    required this.config,
    required this.onSelectDia,
    required this.onAbrirDia,
  });

  final List<DateTime> dias;
  final DateTime fecha;
  final List<Turno> turnos;
  final SalonConfig? config;
  final void Function(DateTime) onSelectDia;
  final void Function(DateTime) onAbrirDia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final porFecha = _porFecha(turnos);
    final diasLab = config?.diasLaborables;

    final delDia = [...(porFecha[fmtFecha(fecha)] ?? const <Turno>[])]
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tira de selección: los 7 días con su contador.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: [
              for (final d in dias)
                Expanded(
                  child: _ChipDia(
                    dia: d,
                    cantidad: (porFecha[fmtFecha(d)] ?? const <Turno>[]).length,
                    seleccionado: _mismoDia(d, fecha),
                    esLaborable: diasLab == null || diasLab.contains(d.weekday),
                    onTap: () => onSelectDia(d),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Encabezado del día seleccionado + botón claro a la vista diaria.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  fmtFechaLegible(fecha),
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (delDia.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '${delDia.length} ${delDia.length == 1 ? 'turno' : 'turnos'}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => onAbrirDia(fecha),
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Abrir día'),
              ),
            ],
          ),
        ),
        // Detalle del día seleccionado.
        Expanded(
          child: delDia.isEmpty
              ? const _SinTurnosDiaMini()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  children: [
                    for (final t in delDia)
                      _ChipTurnoMovil(turno: t, onTap: () => onAbrirDia(fecha)),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Celda de un día en la tira de selección móvil: inicial + número + contador.
class _ChipDia extends StatelessWidget {
  const _ChipDia({
    required this.dia,
    required this.cantidad,
    required this.seleccionado,
    required this.esLaborable,
    required this.onTap,
  });

  final DateTime dia;
  final int cantidad;
  final bool seleccionado;
  final bool esLaborable;
  final VoidCallback onTap;

  static const _iniciales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colorTexto = seleccionado
        ? scheme.onPrimaryContainer
        : (esLaborable
            ? scheme.onSurface
            : scheme.onSurfaceVariant.withValues(alpha: 0.6));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: seleccionado ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: seleccionado ? scheme.primary : scheme.outlineVariant,
                width: seleccionado ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Text(
                  _iniciales[dia.weekday - 1],
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: seleccionado
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dia.day}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: colorTexto, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  cantidad > 0 ? '$cantidad' : '·',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: seleccionado
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant
                            .withValues(alpha: cantidad > 0 ? 1 : 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de un turno en el detalle móvil: hora + cliente + servicios + estado.
/// Más grande y táctil que el `_ChipTurno` de la grilla; abre la vista diaria.
class _ChipTurnoMovil extends StatelessWidget {
  const _ChipTurnoMovil({required this.turno, required this.onTap});

  final Turno turno;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = estadoColor(turno.estado);
    final servicios = turno.servicios.map((s) => s.nombre).join(' + ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 4)),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Text(
                  turno.horaInicio,
                  style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        turno.clienteNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (servicios.isNotEmpty)
                        Text(
                          servicios,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SinTurnosDiaMini extends StatelessWidget {
  const _SinTurnosDiaMini();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined,
                size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              'Sin turnos este día',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
