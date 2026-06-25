import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_salon/core/util/horas.dart';

void main() {
  group('lunesDeSemana', () {
    test('un miércoles devuelve el lunes de esa semana', () {
      // 2026-06-17 es miércoles (weekday==3) → lunes 2026-06-15.
      expect(lunesDeSemana(DateTime(2026, 6, 17)), DateTime(2026, 6, 15));
    });

    test('un domingo (weekday==7) devuelve el lunes 6 días antes', () {
      // 2026-06-21 es domingo → mismo ISO week, lunes 2026-06-15.
      expect(lunesDeSemana(DateTime(2026, 6, 21)), DateTime(2026, 6, 15));
    });

    test('un lunes se devuelve a sí mismo', () {
      expect(lunesDeSemana(DateTime(2026, 6, 15)), DateTime(2026, 6, 15));
    });
  });

  group('semanaDe', () {
    test('devuelve 7 días consecutivos lunes→domingo', () {
      final dias = semanaDe(DateTime(2026, 6, 17));
      expect(dias.length, 7);
      expect(dias.first, DateTime(2026, 6, 15)); // lunes
      expect(dias.last, DateTime(2026, 6, 21)); // domingo
      expect(dias.first.weekday, DateTime.monday);
      expect(dias.last.weekday, DateTime.sunday);
      for (var i = 1; i < dias.length; i++) {
        expect(dias[i].difference(dias[i - 1]), const Duration(days: 1));
      }
    });
  });
}
