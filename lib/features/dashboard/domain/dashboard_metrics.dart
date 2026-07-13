import '../../../core/util/horas.dart';
import '../../turnos/domain/turno.dart';

/// Métricas agregadas del salón sobre una lista de [Turno] (típicamente ya
/// filtrada por rango de fechas / trabajador). Lógica pura y testeable: no
/// depende de Flutter ni de Riverpod.
class DashboardMetrics {
  const DashboardMetrics({
    required this.totalTurnos,
    required this.porServicioConteo,
    required this.porServicioIngreso,
    required this.porTrabajadorConteo,
    required this.porTrabajadorIngreso,
    required this.porDiaConteo,
    required this.porDiaIngreso,
    required this.porHoraConteo,
    required this.porHoraIngreso,
  });

  /// Cantidad total de turnos.
  final int totalTurnos;

  /// Conteo de líneas de servicio (demanda), todos los estados, desc.
  final List<(String nombre, int conteo)> porServicioConteo;

  /// Suma de `LineaCobro.monto` por servicio, solo turnos `completado`, desc.
  final List<(String nombre, num monto)> porServicioIngreso;

  /// Conteo de turnos por trabajador, todos los estados, desc.
  final List<(String nombre, int conteo)> porTrabajadorConteo;

  /// Suma de `cobro.total` por trabajador, solo `completado`, desc.
  final List<(String nombre, num monto)> porTrabajadorIngreso;

  /// Conteo de turnos por fecha, todos los estados, desc.
  final List<(String fecha, int conteo)> porDiaConteo;

  /// Suma de `cobro.total` por fecha, solo `completado`, desc.
  final List<(String fecha, num monto)> porDiaIngreso;

  /// Conteo de turnos por franja horaria (0-23), todos los estados, desc.
  final List<(int hora, int conteo)> porHoraConteo;

  /// Suma de `cobro.total` por franja horaria, solo `completado`, desc.
  final List<(int hora, num monto)> porHoraIngreso;

  factory DashboardMetrics.desde(List<Turno> turnos) {
    final servicioConteo = <String, int>{};
    final servicioNombre = <String, String>{};
    final servicioIngreso = <String, num>{};

    final trabajadorConteo = <String, int>{};
    final trabajadorNombre = <String, String>{};
    final trabajadorIngreso = <String, num>{};

    final diaConteo = <String, int>{};
    final diaIngreso = <String, num>{};

    final horaConteo = <int, int>{};
    final horaIngreso = <int, num>{};

    for (final t in turnos) {
      // Servicios: conteo de líneas sobre todos los estados.
      for (final s in t.servicios) {
        servicioConteo[s.servicioId] = (servicioConteo[s.servicioId] ?? 0) + 1;
        servicioNombre.putIfAbsent(s.servicioId, () => s.nombre);
      }

      // Trabajador: conteo de turnos sobre todos los estados.
      trabajadorConteo[t.trabajadorId] =
          (trabajadorConteo[t.trabajadorId] ?? 0) + 1;
      trabajadorNombre.putIfAbsent(t.trabajadorId, () => t.trabajadorNombre);

      // Día: conteo de turnos sobre todos los estados.
      diaConteo[t.fecha] = (diaConteo[t.fecha] ?? 0) + 1;

      // Hora: conteo de turnos sobre todos los estados.
      final hora = minutosDeHora(t.horaInicio) ~/ 60;
      horaConteo[hora] = (horaConteo[hora] ?? 0) + 1;

      // Ingresos: solo turnos completado con cobro.
      if (t.estado == EstadoTurno.completado && t.cobro != null) {
        for (final l in t.cobro!.lineas) {
          servicioIngreso[l.servicioId] =
              (servicioIngreso[l.servicioId] ?? 0) + l.monto;
          servicioNombre.putIfAbsent(l.servicioId, () => l.nombre);
        }
        trabajadorIngreso[t.trabajadorId] =
            (trabajadorIngreso[t.trabajadorId] ?? 0) + t.cobro!.total;
        diaIngreso[t.fecha] = (diaIngreso[t.fecha] ?? 0) + t.cobro!.total;
        horaIngreso[hora] = (horaIngreso[hora] ?? 0) + t.cobro!.total;
      }
    }

    List<(String, int)> countList(Map<String, int> conteo, Map<String, String> nombres) {
      final list = conteo.entries
          .map((e) => (nombres[e.key] ?? '', e.value))
          .toList();
      list.sort((a, b) => b.$2.compareTo(a.$2));
      return list;
    }

    List<(String, num)> montoList(Map<String, num> monto, Map<String, String> nombres) {
      final list = monto.entries
          .map((e) => (nombres[e.key] ?? '', e.value))
          .toList();
      list.sort((a, b) => b.$2.compareTo(a.$2));
      return list;
    }

    final porDiaConteoList = diaConteo.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final porDiaIngresoList = diaIngreso.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final porHoraConteoList = horaConteo.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final porHoraIngresoList = horaIngreso.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    return DashboardMetrics(
      totalTurnos: turnos.length,
      porServicioConteo: countList(servicioConteo, servicioNombre),
      porServicioIngreso: montoList(servicioIngreso, servicioNombre),
      porTrabajadorConteo: countList(trabajadorConteo, trabajadorNombre),
      porTrabajadorIngreso: montoList(trabajadorIngreso, trabajadorNombre),
      porDiaConteo: porDiaConteoList,
      porDiaIngreso: porDiaIngresoList,
      porHoraConteo: porHoraConteoList,
      porHoraIngreso: porHoraIngresoList,
    );
  }
}
