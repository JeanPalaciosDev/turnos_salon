# Phase 2: Quick Start (TL;DR)

## What's Done ✅

The **Dart/Flutter side** of multi-tenant Custom Claims is complete:

- `CustomClaimsService` → calls Cloud Function to assign claims
- `CustomClaimsException` → Spanish error messages
- `UsuarioForm` updated → automatically calls setClaims() when creating users
- Configuration → `--dart-define` override support
- HTTP client → `http: ^1.2.0` dependency added

## What's Missing ❌

The **Cloud Function** (Node.js backend) that actually sets the claims.

## In 5 Minutes

### 1. Deploy Cloud Function

Copy the code from `CLOUD_FUNCTION_SETUP.md` into `functions/setUserClaims.js`, then:

```bash
firebase deploy --only functions:setUserClaims
```

### 2. Get the Endpoint

Copy the URL from deployment output, e.g.:
```
https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims
```

### 3. Update Config (Optional)

If not the default, update `lib/core/config.dart`:
```dart
const String kCloudFunctionSetUserClaims = '...actual-url...';
```

Or use `--dart-define` when running:
```bash
flutter run --dart-define=CLOUD_FUNCTION_ENDPOINT=https://your-url.cloudfunctions.net/setUserClaims
```

### 4. Test

```bash
flutter pub get
flutter run
```

- Login as super_admin
- Click "Nuevo usuario"
- Fill form and create
- Check Firebase Console → Auth → View Custom Claims

## Architecture in One Picture

```
Flutter:  email, password → AdminUserService.crearCuenta(uid)
                          → CustomClaimsService.setClaims(uid, tenant_id, role)
                             ↓
                          HTTP POST → Cloud Function
                             ↓
                          setCustomUserClaims(uid, {tenant_id, role})
                             ↓
                          UsuariosRepository.crearUsuario()
                             ↓
                          Firestore: usuarios/{uid} with Custom Claims in token
```

## Key Files

| File | What It Does |
|------|--------------|
| `lib/features/auth/data/custom_claims_service.dart` | Makes HTTP requests to Cloud Function |
| `lib/core/config.dart` | Stores Cloud Function endpoint URL |
| `lib/features/auth/presentation/usuario_form.dart` | Calls CustomClaimsService when creating users |
| `CLOUD_FUNCTION_SETUP.md` | **← READ THIS NEXT** |

## Error Messages (All Spanish)

- "No hay sesión activa" → User must be logged in
- "No tienes permiso para asignar roles" → Only super_admin can create users
- "El usuario no existe en Firebase Auth" → Auth account creation failed
- "Los parámetros enviados no son válidos" → Wrong request format
- "Error de red" → Network issue or timeout

## Testing with curl

```bash
# Export ID token from a super_admin user
export ID_TOKEN="eyJhbGci..."

# Test the Cloud Function
curl -X POST https://your-endpoint.cloudfunctions.net/setUserClaims \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{
    "uid": "user-123",
    "tenant_id": "tenant_0",
    "role": "estilista"
  }'

# Expected response:
# { "success": true, "message": "Custom claims assigned successfully" }
```

## Firestore Rules Example

Once Custom Claims are set, you can use them in rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /turnos/{turnoId} {
      allow read: if request.auth.token.claims.tenant_id == resource.data.tenant_id;
      allow create: if request.auth.token.claims.role in ['dueno', 'recepcion'];
    }
  }
}
```

## What's the Multi-Tenant ID?

When creating a user, you pass a `tenant_id`. This is:
- **Development**: `"tenant_0"` or `"dev-salon"` etc.
- **Production**: A unique ID per salon/business (e.g., `"salon_abc123"`)

All users belong to exactly one tenant. All their Firestore docs (appointments, workers) are tagged with their tenant_id and checked by Firestore Rules.

## Backward Compatibility

Existing code works without changes:
```dart
showUsuarioForm(context);  // No tenantId = no Custom Claims (old behavior)
showUsuarioForm(context, tenantId: "salon_123");  // New multi-tenant mode
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Build error: "http package not found" | `flutter pub get` |
| 403 Forbidden when creating user | Verify you're logged in as super_admin |
| 404 User not found | Auth account creation failed, check AdminUserService |
| "Endpoint not found" (404 on HTTP request) | Update CLOUD_FUNCTION_ENDPOINT with correct URL |
| Custom Claims not in token | Manually verify in Firebase Console or refresh token |

## Docs to Read

1. **You are here** → PHASE_2_QUICK_START.md (this file)
2. **Next** → CLOUD_FUNCTION_SETUP.md (create & deploy backend)
3. **Details** → PHASE_2_USAGE_EXAMPLES.md (testing & debugging)
4. **Full context** → PHASE_2_IMPLEMENTATION_SUMMARY.md (architecture)
5. **Checklist** → PHASE_2_VERIFICATION.md (verification steps)

## Quick Commands

```bash
# Run with specific endpoint
flutter run --dart-define=CLOUD_FUNCTION_ENDPOINT=http://localhost:5001/project/region/setUserClaims

# Deploy Cloud Function
firebase deploy --only functions:setUserClaims

# View Cloud Function logs
firebase functions:log

# Get ID token (in your app)
final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult();
print(token?.token);  // Use in curl testing

# Manually refresh token
await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);

# Check if Custom Claims are in token
print(token?.claims?['tenant_id']);
print(token?.claims?['role']);
```

## That's It!

- [x] Dart service implemented
- [x] Integration with user creation complete
- [ ] Deploy Cloud Function from CLOUD_FUNCTION_SETUP.md
- [ ] Test end-to-end
- [ ] Done! 🎉

---

**Status**: Dart side ready, waiting for Cloud Function deployment.  
**Next Step**: Open `CLOUD_FUNCTION_SETUP.md` and deploy the Cloud Function.
