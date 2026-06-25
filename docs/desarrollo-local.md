# Desarrollo local — turnos_salon

Notas para correr la app en local y probar con datos demo.

## Credenciales demo

Cuentas sembradas automáticamente **solo cuando la app corre contra el emulador**
(ver [`lib/dev/seed.dart`](../lib/dev/seed.dart)). Password común: **`salon123`**.

| Email               | Rol        | trabajador_id |
|---------------------|------------|---------------|
| `dueno@salon.test`  | Dueño      | `dueno`       |
| `ana@salon.test`    | Estilista  | `ana`         |
| `marta@salon.test`  | Estilista  | `marta`       |
| `luis@salon.test`   | Recepción  | `luis`        |

> Estas cuentas **NO existen** en el Firebase real (`turnos-salon-163b5`). Si lanzás
> la app sin el flag del emulador, apunta a la nube y el login demo no funciona.

## Correr contra el emulador (datos demo)

### Forma rápida (recomendada): `run-dev.ps1`

Con un emulador de Android ya abierto (o dispositivo conectado), desde la raíz:

```powershell
./run-dev.ps1                          # Android emulator (host 10.0.2.2)
./run-dev.ps1 -EmulatorHost 127.0.0.1  # web / Windows desktop / iOS
```

El script ([`run-dev.ps1`](../run-dev.ps1)) hace los tres pasos en el orden correcto:
1. Levanta el Emulator Suite con la config **permisiva** (`--config firebase.emulator.json
   --only auth,firestore`) — imprescindible para que el seed siembre (ver nota más abajo).
2. **Espera** a que Firestore (8080) acepte conexiones antes de lanzar la app (si no, el
   seed inicial falla con `ECONNREFUSED`).
3. Lanza `flutter run` con los `--dart-define` ya puestos.

Persiste el estado del emulador en `./emulator-data` y lo reimporta en la próxima corrida
(el seed es idempotente, así que no duplica nada).

> Requiere Firebase CLI y JDK 21+ en el PATH (ver requisitos abajo).

### Forma manual (dos terminales)

Requisitos:
- **JDK 21 o superior** instalado y en el PATH (lo necesita el emulador de Firestore).
  Si falta, `firebase emulators:start` falla con `spawn java ENOENT`; con JDK < 21
  firebase-tools (≥15.22) falla con *"no longer supports Java version before 21"*.
  Instalación en Windows: `winget install Microsoft.OpenJDK.21`.
  > Tras instalar, reabrí la terminal para que el PATH tome `java`.
- Firebase CLI (`firebase --version`).

Pasos (dos terminales):

```bash
# 1) Levantar el emulador con la config PERMISIVA (ver nota abajo)
#    Auth :9099, Firestore :8080, UI :4000
firebase emulators:start --config firebase.emulator.json --only auth,firestore

# 2) Lanzar la app apuntando al emulador → dispara el seed (datos + cuentas demo)
flutter run -d chrome --dart-define=USE_EMULATOR=true
```

El flag `USE_EMULATOR=true` activa `kUseEmulator` ([`lib/core/firebase/emulator.dart`](../lib/core/firebase/emulator.dart)),
que cablea Firestore/Auth al emulador y ejecuta `seedEmulatorIfEmpty` en `main.dart`.
El seed es **idempotente**: no duplica datos entre corridas.

### Por qué `--config firebase.emulator.json` (reglas permisivas en local)

El seed (`lib/dev/seed.dart`) corre en `main()` **antes de cualquier login** y
necesita leer/escribir libremente. Las reglas estrictas de `firestore.rules`
(las que van a la nube) **bloquean** ese bootstrap: la primera lectura de
`servicios` da `permission-denied` y los writes exigen `esDueno()`, pero el
primer doc `usuarios/{dueño}` todavía no existe (chicken-and-egg).

Por eso el emulador usa `firebase.emulator.json` → `firestore.rules.emulator`
(**permisivas, SOLO local, nunca se despliegan**). El deploy a la nube sigue
usando `firebase.json` → `firestore.rules` (estrictas). Los guards de UI por rol
(drawer, redirects, prefiltro del estilista, botones ocultos) son lógica Dart y
**sí** se ejercitan aunque las reglas locales sean permisivas.

### Validar las reglas ESTRICTAS por rol

La validación behavioral de `firestore.rules` (allow/deny por rol) se hace con el
harness de `test_rules/` (`@firebase/rules-unit-testing`), que carga las reglas
estrictas reales y asserta denegaciones. Con el emulador corriendo:

```bash
cd test_rules
npm install          # primera vez
npm test             # 16 tests por rol contra firestore.rules
```

### Pruebas manuales en navegador (build release)

Para hacer clic por la app evitá `flutter run -d web-server` en debug: sin la
*Dart Debug Chrome Extension* la página queda **en blanco** (espera el handshake
del debugger). En su lugar, compilá release y servilo estático:

```bash
flutter build web --dart-define=USE_EMULATOR=true
npx http-server build/web -p 5000 -c-1   # abrir http://localhost:5000
```

> ⚠️ **Pendiente (2026-06-22):** con este build release servido estático, el login
> renderiza pero las credenciales demo **no entran**. El SDK cliente (Node) sí
> loguea contra el emulador, así que las cuentas y el emulador están bien — falta
> confirmar que el build esté pegándole al emulador (que `USE_EMULATOR` propague
> en release) y no a la nube. Revisar Network en la consola del navegador.

## Correr en el emulador Android (datos demo)

Igual que en web, pero con **dos diferencias clave** propias de Android.

### 1) Host del emulador: `10.0.2.2`

Dentro del emulador Android, `localhost`/`127.0.0.1` apunta **al propio teléfono
virtual**, no a tu PC. El host de la máquina anfitriona es **`10.0.2.2`**, así que
hay que pasarlo explícito (ver [`lib/core/firebase/emulator.dart`](../lib/core/firebase/emulator.dart)):

```bash
flutter run -d emulator-5554 \
  --dart-define=USE_EMULATOR=true \
  --dart-define=EMULATOR_HOST=10.0.2.2
```

> Sin `EMULATOR_HOST=10.0.2.2` la app falla con `ECONNREFUSED` al puerto 8080:
> está pegándole al propio emulador en vez de a tu PC.

### 2) Cleartext HTTP habilitado solo en debug

El Emulator Suite (Auth/Firestore) habla por **HTTP plano**, y Android (API 28+)
**bloquea cleartext por defecto** → el seed falla con
`Cleartext HTTP traffic to 10.0.2.2 not permitted` y las cuentas Auth no se crean.

Esto ya está resuelto **solo para el build de debug** mediante:
- [`android/app/src/debug/res/xml/network_security_config.xml`](../android/app/src/debug/res/xml/network_security_config.xml) — permite cleartext a `10.0.2.2`/`localhost`.
- [`android/app/src/debug/AndroidManifest.xml`](../android/app/src/debug/AndroidManifest.xml) — lo referencia con `networkSecurityConfig`.

El build de **release** no se ve afectado (cleartext sigue bloqueado en producción).

> Si editás el manifest o ese XML, hacé **rebuild completo** (stop + run), no hot
> restart: los cambios de manifest/recursos no entran con `R`.

### Orden de arranque (importante)

1. **Primero** el emulador de Firebase (terminal aparte) → esperar "All emulators ready":
   ```bash
   firebase emulators:start --config firebase.emulator.json --only auth,firestore
   ```
2. **Después** la app con los dos `--dart-define` de arriba.

El seed corre en `main()` al arrancar; si lanzás la app antes que el emulador, las
cuentas Auth no se siembran. Las cuentas Auth se reintentan en cada arranque
(idempotentes vía `email-already-in-use`), así que basta con relanzar la app una
vez que el emulador esté arriba.

## Correr contra Firebase real (nube)

```bash
flutter run -d chrome
```

Sin el flag, la app usa el proyecto real `turnos-salon-163b5`. Necesitás una cuenta
que exista en ese proyecto (las demo no sirven).

## Verificación

```bash
flutter analyze   # debe dar "No issues found!"
flutter test      # suite completa
```

## Navegación e interfaz (móvil vertical)

- **NavigationBar inferior** con 3 destinos primarios: **Agenda · Clientes · Más**
  (`StatefulShellRoute.indexedStack`, estado preservado por pestaña). "Más"
  (`/mas`) reemplaza al antiguo Drawer: Servicios/Trabajadores/Usuarios (solo
  dueño), Dashboard ("próximamente") y Cerrar sesión.
- Las pantallas de detalle (`/agenda/dia`, `/clientes/detalle`) y las de gestión
  del dueño se abren **full-screen sobre la barra** (root navigator).
- **Tema claro y oscuro** (seed violeta `#534AB7`), sigue el modo del sistema
  (`ThemeMode.system`). Component themes y tokens en [`lib/app/theme.dart`](../lib/app/theme.dart)
  y [`lib/app/tokens.dart`](../lib/app/tokens.dart).
- Plan de diseño/implementación: [`plans/diseno-ui-movil.md`](../plans/diseno-ui-movil.md).

## Vista de agenda (semanal + diaria)

- **`/agenda`** → vista **semanal** (lunes→domingo), pantalla de inicio.
  Responsive: grilla de 7 columnas en ancho ≥ 600px, lista compacta de 7 filas en < 600px.
  Tocar un día abre el detalle.
- **`/agenda/dia`** → vista **diaria** enriquecida: encabezado con totales
  (turnos por estado en chips de color, ingresos cobrados, % ocupación) +
  **toggle de vista** (solo en modo "Todos", no estilista):
  - **Por horario** (default): todos los turnos del día en orden cronológico,
    intercalando trabajadores, cada uno con su color e inicial.
  - **Por trabajador**: agrupados por trabajador (encabezados).
  Al filtrar por un trabajador (o como estilista): lista cronológica con
  huecos libres. Tiles con franja horaria + duración + teléfono.
- Plan original de la agenda: [`plans/vista-semanal-agenda.md`](../plans/vista-semanal-agenda.md).
