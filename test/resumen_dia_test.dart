import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_salon/features/agenda/domain/resumen_dia.dart';
import 'package:turnos_salon/features/config/domain/salon_config.dart';
import 'package:turnos_salon/features/turnos/domain/turno.dart';

/// Helper: turno mínimo con estado, cobro y duración configurables.
Turno _t(
  String inicio,
  String fin, {
  EstadoTurno estado = EstadoTurno.pendiente,
  num? cobroTotal,
}) =>
    Turno(
      id: '$inicio-$fin',
      fecha: '2026-06-19',
      horaInicio: inicio,
      finEstimado: fin,
      trabajadorId: 'w1',
      trabajadorNombre: 'Ana',
      clienteId: 'c1',
      clienteNombre: 'Cliente',
      servicios: const [],
      estado: estado,
      creadoPor: 'staff',
      cobro: cobroTotal == null
          ? null
          : Cobro(lineas: const [], total: cobroTotal),
    );

SalonConfig _config({String apertura = '09:00', String cierre = '19:00'}) =>
    SalonConfig.fromMap({'hora_apertura': apertura, 'hora_cierre': cierre});

void main() {
  group('ResumenDia.desde', () {
    test('conteo por estado', () {
      final r = ResumenDia.desde([
        _t('09:00', '09:30', estado: EstadoTurno.pendiente),
        _t('10:00', '10:30', estado: EstadoTurno.pendiente),
        _t('11:00', '11:30', estado: EstadoTurno.noShow),
        _t('12:00', '12:30', estado: EstadoTurno.completado),
      ], null);
      expect(r.total, 4);
      expect(r.porEstado[EstadoTurno.pendiente], 2);
      expect(r.porEstado[EstadoTurno.noShow], 1);
      expect(r.porEstado[EstadoTurno.completado], 1);
      expect(r.porEstado.containsKey(EstadoTurno.cancelado), isFalse);
    });

    test('ingresosCobrados suma solo completados con cobro', () {
      final r = ResumenDia.desde([
        _t('09:00', '09:30', estado: EstadoTurno.completado, cobroTotal: 1000),
        _t('10:00', '10:30', estado: EstadoTurno.completado, cobroTotal: 500),
        // completado sin cobro → no suma
        _t('11:00', '11:30', estado: EstadoTurno.completado),
        // no vino con cobro → no suma (no está completado)
        _t('12:00', '12:30', estado: EstadoTurno.noShow, cobroTotal: 999),
      ], null);
      expect(r.ingresosCobrados, 1500);
    });

    test('ocupacionPct con config conocida', () {
      // Laborables 09:00–19:00 = 600 min. Ocupados 120 min → 20%.
      final r = ResumenDia.desde([
        _t('09:00', '10:00'),
        _t('11:00', '12:00'),
      ], _config());
      expect(r.ocupacionPct, 20);
    });

    test('ocupacionPct null cuando config es null', () {
      final r = ResumenDia.desde([_t('09:00', '10:00')], null);
      expect(r.ocupacionPct, isNull);
    });

    test('ocupacionPct se acota a 100', () {
      // Laborables 09:00–10:00 = 60 min, pero ocupados 120 → clamp a 100.
      final r = ResumenDia.desde([
        _t('09:00', '11:00'),
      ], _config(apertura: '09:00', cierre: '10:00'));
      expect(r.ocupacionPct, 100);
    });
  });
}
