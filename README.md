# turnos_salon

App de **gestión de turnos para un salón de peluquería/estética**, construida con Flutter + Firebase. Pensada para uso diario desde el móvil (vertical), con persistencia offline para sobrevivir al wifi flojo del salón.

## ¿Qué problema resuelve?

Los salones suelen llevar la agenda en papel o en un grupo de WhatsApp: turnos que se pisan, no se sabe quién atiende qué, ni cuánto se cobró en el día, y cada estilista no tiene visibilidad clara de su propia jornada. `turnos_salon` centraliza todo eso:

- **Agenda compartida** en tiempo real entre dueño, estilistas y recepción.
- **Control por rol**: cada quien ve y hace solo lo que le corresponde.
- **Visión del negocio**: totales por estado, ingresos cobrados y % de ocupación del día.
- **Funciona sin conexión estable**: la persistencia offline de Firestore guarda los cambios y sincroniza cuando vuelve la red.

### Roles

| Rol         | Qué puede hacer                                                        |
|-------------|-----------------------------------------------------------------------|
| **Dueño**   | Todo: agenda, clientes, servicios, trabajadores y alta de usuarios.   |
| **Estilista** | Su propia agenda (prefiltrada), clientes y turnos.                  |
| **Recepción** | Gestión de agenda y clientes para todo el salón.                    |

## Funcionalidades principales

- **Agenda semanal** (lunes→domingo) como pantalla de inicio, responsive (grilla de 7 columnas en pantallas anchas, lista compacta en móvil).
- **Agenda diaria** enriquecida: encabezado con totales por estado, ingresos y ocupación; toggle **por horario** / **por trabajador**; huecos libres al filtrar por estilista.
- **Clientes**: alta, detalle e historial.
- **Servicios** y **trabajadores**: catálogo gestionado por el dueño.
- **Turnos**: creación y cambio de estado.
- **Autenticación** por email/contraseña con guards de navegación por rol.
- **Tema claro/oscuro** (sigue el sistema, seed violeta `#534AB7`).

## Stack

- **Flutter** (Dart SDK `^3.11.3`)
- **Riverpod** (`flutter_riverpod`) — estado
- **go_router** — navegación (`StatefulShellRoute` con NavigationBar inferior)
- **Firebase**: `firebase_core`, `cloud_firestore`, `firebase_auth`

## Estructura del proyecto

```
lib/
├── app/                 # App raíz, tema y tokens de diseño
├── core/                # Utilidades transversales
│   └── firebase/        # Flags y wiring del emulador
├── dev/                 # seed.dart — datos demo para el emulador
└── features/            # Feature-first (cada una: domain / data / application / presentation)
    ├── agenda/          # Vistas semanal y diaria
    ├── auth/            # Login y sesión por rol
    ├── clientes/
    ├── config/
    ├── servicios/
    ├── shell/           # NavigationBar / layout principal
    ├── trabajadores/
    └── turnos/
test/                    # Tests de Flutter
test_rules/              # Tests de las reglas de Firestore (@firebase/rules-unit-testing)
docs/                    # desarrollo-local.md (guía detallada)
plans/                   # Planes de diseño/implementación
```

## Requisitos

- **Flutter SDK** (con Dart `^3.11.3`).
- **Firebase CLI** (`firebase --version`).
- **JDK 21 o superior** en el PATH — lo necesita el emulador de Firestore.
  En Windows: `winget install Microsoft.OpenJDK.21` (reabrí la terminal después de instalar).

Instalá dependencias una vez:

```bash
flutter pub get
```

## Cómo levantar el proyecto

Hay **dos modos** de ejecución, según contra qué backend quieras correr.

### Modo 1 — Emulador local (datos demo) · recomendado para desarrollo

Habla con el Firebase Emulator Suite local en vez de la nube: rápido, gratis y sin tocar datos reales. Al arrancar, siembra automáticamente datos y cuentas demo (seed **idempotente**, no duplica).

Necesitás **dos terminales**:

```bash
# Terminal 1 — emulador con reglas PERMISIVAS (Auth :9099, Firestore :8080, UI :4000)
firebase emulators:start --config firebase.emulator.json --only auth,firestore

# Terminal 2 — app apuntando al emulador (dispara el seed)
flutter run -d chrome --dart-define=USE_EMULATOR=true
```

> **En emulador Android** el host es `10.0.2.2` y hay que habilitar cleartext HTTP
> (ya resuelto en debug). Ver la sección "Correr en el emulador Android" en
> [`docs/desarrollo-local.md`](docs/desarrollo-local.md).

**¿Por qué `firebase.emulator.json`?** El seed corre en `main()` antes de cualquier login y necesita leer/escribir libre. Las reglas estrictas de producción bloquean ese bootstrap (chicken-and-egg con `usuarios/{dueño}`), por eso el emulador usa `firestore.rules.emulator` (**permisivas, solo local, nunca se despliegan**). Detalle completo en [`docs/desarrollo-local.md`](docs/desarrollo-local.md).

#### Credenciales demo

Sembradas **solo** contra el emulador. Password común: **`salon123`**.

| Email              | Rol       |
|--------------------|-----------|
| `dueno@salon.test` | Dueño     |
| `ana@salon.test`   | Estilista |
| `marta@salon.test` | Estilista |
| `luis@salon.test`  | Recepción |

> Estas cuentas **no existen** en el Firebase real; sin el flag del emulador no sirven.

### Modo 2 — Firebase real (nube)

Apunta al proyecto real `turnos-salon-163b5`. Necesitás una cuenta que exista en ese proyecto (las demo no sirven).

```bash
flutter run -d chrome
```

### Pruebas manuales en navegador (build release)

Evitá `flutter run -d web-server` en debug: sin la *Dart Debug Chrome Extension* la página queda en blanco. Compilá release y servila estática:

```bash
flutter build web --dart-define=USE_EMULATOR=true
npx http-server build/web -p 5000 -c-1   # http://localhost:5000
```

## Verificación y tests

```bash
flutter analyze   # debe dar "No issues found!"
flutter test      # suite de Flutter
```

**Reglas de Firestore** (allow/deny por rol contra las reglas estrictas reales). Con el emulador corriendo:

```bash
cd test_rules
npm install        # primera vez
npm test           # tests por rol contra firestore.rules
```

## Deploy

El deploy a la nube usa `firebase.json` → `firestore.rules` (**estrictas**). El archivo `firebase.emulator.json` y `firestore.rules.emulator` son **solo para local** y nunca se despliegan.

---

Más detalle de desarrollo local en [`docs/desarrollo-local.md`](docs/desarrollo-local.md).
