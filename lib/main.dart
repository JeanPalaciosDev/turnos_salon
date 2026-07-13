import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/firebase/emulator.dart';
import 'dev/seed.dart';
import 'firebase_options.dart';

// Las flags de emulador (`kUseEmulator` / `kEmulatorHost`) viven ahora en
// `core/firebase/emulator.dart` para poder reutilizarlas en la instancia
// secundaria de Auth del alta de usuarios (Fase 2D).

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kUseEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator(kEmulatorHost, 8080);
    await FirebaseAuth.instance.useAuthEmulator(kEmulatorHost, 9099);
  }

  // Auto-recuperación de sesiones rancias. Firebase Auth persiste el refresh
  // token en el dispositivo entre arranques; si ese token quedó inválido (caso
  // típico: se cambió de emulador a producción —o al revés— y el token de un
  // backend no lo reconoce el otro → INVALID_REFRESH_TOKEN), Firestore queda en
  // UNAUTHENTICATED y la app no escribe nada, sin pista en la UI.
  //
  // Forzamos aquí un refresh del token: si falla por token inválido, cerramos
  // sesión para caer limpio al login en vez de dejar la app muerta. NO cerramos
  // ante fallos de red (`network-request-failed`): el salón tiene wifi flojo y
  // la persistencia offline debe seguir sirviendo con la sesión existente.
  await _descartarSesionRancia();

  // Persistencia offline (clave para el wifi flojo del salón). El emulador
  // mantiene su propio estado en memoria, así que la desactivamos ahí para
  // evitar caché local que confunda durante las pruebas.
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: !kUseEmulator,
  );

  if (kUseEmulator) {
    // El seed sólo funciona con reglas permisivas (firebase.emulator.json).
    // Si el emulador se arrancó con reglas estrictas, sembrar dará
    // permission-denied: lo atrapamos para no dejar la app en blanco (main
    // abortaría antes de runApp). Ver docs/desarrollo-local.md.
    try {
      await seedEmulatorIfEmpty(FirebaseFirestore.instance);
    } catch (e, st) {
      debugPrint('seedEmulatorIfEmpty falló (¿reglas estrictas en el '
          'emulador? usá --config firebase.emulator.json): $e');
      debugPrintStack(stackTrace: st);
    }
  }

  runApp(const ProviderScope(child: TurnosApp()));
}

/// Valida la sesión persistida al arrancar. Si el refresh token es inválido,
/// hace `signOut()` para que la app muestre el login en vez de quedar en
/// UNAUTHENTICATED. Tolera fallos de red (no cierra sesión offline).
Future<void> _descartarSesionRancia() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  try {
    // `true` = forzar refresh contra el backend (no usar el token cacheado).
    await user.getIdToken(true);
  } on FirebaseAuthException catch (e) {
    if (e.code == 'network-request-failed') {
      // Sin conexión: conservamos la sesión para no romper el modo offline.
      debugPrint('No se pudo validar la sesión (sin red): se conserva. $e');
      return;
    }
    debugPrint('Sesión rancia (${e.code}): cerrando sesión. $e');
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    // Cualquier otro fallo al refrescar (token revocado, usuario borrado…):
    // cerramos sesión para arrancar limpio.
    debugPrint('Sesión inválida: cerrando sesión. $e');
    await FirebaseAuth.instance.signOut();
  }
}
