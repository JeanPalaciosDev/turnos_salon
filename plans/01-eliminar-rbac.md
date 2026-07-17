# Plan 01: Eliminar Sistema de Autorización por Roles (RBAC)

**Decisión:** Eliminar roles (admin, estilista, recepcionista) — mantener solo autenticación  
**Base:** Tribunal de Decisiones, 4 A favor / 4 Neutral — contexto: app single-user/single-tenant  
**Impacto:** Reducción ~15-20% de código de auth, simplificación de navegación, UX más fluida  
**Riesgo Mitigado:** Documentar bien por qué se eliminó, dejar extensibilidad para futuro multi-user

---

## 📋 Phase 0: Documentation Discovery

**Fuentes consultadas:**
- `functions/setUserClaims.js:1-120` — Cloud Function que asigna roles
- `lib/features/auth/data/custom_claims_service.dart:1-100` — Cliente de claims
- `lib/features/auth/application/auth_providers.dart:1-100` — Providers de validación
- `lib/app/router.dart:50-120` — Guards de navegación
- `firestore.rules:40-400` — Reglas de validación por rol
- `lib/shared/models/tenant_user.dart:1-50` — Modelo de usuario
- `lib/features/trabajadores/domain/trabajador.dart` — Enum de roles

**Hallazgos clave:**
1. **3 roles en código:** `dueno`, `recepcion`, `estilista` (+ `super_admin` global)
2. **Almacenamiento:** Custom Claims de Firebase Auth (authoritative) + denormalización en Firestore
3. **Validación en 3 capas:**
   - Firestore Rules (backend enforcement)
   - Router Guards (frontend navigation)
   - Conditional UI (Providers)
4. **Flujo actual:** setUserClaims → Custom Claims → getIdTokenResult() → Providers → UI/Rules
5. **Consumidores de roles:**
   - `router.dart`: 2 guards (`/servicios`, `/trabajadores`, `/usuarios`, `/sistema/*`)
   - `auth_providers.dart`: 4 providers (`esDuenoProvider`, `puedeGestionarTurnosProvider`, `isSuperAdminProvider`, `rolActualProvider`)
   - `firestore.rules`: ~15 checks de autorización
   - 6+ pantallas con condicionales de rol

**Anti-patterns a evitar:**
- ✗ NO dejar hardcodes de "usuario único" — mantener estructura para futures multi-user
- ✗ NO eliminar Custom Claims sin antes limpiar Firestore Rules
- ✗ NO agregar "admin" como estado global en Flutter — mantener role como opcional en token

---

## 🔧 Phase 1: Audit y Documentación de la Decisión

**Qué hacer:**
1. Crear archivo `DECISIONS.md` en raíz del proyecto (documentar por qué se eliminó RBAC)
2. Grep para encontrar todos los usos de "role", "dueno", "recepcion", "estilista" en código
3. Listar todas las pantallas/rutas que actualmente validan por rol
4. Crear archivo de "Breaking Changes" para futuros developers

**Archivos a crear:**
- `DECISIONS.md` — Decisión de arquitectura con contexto
- `docs/RBAC-REMOVAL-NOTES.md` — Notas técnicas para revertir si se necesita

**Verificación:**
```bash
# Contar referencias a roles
grep -r "dueno\|recepcion\|estilista\|esDuenoProvider\|puedeGestionar" lib/ --include="*.dart" | wc -l
# Debe retornar ~40-50 referencias antes de cambios

# Contar referencias en rules
grep -r "isDueno\|isRecepcion\|isEstilista\|userRole()" firestore.rules | wc -l
```

**Documentación:**
```markdown
## Por qué se eliminó RBAC

Este proyecto fue diseñado para un salón pequeño (single-user, single-tenant).
En práctica operativa: un único usuario maneja todo (dueno + recepcion + estilista).

### Decisión
- Eliminar roles admin/estilista/recepcionista
- Mantener autenticación (login/logout)
- Simplificar código: -15-20% en auth layer
- Dejar infraestructura extensible para futuro multi-user (ver Phase 8)

### Razón (Tribunal de Decisiones)
✅ Pragmático: Menos código, menos bugs, ROI claro
✅ Arquitecto: Alineado con single-user constraint
✅ UX/Product: Experiencia más fluida
✅ DevOps: Menos tests, deployment simple
⚠️ Security: Pierdes RBAC, pero mantienes autenticación
⚠️ Escéptico: Si escalas a multi-user será costoso reintroducir
⚠️ Outsider: Asume que nunca habrá múltiples usuarios

### Cómo revertir si se necesita
Ver `docs/RBAC-REMOVAL-NOTES.md` — contiene patrones de cómo re-introducir roles sin reescribir desde cero.
```

**Referencias:**
- Decisión: `tribunal-decisiones` (archivo base)
- Contexto: Usuario = single salon, single-user

---

## 🔐 Phase 2: Migración de Firestore Security Rules

**Qué eliminar:**
1. Funciones helper para validación de roles:
   - `isDueno()` (línea 88-90)
   - `isRecepcionista()` (línea 94-96)
   - `isEstilista()` (línea 100-102)
   - `isSuperAdmin()` (línea 55-57)
2. Todos los checks de rol en reglas (reemplazar por `userInTenant()` solo)

**Patrón ANTES:**
```firestore
allow create: if userInTenant(tenant_id) &&
              (isDueno() || isRecepcionista()) &&
              isTenantActive(tenant_id);
```

**Patrón DESPUÉS:**
```firestore
allow create: if userInTenant(tenant_id) &&
              isTenantActive(tenant_id);
```

**Archivos a modificar:**
- `firestore.rules` líneas 55-102 (eliminar 4 funciones)
- `firestore.rules` líneas 208-400 (reemplazar todos los checks)

**Verificación:**
```bash
# Antes: debe tener isDueno, isRecepcion, isEstilista, isSuperAdmin
grep "isDueno\|isRecepcion\|isEstilista\|isSuperAdmin" firestore.rules

# Después: NO debe haber ninguna de esas funciones
grep "isDueno\|isRecepcion\|isEstilista\|isSuperAdmin" firestore.rules
# Exit code debe ser 1 (no encontrado)
```

**Anti-patterns:**
- ✗ NO eliminar `userInTenant()` o `isTenantActive()` — mantenerlos
- ✗ NO cambiar lógica de multi-tenant — solo eliminar filtros de rol
- ✗ NO dejar checks como `allow read: if true;` — mantener validación de tenant

**Condición para adelante:**
- Firestore Rules compilan sin error (`firebase deploy --only firestore:rules`)
- Todas las colecciones siguen teniendo `userInTenant()` como guard

---

## 🧭 Phase 3: Eliminación de Guards del Router (Flutter)

**Qué eliminar:**
1. `Guard 4` (Dueno-only) en `router.dart` línea 105-108
2. `Guard 5` (Super-admin-only) en `router.dart` línea 112-115
3. Rutas protected: `{'/servicios', '/trabajadores', '/usuarios', '/dashboard', '/sistema/tenants', '/audit-logs'}`

**Cómo:**
- Remover las condiciones `if (ref.read(esDuenoProvider) == false)`
- Remover las condiciones `if ((ref.read(isSuperAdminProvider).value ?? false) == false)`
- Consolidar rutas: todo lo que era "dueno-only" o "super-admin-only" ahora es público (solo requiere login)

**Patrón ANTES:**
```dart
if (loggedIn &&
    rutasSoloDueno.contains(state.matchedLocation) &&
    ref.read(esDuenoProvider) == false) {
  return '/agenda';  // Redirigir si no es dueno
}
```

**Patrón DESPUÉS:**
```dart
// Simplemente: si loggedIn, permite acceso
if (!loggedIn) {
  return '/login';
}
```

**Archivos a modificar:**
- `lib/app/router.dart` línea 34-37 (eliminar sets de rutas protected)
- `lib/app/router.dart` línea 105-115 (eliminar Guards 4 y 5)
- `lib/app/router.dart` línea 52-119 (simplificar goRouterBuilder)

**Verificación:**
```bash
# Antes: debe haber esDuenoProvider y isSuperAdminProvider en router
grep "esDuenoProvider\|isSuperAdminProvider" lib/app/router.dart

# Después: NO debe haber esas referencias
grep "esDuenoProvider\|isSuperAdminProvider" lib/app/router.dart
# Exit code 1
```

**Anti-patterns:**
- ✗ NO eliminar `loggedIn` check — autenticación debe permanecer
- ✗ NO dejar rutas sin protección de login
- ✗ NO comentar el código viejo — eliminarlo por completo

**Condición para adelante:**
- App compila sin errores
- Todas las rutas autenticadas son accesibles (verificar en preview)

---

## 👥 Phase 4: Simplificación de Providers de Auth

**Qué eliminar:**
1. `esDuenoProvider` (línea 30-32)
2. `puedeGestionarTurnosProvider` (línea 35-38) — reemplazar por `true` o eliminar
3. `isSuperAdminProvider` (línea 68-81)
4. `rolActualProvider` (línea 25-27) — opcional, depende de si se usa para UI

**Qué MANTENER:**
- `usuarioActualProvider` — sigue siendo necesario para identidad del usuario
- `tenantIdProvider` — sigue siendo necesario para multi-tenant

**Archivos a modificar:**
- `lib/features/auth/application/auth_providers.dart` línea 25-81

**Verificación en pantallas que consumen estos providers:**
```bash
# Encontrar todos los usos
grep -r "esDuenoProvider\|puedeGestionarTurnosProvider\|isSuperAdminProvider" lib/features/ --include="*.dart"

# Debe retornar CERO después de Phase 6
```

**Anti-patterns:**
- ✗ NO eliminar providers sin primero reemplazar sus usos en pantallas
- ✗ NO perder acceso a `usuarioActualProvider` — mantener siempre

**Condición para adelante:**
- No hay referencias a `esDuenoProvider`, `isSuperAdminProvider`, `puedeGestionarTurnosProvider` en el código
- `usuarioActualProvider` y `tenantIdProvider` siguen funcionando

---

## ☁️ Phase 5: Refactor del Cloud Function setUserClaims

**Qué cambiar:**
1. Eliminar validación de roles (`['dueno', 'recepcion', 'estilista']`)
2. Eliminar campo `role` de customClaims — mantener solo `tenant_id`
3. Simplificar función (quitarle ~50 líneas)

**Patrón ANTES:**
```javascript
const customClaims = {
  tenant_id: tenantId,
  role: role,  // ← ELIMINAR
};
```

**Patrón DESPUÉS:**
```javascript
const customClaims = {
  tenant_id: tenantId,  // ← Solo tenant_id
};
```

**Archivo a modificar:**
- `functions/setUserClaims.js` línea 34-120

**Cambios específicos:**
- Línea 68: eliminar validación `['dueno', 'recepcion', 'estilista']`
- Línea 97: remover check de `super_admin` (o simplificar a "solo el mismo tenant puede asignar")
- Línea 105-108: `customClaims` = `{ tenant_id }`
- Línea 110: llamar a `setCustomUserClaims(uid, customClaims)`

**Verificación:**
```bash
# Antes: debe tener validación de roles
grep "dueno.*recepcion.*estilista" functions/setUserClaims.js

# Después: NO debe haber validación de esos roles específicos
grep -E "\['dueno'.*'recepcion'.*'estilista'\]" functions/setUserClaims.js
# Exit code 1
```

**Anti-patterns:**
- ✗ NO eliminar `tenant_id` del Custom Claims — es crítico para multi-tenant
- ✗ NO dejar lógica de "super_admin" hardcodeada sin migración plan

**Condición para adelante:**
- Cloud Function redeploy exitoso
- `getIdTokenResult()` en Flutter solo contiene `tenant_id` en claims

---

## 🎨 Phase 6: Eliminación de UI Condicional por Roles

**Qué buscar y eliminar:**
1. Condicionales `if (puedeGestionar)`
2. Condicionales `if (esDueno)`
3. Condicionales `if (isSuperAdmin)`
4. Menús que muestran/ocultan items según rol

**Pantallas afectadas:**
- `turno_detalle_sheet.dart` línea 34
- `clientes_screen.dart` línea 20, 63
- `agenda_dia_screen.dart` línea 70
- `audit_log_screen.dart` línea 64
- `dashboard_screen.dart` línea 131
- `mas_screen.dart` línea 15-16
- `role_change_dialog.dart` — ELIMINAR por completo (widget solo para cambiar roles)

**Patrón ANTES:**
```dart
final puedeGestionar = ref.watch(puedeGestionarTurnosProvider);
if (puedeGestionar) {
  // Mostrar botón de guardar
} else {
  // Solo lectura
}
```

**Patrón DESPUÉS:**
```dart
// Mostrar botón siempre (no hay restricción por rol)
```

**Archivos a eliminar completamente:**
- `lib/features/admin/presentation/role_change_dialog.dart`

**Verificación:**
```bash
# Encontrar todos los condicionales de rol
grep -r "if.*puedeGestionar\|if.*esDueno\|if.*isSuperAdmin" lib/features/ --include="*.dart" | wc -l

# Después: debe retornar 0
```

**Anti-patterns:**
- ✗ NO dejar código comentado "// this was role-based"
- ✗ NO mantener la lógica de "solo lectura" si se elimina la restricción

**Condición para adelante:**
- Todas las pantallas muestran todas las funciones (no hay restricciones visuales)
- `role_change_dialog.dart` no existe
- No hay referencias a providers eliminados

---

## 📦 Phase 7: Limpieza de Modelos y Enums

**Qué eliminar:**
1. `RolTrabajador` enum (línea 2 en `trabajador.dart`)
2. Campo `rol: String` en `TenantUser` model (línea 30 en `tenant_user.dart`)
3. `CustomClaimsService` class — si solo se usaba para asignar roles

**Archivos a modificar:**
- `lib/features/trabajadores/domain/trabajador.dart` línea 2
- `lib/shared/models/tenant_user.dart` línea 30

**Verificación:**
```bash
# Antes: debe haber enum RolTrabajador
grep "enum RolTrabajador" lib/features/trabajadores/domain/trabajador.dart

# Después: NO debe haber RolTrabajador
grep "enum RolTrabajador" lib/features/trabajadores/domain/trabajador.dart
# Exit code 1

# Contar referencias a TenantUser.rol
grep -r "\.rol\|TenantUser.*rol" lib/ --include="*.dart" | wc -l
# Después debe retornar 0
```

**Anti-patterns:**
- ✗ NO eliminar otros fields de `TenantUser` (nombre, email, etc.)
- ✗ NO tocar modelos de Trabajador (estilista, recepcionista como datos, no roles)

**Condición para adelante:**
- No hay referencias a `RolTrabajador` enum
- `TenantUser.rol` no existe
- App compila sin errores

---

## ✅ Phase 8: Verificación Final y Testing

**Checklist de verificación:**

1. **Código compila sin errores**
   ```bash
   flutter analyze
   dart analyze lib/
   ```

2. **No hay referencias a roles en codebase**
   ```bash
   grep -r "dueno\|recepcion\|estilista\|esDuenoProvider\|puedeGestionar\|isSuperAdmin\|RolTrabajador" lib/ functions/ --include="*.dart" --include="*.js"
   # Debe retornar solo comentarios o referencias en DECISIONS.md
   ```

3. **Firestore Rules válidas**
   ```bash
   firebase deploy --only firestore:rules
   # Exit code 0
   ```

4. **App funciona en preview**
   ```bash
   flutter run
   # Verificar:
   # - Login funciona
   # - Acceso a /servicios, /trabajadores, /usuarios sin restricciones
   # - Agenda se muestra
   # - Turnos se pueden crear/editar
   ```

5. **Tests de autenticación pasan**
   ```bash
   flutter test test/features/auth/
   # Todos los tests deben pasar
   ```

6. **Documentación actualizada**
   - ✅ `DECISIONS.md` existe y explica por qué se eliminó RBAC
   - ✅ `docs/RBAC-REMOVAL-NOTES.md` existe con notas de re-introducción
   - ✅ README.md actualizado (si tenía notas sobre roles)

**Pruebas funcionales:**
- [ ] Crear nuevo usuario (sin asignar rol)
- [ ] Pantalla de usuarios muestra todos (sin filtrado por rol)
- [ ] Calendario/agenda muestra todos los turnos
- [ ] Servicios/trabajadores se pueden editar
- [ ] Clientes se pueden crear/editar
- [ ] Reportes/auditoría funciona (si aplica)

**Veredicto final:**
- ✅ Si todo pasa → PLAN COMPLETADO
- ❌ Si algo falla → Volver a la fase correspondiente

---

## 📊 Resumen de Cambios

| Componente | Antes | Después | Impacto |
|-----------|-------|---------|---------|
| **Firestore Rules** | ~15 checks de rol | 1 check (`userInTenant`) | -80% complejidad |
| **Router Guards** | 2 guards por rol | 1 guard (solo login) | -50% código |
| **Providers** | 4 providers de auth | 2 providers (user, tenant) | -50% providers |
| **Cloud Function** | ~120 líneas | ~70 líneas | -40% código |
| **UI Widgets** | Condicionales por rol | UI flat | Más simple |
| **Modelos** | `RolTrabajador` enum | Eliminado | Cleanup |

**Líneas de código eliminadas:** ~400-500 líneas  
**Complejidad ciclomática reducida:** ~30-40%  
**Tiempo de test execution:** -15% (menos paths de autorización)

---

## 🚨 Condiciones y Guardrails

### ✅ Cuándo ADELANTE
- Single-user, single-tenant es la realidad operativa (confirmado)
- No hay planes de multi-user en roadmap
- Documentación de reversal está en `docs/RBAC-REMOVAL-NOTES.md`

### ⚠️ Si en el futuro necesitas multi-user
- Re-introducir `CustomClaimsService` (guardar backup de Phase 5 antes de eliminar)
- Re-agregar `role` field a `TenantUser` con migration
- Copiar Firestore Rules helpers de git history
- Tomar ~2-3 sprints (no es "simple")

### 📝 Documentación de reversal (guardar ANTES de eliminar)
```
# Copiar antes de Phase 5:
functions/setUserClaims.js (completo)
lib/features/auth/data/custom_claims_service.dart
lib/features/auth/application/auth_providers.dart

# Guardar en: docs/RBAC-REMOVAL-NOTES.md (git history)
```

---

## 🔗 Links a decisiones y contexto

- **Tribunal de Decisiones:** `/tribunal-decisiones` (prompt usado para análisis)
- **Contexto del negocio:** Salón pequeño, single-user, single-device
- **Restricciones:** Single-tenant, single operador
- **Visión a futuro:** Si escala a múltiples sucursales, volver a introducir RBAC

---

**Plan creado:** 2026-07-17  
**Estado:** Ready for Phase 1  
**Próximo paso:** Crear `DECISIONS.md` y comenzar audit de referencias a roles
