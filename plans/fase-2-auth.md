# Plan — Fase 2: Auth, roles y guards

> **Proyecto:** Turnos Salón (`D:\Work\turnos_salon`) · Flutter + Firebase
> **Fuente de verdad del producto:** `D:\Work\Obsidian\Claude\Projects\turnos\turnos-salon.md`
> **Objetivo de la fase (§11 del plan maestro):** Firebase Auth + mapeo `usuarios → trabajador + rol` + guards por rol. Al cerrarla: salir del modo test desplegando reglas estrictas.
> **Ejecutar con:** `claude-mem:do` — fases consecutivas, cada una autocontenida.

---

## Assumptions (decididas en sesión 2026-06-20)

| Q | A |
|---|---|
| ¿Cómo se crean las cuentas de staff? | **Pantalla admin in-app**: el dueño da de alta staff (cuenta Auth + doc `usuarios/{uid}` + vínculo a trabajador) desde la app. |
| ¿Profundidad de control por rol? | **End-to-end**: guards de UI/navegación **y** reglas de Firestore granulares por rol. |
| ¿Agenda del estilista filtrada? | **Sí, en esta fase**: al loguear un estilista, la agenda se prefiltra a su `trabajador_id`. |

### Consecuencias de las decisiones
- Las reglas `firestore.rules.fase2` (planas, `signedIn()`) **se reemplazan por reglas granulares por rol** — ya no se copian tal cual.
- La regla existente `usuarios/{uid}` con `write: if false` **cambia**: el dueño debe poder escribir `usuarios`.
- Crear usuarios desde el cliente con `createUserWithEmailAndPassword` en la instancia principal **desloguearía al admin**. Se usa una **instancia secundaria de FirebaseApp** (patrón documentado).

---

## Modelo de datos (nuevo en esta fase)

```
usuarios/{uid}   { trabajador_id: string,        # vínculo a trabajadores/{id}
                   rol: "dueno"|"recepcion"|"estilista",
                   nombre: string,               # denormalizado para UI
                   email: string,                # denormalizado (referencia)
                   activo: bool,
                   created_at: timestamp }
```

- `rol` reutiliza el enum existente **`RolTrabajador`** (`dueno|recepcion|estilista`) de `lib/features/trabajadores/domain/trabajador.dart:1` — **no crear un enum nuevo**.
- `uid` = el UID de Firebase Auth (no autogenerado por Firestore).

## Glosario (terminología canónica — evitar sinónimos)
- **usuario** = doc `usuarios/{uid}` (cuenta + rol). **NO** confundir con **trabajador** (`trabajadores/{id}`, perfil de agenda).
- **sesión** = `Usuario` actual resuelto (auth user + su doc `usuarios`).
- **guard** = redirección de `go_router` por estado de auth/rol.
- Roles: `dueno` (admin), `recepcion`, `estilista` — exactamente estos strings en DB.

## Matriz de permisos (de §7 del plan maestro)

| Recurso / acción | dueno | recepcion | estilista |
|---|---|---|---|
| Agenda (ver) | todas | todas | **solo las suyas** |
| Crear/editar turno | ✅ | ✅ | ❌ |
| Cambiar estado de turno | cualquiera | cualquiera | **solo los suyos** |
| Cerrar/cobrar turno | ✅ | ✅ | ❌ |
| Clientes (CRUD) | ✅ | ✅ | ❌ (lectura) |
| Servicios (CRUD) | ✅ | ❌ | ❌ |
| Trabajadores (CRUD + horarios/ausencias) | ✅ | ❌ | ❌ |
| Usuarios/staff (alta, rol, activo) | ✅ | ❌ | ❌ |
| Dashboard (Fase 6) | ✅ | ❌ | ❌ |

> Lectura general (catálogos) permitida a todo staff logueado para que la agenda funcione.

---

## Fase 0 — Documentation Discovery (resultado consolidado)

**APIs permitidas (verificadas):**

- **firebase_auth ^6.5.3** (ya en `pubspec.yaml:41`, ya importado en `lib/main.dart:2`):
  - `FirebaseAuth.instance.authStateChanges()` → `Stream<User?>`
  - `signInWithEmailAndPassword({required String email, required String password})` → `Future<UserCredential>`
  - `createUserWithEmailAndPassword({...})` → `Future<UserCredential>`
  - `FirebaseAuth.instance.signOut()`
  - `FirebaseAuth.instance.currentUser` → `User?` (tiene `.uid`, `.email`)
  - Errores: `FirebaseAuthException` con `.code` (`invalid-credential`, `email-already-in-use`, `weak-password`, `network-request-failed`).
  - **Instancia secundaria** (crear usuario sin desloguear admin):
    `final app = await Firebase.initializeApp(name: 'admin_<rnd>', options: Firebase.app().options);`
    `final secAuth = FirebaseAuth.instanceFor(app: app);`
    crear con `secAuth.createUserWithEmailAndPassword(...)`, luego `await secAuth.signOut(); await app.delete();`
    Fuente: https://firebase.google.com/docs/auth/flutter/manage-users · https://www.w3tutorials.net/blog/flutter-firebase-authentication-create-user-without-logging-in/
  - **Emulador**: si `USE_EMULATOR`, hay que cablear la instancia secundaria al emulador igual que la principal (`useAuthEmulator`). Ver `lib/main.dart:30-33`.

- **go_router ^17.3.0** (ya en `pubspec.yaml:38`, configurado en `lib/app/router.dart`):
  - `GoRouter(refreshListenable: Listenable, redirect: (context, state) {...}, ...)`.
  - `redirect` devuelve `String?` (ruta a la que ir) o `null` (continuar). `state.matchedLocation` para la ruta actual.
  - `refreshListenable` requiere un `Listenable` (no acepta `AsyncValue`). Patrón: clase `GoRouterRefreshStream extends ChangeNotifier` que escucha un `Stream` y llama `notifyListeners()`.
    Fuente: https://pro.codewithandrea.com/flutter-foundations/05-riverpod-part2/22-go-router-refresh-listenable

- **flutter_riverpod ^3.3.2** (Riverpod 3 — ya migrado en el proyecto, ver nota "StateProvider→Notifier"):
  - `StreamProvider<User?>` para `authStateChanges()`.
  - Leer `.value` (no `.valueOrNull`) y `.isLoading` en `AsyncValue` (convención ya usada en el repo).
  - `Provider` para repos (patrón existente `firestoreProvider` en `lib/core/firebase/firestore.dart`).

**Anti-patrones a evitar:**
- ❌ Crear usuario con `FirebaseAuth.instance.createUserWithEmailAndPassword` (instancia principal) → desloguea al admin. Usar instancia secundaria.
- ❌ Pasar `AsyncValue` directo a `refreshListenable` (no es `Listenable`).
- ❌ `await` en escrituras Firestore de UI normal (rompe el patrón offline §9 del proyecto). **Excepción**: la creación de cuenta Auth SÍ se espera (requiere red), igual que la transacción de cobro.
- ❌ Inventar `RolUsuario`/`Role` — reusar `RolTrabajador`.
- ❌ Dejar `usuarios` con `write: if false` en las reglas (rompería el alta in-app del dueño).

---

## Fase 2A — Capa de dominio y datos de auth

**Implementar:**
1. `lib/features/auth/domain/usuario.dart` — modelo `Usuario` (`uid, trabajadorId, rol, nombre, email, activo`) con `fromMap(uid, map)` / `toMap()`, reusando `rolFromDb`/`rolToDb` de `trabajador.dart`. Copiar el estilo de `Trabajador.fromMap/toMap` (`lib/features/trabajadores/domain/trabajador.dart:65-83`).
2. `lib/core/firebase/auth.dart` — `firebaseAuthProvider` = `Provider<FirebaseAuth>((ref) => FirebaseAuth.instance)` (espejo de `firestoreProvider`).
3. `lib/features/auth/data/auth_repository.dart`:
   - `AuthRepository` con `Stream<User?> authState()`, `Future<void> signIn(email, password)`, `Future<void> signOut()`.
   - Mapear `FirebaseAuthException.code` a mensajes en español (`_mensajeError`).
   - `authRepositoryProvider`.
4. `lib/features/auth/data/usuarios_repository.dart`:
   - `Stream<Usuario?> watchUsuario(String uid)` (doc `usuarios/{uid}`).
   - `Future<void> crearUsuario(...)` y `Future<void> setActivo(uid, bool)` — **sin await en UI** salvo lo que exija la fase 2D.
   - `Stream<List<Usuario>> watchUsuarios()` (para la pantalla admin).
   - `usuariosRepositoryProvider`. Copiar patrón de `lib/features/trabajadores/data/trabajadores_repository.dart`.
5. **Providers de sesión** en `lib/features/auth/application/auth_providers.dart`:
   - `authStateProvider = StreamProvider<User?>` (de `authState()`).
   - `usuarioActualProvider = StreamProvider<Usuario?>` que, según `authStateProvider.value`, hace `watchUsuario(uid)` o emite `null`.
   - Helpers sincrónicos: `rolActualProvider` (`Provider<RolTrabajador?>`), y bools `esDuenoProvider`, `puedeGestionarTurnosProvider` (dueno||recepcion).

**Doc refs:** `trabajador.dart:1-17,65-83` (enum + map), `firestore.dart` (provider), `trabajadores_repository.dart` (streams).

**Verificación:**
- `flutter analyze` limpio.
- Test unitario `test/usuario_test.dart`: `Usuario.fromMap('uid1', {...}).toMap()` round-trip preserva `rol` y `trabajador_id`.

**Guards anti-patrón:** no enum nuevo; no `await` en `crearUsuario`/`setActivo` (la espera de Auth ocurre en 2D, no en el repo de Firestore).

---

## Fase 2B — Pantalla de Login + guard de navegación

**Implementar:**
1. `lib/features/auth/presentation/login_screen.dart` — `LoginScreen` (email + password + botón "Entrar"), estados loading/error, sin auto-registro. Llama `authRepository.signIn`. Material 3, estilo del repo.
2. Ruta `/login` en `lib/app/router.dart`.
3. `lib/app/go_router_refresh_stream.dart` — `GoRouterRefreshStream extends ChangeNotifier` que escucha un `Stream` y `notifyListeners()` (copiar de Code With Andrea, citado en Fase 0).
4. En `routerProvider` (`lib/app/router.dart:15`):
   - `refreshListenable: GoRouterRefreshStream(ref.watch(authRepositoryProvider).authState())`.
   - `redirect`: si no logueado y ruta ≠ `/login` → `/login`; si logueado y ruta == `/login` → `/agenda`. Mientras `usuarioActualProvider` carga, no redirigir (o mostrar splash).
   - `initialLocation` se mantiene `/agenda` (el redirect lo corrige).
5. Botón **Cerrar sesión** en el Drawer (la agenda ya tiene Drawer — buscar en `lib/features/agenda/presentation/agenda_screen.dart`). Llama `authRepository.signOut()`.

**Doc refs:** `router.dart:15-47` (estructura actual), búsqueda de doc en Fase 0 (refreshListenable).

**Verificación:**
- Manual (emulador): arrancar sin sesión → cae en `/login`; login OK → `/agenda`; cerrar sesión → vuelve a `/login`.
- `flutter analyze` limpio + `flutter build web` OK.

**Guards anti-patrón:** `refreshListenable` recibe el `ChangeNotifier`, no el `AsyncValue`; el redirect no debe loopear (excluir `/login` de la condición de redirección a login).

---

## Fase 2C — Guards por rol en la UI (navegación)

**Implementar:**
1. En el Drawer (agenda) y en cada pantalla, **ocultar/mostrar** secciones según `rolActualProvider`:
   - Servicios, Trabajadores, **Usuarios (nueva)**, Dashboard(futuro) → solo `dueno`.
   - Clientes (escritura), crear/editar/cerrar turno → `dueno`||`recepcion`.
   - Estilista → ve Agenda y Clientes (lectura); sin botón "nuevo turno", sin "cerrar y cobrar", sin acciones de edición salvo cambiar estado de los suyos.
2. **Guard de ruta** en `redirect` (router): si la ruta es admin-only (`/servicios`, `/trabajadores`, `/usuarios`) y el rol no es `dueno` → redirigir a `/agenda`. Definir un set `rutasSoloDueno` y `rutasGestionTurnos`.
3. Ocultar en `turno_detalle_sheet.dart` las acciones según permiso (crear/editar/cobrar vs cambiar estado). Ver `lib/features/turnos/presentation/turno_detalle_sheet.dart` y `turno_form.dart`.
4. Setear `creado_por` del turno con el `uid` actual en `turno_form.dart` (hoy el seed usa `'seed'`; el alta real debe usar `usuarioActual.uid`).

**Doc refs:** matriz de permisos (arriba), `agenda_screen.dart`, `turno_detalle_sheet.dart`, `turno_form.dart`.

**Verificación:**
- Manual con 3 usuarios seed (uno por rol): cada rol ve solo lo permitido; navegar por URL directa a `/servicios` como estilista redirige a `/agenda`.
- `flutter analyze` limpio.

**Guards anti-patrón:** la UI oculta, pero la **seguridad real la dan las reglas (2E)** — no confiar solo en ocultar widgets.

---

## Fase 2D — Pantalla admin: gestión de staff/usuarios

**Implementar:**
1. `lib/features/auth/presentation/usuarios_screen.dart` — lista de `usuarios` (vía `watchUsuarios`), con rol y estado activo; solo accesible para `dueno`. Ruta `/usuarios`.
2. `lib/features/auth/presentation/usuario_form.dart` — alta de staff:
   - Campos: email, password, nombre, rol (dropdown `RolTrabajador`), vínculo opcional a `trabajadores/{id}` (dropdown de trabajadores existentes).
   - **Alta de cuenta con instancia secundaria** (sin desloguear al admin), en `usuarios_repository.dart` o un servicio `admin_user_service.dart`:
     ```
     final app = await Firebase.initializeApp(name: 'admin_${DateTime.now().microsecondsSinceEpoch}', options: Firebase.app().options);
     final secAuth = FirebaseAuth.instanceFor(app: app);
     if (USE_EMULATOR) await secAuth.useAuthEmulator(host, 9099);
     final cred = await secAuth.createUserWithEmailAndPassword(email:..., password:...);
     await db.collection('usuarios').doc(cred.user!.uid).set(Usuario(...).toMap());
     await secAuth.signOut(); await app.delete();
     ```
     Esta operación **sí se espera con spinner** (excepción al patrón offline §9 — requiere red, como la transacción de cobro).
   - Manejar `email-already-in-use`, `weak-password`, `network-request-failed` con mensajes en español.
3. Toggle activo/inactivo (`setActivo`). Editar rol de un usuario existente (update del doc).
4. Exponer la constante `USE_EMULATOR`/`EMULATOR_HOST` de `main.dart` de forma reutilizable (moverlas a `lib/core/firebase/emulator.dart` o similar) para que el servicio secundario las use.

**Doc refs:** FlutterFire manage-users + w3tutorials (Fase 0), `lib/main.dart:14-21,30-33` (flags emulador), `trabajadores_repository.dart` (streams).

**Verificación:**
- Manual (emulador): logueado como dueño, crear un usuario `recepcion`; **el dueño sigue logueado** tras el alta; el nuevo usuario aparece en la lista y puede loguear en otra sesión.
- `flutter analyze` limpio.

**Guards anti-patrón:** ❌ usar la instancia principal para crear; ✅ instancia secundaria + `app.delete()`. No olvidar cablear el emulador a la instancia secundaria.

---

## Fase 2E — Reglas de Firestore granulares + agenda del estilista + seed

**Implementar:**
1. **Agenda del estilista** (`lib/features/agenda/...`): si `rolActual == estilista`, prefijar el filtro de trabajador a `usuarioActual.trabajadorId` y **bloquear** el cambio de chip. Revisar `trabajadorFiltroProvider` y `agenda_providers.dart` (`lib/features/agenda/application/agenda_providers.dart`).
2. **Reglas granulares** — reescribir `firestore.rules` (estricto, ya no modo test). Funciones helper que leen el rol del doc `usuarios/{uid}`:
   ```
   function usuario() { return get(/databases/$(database)/documents/usuarios/$(request.auth.uid)).data; }
   function signedIn() { return request.auth != null; }
   function activo() { return signedIn() && usuario().activo == true; }
   function rol() { return usuario().rol; }
   function esDueno() { return activo() && rol() == 'dueno'; }
   function gestionTurnos() { return activo() && (rol() == 'dueno' || rol() == 'recepcion'); }
   ```
   - `usuarios/{uid}`: `read: if activo()`; `write: if esDueno()` (cambia el `write:false` previo).
   - `config`, `servicios`, `trabajadores` (+`ausencias`): `read: if activo()`; `write: if esDueno()`.
   - `clientes`: `read: if activo()`; `write: if gestionTurnos()`.
   - `turnos`: `read: if activo()`; `create,update: if gestionTurnos() || (activo() && rol()=='estilista' && resource.data.trabajador_id == usuario().trabajador_id)`; `delete: if gestionTurnos()`.
   - Documentar que el filtrado fino por campo (estilista solo cambia `estado`) es simplificación MVP a refinar.
3. **Actualizar `firestore.rules.fase2`**: marcarlo obsoleto o reemplazar su contenido por estas reglas granulares (dejar una sola fuente de verdad). Borrar la nota "copiar tal cual".
4. **Seed del emulador** (`lib/dev/seed.dart`): crear cuentas Auth + docs `usuarios/{uid}` para los 3 trabajadores demo (ana=estilista, marta=estilista, luis=recepcion) **más un dueño** (`dueno@salon.test`). Usar `FirebaseAuth.instance` (emulador) para `createUserWithEmailAndPassword` y escribir `usuarios/{uid}` con el `trabajador_id` correspondiente. Mantener idempotencia.
5. **Deploy** (acción de Jean, fuera de la app): `firebase deploy --only firestore:rules` para salir del modo test. Requiere validar primero contra el emulador.

**Doc refs:** `firestore.rules.fase2:14-50` (estructura previa), `seed.dart:38-59` (trabajadores demo), reglas Firestore (`get()` para leer rol).

**Verificación:**
- Emulador: estilista NO puede escribir `servicios` (regla deniega); recepción puede crear turno; estilista puede cambiar estado de un turno suyo pero no de otro.
- Estilista ve la agenda prefiltrada a su `trabajador_id` y no puede cambiar el chip.
- `flutter analyze` limpio + `flutter build web` OK.
- Tras `firebase deploy`, la app en la nube exige login y respeta roles.

**Guards anti-patrón:** probar reglas en el emulador ANTES de `deploy`; no dejar `usuarios` con `write:false`; no romper lecturas de catálogo que la agenda necesita.

---

## Fase 2F — Verificación final

1. **Match con docs:** confirmar que toda llamada de auth usa firmas reales (grep) — sin métodos inventados.
2. **Anti-patrón grep:**
   - `Grep "createUserWithEmailAndPassword"` → debe aparecer **solo** sobre instancia secundaria / emulador-seed, nunca sobre `FirebaseAuth.instance` en flujo admin.
   - `Grep "refreshListenable"` → recibe `GoRouterRefreshStream`, no `AsyncValue`.
   - `Grep "if false"` en `firestore.rules` → no debe quedar sobre `usuarios`.
   - `Grep "'seed'"` en `turno_form.dart` → `creado_por` ya usa uid real.
3. **Pruebas:**
   - `flutter analyze` limpio en todo el repo.
   - `flutter test` pasa (incluye `usuario_test.dart`).
   - `flutter build web` OK.
   - Recorrido manual en emulador por los 3 roles (login, permisos, alta de usuario sin deslogueo, agenda filtrada de estilista).
4. **Cierre de fase (post-merge):** activar reglas estrictas en la nube (`firebase deploy --only firestore:rules`) y actualizar la nota del proyecto + dev log (marcar Fase 2 completa, quitar el riesgo de caducidad 2026-09-30).

---

## Definition of Done (acceptance criteria medibles)
- [ ] App sin sesión siempre cae en `/login`; no hay forma de ver la agenda sin loguear.
- [ ] Cada rol ve exactamente lo de la matriz de permisos (verificado con 3 usuarios seed + 1 dueño).
- [ ] El dueño crea staff in-app **sin perder su propia sesión**.
- [ ] El estilista ve solo sus turnos y solo cambia el estado de los suyos.
- [ ] Reglas estrictas desplegadas; la app en la nube deniega acceso no autorizado (probado en emulador con asserts de denegación).
- [ ] `flutter analyze` limpio, `flutter test` y `flutter build web` OK.
