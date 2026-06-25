import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_salon/features/agenda/domain/huecos.dart';
import 'package:turnos_salon/features/config/domain/salon_config.dart';
import 'package:turnos_salon/features/turnos/domain/turno.dart';

Turno _t(String inicio, String fin) => Turno(
      id: '$inicio-$fin',
      fecha: '2026-06-19',
      horaInicio: inicio,
      finEstimado: fin,
      trabajadorId: 'w1',
      trabajadorNombre: 'Ana',
      clienteId: 'c1',
      clienteNombre: 'Cliente',
      servicios: const [],
      estado: EstadoTurno.pendiente,
      creadoPor: 'staff',
    );

SalonConfig _config({String apertura = '09:00', String cierre = '20:00'}) =>
    SalonConfig.fromMap({'hora_apertura': apertura, 'hora_cierre': cierre});

void main() {
  group('calcularHuecos', () {
    test('hueco entre dos turnos separados', () {
      // Día 09–20. Turnos 10:00–11:00 y 13:00–14:00.
      final h = calcularHuecos(
        [_t('10:00', '11:00'), _t('13:00', '14:00')],
        _config(),
      );
      // Inicial 09:00–10:00 (60), medio 11:00–13:00 (120), final 14:00–20:00 (360).
      expect(h.length, 3);
      final medio = h.firstWhere((g) => g.desde == '11:00');
      expect(medio.hasta, '13:00');
      expect(medio.minutos, 120);
    });

    test('sin hueco cuando los turnos están pegados', () {
      // Apertura/cierre justo ajustados para que no haya inicial/final.
      final h = calcularHuecos(
        [_t('09:00', '10:00'), _t('10:00', '11:00')],
        _config(apertura: '09:00', cierre: '11:00'),
      );
      expect(h, isEmpty);
    });

    test('hueco inicial (apertura→primer turno)', () {
      final h = calcularHuecos(
        [_t('10:00', '20:00')],
        _config(),
      );
      expect(h.length, 1);
      expect(h.first.desde, '09:00');
      expect(h.first.hasta, '10:00');
      expect(h.first.minutos, 60);
    });

    test('hueco final (último turno→cierre)', () {
      final h = calcularHuecos(
        [_t('09:00', '18:00')],
        _config(),
      );
      expect(h.length, 1);
      expect(h.first.desde, '18:00');
      expect(h.first.hasta, '20:00');
      expect(h.first.minutos, 120);
    });

    test('respeta el clamp de apertura/cierre', () {
      // Turno que excede el horario: 08:00–21:00 → no hay huecos dentro de 09–20.
      final h = calcularHuecos(
        [_t('08:00', '21:00')],
        _config(),
      );
      expect(h, isEmpty);
    });

    test('huecos por debajo del minimo se descartan', () {
      // Hueco medio de solo 10 min < minimoMin (15) → se descarta.
      final h = calcularHuecos(
        [_t('09:00', '12:00'), _t('12:10', '20:00')],
        _config(),
      );
      expect(h, isEmpty);
    });

    test('sin turnos → un solo hueco de todo el día', () {
      final h = calcularHuecos(const [], _config());
      expect(h.length, 1);
      expect(h.first.desde, '09:00');
      expect(h.first.hasta, '20:00');
    });

    test('config null usa fallback 09:00-20:00', () {
      final h = calcularHuecos(const [], null);
      expect(h.length, 1);
      expect(h.first.desde, '09:00');
      expect(h.first.hasta, '20:00');
    });
  });
}
