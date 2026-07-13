import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_salon/features/dashboard/domain/dashboard_metrics.dart';
import 'package:turnos_salon/features/turnos/domain/turno.dart';

/// Helper: turno con fecha/hora/trabajador/servicios/estado/cobro configurables.
Turno _t({
  required String fecha,
  required String horaInicio,
  required String trabajadorId,
  required String trabajadorNombre,
  List<ServicioEnTurno> servicios = const [],
  EstadoTurno estado = EstadoTurno.pendiente,
  Cobro? cobro,
}) =>
    Turno(
      id: '$fecha-$horaInicio-$trabajadorId',
      fecha: fecha,
      horaInicio: horaInicio,
      finEstimado: horaInicio,
      trabajadorId: trabajadorId,
      trabajadorNombre: trabajadorNombre,
      clienteId: 'c1',
      clienteNombre: 'Cliente',
      servicios: servicios,
      estado: estado,
      creadoPor: 'staff',
      cobro: cobro,
    );

const corte = ServicioEnTurno(servicioId: 's1', nombre: 'Corte', duracionMin: 30);
const color = ServicioEnTurno(servicioId: 's2', nombre: 'Color', duracionMin: 60);

void main() {
  group('DashboardMetrics.desde', () {
    late List<Turno> turnos;

    setUp(() {
      turnos = [
        // Día 1 (2026-06-19), hora 9, Ana, completado, corte+color.
        _t(
          fecha: '2026-06-19',
          horaInicio: '09:00',
          trabajadorId: 'w1',
          trabajadorNombre: 'Ana',
          servicios: const [corte, color],
          estado: EstadoTurno.completado,
          cobro: const Cobro(
            lineas: [
              LineaCobro(servicioId: 's1', nombre: 'Corte', monto: 1000),
              LineaCobro(servicioId: 's2', nombre: 'Color', monto: 3000),
            ],
            total: 4000,
          ),
        ),
        // Día 1, hora 9, Ana, pendiente, solo corte (no suma ingreso).
        _t(
          fecha: '2026-06-19',
          horaInicio: '09:30',
          trabajadorId: 'w1',
          trabajadorNombre: 'Ana',
          servicios: const [corte],
          estado: EstadoTurno.pendiente,
        ),
        // Día 2 (2026-06-20), hora 14, Beto, completado, solo corte.
        _t(
          fecha: '2026-06-20',
          horaInicio: '14:00',
          trabajadorId: 'w2',
          trabajadorNombre: 'Beto',
          servicios: const [corte],
          estado: EstadoTurno.completado,
          cobro: const Cobro(
            lineas: [LineaCobro(servicioId: 's1', nombre: 'Corte', monto: 1200)],
            total: 1200,
          ),
        ),
        // Día 2, hora 14, Beto, cancelado (cuenta conteo, no ingreso).
        _t(
          fecha: '2026-06-20',
          horaInicio: '14:15',
          trabajadorId: 'w2',
          trabajadorNombre: 'Beto',
          servicios: const [color],
          estado: EstadoTurno.cancelado,
        ),
        // Día 2, hora 14, Beto, noShow (cuenta conteo, no ingreso, con cobro
        // presente igual no debería sumar porque no está completado).
        _t(
          fecha: '2026-06-20',
          horaInicio: '14:30',
          trabajadorId: 'w2',
          trabajadorNombre: 'Beto',
          servicios: const [corte],
          estado: EstadoTurno.noShow,
          cobro: const Cobro(
            lineas: [LineaCobro(servicioId: 's1', nombre: 'Corte', monto: 999)],
            total: 999,
          ),
        ),
      ];
    });

    test('totalTurnos cuenta todos los estados', () {
      final m = DashboardMetrics.desde(turnos);
      expect(m.totalTurnos, 5);
    });

    test('porServicioConteo cuenta líneas sobre todos los estados', () {
      final m = DashboardMetrics.desde(turnos);
      // corte: turnos 1,2,3,5 → 4 líneas. color: turnos 1,4 → 2 líneas.
      expect(m.porServicioConteo, [('Corte', 4), ('Color', 2)]);
    });

    test('porServicioIngreso suma solo líneas de completado', () {
      final m = DashboardMetrics.desde(turnos);
      // Corte: 1000 (t1) + 1200 (t3) = 2200. Color: 3000 (t1).
      expect(m.porServicioIngreso, [('Color', 3000), ('Corte', 2200)]);
    });

    test('porTrabajadorConteo cuenta turnos sobre todos los estados', () {
      final m = DashboardMetrics.desde(turnos);
      // Ana: 2 turnos. Beto: 3 turnos.
      expect(m.porTrabajadorConteo, [('Beto', 3), ('Ana', 2)]);
    });

    test('porTrabajadorIngreso suma cobro.total solo de completado', () {
      final m = DashboardMetrics.desde(turnos);
      // Ana: 4000. Beto: 1200 (noShow con cobro no cuenta).
      expect(m.porTrabajadorIngreso, [('Ana', 4000), ('Beto', 1200)]);
    });

    test('porDiaConteo cuenta turnos por fecha, todos los estados', () {
      final m = DashboardMetrics.desde(turnos);
      // 2026-06-19: 2 turnos. 2026-06-20: 3 turnos.
      expect(m.porDiaConteo, [('2026-06-20', 3), ('2026-06-19', 2)]);
    });

    test('porDiaIngreso suma cobro.total por fecha, solo completado', () {
      final m = DashboardMetrics.desde(turnos);
      // 2026-06-19: 4000. 2026-06-20: 1200.
      expect(m.porDiaIngreso, [('2026-06-19', 4000), ('2026-06-20', 1200)]);
    });

    test('porHoraConteo agrupa por franja horaria, todos los estados', () {
      final m = DashboardMetrics.desde(turnos);
      // Hora 9: 2 turnos (09:00, 09:30). Hora 14: 3 turnos.
      expect(m.porHoraConteo, [(14, 3), (9, 2)]);
    });

    test('porHoraIngreso suma cobro.total por franja horaria, solo completado', () {
      final m = DashboardMetrics.desde(turnos);
      // Hora 9: 4000. Hora 14: 1200.
      expect(m.porHoraIngreso, [(9, 4000), (14, 1200)]);
    });
  });
}
