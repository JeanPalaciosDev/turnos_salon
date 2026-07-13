# TROUBLESHOOTING GUIDE - Phase 8: Multi-Tenant System

**Version**: 1.0  
**Last Updated**: 2026-07-13  
**Firebase Project**: turnos-salon-163b5

---

## Quick Reference

| Problem | Solution | Time to Fix |
|---------|----------|------------|
| User can't log in | Check custom claims, check tenant status | 5-10 min |
| Permission denied on data access | Check Firestore Rules, verify tenant_id | 10-15 min |
| Audit logs missing | Check Cloud Function deployment, check logs | 10-20 min |
| Tenant suspension not blocking | Re-deploy Firestore Rules | 5 min |
| App crashes on login | Check Firebase config, check custom claims | 15-20 min |
| Multi-tenant data mixed | Check tenant_id filtering in queries | 10-20 min |
| Performance slow | Check Firestore indexes, implement pagination | 20-30 min |

---

## Problem: User Can't Log In

### Symptom
- User enters email and password
- Clicks "Iniciar Sesión"
- Login fails with: "Usuario o contraseña inválidos"
- OR app shows blank screen or crashes

### Root Causes

#### 1. Custom Claims Not Set

**Check**:
```bash
# Firebase Console method:
1. Go to: https://console.firebase.google.com
2. Project: turnos-salon-163b5
3. Authentication → Users
4. Find user email
5. Click on user
6. Scroll to: "Custom claims"
7. If empty or missing: THIS IS THE PROBLEM
```

**Why it happens**:
- User created but setUserClaims not called
- Cloud Function failed silently
- User created manually without setting claims

**Fix**:
```bash
# Option 1: Re-call setUserClaims via Cloud Function
POST https://us-central1-turnos-salon-163b5.cloudfunctions.net/setUserClaims
Authorization: Bearer [admin_id_token]
Content-Type: application/json

{
  "uid": "[user_uid]",
  "tenant_id": "[tenant_id]",
  "role": "dueno|recepcionista|estilista"
}

# Option 2: Use Firebase Console (for testing only, NOT production)
1. Go to: Authentication → Users → Click user
2. Click: "Custom claims" edit button
3. Paste:
   {
     "tenant_id": "[tenant_id]",
     "role": "dueno"
   }
4. Save

# Option 3: Use Firebase Admin SDK (if you have direct access)
firebase = admin.initializeApp()
uid = "user_uid_here"
custom_claims = {
  "tenant_id": "tenant_id_here",
  "role": "dueno"
}
admin.auth().set_custom_user_claims(uid, custom_claims)
```

---

#### 2. Tenant Doesn't Exist

**Check**:
```bash
1. Firebase Console → Firestore
2. Collections → _platform → tenants
3. Look for: tenant_id matching custom claims
4. If not found: THIS IS THE PROBLEM
```

**Why it happens**:
- Tenant was hard-deleted
- Wrong tenant_id in custom claims
- Tenant never created

**Fix**:
```bash
# Option 1: Create tenant in turnos_admin app
1. Open turnos_admin
2. Click: "Crear Tenant"
3. Fill: name, owner email, password
4. Save
5. Verify in Firestore: _platform → tenants → new doc

# Option 2: Create manually via Firestore Console (testing only)
1. Firestore → _platform → tenants → Add document
2. Document ID: [tenant_id]
3. Add fields:
   - name: "Salon Name"
   - owner_email: "user@example.com"
   - estado: "activo"
   - created_at: [current timestamp]
   - branding: { color_primary: "#FF0000" }
```

---

#### 3. Tenant is Suspended

**Check**:
```bash
1. Firebase Console → Firestore
2. _platform → tenants → [tenant_id]
3. Check: estado field
4. If "suspendido" or "deleted": THIS IS THE PROBLEM
```

**Why it happens**:
- Tenant was explicitly suspended by admin
- Tenant was soft-deleted by admin
- Automated suspension (if configured)

**Fix**:
```bash
# In turnos_admin app:
1. Click: Tenant name
2. Click: "Reactivar" button (if suspended)
3. Click: "Recuperar" button (if deleted)
4. Confirm

# Or manually in Firestore Console:
1. _platform → tenants → [tenant_id] → Edit
2. Change: estado = "activo"
3. Save
```

---

#### 4. Firestore Rules Block Access

**Check**:
```bash
1. Firebase Console → Firestore → Rules
2. Look for: isTenantActive() function
3. Check: Rules deployed (green checkmark)
```

**Why it happens**:
- Rules deployed but have errors
- Rules not deployed yet
- Rules deny login attempt for some reason

**Fix**:
```bash
# Check if rules are deployed
firebase firestore:list-backups

# Re-deploy rules
firebase deploy --only firestore:rules

# View current rules in console
1. Firebase Console → Firestore → Rules
2. Click: View source
3. Look for errors or issues
```

---

#### 5. Password Incorrect

**Check**:
- Caps Lock on?
- Pasted password correctly?
- Password changed recently?

**Why it happens**:
- User entered wrong password
- Password mismatch between what user thinks and what was set

**Fix**:
```bash
# Reset password (if implemented)
1. Login screen: Click "¿Olvidaste tu contraseña?"
2. Enter email
3. Check email for reset link
4. Set new password

# Or delete user and recreate (testing environment)
1. Firebase Console → Authentication → Users
2. Find user → Click delete (three dots)
3. Confirm deletion
4. Recreate user in turnos_admin
```

---

### Debugging Steps

1. **Check logs in turnos_salon app**:
   - Enable debug mode in IDE
   - Watch for Firestore errors: "PERMISSION_DENIED", "UNAUTHENTICATED"
   - Take screenshot of error

2. **Check Firebase Cloud Function logs**:
   ```bash
   firebase functions:log --only setUserClaims
   # Look for: "Error", "exception", "failed"
   ```

3. **Check Firebase Console**:
   - Authentication → Users → Find user → Expand "Additional details"
   - Last sign-in time, auth methods, custom claims

4. **Test with curl** (if rules are issue):
   ```bash
   curl -X GET \
     -H "Authorization: Bearer [id_token]" \
     https://firestore.googleapis.com/v1/projects/turnos-salon-163b5/databases/\(default\)/documents/_platform/tenants
   
   # If response is "PERMISSION_DENIED" → Rules issue
   # If response is empty → Tenant doesn't exist
   ```

---

## Problem: User Sees "Acceso Denegado"

### Symptom
- User successfully logs in
- App starts loading /agenda
- Error message appears: "Acceso denegado" or "No tienes permisos"
- User cannot access any data

### Root Causes

#### 1. Custom Claims Missing or Wrong

**Check**:
```bash
1. Firebase Console → Authentication → Click user
2. Custom claims section
3. Should have: { "tenant_id": "xxx", "role": "yyy" }
4. If missing or incomplete: THIS IS THE PROBLEM
```

**Why it happens**:
- setUserClaims never ran
- setUserClaims ran but failed silently
- Claims were manually deleted

**Fix**:
```bash
# Use Cloud Function to re-set claims
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [admin_token]" \
  -d '{
    "uid": "[user_uid]",
    "tenant_id": "[tenant_id]",
    "role": "dueno"
  }' \
  https://us-central1-turnos-salon-163b5.cloudfunctions.net/setUserClaims
```

---

#### 2. Tenant is Suspended

**Check**:
```bash
1. Firebase Console → Firestore
2. _platform → tenants → [tenant_id]
3. Check: estado field = "activo"?
4. If "suspendido" or "deleted": THIS IS THE PROBLEM
```

**Why it happens**:
- Admin suspended the tenant
- Admin soft-deleted the tenant
- Tenant was auto-suspended (if configured)

**Fix**:
```bash
# Option 1: Reactivate in turnos_admin
1. Open turnos_admin
2. Find tenant
3. Click: "Reactivar"

# Option 2: Manual fix in Firestore
1. Firestore → _platform → tenants → [tenant_id]
2. Edit: estado = "activo"
3. Save
```

---

#### 3. Firestore Rules Have Syntax Error

**Check**:
```bash
1. Firebase Console → Firestore → Rules
2. Look for: Red error indicator
3. Click: "View source" and search for errors
```

**Why it happens**:
- Rules not deployed
- Rules syntax error (typo, logic error)
- Function call with wrong parameters

**Fix**:
```bash
# Download current rules and check
firebase firestore:get-rules > /tmp/current_rules.txt

# Check for errors
grep -i "error\|invalid" /tmp/current_rules.txt

# Re-deploy correct rules
firebase deploy --only firestore:rules

# If still error, rollback
git checkout HEAD~1 firestore.rules
firebase deploy --only firestore:rules
```

---

#### 4. Firestore Rules Don't Include All Collections

**Check**:
```bash
1. Firebase Console → Firestore → Rules
2. Search for: Collection name that's blocked
3. Example: If can't access turnos, search for "/turnos/"
4. Should have: allow read/write rules
```

**Why it happens**:
- Rules only written for some collections
- New collection added but rules not updated
- Copy-paste error in rules

**Fix**:
```bash
# Edit firestore.rules to add missing collection
# Example: If turnos collection missing:

match /tenants/{tenantId}/turnos/{turnoId} {
  allow read, write: if userInTenant(tenantId) && isTenantActive(tenantId);
}

# Then deploy
firebase deploy --only firestore:rules
```

---

#### 5. Tenant ID Mismatch

**Check**:
```bash
1. User's custom claims: { "tenant_id": "tenant_001", ... }
2. Firestore query: Querying collection tenants/tenant_001/?
3. If different IDs: THIS IS THE PROBLEM
```

**Why it happens**:
- User created in one tenant, assigned to another
- Copy-paste error in tenant_id
- Tenant ID changed but user claims not updated

**Fix**:
```bash
# Verify tenant_id is consistent
1. Firebase Console → Authentication → User
2. Note tenant_id from custom claims
3. Firestore → _platform → tenants → Verify this tenant exists
4. Firestore → tenants/{tenant_id} → Verify user's data is here

# If IDs don't match, fix custom claims
curl -X POST \
  -H "Authorization: Bearer [admin_token]" \
  -d '{ "uid": "...", "tenant_id": "correct_id", "role": "dueno" }' \
  https://us-central1-turnos-salon-163b5.cloudfunctions.net/setUserClaims
```

---

### Debugging Steps

1. **Log the error message**:
   - In turnos_salon app, capture full error text
   - Screenshot or copy to notes
   - Search error in Firestore documentation

2. **Check Firestore error codes**:
   | Code | Meaning |
   |------|---------|
   | PERMISSION_DENIED | Rules deny access |
   | UNAUTHENTICATED | User not logged in (token invalid) |
   | NOT_FOUND | Collection doesn't exist |
   | INVALID_ARGUMENT | Bad data sent |

3. **Test Firestore Rules simulator**:
   - Firebase Console → Firestore → Rules
   - Click: "Simulate" (top right)
   - Simulated user: Enter { tenant_id: "xxx", role: "dueno" }
   - Resource: /databases/(default)/documents/tenants/xxx/turnos
   - Request type: Read
   - Click: "Simulate"
   - See: Allow or Deny (and reason)

4. **Check Cloud Function logs** (if using custom function):
   ```bash
   firebase functions:log
   ```

---

## Problem: Audit Logs Not Appearing

### Symptom
- Admin creates user or tenant in turnos_admin
- Expected: Audit log entry in _platform/audit_logs
- Actual: No log found, collection empty or no new entries

### Root Causes

#### 1. Cloud Function Not Deployed

**Check**:
```bash
firebase functions:list
# Should see: setUserClaims [ACTIVE]

# Or in Firebase Console:
1. Cloud Functions → List
2. Look for: setUserClaims
3. Status should be: Green/Active
```

**Why it happens**:
- Function never deployed
- Deployment failed silently
- Deployment was rolled back

**Fix**:
```bash
# Deploy the function
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:setUserClaims

# Verify
firebase functions:list
```

---

#### 2. Cloud Function Has Error

**Check**:
```bash
firebase functions:log --only setUserClaims
# Look for: Error messages, exceptions

# Or in Firebase Console:
1. Cloud Functions → setUserClaims
2. Scroll to: Logs
3. Search for: "ERROR" entries
```

**Why it happens**:
- Function code has bug
- Function missing required libraries
- Firebase Admin SDK not initialized

**Fix**:
```bash
# Check logs for specific error
firebase functions:log --only setUserClaims | grep -i error

# Fix code in: functions/setUserClaims.js
# Verify: require('firebase-admin') present
# Verify: admin.initializeApp() called

# Redeploy
firebase deploy --only functions:setUserClaims
```

---

#### 3. Firestore Rules Block Audit Log Writes

**Check**:
```bash
1. Firebase Console → Firestore → Rules
2. Search for: "audit_logs"
3. Look for rules that allow writes
```

**Why it happens**:
- Rules deny writes to audit_logs
- Rules only allow reads, not writes
- Rules require wrong conditions

**Fix**:
```bash
# In firestore.rules, verify audit_logs section:

match /_platform/audit_logs/{logId} {
  // Only backend (Cloud Functions) can write
  allow read: if isSuperAdmin();
  allow write: if false; // Backend-only
}

# Or if using a Cloud Function to write:
# The function should use Admin SDK, which bypasses rules

# Deploy rules
firebase deploy --only firestore:rules
```

---

#### 4. Audit Log Write Not In Code

**Check**:
```bash
# Search codebase for audit log writes
grep -r "audit_logs" functions/
grep -r "audit_logs" lib/

# In turnos_admin app, check if action triggers write
# Example: When creating user, does it call logAudit()?
```

**Why it happens**:
- Audit logging not implemented in this action
- Code removed or commented out
- Wrong function called

**Fix**:
```bash
# Add to Cloud Function or app code:

// After creating user, write audit log
await admin.firestore()
  .collection('_platform/audit_logs')
  .add({
    acción: 'create_user',
    super_admin: admin_email,
    tenant_id: tenant_id,
    detalles: {
      email: user_email,
      rol: role,
    },
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
```

---

#### 5. No Actions Performed Yet

**Check**:
- Did you actually create a user/tenant?
- Did you see success message in app?
- Time: When was the audit log created?

**Why it happens**:
- Forgot to create user/tenant
- Creation failed silently
- Looking in wrong collection

**Fix**:
```bash
# Create a new user in turnos_admin
# Wait 5 seconds (Cloud Function might be slow)
# Refresh Firestore Console
# Look in: _platform → audit_logs (not tenants!)
```

---

### Debugging Steps

1. **Verify function deployment**:
   ```bash
   firebase functions:describe setUserClaims
   # Should show: status: ACTIVE, runtime: node16
   ```

2. **Check function code**:
   ```bash
   cat functions/setUserClaims.js
   # Verify: Firestore write for audit log
   # Verify: Error handling
   ```

3. **Test function manually**:
   ```bash
   curl -X POST \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer [admin_token]" \
     -d '{
       "uid": "test_uid",
       "tenant_id": "test_tenant",
       "role": "dueno"
     }' \
     https://us-central1-turnos-salon-163b5.cloudfunctions.net/setUserClaims
   
   # Check response: should have "success": true
   # If error, debug based on error message
   ```

4. **Check Cloud Function logs**:
   ```bash
   firebase functions:log --follow
   # Perform action in turnos_admin
   # Watch for function execution and any errors
   ```

---

## Problem: Tenant Suspension Not Blocking

### Symptom
- Admin suspends tenant (estado = "suspendido")
- User logged into turnos_salon continues to access data
- User can still see /agenda, create turnos, etc.
- Expected: User should see error "Tu salón ha sido suspendido"

### Root Causes

#### 1. Firestore Rules Not Deployed

**Check**:
```bash
1. Firebase Console → Firestore → Rules
2. Should show current rules deployed
3. If no rules or old rules: THIS IS THE PROBLEM
```

**Why it happens**:
- Rules never deployed
- Deployment failed
- Rollback accidentally reverted rules

**Fix**:
```bash
# Deploy rules
firebase deploy --only firestore:rules

# Verify deployment
firebase firestore:get-rules
# Should show isTenantActive() function
```

---

#### 2. isTenantActive() Function Wrong

**Check**:
```bash
1. Firebase Console → Firestore → Rules
2. Search for: function isTenantActive(
3. Verify: Checks estado == 'activo'
```

**Why it happens**:
- Function checks wrong field
- Function has typo in field name
- Function logic inverted

**Fix**:
```bash
# Correct function should be:
function isTenantActive(tenantId) {
  return get(/databases/$(database)/documents/_platform/tenants/$(tenantId))
    .data.estado == 'activo';
}

# If wrong, update firestore.rules and deploy
firebase deploy --only firestore:rules
```

---

#### 3. isTenantActive() Not Called in Rules

**Check**:
```bash
1. Firebase Console → Firestore → Rules
2. Search for: isTenantActive()
3. Should be called in allow statements
4. Example: allow read: if userInTenant(...) && isTenantActive(...);
```

**Why it happens**:
- Function defined but not called
- Rules only check tenant_id, not status
- Allow statement missing the check

**Fix**:
```bash
# All tenant data access should check:
match /tenants/{tenantId}/{document=**} {
  allow read: if userInTenant(tenantId) && isTenantActive(tenantId);
  allow write: if userInTenant(tenantId) && isTenantActive(tenantId) && [role checks];
}

# Update firestore.rules and deploy
firebase deploy --only firestore:rules
```

---

#### 4. App Caches Data Before Suspension

**Check**:
- Is app caching turnos locally (Hive, Riverpod cache, etc.)?
- Does app check tenant status on every read?
- Or just once on login?

**Why it happens**:
- App caches data (good for offline mode)
- But doesn't refresh when suspension happens
- User still sees cached data

**Fix**:
```dart
// In turnos_salon app code:
// Before showing cached data, check tenant status

Future<void> checkTenantStatus() async {
  final doc = await _firestore
    .doc('_platform/tenants/$tenantId')
    .get();
  
  final estado = doc.data()?['estado'];
  if (estado != 'activo') {
    // Show error and logout
    showError('Tu salón ha sido suspendido');
    logout();
  }
}

// Call this on app startup and periodically
```

---

#### 5. Firestore Doesn't Immediately Reflect Change

**Check**:
- How long after suspension was the test?
- Was Firestore updated in console?
- Did app refresh?

**Why it happens**:
- Firestore write delay (usually <1s)
- App caching not refreshed
- Browser cache

**Fix**:
```bash
# Ensure writes are confirmed
1. In turnos_admin, suspend tenant
2. Wait 1 second
3. Refresh Firestore Console (F5)
4. Verify: estado = "suspendido"
5. Then test app

# In app, force refresh
1. Close and reopen app
2. Try to load /agenda
3. Should now be blocked
```

---

### Debugging Steps

1. **Test Firestore Rules with simulator**:
   - Firebase Console → Firestore → Rules → Simulate
   - Simulated user: { tenant_id: "xxx", role: "dueno" }
   - Resource: /databases/(default)/documents/tenants/xxx/turnos
   - Request type: Read
   - Click: Simulate
   - Result should be: "Denied" (after suspension)

2. **Check what estado value actually is**:
   ```bash
   1. Firebase Console → Firestore
   2. _platform → tenants → [tenant_id]
   3. Click and view estado field
   4. Copy exact value (including whitespace, case)
   ```

3. **Test with curl**:
   ```bash
   # Suspended tenant should deny reads
   curl -X GET \
     -H "Authorization: Bearer [user_token]" \
     https://firestore.googleapis.com/v1/projects/turnos-salon-163b5/databases/\(default\)/documents/tenants/xxx/turnos
   
   # Should return: { error: { code: 7, message: "Permission denied" } }
   ```

---

## Problem: Multi-Tenant Data Mixed

### Symptom
- Create data in Tenant A
- Switch to Tenant B user
- Tenant B user can see Tenant A's data
- Expected: Complete isolation

### Root Causes

#### 1. Queries Not Filtered by tenant_id

**Check**:
```bash
# In turnos_salon app source code, find query:
# Example: firebase.turnos.get()

# Should include: .where('tenant_id', '==', currentTenantId)
# Should NOT be: .get() without tenant_id filter
```

**Why it happens**:
- Old code didn't need tenant filtering (single tenant)
- Refactoring incomplete
- Copy-paste error removed filter

**Fix**:
```dart
// WRONG (gets all turnos from all tenants)
db.collection('tenants/$tenantId/turnos').get()

// RIGHT (scoped to tenant)
db.collection('tenants/$tenantId/turnos')
  .where('tenant_id', '==', currentTenantId)  // Extra safety check
  .get()

// Even safer (scoped by path alone)
db.collection('tenants/$tenantId/turnos').get()
// Path itself enforces tenant isolation
```

---

#### 2. Firestore Rules Missing Tenant Check

**Check**:
```bash
1. Firebase Console → Firestore → Rules
2. Look for: match /tenants/{tenantId}/
3. Should have: userInTenant(tenantId) check
4. If missing: THIS IS THE PROBLEM
```

**Why it happens**:
- Rules too permissive
- Rules not deployed
- Rules have syntax error

**Fix**:
```bash
# In firestore.rules:

match /tenants/{tenantId}/{document=**} {
  // Every read/write must check user is in tenant
  allow read, write: if userInTenant(tenantId) && isValidRole();
}

# Deploy
firebase deploy --only firestore:rules
```

---

#### 3. Cross-Tenant Queries Possible (app allows it)

**Check**:
```bash
# In app code, search for:
# - Hard-coded tenant IDs
# - User can input tenant_id from URL/form
# - No validation of tenant_id
```

**Why it happens**:
- App doesn't validate tenant_id before querying
- Admin panel allows querying any tenant (intentional, but risky)
- No input validation

**Fix**:
```dart
// WRONG: User can pass any tenant_id
final tenantId = url.queryParameters['tenant_id'];
final data = await db.collection('tenants/$tenantId/turnos').get();

// RIGHT: Use current user's tenant_id
final tenantId = getUserTenantId(); // From custom claims
final data = await db.collection('tenants/$tenantId/turnos').get();
```

---

#### 4. Shared Collection Without Tenant Scoping

**Check**:
```bash
# Check if data stored in wrong collection

# WRONG: Shared collection, all tenants
db.collection('turnos').doc(turnoId).set({ ... })

# RIGHT: Tenant-scoped collection
db.collection('tenants/$tenantId/turnos').doc(turnoId).set({ ... })
```

**Why it happens**:
- Migration incomplete
- New code added to wrong collection
- Copy-paste from old non-multi-tenant code

**Fix**:
```bash
# Move all data to tenant-scoped collections

# In Firebase Console:
1. Firestore → Collections → turnos
2. Copy each document
3. Navigate to: tenants/{tenantId}/turnos
4. Paste documents
5. Delete from root turnos collection

# Or via Cloud Function (batch operation)
```

---

### Debugging Steps

1. **Verify collection structure**:
   ```bash
   1. Firebase Console → Firestore
   2. Click: All collections
   3. Should see:
      - tenants/[id]/turnos/ (has data)
      - tenants/[id]/clientes/ (has data)
      - Should NOT see: /turnos/ at root
   ```

2. **Check queries in app logs**:
   ```bash
   # In Android logcat or iOS console, watch for:
   # - Firestore queries
   # - Should show: "tenants/{id}/turnos"
   # - Should NOT show: "turnos"
   ```

3. **Manually query to verify**:
   ```bash
   # Firebase Console → Firestore
   # Run query on tenants/{tenant_id}/turnos
   # Compare to tenants/{other_tenant_id}/turnos
   # Should be different data
   ```

---

## Problem: Slow Performance

### Symptom
- First login takes >5 seconds
- Loading agenda with many turnos is slow (>2 seconds)
- Filters lag
- App feels unresponsive

### Root Causes

#### 1. No Firestore Indexes

**Check**:
```bash
firebase firestore:indexes:list
# Should see: Composite indexes for common queries
```

**Why it happens**:
- Indexes not created
- Queries don't use best index
- Firestore doing full collection scan

**Fix**:
```bash
# Create indexes in Firebase Console
1. Firestore → Indexes
2. Look for: Missing indexes (red icon)
3. Click: Create index
4. Or create manually:
   - Collection: tenants/{tenantId}/turnos
   - Fields: date (ASC), status (DESC)
   - Scope: Collection

# Or via Firebase CLI
firebase firestore:indexes:list --json > current_indexes.json
# Edit file to add new indexes
firebase firestore:indexes:write updated_indexes.json
```

---

#### 2. Loading All Data at Once

**Check**:
```dart
// WRONG: Gets all turnos (could be 1000s)
final turnos = await db.collection('tenants/$tenantId/turnos').get();

// RIGHT: Limit and paginate
final turnos = await db.collection('tenants/$tenantId/turnos')
  .limit(50)
  .get();
```

**Why it happens**:
- Original single-tenant code didn't paginate
- No limit() in queries
- No date range filter

**Fix**:
```dart
// Add pagination to queries

// In repository or provider
Future<List<Turno>> getTurnos({required int page}) {
  final query = db.collection('tenants/$tenantId/turnos')
    .orderBy('date', descending: true)
    .limit(50)  // 50 per page
    .offset(page * 50);
  
  return query.get().then((snap) => 
    snap.docs.map((doc) => Turno.fromFirestore(doc)).toList()
  );
}

// Use in UI with FutureBuilder or pagination provider
```

---

#### 3. Missing Network Connection

**Check**:
- Device network is slow (WiFi 2.4GHz vs 5GHz)
- Metered connection
- High latency (test with curl)

**Why it happens**:
- Device on poor WiFi
- 3G/LTE network
- Emulator with limited bandwidth

**Fix**:
```bash
# Move to better network:
1. Connect to 5GHz WiFi
2. Reduce distance to router
3. Test on real device (not emulator)

# Or optimize queries to reduce data transfer:
- Add .select(['field1', 'field2']) to only fetch needed fields
- Use .limit(10) instead of .limit(100)
```

---

#### 4. Inefficient App Code

**Check**:
```dart
// WRONG: Rebuild entire list on every change
StreamBuilder(
  stream: db.collection('tenants/$tenantId/turnos').snapshots(),
  builder: (context, snapshot) {
    // Entire list rebuilt even if 1 doc changed
    return ListView.builder(itemCount: snapshot.data!.docs.length, ...);
  },
)

// RIGHT: Use efficient caching/pagination
```

**Why it happens**:
- StreamBuilder rebuilds entire widget tree
- No caching of results
- No pagination

**Fix**:
```dart
// Use Riverpod with caching
final turnosProvider = FutureProvider((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  return getTurnos(tenantId);
});

// Widget uses cached data, only rebuilds if data changes
ConsumerWidget(builder: (context, ref, child) {
  final turnos = ref.watch(turnosProvider);
  // ...
})
```

---

#### 5. Firestore Cold Start

**Check**:
- First operation takes longer than subsequent
- Repeated queries are faster

**Why it happens**:
- Firestore SDK initializing
- Cold start penalty (first request)
- Network latency

**Fix**:
```bash
# This is normal and expected
# Mitigation:
# 1. Pre-warm Firebase on app startup
# 2. Cache results locally (Hive)
# 3. Accept slower first login
```

---

### Debugging Steps

1. **Measure query time**:
   ```dart
   // Wrap query in timer
   final start = DateTime.now();
   final result = await db.collection(...).get();
   final duration = DateTime.now().difference(start);
   print('Query took: ${duration.inMilliseconds}ms');
   ```

2. **Check Firestore usage metrics**:
   - Firebase Console → Firestore → Usage
   - Look for: Total reads, writes, deletes
   - Compare to expected queries
   - If much higher than expected, there are extra queries

3. **Profile app with DevTools**:
   - `flutter run --profile`
   - Open DevTools
   - Performance tab
   - Record frame
   - Look for: Long frames, GC pauses, jank

4. **Reduce data with .select()**:
   ```dart
   // Instead of:
   db.collection('tenants/$tenantId/turnos').get()
   
   // Do:
   db.collection('tenants/$tenantId/turnos')
     .select(['id', 'date', 'clienteName'])  // Only needed fields
     .get()
   ```

---

## Problem: App Crashes on Login

### Symptom
- User enters credentials
- Clicks "Iniciar Sesión"
- App crashes with error
- No error message shown

### Root Causes

#### 1. Firebase Config Missing

**Check**:
```bash
1. In turnos_salon app: lib/firebase_options.dart
2. Should exist and have: firebaseProjectId, etc.
```

**Why it happens**:
- File not generated (`flutterfire configure`)
- File deleted or corrupted
- App using wrong Firebase project

**Fix**:
```bash
# Regenerate Firebase config
flutterfire configure

# Select project: turnos-salon-163b5
# Select iOS, Android, Web as needed
```

---

#### 2. Null Pointer Exception (custom claims)

**Check**:
```dart
// WRONG: Assumes custom claims exist
final tenantId = authUser.customClaims['tenant_id'];  // Crash if null

// RIGHT: Check for null
final tenantId = authUser.customClaims?['tenant_id'] ?? 'unknown';
```

**Why it happens**:
- Custom claims not set before login
- App assumes claims will always exist

**Fix**:
```dart
// In auth repository or service:
Future<void> login(email, password) async {
  final result = await _auth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  
  final claims = result.user?.getCustomClaims() ?? {};
  if (!claims.containsKey('tenant_id')) {
    // Custom claims missing
    throw Exception('Custom claims not set for user');
  }
  
  return result;
}
```

---

#### 3. Firestore Initialization Error

**Check**:
```dart
// Is Firestore initialized?
final firestore = FirebaseFirestore.instance;

// Check: App initialized before using Firestore
await Firebase.initializeApp(...);
```

**Why it happens**:
- Firebase.initializeApp() not called
- Called but failed
- Wrong Firebase project

**Fix**:
```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // BEFORE: Using FirebaseFirestore
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(MyApp());
}
```

---

#### 4. Riverpod/Provider Error

**Check**:
```dart
// Are providers correctly defined?
// Is ProviderScope wrapping root widget?
```

**Why it happens**:
- Provider has error in initialization
- ProviderScope missing from widget tree
- Circular provider dependency

**Fix**:
```dart
// Ensure ProviderScope at root
void main() {
  runApp(
    ProviderScope(  // Wraps entire app
      child: MyApp(),
    ),
  );
}

// Check provider initialization
final authProvider = StateNotifierProvider((ref) {
  try {
    return AuthService();
  } catch (e) {
    print('Provider error: $e');
    rethrow;  // Re-throw for debugging
  }
});
```

---

#### 5. Token Verification Fails

**Check**:
```dart
// During login, does app verify token?
// Does verification throw exception?
```

**Why it happens**:
- Custom claims verification fails
- Token is invalid or expired
- Wrong verification logic

**Fix**:
```dart
// In auth service:
Future<UserCredential> loginUser(email, password) async {
  try {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    // Force refresh custom claims
    await cred.user?.reload();
    
    return cred;
  } catch (e) {
    print('Login error: $e');
    // Show user-friendly error
    rethrow;
  }
}
```

---

### Debugging Steps

1. **Check device logs**:
   ```bash
   # Android
   adb logcat | grep -i "flutter\|error\|exception"
   
   # iOS
   xcrun simctl spawn booted log stream --predicate 'eventMessage contains[c] "flutter"'
   ```

2. **Add try-catch logging**:
   ```dart
   // Wrap main() with error handler
   void main() {
     WidgetsFlutterBinding.ensureInitialized();
     
     FlutterError.onError = (details) {
       print('Flutter error: ${details.exception}');
       print('Stack: ${details.stack}');
     };
     
     runApp(MyApp());
   }
   ```

3. **Test on device vs emulator**:
   - Emulator might have different behavior
   - Real device has real network
   - Try both to narrow down issue

---

## Escalation Procedures

If you cannot resolve an issue using this guide:

1. **Gather information**:
   - Device type and OS version
   - App version
   - Firebase project
   - User email
   - Exact error message
   - Steps to reproduce

2. **Contact**:
   - Tech Lead: [Lead email]
   - Project Manager: [Manager email]
   - Firebase support: https://firebase.google.com/support

3. **Create issue**:
   - GitHub issue with logs
   - Include error stack trace
   - Include Firebase function logs
   - Include Firestore Rules (if applicable)

4. **Fallback**:
   - Rollback to previous version
   - Disable feature temporarily
   - Enable emulator for testing

---

**End of TROUBLESHOOTING.md**
