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
