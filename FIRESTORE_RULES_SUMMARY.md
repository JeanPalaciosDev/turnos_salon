# Firestore Security Rules - Phase 7

**Status**: Production-Ready  
**Last Updated**: 2026-07-13  
**Version**: 1.0

---

## 📋 Overview

This document describes the comprehensive Firestore security rules for the multi-tenant salon management system. The rules enforce:

1. **Multi-tenant data isolation** - Users from different tenants cannot access each other's data
2. **Role-based access control** - Three tenant roles with different permissions (dueno, recepcionista, estilista)
3. **Super-admin global access** - Platform admin can manage all tenants
4. **Suspended tenant blocking** - Immediate access denial when tenant is suspended
5. **Immutable audit trails** - System logs cannot be modified
6. **Backend-only system operations** - Critical changes (tenant creation, user management) via Cloud Functions only

---

## 🔐 Helper Functions

All helper functions are defined at the top of `firestore.rules` and are the building blocks for all security rules.

### Authentication & User Info

| Function | Returns | Purpose |
|----------|---------|---------|
| `signedIn()` | boolean | Is user authenticated in Firebase? |
| `userTenantId()` | string \| null | Extract tenant_id from custom claims |
| `userRole()` | string \| null | Extract role from custom claims |
| `isValidRole()` | boolean | Is role one of: dueno, recepcionista, estilista, super_admin? |

### Authorization Checks

| Function | Returns | Purpose |
|----------|---------|---------|
| `isSuperAdmin()` | boolean | Is user a platform super-admin? (role == 'super_admin') |
| `isDueno()` | boolean | Is user an owner/manager? (role == 'dueno') |
| `isRecepcionista()` | boolean | Is user a receptionist? (role == 'recepcionista') |
| `isEstilista()` | boolean | Is user a stylist? (role == 'estilista') |

### Tenant Access

| Function | Parameters | Returns | Purpose |
|----------|-----------|---------|---------|
| `userInTenant(tenantId)` | tenantId: string | boolean | Is user a member of this tenant? |
| `belongsToTenant(tenantId)` | tenantId: string | boolean | Alias for `userInTenant()` |
| `isTenantActive(tenantId)` | tenantId: string | boolean | Is tenant in 'activo' state? (Reads _platform/tenants/{tenantId}.estado) |

### Important Notes

- **`isTenantActive()` performs a Firestore read** - Every call reads the tenant document to check estado. This costs 1 read unit per call.
  - **Future optimization**: Store tenant estado in custom claims to avoid the read cost
  - **Current cost**: Each user action that checks `isTenantActive()` = 1 read
  - **Alternative**: Implement background task to update custom claims when tenant is suspended

---

## 📁 Collection Structure & Access Rules

### _platform/* Collections

**Access Tier**: Super-admin only (global platform data)

Users from **ANY** tenant cannot read `_platform/` collections. Regular tenant users will receive "Permission denied" if they attempt access.

---

#### `_platform/tenants/{tenant_id}`

**Document Example**:
```json
{
  "name": "Salón Luna",
  "estado": "activo",  // or "suspendido" / "deleted"
  "owner_email": "owner@example.com",
  "created_at": "2024-01-15T10:00:00Z",
  "updated_at": "2024-07-13T15:30:00Z",
  "branding": {
    "color_primary": "#FF6B35",
    "color_secondary": "#004E89",
    "logo_url": "https://...",
    "force_theme": "light"
  }
}
```

**Access Rules**:

| Operation | Allowed | Why |
|-----------|---------|-----|
| Read | Super-admin only | Platform admin needs to view all tenant configs |
| Create | Backend only (Cloud Function) | Prevents rogue tenant creation |
| Update | Backend only (Cloud Function) | Prevents unauthorized tenant state changes |
| Delete | Backend only (Cloud Function) | Prevents accidental tenant deletion |

**Suspended Tenant Behavior**:
- When `estado` changes to `"suspendido"`, all users in that tenant are **immediately blocked**
- Cost: 1 Firestore read per user operation to check `isTenantActive()`
- User sees: "Tu salón ha sido suspendido" (via client app error handling)

---

#### `_platform/usuarios/{tenant_id}/{user_id}`

**Document Example**:
```json
{
  "email": "employee@salon.com",
  "rol": "recepcionista",  // or "dueno" / "estilista"
  "activo": true,
  "created_at": "2024-02-20T08:00:00Z",
  "updated_at": "2024-07-13T10:00:00Z"
}
```

**Access Rules**:

| Operation | Allowed | Conditions |
|-----------|---------|-----------|
| Read | Super-admin | Full access to all users |
| Read | User themselves | Own user document only (request.auth.uid == user_id) |
| Create | Backend only | Cloud Function / Admin SDK |
| Update | Backend only | Cloud Function / Admin SDK |
| Delete | Backend only | Cloud Function / Admin SDK |

**Purpose**:
- Super-admin manages all users across all tenants
- Users can verify their own email, role, and active status
- Authoritative source for user information system-wide

---

#### `_platform/audit_logs/{log_id}`

**Document Example**:
```json
{
  "accion": "suspender_tenant",
  "super_admin_email": "admin@platform.com",
  "tenant_id": "salon-luna-xyz",
  "detalles": {
    "razon": "suspension due to non-payment"
  },
  "timestamp": "2024-07-13T14:00:00Z"
}
```

**Access Rules**:

| Operation | Allowed | Why |
|-----------|---------|-----|
| Read | Super-admin only | Compliance and debugging |
| Create | Backend only (Cloud Function) | Automatic logging on system actions |
| Update | Never | Immutable audit trail |
| Delete | Never | Cannot tamper with audit history |

**Logged Actions** (examples):
- `crear_tenant` - New tenant creation
- `suspender_tenant` - Tenant suspension
- `reactivar_tenant` - Tenant reactivation
- `crear_usuario` - New user creation
- `cambiar_rol_usuario` - User role change
- `cambiar_password_usuario` - Password change

---

### tenants/{tenant_id}/* Collections

**Access Tier**: Tenant members only (tenant-scoped data)

All collections under `tenants/{tenant_id}/` require:
1. User belongs to tenant: `userInTenant(tenant_id)`
2. Tenant is active: `isTenantActive(tenant_id)`
3. User has appropriate role for the operation

---

#### `tenants/{tenant_id}` (Tenant Config)

**Access Rules**:

| Operation | Allowed | Conditions |
|-----------|---------|-----------|
| Read | All tenant members | User in tenant AND tenant active |
| Create | Never | Backend only |
| Update | Never | Backend only |
| Delete | Never | Backend only |

**Purpose**: Allows users to read salon settings, name, branding, etc.

---

#### `tenants/{tenant_id}/servicios/{servicio_id}`

**Document Example**:
```json
{
  "nombre": "Corte y Tinte",
  "descripcion": "Corte de cabello con servicio de tinte",
  "duracion_minutos": 90,
  "precio": 85.00,
  "activo": true,
  "created_at": "2024-01-15T10:00:00Z",
  "updated_at": "2024-07-13T10:00:00Z"
}
```

**Access Rules**:

| Operation | User Role | Allowed | Conditions |
|-----------|-----------|---------|-----------|
| Read | All | ✅ Yes | In tenant AND tenant active |
| Read | Dueno | ✅ Yes | |
| Read | Recepcionista | ✅ Yes | |
| Read | Estilista | ✅ Yes | |
| Create | Dueno | ✅ Yes | In tenant AND tenant active |
| Create | Recepcionista | ❌ No | |
| Create | Estilista | ❌ No | |
| Update | Dueno | ✅ Yes | In tenant AND tenant active |
| Update | Other | ❌ No | |
| Delete | Dueno | ✅ Yes | In tenant AND tenant active |
| Delete | Other | ❌ No | |

**Business Rules**:
- Only owner/manager (dueno) maintains the service catalog
- All staff can view services (needed for scheduling)
- Cannot delete service if turnos still reference it (validate in app)

---

#### `tenants/{tenant_id}/trabajadores/{trabajador_id}`

**Document Example**:
```json
{
  "nombre": "María González",
  "rol": "estilista",  // or "recepcionista" / "dueno"
  "activo": true,
  "horario": {
    "lunes_inicio": "09:00",
    "lunes_fin": "18:00",
    "martes_inicio": "09:00",
    "martes_fin": "18:00",
    "miercoles_inicio": null,
    "miercoles_fin": null,
    "jueves_inicio": "09:00",
    "jueves_fin": "18:00",
    "viernes_inicio": "09:00",
    "viernes_fin": "18:00",
    "sabado_inicio": "10:00",
    "sabado_fin": "16:00",
    "domingo_inicio": null,
    "domingo_fin": null
  },
  "created_at": "2024-01-15T10:00:00Z",
  "updated_at": "2024-07-13T10:00:00Z"
}
```

**Access Rules**:

| Operation | Dueno | Recepcionista | Estilista | Conditions |
|-----------|-------|---------------|-----------|-----------|
| Read | ✅ | ✅ | ✅ | In tenant AND tenant active |
| Create | ✅ | ❌ | ❌ | In tenant AND tenant active |
| Update | ✅ | ❌ | ❌ | In tenant AND tenant active |
| Delete | ✅ | ❌ | ❌ | In tenant AND tenant active |

**Business Rules**:
- Only owner (dueno) manages staff roster
- All staff can view (needed for scheduling turnos)

**Subcollection: ausencias**

```
tenants/{tenant_id}/trabajadores/{trabajador_id}/ausencias/{ausencia_id}
```

**Document Example**:
```json
{
  "tipo": "vacacion",  // or "enfermedad" / "licencia"
  "fecha_inicio": "2024-08-01",
  "fecha_fin": "2024-08-10",
  "notas": "Summer vacation",
  "created_at": "2024-07-13T10:00:00Z"
}
```

**Access Rules**: Same as parent (trabajador)
- Read: All tenant members
- Create/Update/Delete: Dueno only

---

#### `tenants/{tenant_id}/clientes/{cliente_id}`

**Document Example**:
```json
{
  "nombre": "Ana López",
  "email": "ana@example.com",
  "telefono": "+34 666 555 444",
  "direccion": "Calle Principal 123, Madrid",
  "preferencias": {
    "tipo_corte": "bob_corto",
    "color_favorito": "castaño",
    "notas": "Alérgica a ciertos productos"
  },
  "activo": true,
  "created_at": "2024-02-15T14:00:00Z",
  "updated_at": "2024-07-13T10:00:00Z"
}
```

**Access Rules**:

| Operation | Dueno | Recepcionista | Estilista | Conditions |
|-----------|-------|---------------|-----------|-----------|
| Read | ✅ | ✅ | ✅ | In tenant AND tenant active |
| Create | ✅ | ✅ | ❌ | In tenant AND tenant active |
| Update | ✅ | ✅ | ❌ | In tenant AND tenant active |
| Delete | ✅ | ❌ | ❌ | In tenant AND tenant active |

**Business Rules**:
- Recepcionista adds clients and updates contact info
- Only dueno can delete (data retention policy)
- Estilista can view client info and preferences (read-only)

---

#### `tenants/{tenant_id}/turnos/{turno_id}`

**Document Example**:
```json
{
  "cliente_id": "cliente-123",
  "trabajador_id": "trabajador-456",
  "servicio_id": "servicio-789",
  "fecha": "2024-07-20",
  "hora_inicio": "2024-07-20T10:00:00Z",
  "duracion_minutos": 90,
  "estado": "confirmado",  // or "cancelado" / "completado" / "no_asistio"
  "notas": "Client prefers afternoon time",
  "precio": 85.00,
  "created_at": "2024-07-10T08:00:00Z",
  "updated_at": "2024-07-13T15:30:00Z"
}
```

**Access Rules**:

| Operation | Dueno | Recepcionista | Estilista | Conditions |
|-----------|-------|---------------|-----------|-----------|
| Read | ✅ | ✅ | ✅ | In tenant AND tenant active |
| Create | ✅ | ✅ | ❌ | In tenant AND tenant active |
| Update | ✅ | ✅ | ❌ | In tenant AND tenant active |
| Delete | ✅ | ❌ | ❌ | In tenant AND tenant active |

**Business Rules**:
- Recepcionista handles day-to-day scheduling (create/update turnos)
- Estilista can view their assigned turnos (read-only for visibility)
- Status changes: Created as "confirmado" → "completado" when finished → "cancelado" if cancelled
- Never delete turnos (use cancelado status instead for audit trail)
- Only dueno can delete (emergency corrections)

**Turnos Read Optimization** (Future):
- Consider filtering to return only turnos for logged-in estilista:
  - `trabajador_id == userDocInTenant.id`
  - Validate on client-side after reading

---

#### `tenants/{tenant_id}/usuarios/{user_id}`

**Access Rules**:

| Operation | Allowed | Conditions |
|-----------|---------|-----------|
| Read | Tenant members | In tenant AND tenant active |
| Create | Backend only | Cloud Function / Admin SDK |
| Update | Backend only | Cloud Function / Admin SDK |
| Delete | Backend only | Cloud Function / Admin SDK |

**Purpose**: Allows users to see who else has access to the tenant (team roster visibility).

---

## 🚫 Cross-Tenant Access Prevention

The rules explicitly prevent users from accessing data from other tenants.

**Example Scenario**:
- User A belongs to `tenant-1`
- User A tries to read `tenants/tenant-2/turnos/turno-xyz`

**What Happens**:
1. Rule checks: `userInTenant('tenant-2')`
2. User's custom claim: `tenant_id = 'tenant-1'`
3. Condition fails: `'tenant-1' != 'tenant-2'`
4. Result: **Permission Denied** ❌

**Every collection under `tenants/{tenant_id}/` includes the check**:
```javascript
if userInTenant(tenant_id) && isTenantActive(tenant_id)
```

This prevents cross-tenant data leaks at multiple levels.

---

## ⏸️ Suspended Tenant Blocking

When a tenant is suspended (`estado: "suspendido"`), all users in that tenant are immediately blocked from reading/writing data.

**How It Works**:

1. **Super-admin suspends tenant** via Cloud Function:
   ```
   _platform/tenants/{tenant_id}.estado = "suspendido"
   ```

2. **Next user action** in that tenant:
   - Rule checks: `isTenantActive(tenant_id)`
   - Reads: `_platform/tenants/{tenant_id}.estado`
   - Value is now: `"suspendido"` (not `"activo"`)
   - Condition fails
   - Result: **Permission Denied** ❌

3. **User sees error** in app:
   - App catches `FirebaseException: permission-denied`
   - Displays: "Tu salón ha sido suspendido. Contacta al administrador."

**Cost Consideration**:
- Each user action reads the tenant document (1 read unit)
- **Alternative**: Store `estado` in custom claims (requires admin update)
- **Future optimization**: Use custom claims to avoid the read on every operation

---

## 🔄 Backend-Only Operations

Some operations are **intentionally blocked on the client** and must go through backend (Cloud Functions).

### Why Block Client Writes?

1. **Data Consistency**: Ensure operations follow business logic
2. **Audit Trail**: All system actions logged automatically
3. **Cascading Changes**: Related data updates (e.g., create user → set custom claims → log action)
4. **Security**: Prevents abuse (e.g., creating super-admins from client)

### Blocked Operations

| Operation | Collection | Why Blocked |
|-----------|-----------|-----------|
| Create Tenant | `_platform/tenants` | System-level change, must trigger setup |
| Update Tenant | `_platform/tenants` | Estado changes critical to access control |
| Create User | `_platform/usuarios` | Must set up Firebase Auth + custom claims |
| Update User | `_platform/usuarios` | Role changes affect access immediately |
| Delete User | `_platform/usuarios` | Complex cleanup (remove from tenant, revoke auth) |
| Write Audit Log | `_platform/audit_logs` | Backend auto-logs all system actions |
| Update Tenant Config | `tenants/{tenant_id}` | Operational settings, require super-admin approval |

---

## 🔍 Request Validation

The current rules focus on **access control** (who can access). Future enhancements can add **data validation** (what format is allowed).

### Validation Opportunities

| Collection | Field | Validation |
|-----------|-------|-----------|
| turnos | `estado` | Must be one of: confirmado, cancelado, completado, no_asistio |
| turnos | `duracion_minutos` | Must be > 0 and ≤ 240 |
| turnos | `fecha` | Must be future date (for new turnos) |
| servicios | `precio` | Must be ≥ 0 |
| clientes | `email` | Optional but must be valid format if present |
| trabajadores | `rol` | Must be one of: dueno, recepcionista, estilista |

**Implementation**:
```javascript
// Example: In match /servicios/{servicio_id}
allow create: if ... && request.resource.data.precio >= 0;
```

---

## 🧪 Manual Testing Checklist

### Test 1: Super-Admin Access
```
User Role: super_admin
Test: Read _platform/tenants/
Expected: ✅ Can read all tenants
```

### Test 2: Regular User Blocked from Platform
```
User Role: recepcionista in tenant-A
Test: Read _platform/tenants/
Expected: ❌ Permission denied
```

### Test 3: Cross-Tenant Prevention
```
User Role: recepcionista in tenant-A
Test: Read tenants/tenant-B/turnos/
Expected: ❌ Permission denied
```

### Test 4: Suspended Tenant Blocking
```
User Role: dueno in tenant-suspended
Tenant Estado: suspendido
Test: Read tenants/tenant-suspended/turnos/
Expected: ❌ Permission denied (Tu salón ha sido suspendido)
```

### Test 5: Role-Based Access - Estilista Cannot Create
```
User Role: estilista in tenant-A
Test: Create tenants/tenant-A/turnos/
Expected: ❌ Permission denied
```

### Test 6: Role-Based Access - Recepcionista Can Create
```
User Role: recepcionista in tenant-A
Test: Create tenants/tenant-A/turnos/
Expected: ✅ Can create turno
```

### Test 7: Audit Log Immutable
```
User Role: super_admin
Test: Delete _platform/audit_logs/log-xyz/
Expected: ❌ Permission denied (deletes never allowed)
```

### Test 8: User Reading Own Data
```
User Role: dueno in tenant-A
Test: Read _platform/usuarios/tenant-A/uid-xyz/ (own document)
Expected: ✅ Can read own user doc
```

### Test 9: User Cannot Read Other Users in Platform
```
User Role: dueno in tenant-A
Test: Read _platform/usuarios/tenant-A/uid-different/
Expected: ❌ Permission denied (only super-admin or self)
```

### Test 10: Tenant Active Check Required
```
User Role: recepcionista in tenant-A
Tenant Active: true
Test: Read tenants/tenant-A/servicios/
Expected: ✅ Can read
Then:
Tenant Active: false (suspendido)
Test: Read tenants/tenant-A/servicios/
Expected: ❌ Permission denied
```

---

## 📝 Troubleshooting Guide

### "Permission denied" When Reading Tenant Data

**Possible Causes**:

1. **User not in tenant**:
   - Check custom claim: `request.auth.token.tenant_id`
   - Verify matches path: `tenants/{tenant_id}/...`
   - Fix: Admin must assign user to tenant

2. **Tenant is suspended**:
   - Check `_platform/tenants/{tenant_id}.estado`
   - If `"suspendido"`, all access blocked
   - Fix: Admin must reactivate tenant

3. **User not authenticated**:
   - Check Firebase Auth session
   - Verify user token not expired
   - Fix: User must log in again

---

### "Permission denied" When Creating Turno

**Possible Causes**:

1. **User role is estilista**:
   - Estilistas can only READ, not CREATE
   - Fix: Recepcionista or dueno must create
   - Future: Estilista can create if rule changed

2. **Tenant suspended**:
   - All writes blocked to suspended tenant
   - Fix: Admin reactivates tenant

3. **Missing custom claims**:
   - User custom claims not set on Firebase Auth
   - Fix: Super-admin recreates user with proper claims

---

### "Permission denied" When Writing to Audit Logs

**Expected Behavior**:
- Client writes to `_platform/audit_logs/` always fail
- Backend (Cloud Functions) auto-logs system actions
- You should NOT see audit logs written from client app

**Solution**:
- Ensure actions go through Cloud Functions
- Example: Suspending tenant calls Cloud Function, which logs the action
- Audit logs should only appear in backups/exports, not from client code

---

### Admin Cannot Create New Tenant

**Possible Causes**:

1. **Trying direct Firestore write**:
   - `_platform/tenants/` writes blocked (rule: `allow write: if false`)
   - Fix: Use Cloud Function endpoint

2. **Cloud Function has different rules**:
   - Cloud Functions use Admin SDK, bypass rules
   - Verify Cloud Function code has proper validation
   - Check Cloud Logs for errors

---

## 🚀 Deployment

### Prerequisites
- Firebase CLI installed: `npm install -g firebase-tools`
- Logged in: `firebase login`
- Project configured: `firebase use turnos-salon-163b5`

### Deploy Rules
```bash
# Validate syntax
firebase firestore:describe-schema

# Deploy to production
firebase deploy --only firestore:rules

# Rollback if issues
firebase rollback
```

### Verify Deployment
```bash
# Check current rules on server
firebase firestore:describe-schema

# View rules in Firebase Console
# → Firestore → Rules → View / Edit
```

---

## 📋 Custom Claims Setup

Users need custom claims set in Firebase Auth for rules to work.

### Super-Admin Custom Claims
```json
{
  "role": "super_admin"
}
```

### Tenant User Custom Claims
```json
{
  "tenant_id": "salon-luna-xyz",
  "role": "dueno"  // or "recepcionista" / "estilista"
}
```

### Setting Custom Claims (Backend)
```javascript
// Node.js / Firebase Admin SDK
const admin = require('firebase-admin');

await admin.auth().setCustomUserClaims(uid, {
  tenant_id: tenantId,
  role: 'recepcionista'
});

// Refresh token
await admin.auth().revokeRefreshTokens(uid);
```

### Verifying Custom Claims
```javascript
// Client-side (after login)
const token = await user.getIdTokenResult();
console.log(token.claims.tenant_id);
console.log(token.claims.role);
```

---

## 💡 Best Practices

1. **Always check tenant_active** before displaying data to users
   - Rule does this automatically, but app should handle error gracefully

2. **Never trust client-side validation alone**
   - Rules enforce access control, but app should validate data format

3. **Log all failed access attempts** in your monitoring
   - Watch for patterns of rule violations (possible attacks)

4. **Keep audit logs forever**
   - Never delete logs (rules prevent it)
   - Use for compliance and debugging

5. **Test rules in development first**
   - Deploy to staging Firestore project
   - Run manual tests before production push

6. **Document any custom rules you add**
   - Future developers need to understand the security model
   - Include comments explaining "why" not just "what"

7. **Review rules quarterly**
   - New features may require new collections
   - Ensure no unintended access leaks

---

## 📚 References

- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/start)
- [Firebase Auth Custom Claims](https://firebase.google.com/docs/auth/admin-setup)
- [Cloud Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- Project Architecture: `plans/00-arquitectura-dos-apps.md` (Phase 7)

---

## 🔗 Related Files

- **Rules**: `D:\Work\turnos_salon\firestore.rules`
- **Architecture**: `D:\Work\turnos_salon\plans\00-arquitectura-dos-apps.md`
- **Cloud Functions**: `D:\Work\turnos_salon\functions/` (backend operations)

---

**End of Documentation**
