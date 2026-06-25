# Plan — Camino crítico: arreglar login → recorrido por roles → reglas estrictas en la nube

> Generado con `/claude-mem:make-plan`. Ejecutar con `/claude-mem:do` fase por fase.
> **Proyecto:** Turnos Salón (`D:\Work\turnos_salon`) · Flutter (web) + Firebase Emulator Suite
> **Fuente de verdad:** `D:\Work\Obsidian\Claude\Projects\turnos\turnos-salon.md`
> **Sesión previa:** `Dev Logs/2026-06-22 — turnos — emulador operativo, reglas validadas, bug login`

## Objetivo

Cerrar el **camino crítico de la Fase 2** que quedó bloqueado:

1. 🔴 **Arreglar el bug de login** (build release: el formulario renderiza pero las credenciales demo no entran).
2. 🟡 **Endurecer el seed de cuentas Auth** (hoy falla silenciosamente en web).
3. 🔴 **Completar el recorrido por roles** en el emulador (login, permisos, alta de staff sin deslogueo, agenda filtrada del estilista).
4. 🔴 **Validar y dejar listas las reglas estrictas para deploy** → matar el riesgo de caducidad **2026-09-30** (la nube sigue en modo test). El `firebase deploy` final lo corre Jean.

## Decisiones del usuario (Clarification Gate)

| Q | A |
|---|---|
| Alcance del plan | **Todo el camino crítico**: bug de login → recorrido por roles → reglas estrictas validadas y listas para deploy. |
| Quién corre el deploy a la nube | **Jean**, manualmente (acción fuera de la app). El plan deja todo validado + el comando exacto; no ejecuta el deploy. |

## Estado verificado del código (Fase 0 ya hecha en esta sesión)

El wiring se leyó y está **correcto en principio** — el bug NO es de lógica obvia, por eso Fase 1 es **diagnóstico antes que fix**:

- `kUseEmulator = bool.fromEnvironment('USE_EMULATOR')` ([emulator.dart:10](../lib/core/firebase/emulator.dart)) — funciona en release.
- `main()` cablea Auth+Firestore al emulador cuando `kUseEmulator` ([main.dart:23-26](../lib/main.dart)).
- `AuthRepository.signIn` mapea `FirebaseAuthException.code` a español; `invalid-credential` → "Correo o contraseña incorrectos" ([auth_repository.dart:33-47](../lib/features/auth/data/auth_repository.dart)).
- El router redirige a `/login` sin sesión y a `/agenda` al loguear ([router.dart:32-44](../lib/app/router.dart)).
- **🐛 Bug del seed encontrado:** el guard de idempotencia `servicios.limit(1)` hace `return` en [seed.dart:23](../lib/dev/seed.dart) **antes** de `_seedUsuariosAuth(db)` ([seed.dart:127](../lib/dev/seed.dart)). Si los datos ya están sembrados pero las cuentas Auth no (corrida parcial / reload), las cuentas **nunca se crean**. Esto explica el síntoma "el seed no escribió cuentas Auth" del dev log.

---

## Fase 0 — APIs / patrones permitidos (releer ANTES de codear)

La "documentación" de este repo es el código + `docs/desarrollo-local.md`. **Copiar estos patrones, no inventar.**

### Firebase emulador (web)
- Cableado: `FirebaseFirestore.instance.useFirestoreEmulator(host, 8080)` + `await FirebaseAuth.instance.useAuthEmulator(host, 9099)` ([main.dart:23-26](../lib/main.dart)).
- Flags: `--dart-define=USE_EMULATOR=true` y opcional `--dart-define=EMULATOR_HOST=127.0.0.1` ([emulator.dart](../lib/core/firebase/emulator.dart)).
- Arranque emulador (config PERMISIVA, solo local): `firebase emulators:start --config firebase.emulator.json --only auth,firestore`.
- Build + servir release: `flutter build web --dart-define=USE_EMULATOR=true` luego `npx http-server build/web -p 5000 -c-1` (`-c-1` = sin caché, crítico para no servir un build viejo).

### Auth (FlutterFire)
- `signInWithEmailAndPassword({required email, required password})`; errores vía `FirebaseAuthException.code` (`invalid-credential`, `network-request-failed`). Ver [auth_repository.dart](../lib/features/auth/data/auth_repository.dart).
- Seed Node de cuentas (SDK cliente, ya funciona): `cd test_rules && node seed_auth.mjs`. Smoke de login: `node test_login.mjs`.

### Reglas / deploy
- `firebase.json` → `firestore.rules` (estrictas, las que van a la nube) ([firebase.json:22-25](../firebase.json)).
- Validación behavioral: `cd test_rules && npm test` (16 tests, `@firebase/rules-unit-testing`).
- Deploy (acción de Jean): `firebase deploy --only firestore:rules`.

### Credenciales demo (solo emulador)
`dueno@ / ana@ / marta@ / luis@salon.test`, password `salon123` ([docs/desarrollo-local.md](../docs/desarrollo-local.md)).

### Anti-patrones a evitar
- ❌ Servir `build/web` sin `-c-1` (sirve un build cacheado viejo → falsos negativos).
- ❌ Tocar `firestore.rules.emulator` para "arreglar" cosas — es permisiva a propósito y **nunca se despliega**.
- ❌ Crear cuentas con `FirebaseAuth.instance` en el flujo admin (desloguea al dueño) — eso ya usa instancia secundaria en `admin_user_service.dart`.
- ❌ Desplegar reglas a la nube sin antes ver `npm test` en verde.

---

## Fase 1 — Diagnóstico del bug de login (decide el fix)

**Objetivo:** determinar **a dónde van las requests de Auth** del build release. El fix depende de esto; no codear a ciegas.

**Procedimiento:**
1. Levantar emulador permisivo: `firebase emulators:start --config firebase.emulator.json --only auth,firestore`.
2. Confirmar que las cuentas existen en ESTA instancia del emulador: `cd test_rules && node seed_auth.mjs` (idempotente) y `node test_login.mjs` → debe decir LOGIN OK.
3. Build limpio + servir sin caché:
   ```bash
   flutter build web --dart-define=USE_EMULATOR=true
   npx http-server build/web -p 5000 -c-1
   ```
4. Abrir `http://localhost:5000`, **DevTools → Network**, hacer hard-refresh (Ctrl+Shift+R), intentar login con `dueno@salon.test` / `salon123`.
5. **Observar la request de Auth** (`accounts:signInWithPassword`):
   - Destino **`localhost:9099`** → el build SÍ pega al emulador → **rama B**.
   - Destino **`identitytoolkit.googleapis.com`** → el build pega a la NUBE (cuentas demo no existen) → **rama A**.
6. Anotar también el **mensaje de error** que muestra la UI y el **status/payload** de la request en Network.

**Salida de esta fase:** una línea registrada — "Auth va a `<destino>`, error UI = `<texto>`, código = `<code>`" — que selecciona la rama de Fase 2.

**Anti-patrón guard:** no aplicar ningún fix en esta fase; solo medir.

---

## Fase 2 — Fix del login (según la rama de Fase 1)

### Rama A — el build pega a la nube (`USE_EMULATOR` no llegó al build)
Causa: build compilado/servido sin el flag, o build cacheado viejo.
1. Borrar el build viejo: `rm -rf build/web` (o `Remove-Item -Recurse -Force build/web`).
2. Rebuild explícito: `flutter build web --dart-define=USE_EMULATOR=true`.
3. Servir SIEMPRE con `-c-1` y hacer hard-refresh.
4. Re-verificar en Network que ahora Auth va a `localhost:9099`.
5. Si aún va a la nube, revisar que no haya un Service Worker viejo cacheando (`flutter_service_worker.js`): en DevTools → Application → Service Workers → Unregister, y recargar.

### Rama B — el build pega al emulador pero el login falla igual
Según el `code` observado en Fase 1:
- **`invalid-credential` / `user-not-found`:** las cuentas no están en la instancia viva del emulador (se reinició sin persistencia, o el seed no corrió). → re-sembrar con `node test_rules/seed_auth.mjs` y reintentar. Aplicar también **Fase 3** (fix del seed Flutter) para que no vuelva a pasar.
- **`network-request-failed`:** el navegador no alcanza `localhost:9099`. Probar `--dart-define=EMULATOR_HOST=127.0.0.1` en el build (algunos navegadores resuelven `localhost` distinto). Confirmar que el emulador escucha (UI en `:4000`).
- **Otro `code`:** registrar verbatim y mapearlo; ampliar `_mensajeError` solo si aparece un código no contemplado.

**Verificación (ambas ramas):**
- Login con `dueno@salon.test` / `salon123` en el build release → entra y el router redirige a `/agenda`.
- En Network, la request de Auth resuelve **200** contra `localhost:9099`.
- `flutter analyze` limpio si se tocó código.

**Anti-patrón guard:** no relajar `firestore.rules` ni `firestore.rules.emulator` para "que entre"; el login es Auth, no reglas de Firestore.

---

## Fase 3 — Endurecer el seed de cuentas Auth (fix de confiabilidad)

**Bug confirmado por lectura:** `_seedUsuariosAuth` queda detrás del early-return del guard de idempotencia de datos ([seed.dart:21-23](../lib/dev/seed.dart) → [seed.dart:127](../lib/dev/seed.dart)). Las cuentas Auth y los datos comparten un solo guard (`servicios`), pero tienen existencia independiente.

**Qué implementar** en [seed.dart](../lib/dev/seed.dart):
1. **Desacoplar** la siembra de cuentas del early-return. `_seedUsuariosAuth` ya es idempotente por sí mismo (atrapa `email-already-in-use`, [seed.dart:180-184](../lib/dev/seed.dart)), así que es seguro llamarlo SIEMPRE:
   ```dart
   Future<void> seedEmulatorIfEmpty(FirebaseFirestore db) async {
     final yaSembrado = await db.collection('servicios').limit(1).get();
     if (yaSembrado.docs.isEmpty) {
       // ... arma y commitea el batch de datos demo (sin cambios) ...
       await batch.commit();
     }
     // Las cuentas Auth se siembran SIEMPRE (idempotencia propia vía
     // email-already-in-use), independientes del guard de datos.
     await _seedUsuariosAuth(db);
   }
   ```
   (Mover el cuerpo actual de seteo+commit dentro del `if`; quitar el `return` temprano.)
2. **Logging defensivo** en `_seedUsuariosAuth`: envolver el loop en try/catch que haga `debugPrint` del email + error (sin abortar las demás cuentas) para que un fallo en web sea visible, no silencioso. Importar `package:flutter/foundation.dart` para `debugPrint`.
3. Mantener el `await auth.signOut()` final ([seed.dart:187](../lib/dev/seed.dart)) para no dejar sesión colgada.

**Verificación:**
- Emulador fresco (sin `--import`): lanzar la app con `USE_EMULATOR=true` → UI del emulador (`:4000`) muestra **4 cuentas Auth** + 4 docs `usuarios` + `trabajadores/dueno`.
- Segunda corrida (datos ya sembrados): `_seedUsuariosAuth` corre igual y NO duplica (sigue en 4 cuentas). Confirma que el desacople funciona.
- `flutter analyze` limpio.

**Anti-patrón guard:** no convertir `_seedUsuariosAuth` en no-idempotente; no quitar el `try/email-already-in-use`. No correr este seed contra la nube (sigue gateado por `kUseEmulator` en `main.dart`).

---

## Fase 4 — Recorrido por roles en el emulador

Con login funcionando, ejercitar la matriz de permisos (§7 del plan maestro) con los 4 usuarios demo.

**Procedimiento (build release contra emulador permisivo):**
1. **Dueño** (`dueno@salon.test`): ve Agenda + Clientes + Servicios + Trabajadores + Usuarios en el drawer. Crea un turno; cierra/cobra un turno; entra a `/usuarios`.
2. **Alta de staff sin deslogueo:** como dueño, en `/usuarios` crear una cuenta nueva (`admin_user_service.dart`, instancia secundaria) → **el dueño sigue logueado** tras el alta; la cuenta nueva aparece en la lista.
3. **Recepción** (`luis@salon.test`): ve Agenda + Clientes; puede crear/editar/cobrar turnos; NO ve Servicios/Trabajadores/Usuarios. Navegar por URL directa a `/servicios` → el guard redirige a `/agenda`.
4. **Estilista** (`ana@salon.test`): la agenda viene **prefiltrada a su `trabajador_id`** y sin chips de trabajador; sin botón "nuevo turno" ni "cerrar y cobrar"; puede cambiar el estado de SUS turnos.
5. Cerrar sesión desde el drawer → vuelve a `/login`.

**Verificación:**
- Checklist marcado para los 4 roles según la matriz (§7 / [plans/fase-2-auth.md](fase-2-auth.md) Matriz de permisos).
- El alta in-app no desloguea al dueño (criterio clave de la Fase 2D).
- Los guards de UI ocultan lo correcto y el guard de ruta redirige.

**Nota:** los guards de UI son lógica Dart y se ejercitan aunque el emulador use reglas permisivas. La **seguridad real** la dan las reglas estrictas, que se validan en Fase 5.

**Anti-patrón guard:** no confiar solo en que el widget está oculto; el recorrido es de UX/navegación, complementario a la validación de reglas (Fase 5).

---

## Fase 5 — Validar reglas estrictas y dejarlas listas para deploy

**Objetivo:** confirmar que `firestore.rules` (estrictas) son correctas y dejar el deploy a un comando. **No** ejecutar el deploy (lo corre Jean).

1. **Harness de reglas:** `cd test_rules && npm test` → **16/16 verde** contra `../firestore.rules`. Si algo falla, corregir `firestore.rules` (la fuente única de la nube), no la versión emulador.
2. **Leer `firestore.rules`** y confirmar coherencia con la matriz: `usuarios` con `write: if esDueno()` (no `if false`); catálogos `read: if activo()`; `turnos` create/update por `gestionTurnos()` o estilista dueño del turno.
3. **Sanity del deploy (dry, sin publicar):** `firebase deploy --only firestore:rules --dry-run` si está disponible, o al menos `firebase use` correcto (`turnos-salon-163b5`) y `firebase.json` apuntando a `firestore.rules`.
4. **Dejar el comando listo** para Jean:
   ```bash
   firebase deploy --only firestore:rules
   ```
   Documentar que esto **saca la nube del modo test** y **mata el riesgo de caducidad 2026-09-30**.

**Verificación:**
- `npm test` 16/16.
- `firestore.rules` revisada (sin `if false` sobre `usuarios`, sin `allow ... if true`).
- Instrucción de deploy registrada para Jean.

**Anti-patrón guard:** ❌ desplegar `firestore.rules.emulator`. ❌ deploy sin `npm test` verde. ❌ ejecutar el deploy automáticamente (es decisión/acción de Jean — acción saliente sobre producción).

---

## Fase 6 — Verificación final + cierre

1. **Análisis:** `flutter analyze` limpio; `flutter build web --dart-define=USE_EMULATOR=true` OK.
2. **Grep anti-patrones:**
   - `grep -n "if false" firestore.rules` → sin resultados sobre `usuarios`.
   - `grep -n "allow read, write: if true" firestore.rules` → sin resultados (eso solo en `firestore.rules.emulator`).
   - Confirmar que `_seedUsuariosAuth(db)` se llama fuera del early-return en `seed.dart`.
3. **Recorrido end-to-end** (build release contra emulador): login de los 4 roles, permisos, alta sin deslogueo, agenda filtrada del estilista, logout.
4. **`test_rules`:** `npm test` 16/16.
5. **Actualizar el vault (`/obsidian-log`):**
   - Nuevo dev log: bug de login resuelto (causa raíz + rama), seed endurecido, recorrido por roles completado, reglas listas para deploy.
   - Actualizar la nota del proyecto: marcar el bug de login como resuelto y, **una vez que Jean haga el deploy**, quitar el riesgo de caducidad 2026-09-30 (§9) y marcar Fase 2 completa (§11).

---

## Mapa de archivos

| Acción | Archivo |
|---|---|
| Diagnóstico (Network), sin cambios de código | DevTools del navegador |
| Fix login rama A (rebuild/caché/SW) | proceso de build, no código |
| Fix login rama B (host emulador) | `--dart-define=EMULATOR_HOST=127.0.0.1` (build), opcional |
| Desacoplar + logging del seed de cuentas | [lib/dev/seed.dart](../lib/dev/seed.dart) |
| (Solo si aparece code nuevo) ampliar mensajes | [lib/features/auth/data/auth_repository.dart](../lib/features/auth/data/auth_repository.dart) |
| Validar reglas estrictas | [firestore.rules](../firestore.rules), [test_rules/](../test_rules) |
| Deploy (acción de Jean) | `firebase deploy --only firestore:rules` |
| Cierre | dev log + nota del proyecto en el vault |

## Definition of Done (medible)

- [ ] El build release contra el emulador **loguea** con las 4 credenciales demo (request de Auth → `localhost:9099`, 200).
- [ ] El seed crea las 4 cuentas Auth de forma confiable e idempotente, aun con datos ya sembrados.
- [ ] Recorrido por roles OK: cada rol ve lo de la matriz; alta de staff sin deslogueo; agenda del estilista prefiltrada.
- [ ] `test_rules` 16/16; `firestore.rules` revisada y lista; comando de deploy entregado a Jean.
- [ ] `flutter analyze` limpio y `flutter build web` OK.
- [ ] Vault actualizado (dev log + nota del proyecto); riesgo 2026-09-30 listo para cerrarse tras el deploy de Jean.

## Analyze Gate (request ↔ plan)

| ID | Categoría | Severidad | Ubicación | Resumen | Recomendación |
|----|-----------|-----------|-----------|---------|---------------|
| A1 | Underspecification | MEDIUM | Fase 1/2 | Causa raíz del login no confirmada aún | Resuelto: Fase 1 diagnostica (Network) y selecciona rama A/B antes de codear |
| A2 | Coverage | LOW | Fase 5/6 | El deploy es acción externa de Jean | Resuelto: el plan valida y entrega el comando; no ejecuta el deploy |
| A3 | Inconsistency | LOW | Fases 2-6 | `firestore.rules` vs `firestore.rules.emulator` | Resuelto: guards explícitos — emulador permisivo nunca se despliega |

**Cobertura:** requisitos del usuario cubiertos 100% (fix login ✓, seed confiable ✓, recorrido por roles ✓, reglas validadas + deploy listo ✓). Findings CRITICAL/HIGH: 0.
</content>
</invoke>
