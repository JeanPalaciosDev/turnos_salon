# Plan — Vista semanal + vista diaria enriquecida (Agenda)

> Generado con `/claude-mem:make-plan`. Ejecutar con `/claude-mem:do` fase por fase.

## Objetivo

Hoy la agenda muestra **un solo día** con flechas ◀ ▶ ([agenda_screen.dart](../lib/features/agenda/presentation/agenda_screen.dart)).
Es pobre visualmente. Se quiere:

1. **Vista semanal** (lunes→domingo) como pantalla de entrada, con **menos detalle**, en formato **grilla de 7 columnas** (mini-timeline), **responsive**.
2. La **vista diaria** pasa a ser un detalle al **tocar un día**, y se **enriquece** con más información.

## Decisiones del usuario (Clarification Gate)

| Q | A |
|---|---|
| Layout semanal | **Grilla de 7 columnas** (mini-timeline horario) |
| Navegación | **Semanal = pantalla inicial**; tocar un día abre la vista diaria detallada (con botón volver) **+ texto que explica la acción** ("Tocá un día para ver el detalle") |
| Detalle extra en vista diaria | **Encabezado con totales** + **más info por turno** + **huecos libres** |
| Dispositivo | **Ambos (responsive)**: grilla en ancho ≥ 600px, lista compacta en < 600px |

## Restricciones / supuestos

- **Sin dependencias nuevas.** Solo Flutter Material + `flutter_riverpod ^3` + `cloud_firestore ^6` + `go_router ^17` (ver [pubspec.yaml](../pubspec.yaml)). **No** agregar `table_calendar`, `intl`, `syncfusion`, etc.
- `fecha` se guarda como `'yyyy-MM-dd'` (string) → ordena lexicográficamente = cronológicamente. Las queries de rango funcionan sin índice compuesto (un solo campo de desigualdad; Firestore crea el índice de campo único automáticamente).
- `weekday`: lunes = 1 … domingo = 7 (igual que `SalonConfig.diasLaborables`).
- Horario del salón viene de `config/salon` → `configStreamProvider` (`horaApertura`/`horaCierre`/`diasLaborables`), ver [salon_config.dart](../lib/features/config/domain/salon_config.dart).
- El **prefiltro del estilista** (un estilista solo ve SU agenda) y el filtro por trabajador deben seguir funcionando en AMBAS vistas. Reusar `trabajadorFiltroProvider` y la lógica de `ref.listen(usuarioActualProvider…)` ya existente en [agenda_screen.dart:33-45](../lib/features/agenda/presentation/agenda_screen.dart).

---

## Fase 0 — APIs / patrones permitidos (leer ANTES de codear)

Esta es una app Flutter sin docs externas; la "documentación" es el código existente. **Copiar estos patrones, no inventar APIs.**

### Acceso a datos (Firestore vía Riverpod)
- Repo: [turnos_repository.dart](../lib/features/turnos/data/turnos_repository.dart). Patrón de query existente a copiar:
  ```dart
  Stream<List<Turno>> watchByFecha(String fecha) =>
      _col.where('fecha', isEqualTo: fecha).snapshots().map((snap) {
        final turnos = snap.docs.map((d) => Turno.fromMap(d.id, d.data())).toList();
        turnos.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
        return turnos;
      });
  ```
- Providers: `StreamProvider.family` (ver `turnosPorFechaProvider`, [turnos_repository.dart:97-99](../lib/features/turnos/data/turnos_repository.dart)).

### Estado de fecha (Riverpod Notifier)
- [agenda_providers.dart](../lib/features/agenda/application/agenda_providers.dart): `FechaSeleccionada extends Notifier<DateTime>` con `hoy()`, `mover(int dias)`, `set(DateTime)`.

### Helpers de fecha/hora
- [horas.dart](../lib/core/util/horas.dart): `fmtFecha(DateTime)` → `'yyyy-MM-dd'`, `parseFecha(String)`, `fmtFechaLegible(DateTime)` → `'Jue 19 jun'`, `minutosDeHora('HH:mm')`, `horaDeMinutos(int)`, y las constantes privadas `_dias`/`_meses`.
- [moneda.dart](../lib/core/util/moneda.dart): `fmtMoneda(num)` → `'$ 1.234,50'`.

### Presentación de turnos (reusar)
- [estado_ui.dart](../lib/features/turnos/presentation/estado_ui.dart): `estadoColor(EstadoTurno)`, `estadoLabel(EstadoTurno)`.
- [agrupar_solapamientos.dart](../lib/features/turnos/domain/agrupar_solapamientos.dart): `agruparSolapados(List<Turno>)` para atención simultánea.
- Sheets/forms: `showTurnoDetalle(context, turno)`, `showTurnoForm(context, …)` (ver imports de [agenda_screen.dart:13-15](../lib/features/agenda/presentation/agenda_screen.dart)).

### Navegación (go_router)
- [router.dart](../lib/app/router.dart): rutas con `GoRoute(path, name, builder)`, `initialLocation: '/agenda'`, redirects de auth. `context.push('/ruta')` para apilar.

### Anti-patrones a evitar
- ❌ Agregar paquetes de calendario/fecha. ❌ Query con dos campos de desigualdad (solo `fecha` puede ser rango). ❌ `intl`/`DateFormat` (usar helpers de `horas.dart`). ❌ Romper el prefiltro del estilista. ❌ Hardcodear horario 09–20 (leer de `SalonConfig`).

---

## Fase 1 — Capa de datos: rango semanal

**Qué implementar (copiar de `watchByFecha`):**

1. En [turnos_repository.dart](../lib/features/turnos/data/turnos_repository.dart), añadir:
   ```dart
   /// Turnos entre dos fechas inclusive ('yyyy-MM-dd'). Rango sobre el único
   /// campo de desigualdad `fecha` → sin índice compuesto. Ordena en cliente.
   Stream<List<Turno>> watchByRango(String desde, String hasta) =>
       _col
           .where('fecha', isGreaterThanOrEqualTo: desde)
           .where('fecha', isLessThanOrEqualTo: hasta)
           .snapshots()
           .map((snap) {
             final turnos =
                 snap.docs.map((d) => Turno.fromMap(d.id, d.data())).toList();
             turnos.sort((a, b) {
               final f = a.fecha.compareTo(b.fecha);
               return f != 0 ? f : a.horaInicio.compareTo(b.horaInicio);
             });
             return turnos;
           });
   ```
2. Provider family keyed por **fecha de inicio de semana** (lunes, `'yyyy-MM-dd'`):
   ```dart
   /// Turnos de la semana cuyo lunes es [lunesFecha] ('yyyy-MM-dd').
   final turnosPorSemanaProvider =
       StreamProvider.family<List<Turno>, String>((ref, lunesFecha) {
     final lunes = parseFecha(lunesFecha);
     final domingo = lunes.add(const Duration(days: 6));
     return ref.watch(turnosRepositoryProvider)
         .watchByRango(lunesFecha, fmtFecha(domingo));
   });
   ```

3. Helper de semana en [horas.dart](../lib/core/util/horas.dart):
   ```dart
   /// Lunes (00:00 local) de la semana que contiene [d].
   DateTime lunesDeSemana(DateTime d) =>
       DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

   /// Los 7 días (lunes→domingo) de la semana que contiene [d].
   List<DateTime> semanaDe(DateTime d) {
     final l = lunesDeSemana(d);
     return List.generate(7, (i) => l.add(Duration(days: i)));
   }
   ```

**Verificación:**
- `flutter analyze` sin errores nuevos.
- Test unitario nuevo en `test/horas_test.dart` (o `test/semana_test.dart`): `lunesDeSemana` para un miércoles devuelve el lunes correcto; `semanaDe` devuelve 7 días lunes→domingo; un domingo (`weekday==7`) mapea al lunes anterior. Correr `flutter test`.

**Guardas anti-patrón:** no usar `isEqualTo` en bucle de 7 queries; una sola query de rango.

---

## Fase 2 — Vista semanal (grilla responsive) + navegación

**Estado nuevo** en [agenda_providers.dart](../lib/features/agenda/application/agenda_providers.dart):
- Reusar `fechaSeleccionadaProvider` como **ancla compartida** entre semana y día.
- Añadir a `FechaSeleccionada`: `void moverSemana(int s) => state = state.add(Duration(days: 7 * s));`.

**Archivo nuevo:** `lib/features/agenda/presentation/agenda_semana_screen.dart` con `AgendaSemanaScreen extends ConsumerWidget` (o `ConsumerStatefulWidget` para reusar el `ref.listen` del prefiltro estilista — copiarlo de [agenda_screen.dart:33-45](../lib/features/agenda/presentation/agenda_screen.dart)).

Estructura:
- `Scaffold` con `AppBar('Agenda')`, `drawer: const _AppDrawer()` → **mover `_AppDrawer` a un archivo compartido** `lib/features/agenda/presentation/app_drawer.dart` (hoy es privado en agenda_screen.dart) y que ambas pantallas lo importen. El item "Agenda" del drawer navega a la semanal (`context.go('/agenda')`).
- Barra de semana: ◀ `moverSemana(-1)` / título "16–22 jun" (rango legible, derivado con helpers de `horas.dart`) / ▶ `moverSemana(1)`, y botón **"Hoy"** (`hoy()`).
- **Texto explicativo** debajo de la barra: `Text('Tocá un día para ver el detalle', style: bodySmall onSurfaceVariant)` centrado — pedido explícito del usuario.
- Chips de trabajador (reusar `_ChipsTrabajadores`, también moverlo a archivo compartido o duplicar) salvo para estilista.
- Cuerpo: `ref.watch(turnosPorSemanaProvider(fmtFecha(lunesDeSemana(fecha))))` con `.when(loading/error/data)`.

**Layout responsive** (`LayoutBuilder`):
- **Ancho ≥ 600px → `_GrillaSemana`**: 7 columnas (lunes→domingo). Cada columna = encabezado (`'Lun 16'`) + área de tiempo. El eje vertical va de `minutosDeHora(config.horaApertura)` a `horaCierre` (fallback `09:00`–`20:00` si `config` aún carga). Cada turno = bloque posicionado (`Stack`/`Positioned` o filas por franja) con altura ∝ duración (`finEstimado − horaInicio`), color = `estadoColor`, texto mínimo (hora + cliente truncado). **Menos detalle**: sin subtítulos largos. Toda la columna es tappable y el bloque también → navegan al día.
- **Ancho < 600px → `_ListaSemana`**: 7 filas (una por día), cada fila = `Card`/`ListTile` con `'Lun 16'`, contador de turnos y mini-resumen (p. ej. fila de puntos `estadoColor` o "3 turnos"). Días sin turnos atenuados. Días no laborables (`!config.diasLaborables.contains(weekday)`) marcados sutilmente.

**Navegación al día:** al tocar un día → `ref.read(fechaSeleccionadaProvider.notifier).set(dia); context.push('/agenda/dia');`

**Router** ([router.dart](../lib/app/router.dart)):
- Mantener `path: '/agenda'` pero `builder: (_, __) => const AgendaSemanaScreen()`.
- Añadir `GoRoute(path: '/agenda/dia', name: 'agenda-dia', builder: (_, __) => const AgendaDiaScreen())` (la pantalla de Fase 3).
- Verificar que los redirects de login (`'/agenda'`) y el `initialLocation` sigan apuntando a la semanal (sí, '/agenda').

**Verificación:**
- App corre (`flutter run -d chrome` o emulador); `/agenda` muestra la semana; tocar un día apila `/agenda/dia` con el día correcto y el botón "volver" del AppBar regresa.
- Redimensionar la ventana cruza el breakpoint 600px y alterna grilla↔lista.
- Estilista: la semanal aparece prefiltrada y sin chips.
- `flutter analyze` limpio.

**Guardas anti-patrón:** no duplicar la lógica de prefiltro de forma divergente — copiar exacto. No hardcodear el horario. No romper `initialLocation`.

---

## Fase 3 — Vista diaria enriquecida

**Renombrar/mover** la actual `AgendaScreen` → `AgendaDiaScreen` en `lib/features/agenda/presentation/agenda_dia_screen.dart` (es la lista por trabajador ya existente). El AppBar ahora tiene **flecha de volver automática** (viene de `context.push`). Conservar las flechas ◀ ▶ de `_BarraFecha` para moverse día a día sin volver a la semana, y el botón "Hoy".

Añadir **tres mejoras** (las tres pedidas):

### 3a. Encabezado con totales (`_ResumenDia`)
Widget sobre la lista. Calcular desde `visibles` (turnos filtrados del día):
- **Nº de turnos** y desglose por estado (p. ej. "2 pendientes · 1 en curso · 3 completados") usando `estadoLabel`.
- **Ingresos cobrados**: `sum(t.cobro?.total)` de los `completado` → `fmtMoneda`. (No hay precio estimado en el snapshot del turno; no inventarlo.)
- **Ocupación** (opcional, si es trivial): `sum(duración de turnos) / minutos laborables del día` (de `config`), como `'68% ocupado'`.
Lógica pura en helper testeable: `lib/features/agenda/domain/resumen_dia.dart` → `ResumenDia.desde(List<Turno>, SalonConfig?)`.

### 3b. Más info por turno (enriquecer `_TurnoTile`)
En el tile (hoy solo hora + cliente + `servicios + estado`, [agenda_screen.dart:300-336](../lib/features/agenda/presentation/agenda_screen.dart)) agregar:
- Franja horaria completa: `'${turno.horaInicio}–${turno.finEstimado}'` + duración total `'· ${dur} min'` (`dur = minutosDeHora(finEstimado) − minutosDeHora(horaInicio)`).
- **Teléfono** del cliente si existe (`turno.clienteTelefono`), con `Icons.phone` pequeño.
- Lista completa de servicios (ya se arma `servicios.join(' + ')`; mantener o pasar a chips).
- Mantener el punto de `estadoColor` en `trailing` y el `onTap` → `showTurnoDetalle`/`showTurnoForm` intactos.

### 3c. Huecos libres (`_HuecoTile` entre turnos)
- Helper puro `lib/features/agenda/domain/huecos.dart` → `List<Hueco> calcularHuecos(List<Turno> turnosOrdenados, SalonConfig? config)`: recorre los grupos no solapados ordenados por hora; un `Hueco{desde, hasta, minutos}` por cada brecha entre `finEstimado` del anterior y `horaInicio` del siguiente, acotado a `[horaApertura, horaCierre]`; incluir hueco inicial (apertura→primer turno) y final (último→cierre) si > umbral (p. ej. ≥ 15 min). Reusar `minutosDeHora`/`horaDeMinutos`.
- Intercalar `_HuecoTile` (estilo tenue, `Icons.schedule`, "Libre 12:30–14:00 · 90 min") en `_ListaAgenda`. Solo cuando hay filtro de un trabajador (`mostrarEncabezados == false`) o por trabajador dentro de su encabezado — definir: **mostrar huecos solo en vista de un trabajador** (con varios trabajadores los huecos se solapan y confunden). Tappable opcional → `showTurnoForm` con esa hora pre-cargada (nice-to-have, no obligatorio).

**Verificación:**
- Tests unitarios: `test/resumen_dia_test.dart` (conteos por estado + suma de cobros) y `test/huecos_test.dart` (hueco entre dos turnos, sin huecos si están pegados, hueco inicial/final, respeta apertura/cierre). `flutter test`.
- En app: un día con turnos muestra encabezado de totales, tiles con teléfono/duración, y huecos al filtrar por un trabajador.
- `flutter analyze` limpio.

**Guardas anti-patrón:** no inventar ingresos "estimados" (no hay precio en el turno). No mostrar huecos en vista multi-trabajador. No duplicar `agruparSolapados`.

---

## Fase 4 — Verificación final

1. **Análisis y tests:** `flutter analyze` (0 issues nuevos) + `flutter test` (todos verdes, incluidos los 3 archivos de test nuevos).
2. **Anti-patrones (grep):**
   - `grep -rn "table_calendar\|package:intl\|DateFormat" lib/` → sin resultados.
   - `grep -rn "09:00\|20:00" lib/features/agenda/` → solo como *fallback* explícito cuando `config == null`, no como horario fijo.
   - Confirmar una sola query de rango: `grep -rn "isGreaterThanOrEqualTo" lib/features/turnos/data/turnos_repository.dart` → 1 uso.
3. **Recorrido manual (flutter run):**
   - `/agenda` abre en semanal, semana actual, "Hoy" funciona, ◀▶ cambian de semana.
   - Texto "Tocá un día para ver el detalle" visible.
   - Tocar día → `/agenda/dia` con totales + tiles enriquecidos + huecos (filtrando trabajador); volver funciona.
   - Breakpoint 600px alterna grilla↔lista.
   - Estilista: ambas vistas prefiltradas, sin chips de trabajador.
   - Dueño: chips de "Todos" + trabajadores en ambas vistas.
4. **Regresión:** alta/edición de turno (`showTurnoForm`), detalle (`showTurnoDetalle`) y cierre/cobro siguen funcionando desde la vista diaria.

---

## Mapa de archivos

| Acción | Archivo |
|---|---|
| +método `watchByRango` + `turnosPorSemanaProvider` | [turnos_repository.dart](../lib/features/turnos/data/turnos_repository.dart) |
| +`lunesDeSemana`/`semanaDe` | [horas.dart](../lib/core/util/horas.dart) |
| +`moverSemana` | [agenda_providers.dart](../lib/features/agenda/application/agenda_providers.dart) |
| nuevo: pantalla semanal (grilla/lista responsive) | `lib/features/agenda/presentation/agenda_semana_screen.dart` |
| renombrar AgendaScreen → AgendaDiaScreen + 3 mejoras | `lib/features/agenda/presentation/agenda_dia_screen.dart` |
| extraer drawer/chips compartidos | `lib/features/agenda/presentation/app_drawer.dart` |
| nuevo: lógica pura resumen del día | `lib/features/agenda/domain/resumen_dia.dart` |
| nuevo: lógica pura de huecos | `lib/features/agenda/domain/huecos.dart` |
| rutas `/agenda` (semanal) + `/agenda/dia` | [router.dart](../lib/app/router.dart) |
| tests | `test/semana_test.dart`, `test/resumen_dia_test.dart`, `test/huecos_test.dart` |

## Analyze Gate (request ↔ plan)

| ID | Categoría | Severidad | Ubicación | Resumen | Recomendación |
|----|-----------|-----------|-----------|---------|---------------|
| A1 | Underspecification | MEDIUM | Fase 3c | Huecos en vista multi-trabajador son ambiguos | Resuelto: mostrar solo en vista de un trabajador |
| A2 | Inconsistency | LOW | Fase 2/3 | `_AppDrawer`/`_ChipsTrabajadores` hoy privados en agenda_screen | Resuelto: extraer a archivo compartido |
| A3 | Coverage | LOW | Fase 3a | "Ingresos estimados" no existe en el modelo | Resuelto: solo ingresos cobrados (cobro.total) |
| A4 | Ambiguity | LOW | Fase 2 | Breakpoint responsive sin valor | Resuelto: 600px |

**Cobertura:** requisitos del usuario cubiertos 100% (semanal grilla ✓, responsive ✓, navegación con texto ✓, totales ✓, más info por turno ✓, huecos ✓). Findings CRITICAL/HIGH: 0.
