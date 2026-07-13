# Firestore Rules - Quick Reference Card

**For**: Developers using the APP CLIENTE and APP ADMIN  
**Version**: Phase 7 (2026-07-13)  
**File**: `D:\Work\turnos_salon\firestore.rules`

---

## 🎯 TL;DR - What Can I Do?

### If You Are... `SUPER_ADMIN`

**Custom Claims**:
```json
{ "role": "super_admin" }
```

**You Can**:
- ✅ Read `_platform/tenants/` (view all salons)
- ✅ Read `_platform/usuarios/` (view all users)
- ✅ Read `_platform/audit_logs/` (view action logs)
- ✅ Read any `tenants/{tenant_id}/` data
- ❌ Write directly (use Cloud Functions instead)

**Common Tasks**:
1. Create tenant (via Cloud Function)
2. Suspend tenant (via Cloud Function)
3. Review audit logs
4. View user management data

---

### If You Are... `DUENO` (Salon Owner)

**Custom Claims**:
```json
{ "tenant_id": "salon-luna-xyz", "role": "dueno" }
```

**You Can**:
- ✅ Read all data in your salon: `tenants/salon-luna-xyz/*`
- ✅ Create/Edit services, staff, clients, turnos
- ✅ Delete services, staff, clients, turnos
- ✅ Create users and assign roles
- ❌ Access other salons' data
- ❌ Access platform-level data

**Common Tasks**:
1. Manage service catalog
2. Manage staff roster
3. Manage client database
4. Create/manage appointments
5. View team members and their roles

---

### If You Are... `RECEPCIONISTA` (Receptionist)

**Custom Claims**:
```json
{ "tenant_id": "salon-luna-xyz", "role": "recepcionista" }
```

**You Can**:
- ✅ Read all data in your salon: `tenants/salon-luna-xyz/*`
- ✅ Create/Edit clients and turnos
- ✅ Create/Edit services (usually via dueno)
- ❌ Delete anything (only dueno can delete)
- ❌ Create/manage users or staff
- ❌ Access other salons' data

**Common Tasks**:
1. Book new appointments (create turnos)
2. Manage client info (create/edit clientes)
3. View service catalog
4. View staff availability
5. View and update appointment status

---

### If You Are... `ESTILISTA` (Stylist)

**Custom Claims**:
```json
{ "tenant_id": "salon-luna-xyz", "role": "estilista" }
```

**You Can**:
- ✅ Read data in your salon: `tenants/salon-luna-xyz/*`
- ✅ View assigned appointments
- ✅ View clients and services
- ✅ View staff roster
- ❌ Create new appointments
- ❌ Create/delete anything
- ❌ Access other salons' data

**Common Tasks**:
1. View my today's appointments
2. Check client preferences
3. View service details
4. See staff availability
5. View client contact info

---

## 🚫 What's Blocked?

### You CANNOT Do (Client Side)

```javascript
// ❌ Create a new tenant - Blocked
firebase.firestore()
  .collection('_platform').doc('tenants').collection('tenants')
  .add({ name: 'New Salon' });

// ❌ Create a new user - Blocked
firebase.firestore()
  .collection('_platform').doc('usuarios')
  .collection('salon-luna-xyz')
  .add({ email: 'user@example.com' });

// ❌ Delete audit log - Blocked
firebase.firestore()
  .collection('_platform').doc('audit_logs')
  .delete();

// ❌ As estilista: Create turno - Blocked
firebase.firestore()
  .collection('tenants').doc('salon-luna-xyz')
  .collection('turnos')
  .add({ cliente_id: '...', fecha: '...' });

// ❌ As recepcionista: Delete client - Blocked
firebase.firestore()
  .collection('tenants').doc('salon-luna-xyz')
  .collection('clientes')
  .doc('cliente-id')
  .delete();
```

**Why These Are Blocked**:
- System operations must go through Cloud Functions
- Ensures audit trail and data consistency
- Prevents accidental/malicious changes from client app

### You CAN Do (Examples)

```javascript
// ✅ As dueno: Create new turno
firebase.firestore()
  .collection('tenants').doc('salon-luna-xyz')
  .collection('turnos')
  .add({
    cliente_id: 'cliente-123',
    trabajador_id: 'trabajador-456',
    servicio_id: 'servicio-789',
    fecha: '2024-07-20',
    hora_inicio: new Date('2024-07-20T10:00:00Z'),
    duracion_minutos: 90,
    estado: 'confirmado',
    precio: 85.00
  });

// ✅ As recepcionista: Update client info
firebase.firestore()
  .collection('tenants').doc('salon-luna-xyz')
  .collection('clientes')
  .doc('cliente-123')
  .update({ telefono: '+34 666 555 444' });

// ✅ As dueno: Delete service
firebase.firestore()
  .collection('tenants').doc('salon-luna-xyz')
  .collection('servicios')
  .doc('servicio-789')
  .delete();

// ✅ As estilista: Read today's appointments
firebase.firestore()
  .collection('tenants').doc('salon-luna-xyz')
  .collection('turnos')
  .where('trabajador_id', '==', myTrabajadorId)
  .where('fecha', '==', '2024-07-13')
  .get();

// ✅ All roles: Read client preferences
firebase.firestore()
  .collection('tenants').doc('salon-luna-xyz')
  .collection('clientes')
  .doc('cliente-123')
  .get();
```

---

## 🚨 Error Handling

### "Permission Denied" Error

**Means**: Rule blocked your access (access control working!)

**Possible Causes**:

| Error | Reason | Fix |
|-------|--------|-----|
| `permission-denied` | User not in tenant | Check custom claim `tenant_id` |
| `permission-denied` | Tenant suspended | Admin must reactivate salon |
| `permission-denied` | User role too low | Use a higher role (dueno > recepcionista > estilista) |
| `permission-denied` | Operation not allowed | Check what operation you're attempting |
| `permission-denied` | Not authenticated | Login again (token might be expired) |

**Debug Code**:
```javascript
// Check your custom claims
const user = firebase.auth().currentUser;
const token = await user.getIdTokenResult();
console.log('Tenant ID:', token.claims.tenant_id);
console.log('Role:', token.claims.role);

// Should see:
// Tenant ID: salon-luna-xyz
// Role: dueno
```

---

## 📊 Collection Access Matrix

| Collection | Super-Admin | Dueno | Recepcionista | Estilista |
|-----------|------------|-------|---------------|-----------|
| **_platform/tenants** | 🔍 Read | ❌ No | ❌ No | ❌ No |
| **_platform/usuarios** | 🔍 Read ✏️ Write | ❌ No | ❌ No | ❌ No |
| **_platform/audit_logs** | 🔍 Read | ❌ No | ❌ No | ❌ No |
| **tenants/{tenant_id}** | 🔍 Read | 🔍 Read | 🔍 Read | 🔍 Read |
| **servicios** | 🔍 Read | ✏️ RW🗑️D | 🔍 Read | 🔍 Read |
| **trabajadores** | 🔍 Read | ✏️ RW🗑️D | 🔍 Read | 🔍 Read |
| **clientes** | 🔍 Read | ✏️ RW🗑️D | ✏️ RW | 🔍 Read |
| **turnos** | 🔍 Read | ✏️ RW🗑️D | ✏️ RW | 🔍 Read |
| **usuarios** | 🔍 Read | 🔍 Read | 🔍 Read | 🔍 Read |

**Legend**:
- 🔍 Read = Can read documents
- ✏️ RW = Can read & write (create/update)
- 🗑️ D = Can delete
- ❌ No = No access

---

## 🔑 Custom Claims Explained

Your access is determined by the **custom claims** in your Firebase Auth token.

### What Are Custom Claims?

Claims are JSON metadata attached to your auth token:

```javascript
// Your custom claims look like:
{
  "tenant_id": "salon-luna-xyz",
  "role": "dueno"
}

// Super-admin custom claims:
{
  "role": "super_admin"
}
```

### When Are They Used?

1. **You log in** → Firebase Auth issues token with claims
2. **You make Firestore request** → Claims travel with request
3. **Rules check claims** → `userTenantId()`, `userRole()`, `isSuperAdmin()`
4. **Access granted/denied** → Based on claim values

### Who Sets Them?

- **Super-admin only** (via Cloud Function or Firebase Admin SDK)
- You cannot set your own claims
- If wrong: Contact your salon owner or platform admin

### How to Check Your Claims?

```javascript
// In browser console (after login)
const user = firebase.auth().currentUser;
const token = await user.getIdTokenResult();
console.log('Full token:', token);
console.log('My claims:');
console.log('  tenant_id:', token.claims.tenant_id);
console.log('  role:', token.claims.role);
```

**Example Output**:
```
My claims:
  tenant_id: salon-luna-xyz
  role: dueno
```

---

## 🌳 Collection Paths

### Platform Collections (Super-admin only)

```
_platform/
├─ tenants/
│  └─ {tenant_id}
│     ├─ name: "Salón Luna"
│     ├─ estado: "activo"
│     └─ branding: {...}
│
├─ usuarios/
│  └─ {tenant_id}/
│     └─ {user_id}
│        ├─ email: "employee@salon.com"
│        ├─ rol: "recepcionista"
│        └─ activo: true
│
└─ audit_logs/
   └─ {log_id}
      ├─ accion: "suspender_tenant"
      ├─ super_admin_email: "admin@platform.com"
      └─ timestamp: "2024-07-13T14:00:00Z"
```

### Tenant Collections (Tenant members only)

```
tenants/
└─ {tenant_id}/
   ├─ config/ (salon settings)
   ├─ servicios/ (service catalog)
   ├─ trabajadores/ (staff roster)
   │  └─ {trabajador_id}/
   │     └─ ausencias/ (vacations/absences)
   ├─ clientes/ (customer database)
   ├─ turnos/ (appointments)
   └─ usuarios/ (team members)
```

---

## ⚡ Common Code Patterns

### Pattern 1: Create New Appointment (As Recepcionista)

```javascript
const newTurno = {
  cliente_id: selectedClientId,
  trabajador_id: selectedStaffId,
  servicio_id: selectedServiceId,
  fecha: '2024-07-20',
  hora_inicio: firebaseTimestamp,
  duracion_minutos: 90,
  estado: 'confirmado',
  precio: 85.00,
  created_at: firebase.firestore.FieldValue.serverTimestamp(),
  updated_at: firebase.firestore.FieldValue.serverTimestamp()
};

await firebase.firestore()
  .collection('tenants').doc(tenantId)
  .collection('turnos')
  .add(newTurno);
```

### Pattern 2: Get My Appointments (As Estilista)

```javascript
const staffId = getCurrentStaffId(); // Your ID
const today = '2024-07-13';

const appointments = await firebase.firestore()
  .collection('tenants').doc(tenantId)
  .collection('turnos')
  .where('trabajador_id', '==', staffId)
  .where('fecha', '==', today)
  .get();

appointments.forEach(doc => {
  console.log('Appointment:', doc.data());
});
```

### Pattern 3: Update Client Info (As Recepcionista)

```javascript
const clientId = 'cliente-123';
const updateData = {
  telefono: '+34 666 555 444',
  preferencias: {
    tipo_corte: 'bob_corto',
    notas: 'Alérgica a ciertos productos'
  },
  updated_at: firebase.firestore.FieldValue.serverTimestamp()
};

await firebase.firestore()
  .collection('tenants').doc(tenantId)
  .collection('clientes')
  .doc(clientId)
  .update(updateData);
```

### Pattern 4: View All Services (All Roles)

```javascript
const services = await firebase.firestore()
  .collection('tenants').doc(tenantId)
  .collection('servicios')
  .where('activo', '==', true)
  .get();

services.forEach(doc => {
  console.log(doc.data().nombre, '-', doc.data().precio);
});
```

---

## 🛟 Getting Help

### If Your Access Is Blocked

1. **Check custom claims**:
   ```javascript
   const token = await firebase.auth().currentUser.getIdTokenResult();
   console.log(token.claims);
   ```

2. **Verify tenant status**:
   - Ask your salon owner: Is the salon active?
   - If suspended, contact admin to reactivate

3. **Check your role**:
   - Estilista can only READ
   - Recepcionista can CREATE/UPDATE but not DELETE
   - Dueno has full access

4. **Report issue**:
   - Share error message and what you were trying to do
   - Include custom claims output
   - Contact: salon-owner or platform-admin

---

## 📚 Full Documentation

For detailed rules and access patterns, see:
- **`FIRESTORE_RULES_SUMMARY.md`** - Complete rule documentation
- **`FIRESTORE_DEPLOYMENT_GUIDE.md`** - Deployment and testing
- **`firestore.rules`** - Actual Firestore rules file

---

**Last Updated**: 2026-07-13  
**Firestore Project**: turnos-salon-163b5  
**Status**: Production Ready ✅
