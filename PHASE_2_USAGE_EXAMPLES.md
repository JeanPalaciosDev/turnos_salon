# Phase 2: Usage Examples & Testing Guide

This guide shows how to use the Custom Claims system in practice.

---

## Example 1: Creating a User with Custom Claims

### Flutter Code (Already implemented in usuario_form.dart)

```dart
// Show the user creation form with tenant_id
showUsuarioForm(
  context,
  tenantId: 'salon_123',  // Required for Custom Claims
);
```

The form will:
1. Collect email, password, nombre, rol
2. Create Auth account
3. Call CustomClaimsService.setClaims()
4. Create usuarios/{uid} Firestore doc

### What Happens Behind Scenes

```dart
// Inside usuario_form.dart _save()

// 1. Create Auth account
final uid = await adminUserService.crearCuenta(
  email: 'estilista@salon.com',
  password: 'SecurePass123',
);

// 2. Assign Custom Claims
await customClaimsService.setClaims(
  uid: uid,
  tenantId: 'salon_123',
  role: 'estilista',  // From dropdown
);

// 3. Create Firestore doc
usuariosRepository.crearUsuario(
  Usuario(
    uid: uid,
    trabajadorId: '...',
    rol: RolTrabajador.estilista,
    nombre: 'María García',
    email: 'estilista@salon.com',
    activo: true,
  ),
);
```

---

## Example 2: Cloud Function Request/Response

### Request from Flutter

```http
POST https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IjE...

{
  "uid": "user_abc123",
  "tenant_id": "salon_456",
  "role": "dueno"
}
```

### Cloud Function Processing

```javascript
// functions/setUserClaims.js

1. Decode Authorization header → extract ID token
2. admin.auth().verifyIdToken(idToken)
   → Verify token is authentic
   → Extract claims: { role: "super_admin", tenant_id: "..." }
3. Check caller.role == "super_admin" → Allow
4. admin.auth().getUser("user_abc123") → Verify user exists
5. admin.auth().setCustomUserClaims("user_abc123", {
     tenant_id: "salon_456",
     role: "dueno"
   })
6. Return { success: true, message: "Custom claims assigned successfully" }
```

### Response to Flutter

```json
200 OK
Content-Type: application/json

{
  "success": true,
  "message": "Custom claims assigned successfully",
  "uid": "user_abc123",
  "tenant_id": "salon_456",
  "role": "dueno"
}
```

### Error Response Examples

#### 403 Forbidden (Caller not super_admin)
```json
403 Forbidden
{
  "success": false,
  "message": "Permission denied. Only super_admin can assign claims.",
  "callerRole": "estilista"
}
```
Flutter shows: "No tienes permiso para asignar roles. Solo super_admin puede hacerlo."

#### 404 Not Found (User doesn't exist)
```json
404 Not Found
{
  "success": false,
  "message": "Target user not found"
}
```
Flutter shows: "El usuario no existe en Firebase Auth."

#### 400 Bad Request (Invalid parameters)
```json
400 Bad Request
{
  "success": false,
  "message": "Missing required fields: uid, tenant_id, role"
}
```
Flutter shows: "Los parámetros enviados no son válidos."

---

## Example 3: Reading Custom Claims in Firestore Rules

After Custom Claims are assigned, Firebase knows about them in rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Only allow users from the same tenant to read their documents
    match /turnos/{turnoId} {
      allow read: if request.auth.token.claims.tenant_id == resource.data.tenant_id;
      allow create: if (
        request.auth.token.claims.tenant_id == resource.data.tenant_id &&
        request.auth.token.claims.role in ['dueno', 'recepcion']
      );
    }
    
    // Only super_admin can modify user accounts
    match /usuarios/{uid} {
      allow read: if request.auth.token.claims.tenant_id == resource.data.tenant_id;
      allow create, update: if request.auth.token.claims.role == 'super_admin';
    }
  }
}
```

**Benefits**:
- No database query needed to check tenant
- Tenant isolation happens at Firebase security level
- Fast, reliable, and centralized

---

## Example 4: Accessing Custom Claims in Dart

```dart
import 'package:firebase_auth/firebase_auth.dart';

// Inside your Dart code
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final tokenResult = await user.getIdTokenResult();
  
  // Access custom claims
  final claims = tokenResult.claims ?? {};
  final tenantId = claims['tenant_id'] as String?;
  final role = claims['role'] as String?;
  
  print('Tenant: $tenantId, Role: $role');
  
  // Token is fresh (within 1 hour)
  print('Token expires: ${tokenResult.expirationTime}');
}
```

---

## Testing Scenarios

### Scenario 1: Successful User Creation (Happy Path)

**Setup**:
- Current user is super_admin with token
- Creating new estilista user

**Steps**:
1. Open UsuarioForm with tenantId
2. Fill form:
   - Email: estilista@salon.com
   - Password: Secure123
   - Nombre: María
   - Rol: Estilista
3. Click "Crear usuario"

**Expected Result**:
- ✅ Auth account created
- ✅ Custom Claims assigned (tenant_id, role in token)
- ✅ usuarios/{uid} doc created
- ✅ SnackBar: 'Usuario "María" creado.'

**Verification**:
```bash
# Check Custom Claims in Firebase Console
# → Authentication → Users → Look for the user
# → Click on it → View Custom Claims
```

### Scenario 2: Non-Super-Admin Cannot Create Users

**Setup**:
- Current user is estilista (NOT super_admin)
- Trying to create new user

**Steps**:
1. estilista logs in
2. Somehow calls showUsuarioForm (shouldn't be available in UI, but testing error handling)
3. Tries to create user

**Expected Result**:
- ✅ Auth account created successfully
- ❌ CustomClaimsService.setClaims() fails with 403
- ❌ Error shown: "No tienes permiso para asignar roles. Solo super_admin puede hacerlo."
- ⚠️ Auth account created but NO Custom Claims (orphaned)

**Verification**: In Firestore Rules, estilista cannot perform admin operations

### Scenario 3: Network Error / Timeout

**Setup**:
- Cloud Function unreachable or very slow
- Create user while network is slow

**Steps**:
1. Disable internet or introduce artificial delay
2. Try to create user
3. Wait for timeout (30 seconds)

**Expected Result**:
- ✅ Auth account created
- ❌ CustomClaimsService.setClaims() times out after 30 seconds
- ❌ Error shown: "La operación tardó demasiado. Verifica tu conexión e intenta de nuevo."
- ⚠️ Auth account created but NO Custom Claims

**Verification**: Manually call setUserClaims later to assign claims to orphaned user

### Scenario 4: Cloud Function Endpoint Not Set

**Setup**:
- CLOUD_FUNCTION_ENDPOINT environment variable not set or wrong

**Steps**:
1. Run app with missing endpoint
2. Try to create user with tenantId

**Expected Result**:
- ✅ Auth account created
- ❌ HTTP request fails (connection refused or 404)
- ❌ Error shown: "Error de red. Verifica tu conexión e intenta de nuevo."

**Fix**:
```bash
flutter run --dart-define=CLOUD_FUNCTION_ENDPOINT=https://your-actual-endpoint.cloudfunctions.net/setUserClaims
```

### Scenario 5: Creating User WITHOUT tenantId (Backward Compatibility)

**Setup**:
- Old code path that doesn't pass tenantId

**Steps**:
```dart
showUsuarioForm(context);  // No tenantId
```

**Expected Result**:
- ✅ Auth account created
- ⏭️ CustomClaimsService.setClaims() skipped (tenantId is null)
- ✅ usuarios/{uid} doc created WITHOUT Custom Claims
- ✅ User works (no tenant isolation for this user)

---

## Testing with curl (Backend Developer)

### Prerequisites

1. Get an ID token from a super_admin user:
   ```bash
   # Via Firebase Console → Auth → Click user → Copy ID Token (from DevTools)
   # OR via app login + print in debug
   ```

2. Export as environment variable:
   ```bash
   export ID_TOKEN="eyJhbGciOiJSUzI1NiIsImtpZCI6IjE..."
   ```

### Test 1: Successful Claim Assignment

```bash
curl -X POST https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{
    "uid": "testuser123",
    "tenant_id": "tenant_0",
    "role": "estilista"
  }'

# Expected response:
# { "success": true, "message": "Custom claims assigned successfully", ... }
```

### Test 2: Non-Super-Admin Caller (403)

```bash
# Use ID token from non-super_admin user
export NON_ADMIN_TOKEN="..."

curl -X POST https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $NON_ADMIN_TOKEN" \
  -d '{
    "uid": "testuser123",
    "tenant_id": "tenant_0",
    "role": "estilista"
  }'

# Expected response:
# 403 Forbidden
# { "success": false, "message": "Permission denied. Only super_admin can assign claims." }
```

### Test 3: Missing Authorization Header (403)

```bash
curl -X POST https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims \
  -H "Content-Type: application/json" \
  -d '{
    "uid": "testuser123",
    "tenant_id": "tenant_0",
    "role": "estilista"
  }'

# Expected response:
# 403 Forbidden
# { "success": false, "message": "Missing or invalid Authorization header" }
```

### Test 4: Invalid Parameters (400)

```bash
curl -X POST https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{
    "uid": "testuser123"
    # Missing: tenant_id, role
  }'

# Expected response:
# 400 Bad Request
# { "success": false, "message": "Missing required fields: uid, tenant_id, role" }
```

### Test 5: User Not Found (404)

```bash
curl -X POST https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{
    "uid": "nonexistent-user-xyz",
    "tenant_id": "tenant_0",
    "role": "estilista"
  }'

# Expected response:
# 404 Not Found
# { "success": false, "message": "Target user not found" }
```

---

## Debugging Checklist

### In Flutter

1. **Check if CustomClaimsService is called**:
   ```dart
   // Add print in usuario_form.dart _save()
   print('Calling CustomClaimsService.setClaims...');
   ```

2. **View the HTTP request**:
   ```dart
   // Add in custom_claims_service.dart
   print('POST $endpoint with uid=$uid, tenantId=$tenantId');
   ```

3. **View the response**:
   ```dart
   print('Response status: ${response.statusCode}');
   print('Response body: ${response.body}');
   ```

4. **Check ID token contents**:
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   final token = await user?.getIdTokenResult();
   print('Token claims: ${token?.claims}');
   ```

### In Cloud Function

1. **Check logs**:
   ```bash
   firebase functions:log --region us-central1
   # Or Firebase Console → Cloud Functions → setUserClaims → Logs
   ```

2. **Add console.log in function**:
   ```javascript
   console.log('Received request:', { uid, tenant_id, role });
   console.log('Decoded token:', decodedToken);
   console.log('Caller role:', callerRole);
   ```

3. **Test locally**:
   ```bash
   firebase emulators:start --inspect-functions
   # Opens debugger on port 9229
   ```

---

## Common Issues & Solutions

### Issue: "No sesión activa" Error

**Cause**: No user is logged in when trying to create another user

**Solution**: Ensure super_admin is logged in before opening the form

### Issue: "No tienes permiso para asignar roles"

**Cause**: Caller is not super_admin

**Solution**: Only super_admin should be able to create users. Check Firestore Rules to hide the create-user button for non-admins

### Issue: "La operación tardó demasiado"

**Cause**: Network is slow or Cloud Function is unresponsive

**Solution**: 
1. Check Cloud Function is deployed and healthy
2. Check internet connection
3. Increase timeout if needed (update kCloudFunctionTimeout in config.dart)

### Issue: "El usuario no existe en Firebase Auth"

**Cause**: Auth account creation failed but code continued

**Solution**: Check Auth account creation response. This usually means step 1 (crearCuenta) failed but wasn't caught properly

### Issue: Custom Claims don't appear in token

**Cause**: 
1. setCustomUserClaims response showed 200 but didn't actually set claims
2. Token was not refreshed after claims were set
3. Used wrong uid

**Solution**: 
1. Check Cloud Function logs
2. Manually verify in Firebase Console → Auth → User → Custom Claims
3. Refresh token: `await user.getIdTokenResult(true)` (force refresh)

---

## End-to-End Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter App (usuario_form.dart)              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ├─→ [1] AdminUserService.crearCuenta()
                              │        ↓
                              │   [Sec] Firebase Auth (secondary instance)
                              │        │
                              │        ├─→ createUserWithEmailAndPassword()
                              │        │        ↓
                              │        ├─→ ✅ New Auth account: uid-123
                              │        │
                              │        ├─→ signOut() & app.delete()
                              │        ↓
                              ├─→ [2] CustomClaimsService.setClaims()
                              │        │
                              │        ├─→ Get current user's ID token
                              │        │
                              │        ├─→ HTTP POST to Cloud Function
                              │        │   Content-Type: application/json
                              │        │   Authorization: Bearer <token>
                              │        │   Body: { uid, tenant_id, role }
                              │        │
    ┌──────────────────────────────────┐
    │  CLOUD_FUNCTION_ENDPOINT         │
    │  ─────────────────────────────    │
    │  setUserClaims() (Node.js)       │
    │                                  │
    │  1. Parse request body           │
    │  2. Extract Bearer token         │
    │  3. admin.auth().verifyIdToken() │
    │  4. Check role == 'super_admin'  │
    │  5. admin.auth().setCustom      │
    │     UserClaims(uid, {...})      │
    │  6. Return { success: true }     │
    └──────────────────────────────────┘
                              │
                              ├─→ ✅ Response 200
                              │
                              ├─→ [3] UsuariosRepository.crearUsuario()
                              │        ↓
                              │   Firestore: usuarios/{uid-123}
                              │        ├─ trabajador_id: "..."
                              │        ├─ rol: "estilista"
                              │        ├─ nombre: "María"
                              │        ├─ email: "..."
                              │        ├─ activo: true
                              │        ├─ created_at: <server-time>
                              │
                              └─→ ✅ User created successfully
                                   Show SnackBar
```

---

## Quick Reference

### URLs
- **Default Cloud Function**: `https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims`
- **Local Emulator**: `http://127.0.0.1:5001/turnos-salon-dev/us-central1/setUserClaims`

### Key Classes
- `CustomClaimsService` - main service
- `CustomClaimsException` - exceptions
- `AdminUserService` - creates Auth account
- `UsuariosRepository` - creates Firestore doc

### Key Files
- `lib/core/config.dart` - endpoint configuration
- `lib/features/auth/data/custom_claims_service.dart` - service implementation
- `lib/features/auth/presentation/usuario_form.dart` - integration point
- `CLOUD_FUNCTION_SETUP.md` - Cloud Function guide (do this next!)

### Commands

**Run with custom endpoint**:
```bash
flutter run --dart-define=CLOUD_FUNCTION_ENDPOINT=http://localhost:5001/project/region/setUserClaims
```

**Deploy Cloud Function**:
```bash
firebase deploy --only functions:setUserClaims
```

**View logs**:
```bash
firebase functions:log
```

**Test with curl**:
```bash
curl -X POST <endpoint> \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{ "uid": "...", "tenant_id": "...", "role": "..." }'
```
