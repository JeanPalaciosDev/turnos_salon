# Plan — Ampliar el seed para probar el Dashboard

> Objetivo: el seed actual (`lib/dev/seed.dart`) solo tiene 4 turnos (hoy + ayer),
> insuficiente para ver rankings "top 5" con datos interesantes en las 8 secciones
> del Dashboard (Fase 6, `plans/03-dashboard.md`). Se amplía a un volumen que
> produzca variedad real en servicios/trabajadores/días/horarios, sin tocar la
> lógica de la app.

## Decisiones (por defecto, alcance acotado y reversible — no requieren confirmación)
- Rango: turnos distribuidos en los **últimos 10 días** (incluye hoy), suficiente
  para ver "Días con más turnos/ingreso" con más de un dato y sin hacer el seed
  ilegible.
- Todos los turnos nuevos con **`cobro` completo** cuando `estado == completado`
  (si no, no alimentan las métricas de ingreso — el mismo invariante que ya usa
  `ResumenDia`/`DashboardMetrics`).
- Se reusan los 3 trabajadores y los 5 servicios existentes (no se agregan
  catálogos nuevos — eso es un ítem aparte ya anotado en la nota del proyecto,
  fuera de este plan).
- Se reusan los 4 clientes existentes (ciclando entre ellos), no hace falta
  agregar clientes nuevos para este objetivo.

### Fuera de alcance
- No se agregan servicios/trabajadores/clientes nuevos al catálogo.
- No se toca `DashboardMetrics`, los providers, ni la pantalla — esta fase es
  solo datos.
- No se cambia el guard de idempotencia por-colección (`servicios` no vacía →
  no reseedea) — ver advertencia de Fase 0 sobre cómo probarlo.

---

## Fase 0 — Contexto verificado

**Archivo:** `lib/dev/seed.dart` (leído completo).

- El guard de idempotencia (`seed.dart:29-30`) chequea si `servicios` ya tiene
  documentos; si sí, **hace early-return y NO vuelve a correr el bloque de
  turnos**. Esto significa que **si el emulador ya tiene datos sembrados de una
  corrida anterior, agregar turnos nuevos a este archivo no los agrega solo con
  hacer hot-reload** — hace falta un emulador con estado limpio (sin
  `--import` de una sesión previa, o borrar los datos) para que el seed
  ampliado se ejecute de punta a punta.
- Helpers existentes a reusar tal cual (no reinventar):
  - `_turno(id, fecha, horaInicio, trabId, trabNombre, cliId, cliNombre, servicios, estado, {cobro, fechaCobro})` (`seed.dart:212-241`) — firma exacta, calcula `finEstimado` solo.
  - `_svc(id, nombre, dur)` (`seed.dart:209-210`).
  - `_fmtFecha(DateTime)` (`seed.dart:245-246`) para construir fechas de días pasados: `_fmtFecha(DateTime.now().subtract(const Duration(days: N)))`.
- Modelo `Cobro`/`LineaCobro` (`lib/features/turnos/domain/turno.dart`) — mismo
  patrón que el turno `t0` ya sembrado (líneas con `monto` real, `total` =
  suma − `descuento`).
- IDs de trabajadores/servicios/clientes disponibles (ya en `seed.dart`):
  trabajadores `ana`/`marta`/`luis`; servicios `corte`/`tinte`/`peinado`/`manicura`/`barba`;
  clientes `lucia`/`sofia`/`diego`/`valen`.

### Anti-patrones a evitar
- ❌ No inventar un nuevo helper de fecha — usar `_fmtFecha`/`DateTime.now().subtract`.
- ❌ No poner `cobro` en turnos `pendiente`/`cancelado`/`noShow` (rompe el
  invariante que usan `ResumenDia` y `DashboardMetrics`: ingreso solo si
  `completado`).
- ❌ No usar IDs de trabajador/servicio/cliente que no existan en el seed (los
  providers no fallarían silenciosamente pero las métricas quedarían huérfanas
  de nombre).
- ❌ No romper la agrupación de solapamiento ya demostrada por `t1`/`t2` (no
  tocar esos dos turnos).

---

## Fase 1 — Agregar turnos de días anteriores

**Archivo:** `lib/dev/seed.dart`

1. Agregar una lista `_turnosHistoricos` (o extender la lista `turnos` existente
   en `seedEmulatorIfEmpty`, `seed.dart:105-127`) con **~20-25 turnos nuevos**
   repartidos en los últimos 10 días (día -1 a -9, más el `t0` de ayer que ya
   existe), variando deliberadamente:
   - **Trabajador**: alternar `ana`/`marta`/`luis` (dar a `luis` algún turno
     también, hoy solo tiene rol recepción en catálogo pero puede atender
     turnos igual que un estilista para efectos de datos demo — si no
     corresponde al negocio, usar solo `ana`/`marta` y dejar nota).
   - **Servicio**: usar los 5 servicios variando combinaciones (algunos turnos
     con 1 servicio, otros con 2), para que "Servicios más solicitados" tenga
     un ranking real (ej. `corte` debe repetirse más que `manicura`).
   - **Hora de inicio**: variar entre `09:00`, `10:30`, `13:00`, `15:00`,
     `17:30`, `19:00` para poblar "Horarios con más turnos/ingreso" en más de
     una franja.
   - **Estado**: mayoría `completado` (con `cobro`), pero incluir 2-3
     `cancelado`/`noShow` mezclados (sin `cobro`) para que el dashboard también
     muestre que esos turnos cuentan en "conteo" pero no en "ingreso" — mismo
     comportamiento que ya cubre `dashboard_metrics_test.dart`.
   - **Cliente**: ciclar entre los 4 existentes.
   - **Montos de cobro**: usar el `precio_referencia` del servicio como base
     del `monto` de cada línea (coherente con el negocio: el monto real ronda
     la referencia), sin descuento en la mayoría, descuento ocasional en 2-3
     turnos.
2. IDs de turno nuevos: continuar la numeración (`t4`, `t5`, … `tN`) para no
   colisionar con `t0`-`t3` ya existentes.
3. Los turnos nuevos se agregan al **mismo `batch`** ya usado en
   `seedEmulatorIfEmpty` (antes de `await batch.commit()`, `seed.dart:132`) —
   no crear un batch aparte.

**Verificación:**
- `flutter analyze` limpio.
- Lectura manual del archivo: contar que cada uno de los 5 servicios y los 3
  trabajadores aparecen en al menos 2 turnos `completado`, y que hay turnos en
  al menos 4 franjas horarias distintas y 4 días distintos (para que el "top 5"
  del dashboard no quede vacío ni trivial).

**Guards anti-patrón:** no dejar `cobro` en estados no-`completado`; no reusar
IDs de turno ya existentes (`t0`-`t3`).

---

## Fase 2 — Verificación final

1. **Anti-patrón grep:**
   ```
   grep -n "EstadoTurno.completado" lib/dev/seed.dart   # cada match debe tener un `cobro:` asociado cerca
   ```
2. `flutter analyze` → sin issues.
3. `flutter test` → todos verdes (el seed no tiene test propio, pero no debe
   romper nada existente).
4. **Smoke manual (requiere emulador con estado limpio — ver advertencia de
   Fase 0):**
   - Arrancar el emulador **sin** datos previos (o borrar/point a un directorio
     nuevo de `--import`), correr la app contra el emulador.
   - Login como `dueno@salon.test` / `salon123` → "Más" → "Dashboard".
   - Confirmar visualmente que las 8 secciones muestran más de una fila con
     valores distintos entre sí (no todo empatado en 1), y que cambiar el
     rango a "Mes anterior"/"Esta semana" y el filtro de trabajador cambia los
     números mostrados.

### Tabla de cobertura request → fases
| Requisito | Fase |
|---|---|
| Ampliar el seed con más turnos/variedad | 1 |
| Poder probar visualmente el Dashboard con datos reales | 1, 2 |
| No romper nada existente (seed actual, tests, analyze) | 2 |
