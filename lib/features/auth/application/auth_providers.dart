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

/// tenant_id del usuario actual (desde Custom Claims).
///
/// Observa [authStateProvider] y extrae el tenant_id de los claims del token ID.
/// Emite null si no hay sesión o si el usuario no tiene tenant_id asignado
/// (caso edge: super_admin sin tenant específico).
///
/// Nota: se usa Future + Stream.fromFuture para permitir que Firebase actualice
/// el token si es necesario (verifica claims de forma asíncrona).
final tenantIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream<String?>.value(null);
  }

  return Stream.fromFuture(
    user.getIdTokenResult(),
  ).map((idToken) {
    final claims = idToken.claims;
    if (claims == null) return null;
    return claims['tenant_id'] as String?;
  }).handleError((_) => null);
});

/// True si el usuario actual es super_admin (desde Custom Claims).
///
/// Verifica que el usuario tenga role == 'super_admin' en los Custom Claims.
/// Emite false si no hay sesión o si el rol no coincide, o mientras carga.
/// El .value está disponible para lecturas sincrónicas en el router.
final isSuperAdminProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream<bool>.value(false);
  }

  return Stream.fromFuture(
    user.getIdTokenResult(),
  ).map((idToken) {
    final claims = idToken.claims;
    if (claims == null) return false;
    return (claims['role'] as String?) == 'super_admin';
  }).handleError((_) => false);
});
