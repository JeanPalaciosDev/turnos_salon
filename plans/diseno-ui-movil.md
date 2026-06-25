# Plan — Rediseño de interfaz, foco móvil vertical

> Generado en sesión de diseño (2026-06-24). Ejecutar fase por fase con `/claude-mem:do`.
> **Proyecto:** Turnos Salón (`D:\Work\turnos_salon`) · Flutter (web/móvil) + Material 3 + Riverpod 3 + go_router 17.
> **Fuente de verdad del producto:** `D:\Work\Obsidian\Claude\Projects\turnos\turnos-salon.md`
> **Estado previo:** las 3 fases funcionales (auth/roles, agenda semanal+diaria, reglas) están implementadas. Este plan es **solo capa visual/UX**, sin tocar lógica de datos ni reglas.

## Objetivo

Elevar la calidad visual de la app **priorizando el uso en teléfono en vertical**, sin cambiar el comportamiento funcional. Cinco frentes acordados con el usuario:

1. **Vista diaria por horario** (cronológica, todos los trabajadores intercalados) con **toggle** a la vista actual por trabajador.
2. **Sistema de tema base** (tipografía, theming de componentes, tokens) con **modo claro + oscuro**.
3. **NavigationBar inferior** (M3) para navegación primaria a una mano.
4. **Pulido de listas/tiles** (agenda + pantallas CRUD).
5. **Login con identidad de marca**.

## Decisiones del usuario (Clarification Gate)

| Q | A |
|---|---|
| Vista diaria | **Por horario como default** + toggle a "por trabajador". Evaluado: cronológico responde mejor "¿qué sigue?" en vertical; el toggle conserva la lectura por persona. |
| Modo oscuro | **Sí**, claro + oscuro, siguiendo el SO. |
| Áreas | Vista diaria + tema base + NavigationBar inferior + pulido de tiles + login con identidad. |
| Modo de trabajo | **Plan primero**, aprobar antes de codear. |

## Restricciones / supuestos

- **Sin dependencias nuevas de pub por defecto.** Solo Flutter Material + libs ya en [pubspec.yaml](../pubspec.yaml) (`flutter_riverpod ^3`, `cloud_firestore ^6`, `go_router ^17`, `firebase_*`). La tipografía se hace **afinando el type scale Roboto** (pesos/tamaños/tracking) — cero deps. *(Opcional, decisión futura: bundlear una familia como asset — sin paquete pub — para más identidad; no se asume en este plan.)*
- **Identidad violeta** ya establecida: seed `#534AB7` ([theme.dart](../lib/app/theme.dart), [colores.dart](../lib/core/util/colores.dart)). Se conserva.
- Todo color vía `ColorScheme`/`ThemeData` (regla Flutter de la skill ui-ux-pro-max). **Cero colores hardcodeados nuevos** en widgets; los estados de turno siguen en [estado_ui.dart](../lib/features/turnos/presentation/estado_ui.dart) (única excepción centralizada, ya existente).
- No romper: prefiltro del estilista, guards de rol, `ref.listen(usuarioActualProvider…)`, rutas de auth (`initialLocation: '/agenda'`, redirects).
- Touch targets ≥ 48px, texto de cuerpo ≥ 14–16px, contraste WCAG AA en ambos modos (checklist de la skill).

---

## Fase 0 — Patrones permitidos (leer ANTES de codear)

La "documentación" es el código existente. **Copiar estos patrones, no inventar.**

### Tema (hoy)
- [theme.dart](../lib/app/theme.dart): `buildTheme()` devuelve `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF534AB7)))`.
- Cableado en [app.dart](../lib/app/app.dart): `MaterialApp.router(theme: buildTheme(), routerConfig: router)`. **No** hay `darkTheme` ni `themeMode` todavía.

### Navegación (hoy)
- [router.dart](../lib/app/router.dart): `GoRouter` plano con `GoRoute` + `context.push`/`context.go`. `rutasSoloDueno` para guard de rol. Detalle/formularios apilan con `context.push` o `showXForm(context)` (modales).
- Drawer compartido: [app_drawer.dart](../lib/features/agenda/presentation/app_drawer.dart) (`AppDrawer`, `ChipsTrabajadores`). Items: Agenda (todos), Servicios/Trabajadores/Usuarios (solo dueño), Clientes (todos), Dashboard (deshabilitado), Cerrar sesión.

### Agenda diaria (hoy)
- [agenda_dia_screen.dart](../lib/features/agenda/presentation/agenda_dia_screen.dart): `_ListaAgenda` agrupa `porTrabajador`, emite `_Encabezado` por trabajador cuando `mostrarEncabezados` (= `filtro == null`); usa `agruparSolapados` y `calcularHuecos` (huecos solo si un trabajador). `_TurnoTile` = `ListTile` (hora, cliente, servicios, estado, teléfono). `_ResumenDia` = Card con totales.
- Estado: `fechaSeleccionadaProvider`, `trabajadorFiltroProvider` en [agenda_providers.dart](../lib/features/agenda/application/agenda_providers.dart).

### Colores de estado y de trabajador (reusar)
- [estado_ui.dart](../lib/features/turnos/presentation/estado_ui.dart): `estadoColor(EstadoTurno)`, `estadoLabel(EstadoTurno)`.
- [colores.dart](../lib/core/util/colores.dart): `trabajadorColores` (8 hex) + `colorFromHex(String?)`. `Trabajador.color` ya guarda un hex.

### Helpers (reusar)
- [horas.dart](../lib/core/util/horas.dart): `fmtFecha`, `fmtFechaLegible`, `minutosDeHora`, `horaDeMinutos`, `lunesDeSemana`, `semanaDe`, `fmtRangoSemana`, `fmtDiaCorto`.
- [moneda.dart](../lib/core/util/moneda.dart): `fmtMoneda`.

### Anti-patrones a evitar
- ❌ Colores hardcodeados en widgets (usar `Theme.of(context).colorScheme`). ❌ Romper el prefiltro del estilista o los guards de rol. ❌ Agregar `google_fonts`/`intl`/paquetes de UI sin aprobación. ❌ Mostrar el toggle de vista cuando ya hay un solo trabajador filtrado. ❌ Usar `agruparSolapados` en la vista cronológica multi-trabajador (turnos de distintos trabajadores se solapan legítimamente).

---

## Fase 1 — Sistema de tema (claro + oscuro)

**El cambio de mayor palanca: mejora todas las pantallas a la vez.**

**Implementar en [theme.dart](../lib/app/theme.dart):**
1. Refactor a dos builders: `ThemeData buildTheme(Brightness)` que arma `ColorScheme.fromSeed(seedColor: Color(0xFF534AB7), brightness: ...)` y devuelve `lightTheme`/`darkTheme`. Exponer `buildLightTheme()` y `buildDarkTheme()`.
2. **Type scale afinado** (`textTheme`): subir peso de títulos (`titleMedium`/`titleSmall` → `w600`), `bodyMedium` legible (≥14, `height: 1.4`), `labelLarge` para botones. Mantener Roboto (sin deps).
3. **Component themes** (tokens consistentes):
   - `cardTheme`: `elevation: 0`, `surfaceTintColor`, borde sutil `OutlineInputBorder`-like vía `shape: RoundedRectangleBorder(radius 16)`, sombra suave (estilo "Soft UI Evolution").
   - `appBarTheme`: `centerTitle: false`, `scrolledUnderElevation`, color `surface`.
   - `inputDecorationTheme`: `filled: true`, `OutlineInputBorder(radius 12)`, `contentPadding` cómodo (toca login y todos los forms).
   - `chipTheme` / `choiceChip`: radios y padding consistentes (toca `ChipsTrabajadores`).
   - `navigationBarTheme`: altura, indicador, labels `onSurface` (para Fase 2).
   - `listTileTheme`: `minVerticalPadding`, `shape` con radio para tiles tipo card.
   - `filledButtonTheme`/`floatingActionButtonTheme`: radios consistentes.
   - `dividerTheme`: color `outlineVariant`, `space`.
4. **Tokens de espaciado/radio** en un archivo nuevo `lib/app/tokens.dart` (`class Insets { static const xs=4, sm=8, md=12, lg=16, xl=24; }`, `class Radii {...}`) para reemplazar números mágicos gradualmente.

**Cablear en [app.dart](../lib/app/app.dart):**
- `MaterialApp.router(theme: buildLightTheme(), darkTheme: buildDarkTheme(), themeMode: ThemeMode.system, ...)`.

**Verificación:**
- `flutter analyze` limpio.
- `flutter run` (o build web): la app se ve consistente; alternar el modo del SO cambia claro/oscuro sin romper contraste (probar agenda, login, un form).
- Test de humo: `buildLightTheme().brightness == Brightness.light` y dark == dark (en `test/theme_test.dart`).

**Guarda anti-patrón:** no introducir un set de colores propio fuera del `ColorScheme`; estados de turno siguen en `estado_ui.dart` (revisar que esos hex tengan contraste aceptable sobre fondo oscuro — si no, derivar variante por brightness ahí mismo).

---

## Fase 2 — NavigationBar inferior (navegación primaria)

**Objetivo:** barra inferior M3 para destinos primarios, accesible a una mano en vertical; el resto de opciones quedan en "Más".

**Enfoque (go_router):** `StatefulShellRoute.indexedStack` con ramas, preservando estado por pestaña. Un `Scaffold` contenedor con `NavigationBar` que refleja la rama activa.

**Destinos (según rol):**
- **Agenda** (todos) → rama `/agenda` (semanal; `/agenda/dia` apila **sobre** la barra usando el `rootNavigatorKey`).
- **Clientes** (todos) → rama `/clientes`.
- **Más** (todos) → rama `/mas`: pantalla nueva `lib/features/shell/presentation/mas_screen.dart` con los items que hoy están en el Drawer (Servicios/Trabajadores/Usuarios solo dueño; Dashboard "próximamente"; Cerrar sesión). El estilista ve solo Cerrar sesión + (lectura) lo permitido.

**Implementar:**
1. `lib/features/shell/presentation/app_shell.dart` — `AppShell` con `Scaffold(body: navigationShell, bottomNavigationBar: NavigationBar(...))`; `onDestinationSelected` → `navigationShell.goBranch(i)`. Destinos con `NavigationDestination(icon/selectedIcon/label)`.
2. Reescribir [router.dart](../lib/app/router.dart): envolver `/agenda`, `/clientes`, `/mas` en `StatefulShellRoute.indexedStack`. Mantener **fuera del shell** (root navigator, full-screen sobre la barra): `/login`, `/agenda/dia`, `/clientes/detalle`, y las rutas que hoy apila el dueño (`/servicios`, `/trabajadores`, `/usuarios`) lanzadas desde "Más". Conservar `redirect`, `rutasSoloDueno`, `refreshListenable`, `initialLocation: '/agenda'`.
3. **Drawer:** dejar de usar `drawer:` en las pantallas que ahora viven en el shell (Agenda semana/Clientes). `AppDrawer` se reemplaza por `MasScreen`; mover `ChipsTrabajadores` a un archivo neutral (`lib/features/agenda/presentation/chips_trabajadores.dart`) para no depender de `app_drawer.dart`. Borrar `app_drawer.dart` cuando nadie lo importe.
4. Quitar `drawer: const AppDrawer()` de `agenda_semana_screen.dart`, `agenda_dia_screen.dart` (la diaria mantiene su flecha de volver, ya que apila sobre el shell).

**Verificación:**
- `/agenda` muestra barra inferior con Agenda/Clientes/Más; tocar Clientes cambia de rama sin perder el estado de Agenda.
- Tocar un día → `/agenda/dia` cubre la barra y "volver" regresa a la semana con la barra.
- Dueño ve en "Más" Servicios/Trabajadores/Usuarios; estilista no.
- Cerrar sesión desde "Más" → `/login`.
- `flutter analyze` limpio.

**Guarda anti-patrón:** no duplicar lógica de permisos — "Más" reusa `esDuenoProvider`/`puedeGestionarTurnosProvider`. No dejar el Drawer y la barra a la vez (confunde). Detalles full-screen via `parentNavigatorKey: rootNavigatorKey`.

---

## Fase 3 — Vista diaria por horario + toggle

**Estado nuevo** en [agenda_providers.dart](../lib/features/agenda/application/agenda_providers.dart):
```dart
enum VistaDia { porHorario, porTrabajador }

class VistaDiaModo extends Notifier<VistaDia> {
  @override
  VistaDia build() => VistaDia.porHorario; // default cronológico
  void set(VistaDia v) => state = v;
  void toggle() =>
      state = state == VistaDia.porHorario ? VistaDia.porTrabajador : VistaDia.porHorario;
}
final vistaDiaProvider = NotifierProvider<VistaDiaModo, VistaDia>(VistaDiaModo.new);
```

**Implementar en [agenda_dia_screen.dart](../lib/features/agenda/presentation/agenda_dia_screen.dart):**
1. **Toggle UI:** un `SegmentedButton<VistaDia>` (o dos `ChoiceChip`) bajo `_BarraFecha`, **solo visible cuando `filtro == null`** (modo "Todos") y no es estilista. Etiquetas: "Por horario" / "Por trabajador".
2. **`_ListaAgenda` ramifica** según `vistaDiaProvider`:
   - **`porTrabajador`** (= comportamiento actual): sin cambios — encabezados por trabajador + `agruparSolapados` + huecos solo si un trabajador.
   - **`porHorario`** (nuevo): una sola lista ordenada por `horaInicio` (ya viene ordenada del repo), **sin** `_Encabezado` ni `agruparSolapados`. Cada item = `_TurnoTile` enriquecido con **distintivo del trabajador**: franja/borde izquierdo `colorFromHex(trabajador.color)` + avatar pequeño con inicial + nombre del trabajador en el subtítulo. El punto de `estadoColor` se mantiene en `trailing`. Resolver el `Trabajador` por `t.trabajadorId` desde la lista ya disponible (`trabajadores`).
3. Cuando hay **un solo trabajador filtrado o estilista**: forzar vista cronológica con huecos (el toggle no aparece); es lo que ya hace hoy el camino `mostrarEncabezados == false`.
4. **`_ResumenDia`** se mantiene arriba en ambos modos.

**Verificación:**
- Modo "Todos" + "Por horario": turnos de distintos trabajadores intercalados por hora, cada uno con su color/inicial; sin encabezados.
- Toggle a "Por trabajador": vuelve a la vista agrupada actual.
- Filtrar a un trabajador: vista cronológica con huecos, sin toggle.
- Estilista: cronológica prefiltrada, sin toggle ni chips.
- `flutter analyze` limpio; abrir/editar/cobrar turno sigue funcionando (`showTurnoDetalle`/`showTurnoForm`).

**Guarda anti-patrón:** no usar `agruparSolapados` en `porHorario`. No inventar datos de trabajador — si falta el `Trabajador` por id, degradar a inicial genérica + color gris (`colorFromHex(null)`).

---

## Fase 4 — Pulido de listas/tiles

**Objetivo:** jerarquía visual y targets táctiles consistentes en agenda + CRUD, apoyándose en los component themes de Fase 1.

**Implementar:**
1. **Agenda diaria** — `_TurnoTile`: pasar de `ListTile` plano a un tile tipo card (borde izquierdo de color de estado/trabajador, padding cómodo, hora en `titleMedium` tabular, cliente en `w600`, servicios/teléfono en `bodySmall onSurfaceVariant`). Reusar el estilo de `_ChipTurnoMovil` que ya existe en [agenda_semana_screen.dart](../lib/features/agenda/presentation/agenda_semana_screen.dart) para consistencia.
2. **`_ResumenDia`**: reemplazar el desglose por estado en texto corrido por **chips de color** pequeños (un chip por estado con su `estadoColor` y conteo). Ingresos y % ocupación destacados.
3. **CRUD** ([clientes](../lib/features/clientes/presentation/clientes_screen.dart), [servicios](../lib/features/servicios/presentation/servicios_screen.dart), [trabajadores](../lib/features/trabajadores/presentation/trabajadores_screen.dart), [usuarios](../lib/features/auth/presentation/usuarios_screen.dart)): unificar a un patrón de tile consistente (avatar/leading con color, título `w500`, subtítulo `onSurfaceVariant`, acción `trailing`). Mantener `ListView.separated` o pasar a tarjetas con `Insets`. Estados vacíos ya están bien; alinear iconos/espaciados a tokens.
4. Quitar números mágicos repetidos usando `Insets`/`Radii` de `tokens.dart`.

**Verificación:**
- Recorrer agenda diaria (ambos modos), Clientes, Servicios, Trabajadores, Usuarios en claro y oscuro: jerarquía clara, sin desbordes, targets ≥ 48px.
- `flutter analyze` limpio.

**Guarda anti-patrón:** no romper acciones existentes (borrar, abrir detalle, editar). No densificar tanto que el target táctil baje de 48px.

---

## Fase 5 — Login + identidad

**Implementar en [login_screen.dart](../lib/features/auth/presentation/login_screen.dart):**
- Encabezado de marca: logo (icono `content_cut` en un contenedor con `primaryContainer` y radio, o un wordmark "Turnos Salón" con peso) + subtítulo.
- Fondo con un toque de identidad (gradiente sutil derivado del `colorScheme` o `surfaceContainer`), respetando claro/oscuro.
- Inputs y botón ya heredan `inputDecorationTheme`/`filledButtonTheme` de Fase 1 → consistencia automática.
- Mantener la lógica intacta (`_entrar`, validación, spinner, mensaje de error, `maxWidth: 400`).

**Verificación:**
- Login se ve con identidad en claro y oscuro; el flujo de entrada sigue igual (credenciales demo → `/agenda`).
- `flutter analyze` limpio.

**Guarda anti-patrón:** no tocar `AuthRepository.signIn` ni el redirect; es solo presentación.

---

## Fase 6 — Verificación final

1. **Análisis/tests:** `flutter analyze` (0 issues nuevos) + `flutter test` (incluye `theme_test.dart` y los existentes).
2. **Anti-patrones (grep):**
   - `grep -rn "Color(0xFF" lib/features` → solo en `estado_ui.dart`/`colores.dart` (centralizado), no en widgets nuevos.
   - `grep -rn "AppDrawer" lib/` → sin referencias colgando si se borró.
   - Confirmar `agruparSolapados` NO se usa en la rama `porHorario`.
3. **Recorrido manual (build web release contra emulador, según [docs/desarrollo-local.md](../docs/desarrollo-local.md)):**
   - Modo claro y oscuro del SO.
   - Barra inferior: Agenda / Clientes / Más; estado por pestaña preservado.
   - Vista diaria: default "Por horario" (multi-trabajador con colores), toggle a "Por trabajador", filtrado a un trabajador = cronológico con huecos.
   - Login con identidad; los 3 roles entran y ven lo de la matriz.
   - Estilista: agenda prefiltrada, sin chips/toggle.
4. **Cierre:** actualizar [docs/desarrollo-local.md](../docs/desarrollo-local.md) (sección agenda + navegación) y `/obsidian-log` del trabajo de diseño.

---

## Mapa de archivos

| Acción | Archivo |
|---|---|
| Tema claro/oscuro + component themes | [lib/app/theme.dart](../lib/app/theme.dart) |
| `darkTheme` + `themeMode` | [lib/app/app.dart](../lib/app/app.dart) |
| Tokens de espaciado/radio | `lib/app/tokens.dart` (nuevo) |
| Shell + NavigationBar inferior | `lib/features/shell/presentation/app_shell.dart` (nuevo) |
| Pantalla "Más" (ex-drawer) | `lib/features/shell/presentation/mas_screen.dart` (nuevo) |
| StatefulShellRoute + rutas full-screen | [lib/app/router.dart](../lib/app/router.dart) |
| Chips a archivo neutral; retiro de AppDrawer | `lib/features/agenda/presentation/chips_trabajadores.dart` (nuevo), [app_drawer.dart](../lib/features/agenda/presentation/app_drawer.dart) (borrar) |
| `vistaDiaProvider` (enum + notifier) | [lib/features/agenda/application/agenda_providers.dart](../lib/features/agenda/application/agenda_providers.dart) |
| Toggle + rama "por horario" + tile enriquecido | [lib/features/agenda/presentation/agenda_dia_screen.dart](../lib/features/agenda/presentation/agenda_dia_screen.dart) |
| Pulido tiles CRUD | clientes / servicios / trabajadores / usuarios screens |
| Login con identidad | [lib/features/auth/presentation/login_screen.dart](../lib/features/auth/presentation/login_screen.dart) |
| Tests | `test/theme_test.dart` (nuevo) |

## Definition of Done (medible)

- [ ] Tema claro **y** oscuro funcionando vía `ThemeMode.system`; contraste AA en ambos.
- [ ] NavigationBar inferior con Agenda/Clientes/Más; estado por pestaña preservado; detalles full-screen sobre la barra.
- [ ] Vista diaria: default "Por horario" (multi-trabajador con color/inicial) + toggle a "Por trabajador"; un trabajador filtrado = cronológico con huecos; estilista prefiltrado sin toggle.
- [ ] Tiles de agenda y CRUD pulidos y consistentes; targets ≥ 48px.
- [ ] Login con identidad de marca en ambos modos.
- [ ] `flutter analyze` limpio, `flutter test` verde, recorrido manual OK.
- [ ] Guards de rol y prefiltro del estilista intactos.

## Analyze Gate (request ↔ plan)

| ID | Categoría | Severidad | Ubicación | Resumen | Recomendación |
|----|-----------|-----------|-----------|---------|---------------|
| A1 | Ambiguity | MEDIUM | Fase 3 | "por turno respetando orden" vs grupos | Resuelto: cronológico = default, toggle conserva agrupado por trabajador |
| A2 | Risk | MEDIUM | Fase 2 | Refactor de router a StatefulShellRoute puede tocar redirects | Resuelto: conservar redirect/guards/initialLocation; detalles en root navigator |
| A3 | Constraint | LOW | Fase 1 | Tipografía sin `google_fonts` | Resuelto: afinar type scale Roboto; bundle de font queda como opción futura |
| A4 | Inconsistency | LOW | Fase 2 | Drawer y barra coexistiendo | Resuelto: la barra reemplaza al Drawer; "Más" absorbe sus items |
| A5 | Contrast | LOW | Fase 1 | `estadoColor` fijos sobre fondo oscuro | Resuelto: verificar/derivar variante por brightness en estado_ui.dart |

**Cobertura:** requisitos del usuario cubiertos 100% (vista diaria por horario + toggle ✓, tema base claro/oscuro ✓, NavigationBar inferior ✓, pulido de tiles ✓, login con identidad ✓). Findings CRITICAL/HIGH: 0.
</content>
</invoke>
