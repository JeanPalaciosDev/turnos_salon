# TESTING GUIDE - Phase 8: Multi-Tenant System Integration

**Date**: 2026-07-13  
**Version**: 1.0  
**Status**: Ready for Testing  
**Firebase Project**: turnos-salon-163b5

---

## Table of Contents

1. [Pre-Testing Setup](#pre-testing-setup)
2. [End-to-End Flow Tests](#end-to-end-flow-tests)
3. [Manual Testing Procedures](#manual-testing-procedures)
4. [Security Testing](#security-testing)
5. [Error Scenario Testing](#error-scenario-testing)
6. [Performance Testing](#performance-testing)
7. [Audit Trail Verification](#audit-trail-verification)
8. [Debugging & Troubleshooting](#debugging--troubleshooting)
9. [Rollback Procedures](#rollback-procedures)

---

## Pre-Testing Setup

### Prerequisites Checklist

Before beginning any tests, verify all these items are complete:

```
[ ] Firebase Project: turnos-salon-163b5 configured
    - [ ] Project ID verified: turnos-salon-163b5
    - [ ] Firebase CLI installed: `firebase --version`
    - [ ] Authenticated: `firebase login`

[ ] Firestore Rules Deployed
    - [ ] Rules file: firestore.rules (D:\Work\turnos_salon\firestore.rules)
    - [ ] Deploy command: `firebase deploy --only firestore:rules`
    - [ ] Verify in Firebase Console → Firestore → Rules tab

[ ] Cloud Functions Deployed
    - [ ] setUserClaims function: functions/setUserClaims.js
    - [ ] Deploy command: `firebase deploy --only functions`
    - [ ] Verify in Firebase Console → Functions tab
    - [ ] Check function URL and test endpoint

[ ] turnos_admin App Ready
    - [ ] Located at: D:\Work\turnos_admin
    - [ ] Dependencies installed: `flutter pub get`
    - [ ] Compiled: `flutter build apk` (or run on device)
    - [ ] Connected to Firebase project
    - [ ] Super-admin account created and verified

[ ] turnos_salon App Ready
    - [ ] Located at: D:\Work\turnos_salon
    - [ ] Dependencies installed: `flutter pub get`
    - [ ] Compiled: `flutter build apk` (or run on device)
    - [ ] Connected to Firebase project
    - [ ] Firebase config file present

[ ] Firebase Emulator (Optional but Recommended)
    - [ ] Installed: `firebase emulators:start`
    - [ ] Firestore emulator running on localhost:8080
    - [ ] Auth emulator running on localhost:9099
    - [ ] Both apps configured to use emulators

[ ] Test Accounts Available
    - [ ] Super-admin email: [your-super-admin@example.com]
    - [ ] Super-admin password: [secure]
    - [ ] Note: Keep this account secure, used only in APP ADMIN

[ ] Workspace Setup
    - [ ] Firebase Console open: https://console.firebase.google.com
    - [ ] Firestore database tab ready
    - [ ] Cloud Functions tab ready
    - [ ] Authentication tab ready
    - [ ] Text editor for notes and screenshots
```

### Firebase Environment Check

Run these commands to verify setup:

```bash
# Check Firebase project
firebase projects:list
firebase use turnos-salon-163b5

# Check Firestore connection
firebase firestore:indexes:list

# Check deployed rules (if deployed)
firebase firestore:list-backups

# Check Cloud Functions
firebase functions:list

# Check authentication
firebase auth:list
```

### Data Structure Verification

Before testing, verify Firestore structure exists:

1. **Open Firebase Console**
   - Go to: https://console.firebase.google.com
   - Select project: turnos-salon-163b5
   - Navigate to Firestore Database

2. **Verify Collections Exist**
   ```
   _platform/
   ├─ tenants/
   ├─ usuarios/
   └─ audit_logs/
   
   tenants/
   └─ (empty initially, will be populated by tests)
   ```

3. **Check if sample tenant exists**
   - Click: _platform → tenants
   - If empty, first test will create one
   - If exists, note the tenant_id for reference

---

## End-to-End Flow Tests

These are the critical tests that validate the entire system works together.

### Test 1: Create Tenant & Login

**Objective**: Verify tenant creation and user login work end-to-end.

**Test Steps**:

1. **Open turnos_admin app**
   - Launch app on emulator or device
   - Click: "Dashboard" or main screen
   - Verify: You see "Crear Tenant" button (or similar)

2. **Create a test tenant**
   - Click: "Crear Tenant" button
   - Fill form:
     ```
     Nombre Salón: "Salón Test 001"
     Email Dueño: "salon_001_dueno@test.com"
     Contraseña: "Test123!@#"
     Color: "#FF6B9D" (pink)
     ```
   - Click: "Guardar" button
   - Expected: Success message, tenant appears in list

3. **Verify tenant in Firestore**
   - Open Firebase Console
   - Navigate: Firestore → Collections → _platform → tenants
   - Click on the new tenant document
   - Verify fields:
     ```
     name: "Salón Test 001"
     owner_email: "salon_001_dueno@test.com"
     estado: "activo"
     branding.color_primary: "#FF6B9D"
     created_at: [timestamp]
     ```
   - Note: Copy the tenant_id for next steps

4. **Verify user created in Firebase Auth**
   - Open Firebase Console
   - Navigate: Authentication → Users
   - Find user: salon_001_dueno@test.com
   - Verify: User exists and email is verified/pending

5. **Verify custom claims set**
   - In Firebase Console, click on the user
   - Scroll to: "Custom claims"
   - Verify claims:
     ```
     {
       "tenant_id": "[tenant_id_from_step_3]",
       "role": "dueno"
     }
     ```

6. **Login to turnos_salon app with this user**
   - Open turnos_salon app (on same device or different)
   - Go to: Login screen
   - Enter:
     ```
     Email: salon_001_dueno@test.com
     Password: Test123!@#
     ```
   - Click: "Iniciar Sesión"
   - Expected: Login succeeds, redirected to /agenda

7. **Verify app shows tenant branding**
   - Check app header/shell
   - Verify: Shows tenant name "Salón Test 001"
   - Verify: Primary color is pink (#FF6B9D) in buttons, header, etc.

8. **Verify data scoped to tenant**
   - In Firebase Console, navigate: Firestore → Collections → tenants
   - Should see: tenants/{tenant_id}/
   - Check: All data (turnos, clientes, etc.) is under this tenant path
   - Verify: No data under different tenant_id

**Expected Result**: PASS
- Tenant created in _platform/tenants/{tenant_id}
- User created in Firebase Auth with correct custom claims
- User successfully logs in to turnos_salon
- App displays tenant branding
- All data isolated under tenants/{tenant_id}/*

**Failure Handling**:
- If tenant creation fails → Check Cloud Function logs
- If login fails → Check custom claims in Firebase Console
- If branding doesn't show → Check TenantProvider in app code

---

### Test 2: Create Users & Verify Roles

**Objective**: Verify role-based access control works correctly.

**Test Steps**:

1. **In turnos_admin app, go to tenant management**
   - Click: "Salón Test 001" (from Test 1)
   - Expected: Shows tenant details and user list

2. **Create 3 users in the tenant**
   
   **User 1 - Recepcionista**
   - Click: "Agregar Usuario"
   - Fill:
     ```
     Email: recepcionista_001@test.com
     Rol: Recepcionista
     Contraseña: Test123!@#
     ```
   - Click: "Guardar"
   - Expected: Success message
   
   **User 2 - Estilista**
   - Click: "Agregar Usuario"
   - Fill:
     ```
     Email: estilista_001@test.com
     Rol: Estilista
     Contraseña: Test123!@#
     ```
   - Click: "Guardar"
   - Expected: Success message
   
   **User 3 - Another Dueno (optional, for escalation testing)**
   - Click: "Agregar Usuario"
   - Fill:
     ```
     Email: dueno_002@test.com
     Rol: Dueno
     Contraseña: Test123!@#
     ```
   - Click: "Guardar"
   - Expected: Success message

3. **Verify users in Firebase Auth**
   - Open Firebase Console → Authentication → Users
   - Find all three new users
   - Verify: All users exist

4. **Verify custom claims per role**
   - Click on recepcionista_001@test.com
   - Custom claims should be:
     ```
     {
       "tenant_id": "[same as tenant]",
       "role": "recepcionista"
     }
     ```
   - Repeat for estilista and dueno accounts
   - Verify: Each has correct role

5. **Test login for each role**
   - On turnos_salon app, log out (if needed)
   - Login as recepcionista_001@test.com
   - Expected: Login succeeds, sees /agenda
   - Logout
   - Login as estilista_001@test.com
   - Expected: Login succeeds, sees /agenda
   - Logout
   - Login as dueno_002@test.com
   - Expected: Login succeeds, sees /agenda

6. **Verify Firestore Rules enforce role permissions**
   
   **Test 6a - Estilista cannot delete turno**
   - While logged in as estilista_001@test.com
   - Navigate: Agenda → Select a turno (or create one)
   - Look for: "Eliminar" button or delete icon
   - Expected: Button is disabled OR not visible OR shows error "Acceso denegado"
   - If button exists and clickable, attempt delete
   - Expected: Error message in Spanish: "No tienes permisos para eliminar turnos"
   
   **Test 6b - Recepcionista can create turno**
   - While logged in as recepcionista_001@test.com
   - Navigate: Create new turno
   - Fill form: cliente, hora, servicio, etc.
   - Click: "Guardar"
   - Expected: Turno created successfully
   
   **Test 6c - Recepcionista cannot delete turno**
   - While logged in as recepcionista_001@test.com
   - Navigate: Agenda → Select the turno just created
   - Look for: "Eliminar" button
   - Expected: Button disabled OR not visible OR error on click
   
   **Test 6d - Dueno can delete turno**
   - While logged in as dueno_001@test.com (original owner)
   - Navigate: Agenda → Select a turno
   - Look for: "Eliminar" button
   - Expected: Button visible and enabled
   - Click: "Eliminar"
   - Expected: Turno deleted successfully

7. **Verify audit logs created**
   - Open Firebase Console → Firestore → Collections
   - Navigate: _platform → audit_logs
   - Should see logs for:
     - create_user (recepcionista_001@test.com)
     - create_user (estilista_001@test.com)
     - create_user (dueno_002@test.com)
   - Each log should have:
     ```
     acción: "create_user"
     super_admin: "[your-super-admin@example.com]"
     tenant_id: "[same as tenant]"
     detalles: { email, rol, ... }
     timestamp: [when created]
     ```

**Expected Result**: PASS
- All 3 users created and can login
- Custom claims set correctly per role
- Firestore Rules enforce permissions (estilista read-only, recepcionista create, dueno delete)
- Audit logs recorded for each user creation

**Failure Handling**:
- If user creation fails → Check Cloud Function setUserClaims logs
- If role permissions don't work → Check Firestore Rules: roles section
- If audit logs missing → Check if audit log write succeeded in Functions

---

### Test 3: Suspend Tenant & Verify Blocking

**Objective**: Verify suspended tenants are immediately blocked at Firestore Rules level.

**Test Steps**:

1. **In turnos_admin app, suspend the tenant**
   - Click: "Salón Test 001"
   - Look for: "Suspender" button or status toggle
   - Click: "Suspender"
   - Fill (if prompted): Reason = "Testing suspension"
   - Expected: Success message, tenant status changes to "Suspendido"

2. **Verify estado in Firestore**
   - Open Firebase Console → Firestore → _platform → tenants
   - Click: tenant document
   - Verify: estado field changed to "suspendido"

3. **Test logged-in user cannot read data**
   - Keep turnos_salon app logged in as dueno_001@test.com
   - Navigate: /agenda (or try to load any page accessing Firestore)
   - Expected within ~5 seconds:
     - Data doesn't load
     - Error message appears: "Tu salón ha sido suspendido"
     - User is shown logout option
   
   Note: The Firestore Rules check `isTenantActive()` on every read, so access is immediately blocked.

4. **Test logged-out user cannot login**
   - On turnos_salon app, logout (if not already)
   - Go to: Login screen
   - Try to login with dueno_001@test.com
   - Expected: Login fails with error message
     - "Tu salón ha sido suspendido"
     - OR "Usuario o contraseña inválidos" (generic)
     - Contact the admin for more info

5. **In turnos_admin, reactivate the tenant**
   - Click: "Salón Test 001"
   - Click: "Reactivar" button
   - Expected: Success message, status changes back to "Activo"

6. **Verify estado back to activo**
   - Open Firebase Console → Firestore → _platform → tenants
   - Verify: estado = "activo"

7. **Test user can login again**
   - On turnos_salon app, try login again
   - Expected: Login succeeds, redirected to /agenda
   - User can see data normally

8. **Test data is accessible again**
   - In app, navigate to /agenda
   - Expected: Turnos load successfully
   - No error messages

**Expected Result**: PASS
- Suspension blocks all access immediately (Firestore Rules + custom claims validation)
- Users see Spanish error message
- Reactivation restores access
- No data loss during suspension

**Failure Handling**:
- If suspension doesn't block → Check Firestore Rules `isTenantActive()` function
- If error message is in English → Update error strings to Spanish
- If data is lost → Check if soft-delete was used (should not be hard-delete)

---

### Test 4: Multi-Tenant Isolation

**Objective**: Verify users cannot access data from other tenants.

**Test Steps**:

1. **Create a second tenant in turnos_admin**
   - Click: "Crear Tenant"
   - Fill:
     ```
     Nombre Salón: "Salón Test 002"
     Email Dueño: "salon_002_dueno@test.com"
     Contraseña: Test123!@#
     Color: "#00B8D4" (cyan)
     ```
   - Click: "Guardar"
   - Expected: Success, second tenant created
   - Note: Copy tenant_id_2

2. **Create a turno in Salón Test 001**
   - Login to turnos_salon as dueno_001@test.com
   - Navigate: /agenda
   - Create a new turno (or use existing)
   - Note the turno details and ID
   - Example: turno_id = "turno_001", cliente = "Juan Pérez"

3. **Create user in Salón Test 002**
   - In turnos_admin, click "Salón Test 002"
   - Create new user:
     ```
     Email: salon_002_dueno@test.com
     Rol: Dueno
     Contraseña: Test123!@#
     ```
   - Expected: User created

4. **Login to turnos_salon as Salón Test 002 user**
   - On turnos_salon app, logout
   - Login as: salon_002_dueno@test.com
   - Expected: Login succeeds, sees "Salón Test 002" in header

5. **Try to access Salón Test 001's data via URL tampering (optional, advanced test)**
   - In app source or browser developer tools:
   - Try to access: /turnos?tenant_id=tenant_id_1
   - Expected: Firestore Rules block, returns empty or error
   - User should not see any of Salón Test 001's turnos

6. **Verify actual data isolation in Firestore**
   - Open Firebase Console → Firestore → tenants
   - Navigate: tenants/tenant_id_1/turnos
   - Verify: Contains turno_001
   - Navigate: tenants/tenant_id_2/turnos
   - Verify: Empty or contains only tenant_2 data
   - No overlap

7. **Verify audit logs are separate**
   - Open Firebase Console → _platform → audit_logs
   - Filter or view logs:
     - Logs for tenant_id_1 should only show actions by tenant_id_1 users
     - Logs for tenant_id_2 should only show actions by tenant_id_2 users
     - No cross-tenant audit entries

8. **Test: Create turno in Salon 002, verify isolated**
   - While logged in as salon_002_dueno@test.com
   - Create a new turno
   - Verify it appears in /agenda
   - Navigate: Firebase Console → tenants/tenant_id_2/turnos
   - Verify: New turno exists in correct tenant collection

**Expected Result**: PASS
- Salón Test 002 user cannot see Salón Test 001's data
- All data is scoped to correct tenant collection
- Audit logs show no cross-tenant access
- Firestore Rules enforce isolation

**Failure Handling**:
- If cross-tenant access possible → Check Firestore Rules `userInTenant()` calls
- If data mixed in collections → Check app code's `tenant_id` filtering
- If audit logs mixed → Check Cloud Function audit logging

---

### Test 5: Soft Delete & Recovery

**Objective**: Verify soft-deleted tenants are not hard-deleted and can be recovered.

**Test Steps**:

1. **In turnos_admin, soft-delete the tenant**
   - Create a new temporary tenant (or use Salón Test 002)
   - Click: Tenant name
   - Look for: "Eliminar" button (soft-delete, not permanent delete)
   - Click: "Eliminar"
   - Confirm dialog
   - Expected: Success message, tenant "deleted" (estado = "deleted")

2. **Verify tenant still exists in Firestore**
   - Open Firebase Console → Firestore → _platform → tenants
   - Find the deleted tenant
   - Verify: Document still exists
   - Verify: estado field = "deleted"
   - Verify: All other data intact (name, owner_email, branding, etc.)
   - Note: Hard deletion would have removed the document completely

3. **Verify users from deleted tenant cannot login**
   - On turnos_salon app, try to login as salon_002_dueno@test.com
   - Expected: Login fails, error message
     - "Tu salón ha sido eliminado" or "Salón no encontrado"
   - Users should not be able to access

4. **Verify data is preserved**
   - Open Firebase Console → Firestore → tenants/tenant_id_2/
   - Verify: turnos, clientes, etc. still exist
   - Data not deleted, only tenant marked as deleted

5. **In turnos_admin, reactivate (recover) the tenant**
   - Click: "Salón Test 002" (or filter by "deleted")
   - Look for: "Reactivar" or "Recuperar" button
   - Click: "Reactivar"
   - Expected: Success message, estado changes back to "activo"

6. **Verify data recovery**
   - Open Firebase Console → Firestore → _platform → tenants
   - Find tenant, verify: estado = "activo"
   - Verify: All data still there (turnos, clientes, etc.)

7. **Verify users can login again**
   - On turnos_salon app, try login as salon_002_dueno@test.com
   - Expected: Login succeeds
   - Verify: Can access /agenda and see all previous data

**Expected Result**: PASS
- Tenant marked as deleted (estado = "deleted")
- Document not hard-deleted from Firestore
- Users cannot login to deleted tenant
- All data preserved and recoverable
- Reactivation restores full access

**Failure Handling**:
- If tenant hard-deleted → Check soft-delete implementation in turnos_admin
- If data lost → Verify Cloud Function doesn't hard-delete related collections
- If users can still login → Check login validation for deleted tenants

---

## Manual Testing Procedures

### Regression Testing (Existing Features)

Run these tests to ensure existing features still work after multi-tenant refactoring:

```
[ ] Existing agenda screen loads
    - Open turnos_salon app
    - Login with tenant user
    - Navigate to /agenda
    - Expected: Shows calendar or list of turnos
    
[ ] Can create turno (local to tenant)
    - Click: "Crear Turno" or + button
    - Fill: Cliente, hora, servicio, duración
    - Click: "Guardar"
    - Expected: Turno created, appears in agenda
    
[ ] Can update turno
    - Click on existing turno
    - Edit: Change hora or cliente
    - Click: "Guardar"
    - Expected: Turno updated, changes reflected immediately
    
[ ] Can delete turno (if dueno role)
    - While logged in as dueno
    - Click on turno
    - Click: "Eliminar"
    - Confirm: Click "Sí" in confirmation dialog
    - Expected: Turno deleted, removed from agenda
    
[ ] Can create cliente
    - Click: "Clientes" or management screen
    - Click: "Crear Cliente"
    - Fill: Nombre, teléfono, email
    - Click: "Guardar"
    - Expected: Cliente created, appears in list
    
[ ] Can update cliente
    - Click on existing cliente
    - Edit: Change teléfono or email
    - Click: "Guardar"
    - Expected: Cliente updated
    
[ ] Filters/search still work
    - Navigate: /agenda
    - Try: Filter by date, filter by cliente
    - Expected: Filters work, results update
    
[ ] Offline mode works
    - Open turnos_salon app
    - Enable airplane mode or disable network
    - Navigate: /agenda
    - Expected: Cached data shows (if previously loaded)
    - Editing offline: Changes queued, synced when online
```

### Security Testing

Test these security vectors to ensure they cannot be bypassed:

```
[ ] Cannot manually bypass Firestore Rules (curl/Postman)
    - Open Postman or curl
    - Try to query: tenants/other-tenant/turnos
    - Without proper Authorization header
    - Expected: Request denied with permission error
    - Signature of error: "Missing or insufficient permissions"
    
[ ] Cannot create Auth user without admin
    - In turnos_salon app (client)
    - Look for: Sign-up button
    - Expected: No sign-up button
    - Cannot create users from client app
    - Users must be created via turnos_admin only
    
[ ] Cannot modify audit logs via client
    - Try to write to: _platform/audit_logs/{log_id}
    - With Firebase SDK from turnos_salon app
    - Expected: Permission denied
    - Audit logs are backend-only (Cloud Functions)
    
[ ] Cannot create turno for different tenant_id
    - While logged in as tenant_1 user
    - Try to create turno with tenant_id = tenant_2
    - In Firestore Rules: check will fail
    - Expected: Permission denied or error
    
[ ] Cannot escalate privileges (estilista to dueno)
    - Try to modify custom claims on your own user
    - Use Firebase SDK to call setCustomUserClaims
    - Expected: Permission denied
    - Custom claims only set by Cloud Function (admin SDK)
    
[ ] Cannot read _platform/tenants/ (non-admin)
    - While logged in as regular tenant user
    - Try to read: _platform/tenants
    - Expected: Permission denied
    - Only super_admin can access _platform collections
    
[ ] Token expiration handled gracefully
    - Force token to expire (in development mode)
    - Try to make request to Firestore
    - Expected: Auto re-login or error message
    - Should not crash app or show raw error
```

---

## Error Scenario Testing

Test these error cases to verify handling is correct:

### Network Errors

```
[ ] Connection lost during login → Retry works
    - Start login process
    - During login, disable network
    - Expected: Error dialog with "Reintentar" button
    - Enable network, click "Reintentar"
    - Expected: Login succeeds
    
[ ] Connection lost while viewing agenda → Cached data shows
    - Load /agenda with network enabled
    - Verify: Turnos load
    - Disable network
    - Navigate away and back to /agenda
    - Expected: Cached data shows (if Riverpod/Hive caching enabled)
    
[ ] Connection lost during turno creation → Queue/retry appears
    - Start creating a new turno
    - During save, disable network
    - Expected: Error or "offline" indicator
    - Enable network
    - Expected: Offline changes synced or "Reintentar" option
```

### Permission Errors

```
[ ] Estilista tries to delete turno → Error shown in Spanish
    - Login as estilista user
    - Try to delete turno (manually or via UI)
    - Expected: Error message in Spanish
    - Example: "No tienes permisos para eliminar turnos"
    
[ ] User tries to access suspended tenant → Error shown
    - Suspend tenant (see Test 3)
    - Try to access any page requiring Firestore read
    - Expected: Error message in Spanish
    - Example: "Tu salón ha sido suspendido"
    
[ ] Invalid custom claims → Logout + error
    - Manually corrupt custom claims (admin SDK, for testing)
    - User tries to login or access data
    - Expected: Error message and auto-logout
```

### Data Validation Errors

```
[ ] Create turno with invalid date → Error
    - Click: "Crear Turno"
    - Enter: Invalid date (past date, malformed)
    - Click: "Guardar"
    - Expected: Form validation error
    - Example: "Fecha no válida" or "La fecha debe ser en el futuro"
    
[ ] Create turno without client → Error
    - Click: "Crear Turno"
    - Leave: Cliente field empty
    - Click: "Guardar"
    - Expected: Form validation error
    - Example: "Cliente es requerido"
    
[ ] Empty nombre field → Form error
    - Click: "Crear Cliente"
    - Leave: Nombre field empty
    - Click: "Guardar"
    - Expected: Form validation error
    - Example: "Nombre es requerido"
```

---

## Performance Testing

These tests are optional but recommended. Performance issues should be addressed before production.

```
[ ] First login takes <3s (including branding load)
    - Start: At login screen
    - Enter credentials, click "Iniciar Sesión"
    - Time: From button click to /agenda visible and responsive
    - Expected: <3 seconds on good network
    - Measurement: Use device profiler or stopwatch
    
[ ] Load agenda with 100 turnos: <2s
    - Pre-populate tenant with 100 turnos (via Cloud Function or batch write)
    - Open turnos_salon app
    - Navigate to /agenda
    - Time: From navigation to all turnos displayed
    - Expected: <2 seconds
    
[ ] Filter turnos by date: <500ms
    - Load /agenda with 100 turnos
    - Apply date filter
    - Time: From filter applied to results updated
    - Expected: <500ms
    
[ ] Suspend tenant blocks immediately (<1s)
    - Suspend tenant in turnos_admin
    - User with turnos_salon open sees error
    - Time: From suspend in admin to error in client
    - Expected: <1 second (Firestore Rules check is immediate)
    
[ ] User sync across devices (Cloud Function delay <2s)
    - Create user in turnos_admin on Device A
    - On Device B (logged in as admin), refresh user list
    - Time: From user creation to appearing in list
    - Expected: <2 seconds
```

---

## Audit Trail Verification

Verify that all actions are logged correctly:

```
[ ] Admin views audit logs in APP ADMIN
    - In turnos_admin app
    - Navigate to: Audit Logs or Admin panel
    - Expected: See list of all actions (create tenant, create user, etc.)
    
[ ] Each action logged correctly
    - For each of these actions, verify audit log entry:
      [ ] create_tenant → log shows tenant name, owner email
      [ ] create_user → log shows email, role, tenant_id
      [ ] delete_user → log shows email, tenant_id
      [ ] suspend_tenant → log shows tenant_id, reason
      [ ] create_turno → log shows turno_id, cliente, tenant_id
      [ ] update_turno → log shows what changed
      [ ] delete_turno → log shows turno_id, who deleted
    
[ ] Logs show: timestamp, action, super_admin_email, tenant_id, detalles
    - Open Firebase Console → _platform → audit_logs
    - Click on any log entry
    - Verify fields:
      [ ] acción: string (e.g., "create_tenant")
      [ ] super_admin: email of who performed action
      [ ] tenant_id: which tenant was affected
      [ ] detalles: object with action-specific info
      [ ] timestamp: when action occurred
    
[ ] Cannot modify audit logs (tested)
    - Try to update an audit log document (via SDK or Postman)
    - Expected: Permission denied
    - Audit logs are immutable (backend-only writes)
    
[ ] Export audit logs feature (optional)
    - If implemented: In turnos_admin, export logs to CSV
    - Expected: File downloads with all log entries
```

---

## Debugging & Troubleshooting

### Common Issues and Solutions

#### Issue: "User can't log in"

**Symptoms**:
- Login button click does nothing
- Error message: "Usuario o contraseña inválidos"
- App crashes on login

**Diagnosis**:
1. Check custom claims are set:
   - Firebase Console → Authentication → Click user
   - Scroll to "Custom claims"
   - Should show: `{ "tenant_id": "...", "role": "..." }`

2. Check tenant exists and is active:
   - Firebase Console → Firestore → _platform → tenants
   - Find tenant_id from custom claims
   - Verify: estado = "activo"

3. Check Firestore Rules deployment:
   - Firebase Console → Firestore → Rules
   - Verify rules are deployed (green checkmark)
   - Download current rules and compare to firestore.rules

**Solution**:
- If custom claims missing → Re-run setUserClaims Cloud Function
- If tenant doesn't exist → Create it in turnos_admin
- If rules not deployed → Run `firebase deploy --only firestore:rules`

---

#### Issue: "User sees 'Acceso denegado'"

**Symptoms**:
- User logs in successfully
- App loads /agenda
- Message: "Acceso denegado" or "No tienes permisos"

**Diagnosis**:
1. Check custom claims:
   - Firebase Console → Authentication → User
   - Verify: tenant_id and role present

2. Check tenant status:
   - Firebase Console → Firestore → _platform → tenants/{tenant_id}
   - Verify: estado = "activo"

3. Check Firestore Rules:
   - Firebase Console → Firestore → Rules
   - Verify: rules include role-based checks

**Solution**:
- If custom claims wrong → Re-set via setUserClaims
- If tenant suspended → Reactivate in turnos_admin
- If rules not deployed → Deploy rules

---

#### Issue: "Audit logs not appearing"

**Symptoms**:
- Admin creates user/tenant
- Expected audit log but not found
- Audit log collection is empty

**Diagnosis**:
1. Check Cloud Function is deployed:
   - Firebase Console → Cloud Functions
   - Should see: setUserClaims function
   - Status should be: Green/Active

2. Check function logs:
   - Firebase Console → Cloud Functions → setUserClaims → Logs
   - Look for errors: Permission denied, unhandled exception, etc.

3. Check Firestore Rules for audit_logs:
   - Firebase Console → Firestore → Rules
   - Search for: "audit_logs" rules section
   - Should allow backend writes but block client writes

**Solution**:
- If function not deployed → Run `firebase deploy --only functions`
- If function error in logs → Fix code and redeploy
- If rules block writes → Update rules to allow backend-only writes

---

#### Issue: "Admin can't create tenant"

**Symptoms**:
- Click "Crear Tenant" in turnos_admin
- Form fills, click "Guardar"
- Nothing happens or error appears

**Diagnosis**:
1. Check admin has super_admin custom claims:
   - Firebase Console → Authentication → Admin user
   - Custom claims should have: `{ "role": "super_admin" }`

2. Check Firestore Rules for _platform/tenants:
   - Verify rules allow super_admin to write

3. Check app code has TenantRepository:
   - Verify create() method exists
   - Verify it calls correct Firestore path

**Solution**:
- If custom claims missing → Set via Firebase Console or Cloud Function
- If rules restrictive → Update rules to allow super_admin writes
- If repository missing → Implement TenantRepository.create()

---

#### Issue: "Performance is slow"

**Symptoms**:
- First login takes >5s
- Loading agenda with many turnos is slow
- Filters lag

**Diagnosis**:
1. Check Firestore indexes:
   - Firebase Console → Firestore → Indexes
   - Verify: Composite indexes created for common queries
   - Example: tenants/{tenant_id}/turnos queried by date

2. Check data size:
   - Firebase Console → Firestore → Size/Stats
   - If hundreds of MB, may need optimization

3. Check network:
   - Device network settings
   - Verify: Good connection (not metered/slow)

4. Check app code for inefficiencies:
   - Verify: Not making duplicate queries
   - Verify: Not loading all data at once
   - Verify: Pagination/lazy loading implemented

**Solution**:
- Create Firestore indexes: Firebase Console → Firestore → Indexes → Create index
- Implement pagination: Load 20-50 turnos at a time
- Add caching: Use Riverpod cache or Hive for offline
- Optimize queries: Add `.limit(50)` or date range filters

---

### How to Read Firestore Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| "Missing or insufficient permissions" | Firestore Rules deny access | Check rules, verify custom claims |
| "PERMISSION_DENIED" | Same as above | Verify user role and tenant_id |
| "NOT_FOUND" | Collection or document doesn't exist | Create via admin or app |
| "ALREADY_EXISTS" | Trying to create duplicate document | Use unique IDs (auto-generated) |
| "INVALID_ARGUMENT" | Bad data type or value | Check data type (string vs number) |
| "UNAUTHENTICATED" | User not logged in | Require login before Firestore access |

---

### How to Check Cloud Function Logs

```bash
# View setUserClaims logs in real-time
firebase functions:log --only setUserClaims

# View all function logs
firebase functions:log

# Filter by error
firebase functions:log --only setUserClaims | grep -i error
```

Or via Firebase Console:
1. Go to: https://console.firebase.google.com
2. Project: turnos-salon-163b5
3. Navigate to: Cloud Functions
4. Click: setUserClaims
5. Scroll to: Logs section at bottom

---

## Rollback Procedures

If critical issues are found, use these procedures to rollback:

### Rollback Firestore Rules

```bash
# View current rules
firebase firestore:list-backups

# If rules are wrong, revert to previous version
# Option 1: Use git to revert firestore.rules
git checkout HEAD~1 firestore.rules

# Option 2: Manual revert in Firebase Console
# - Go to: Firestore → Rules
# - Click: Rollback
# - Select: Previous version date
# - Click: Restore

# Deploy previous rules
firebase deploy --only firestore:rules
```

### Rollback Cloud Function

```bash
# Delete the function (careful!)
firebase functions:delete setUserClaims

# Or redeploy previous version from git
git checkout HEAD~1 functions/setUserClaims.js
firebase deploy --only functions
```

### Rollback User/Tenant (if corrupted)

```bash
# In Firebase Console:
# 1. Go to: Authentication → Users
# 2. Click user to delete
# 3. Click: Delete user (three dots menu)
# 4. Confirm
# 
# Or via Firebase CLI:
firebase auth:delete [uid] --project turnos-salon-163b5

# Soft-delete tenant in Firestore:
# 1. Navigate: Firestore → _platform → tenants → {tenant_id}
# 2. Update: estado = "deleted"
# (Do NOT hard-delete, to preserve data recovery)
```

### Rollback App Versions

```bash
# If app deployment is broken
git log --oneline  # Find good commit

git checkout [good_commit_hash]
flutter pub get
flutter build apk  # or run on device

# Once verified working, can merge/revert as needed
```

---

## Test Sign-Off

Once all tests pass, document results:

```
Test Session Date: 2026-07-13
Tester Name: [Your Name]
Platform Tested: Android / iOS / Web
Firebase Environment: turnos-salon-163b5

Test Results:
[ ] Test 1 (Create Tenant & Login): PASS / FAIL
[ ] Test 2 (Create Users & Roles): PASS / FAIL
[ ] Test 3 (Suspend Tenant): PASS / FAIL
[ ] Test 4 (Multi-Tenant Isolation): PASS / FAIL
[ ] Test 5 (Soft Delete): PASS / FAIL
[ ] Regression Tests: PASS / FAIL
[ ] Security Tests: PASS / FAIL
[ ] Error Scenarios: PASS / FAIL
[ ] Performance: PASS / FAIL (or: PASS with notes)
[ ] Audit Trail: PASS / FAIL

Issues Found:
1. [Issue description] - Severity: Critical / High / Medium / Low
2. ...

Approved By: _________________ (Tech Lead)
Approved By: _________________ (Project Manager)
Date: 2026-07-13
```

---

**End of TESTING_GUIDE.md**
