# Phase 2: Cloud Function Setup Guide for Custom Claims

## Overview

The Flutter app (Dart side) now sends HTTP requests to a Cloud Function to assign Custom Claims to Firebase Auth users. This document explains how to implement and deploy the Cloud Function.

## What is setUserClaims?

`setUserClaims` is a **Cloud Function** that:
1. Receives an HTTP POST request with `{ uid, tenant_id, role }`
2. Verifies that the caller has `super_admin` role via their ID token
3. Uses the Firebase Admin SDK to assign Custom Claims to the target user
4. Returns `{ success: true }` or error details

**Why separate?** Firebase Admin SDK (which can set Custom Claims) only runs on the backend, not in Flutter. The Cloud Function acts as an intermediary.

---

## Phase 2 Flow (Complete)

### User Creation in Flutter (already implemented):

```dart
// lib/features/auth/presentation/usuario_form.dart

_save() {
  // 1. Create Auth account (secondary instance)
  uid = await adminUserService.crearCuenta(email, password)
  
  // 2. [NEW] Assign Custom Claims via Cloud Function
  await customClaimsService.setClaims(
    uid: uid,
    tenantId: "tenant_0",
    role: "super_admin"
  )
  
  // 3. Create Firestore doc usuarios/{uid}
  usuariosRepository.crearUsuario(usuario)
}
```

### Cloud Function Implementation (you need to build):

```
setUserClaims Cloud Function
├── Receives: POST with { uid, tenant_id, role }
├── Extracts: Authorization Bearer token
├── Verifies: Token is super_admin
├── Sets: admin.auth().setCustomUserClaims(uid, { tenant_id, role })
└── Returns: { success: true }
```

---

## Cloud Function Implementation (Node.js)

Create or update `functions/setUserClaims.js`:

```javascript
// functions/setUserClaims.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * HTTP Cloud Function: Assigns Custom Claims (tenant_id, role) to a Firebase Auth user.
 *
 * Security:
 * - Requires Authorization: Bearer <ID_TOKEN> header
 * - Token must belong to a super_admin (verified via decoded claims)
 * - Only super_admin can assign claims to other users
 *
 * Request body:
 * {
 *   "uid": "user-to-update",
 *   "tenant_id": "tenant_123",
 *   "role": "super_admin|dueno|recepcion|estilista"
 * }
 *
 * Response:
 * Success (200):
 *   { "success": true, "message": "Claims assigned" }
 *
 * Errors:
 * 400: Invalid parameters
 * 403: Unauthorized (not super_admin, no token, invalid token)
 * 404: User not found
 * 500: Server error
 */
exports.setUserClaims = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // Handle OPTIONS (CORS preflight)
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Only POST allowed
  if (req.method !== 'POST') {
    return res.status(405).json({
      success: false,
      message: 'Method not allowed. Use POST.',
    });
  }

  try {
    // 1. Validate request body
    const { uid, tenant_id, role } = req.body;
    if (!uid || !tenant_id || !role) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: uid, tenant_id, role',
      });
    }

    // 2. Extract Authorization header
    const authHeader = req.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(403).json({
        success: false,
        message: 'Missing or invalid Authorization header',
      });
    }

    const idToken = authHeader.substring(7); // Remove "Bearer "

    // 3. Verify ID token and check if caller is super_admin
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      return res.status(403).json({
        success: false,
        message: 'Invalid or expired ID token',
        detail: error.message,
      });
    }

    // 4. Check if caller has super_admin role
    const callerRole = decodedToken.claims?.role;
    if (callerRole !== 'super_admin') {
      return res.status(403).json({
        success: false,
        message: 'Permission denied. Only super_admin can assign claims.',
        callerRole: callerRole || 'no role',
      });
    }

    // 5. Verify target user exists
    try {
      await admin.auth().getUser(uid);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        return res.status(404).json({
          success: false,
          message: 'Target user not found',
        });
      }
      throw error;
    }

    // 6. Set custom claims
    await admin.auth().setCustomUserClaims(uid, {
      tenant_id,
      role,
    });

    return res.status(200).json({
      success: true,
      message: 'Custom claims assigned successfully',
      uid,
      tenant_id,
      role,
    });
  } catch (error) {
    console.error('[setUserClaims] Unexpected error:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error',
      detail: error.message,
    });
  }
});
```

---

## Alternative: Using Cloud Tasks (For Reliability)

If you want **guaranteed delivery** (recommended for critical operations):

```javascript
// Invoke setUserClaims via Cloud Tasks instead of direct HTTP

const tasks = require('@google-cloud/tasks');

async function enqueueSetClaims(uid, tenantId, role) {
  const client = new tasks.CloudTasksClient();
  const project = process.env.GCP_PROJECT;
  const queue = 'set-user-claims';
  const location = 'us-central1';
  
  const parent = client.queuePath(project, location, queue);

  const task = {
    httpRequest: {
      httpMethod: 'POST',
      url: 'https://REGION-PROJECT.cloudfunctions.net/setUserClaims',
      headers: {
        'Content-Type': 'application/json',
      },
      body: Buffer.from(JSON.stringify({
        uid,
        tenant_id: tenantId,
        role,
      })).toString('base64'),
      oidcToken: {
        // Use service account to authenticate
        serviceAccountEmail: 'service-account@PROJECT.iam.gserviceaccount.com',
      },
    },
  };

  const request = { parent, task };
  const [response] = await client.createTask(request);
  console.log(`Created task: ${response.name}`);
}
```

---

## Deployment

### 1. Deploy via Firebase CLI

```bash
# Install Firebase CLI if needed
npm install -g firebase-tools

# Login (one time)
firebase login

# Deploy function
firebase deploy --only functions:setUserClaims
```

### 2. Get the Endpoint URL

After deployment, the URL appears in the console:

```
✔ Deploy complete!

Function URL (setUserClaims): https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims
```

### 3. Update Dart App Configuration

In `lib/core/config.dart`, replace the default endpoint:

```dart
const String kCloudFunctionSetUserClaims = String.fromEnvironment(
  'CLOUD_FUNCTION_ENDPOINT',
  defaultValue: 'https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims',
);
```

Or run with `--dart-define`:

```bash
flutter run --dart-define=CLOUD_FUNCTION_ENDPOINT=https://us-central1-turnos-salon-prod.cloudfunctions.net/setUserClaims
```

---

## Testing the Cloud Function

### Manual Test (curl)

```bash
# 1. Get an ID token from a super_admin user (via Firebase Console or your app)
ID_TOKEN="eyJhbGciOiJSUzI1NiIsImtpZCI6I..."

# 2. Call the function
curl -X POST https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{
    "uid": "user-123",
    "tenant_id": "tenant_0",
    "role": "super_admin"
  }'

# Expected response:
# { "success": true, "message": "Custom claims assigned successfully", ... }
```

### In Firebase Emulator Suite

If running locally with the emulator:

```bash
# Start emulator
firebase emulators:start

# The function runs at:
# http://127.0.0.1:5001/PROJECT_ID/region/setUserClaims

# Test:
curl -X POST http://127.0.0.1:5001/turnos-salon-dev/us-central1/setUserClaims \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ID_TOKEN" \
  -d '{ "uid": "...", "tenant_id": "...", "role": "..." }'
```

---

## Firestore Security Rules Integration

Once Custom Claims are set, Firestore Rules can read them:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Only super_admin can create/update users
    match /usuarios/{uid} {
      allow create, update: if request.auth.token.claims.role == 'super_admin';
      allow read: if request.auth.token.claims.tenant_id == resource.data.tenant_id;
      allow delete: if request.auth.token.claims.role == 'super_admin';
    }

    // Only users in the same tenant can read appointments
    match /turnos/{turnoId} {
      allow read: if request.auth.token.claims.tenant_id == resource.data.tenant_id;
      allow create, update: if request.auth.token.claims.role in ['super_admin', 'dueno', 'recepcion'];
    }
  }
}
```

---

## Error Handling in Flutter

The Dart `CustomClaimsService` already handles:

- **403 Forbidden**: "Not authorized to set claims"
- **404 Not Found**: "User not found"
- **400 Bad Request**: Parameter validation errors
- **500+ Server**: "Error in server"
- **Network timeout**: "Operation took too long"

All errors are converted to `CustomClaimsException` with Spanish user-facing messages (see `lib/features/auth/data/custom_claims_service.dart`).

---

## Checklist

- [ ] Create or update `functions/setUserClaims.js` with code above
- [ ] Run `firebase deploy --only functions:setUserClaims`
- [ ] Copy the function URL from deployment output
- [ ] Update `lib/core/config.dart` with the production URL
- [ ] Test with a curl request as shown above
- [ ] Verify Firestore Rules can read `request.auth.token.claims`
- [ ] Test user creation flow end-to-end in the Flutter app
- [ ] (Optional) Set up Cloud Tasks queue for retry reliability
- [ ] (Optional) Add logging/monitoring to track claim assignments

---

## Debugging Tips

1. **Check Firebase Console → Cloud Functions → Logs** to see function invocations
2. **Verify ID token**: use `jwt.io` to decode and check the `claims` field
3. **Test CORS**: ensure endpoints accept cross-origin requests (see `res.set()` headers above)
4. **Emulator**: run `firebase emulators:start --inspect-functions` to debug locally
5. **Network tab**: in Flutter DevTools, inspect the HTTP request/response

---

## Notes for Phase 2 Implementation

- Custom Claims are set **immediately after** Auth account creation (synchronous)
- They are **immutable** from the client side (only Admin SDK can change them)
- They appear in every ID token refresh (valid for ~1 hour)
- Firestore Rules can use them without additional lookups
- On logout/login, the token is refreshed and claims are re-verified by Firebase

This design ensures that tenant isolation is enforced at the **token level**, not just in Firestore rules.
