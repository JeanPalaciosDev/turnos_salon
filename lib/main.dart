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
