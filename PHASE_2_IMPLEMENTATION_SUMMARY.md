# Phase 2: Custom Claims Implementation Summary

**Date**: 2026-07-13  
**Status**: Dart-side implementation complete; Cloud Function needed

---

## Objective

Implement infrastructure to set Custom Claims (tenant_id and role) on Firebase Auth users so that Firestore Rules can enforce multi-tenant access control via `request.auth.token.claims`.

---

## What Was Implemented

### Part A: Dart Service Layer ✅

#### 1. CustomClaimsService (`lib/features/auth/data/custom_claims_service.dart`)

**Class**: `CustomClaimsService`

**Key Method**:
```dart
Future<void> setClaims({
  required String uid,
  required String tenantId,
  required String role,
}) async
```

**Features**:
- Extracts current user's ID token
- Makes HTTP POST to Cloud Function endpoint
- Includes Authorization Bearer token in headers
- Request body: `{ uid, tenant_id, role }`
- Handles errors with user-friendly Spanish messages
- 30-second timeout
- Error codes handled:
  - 200: Success
  - 400: Bad request (invalid parameters)
  - 403: Forbidden (not super_admin, no session)
  - 404: User not found
  - 500+: Server error
  - Network/timeout

**Error Handling**: All errors thrown as `CustomClaimsException` with Spanish messages

#### 2. CustomClaimsException (`lib/features/auth/data/custom_claims_service.dart`)

Custom exception class following the pattern of `AdminUserException`:
```dart
class CustomClaimsException implements Exception {
  const CustomClaimsException(
    this.message,
    { this.originalError }
  );
  
  final String message;       // User-facing Spanish message
  final dynamic originalError; // For debugging
}
```

#### 3. Configuration (`lib/core/config.dart`)

Centralized endpoint configuration:
```dart
const String kCloudFunctionSetUserClaims = String.fromEnvironment(
  'CLOUD_FUNCTION_ENDPOINT',
  defaultValue: 'https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims',
);

const Duration kCloudFunctionTimeout = Duration(seconds: 30);
```

Can be overridden at runtime:
```bash
flutter run --dart-define=CLOUD_FUNCTION_ENDPOINT=http://127.0.0.1:5001/...
```

#### 4. Integration Point: UsuarioForm (`lib/features/auth/presentation/usuario_form.dart`)

Updated user creation flow:

```dart
showUsuarioForm(context, tenantId: "tenant_0");
```

The `_save()` method now:
1. Creates Auth account via `AdminUserService.crearCuenta()` → uid
2. **[NEW]** Calls `CustomClaimsService.setClaims(uid, tenantId, role)` if tenantId is provided
3. Creates Firestore doc via `UsuariosRepository.crearUsuario(usuario)`

```dart
// 1) Crear cuenta Auth
final uid = await ref.read(adminUserServiceProvider).crearCuenta(
      email: _email.text,
      password: _password.text,
    );

// 2) [NEW] Asignar Custom Claims
if (widget.tenantId != null) {
  try {
    await ref.read(customClaimsServiceProvider).setClaims(
          uid: uid,
          tenantId: widget.tenantId!,
          role: rolToDb(_rol),  // "dueno", "recepcion", "estilista"
        );
  } catch (e) {
    print('⚠️ CustomClaimsService.setClaims falló: $e');
    rethrow;
  }
}

// 3) Crear doc usuarios/{uid}
ref.read(usuariosRepositoryProvider).crearUsuario(usuario);
```

**Backward Compatibility**: If `tenantId` is null, Custom Claims assignment is skipped (legacy mode).

#### 5. Dependencies Added (`pubspec.yaml`)

```yaml
http: ^1.2.0  # For HTTP requests to Cloud Function
```

---

## What Still Needs Implementation

### Part B: Cloud Function (Backend) ❌ — You need to implement

**File to create**: `functions/setUserClaims.js` (Node.js + Firebase Admin SDK)

**See**: `CLOUD_FUNCTION_SETUP.md` for complete implementation guide

**Key requirements**:
- Receive POST: `{ uid, tenant_id, role }`
- Extract Authorization Bearer token from headers
- Verify token with `admin.auth().verifyIdToken(token)`
- Check caller has `role='super_admin'` in decoded token
- Call `admin.auth().setCustomUserClaims(uid, { tenant_id, role })`
- Return `{ success: true }` or error details
- Handle errors: 400, 403, 404, 500

**Deployment**:
```bash
firebase deploy --only functions:setUserClaims
```

---

## Architecture: How It Works

### Token-Level Multi-Tenancy

```
┌─────────────────────────────────────────────────────┐
│ User Creation Flow                                   │
└─────────────────────────────────────────────────────┘

1. showUsuarioForm(context, tenantId: "tenant_0")
   ↓
2. User fills form (email, password, role, nombre)
   ↓
3. _save() clicked
   ├─ adminUserService.crearCuenta(email, password)
   │  └─ → uid (Firebase Auth account created)
   │
   ├─ customClaimsService.setClaims(uid, "tenant_0", "dueno")
   │  ├─ Gets current user's ID token
   │  ├─ POST to Cloud Function with Authorization header
   │  ├─ Cloud Function verifies token is super_admin
   │  ├─ admin.auth().setCustomUserClaims(uid, {tenant_id, role})
   │  └─ → Claims attached to user's Firebase token
   │
   └─ usuariosRepository.crearUsuario(usuario)
      └─ → usuarios/{uid} Firestore doc created
```

### Custom Claims in ID Token

After `setCustomUserClaims` is called:

```
ID Token Payload (decoded):
{
  "iss": "https://securetoken.google.com/...",
  "sub": "uid-123",
  "email": "user@example.com",
  "claims": {
    "tenant_id": "tenant_0",
    "role": "dueno"  // ← Custom Claims attached here
  }
}
```

### Firestore Rules Integration

Once Custom Claims are in the token, Firestore Rules can enforce access:

```
match /usuarios/{uid} {
  allow read: if request.auth.token.claims.tenant_id == resource.data.tenant_id;
  allow update: if request.auth.token.claims.role == 'super_admin';
}

match /turnos/{turnoId} {
  allow read: if request.auth.token.claims.tenant_id == resource.data.tenant_id;
}
```

**Benefits**:
- No database lookup needed to check tenant
- Tenant isolation enforced at token level
- Firestore Rules are simpler and faster

---

## Files Created/Modified

### Created:
- ✅ `lib/core/config.dart` — Cloud Function endpoint configuration
- ✅ `lib/features/auth/data/custom_claims_service.dart` — Main service + exception
- ✅ `CLOUD_FUNCTION_SETUP.md` — Complete Cloud Function implementation guide
- ✅ `PHASE_2_IMPLEMENTATION_SUMMARY.md` — This file

### Modified:
- ✅ `pubspec.yaml` — Added `http: ^1.2.0` dependency
- ✅ `lib/features/auth/presentation/usuario_form.dart` — Integrated setClaims() call

---

## Verification Checklist

### Dart/Flutter Side ✅
- [x] CustomClaimsService class exists with setClaims() method
- [x] Method signature: uid, tenantId, role parameters
- [x] CustomClaimsException class exists with Spanish error messages
- [x] HTTP POST logic: Bearer token, correct headers, jsonEncode body
- [x] Error handling: 400, 403, 404, 500 all caught
- [x] Timeout handling: 30-second limit
- [x] Integration point: usuario_form.dart calls setClaims() after crearCuenta()
- [x] Backward compatibility: null tenantId skips Custom Claims
- [x] Provider pattern: customClaimsServiceProvider registered

### Cloud Function Side ❌ (To do)
- [ ] Create functions/setUserClaims.js
- [ ] Implement token verification (admin.auth().verifyIdToken)
- [ ] Implement role check (caller must be super_admin)
- [ ] Implement setCustomUserClaims call
- [ ] Handle all error cases (400, 403, 404, 500)
- [ ] Deploy to Firebase
- [ ] Update CLOUD_FUNCTION_ENDPOINT in lib/core/config.dart with actual URL
- [ ] Test with curl command (see CLOUD_FUNCTION_SETUP.md)

### Integration Testing ❌ (To do)
- [ ] Manual test: Create user via form with tenantId
- [ ] Verify Custom Claims appear in Firebase Console → Authentication
- [ ] Verify ID token contains claims (getIdTokenResult().token)
- [ ] Verify Firestore Rules can read request.auth.token.claims
- [ ] Test error scenarios: 403 (not super_admin), 404 (user not found)

---

## Testing: Local Development

### Option 1: Using Emulator + Local Cloud Function

```bash
# 1. Start Firebase Emulator Suite
firebase emulators:start

# 2. Create local Cloud Function (see CLOUD_FUNCTION_SETUP.md)
# 3. Run Flutter with emulator endpoint
flutter run --dart-define=USE_EMULATOR=true \
  --dart-define=CLOUD_FUNCTION_ENDPOINT=http://127.0.0.1:5001/turnos-salon-dev/us-central1/setUserClaims

# 4. Create a user via the form
# 5. Check Firebase Emulator UI → Auth to see claims assigned
```

### Option 2: Using Production Firebase + Local Function

```bash
# 1. Deploy only Firestore to emulator
firebase emulators:start --only firestore

# 2. Run local Cloud Function with Admin SDK
# 3. Point Flutter to local function endpoint
flutter run --dart-define=CLOUD_FUNCTION_ENDPOINT=http://127.0.0.1:3000/setUserClaims
```

### Debugging

**View HTTP requests**:
```dart
// Add to CustomClaimsService for debugging
print('POST $kCloudFunctionSetUserClaims');
print('Body: $requestBody');
print('Response: ${response.statusCode} ${response.body}');
```

**View Firebase token**:
```dart
final user = FirebaseAuth.instance.currentUser;
final tokenResult = await user?.getIdTokenResult();
print('Token: ${tokenResult?.token}');
print('Custom Claims: ${tokenResult?.claims}');
```

---

## Error Scenarios & Responses

### Success (200 OK)
```json
{
  "success": true,
  "message": "Custom claims assigned successfully",
  "uid": "user-123",
  "tenant_id": "tenant_0",
  "role": "dueno"
}
```
Flutter: Success, user continues

### Error: Missing Token (403 Forbidden)
```json
{
  "success": false,
  "message": "Missing or invalid Authorization header"
}
```
Flutter: `CustomClaimsException("No hay sesión activa...")`

### Error: Not Super Admin (403 Forbidden)
```json
{
  "success": false,
  "message": "Permission denied. Only super_admin can assign claims.",
  "callerRole": "dueno"
}
```
Flutter: `CustomClaimsException("No tienes permiso para asignar roles...")`

### Error: User Not Found (404 Not Found)
```json
{
  "success": false,
  "message": "Target user not found"
}
```
Flutter: `CustomClaimsException("El usuario no existe en Firebase Auth.")`

### Error: Invalid Parameters (400 Bad Request)
```json
{
  "success": false,
  "message": "Missing required fields: uid, tenant_id, role"
}
```
Flutter: `CustomClaimsException("Los parámetros enviados no son válidos.")`

### Error: Network Timeout
Flutter: `CustomClaimsException("La operación tardó demasiado...")`

---

## Next Steps

### Immediate (Before Testing)
1. Read `CLOUD_FUNCTION_SETUP.md` for Cloud Function implementation
2. Create and deploy `functions/setUserClaims.js`
3. Update `lib/core/config.dart` with actual deployed endpoint
4. Run `flutter pub get` to fetch the `http` package

### For Full Multi-Tenant Support
1. Ensure every user-creation flow includes tenantId
2. Update Firestore Rules to check `request.auth.token.claims.tenant_id`
3. Update UI to show/select tenant when creating users
4. Handle "first tenant + admin" onboarding (initial setup)

### Future Enhancements
1. Add super_admin role to RolTrabajador enum if needed
2. Add Cloud Tasks queue for retry reliability
3. Add monitoring/logging for claim assignments
4. Add UI to view/audit Custom Claims on users
5. Implement token refresh on claim changes

---

## Security Considerations

✅ **What's Secure**:
- Custom Claims are read-only from client (set only via Admin SDK)
- Authorization header required (Bearer token)
- Server-side verification of token authenticity
- Role-based access control enforced on Cloud Function
- Claims are immutable once set (unless explicitly changed)

⚠️ **What to Monitor**:
- Ensure only super_admin can call setUserClaims
- Ensure ID tokens are refreshed after claims change
- Ensure Firestore Rules check claims on all sensitive collections
- Monitor Cloud Function invocations for abuse
- Log all claim assignments for audit trail

---

## Architecture Decisions Documented

### Why HTTP Cloud Function?
- Admin SDK (setCustomUserClaims) only available on backend
- HTTP endpoint provides clean interface for Flutter
- Bearer token verification ensures security

### Why Custom Claims (Not Firestore)?
- Custom Claims attached to ID token (no DB lookup needed)
- Faster Firestore Rules evaluation
- Tenant isolation enforced at authentication layer
- Claims are immutable during token lifetime (~1 hour)

### Why Optional tenantId?
- Backward compatibility with single-tenant setup
- Gradual migration path to multi-tenant
- Allows testing without full multi-tenant infrastructure

---

## Files Reference

| File | Purpose |
|------|---------|
| `lib/core/config.dart` | Cloud Function endpoint configuration |
| `lib/features/auth/data/custom_claims_service.dart` | Main service + exception class |
| `lib/features/auth/presentation/usuario_form.dart` | Integration: calls setClaims() |
| `CLOUD_FUNCTION_SETUP.md` | Backend implementation guide (YOU NEED TO DO THIS) |
| `pubspec.yaml` | Added http: ^1.2.0 dependency |

---

## Documentation & References

- **Firebase Admin SDK**: https://firebase.google.com/docs/auth/admin-setup
- **Firebase Custom Claims**: https://firebase.google.com/docs/auth/admin-setup#set-custom-user-claims
- **Firestore Rules**: https://firebase.google.com/docs/firestore/security/rules-query-filters
- **Flutter Firebase Auth**: https://firebase.google.com/docs/auth/flutter/start
- **Dart HTTP Package**: https://pub.dev/packages/http

---

## Support

For questions or issues:
1. Check `CLOUD_FUNCTION_SETUP.md` for Cloud Function implementation help
2. Review error messages in `CustomClaimsException` for user-facing feedback
3. Check Firebase Console → Cloud Functions → Logs for function invocation errors
4. Use `flutter run -v` for verbose logging
5. Check network tab in Flutter DevTools for HTTP request/response details
