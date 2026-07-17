# Decisiones Arquitectónicas

## Por qué se eliminó RBAC (Role-Based Access Control)

### Contexto

Este proyecto fue diseñado para un salón de belleza pequeño con un modelo operativo **single-user, single-tenant**:
- Un único usuario (dueño) maneja todo: agenda, clientes, trabajadores, facturación
- Históricamente, el código implementaba roles (dueño, recepcionista, estilista) pero nunca se usaron en práctica
- La complejidad de autorización no proporciona valor en el caso de uso actual

### La Decisión

**Eliminar roles de autorización (admin/estilista/recepcionista) y mantener solo autenticación (login/logout).**

**Beneficios:**
- Reducción de ~15-20% del código de autenticación
- Navegación y UX más simple (sin condicionales de rol)
- Menos surface de bugs en validación de permisos
- Tests más directos (menos paths de autorización)

**Trade-off:**
- Pierdes granularidad de acceso (pero nunca se usó)
- Si escala a multi-user será costoso re-introducir (ver cómo revertir abajo)

### Tribunal de Decisiones

| Rol | Voto | Razón |
|-----|------|-------|
| Pragmático | ✅ A favor | Menos código = menos bugs, ROI claro |
| Arquitecto | ✅ A favor | Alineado con single-user constraint actual |
| UX/Product | ✅ A favor | Experiencia más fluida, sin rutas protegidas |
| DevOps | ✅ A favor | Menos tests, deployment simple, no RBAC checks |
| Security | ⚠️ Neutral | Pierdes RBAC, pero mantienes autenticación strong |
| Escéptico | ⚠️ Neutral | Si escalas a multi-user será costoso reintroducir |
| Outsider | ⚠️ Neutral | Asume que nunca habrá múltiples usuarios/dispositivos |

**Resultado:** 4 A favor / 4 Neutral → **ADELANTE**

### Referencias a Roles en el Código (Audit Previo a Cambios)

Antes de eliminar, encontramos **100 referencias** en:
- `lib/` (Dart/Flutter): Providers, Guards, UI condicionales, Modelos
- `functions/` (JavaScript): Cloud Function `setUserClaims.js`
- `firestore.rules`: Validación de permisos por rol

**Ubicaciones críticas:**
- `lib/features/auth/application/auth_providers.dart`: 4 providers de rol
- `lib/app/router.dart`: 2 guards de navegación por rol
- `firestore.rules` (líneas 55-102): 4 funciones de validación de rol
- `functions/setUserClaims.js`: Lógica de asignación y validación de roles
- 6+ pantallas con condicionales `if (puedeGestionar)`, `if (esDueno)`, etc.

### Cómo Revertir (Si en el Futuro Necesitas Multi-User)

Ver `docs/RBAC-REMOVAL-NOTES.md` — contiene:
- Backup de funciones de roles antes de eliminación
- Patrones de cómo re-introducir RBAC sin reescribir desde cero
- Archivos críticos que se modificaron y cómo restaurarlos

**Esfuerzo estimado:** 2-3 sprints si necesitas reintroducir completamente.

### Cambios Implementados

| Fase | Componente | Cambio | Estado |
|------|-----------|--------|--------|
| 1 | Documentación | Crear `DECISIONS.md` + auditoría | ✅ En curso |
| 2 | Firestore Rules | Eliminar funciones `isDueno()`, `isRecepcion()`, etc. | ⏳ Pendiente |
| 3 | Router Guards | Eliminar guards de rol | ⏳ Pendiente |
| 4 | Providers | Eliminar `esDuenoProvider`, `isSuperAdminProvider`, etc. | ⏳ Pendiente |
| 5 | Cloud Function | Simplificar `setUserClaims.js` | ⏳ Pendiente |
| 6 | UI Widgets | Remover condicionales de rol | ⏳ Pendiente |
| 7 | Modelos | Eliminar `RolTrabajador` enum, `TenantUser.rol` | ⏳ Pendiente |
| 8 | Testing | Verificación final | ⏳ Pendiente |

### Guardrails

✅ **Cuándo ADELANTE:**
- Single-user, single-tenant es la realidad operativa (confirmado)
- No hay planes de multi-user en roadmap inmediato
- Documentación de reversal está guardada

⚠️ **Si necesitas revertir en el futuro:**
- Backup de código pre-eliminación está en git history
- Instrucciones detalladas en `docs/RBAC-REMOVAL-NOTES.md`

---

**Decisión tomada:** 2026-07-17  
**Estado:** Phase 1 en progreso  
**Próximo paso:** Ejecutar Phase 2 (Firestore Rules migration)
