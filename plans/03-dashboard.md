# Plan — Fase 6: Dashboard (métricas del salón)

> **Fuente de verdad del producto:** `D:\Work\Obsidian\Claude\Projects\turnos\turnos-salon.md` §6 y §11 (Fase 6).
> **Objetivo:** el dueño ve métricas agregadas del salón, filtrables por rango de fechas y trabajador.
> Único rol con acceso (matriz de permisos §7 de `fase-2-auth.md`: "Dashboard → solo dueño").
> Ya hay un placeholder deshabilitado ("Dashboard · Próximamente") en `mas_screen.dart` esperando esta feature.
> **Ejecutar con:** `claude-mem:do` — fases consecutivas, cada una autocontenida.

## Decisiones (acordadas con el usuario en esta sesión)

| Q | A |
|---|---|
| ¿Visualización? | **Listas/tablas rankeadas**, sin librería de gráficos nueva (no hay `fl_chart` ni similar en `pubspec.yaml`; se mantiene la línea del resto de la app). Barras de progreso simples con `LinearProgressIndicator`/`Container` para dar sensación de magnitud relativa. |
| ¿Rango de fechas por defecto? | **Mes actual**, con selector para cambiar a otros rangos (semana actual, mes anterior, custom vía `showDateRangePicker`). |
| ¿Tamaño de franja horaria? | **Por hora completa** (09:00-10:00, 10:00-11:00, …), bucketizando `hora_inicio`. |

### Fuera de alcance
- No se agregan contadores server-side (Cloud Functions) — la spec (§6, nota técnica) dice explícitamente client-side por ahora; migrar solo si escala.
- No se agrega ninguna librería de gráficos (`fl_chart`, etc.) — decisión de esta sesión.
- No se toca la matriz de permisos ni las reglas de Firestore — el dashboard solo **lee** `turnos` (ya permitido para `activo()` en las reglas existentes) y filtra en UI por `esDuenoProvider` + guard de ruta.
- No se agregan filtros nuevos más allá de rango de fechas + trabajador (los únicos pedidos en §6).

---

## Fase 0 — APIs y patrones existentes (verificado en esta sesión)

**Acceso a datos (reusar, no reinventar):**
- `lib/features/turnos/data/turnos_repository.dart:26-39` — `TurnosRepository.watchByRango(desde, hasta)` ya existe: `Stream<List<Turno>>` filtrando por `fecha` (`'yyyy-MM-dd'`) en rango inclusive, **sin índice compuesto** (single-field range + sort en cliente). Es la query correcta para el dashboard — no crear una nueva.
- No hay provider `.family` para rango arbitrario todavía (`turnosPorSemanaProvider` está keyed a un lunes fijo). Para el dashboard se necesita un provider `.family<List<Turno>, ({String desde, String hasta})>` nuevo que llame a `watchByRango` directo (un registro, no unos por semana).
- `lib/features/trabajadores/data/trabajadores_repository.dart:57-58` — `trabajadoresStreamProvider` (`StreamProvider<List<Trabajador>>`) ya existe, usarlo para el dropdown de filtro por trabajador (mismo patrón que `chips_trabajadores.dart`).
- `lib/core/util/horas.dart` — ya tiene `fmtFecha`/`parseFecha` (usados en `turnos_repository.dart:38` y `agenda_providers`) y `minutosDeHora` (usado en `resumen_dia.dart:40`). Reusar para bucketizar franjas horarias (`minutosDeHora(t.horaInicio) ~/ 60` → hora entera).

**Modelo `Turno`** (`lib/features/turnos/domain/turno.dart`):
- Campos relevantes para agregación: `fecha` (String `'yyyy-MM-dd'`), `horaInicio` (String `'HH:mm'`), `trabajadorId`/`trabajadorNombre`, `servicios: List<ServicioEnTurno>` (`servicioId`, `nombre`, `duracionMin`), `estado: EstadoTurno`, `cobro: Cobro?` (`lineas: List<LineaCobro>` con `servicioId`/`nombre`/`monto`, `total`).
- **Solo los turnos `completado` tienen `cobro` no-nulo** (mismo invariante que usa `ResumenDia.desde`, `resumen_dia.dart:36`). Las métricas de ingreso deben sumar `LineaCobro.monto` (por servicio) o `cobro.total` (por turno/trabajador/día/hora), nunca `precio_referencia` del catálogo de servicios (la spec §4.4 es explícita: el precio real se captura al cobrar).
- "Servicios más solicitados" = **conteo de líneas**, es decir cuenta cada `ServicioEnTurno` de cada turno (no cuenta turnos) — así lo dice §6 textual: "conteo de líneas". Esto difiere de "servicios de mayor ingreso", que suma `LineaCobro.monto` (requiere `cobro`, no `servicios`) agrupado por `servicio_id`.

**Patrón de agregación pura y testeable ya establecido:**
- `lib/features/agenda/domain/resumen_dia.dart` — clase inmutable con **factory `.desde(List<Turno>, ...)`**, sin dependencia de Flutter/Riverpod, 100% testeable con `test/resumen_dia_test.dart`. **Copiar este patrón exacto** para el nuevo `DashboardMetrics` (o clase equivalente): lógica pura en `domain/`, sin `await`, sin Firestore directo.

**Rutas y permisos (reusar, no reinventar):**
- `lib/app/router.dart:24-25` — `rutasSoloDueno = {'/servicios', '/trabajadores', '/usuarios'}` — **agregar `/dashboard` a este set** (una línea) para que el guard de ruta ya existente (`router.dart:56-61`) lo cubra automáticamente.
- `lib/features/shell/presentation/mas_screen.dart:38-44` — el `ListTile` "Dashboard · Próximamente" (`enabled: false`) ya está condicionado a `if (esDueno)`. Reemplazar por un `ListTile` habilitado que navega a `/dashboard`.
- `lib/features/auth/application/auth_providers.dart` — `esDuenoProvider` (`Provider<bool>`) ya existe, usar para doble-check en la propia pantalla (defensa en profundidad, mismo patrón que `mas_screen.dart`).

**UI de filtros (reusar, no reinventar):**
- Selector de rango: `showDateRangePicker` (API estándar de Flutter, Material 3) — no hay wrapper propio en el repo, es la primera vez que se necesita rango custom. Helpers de fecha (`fmtFecha`) para convertir `DateTimeRange` → strings `'yyyy-MM-dd'` que pide `watchByRango`.
- Filtro de trabajador: `DropdownButton`/`DropdownMenu` sobre `trabajadoresStreamProvider`, patrón similar a los chips de `chips_trabajadores.dart` pero como dropdown (no chips, porque acá es un solo filtro exclusivo + opción "Todos", no multi-selección).

### Anti-patrones a evitar
- ❌ No crear una nueva query Firestore para el dashboard — usar `TurnosRepository.watchByRango` (ya sin índice compuesto).
- ❌ No sumar `precio_referencia` de `servicios` — las métricas de ingreso son SIEMPRE sobre `cobro`/`LineaCobro.monto` de turnos `completado`.
- ❌ No hacer la agregación dentro de un widget (`build()`) sin extraerla a una clase pura en `domain/` — rompe el patrón de `resumen_dia.dart` y la hace imposible de testear.
- ❌ No agregar `fl_chart` ni ninguna librería de gráficos (decisión de esta sesión).
- ❌ No usar `await` en las lecturas — todo vía `Stream`/`StreamProvider`, igual que el resto de la app (patrón offline §9 de la spec).
- ❌ No olvidar agregar `/dashboard` a `rutasSoloDueno` — sin eso, el guard de ruta no protege la URL directa.

---

## Fase 1 — Capa de dominio: `DashboardMetrics` (lógica pura)

**Archivo nuevo:** `lib/features/dashboard/domain/dashboard_metrics.dart`

1. Clase inmutable `DashboardMetrics` con factory `DashboardMetrics.desde(List<Turno> turnos)`:
   - `totalTurnos: int`
   - `porServicioConteo: List<(String nombre, int conteo)>` — cuenta **líneas** de `t.servicios` sobre TODOS los turnos del rango (no solo completados; "servicios más solicitados" es demanda, no ingreso), agrupado por `servicioId`, tomando el `nombre` de la primera aparición. Ordenado desc, ya listo para pintar top-N.
   - `porServicioIngreso: List<(String nombre, num monto)>` — suma `LineaCobro.monto` agrupado por `servicioId` sobre turnos `completado` con `cobro != null`. Ordenado desc.
   - `porTrabajadorConteo: List<(String nombre, int conteo)>` — cuenta turnos por `trabajadorId`/`trabajadorNombre` (todos los estados, es "más turnos").
   - `porTrabajadorIngreso: List<(String nombre, num monto)>` — suma `cobro.total` por `trabajadorId` sobre `completado`.
   - `porDiaConteo: List<(String fecha, int conteo)>` y `porDiaIngreso: List<(String fecha, num monto)>` — agrupado por `t.fecha`, mismo criterio completado/no según corresponda.
   - `porHoraConteo: List<(int hora, int conteo)>` y `porHoraIngreso: List<(int hora, num monto)>` — agrupado por `minutosDeHora(t.horaInicio) ~/ 60` (franja de hora completa, 0-23).
2. Reusar el mismo estilo que `resumen_dia.dart`: un solo loop `for (final t in turnos)` acumulando en mapas, conversión a listas ordenadas al final. Sin dependencias de Flutter/Riverpod/Firestore.

**Doc refs:** `resumen_dia.dart` completo (patrón a copiar), `turno.dart` (campos de `Turno`/`ServicioEnTurno`/`LineaCobro`/`Cobro`).

**Verificación:**
- `flutter analyze` limpio.
- Test nuevo `test/dashboard_metrics_test.dart` (mismo estilo que `resumen_dia_test.dart`): construir 4-5 turnos fixture cubriendo servicios repetidos, dos trabajadores, dos días, dos franjas horarias, y turnos `completado`/`pendiente`/`cancelado` mezclados. Asserts sobre cada lista (`porServicioConteo`, `porServicioIngreso`, etc.) con valores exactos calculados a mano.

**Guards anti-patrón:** no meter Firestore ni Riverpod en este archivo; no sumar `precio_referencia`; no contar `porServicioConteo` solo sobre completados (es demanda total, no ingreso).

---

## Fase 2 — Provider de datos filtrados

**Archivo nuevo:** `lib/features/dashboard/application/dashboard_providers.dart`

1. Estado del filtro de rango: `Notifier<DateTimeRange>` (`RangoDashboard`), default = **mes actual** (`DateTime.now()` → primer/último día del mes, usar `DateTime(year, month, 1)` y `DateTime(year, month + 1, 0)`).
2. Estado del filtro de trabajador: reusar el patrón de `TrabajadorFiltro` (`agenda_providers.dart:18-26`) — puede ser el mismo provider (`trabajadorFiltroProvider`) o uno nuevo `dashboardTrabajadorFiltroProvider` si se quiere que el filtro del dashboard sea independiente del de la agenda (**recomendado: independiente**, para no pisar el filtro que el usuario dejó puesto en la agenda).
3. Provider derivado `dashboardTurnosProvider` (`StreamProvider`):
   - Lee `rangoDashboardProvider` → `fmtFecha(rango.start)`/`fmtFecha(rango.end)`.
   - Llama `ref.watch(turnosRepositoryProvider).watchByRango(desde, hasta)`.
   - Si `dashboardTrabajadorFiltroProvider` no es `null`, filtra la lista resultante por `trabajadorId` (filtro en cliente, mismo patrón que la agenda con `trabajadorFiltroProvider`).
4. Provider derivado `dashboardMetricsProvider` (`Provider`, no `StreamProvider`): `DashboardMetrics.desde(ref.watch(dashboardTurnosProvider).value ?? [])`.

**Doc refs:** `agenda_providers.dart` completo (patrón `Notifier`/`NotifierProvider`), `turnos_repository.dart:26-39` (`watchByRango`).

**Verificación:** `flutter analyze` limpio. No requiere test unitario nuevo (son providers, se validan por uso en Fase 3 + manual).

**Guards anti-patrón:** el filtro de trabajador del dashboard NO debe compartir estado con `trabajadorFiltroProvider` de la agenda (evita que cambiar uno mueva el otro sin que el usuario lo espere).

---

## Fase 3 — Pantalla `DashboardScreen`

**Archivo nuevo:** `lib/features/dashboard/presentation/dashboard_screen.dart`

1. `Scaffold` con `AppBar(title: Text('Dashboard'))`.
2. Header de filtros:
   - Chip/botón con el rango actual formateado (ej. "1-31 jul 2026") que abre `showDateRangePicker` (rango inicial = `rangoDashboardProvider`, `firstDate`/`lastDate` amplios). Al confirmar, `ref.read(rangoDashboardProvider.notifier).set(rango)`.
   - Atajos rápidos: `ActionChip`/`SegmentedButton` con "Este mes" / "Mes anterior" / "Esta semana" que setean el rango directo (sin abrir el picker).
   - `DropdownButton<String?>` con `trabajadoresStreamProvider` + opción "Todos" (`null`) para `dashboardTrabajadorFiltroProvider`.
3. Cuerpo: `ListView` con una sección por métrica (reusar `Card`/`ListTile` — estilo Material 3 del resto de la app, ver `theme.dart` component themes):
   - "Servicios más solicitados" — top 5 de `porServicioConteo`, cada fila con nombre + conteo + `LinearProgressIndicator` (valor relativo al máximo del top).
   - "Servicios de mayor ingreso" — top 5 de `porServicioIngreso`, monto formateado con `core/util/moneda.dart` (ya existe, usado en `cliente_detalle_screen.dart`/cobro).
   - "Trabajadores — más turnos" y "— mayor ingreso" — reusar el mismo patrón de fila.
   - "Días con más turnos/ingreso" — igual, `fecha` formateada legible (reusar helper de fecha existente si hay uno para mostrar día+fecha, si no, `DateFormat` de `intl` si ya está en `pubspec.yaml`; si no está, formatear a mano `dd/MM`).
   - "Horarios con más turnos/ingreso" — fila por hora `09:00`, `10:00`, etc. (formatear el `int hora` con `.toString().padLeft(2,'0')`).
   - Estado vacío: si `dashboardTurnosProvider` no tiene datos en el rango, `Center` con texto "Sin turnos en este rango" (mismo tono que otros empty states del repo, ej. `servicios_screen.dart`).
4. Ruta `/dashboard` en `lib/app/router.dart`:
   - `GoRoute(path: '/dashboard', name: 'dashboard', parentNavigatorKey: _rootNavigatorKey, builder: (_, __) => const DashboardScreen())` — mismo patrón que `/servicios`/`/trabajadores`/`/usuarios`.
   - Agregar `'/dashboard'` a `rutasSoloDueno` (`router.dart:25`).
5. `lib/features/shell/presentation/mas_screen.dart:38-44`: reemplazar el `ListTile` deshabilitado "Dashboard · Próximamente" por uno habilitado que hace `context.push('/dashboard')` (mismo patrón que "Servicios"/"Trabajadores"/"Usuarios" arriba en el mismo archivo).

**Doc refs:** `mas_screen.dart` completo (patrón de `ListTile` + `esDuenoProvider`), `router.dart` completo (patrón de ruta full-screen sobre `_rootNavigatorKey`), `theme.dart` (component themes reusados), `core/util/moneda.dart` (formato de montos).

**Verificación:**
- Manual (emulador, usuario `dueno@salon.test`): abrir "Más" → "Dashboard" ya no dice "Próximamente"; cambiar rango a "Mes anterior" actualiza las listas; filtrar por un trabajador reduce los conteos; navegar a `/dashboard` como `estilista`/`recepcion` (URL directa o intentando abrir el link, que ni siquiera se muestra) redirige a `/agenda`.
- `flutter analyze` limpio.

**Guards anti-patrón:** no dejar el `ListTile` de "Dashboard" visible/habilitado para roles no-dueño (ya cubierto por el `if (esDueno)` existente en `mas_screen.dart`, no tocar esa condición); no navegar a `/dashboard` sin que esté en `rutasSoloDueno` (si se olvida, la URL directa bypassea el guard).

---

## Fase 4 — Verificación final

1. **Búsqueda de referencias muertas / anti-patrones:**
   ```
   grep -rn "fl_chart\|charts_flutter" pubspec.yaml lib   # → 0 resultados (no se agregó lib de gráficos)
   grep -n "'/dashboard'" lib/app/router.dart              # → aparece tanto en GoRoute como en rutasSoloDueno
   grep -n "precio_referencia" lib/features/dashboard      # → 0 resultados (ingresos solo desde cobro)
   ```
2. **Análisis estático:** `flutter analyze` → sin issues.
3. **Tests:** `flutter test` → todos verdes, incluyendo `dashboard_metrics_test.dart` nuevo.
4. **Smoke manual (emulador):** con datos seed actuales (pocos turnos), el dashboard puede mostrar rankings cortos o vacíos — si hace falta más volumen para probar el "top 5" y el ranking por hora, ampliar `lib/dev/seed.dart` con turnos `completado` en más días/horas/trabajadores (ítem ya anotado como pendiente opcional en la nota del proyecto: "Ampliar seed con ~15-20 servicios").
5. **Actualizar nota del proyecto** (`turnos-salon.md`): marcar Fase 6 completa en §11 y "Recent Activity", y tachar el ítem `- [ ] **Fase 6** — Dashboard` en "Próximos pasos".

### Tabla de cobertura request → fases
| Requisito de §6 (spec) | Fase(s) |
|---|---|
| Servicios más solicitados (conteo de líneas) | 1, 3 |
| Servicios de mayor ingreso | 1, 3 |
| Trabajadores con más turnos / mayor ingreso | 1, 3 |
| Días con más turnos / mayor ingreso | 1, 3 |
| Horarios con más turnos / mayor ingreso | 1, 3 |
| Filtrable por rango de fechas y trabajador | 2, 3 |
| Solo accesible para el dueño | 0 (hallazgo), 3 |
| Agregación client-side (nota técnica §6) | 1, 2 |
