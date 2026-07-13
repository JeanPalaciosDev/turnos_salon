# Plan de Ejecución: Arquitectura Multi-Tenant con DOS APPS

**Fecha**: 2024-07-15  
**Estado**: Listo para ejecutar  
**Versión**: 1.0

---

## 📋 Resumen Ejecutivo

Convertir el sistema de un salón a una plataforma multi-tenant con dos aplicaciones Flutter independientes:

1. **APP ADMIN** (`turnos_admin`): Super-admin gestiona tenants
2. **APP CLIENTE** (refactor del actual): Usuarios usan su salón

Ambas apuntan a un único Firebase project (Auth + Firestore compartido).

---

## 🎯 Objetivos

- ✅ Crear infraestructura Firestore multi-tenant
- ✅ Implementar APP ADMIN (CRUD tenants + usuarios)
- ✅ Refactorizar APP CLIENTE para usar tenant_id
- ✅ Asegurar aislamiento de datos mediante Firestore Rules
- ✅ Bloqueo inmediato si tenant está suspendido
- ✅ Custom Claims para autenticación multi-tenant

---

## 📊 Decisiones Arquitectónicas

| Decisión | Valor |
|----------|-------|
| Orden de implementación | APP ADMIN primero |
| Reutilización de código | Refactorizar código actual como APP CLIENTE |
| MVP APP ADMIN | CRUD tenants + gestión de usuarios |
| MVP APP CLIENTE | Agenda con login multi-tenant |
| Suspensión de tenant | Bloqueo inmediato |
| Firebase | UN proyecto compartido |

---

## 🗂️ Estructura de Datos Firestore

```
firestore/
│
├─ _platform/
│  ├─ tenants/
│  │  └─ {tenant_id}/
│  │     ├─ name: string
│  │     ├─ estado: "activo" | "suspendido" | "deleted"
│  │     ├─ owner_email: string
│  │     ├─ created_at: timestamp
│  │     ├─ updated_at: timestamp
│  │     └─ branding:
│  │        ├─ color_primary: string (hex)
│  │        ├─ color_secondary: string (hex, optional)
│  │        ├─ logo_url: string (optional)
│  │        └─ force_theme: "light" | "dark" | null
│  │
│  ├─ usuarios/
│  │  └─ {tenant_id}/
│  │     └─ {user_id}/
│  │        ├─ email: string
│  │        ├─ rol: "dueno" | "recepcionista" | "estilista"
│  │        ├─ activo: boolean
│  │        ├─ created_at: timestamp
│  │        └─ updated_at: timestamp
│  │
│  └─ audit_logs/
│     └─ {log_id}/
│        ├─ acción: string
│        ├─ super_admin: string (email)
│        ├─ tenant_id: string
│        ├─ detalles: object
│        └─ timestamp: timestamp
│
└─ tenants/
   └─ {tenant_id}/
      ├─ config/
      │  └─ salon/ (configuración general del salón)
      ├─ turnos/
      │  └─ {turno_id}/ (datos de turnos)
      ├─ clientes/
      │  └─ {cliente_id}/ (datos de clientes)
      ├─ trabajadores/
      │  └─ {trabajador_id}/ (datos de empleados)
      ├─ servicios/
      │  └─ {servicio_id}/ (datos de servicios)
      └─ usuarios/
         └─ {user_id}/ (usuarios asignados a este tenant)
```

---

## 👤 Modelos Dart (Compartidos)

```dart
// Tenant
class Tenant {
  final String id;
  final String name;
  final String estado; // "activo", "suspendido", "deleted"
  final Branding branding;
  final String ownerEmail;
  final DateTime createdAt;
  final DateTime updatedAt;
}

// Branding
class Branding {
  final String colorPrimary;
  final String? colorSecondary;
  final String? logoUrl;
  final String? forceTheme; // "light", "dark", null
}

// TenantUser
class TenantUser {
  final String uid;
  final String email;
  final String rol; // "dueno", "recepcionista", "estilista"
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;
}

// AuditLog
class AuditLog {
  final String id;
  final String acción;
  final String superAdmin;
  final String tenantId;
  final Map<String, dynamic> detalles;
  final DateTime timestamp;
}
```

---

## 🔑 Custom Claims (Firebase Auth)

### Para Super-Admin:
```json
{
  "role": "super_admin"
}
```

### Para Usuario de Tenant:
```json
{
  "tenant_id": "tenant_ana_123",
  "role": "dueno"  // o "recepcionista" o "estilista"
}
```

---

## 📱 APP ADMIN Flujos

### Flujo 1: Crear Tenant
```
Super-admin en APP ADMIN
  ↓
Click: "Crear nuevo tenant"
  ↓
Formulario:
  - Nombre del salón
  - Email del primer admin
  - Contraseña
  - Color primario (hex)
  ↓
Click: "Crear"
  ↓
Sistema:
  1. Crea doc en _platform/tenants/{nuevo_id}
  2. Crea usuario en Firebase Auth
  3. Llama Cloud Function para asignar Custom Claims
  4. Crea doc en _platform/usuarios/{tenant_id}/{uid}
  5. Registra en _platform/audit_logs/
  ↓
Muestra: "✅ Tenant creado"
"Credenciales: email / password"
```

### Flujo 2: Editar Tenant
```
Super-admin en APP ADMIN
  ↓
Selecciona tenant
  ↓
Click: "Editar"
  ↓
Formulario: nombre, colores, logo, estado
  ↓
Click: "Guardar"
  ↓
Sistema:
  1. Actualiza _platform/tenants/{tenant_id}
  2. Registra en _platform/audit_logs/
  ↓
Cambios reflejados inmediatamente
```

### Flujo 3: Suspender Tenant
```
Super-admin en APP ADMIN
  ↓
Selecciona tenant
  ↓
Click: "Suspender"
  ↓
Sistema:
  1. Cambia estado a "suspendido"
  2. Registra en audit_logs
  ↓
Usuarios de ese tenant:
  - Próxima lectura falla (Firestore Rules)
  - Ven error: "Tu salón ha sido suspendido"
```

### Flujo 4: Crear Usuario en Tenant
```
Super-admin en APP ADMIN
  ↓
Selecciona tenant
  ↓
Click: "Agregar usuario"
  ↓
Formulario:
  - Email
  - Contraseña
  - Rol (dueno, recepcionista, estilista)
  ↓
Click: "Crear"
  ↓
Sistema:
  1. Crea usuario en Firebase Auth
  2. Llama Cloud Function para asignar Custom Claims
  3. Crea doc en _platform/usuarios/{tenant_id}/{uid}
  4. Registra en audit_logs
  ↓
Usuario listo para usar
```

---

## 📱 APP CLIENTE Flujos

### Flujo 1: Login Tenant Usuario
```
Usuario en APP CLIENTE
  ↓
LoginScreen:
  - Email
  - Contraseña
  ↓
Click: "Entrar"
  ↓
Firebase Auth valida
  ↓
Sistema extrae:
  - tenant_id de Custom Claims
  - role de Custom Claims
  ↓
Si tenant_id no existe → Error
Si tenant estado = "suspendido" → Error
  ↓
Carga:
  1. Branding del tenant
  2. Datos de su salón
  ↓
Redirect a /agenda
  ↓
Interfaz personalizada con marca del tenant
```

### Flujo 2: Ver Agenda
```
Usuario logueado
  ↓
Agenda muestra:
  - Solo turnos de su tenant (filtrados por tenant_id)
  - Datos de su salón
  - Su nombre/rol
  ↓
Si intenta bypassear y acceder a /tenants/{OTRO_id}/*
  → Firestore Rules deniegan
  → Error: "Sin permiso"
```

---

## 🔒 Firestore Rules (Resumen)

```javascript
// Para _platform/tenants/:
// Solo super-admin (role = "super_admin")
allow read, write: if request.auth.token.role == "super_admin"

// Para _platform/usuarios/{tenant_id}/:
// Super-admin o usuarios de ese tenant
allow read: if request.auth.token.role == "super_admin" 
         || request.auth.token.tenant_id == tenant_id

// Para tenants/{tenant_id}/*:
// Solo usuarios de ese tenant
allow read, write: if request.auth.token.tenant_id == tenant_id
                && request.auth.token.role != "super_admin"
```

---

## ☁️ Cloud Function: setUserClaims

**Nombre**: `setUserClaims`  
**Trigger**: HTTP POST  
**Endpoint**: `https://region-projectid.cloudfunctions.net/setUserClaims`

**Request Body**:
```json
{
  "uid": "firebase_user_uid",
  "tenant_id": "tenant_abc123",
  "role": "dueno"
}
```

**Response Success**:
```json
{
  "success": true,
  "message": "Custom Claims asignados"
}
```

**Response Error**:
```json
{
  "success": false,
  "message": "El usuario no existe" // 404
}
```

**Node.js Implementation** (pseudo):
```javascript
exports.setUserClaims = functions.https.onRequest(async (req, res) => {
  const { uid, tenant_id, role } = req.body;
  const token = req.headers.authorization?.split(' ')[1];
  
  // Verificar que quien llama es super_admin
  const caller = await admin.auth().verifyIdToken(token);
  if (caller.role !== 'super_admin') {
    return res.status(403).send({ success: false, message: 'Forbidden' });
  }
  
  // Asignar Custom Claims
  await admin.auth().setCustomUserClaims(uid, { tenant_id, role });
  return res.status(200).send({ success: true });
});
```

---

## 📋 Fases de Implementación

### Phase 0: Documentation Discovery
- [ ] Investigar Firebase Auth Custom Claims en Flutter
- [ ] Validar APIs Firestore Rules
- [ ] Confirmar patrones Riverpod + Firestore
- **Duración estimada**: 2-3 horas
- **Output**: Documentación confirmada, APIs listadas

---

### Phase 1: Infraestructura Firestore
- [ ] Crear colecciones en Firestore (_platform/, tenants/)
- [ ] Definir modelos Dart (Tenant, TenantUser, AuditLog, Branding)
- [ ] Crear Firestore Rules base (sin seguridad aún)
- [ ] Seed inicial (opcional)
- **Duración estimada**: 4-5 horas
- **Output**: Firestore structure + Dart models compilando

---

### Phase 2: APP ADMIN - Setup Base
- [ ] Crear proyecto Flutter nuevo: `turnos_admin`
- [ ] Configurar Firebase (mismo project)
- [ ] Crear `AdminAuthRepository` (login super-admin)
- [ ] Crear routing base (/login, /dashboard)
- [ ] Implementar LoginScreen
- [ ] Guard: solo super-admin puede entrar
- **Duración estimada**: 6-8 horas
- **Output**: APP ADMIN compila, login funciona

---

### Phase 3: APP ADMIN - CRUD Tenants
- [ ] Crear `TenantRepository` (CRUD)
- [ ] Cloud Function `setUserClaims` (backend)
- [ ] Crear `AdminUserService` para usuarios
- [ ] Implementar DashboardScreen (listar tenants)
- [ ] Implementar CreateTenantScreen (formulario)
- [ ] Implementar EditTenantScreen (editar config)
- [ ] Implementar Suspender/Reactivar
- [ ] Implementar Soft-Delete
- **Duración estimada**: 10-12 horas
- **Output**: APP ADMIN CRUD funciona, puede crear/editar tenants

---

### Phase 4: APP ADMIN - Gestión de Usuarios
- [ ] Pantalla: Ver usuarios por tenant
- [ ] Formulario: Crear usuario en tenant
- [ ] Botón: Desactivar/Activar usuario
- [ ] Integración con Cloud Function para Custom Claims
- **Duración estimada**: 6-8 horas
- **Output**: APP ADMIN puede crear usuarios por tenant

---

### Phase 5: APP CLIENTE - Refactorización
- [ ] Copiar código actual como base APP CLIENTE
- [ ] Modificar `AuthRepository` para extraer tenant_id
- [ ] Crear `TenantProvider` (carga config del tenant)
- [ ] Crear `currentTenantIdProvider` (global)
- [ ] Filtrar todas las queries por tenant_id
- [ ] Compilar sin errores
- **Duración estimada**: 8-10 horas
- **Output**: APP CLIENTE compila, estructura lista

---

### Phase 6: APP CLIENTE - Login Multi-Tenant
- [ ] Verificar Custom Claims en LoginScreen
- [ ] Validar que usuario tiene tenant_id
- [ ] Cargar config del tenant después de login
- [ ] Verificar que tenant estado = "activo"
- [ ] Mostrar nombre del tenant en AppShell
- [ ] Redirect correcto a /agenda
- **Duración estimada**: 4-6 horas
- **Output**: APP CLIENTE login funciona, usuario ve su tenant

---

### Phase 7: Firestore Rules & Security
- [ ] Escribir reglas completas para _platform/
- [ ] Escribir reglas para tenants/{tenant_id}/*
- [ ] Validar Custom Claims en todas las rules
- [ ] Bloquear cross-tenant access
- [ ] Verificar estado tenant = "activo"
- [ ] Desplegar a Firestore
- **Duración estimada**: 4-6 horas
- **Output**: Rules activas, aislamiento funciona

---

### Phase 8: Testing & Integration
- [ ] Test: Crear tenant en APP ADMIN
- [ ] Test: Login en APP CLIENTE con ese tenant
- [ ] Test: Crear dos tenants, verificar aislamiento
- [ ] Test: Suspender tenant, verificar bloqueo inmediato
- [ ] Test: Seguridad (intentar bypassear)
- [ ] Test: Performance
- [ ] Documentación (README, troubleshooting)
- **Duración estimada**: 6-8 horas
- **Output**: Todos los flujos funcionan, documentación lista

---

## 📊 Estimación Total

| Fase | Horas |
|------|-------|
| Phase 0 | 2-3 |
| Phase 1 | 4-5 |
| Phase 2 | 6-8 |
| Phase 3 | 10-12 |
| Phase 4 | 6-8 |
| Phase 5 | 8-10 |
| Phase 6 | 4-6 |
| Phase 7 | 4-6 |
| Phase 8 | 6-8 |
| **TOTAL** | **50-66 horas** |

**Tiempo real estimado**: 2-3 semanas (con desarrollo diario)

---

## ✅ Definición de "Done"

**MVP Completado cuando**:
- ✅ APP ADMIN: Super-admin puede crear tenants, crear usuarios, editar config
- ✅ APP CLIENTE: Usuario loguea, ve su salón, datos aislados
- ✅ Firestore Rules: Aislamiento funciona (cross-tenant denegado)
- ✅ Bloqueo inmediato: Si tenant suspendido, usuario ve error

**No incluido en MVP** (futuro):
- ❌ Auditoría detallada (logs, historial)
- ❌ Dashboard de métricas
- ❌ Personalización de branding en APP CLIENTE (colores, logo, tema)
- ❌ Gestión de empleados en APP CLIENTE
- ❌ Email de bienvenida automático
- ❌ Recuperación de contraseña

---

## 🚀 Cómo Ejecutar Este Plan

### En una nueva sesión:

1. Invocar `/claude-mem:do` con este archivo como referencia
2. Especificar qué phase ejecutar
3. Cada phase es autónomo y puede pausarse/reanudarse

### Estructura de commits:

Cada phase debe resultar en un commit:
```
git commit -m "Phase X: Descripción"
```

### Checkpoints de verificación:

Al final de cada phase:
```bash
# Compilar sin errores
flutter analyze

# Verificar Firestore en console
# Probar flujos manualmente
```

---

## 📞 Contacto & Notas

- **Timezone**: Argentina (ART, UTC-3)
- **Repo**: D:\Work\turnos_salon
- **Firebase Project**: turnos-salon-163b5 (compartido)
- **Documentación**: plans/ folder

---

**Plan creado**: 2024-07-15  
**Versión**: 1.0  
**Estado**: ✅ Listo para ejecutar
