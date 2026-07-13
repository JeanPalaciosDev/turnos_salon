# Plan — Cerrar los pendientes actuales del sistema

> Análisis de estado: se revisaron los 5 planes en `plans/` y el `git status` actual.
> Los planes `camino-critico-login-deploy.md`, `diseno-ui-movil.md`, `fase-2-auth.md`
> y `vista-semanal-agenda.md` están **completamente implementados** en el código
> (login, guards por rol, tema claro/oscuro, `NavigationBar`, vista semanal y diaria
> enriquecida — todos los archivos que describen existen y funcionan).
>
> El único plan con trabajo abierto es `01-simplificar-estados-turno.md`. Su código
> **ya está escrito** en el working tree (no committeado) y **ya se verificó en esta
> sesión**: `flutter analyze` → sin issues, `flutter test` → 27/27 pasan. Lo que falta
> no es codear, es **cerrar el ciclo**: confirmar el alcance de un cambio no
> planificado que viajó en el mismo diff, y commitear.

## Estado verificado (Fase 0 — ya hecho en esta sesión)

Comandos ejecutados y resultado:
- `flutter analyze` → **"No issues found!" (20.9s)**
- `flutter test` → **"All tests passed!" (27/27)**

`git diff --stat` muestra 7 archivos modificados. Todos los cambios de
`01-simplificar-estados-turno.md` (fases 1-5) están presentes y coinciden con el plan:
- `lib/features/turnos/domain/turno.dart` — enum reducido a 4 estados. ✅
- `lib/features/turnos/presentation/estado_ui.dart` — `estadoColor`/`estadoLabel` sin `confirmado`/`enCurso`. ✅
- `lib/features/turnos/presentation/turno_detalle_sheet.dart` — botones reducidos a `Cancelar`/`No vino`. ✅
- `lib/features/agenda/presentation/agenda_dia_screen.dart` — color de ingresos ya no depende de `EstadoTurno.enCurso`. ✅
- `lib/dev/seed.dart` + `test/resumen_dia_test.dart` — datos demo y tests migrados. ✅

**Hallazgo — cambio fuera del alcance del plan 01** (no es un error, pero necesita
decisión del usuario antes de commitear):
1. `lib/features/turnos/presentation/turno_detalle_sheet.dart` — se agregó un botón
   **"Reactivar turno"** (`_esReversible`) que no estaba en el plan 01. Permite volver
   `cancelado`/`noShow` → `pendiente`. Es una función nueva, no una limpieza.
2. `lib/main.dart` — se agregó `_descartarSesionRancia()`: al arrancar, fuerza refresh
   del ID token y hace `signOut()` si el refresh token quedó inválido (excepto en
   fallos de red). Tampoco estaba en el plan 01 ni en ningún otro plan de `plans/`.

Ninguno de los dos rompe tests ni analyze, pero son features nuevas sin plan propio
(sin Fase 0/verificación documentada) mezcladas con una limpieza de estados.

### Anti-patrones a evitar en este cierre
- ❌ No commitear los 7 archivos como "un solo cambio de limpieza" sin que el usuario
  confirme que quiere incluir "Reactivar turno" y el fix de sesión rancia en el mismo
  commit (o separarlos).
- ❌ No revertir `_descartarSesionRancia` ni `_esReversible` sin preguntar — pueden ser
  intencionales del usuario en esta sesión de trabajo, solo no están documentados.
- ❌ No tocar los otros 4 planes de `plans/`: están implementados y verificados, no
  requieren más trabajo.

---

## Fase 1 — Confirmar alcance con el usuario

Antes de tocar nada, preguntar (una sola vez, opciones concretas):
1. ¿El botón "Reactivar turno" y el fix de sesión rancia en `main.dart` son
   intencionales y deben quedar? (sí / no / solo uno de los dos)
2. Si quedan: ¿van en el mismo commit que la simplificación de estados, o en
   commits separados (uno por feature, siguiendo el estilo de commits del repo)?

**Verificación:** respuesta registrada antes de pasar a Fase 2.

---

## Fase 2 — Commit(s)

Según la respuesta de Fase 1:
- **Si todo va junto:** un commit que cubra "simplificar estados de turno + reactivar
  turno + fix de sesión rancia al arrancar".
- **Si van separados:** 2-3 commits atómicos, cada uno con su propio mensaje
  (estado de turnos / reactivar turno / sesión rancia), en el orden en que aparecen
  en el diff para minimizar conflictos.

No usar `git add -A`; agregar archivos por nombre explícito (7 archivos conocidos).

**Verificación:** `git status` → working tree limpio; `git log --oneline -3` muestra
los commits nuevos con mensajes que reflejan el "por qué", no el "qué".

---

## Fase 3 — Verificación final (repetir tras el commit)

1. `flutter analyze` → sin issues (ya confirmado antes del commit, repetir solo si
   hubo cambios adicionales en Fase 1/2).
2. `flutter test` → 27/27 verdes.
3. `git status` limpio, `plans/01-simplificar-estados-turno.md` puede quedar en el
   repo como registro histórico (o moverse a una carpeta `plans/done/` si el usuario
   tiene esa convención — no se detectó tal carpeta en este repo, así que por defecto
   se deja donde está).

### Tabla de cobertura request → fases
| Pendiente detectado | Fase |
|---|---|
| Plan 01 implementado pero no committeado | 2 |
| Cambios fuera de alcance sin decisión del usuario | 1 |
| Confirmar que analyze/test siguen verdes tras commit | 3 |
| Otros 4 planes de `plans/` | Ninguna — ya completos, sin acción |
