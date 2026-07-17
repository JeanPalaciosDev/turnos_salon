import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tokens.dart';
import '../../../core/util/colores.dart';
import '../../../core/util/horas.dart';
import '../../../core/util/moneda.dart';
import '../../auth/application/auth_providers.dart';
import '../../config/data/config_repository.dart';
import '../../config/domain/salon_config.dart';
import '../../trabajadores/application/trabajadores_providers.dart';
import '../../trabajadores/domain/trabajador.dart';
import '../../turnos/application/turno_providers.dart';
import '../../turnos/domain/agrupar_solapamientos.dart';
import '../../turnos/domain/turno.dart';
import '../../turnos/presentation/estado_ui.dart';
import '../../turnos/presentation/turno_detalle_sheet.dart';
import '../../turnos/presentation/turno_form.dart';
import '../application/agenda_providers.dart';
import '../domain/huecos.dart';
import '../domain/resumen_dia.dart';
import 'chips_trabajadores.dart';

/// Vista diaria de la agenda: lista por trabajador del día seleccionado.
/// Se abre al tocar un día desde la vista semanal (`/agenda/dia`).
class AgendaDiaScreen extends ConsumerStatefulWidget {
  const AgendaDiaScreen({super.key});

  @override
  ConsumerState<AgendaDiaScreen> createState() => _AgendaDiaScreenState();
}

class _AgendaDiaScreenState extends ConsumerState<AgendaDiaScreen> {
  @override
  Widget build(BuildContext context) {
    // Prefiltro del estilista (Fase 2E): cuando el usuario actual es estilista,
    // forzamos el filtro de trabajador a SU trabajador_id una sola vez por
    // emisión del usuario (vía ref.listen, no en cada build → sin loops de
    // rebuild) y bloqueamos los chips de cambio de trabajador.
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
    // Filtro efectivo: para el estilista siempre su trabajador_id (aunque el
    // listener aún no haya disparado en el primer frame).
    final filtroRaw = ref.watch(trabajadorFiltroProvider);
    final filtro = esEstilista && (trabajadorIdEstilista?.isNotEmpty ?? false)
        ? trabajadorIdEstilista
        : filtroRaw;
    final turnosAsync = ref.watch(turnosPorFechaProvider(fmtFecha(fecha)));
    final trabajadores =
        ref.watch(trabajadoresStreamProvider).value ?? const <Trabajador>[];
    final vistaDia = ref.watch(vistaDiaProvider);
    // El toggle de vista solo tiene sentido en modo "Todos" (filtro == null) y
    // para no-estilistas: con un único trabajador la vista ya es cronológica.
    final mostrarToggle = filtro == null && !esEstilista;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver a la semana',
          onPressed: () => context.pop(),
        ),
        title: const Text('Agenda'),
        actions: [
          TextButton(
            onPressed: () => ref.read(fechaSeleccionadaProvider.notifier).hoy(),
            child: const Text('Hoy'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTurnoForm(context,
            fechaInicial: fecha, trabajadorInicial: filtro),
        icon: const Icon(Icons.add),
        label: const Text('Turno'),
      ),
      body: Column(
        children: [
          _BarraFecha(fecha: fecha),
          if (mostrarToggle) _ToggleVista(vista: vistaDia),
          // El estilista tiene su agenda prefiltrada y NO puede cambiar de
          // trabajador: ocultamos la fila de chips (Fase 2E).
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
                if (visibles.isEmpty) return const _SinTurnos();
                final config = ref.watch(configStreamProvider).value;
                return Column(
                  children: [
                    _ResumenDia(turnos: visibles, config: config),
                    Expanded(
                      child: _ListaAgenda(
                        turnos: visibles,
                        trabajadores: trabajadores,
                        mostrarEncabezados: filtro == null,
                        vista: vistaDia,
                        config: config,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraFecha extends ConsumerWidget {
  const _BarraFecha({required this.fecha});

  final DateTime fecha;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void mover(int dias) =>
        ref.read(fechaSeleccionadaProvider.notifier).mover(dias);

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
              fmtFechaLegible(fecha),
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

/// Toggle "Por horario" / "Por trabajador". Solo se muestra en modo "Todos"
/// (sin filtro de trabajador) y para no-estilistas.
class _ToggleVista extends ConsumerWidget {
  const _ToggleVista({required this.vista});

  final VistaDia vista;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<VistaDia>(
          segments: const [
            ButtonSegment(
              value: VistaDia.porHorario,
              label: Text('Por horario'),
              icon: Icon(Icons.schedule),
            ),
            ButtonSegment(
              value: VistaDia.porTrabajador,
              label: Text('Por trabajador'),
              icon: Icon(Icons.people_outline),
            ),
          ],
          selected: {vista},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              ref.read(vistaDiaProvider.notifier).set(s.first),
        ),
      ),
    );
  }
}

class _ListaAgenda extends StatelessWidget {
  const _ListaAgenda({
    required this.turnos,
    required this.trabajadores,
    required this.mostrarEncabezados,
    required this.vista,
    this.config,
  });

  final List<Turno> turnos;
  final List<Trabajador> trabajadores;
  final bool mostrarEncabezados;
  final VistaDia vista;
  final SalonConfig? config;

  @override
  Widget build(BuildContext context) {
    // Modo "Todos" + "Por horario": una sola lista cronológica intercalando
    // todos los trabajadores, sin encabezados ni agrupar solapamientos
    // (turnos de distintos trabajadores se solapan legítimamente).
    if (mostrarEncabezados && vista == VistaDia.porHorario) {
      final ordenados = [...turnos]
        ..sort((a, b) =>
            minutosDeHora(a.horaInicio).compareTo(minutosDeHora(b.horaInicio)));
      final porId = <String, Trabajador>{
        for (final tr in trabajadores) tr.id: tr,
      };
      return ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 96),
        children: [
          for (final t in ordenados)
            _TurnoTileCronologico(turno: t, trabajador: porId[t.trabajadorId]),
        ],
      );
    }

    final porTrabajador = <String, List<Turno>>{};
    for (final t in turnos) {
      porTrabajador.putIfAbsent(t.trabajadorId, () => []).add(t);
    }

    // Orden: por la lista de trabajadores; luego cualquier id restante.
    final orden = <String>[];
    for (final tr in trabajadores) {
      if (porTrabajador.containsKey(tr.id)) orden.add(tr.id);
    }
    for (final id in porTrabajador.keys) {
      if (!orden.contains(id)) orden.add(id);
    }

    // Huecos libres solo en vista de un trabajador (sin encabezados); con
    // varios trabajadores los huecos se solapan y confunden.
    final mostrarHuecos = !mostrarEncabezados && orden.length == 1;

    final children = <Widget>[];
    for (final id in orden) {
      final lista = porTrabajador[id]!;
      if (mostrarEncabezados) {
        children.add(_Encabezado(lista.first.trabajadorNombre));
      }
      final grupos = agruparSolapados(lista);
      // Huecos ordenados cronológicamente; se intercalan por hora de inicio.
      final huecos = mostrarHuecos
          ? calcularHuecos(lista, config)
          : const <Hueco>[];
      var hi = 0;
      for (final grupo in grupos) {
        final iniGrupo = minutosDeHora(grupo.first.horaInicio);
        // Emite todos los huecos que arrancan antes de este grupo.
        while (hi < huecos.length &&
            minutosDeHora(huecos[hi].desde) <= iniGrupo) {
          children.add(_HuecoTile(huecos[hi]));
          hi++;
        }
        children.add(grupo.length == 1
            ? _TurnoTile(grupo.first)
            : _GrupoSimultaneo(grupo));
      }
      // Huecos restantes (típicamente el final hasta el cierre).
      while (hi < huecos.length) {
        children.add(_HuecoTile(huecos[hi]));
        hi++;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: children,
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado(this.nombre);

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        nombre,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _GrupoSimultaneo extends StatelessWidget {
  const _GrupoSimultaneo(this.turnos);

  final List<Turno> turnos;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.3),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.alt_route, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${turnos.length} en simultáneo',
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            for (final t in turnos) _TurnoTile(t),
          ],
        ),
      ),
    );
  }
}

class _TurnoTile extends StatelessWidget {
  const _TurnoTile(this.turno);

  final Turno turno;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servicios = turno.servicios.map((s) => s.nombre).join(' + ');
    final dur =
        minutosDeHora(turno.finEstimado) - minutosDeHora(turno.horaInicio);
    final tieneTelefono =
        turno.clienteTelefono != null && turno.clienteTelefono!.isNotEmpty;
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return ListTile(
      isThreeLine: tieneTelefono,
      minVerticalPadding: Insets.sm,
      onTap: () async {
        final action = await showTurnoDetalle(context, turno);
        if (action == 'edit' && context.mounted) {
          showTurnoForm(context, turno: turno);
        }
      },
      leading: SizedBox(
        width: 48,
        child: Text(
          turno.horaInicio,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      title: Text(
        turno.clienteNombre,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${turno.horaInicio}–${turno.finEstimado}'
            '${dur > 0 ? '  ·  $dur min' : ''}',
            style: muted,
          ),
          Text('$servicios  ·  ${estadoLabel(turno.estado)}', style: muted),
          if (tieneTelefono)
            Row(
              children: [
                Icon(Icons.phone,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: Insets.xs),
                Text(turno.clienteTelefono!, style: muted),
              ],
            ),
        ],
      ),
      trailing: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: estadoColor(turno.estado),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Tile para la vista cronológica multi-trabajador ("Por horario"). Reusa el
/// layout de [_TurnoTile] (hora, cliente, servicios+estado, teléfono, punto de
/// estado en trailing) y agrega el distintivo del trabajador: franja de color
/// a la izquierda, avatar con inicial y nombre en el subtítulo. Si no se
/// resuelve el [Trabajador] por id, degrada a inicial '?' y gris.
class _TurnoTileCronologico extends StatelessWidget {
  const _TurnoTileCronologico({required this.turno, this.trabajador});

  final Turno turno;
  final Trabajador? trabajador;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servicios = turno.servicios.map((s) => s.nombre).join(' + ');
    final dur =
        minutosDeHora(turno.finEstimado) - minutosDeHora(turno.horaInicio);
    final tieneTelefono =
        turno.clienteTelefono != null && turno.clienteTelefono!.isNotEmpty;
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final nombreTrabajador =
        trabajador?.nombre ?? turno.trabajadorNombre;
    final colorTrabajador = colorFromHex(trabajador?.color);
    final inicial = nombreTrabajador.trim().isNotEmpty
        ? nombreTrabajador.trim()[0].toUpperCase()
        : '?';

    // Card con InkWell ceñido al tile (no a un ListTile que se estira): el
    // onTap solo dispara al tocar el turno, no el fondo. Borde izquierdo con el
    // color del trabajador como distintivo.
    return Padding(
      padding: const EdgeInsets.fromLTRB(Insets.md, 3, Insets.md, 3),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: () async {
            final action = await showTurnoDetalle(context, turno);
            if (action == 'edit' && context.mounted) {
              showTurnoForm(context, turno: turno);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(color: colorTrabajador, width: 4)),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    turno.horaInicio,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        turno.clienteNombre,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${turno.horaInicio}–${turno.finEstimado}'
                        '${dur > 0 ? '  ·  $dur min' : ''}',
                        style: muted,
                      ),
                      Text('$servicios  ·  ${estadoLabel(turno.estado)}',
                          style: muted),
                      const SizedBox(height: Insets.xs),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: colorTrabajador,
                            child: Text(
                              inicial,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(nombreTrabajador,
                                style: muted,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      if (tieneTelefono)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(Icons.phone,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: Insets.xs),
                              Text(turno.clienteTelefono!, style: muted),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: estadoColor(turno.estado),
                      shape: BoxShape.circle,
                    ),
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

/// Encabezado compacto con totales del día: cantidad de turnos, desglose por
/// estado, ingresos cobrados y ocupación. Lógica pura en [ResumenDia].
class _ResumenDia extends StatelessWidget {
  const _ResumenDia({required this.turnos, required this.config});

  final List<Turno> turnos;
  final SalonConfig? config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = ResumenDia.desde(turnos, config);

    return Card(
      margin: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, Insets.xs),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg, vertical: Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${r.total} ${r.total == 1 ? 'turno' : 'turnos'}',
                  style: theme.textTheme.titleSmall,
                ),
                if (r.ocupacionPct != null) ...[
                  const SizedBox(width: Insets.sm),
                  Text(
                    '·  ${r.ocupacionPct}% ocupado',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const Spacer(),
                Text(
                  fmtMoneda(r.ingresosCobrados),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: scheme.primary),
                ),
              ],
            ),
            if (r.porEstado.isNotEmpty) ...[
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.xs,
                children: [
                  for (final e in r.porEstado.entries)
                    _ChipEstado(estado: e.key, conteo: e.value),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip compacto: punto del color del estado + etiqueta + conteo. Sin colores
/// hardcodeados (usa [estadoColor] y el [ColorScheme]).
class _ChipEstado extends StatelessWidget {
  const _ChipEstado({required this.estado, required this.conteo});

  final EstadoTurno estado;
  final int conteo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = estadoColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm, vertical: Insets.xs),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Insets.xs + 2),
          Text(
            '${estadoLabel(estado)} $conteo',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Tile tenue para un tramo libre entre turnos.
class _HuecoTile extends StatelessWidget {
  const _HuecoTile(this.hueco);

  final Hueco hueco;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 44,
        child: Icon(Icons.schedule, size: 18, color: scheme.onSurfaceVariant),
      ),
      title: Text(
        'Libre ${hueco.desde}–${hueco.hasta}  ·  ${hueco.minutos} min',
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
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
            Icon(Icons.event_available_outlined,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Sin turnos para este día',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tocá "Turno" para agendar el primero.',
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
