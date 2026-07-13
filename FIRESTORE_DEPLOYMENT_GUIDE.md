# Firestore Deployment Guide - Phase 7

**Status**: Ready for Deployment  
**Last Updated**: 2026-07-13  
**Project**: turnos-salon-163b5  

---

## 📋 Pre-Deployment Checklist

- [ ] `firestore.rules` syntax validated (no parse errors)
- [ ] All helper functions defined and working
- [ ] Development/staging testing complete
- [ ] No unresolved TODOs in rules file
- [ ] Team notified of deployment window
- [ ] Backup of current rules saved
- [ ] Firebase CLI installed and logged in
- [ ] Permission to deploy: Contact Firebase project admin

---

## 🔧 Installation & Setup

### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 2. Authenticate
```bash
firebase login
# Opens browser for Google authentication
```

### 3. Select Project
```bash
firebase use turnos-salon-163b5
```

### 4. Verify Project Connection
```bash
firebase projects:list
# Should show: turnos-salon-163b5 (selected)
```

---

## ✅ Validation (Before Deploying)

### 1. Syntax Validation
```bash
# Check if rules have valid syntax (no parser errors)
firebase firestore:describe-schema
```

**Expected Output**:
```
Rules syntax is valid.
```

**If Error**:
- Check for unclosed brackets/braces in firestore.rules
- Verify function names match their calls
- Look for typos in helper function definitions

### 2. Rule Coverage Analysis
```bash
# Check which collections are covered by rules
firebase firestore:describe-schema --pretty
```

**Should Cover**:
- ✅ `_platform/tenants/{tenant_id}`
- ✅ `_platform/usuarios/{tenant_id}/{user_id}`
- ✅ `_platform/audit_logs/{log_id}`
- ✅ `tenants/{tenant_id}/servicios/{servicio_id}`
- ✅ `tenants/{tenant_id}/trabajadores/{trabajador_id}`
- ✅ `tenants/{tenant_id}/clientes/{cliente_id}`
- ✅ `tenants/{tenant_id}/turnos/{turno_id}`
- ✅ `tenants/{tenant_id}/usuarios/{user_id}`

### 3. Local Testing (Optional)
```bash
# Start Firestore emulator
firebase emulators:start --only firestore

# In separate terminal, run tests against emulator
firebase emulators:exec "./test-rules.sh"

# Stop emulator
# Press Ctrl+C in emulator terminal
```

---

## 🚀 Deployment Steps

### Option A: Deploy Rules Only (Recommended)

**Fastest and safest** - Only updates Firestore rules, doesn't touch other services.

```bash
firebase deploy --only firestore:rules
```

**Output**:
```
=== Deploying to 'turnos-salon-163b5'...

i  firestore: checking firestore.rules for compilation errors...
✔  firestore: rules compiled successfully
i  firestore: uploading rules...
✔  firestore: released new rules...

✔  Deploy complete!
```

**Time**: 10-30 seconds

### Option B: Full Firebase Deployment

**Deploys all changes** (functions, hosting, rules, etc.)

```bash
firebase deploy
```

**Caution**: Only use if you're also updating Cloud Functions or other services.

---

## ✔️ Post-Deployment Verification

### 1. Confirm Rules Deployed
```bash
firebase firestore:describe-schema
```

**Expected**: Rules version should show timestamp of deployment

### 2. Check Firebase Console
1. Go to: https://console.firebase.google.com/
2. Select project: `turnos-salon-163b5`
3. Navigate: Firestore → Rules
4. Verify: Rules content matches your latest `firestore.rules`

### 3. Quick Access Test
```bash
# Create test script to verify rules are live
# (See Testing section below)
```

---

## 🧪 Manual Testing (Post-Deployment)

### Test Environment Setup

You'll need test users with proper custom claims:

**Super-Admin User**:
- Email: admin@turnos-salon.com
- Custom Claims: `{ "role": "super_admin" }`
- Expected: Can read `_platform/` collections

**Tenant User (Dueno)**:
- Email: owner@salon-luna.com
- Tenant ID: salon-luna-xyz
- Role: dueno
- Custom Claims: `{ "tenant_id": "salon-luna-xyz", "role": "dueno" }`
- Expected: Can read/write tenant data

**Tenant User (Recepcionista)**:
- Email: receptionist@salon-luna.com
- Tenant ID: salon-luna-xyz
- Role: recepcionista
- Custom Claims: `{ "tenant_id": "salon-luna-xyz", "role": "recepcionista" }`
- Expected: Limited write access (no delete)

---

### Test 1: Super-Admin Access to Platform Collections

**Test Setup**:
- User: Super-Admin (custom claim: role='super_admin')
- Action: Read `_platform/tenants/`

**Firebase Console**:
1. Login as super-admin user
2. Firestore → Data → `_platform` → `tenants`
3. Try to read any document

**Expected Result**: ✅ Can read all tenant documents

**Code Test** (if using API):
```javascript
const db = firebase.firestore();
db.collection('_platform').doc('tenants').collection('_platform/tenants')
  .get()
  .then(snap => console.log("SUCCESS: Read tenants", snap.docs.length))
  .catch(err => console.log("FAILED:", err.message));
```

---

### Test 2: Regular User Cannot Access Platform Collections

**Test Setup**:
- User: Recepcionista in salon-luna-xyz
- Action: Try to read `_platform/tenants/`

**Expected Result**: ❌ Permission Denied

**Firebase Console**:
1. Logout super-admin
2. Login as recepcionista user
3. Try to access `_platform` → `tenants` collection
4. Should see: "Permission denied"

---

### Test 3: Cross-Tenant Access Prevention

**Test Setup**:
- User: Dueno in salon-luna-xyz
- Action: Try to read `tenants/different-tenant-xyz/turnos/`

**Expected Result**: ❌ Permission Denied

**Verify**: Custom claim tenant_id doesn't match path tenant_id

---

### Test 4: Suspended Tenant Blocking

**Test Setup**:
- User: Dueno in salon-luna-xyz
- Action: Read `tenants/salon-luna-xyz/turnos/`
- Then: Super-admin suspends tenant (change `estado: "suspendido"`)
- Action: Try to read turnos again

**Expected Result**:
- First read: ✅ Success
- After suspension: ❌ Permission Denied

**Simulate Suspension** (console):
```javascript
// Super-admin only
const admin = require('firebase-admin');
await admin.firestore()
  .collection('_platform').doc('tenants').collection('tenants')
  .doc('salon-luna-xyz')
  .update({ estado: 'suspendido' });
```

---

### Test 5: Estilista Read-Only Access

**Test Setup**:
- User: Estilista in salon-luna-xyz
- Action: Try to CREATE new turno

**Expected Result**: ❌ Permission Denied

**Verify**: Role is 'estilista' and rule checks for isDueno() or isRecepcionista()

---

### Test 6: Recepcionista Can Create (Not Delete)

**Test Setup**:
- User: Recepcionista in salon-luna-xyz
- Action 1: CREATE new turno ✅ Should succeed
- Action 2: DELETE turno ❌ Should fail

**Expected Results**:
- Create: ✅ Permission granted
- Delete: ❌ Permission denied

---

### Test 7: Audit Log Immutable

**Test Setup**:
- User: Super-Admin
- Action: Try to DELETE document in `_platform/audit_logs/`

**Expected Result**: ❌ Permission Denied (deletes never allowed)

---

### Test 8: User Reading Own Platform Data

**Test Setup**:
- User: Dueno in salon-luna-xyz with UID: user-123
- Action: Read `_platform/usuarios/salon-luna-xyz/user-123/`

**Expected Result**: ✅ Can read own user document

---

### Test 9: User Cannot Read Other Users' Data

**Test Setup**:
- User: Dueno in salon-luna-xyz with UID: user-123
- Action: Read `_platform/usuarios/salon-luna-xyz/user-456/` (different user)

**Expected Result**: ❌ Permission Denied (only own or super-admin)

---

### Test 10: Tenant Active Check Required

**Test Setup**:
- User: Recepcionista in salon-luna-xyz
- Action: Read `tenants/salon-luna-xyz/servicios/`
- Verify: Works when `estado: "activo"`
- Change: Set `estado: "suspendido"`
- Action: Try again

**Expected Results**:
- Active tenant: ✅ Can read
- Suspended tenant: ❌ Permission Denied

---

## ⏮️ Rollback Procedure

If issues occur after deployment:

### Immediate Rollback (Recommended)
```bash
firebase rollback
```

**Effect**: Reverts to previous Firestore rules version
**Time**: 5-10 seconds

**Prompts**:
```
Found Firestore rules version: 2024-07-13 15:30:00 UTC
OK to rollback? (y/n)
```

### Manual Rollback
If `firebase rollback` doesn't work:

1. Get previous rules from version control:
   ```bash
   git log --oneline firestore.rules
   git show PREVIOUS_COMMIT:firestore.rules > firestore.rules.backup
   ```

2. Restore:
   ```bash
   git checkout HEAD~1 firestore.rules
   firebase deploy --only firestore:rules
   ```

---

## 🔍 Monitoring Post-Deployment

### Check Firestore Logs

1. Go to: https://console.cloud.google.com/
2. Select project: turnos-salon-163b5
3. Navigate: Logs → Firestore Logs
4. Filter by:
   - Severity: Error (watch for permission denials)
   - Resource: Cloud Firestore
   - Time range: Last hour

### Common Error Patterns

**Pattern**: Many "Permission Denied" errors
- Cause: User custom claims not set, or rules too restrictive
- Fix: Verify custom claims, test with known-good user

**Pattern**: Tenant users can't read own data
- Cause: `isTenantActive()` failing (tenant suspended or estado field missing)
- Fix: Check `_platform/tenants/{tenant_id}.estado` value

**Pattern**: Super-admin can't read `_platform/` collections
- Cause: User custom claim `role` != 'super_admin'
- Fix: Set correct custom claims for admin user

---

## 📊 Performance Monitoring

### Read Cost Tracking

Each operation now reads tenant estado for active check:

```
Cost per user action = 1 (access check) + 0 (if cached)
Example: User reads 10 turnos = 11 reads total (1 tenant check + 10 docs)
```

### Optimization Opportunity

Store `estado` in custom claims:
- **Current**: 1 read per operation (isTenantActive())
- **Optimized**: 0 reads per operation (check claim)
- **Trade-off**: Must update claims when tenant suspended
- **Implementation**: Add Cloud Task to update custom claims on suspension

---

## 🚨 Troubleshooting Deployment

### Issue: Deployment Fails with "Syntax Error"

**Solution**:
1. Check firestore.rules for unclosed brackets
2. Verify function names and signatures
3. Run: `firebase firestore:describe-schema` for details
4. Fix errors, retry: `firebase deploy --only firestore:rules`

### Issue: "Project Not Set"

**Solution**:
```bash
firebase use turnos-salon-163b5
firebase deploy --only firestore:rules
```

### Issue: "Permission Denied" on Deploy

**Solution**:
1. Verify logged-in user has Firebase Admin role
2. Run: `firebase login --reauth`
3. Check project IAM: https://console.cloud.google.com/ → IAM
4. Contact project admin if needed

### Issue: Rules Deployed but Tests Still Fail

**Solution**:
1. Clear browser cache and logout
2. Re-login to get fresh token with new custom claims
3. Refresh Firestore data in console
4. Wait 10 seconds for rules propagation (usually instant)
5. Try test again

---

## 📝 Deployment Checklist (Final)

Before declaring deployment successful:

- [ ] `firebase firestore:describe-schema` shows valid syntax
- [ ] All 10 manual tests pass (see Testing section)
- [ ] Firebase Console rules match deployed version
- [ ] No permission denied errors in logs for legitimate users
- [ ] Suspended tenant blocking works (users get access denied)
- [ ] Cross-tenant access properly blocked
- [ ] Audit logs cannot be deleted
- [ ] Performance metrics acceptable (no spike in reads)
- [ ] Team notified of successful deployment
- [ ] Deployment tagged in git: `git tag -a phase-7-rules-deployed -m "Firestore Rules Phase 7"`

---

## 📞 Support & Escalation

### If Users Report Access Issues

1. **Collect info**:
   - User's email
   - Tenant they're trying to access
   - Error message
   - What action they were doing

2. **Check**:
   - User's custom claims: `firebase auth:get USER_UID`
   - Tenant estado: `firebase firestore:inspect-schema`
   - Firestore logs for permission denials

3. **Escalate**:
   - If custom claims wrong: Contact super-admin
   - If rules wrong: Create issue in `FIRESTORE_RULES_SUMMARY.md`
   - If tenant suspended: Verify with business team

### Rollback Decision Tree

```
User reports access blocked?
├─ Custom claims wrong?
│  └─ Fix claims, test again (5 min)
├─ Tenant suspended?
│  └─ Check with business team, reactivate if needed
├─ Rules broke something?
│  ├─ One or two tests fail?
│  │  └─ Fix rules, redeploy
│  └─ Multiple failures?
│     └─ Run: firebase rollback
└─ Other issue?
   └─ Check TROUBLESHOOTING section
```

---

## 🎯 Next Steps (Post-Deployment)

1. **Update Client Apps** (Phase 8):
   - Add error handling for suspended tenants
   - Show "Tu salón ha sido suspendido" message
   - Implement graceful degradation

2. **Monitor & Optimize** (Phase 9):
   - Track read costs from `isTenantActive()` checks
   - If cost > threshold: Move estado to custom claims

3. **Security Audit** (Phase 10):
   - Review access logs quarterly
   - Look for patterns of rule violations
   - Update documentation if business rules change

4. **Team Training**:
   - Onboard new developers on rules
   - Document custom claim setup process
   - Keep FIRESTORE_RULES_SUMMARY.md updated

---

**End of Deployment Guide**

Questions? See `FIRESTORE_RULES_SUMMARY.md` for detailed rule documentation.
