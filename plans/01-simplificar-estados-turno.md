# Plan — Simplificar los estados del turno

> Objetivo: eliminar los estados que estorban al usuario (`confirmado`, `enCurso`) y
> dejar solo los que se usan en la práctica de un salón:
> **Pendiente · Completado · Cancelado · No vino**.
> "Completado" se sigue asignando **solo al cobrar** (no es manual).

## Decisiones (acordadas con el usuario)

| Q | A |
|---|---|
| ¿Qué estados conservar? | **Pendiente + Completado + Cancelado + No vino**. Se eliminan `confirmado` y `enCurso`. |
| Datos existentes en Firestore | **Solo seed/demo → sin migración.** Valores legacy (`confirmado`/`en_curso`) caen al default `pendiente` vía `estadoFromDb`. |

### Modelo final
```
EstadoTurno { pendiente, completado, cancelado, noShow }
```
- `pendiente` = agendado, aún no resuelto (default). Único estado **no terminal**.
- `completado` = cliente atendido y cobrado. Se asigna **solo** en `registrarCobro` (no manual).
- `cancelado` = cancelación avisada (libera el hueco).
- `noShow` ("No vino") = ausencia sin aviso. **El estado que el usuario realmente quiere marcar.**

### Fuera de alcance
- No se cambia la lógica de cobro ni el cálculo de ingresos.
- No se renombran valores existentes ni se toca el esquema de Firestore.
- No se agregan estados nuevos ni toggles nuevos de UI (se reusan los botones actuales, solo se quitan dos).

---

## Phase 0 — APIs y patrones existentes (ya verificado)

Fuente leída: todo el feature `turnos` + sus consumidores. Símbolos y firmas reales:

**Definición del enum** — `lib/features/turnos/domain/turno.dart`
- L5: `enum EstadoTurno { pendiente, confirmado, enCurso, completado, cancelado, noShow }`
- L7-15: `EstadoTurno estadoFromDb(String? v)` — `switch` con default `_ => EstadoTurno.pendiente` (absorbe valores desconocidos sin romper).
- L17-24: `String estadoToDb(EstadoTurno e)` — `switch` **exhaustivo** (Dart obliga a cubrir todos los casos).

**UI de estado** — `lib/features/turnos/presentation/estado_ui.dart`
- L6-13: `Color estadoColor(EstadoTurno e)` — switch exhaustivo.
- L16-23: `String estadoLabel(EstadoTurno e)` — switch exhaustivo. Etiqueta de `noShow` = `'No vino'`.

**Consumidores de los estados manuales a eliminar:**
1. `lib/features/turnos/presentation/turno_detalle_sheet.dart`
   - L85-90: botones `_EstadoButton` → `Confirmar` (`confirmado`), `En curso` (`enCurso`), `Cancelar` (`cancelado`), `No vino` (`noShow`).
   - L163-166: `_esTerminal(e)` = `completado || cancelado || noShow`. **No cambia** (sigue correcto; `pendiente` queda como único no-terminal).
2. `lib/features/agenda/presentation/agenda_dia_screen.dart`
   - **L618: `estadoColor(EstadoTurno.enCurso)`** — uso "prestado" del verde para colorear los **ingresos**, NO es un estado real. Hay que sustituirlo por un color que no dependa del enum eliminado.
3. `lib/dev/seed.dart`
   - L107: `EstadoTurno.confirmado` · L109: `EstadoTurno.enCurso` (datos demo).
4. `test/resumen_dia_test.dart`
   - L40, L45, L57: `EstadoTurno.enCurso`.

**No requieren cambios** (usan el enum de forma genérica o solo estados que se conservan):
- `resumen_dia.dart` (mapa `porEstado` genérico + chequeo de `completado`).
- `turno_form.dart:149` (default `pendiente`).
- `turnos_repository.dart` (`updateEstado` genérico; `registrarCobro` usa `completado`).
- chips de agenda semanal / día / ficha de cliente (usan `estadoColor`/`estadoLabel` genéricos).

### Anti-patrones a evitar
- ❌ No agregar un estado "atendido"/"vino" nuevo: "atendido" = `completado` (vía cobro).
- ❌ No tocar `estadoFromDb`'s default `_ => pendiente` — es lo que hace innecesaria la migración.
- ❌ No dejar referencias a `EstadoTurno.confirmado` / `EstadoTurno.enCurso`: el analizador de Dart fallará en compilación (es la red de seguridad).

---

## Phase 1 — Reducir el enum y sus mapeos (`turno.dart`)

**Archivo:** `lib/features/turnos/domain/turno.dart`

1. L3-5: actualizar el doc-comment y el enum:
   ```dart
   /// Estado del turno. `pendiente` es el único estado vivo; `completado`
   /// (vía cobro), `cancelado` y `noShow` son ramas terminales.
   enum EstadoTurno { pendiente, completado, cancelado, noShow }
   ```
2. L7-15 `estadoFromDb`: **eliminar** las ramas `'confirmado'` y `'en_curso'`.
   Conservar el default `_ => EstadoTurno.pendiente` (los docs legacy con esos
   valores caen ahí automáticamente).
3. L17-24 `estadoToDb`: **eliminar** los casos `confirmado` y `enCurso`. El switch
   queda exhaustivo con 4 casos.

**Verificación:** `grep -n "confirmado\|enCurso\|en_curso" lib/features/turnos/domain/turno.dart` → 0 resultados.

---

## Phase 2 — Limpiar la UI de estado (`estado_ui.dart`)

**Archivo:** `lib/features/turnos/presentation/estado_ui.dart`

1. L6-13 `estadoColor`: eliminar los casos `confirmado` y `enCurso`. Quedan 4 casos
   (switch exhaustivo). Mantener los colores actuales de los 4 conservados.
2. L16-23 `estadoLabel`: eliminar los casos `confirmado` y `enCurso`.

**Verificación:** `flutter analyze` no debe reportar "missing case" ni referencias muertas en este archivo.

---

## Phase 3 — Quitar los botones manuales del detalle (`turno_detalle_sheet.dart`)

**Archivo:** `lib/features/turnos/presentation/turno_detalle_sheet.dart`

1. L85-90 (`Wrap` de `_EstadoButton`): **eliminar** los botones `Confirmar` y
   `En curso`. Dejar solo:
   ```dart
   _EstadoButton('Cancelar', () => setEstado(EstadoTurno.cancelado)),
   _EstadoButton('No vino', () => setEstado(EstadoTurno.noShow)),
   ```
2. L78 — el título `'Cambiar estado'` sigue siendo válido (2 acciones). *Opcional*:
   renombrar a `'Marcar turno'` para reflejar que ya no es un flujo de estados.
   (Decisión menor; dejar como está salvo que el usuario prefiera el rename.)
3. `_esTerminal` (L163-166): **sin cambios**. `pendiente` sigue siendo el único
   no-terminal, así que los botones aparecen solo para turnos pendientes — correcto.

**Verificación:** abrir el detalle de un turno pendiente muestra exactamente 2 botones
(`Cancelar`, `No vino`) + (si `puedeGestionar`) `Cerrar y cobrar`.

---

## Phase 4 — Reemplazar el color "prestado" de ingresos (`agenda_dia_screen.dart`)

**Archivo:** `lib/features/agenda/presentation/agenda_dia_screen.dart`

- L618: reemplazar `estadoColor(EstadoTurno.enCurso)` (verde `0xFF1D9E75`) por un
  color que NO dependa del enum eliminado. Opciones (elegir una):
  - **(Recomendado)** `scheme.primary` — ya hay `scheme` en scope (L651 usa el patrón); el monto de ingresos hereda el color de marca.
  - O un token verde literal `const Color(0xFF1D9E75)` si se quiere conservar el verde exacto.

**Verificación:** la cabecera del resumen del día sigue mostrando los ingresos con
color de acento; `grep -n "enCurso" lib/features/agenda` → 0 resultados.

---

## Phase 5 — Actualizar datos demo y tests

1. **`lib/dev/seed.dart`**
   - L107: `EstadoTurno.confirmado` → `EstadoTurno.pendiente`.
   - L109: `EstadoTurno.enCurso` → `EstadoTurno.pendiente` (o `EstadoTurno.noShow`
     en uno de ellos para cubrir visualmente el estado "No vino" en la demo).
2. **`test/resumen_dia_test.dart`**
   - L40, L45, L57: reemplazar `EstadoTurno.enCurso` por un estado conservado
     (p. ej. `EstadoTurno.noShow`). Ajustar la aserción `r.porEstado[...]`
     correspondiente al nuevo valor en L45. La semántica del test (conteo por
     estado) se mantiene; solo cambia qué estado se cuenta.

**Verificación:** `flutter test test/resumen_dia_test.dart` pasa.

---

## Phase 6 — Verificación final

1. **Búsqueda de referencias muertas** (deben dar 0 resultados en `lib/` y `test/`):
   ```
   grep -rn "EstadoTurno.confirmado\|EstadoTurno.enCurso\|'confirmado'\|'en_curso'" lib test
   ```
2. **Análisis estático:** `flutter analyze` → sin errores ni warnings nuevos.
   (Los `switch` exhaustivos sobre `EstadoTurno` son la garantía: si quedara un caso
   sin migrar, el compilador lo marca.)
3. **Tests:** `flutter test` → todo verde.
4. **Smoke manual (opcional, con emuladores):** sembrar demo, abrir un turno
   pendiente, marcar "No vino" → el chip pasa a "No vino" y el turno queda terminal
   (sin botones de estado). Cobrar otro turno → pasa a "Completado".

### Tabla de cobertura request → fases
| Requisito del usuario | Fase(s) |
|---|---|
| Eliminar estados que estorban (`confirmado`, `enCurso`) | 1, 2, 3 |
| Conservar "No vino" como marca principal | 3 (botón) + 1, 2 (modelo/UI) |
| Conservar Cancelado y Completado(cobro) | 1, 2 (sin tocar lógica de cobro) |
| No romper agenda/resumen/ficha | 4, 5 |
| Sin migración de datos | 1 (default `_ => pendiente`) |
