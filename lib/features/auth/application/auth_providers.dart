import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trabajadores/domain/trabajador.dart';
import '../data/auth_repository.dart';
import '../data/usuarios_repository.dart';
import '../domain/usuario.dart';

/// Estado de autenticación de Firebase (User logueado o null).
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authState(),
);

/// Usuario actual resuelto: según el uid del [authStateProvider], observa
/// `usuarios/{uid}`; emite null si no hay sesión.
final usuarioActualProvider = StreamProvider<Usuario?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream<Usuario?>.value(null);
  }
  return ref.watch(usuariosRepositoryProvider).watchUsuario(user.uid);
});

/// Rol del usuario actual (sincrónico); null mientras carga o sin sesión.
final rolActualProvider = Provider<RolTrabajador?>(
  (ref) => ref.watch(usuarioActualProvider).value?.rol,
);

/// True si el usuario actual es dueño.
final esDuenoProvider = Provider<bool>(
  (ref) => ref.watch(rolActualProvider) == RolTrabajador.dueno,
);

/// True si el usuario actual puede gestionar turnos (dueño o recepción).
final puedeGestionarTurnosProvider = Provider<bool>((ref) {
  final rol = ref.watch(rolActualProvider);
  return rol == RolTrabajador.dueno || rol == RolTrabajador.recepcion;
});
