import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_salon/features/auth/domain/usuario.dart';
import 'package:turnos_salon/features/trabajadores/domain/trabajador.dart';

void main() {
  group('Usuario.fromMap / toMap', () {
    test('round-trip preserva rol y trabajador_id', () {
      final map = {
        'trabajador_id': 'trab_123',
        'rol': 'recepcion',
        'nombre': 'Marta',
        'email': 'marta@salon.test',
        'activo': true,
      };

      final usuario = Usuario.fromMap('uid1', map);
      final out = usuario.toMap();

      expect(usuario.uid, 'uid1');
      expect(usuario.rol, RolTrabajador.recepcion);
      expect(usuario.trabajadorId, 'trab_123');

      // Round-trip: el map de salida preserva rol y trabajador_id.
      expect(out['rol'], 'recepcion');
      expect(out['trabajador_id'], 'trab_123');
      expect(out['nombre'], 'Marta');
      expect(out['email'], 'marta@salon.test');
      expect(out['activo'], true);
    });

    test('rol desconocido cae en estilista', () {
      final usuario = Usuario.fromMap('uid2', {'rol': 'algo_raro'});
      expect(usuario.rol, RolTrabajador.estilista);
    });
  });
}
