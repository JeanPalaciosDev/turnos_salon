// Flags del Firebase Emulator Suite, reutilizables fuera de `main.dart`.
//
// Se extrajeron aquí (Fase 2D) para que el servicio de alta de cuentas
// (admin_user_service.dart) pueda cablear la instancia SECUNDARIA de
// FirebaseAuth al emulador igual que la principal.

/// Cuando es `true` (build con `--dart-define=USE_EMULATOR=true`) la app habla
/// con el Firebase Emulator Suite local en vez de la nube. Pruebas rápidas,
/// gratis y sin tocar datos reales.
const bool kUseEmulator = bool.fromEnvironment('USE_EMULATOR');

/// Host del emulador. Default `127.0.0.1` (IPv4) — NO `localhost`: en web el
/// navegador resuelve `localhost` a `::1` (IPv6) y el Emulator Suite bindea solo
/// IPv4, así que las requests de Auth/Firestore no llegan y el login "no entra"
/// (bug 2026-06-22). El SDK de Node resuelve `localhost`→IPv4, por eso ahí sí
/// funcionaba. En un emulador de Android la máquina anfitriona es `10.0.2.2`:
/// override con `--dart-define=EMULATOR_HOST=10.0.2.2`.
const String kEmulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);
