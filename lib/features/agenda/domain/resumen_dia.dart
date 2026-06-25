import '../../../core/util/horas.dart';
import '../../config/domain/salon_config.dart';
import '../../turnos/domain/turno.dart';

/// Resumen agregado de un día de agenda. Lógica pura y testeable: no depende de
/// Flutter ni de Riverpod. Calcula totales sobre una lista de [Turno] ya
/// filtrada (los turnos visibles del día).
class ResumenDia {
  const ResumenDia({
    required this.total,
    required this.porEstado,
    required this.ingresosCobrados,
    required this.ocupacionPct,
  });

  /// Cantidad total de turnos.
  final int total;

  /// Conteo por estado (solo estados presentes; los ausentes no aparecen).
  final Map<EstadoTurno, int> porEstado;

  /// Suma de `cobro.total` sobre los turnos `completado`.
  final num ingresosCobrados;

  /// Ocupación 0..100 (minutos ocupados / minutos laborables). `null` cuando no
  /// hay config o los minutos laborables no son positivos.
  final int? ocupacionPct;

  factory ResumenDia.desde(List<Turno> turnos, SalonConfig? config) {
    final porEstado = <EstadoTurno, int>{};
    var ingresos = 0 as num;
    var minutosOcupados = 0;

    for (final t in turnos) {
      porEstado[t.estado] = (porEstado[t.estado] ?? 0) + 1;
      if (t.estado == EstadoTurno.completado && t.cobro != null) {
        ingresos += t.cobro!.total;
      }
      final dur =
          minutosDeHora(t.finEstimado) - minutosDeHora(t.horaInicio);
      if (dur > 0) minutosOcupados += dur;
    }

    int? ocupacion;
    if (config != null) {
      final laborables =
          minutosDeHora(config.horaCierre) - minutosDeHora(config.horaApertura);
      if (laborables > 0) {
        final pct = (minutosOcupados * 100 / laborables).round();
        ocupacion = pct.clamp(0, 100);
      }
    }

    return ResumenDia(
      total: turnos.length,
      porEstado: porEstado,
      ingresosCobrados: ingresos,
      ocupacionPct: ocupacion,
    );
  }
}
