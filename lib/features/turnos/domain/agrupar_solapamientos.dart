import '../../../core/util/horas.dart';
import 'turno.dart';

/// Agrupa turnos (de un mismo trabajador) cuyas ventanas
/// [horaInicio, finEstimado) se solapan. Devuelve grupos ordenados por hora de
/// inicio; un grupo con más de un turno representa atención simultánea.
///
/// El `finEstimado` solo se usa para detectar el solapamiento visual: el
/// solapamiento está permitido, nunca se bloquea.
List<List<Turno>> agruparSolapados(List<Turno> turnos) {
  final sorted = [...turnos]
    ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
  final grupos = <List<Turno>>[];
  var maxFin = -1;
  for (final t in sorted) {
    final ini = minutosDeHora(t.horaInicio);
    final fin = minutosDeHora(t.finEstimado);
    if (grupos.isEmpty || ini >= maxFin) {
      grupos.add([t]);
      maxFin = fin;
    } else {
      grupos.last.add(t);
      if (fin > maxFin) maxFin = fin;
    }
  }
  return grupos;
}
