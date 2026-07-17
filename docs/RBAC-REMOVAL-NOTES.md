# RBAC Removal Technical Notes

**Date:** 2026-07-17  
**Status:** Phase 1 - Audit Complete  
**Impact:** 100 role-related references found in codebase

---

## Overview

This document serves as a technical reference for the RBAC (Role-Based Access Control) removal project and provides instructions for reverting if needed in the future.

### Critical Files Being Modified

| File | Path | Current Lines | Changes | Phase |
|------|------|---|---------|-------|
| Firestore Rules | `firestore.rules` | 55-102 (functions), 200-400 (checks) | Remove: `isDueno()`, `isRecepcionista()`, `isEstilista()`, `isSuperAdmin()` | Phase 2 |
| Router Guards | `lib/app/router.dart` | 34-37, 105-115 | Remove: role-based route guards | Phase 3 |
| Auth Providers | `lib/features/auth/application/auth_providers.dart` | 25-81 | Remove: `esDuenoProvider`, `puedeGestionarTurnosProvider`, `isSuperAdminProvider`, `rolActualProvider` | Phase 4 |
| Cloud Function | `functions/setUserClaims.js` | 34-128 | Remove: role validation, simplify to tenant_id only | Phase 5 |
| UI Widgets | Multiple (see section below) | Various | Remove: conditional role checks, `role_change_dialog.dart` | Phase 6 |
| Models | `lib/features/trabajadores/domain/trabajador.dart`, `lib/shared/models/tenant_user.dart` | Various | Remove: `RolTrabajador` enum, `TenantUser.rol` field | Phase 7 |

---

## Current Role System (Before Removal)

### 1. Custom Claims Structure (Firebase Auth)

**Current format:**
```json
{
  "tenant_id": "salon_001",
  "role": "dueno" | "recepcionista" | "estilista"
}
```

**After removal:**
```json
{
  "tenant_id": "salon_001"
}
```

### 2. Firestore Rules - Role Functions (Lines 53-102)

**BEFORE (keep as reference):**
```firestore
/// Check if user is a super_admin.
function isSuperAdmin() {
  return signedIn() && userRole() == 'super_admin';
}

/// Check if user belongs to a specific tenant.
function userInTenant(tenantId) {
  return signedIn() && userTenantId() == tenantId;
}

/// Check if user has role 'dueno' (owner/manager).
function isDueno() {
  return userRole() == 'dueno';
}

/// Check if user has role 'recepcionista' (receptionist).
function isRecepcionista() {
  return userRole() == 'recepcionista';
}

/// Check if user has role 'estilista' (stylist).
function isEstilista() {
  return userRole() == 'estilista';
}
```

**AFTER (keep only tenant validation):**
```firestore
/// Check if user is authenticated.
function signedIn() {
  return request.auth != null;
}

/// Extract tenant_id from Firebase Auth Custom Claims.
function userTenantId() {
  return request.auth.token.tenant_id;
}

/// Check if user belongs to a specific tenant.
function userInTenant(tenantId) {
  return signedIn() && userTenantId() == tenantId;
}

/// Check if a tenant is active.
function isTenantActive(tenantId) {
  return get(/databases/$(database)/documents/_platform/tenants/$(tenantId)).data.estado == 'activo';
}
```

### 3. Flutter Auth Providers (Lines 25-81)

**BEFORE (keep as reference):**
```dart
/// Rol del usuario actual (sincrónico); null mientras carga o sin sesión.
final rolActualProvider = Provider<RolTrabajador?>(
  (ref) => ref.watch(usuarioActualProvider).value?.rol,
);

/// True si el usuario actual es dueño.
final esDuenoProvider = Provider<bool>(
  (ref) => ref.watch(rolActualProvider) == RolTrabajador.dueno,
);

/// True si el usuario actual puede gestionar turnos (dueño o recepción).
final puedeGestionarTurnosProvider = Provider<bool>((ref) {
  final rol = ref.watch(rolActualProvider);
  return rol == RolTrabajador.dueno || rol == RolTrabajador.recepcion;
});

/// True si el usuario actual es super_admin (desde Custom Claims).
final isSuperAdminProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream<bool>.value(false);
  }

  return Stream.fromFuture(
    user.getIdTokenResult(),
  ).map((idToken) {
    final claims = idToken.claims;
    if (claims == null) return false;
    return (claims['role'] as String?) == 'super_admin';
  }).handleError((_) => false);
});
```

**AFTER (keep only user and tenant info):**
```dart
/// Usuario actual resuelto: según el uid del [authStateProvider], observa
/// `usuarios/{uid}`; emite null si no hay sesión.
final usuarioActualProvider = StreamProvider<Usuario?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream<Usuario?>.value(null);
  }
  return ref.watch(usuariosRepositoryProvider).watchUsuario(user.uid);
});

/// tenant_id del usuario actual (desde Custom Claims).
final tenantIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream<String?>.value(null);
  }

  return Stream.fromFuture(
    user.getIdTokenResult(),
  ).map((idToken) {
    final claims = idToken.claims;
    if (claims == null) return null;
    return claims['tenant_id'] as String?;
  }).handleError((_) => null);
});
```

### 4. Cloud Function - setUserClaims.js (Lines 34-128)

**BEFORE (keep as reference):**
```javascript
const setUserClaims = functions.https.onRequest(async (request, response) => {
  // ... CORS and method validation ...

  try {
    const { uid, tenant_id, role } = request.body;

    // Validate required fields
    if (!uid || !tenant_id || !role) {
      return response.status(400).json({
        success: false,
        error: 'Missing required fields: uid, tenant_id, role',
      });
    }

    // Validate role
    const validRoles = ['dueno', 'recepcionista', 'estilista'];
    if (!validRoles.includes(role)) {
      return response.status(400).json({
        success: false,
        error: `Invalid role. Must be one of: ${validRoles.join(', ')}`,
      });
    }

    // Verify caller is super_admin
    // ... token verification ...

    // Set custom claims on user
    const customClaims = {
      tenant_id,
      role,
    };

    await admin.auth().setCustomUserClaims(uid, customClaims);

    return response.status(200).json({
      success: true,
      message: 'Custom claims set successfully',
      data: {
        uid,
        claims: customClaims,
      },
    });
  } catch (error) {
    // ... error handling ...
  }
});
```

**AFTER (simplified):**
```javascript
const setUserClaims = functions.https.onRequest(async (request, response) => {
  // ... CORS and method validation ...

  try {
    const { uid, tenant_id } = request.body;

    // Validate required fields
    if (!uid || !tenant_id) {
      return response.status(400).json({
        success: false,
        error: 'Missing required fields: uid, tenant_id',
      });
    }

    // Verify caller (optional: keep admin check or simplify)
    // ... token verification ...

    // Set custom claims on user (only tenant_id)
    const customClaims = {
      tenant_id,
    };

    await admin.auth().setCustomUserClaims(uid, customClaims);

    return response.status(200).json({
      success: true,
      message: 'Custom claims set successfully',
      data: {
        uid,
        claims: customClaims,
      },
    });
  } catch (error) {
    // ... error handling ...
  }
});
```

---

## Audit Results

### Reference Count (Pre-removal)

```bash
Command: grep -r "dueno\|recepcion\|estilista\|esDuenoProvider\|puedeGestionar" lib/ functions/ --include="*.dart" --include="*.js" | wc -l
Result: 100 references
```

### Distribution of References

To find exact locations:
```bash
# Dart files in lib/
grep -r "dueno\|recepcion\|estilista\|esDuenoProvider\|puedeGestionar" lib/ --include="*.dart"

# JavaScript in functions/
grep -r "dueno\|recepcion\|estilista\|role" functions/ --include="*.js"

# Firestore rules
grep -r "isDueno\|isRecepcion\|isEstilista\|userRole" firestore.rules
```

### Affected Screens/Widgets

Files containing UI conditionals (to be simplified in Phase 6):
- `turno_detalle_sheet.dart` - line ~34
- `clientes_screen.dart` - lines ~20, ~63
- `agenda_dia_screen.dart` - line ~70
- `audit_log_screen.dart` - line ~64
- `dashboard_screen.dart` - line ~131
- `mas_screen.dart` - lines ~15-16
- `role_change_dialog.dart` - **ELIMINATE ENTIRELY**

---

## How to Re-introduce RBAC (If Needed)

### Prerequisites

1. Git history contains the original implementations (commit before Phase 1)
2. This document is available as reference

### Step-by-step Reversal

#### Step 1: Restore Custom Claims Structure

Add `role` field back to Custom Claims in Firebase Auth:

```bash
git log --oneline | grep "Phase 1\|Phase 5"
# Find the commit before Phase 1
git show <commit>:functions/setUserClaims.js > temp_setUserClaims.js
```

Restore:
- `tenant_id` ✅ (kept)
- `role` → add back (was removed in Phase 5)

#### Step 2: Restore Firestore Rules Functions

From `firestore.rules` (commit before Phase 2):

```bash
git show <pre-phase-2-commit>:firestore.rules | head -102 > temp_rules_backup.txt
```

Restore functions:
- `isDueno()` - lines 88-90
- `isRecepcionista()` - lines 94-96
- `isEstilista()` - lines 100-102
- `userRole()` - lines 49-51

Then restore role checks in permission rules (lines 200-400).

#### Step 3: Restore Router Guards

From `lib/app/router.dart` (commit before Phase 3):

```bash
git show <pre-phase-3-commit>:lib/app/router.dart > temp_router.dart
```

Restore:
- `esDuenoProvider` checks in route guards
- `isSuperAdminProvider` checks
- Route protection lists

#### Step 4: Restore Auth Providers

From `lib/features/auth/application/auth_providers.dart`:

```bash
git show <pre-phase-4-commit>:lib/features/auth/application/auth_providers.dart > temp_providers.dart
```

Restore all 4 providers:
- `rolActualProvider`
- `esDuenoProvider`
- `puedeGestionarTurnosProvider`
- `isSuperAdminProvider`

#### Step 5: Restore UI Conditionals

From individual widget files (commit before Phase 6):

```bash
git log --oneline -- lib/features/*/presentation/*.dart | grep "Phase 6"
git show <pre-phase-6-commit>:lib/features/turno/presentation/turno_detalle_sheet.dart | grep -A5 "puedeGestionar"
```

Restore `if (puedeGestionar)` and `if (esDueno)` conditionals in each screen.

Re-create `role_change_dialog.dart` with original implementation.

#### Step 6: Restore Models

From `lib/shared/models/tenant_user.dart` and `lib/features/trabajadores/domain/trabajador.dart`:

```bash
git show <pre-phase-7-commit>:lib/shared/models/tenant_user.dart | grep "rol"
git show <pre-phase-7-commit>:lib/features/trabajadores/domain/trabajador.dart | grep "enum RolTrabajador"
```

Restore:
- `RolTrabajador` enum
- `TenantUser.rol` field

### Estimated Effort

- **Time:** 2-3 sprints (depends on test suite)
- **Complexity:** Medium-High (multiple layers to coordinate)
- **Risk:** Low (original code in git history; clear rollback path)

---

## Reference Implementation Backups

### Complete setUserClaims.js (Phase 5 backup)

File: `functions/setUserClaims.js` (lines 1-130, complete function)

Key sections:
- Line 68: `validRoles = ['dueno', 'recepcionista', 'estilista']`
- Line 96-97: `callerRole` check for 'super_admin'
- Lines 105-108: `customClaims = { tenant_id, role }`

### Complete auth_providers.dart (Phase 4 backup)

File: `lib/features/auth/application/auth_providers.dart` (lines 1-82, complete)

Key sections:
- Lines 25-27: `rolActualProvider`
- Lines 30-32: `esDuenoProvider`
- Lines 35-38: `puedeGestionarTurnosProvider`
- Lines 68-81: `isSuperAdminProvider`

### Complete firestore.rules (Phase 2 backup)

File: `firestore.rules` (lines 1-500+, complete)

Key sections:
- Lines 49-51: `userRole()` function
- Lines 55-57: `isSuperAdmin()` function
- Lines 88-102: `isDueno()`, `isRecepcionista()`, `isEstilista()` functions
- Lines 200-400: Role checks in collection rules

---

## Verification Checklist Before RBAC Removal

- [ ] All 100 references audited and documented
- [ ] Backup of Phase 0-1 code in git
- [ ] DECISIONS.md created and reviewed
- [ ] Team has access to this document
- [ ] Decision tribunal approved (4/8 A favor/Neutral)

## Post-Removal Verification Checklist

- [ ] Phase 8 testing complete
- [ ] No references remain (grep returns 0)
- [ ] Firestore Rules deploy successfully
- [ ] Flutter app compiles without errors
- [ ] All user flows work without role-based gates
- [ ] Documentation updated in README.md

---

## Emergency Rollback

If critical issues emerge after removal:

```bash
# Identify the last working commit before Phase 1
git log --oneline | head -20

# Option 1: Revert entire RBAC removal (if all phases merged)
git revert --no-edit <first-phase-1-commit>..<last-phase-8-commit>

# Option 2: Cherry-pick from history (selective restore)
git cherry-pick <backup-commit-before-phase1>

# Re-deploy:
firebase deploy
flutter pub get && flutter analyze
```

---

**Document version:** 1.0  
**Last updated:** 2026-07-17  
**Created by:** RBAC Removal - Phase 1 Audit
