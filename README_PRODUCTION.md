# PRODUCTION GUIDE - Multi-Tenant Salon Management System

**Version**: 1.0.0  
**Date**: 2026-07-13  
**Firebase Project**: turnos-salon-163b5

---

## Overview

This document provides operational guidance for the production deployment and management of the multi-tenant salon management system. It covers two Flutter apps:

1. **turnos_admin**: Platform administrator app for managing tenants and users
2. **turnos_salon**: Client app for salon employees and management

Both apps connect to a shared Firebase project with multi-tenant data isolation enforced via Firestore Rules and custom authentication claims.

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Firebase Project (turnos-salon-163b5)        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  │   Firestore DB   │  │   Auth Service   │  │  Cloud Functions │
│  │                  │  │                  │  │                  │
│  │ - _platform/     │  │ - Email/Password │  │ setUserClaims()  │
│  │   tenants/       │  │ - Custom Claims  │  │ (manages roles)  │
│  │   usuarios/      │  │ - Session Tokens │  │                  │
│  │   audit_logs/    │  │                  │  │                  │
│  │ - tenants/       │  │                  │  │                  │
│  │   {id}/          │  │                  │  │                  │
│  │   turnos/        │  │                  │  │                  │
│  │   clientes/      │  │                  │  │                  │
│  │   usuarios/      │  │                  │  │                  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘
│
└─────────────────────────────────────────────────────────────────┘
        ▲                           ▲                       ▲
        │                           │                       │
┌───────┴─────────────┐  ┌──────────┴──────────────┐  ┌────┴───────────┐
│   turnos_admin      │  │   turnos_salon         │  │ Admin Console  │
│   (Flutter App)     │  │   (Flutter App)        │  │ (Browser)      │
│                     │  │                        │  │                │
│ - Create tenants    │  │ - View appointments   │  │ - Manage users │
│ - Manage users      │  │ - Create appointments │  │ - View logs    │
│ - Set roles         │  │ - Manage clients      │  │ - Analytics    │
│ - View audit logs   │  │ - Salón operations    │  │                │
│ - Super-admin only  │  │ - Multi-tenant users  │  │                │
└─────────────────────┘  └───────────────────────┘  └────────────────┘
```

### Data Flow

1. **Tenant Creation**:
   - Admin in turnos_admin creates tenant
   - Document created in `_platform/tenants/{tenant_id}`
   - User created in Firebase Auth with custom claims

2. **User Login**:
   - User enters credentials in turnos_salon
   - Firebase Auth validates email/password
   - Custom claims loaded: `{ tenant_id, role }`
   - App verifies tenant status (estado = "activo")
   - App loads tenant configuration
   - App applies branding

3. **Data Access**:
   - All queries scoped to `tenants/{tenant_id}/*`
   - Firestore Rules validate tenant_id from custom claims
   - Users cannot access other tenants' data

---

## Multi-Tenant Data Model

### Firestore Structure

```
_platform/                           # System-level (super-admin only)
├── tenants/                          # Tenant registry
│   └── {tenant_id}/
│       ├── name: string
│       ├── owner_email: string
│       ├── estado: "activo" | "suspendido" | "deleted"
│       ├── created_at: timestamp
│       ├── updated_at: timestamp
│       └── branding:
│           ├── color_primary: string (hex)
│           ├── color_secondary: string (hex, optional)
│           ├── logo_url: string (optional)
│           └── force_theme: "light" | "dark" | null
│
├── usuarios/                         # User registry per tenant
│   └── {tenant_id}/
│       └── {user_id}/
│           ├── email: string
│           ├── rol: "dueno" | "recepcionista" | "estilista"
│           ├── activo: boolean
│           ├── created_at: timestamp
│           └── updated_at: timestamp
│
└── audit_logs/                       # Immutable action log
    └── {log_id}/
        ├── acción: string
        ├── super_admin: string (email)
        ├── tenant_id: string
        ├── detalles: object
        └── timestamp: timestamp

tenants/                             # Tenant data (user-facing)
└── {tenant_id}/
    ├── config/
    │   └── salon/
    │       ├── nombre: string
    │       ├── telefono: string
    │       └── direccion: string
    │
    ├── turnos/
    │   └── {turno_id}/
    │       ├── cliente_id: string
    │       ├── fecha: date
    │       ├── hora: time
    │       ├── duracion: number
    │       ├── servicio: string
    │       ├── trabajador_id: string
    │       ├── estado: "confirmado" | "pendiente" | "cancelado"
    │       ├── created_at: timestamp
    │       └── updated_at: timestamp
    │
    ├── clientes/
    │   └── {cliente_id}/
    │       ├── nombre: string
    │       ├── apellido: string
    │       ├── telefono: string
    │       ├── email: string
    │       ├── prefencias: object
    │       ├── created_at: timestamp
    │       └── updated_at: timestamp
    │
    ├── trabajadores/
    │   └── {trabajador_id}/
    │       ├── nombre: string
    │       ├── email: string
    │       ├── especialidades: array
    │       ├── horario: object
    │       ├── created_at: timestamp
    │       └── updated_at: timestamp
    │
    ├── servicios/
    │   └── {servicio_id}/
    │       ├── nombre: string
    │       ├── duracion: number
    │       ├── precio: number
    │       └── created_at: timestamp
    │
    └── usuarios/
        └── {user_id}/
            ├── email: string
            ├── rol: string
            └── active: boolean
```

---

## Security Model

### Authentication

- **Method**: Firebase Email/Password authentication
- **Custom Claims**: Set by Cloud Function after user creation
- **Claims Structure**:
  ```json
  {
    "tenant_id": "salon_001",
    "role": "dueno|recepcionista|estilista"
  }
  ```
- **Super-Admin**: Special role only in turnos_admin
  ```json
  {
    "role": "super_admin"
  }
  ```

### Authorization

**Role Hierarchy**:
```
super_admin (platform admin)
└── dueno (tenant owner)
    ├── recepcionista (receptionist - can create)
    └── estilista (stylist - read-only)
```

**Permissions by Role**:

| Action | Super-Admin | Dueno | Recepcionista | Estilista |
|--------|---|---|---|---|
| Create Tenant | ✓ | ✗ | ✗ | ✗ |
| Edit Tenant | ✓ | ✓ | ✗ | ✗ |
| Suspend Tenant | ✓ | ✗ | ✗ | ✗ |
| View Audit Logs | ✓ | ✓ | ✗ | ✗ |
| Create User | ✓ | ✓ | ✗ | ✗ |
| Delete User | ✓ | ✓ | ✗ | ✗ |
| Read Turnos | ✓ | ✓ | ✓ | ✓ |
| Create Turno | ✓ | ✓ | ✓ | ✗ |
| Update Turno | ✓ | ✓ | ✓ | ✗ |
| Delete Turno | ✓ | ✓ | ✗ | ✗ |
| Read Clientes | ✓ | ✓ | ✓ | ✓ |
| Create Cliente | ✓ | ✓ | ✓ | ✗ |
| Edit Cliente | ✓ | ✓ | ✓ | ✗ |

### Data Isolation

- **Multi-tenant enforcement**: Firestore Rules check `userInTenant(tenantId)` on all reads/writes
- **Cross-tenant access**: Blocked by Rules, returns permission error
- **Suspension**: `isTenantActive()` check on every Firestore access
- **Backend operations**: Cloud Functions use Admin SDK (bypass Rules), but enforce custom validation

---

## Role Descriptions

### Super-Admin

**Who**: Platform infrastructure team  
**What they can do**:
- Create new tenant salons
- Edit tenant configuration (name, branding)
- Suspend/reactivate tenants
- Create users in any tenant
- Delete users
- Set user roles
- View global audit logs
- View all tenant data (for support/debugging)

**Access**: turnos_admin app only

**Responsibility**:
- Onboard new salon tenants
- Manage user accounts
- Handle security incidents
- Monitor system health

---

### Dueno (Owner)

**Who**: Salon owner or manager  
**What they can do**:
- View dashboard of their salon's data
- Create/edit turnos (appointments)
- Create/edit clientes (customers)
- Create/edit trabajadores (employees)
- Create/edit servicios (services)
- Manage staff roles (assign recepcionista, estilista)
- View audit logs of their salon
- Delete turnos, clientes, usuarios
- Cannot create super-admin users

**Access**: turnos_salon app

**Responsibility**:
- Manage daily operations
- Onboard staff
- Handle customer issues
- Ensure data quality

---

### Recepcionista (Receptionist)

**Who**: Salon receptionist/front desk  
**What they can do**:
- View appointments (turnos)
- Create new appointments
- Edit appointments
- Create new customers
- Edit customer info
- Cannot delete appointments or customers
- Cannot manage other users

**Access**: turnos_salon app

**Responsibility**:
- Schedule appointments
- Answer phones/emails
- Check in customers
- Update customer records

---

### Estilista (Stylist)

**Who**: Salon stylist/hair dresser  
**What they can do**:
- View their assigned appointments
- View customer info (name, phone, notes)
- Cannot create, edit, or delete appointments
- Cannot create/edit customers
- Cannot delete anything

**Access**: turnos_salon app (read-only view)

**Responsibility**:
- View their schedule
- Prepare for appointments
- No administrative tasks

---

## Operations: Common Tasks

### How to Create a New Tenant

**Step 1: Prepare Information**
```
Tenant Name: "Salon de Belleza Esmeralda"
Owner Email: "lucia@salonesmera lda.com"
Initial Password: [Generate secure password]
Primary Color: "#FF1493" (hex code)
```

**Step 2: Create in turnos_admin**
1. Launch turnos_admin app
2. Login with super-admin account
3. Click: "Crear Nuevo Tenant" button
4. Fill form:
   - Nombre Salón: [Enter name]
   - Email Dueño: [Enter owner email]
   - Contraseña: [Enter initial password]
   - Color Primario: [Select color]
5. Click: "Guardar"
6. Verify: Success message and new tenant in list

**Step 3: Verify in Firebase Console**
1. Open: https://console.firebase.google.com
2. Project: turnos-salon-163b5
3. Firestore → Collections → _platform → tenants
4. Should see new tenant document with:
   - name: "Salon de Belleza Esmeralda"
   - owner_email: "lucia@salonesmera lda.com"
   - estado: "activo"
   - branding.color_primary: "#FF1493"

**Step 4: Verify User Created**
1. Firebase Console → Authentication → Users
2. Find: lucia@salonesmera lda.com
3. Click user → Custom claims
4. Should show: `{ "tenant_id": "...", "role": "dueno" }`

**Step 5: Owner Login**
1. Send password to owner (securely, not in email)
2. Owner opens turnos_salon app
3. Login with: lucia@salonesmera lda.com and password
4. Verify: App loads, shows salon name and color

---

### How to Add Users to Tenant

**Step 1: In turnos_admin, Navigate to Tenant**
1. Click: Tenant name (e.g., "Salon Esmeralda")
2. Should see: List of users and "Agregar Usuario" button

**Step 2: Create New User**
1. Click: "Agregar Usuario"
2. Fill form:
   ```
   Email: juan.recepcionista@salones meralda.com
   Rol: Recepcionista
   Contraseña: [Generate secure password]
   ```
3. Click: "Guardar"
4. Verify: Success message, user appears in list

**Step 3: Verify in Firebase**
1. Firebase Console → Authentication → Users
2. Find: juan.recepcionista@salonesmera lda.com
3. Click → Custom claims
4. Should show: `{ "tenant_id": "[same as tenant]", "role": "recepcionista" }`

**Step 4: User Can Login**
1. Send password to user
2. User opens turnos_salon
3. Login with credentials
4. Verify: Access to appointment management (create, edit)
5. Verify: Cannot delete appointments (recepcionista role)

---

### How to Suspend a Tenant

**When to suspend**:
- Non-payment of fees
- Terms of service violation
- Customer request (temporary)
- Emergency maintenance

**Step 1: In turnos_admin**
1. Find tenant in list
2. Click tenant name
3. Look for: "Suspender" button
4. Click: "Suspender"
5. Optional: Enter reason (e.g., "Maintenance")
6. Confirm

**Step 2: Verify Suspension**
1. Firebase Console → Firestore → _platform → tenants → [tenant_id]
2. Check: estado field = "suspendido"

**Step 3: Verify Users Are Blocked**
1. User tries to login to turnos_salon
2. Expected: Error message "Tu salón ha sido suspendido"
3. User cannot access data

**Step 4: To Reactivate**
1. In turnos_admin, click tenant
2. Click: "Reactivar"
3. Verify: estado changes to "activo"
4. Users can login again

---

### How to Permanently Delete a Tenant

**Important**: This is "soft delete" - data remains recoverable for 30 days.

**When to delete**:
- Tenant requested closure
- Trial period ended (no conversion)
- Business closed

**Step 1: In turnos_admin**
1. Find tenant in list
2. Click tenant name
3. Look for: "Eliminar" button
4. Click: "Eliminar"
5. Confirm: "This cannot be undone"

**Step 2: Verify Deletion**
1. Firebase Console → Firestore → _platform → tenants → [tenant_id]
2. Check: estado field = "deleted"
3. Verify: All data still present (not hard-deleted)

**Step 3: User Cannot Login**
1. User tries to login
2. Expected: Error "Tu salón ha sido eliminado"

**Step 4: To Recover (within 30 days)**
1. In turnos_admin, filter by "Deleted" tenants
2. Click tenant
3. Click: "Recuperar"
4. Verify: estado changes to "activo"
5. Users can login again

---

### How to View Audit Logs

**Purpose**: Track who did what and when for security/compliance.

**Step 1: In turnos_admin**
1. Navigate to: Audit Logs or Admin → Logs
2. Should see list of actions with:
   - Timestamp: When action occurred
   - Acción: What was done (create_user, create_tenant, etc.)
   - Super-Admin: Who performed it
   - Tenant ID: Which tenant affected
   - Detalles: Additional info

**Step 2: Filter Logs**
1. Optional: Filter by:
   - Date range
   - Action type (create_user, delete_user, etc.)
   - Tenant ID
   - User email

**Step 3: Export Logs** (if feature available)
1. Click: "Exportar"
2. Select: Format (CSV, JSON)
3. Click: "Descargar"
4. File saved with all logs

**What's logged**:
```
- create_tenant: When new tenant created
- edit_tenant: When tenant config changed
- suspend_tenant: When tenant suspended
- delete_tenant: When tenant soft-deleted
- create_user: When new user added
- delete_user: When user removed
- update_user: When user role/status changed
- create_turno: When appointment created
- update_turno: When appointment changed
- delete_turno: When appointment deleted
```

---

## Troubleshooting

For detailed troubleshooting, see: `TROUBLESHOOTING.md`

### Quick Reference

| Problem | Quick Fix |
|---------|-----------|
| User can't log in | Check custom claims in Firebase Console |
| User sees "Acceso denegado" | Check tenant estado = "activo" |
| Audit logs missing | Check Cloud Function deployed |
| Tenant suspension not blocking | Re-deploy Firestore Rules |
| App crashes on login | Check Firebase config (google-services.json) |
| Multi-tenant data mixed | Check queries include tenant_id filter |
| Performance slow | Add Firestore indexes, implement pagination |

---

## Monitoring & Health Checks

### Daily Checks

```
[ ] Firestore is accessible
    - Firebase Console open without errors
    - Collections visible

[ ] Cloud Functions are active
    - Firebase Console → Cloud Functions
    - setUserClaims shows "ACTIVE"

[ ] No error spikes
    - Firebase Console → Logging
    - Look for sudden increase in errors

[ ] Performance is normal
    - Check query latencies
    - No slowdowns reported by users
```

### Weekly Checks

```
[ ] Audit logs are growing
    - _platform → audit_logs has recent entries
    - No gaps in logging

[ ] User metrics
    - Active users count
    - Failed login attempts (should be low)
    - Storage usage trend

[ ] Backups are running
    - Firebase Backups tab
    - Last backup timestamp recent (within 24 hours)
```

### Monthly Checks

```
[ ] Review storage usage
    - Estimate growth rate
    - Ensure within quota

[ ] Review costs
    - Firestore reads/writes
    - Cloud Function invocations
    - Storage used
    - Compare to budget

[ ] Security audit
    - Review high-risk logs
    - Check for unusual access patterns
    - Verify no unauthorized access

[ ] Performance review
    - Average login time
    - Average query latency
    - Error rate trend
```

---

## Incident Response

### Authentication Outage

**Symptoms**: Users cannot login

**Response**:
1. Check Firebase Status page: https://status.firebase.google.com
2. If Firebase is down, wait for recovery (usually <15 minutes)
3. If Firebase is up but auth failing:
   - Check Cloud Function logs
   - Check custom claims are set
   - Verify Firestore Rules not too restrictive
4. Notify users of delay

---

### Firestore Access Denied

**Symptoms**: Users see "Acceso denegado" errors

**Response**:
1. Check tenant estado in Firestore
2. Check user custom claims
3. Check if rules deployed correctly
4. Review recent rule changes
5. Rollback if needed

---

### Suspension Abuse

**Symptoms**: Tenants repeatedly suspended/restored

**Response**:
1. Review audit logs
2. Identify root cause
3. Update suspension policy if needed
4. Consider implementing cooldown period

---

### Data Inconsistency

**Symptoms**: User sees incorrect data

**Response**:
1. Check Firestore for data integrity
2. Check if queries using correct tenant_id
3. Verify custom claims still valid
4. Refresh user session

---

## Backup & Disaster Recovery

### Backup Strategy

- **Frequency**: Daily automated backups
- **Retention**: 30 days
- **Location**: Different region than primary
- **Testing**: Recovery tested monthly

### Recovery Procedure

If data is lost or corrupted:

1. **Assessment**: Determine what's missing
2. **Locate backup**: Firebase Backups tab, select date
3. **Test restore**: Restore to temporary database first
4. **Verify**: Check data integrity
5. **Production restore**: If verified, restore to production
6. **Notify users**: Explain downtime and recovery

### Recovery Time

- **Assessment**: 15 minutes
- **Restore**: 30 minutes (depends on data size)
- **Verification**: 15 minutes
- **Total**: ~1 hour for complete recovery

---

## Performance Optimization

### Database Indexes

Firestore automatically creates single-field indexes. For complex queries, composite indexes may be needed:

**Common queries** (indexes may be needed):
- Find turnos by date and status
- Find turnos by worker and date
- Find clients by name

**Add index**:
1. Firebase Console → Firestore → Indexes
2. Click: "Create composite index"
3. Collection: tenants/{tenant_id}/turnos
4. Fields: date (DESC), status (ASC)
5. Click: Create

### Caching

App uses Riverpod + Hive for caching:
- Recent queries cached locally
- 24-hour cache expiry
- Manual refresh available
- Offline mode uses cache

### Pagination

Queries load 50 items per page:
- Reduces network data
- Improves initial load time
- Implemented in turnos, clientes lists

---

## Scaling Considerations

### Current Limits

- **Firestore**: 1 million documents per collection (practically unlimited for our use case)
- **Cloud Functions**: 540 concurrent executions by default
- **Storage**: Unlimited
- **Bandwidth**: Billed per GB

### When to Scale

Monitor these metrics:

1. **Query latency increasing**
   - Solution: Add indexes, implement pagination

2. **Cloud Function timeouts**
   - Solution: Increase memory allocation

3. **Cost increasing unexpectedly**
   - Solution: Review queries, implement caching

4. **User growth >1000 tenants**
   - Solution: Consider database sharding (advance topic)

---

## Support & Escalation

### Support Channels

1. **Technical Issues**: engineering@company.com
2. **Billing Issues**: billing@company.com
3. **Security Issues**: security@company.com
4. **Urgent (Down)**: [Emergency contact]

### Escalation Procedure

| Issue | Owner | Response Time |
|-------|-------|---|
| Users cannot login | Tech Lead | 15 min |
| Data loss | Database Admin | 30 min |
| Security breach | Security Lead | 5 min |
| Performance degradation | DevOps | 30 min |
| App crash | Engineering | 1 hour |

---

## Documentation Index

- **TESTING_GUIDE.md**: How to test the system
- **TROUBLESHOOTING.md**: How to solve common issues
- **PRODUCTION_READINESS_CHECKLIST.md**: Pre-deployment verification
- **INTEGRATION_TEST_REPORT_TEMPLATE.md**: Test results template

---

## Contact Information

**Project Manager**: [Name] - [Email] - [Phone]  
**Tech Lead**: [Name] - [Email] - [Phone]  
**DevOps Lead**: [Name] - [Email] - [Phone]  
**Security Lead**: [Name] - [Email] - [Phone]

---

**Last Updated**: 2026-07-13  
**Next Review**: 2026-08-13

---

**End of README_PRODUCTION.md**
