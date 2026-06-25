import '../../../core/util/horas.dart';
import '../../config/domain/salon_config.dart';
import '../../turnos/domain/agrupar_solapamientos.dart';
import '../../turnos/domain/turno.dart';

/// Un tramo libre entre turnos (o entre apertura/cierre y el primer/último
/// turno). Horas en 'HH:mm'; [minutos] es la duración del hueco.
class Hueco {
  const Hueco({
    required this.desde,
    required this.hasta,
    required this.minutos,
  });

  final String desde;
  final String hasta;
  final int minutos;
}

/// Calcula los tramos libres del día para un solo trabajador.
///
/// Agrupa solapados (reusa [agruparSolapados]) y toma, por grupo, la ventana
/// `[min(horaInicio), max(finEstimado)]`. Emite un [Hueco] por cada brecha
/// entre ventanas consecutivas, más un hueco inicial (apertura→primer turno) y
/// uno final (último turno→cierre). Todo acotado a `[apertura, cierre]`. Solo
/// se devuelven huecos de duración ≥ [minimoMin].
List<Hueco> calcularHuecos(
  List<Turno> turnos,
  SalonConfig? config, {
  int minimoMin = 15,
}) {
  final apertura = minutosDeHora(config?.horaApertura ?? '09:00');
  final cierre = minutosDeHora(config?.horaCierre ?? '20:00');
  if (cierre <= apertura) return const [];

  // Ventanas no solapadas, ordenadas por inicio (agruparSolapados ya ordena).
  final ventanas = <({int ini, int fin})>[];
  for (final grupo in agruparSolapados(turnos)) {
    var ini = minutosDeHora(grupo.first.horaInicio);
    var fin = ini;
    for (final t in grupo) {
      final i = minutosDeHora(t.horaInicio);
      final f = minutosDeHora(t.finEstimado);
      if (i < ini) ini = i;
      if (f > fin) fin = f;
    }
    ventanas.add((ini: ini, fin: fin));
  }

  final huecos = <Hueco>[];
  void emitir(int desde, int hasta) {
    final d = desde < apertura ? apertura : desde;
    final h = hasta > cierre ? cierre : hasta;
    final dur = h - d;
    if (dur >= minimoMin) {
      huecos.add(Hueco(desde: horaDeMinutos(d), hasta: horaDeMinutos(h), minutos: dur));
    }
  }

  if (ventanas.isEmpty) {
    emitir(apertura, cierre);
    return huecos;
  }

  // Hueco inicial.
  emitir(apertura, ventanas.first.ini);
  // Huecos entre ventanas consecutivas.
  for (var i = 0; i < ventanas.length - 1; i++) {
    emitir(ventanas[i].fin, ventanas[i + 1].ini);
  }
  // Hueco final.
  emitir(ventanas.last.fin, cierre);

  return huecos;
}
