import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_salon/features/turnos/domain/agrupar_solapamientos.dart';
import 'package:turnos_salon/features/turnos/domain/turno.dart';

/// Helper: turno mínimo con solo lo que mira [agruparSolapados]
/// (`horaInicio` y `finEstimado`).
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

void main() {
  group('agruparSolapados', () {
    test('lista vacía → sin grupos', () {
      expect(agruparSolapados(const []), isEmpty);
    });

    test('turnos disjuntos → un grupo de uno cada uno', () {
      final grupos = agruparSolapados([
        _t('09:00', '10:00'),
        _t('10:00', '11:00'), // arranca justo al fin del anterior → NO solapa
        _t('11:30', '12:00'),
      ]);
      expect(grupos.length, 3);
      expect(grupos.every((g) => g.length == 1), isTrue);
    });

    test('ventanas que se cruzan → se agrupan como simultáneos', () {
      final grupos = agruparSolapados([
        _t('09:00', '10:30'),
        _t('09:30', '10:00'), // dentro de la ventana del primero
      ]);
      expect(grupos.length, 1);
      expect(grupos.first.length, 2);
    });

    test('encadenado: el grupo se extiende con el fin máximo', () {
      // A 09:00–10:00, B 09:30–11:00, C 10:30–11:30.
      // C solapa con B (no con A), pero el grupo arrastra maxFin → un solo grupo.
      final grupos = agruparSolapados([
        _t('09:00', '10:00'),
        _t('09:30', '11:00'),
        _t('10:30', '11:30'),
      ]);
      expect(grupos.length, 1);
      expect(grupos.first.length, 3);
    });

    test('ordena por hora de inicio aunque la entrada venga desordenada', () {
      final grupos = agruparSolapados([
        _t('12:00', '12:30'),
        _t('09:00', '09:30'),
        _t('10:00', '10:30'),
      ]);
      expect(grupos.map((g) => g.first.horaInicio).toList(),
          ['09:00', '10:00', '12:00']);
    });
  });
}
