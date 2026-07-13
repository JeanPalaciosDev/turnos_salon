# 📋 Checklist de Ejecución por Phase

Usa este archivo para seguimiento durante la ejecución de cada phase.

---

## Phase 0: Documentation Discovery

**Duración**: 2-3 horas  
**Responsable**: Investigación

### Tasks:

- [ ] Leer documentación Firebase Auth Custom Claims en Flutter
  - [ ] Cómo setear Custom Claims (Admin SDK)
  - [ ] Cómo leer Custom Claims (getIdTokenResult)
  
- [ ] Validar Firestore Rules API
  - [ ] request.auth.token.* sintaxis
  - [ ] Ejemplos de rules multi-tenant
  
- [ ] Revisar patrones Riverpod existentes
  - [ ] StreamProvider pattern
  - [ ] Provider dependencies
  
- [ ] Confirmar Cloud Functions Node.js
  - [ ] Firebase Admin SDK setCustomUserClaims
  - [ ] HTTP trigger deployment

### Output Esperado:
- Documentación consolidada
- Lista de APIs confirmadas
- Anti-patterns identificados

### Verificación:
- [ ] Documentación guardada en `docs/` o `plans/`
- [ ] Todas las APIs funcionan en proyecto test

---

## Phase 1: Infraestructura Firestore

**Duración**: 4-5 horas  
**Responsable**: Backend/DB

### Tasks:

- [ ] Crear colecciones en Firestore:
  - [ ] `_platform/tenants/`
  - [ ] `_platform/usuarios/`
  - [ ] `_platform/audit_logs/`
  - [ ] `tenants/` (raíz para datos por tenant)

- [ ] Definir modelos Dart (crear archivo compartido):
  - [ ] Tenant class
  - [ ] Branding class
  - [ ] TenantUser class
  - [ ] AuditLog class

- [ ] Crear Firestore Rules base:
  - [ ] Estructura básica (sin seguridad completa aún)
  - [ ] Deploy a Firestore

- [ ] Seed inicial (opcional):
  - [ ] Crear tenant de prueba
  - [ ] Crear usuario super-admin

### Output Esperado:
- Colecciones en Firestore visible en console
- Modelos Dart compilando
- Rules base activas

### Verificación:
```bash
flutter analyze  # Sin errores
firebase emulators:start  # Firestore emulator running
# Verificar en console: firestore colecciones creadas
```

### Archivos a crear/modificar:
- `lib/shared/domain/tenant.dart` (nuevo)
- `firestore.rules` (actualizar)

---

## Phase 2: APP ADMIN - Setup Base

**Duración**: 6-8 horas  
**Responsable**: Frontend Admin

### Tasks:

- [ ] Crear proyecto Flutter nuevo:
  ```bash
  flutter create turnos_admin
  ```

- [ ] Configurar Firebase:
  - [ ] Descargar google-services.json (MISMO project)
  - [ ] Configurar en pubspec.yaml
  - [ ] Inicializar Firebase.initializeApp()

- [ ] Crear estructura base:
  - [ ] lib/features/auth/
  - [ ] lib/features/dashboard/
  - [ ] lib/core/

- [ ] Crear AuthRepository:
  - [ ] Login super-admin (email/password)
  - [ ] Verificar Custom Claims (role = "super_admin")
  - [ ] Si no super_admin → error

- [ ] Crear routing:
  - [ ] /login (LoginScreen)
  - [ ] /dashboard (DashboardScreen)
  - [ ] Guard: solo super-admin

- [ ] Implementar LoginScreen:
  - [ ] Email + password input
  - [ ] Loading spinner
  - [ ] Error messages en español
  - [ ] Redirect a /dashboard si login ok

### Output Esperado:
- APP ADMIN compila sin errores
- Login funciona para super-admin
- Protección de rutas activa

### Verificación:
```bash
cd turnos_admin
flutter pub get
flutter run

# Probar:
# 1. Login con super-admin → /dashboard
# 2. Login con usuario normal → error "No autorizado"
```

### Archivos a crear:
- `turnos_admin/` (nuevo proyecto)
- `turnos_admin/lib/features/auth/data/admin_auth_repository.dart`
- `turnos_admin/lib/app/router.dart`

---

## Phase 3: APP ADMIN - CRUD Tenants

**Duración**: 10-12 horas  
**Responsable**: Frontend Admin

### Tasks:

- [ ] Crear TenantRepository:
  - [ ] createTenant()
  - [ ] listTenants()
  - [ ] getTenant()
  - [ ] updateTenant()
  - [ ] deleteTenant() (soft-delete)

- [ ] Cloud Function setUserClaims:
  - [ ] Crear en `functions/setUserClaims.js`
  - [ ] Configurar variables de entorno
  - [ ] Desplegar: `firebase deploy --only functions:setUserClaims`

- [ ] Crear AdminUserService:
  - [ ] Crear usuarios en instancia secundaria
  - [ ] Manejo de errores

- [ ] DashboardScreen:
  - [ ] ListView de tenants
  - [ ] Mostrar: nombre, estado, created_at, owner_email
  - [ ] Botones: Ver, Editar, Suspender, Eliminar

- [ ] CreateTenantScreen (formulario):
  - [ ] Nombre, email owner, password, color primario
  - [ ] Validación
  - [ ] On submit:
    - [ ] Crear doc en _platform/tenants/
    - [ ] Crear usuario Auth
    - [ ] Llamar Cloud Function para Custom Claims
    - [ ] Crear doc en _platform/usuarios/
    - [ ] Mostrar credenciales

- [ ] EditTenantScreen (modal):
  - [ ] Editar nombre, colores, logo, estado
  - [ ] Save button

- [ ] Suspender/Reactivar:
  - [ ] Botón rápido
  - [ ] Confirm dialog

### Output Esperado:
- Puede crear tenant desde APP ADMIN
- Tenant aparece en Firestore
- Usuario admin creado con Custom Claims
- Edición funciona
- Suspender cambia estado

### Verificación:
```bash
# APP ADMIN
flutter run

# Probar en APP ADMIN:
# 1. Crear tenant "Prueba"
# 2. Verificar en Firestore console
# 3. Editar nombre → cambio visible
# 4. Suspender → estado = "suspendido"

# Verificar en Firebase console:
# - _platform/tenants/XXX creado
# - Auth: usuario nuevo con role=super_admin
# - Custom Claims: { tenant_id, role }
```

### Archivos a crear:
- `turnos_admin/lib/features/tenants/data/tenant_repository.dart`
- `turnos_admin/lib/features/tenants/data/admin_user_service.dart`
- `turnos_admin/lib/features/tenants/presentation/dashboard_screen.dart`
- `turnos_admin/lib/features/tenants/presentation/create_tenant_screen.dart`
- `turnos_admin/lib/features/tenants/presentation/edit_tenant_screen.dart`
- `functions/setUserClaims.js` (Cloud Function)

---

## Phase 4: APP ADMIN - Gestión de Usuarios

**Duración**: 6-8 horas  
**Responsable**: Frontend Admin

### Tasks:

- [ ] Pantalla: Ver usuarios del tenant
  - [ ] Desde dashboard, clic en tenant → ver usuarios
  - [ ] ListView: email, rol, activo, created_at
  - [ ] Botones: Crear, Desactivar/Activar

- [ ] Crear usuario en tenant:
  - [ ] Formulario: email, contraseña, rol
  - [ ] On submit:
    - [ ] Crear usuario Auth
    - [ ] Cloud Function → Custom Claims
    - [ ] Doc en _platform/usuarios/{tenant_id}/

- [ ] Desactivar/Activar:
  - [ ] Botón que cambia `activo`
  - [ ] Usuario no puede loguear si activo=false

### Output Esperado:
- Puede crear usuarios por tenant
- Usuarios aparecen en Firestore
- Desactivación funciona

### Verificación:
```bash
# APP ADMIN
# 1. Crear tenant
# 2. Agregar usuario al tenant
# 3. Verificar en _platform/usuarios/{tenant_id}/
# 4. Desactivar usuario
# 5. Verificar activo=false en Firestore
```

### Archivos a crear:
- `turnos_admin/lib/features/tenants/presentation/tenant_users_screen.dart`
- `turnos_admin/lib/features/tenants/presentation/create_user_screen.dart`

---

## Phase 5: APP CLIENTE - Refactorización

**Duración**: 8-10 horas  
**Responsable**: Frontend Cliente

### Tasks:

- [ ] Copiar código actual como APP CLIENTE base:
  - [ ] Mantener estructura existente
  - [ ] Mantener modelos (Turno, Cliente, etc.)

- [ ] Modificar AuthRepository:
  - [ ] Login extrae tenant_id de Custom Claims
  - [ ] Guarda tenant_id en provider

- [ ] Crear TenantProvider:
  - [ ] Lee tenant_id del usuario
  - [ ] Carga doc de tenants/{tenant_id}/config/

- [ ] Crear currentTenantIdProvider:
  - [ ] Global, siempre devuelve tenant_id

- [ ] Filtrar todas las queries por tenant:
  - [ ] TurnosRepository.watchTurnos() → .where("tenant_id", isEqualTo: tenant_id)
  - [ ] ClientesRepository.watchClientes() → mismo
  - [ ] Todas las queries de datos de usuario

- [ ] Router:
  - [ ] Mantener lógica, agregar tenant check

### Output Esperado:
- APP CLIENTE compila
- Login extrae tenant_id
- TenantProvider carga config
- Todas las queries filtradas

### Verificación:
```bash
cd ..  # Volver al proyecto original (APP CLIENTE)
flutter analyze  # Sin errores

# Compilar
flutter run

# Probar login: debe llegar hasta agenda
# (sin datos aún, porque no hay tenant en Firestore)
```

### Archivos a modificar:
- `lib/features/auth/data/auth_repository.dart`
- `lib/features/auth/application/auth_providers.dart`
- Todas las repositories: agregar `.where("tenant_id", isEqualTo: tenantId)`

---

## Phase 6: APP CLIENTE - Login Multi-Tenant

**Duración**: 4-6 horas  
**Responsable**: Frontend Cliente

### Tasks:

- [ ] LoginScreen enhancement:
  - [ ] Validar que usuario tiene Custom Claims
  - [ ] Si no hay tenant_id → error

- [ ] Post-login:
  - [ ] Leer tenant_id de Custom Claims
  - [ ] Cargar tenants/{tenant_id}/
  - [ ] Verificar estado = "activo"

- [ ] AppShell:
  - [ ] Mostrar nombre del tenant en AppBar

- [ ] Error handling:
  - [ ] Si tenant suspendido → error
  - [ ] Si no hay tenant_id → error

### Output Esperado:
- Login funciona para usuarios de tenant
- Tenant config cargado
- Error si tenant suspendido

### Verificación:
```bash
# Desde APP ADMIN, crear un tenant:
# - Nombre: "Test Salon"
# - Owner: test@salon.com
# - Password: test123

# Desde APP CLIENTE:
# - Login con test@salon.com / test123
# - Debe llegar a /agenda
# - AppBar debe mostrar "Test Salon"
# - Agenda vacía (sin datos)

# Desde APP ADMIN:
# - Suspender "Test Salon"

# Desde APP CLIENTE:
# - Logout y vuelve a login
# - Debe ver error: "Tu salón ha sido suspendido"
```

### Archivos a modificar:
- `lib/features/auth/presentation/login_screen.dart`
- `lib/features/shell/presentation/app_shell.dart`

---

## Phase 7: Firestore Rules & Security

**Duración**: 4-6 horas  
**Responsable**: Security/Backend

### Tasks:

- [ ] Firestore Rules completas:
  - [ ] _platform/tenants/: solo super_admin
  - [ ] _platform/usuarios/: super_admin + usuarios de ese tenant
  - [ ] tenants/{tenant_id}/*: solo usuarios de ese tenant
  - [ ] Validar request.auth.token.tenant_id

- [ ] Verificar estado tenant:
  - [ ] En app (opcional): check antes de leer
  - [ ] En Firestore: rules bloquean si estado != "activo"

- [ ] Desplegar rules:
  ```bash
  firebase deploy --only firestore:rules
  ```

### Output Esperado:
- Rules activas en Firestore
- Aislamiento funciona
- Cross-tenant access denegado

### Verificación:
```bash
# APP ADMIN:
# - Crear tenant A
# - Crear usuario en tenant A

# APP CLIENTE:
# - Login con usuario de tenant A
# - Puede leer datos de tenant A
# - No puede leer _platform/tenants/ (denegado)

# (Verificar logs de Firestore console: Permission denied)
```

### Archivos a modificar:
- `firestore.rules`

---

## Phase 8: Testing & Integration

**Duración**: 6-8 horas  
**Responsable**: QA/Testing

### Integration Tests:

- [ ] Test 1: Crear tenant en APP ADMIN
  - [ ] Super-admin crea tenant
  - [ ] Verificar en Firestore
  - [ ] Verificar usuario admin en Auth

- [ ] Test 2: Login en APP CLIENTE
  - [ ] Usuario logueado ve su tenant
  - [ ] Agenda carga (vacía)
  - [ ] Nombre del tenant en AppBar

- [ ] Test 3: Aislamiento de datos
  - [ ] Crear tenant A y B
  - [ ] Usuario A loguea → ve A
  - [ ] Usuario B loguea → ve B
  - [ ] Nunca se cruzan datos

- [ ] Test 4: Suspensión de tenant
  - [ ] Usuario A logueado
  - [ ] Super-admin suspende tenant A
  - [ ] Usuario A próxima lectura → error
  - [ ] Usuario B funciona normal

- [ ] Test 5: Seguridad
  - [ ] Intentar acceder _platform/tenants desde APP CLIENTE → denegado
  - [ ] Intentar acceder tenants/OTRO_TENANT → denegado
  - [ ] Intentar falsificar tenant_id en token → Firestore valida

- [ ] Test 6: Performance
  - [ ] Queries rápidas (< 500ms)
  - [ ] No hay bottlenecks

### Documentation:

- [ ] README APP ADMIN:
  - [ ] Instalación
  - [ ] Setup Firebase
  - [ ] Flujos principales

- [ ] README APP CLIENTE:
  - [ ] Cambios respecto al código original
  - [ ] Nuevos providers

- [ ] Troubleshooting:
  - [ ] "Permission denied" → Custom Claims?
  - [ ] "Usuario no encontrado" → Firestore?

### Verificación Final:
```bash
# Ambas apps compilan
flutter analyze  # 0 errors

# Ambas apps corren
flutter run  # APP ADMIN
flutter run -t lib/main.dart  # APP CLIENTE

# Todos los flujos funcionan
# Ver checklist de tests arriba

# Documentación completa
# Ver README y troubleshooting
```

### Archivos a crear:
- `turnos_admin/README.md`
- `README_CLIENTE.md`
- `docs/TROUBLESHOOTING.md`

---

## 🎯 Checklist Final de MVP

- [ ] APP ADMIN compila y corre
- [ ] APP ADMIN: crear tenant (CRUD)
- [ ] APP ADMIN: crear usuarios por tenant
- [ ] APP ADMIN: editar config de tenant
- [ ] APP ADMIN: suspender tenant
- [ ] APP CLIENTE compila y corre
- [ ] APP CLIENTE: login funciona
- [ ] APP CLIENTE: datos filtrados por tenant
- [ ] APP CLIENTE: error si tenant suspendido
- [ ] Firestore Rules activas
- [ ] Cross-tenant access bloqueado
- [ ] Ambas apps funcionan juntas
- [ ] Documentación lista

---

## 📊 Tracking de Tiempo

| Fase | Estimado | Real | Status |
|------|----------|------|--------|
| Phase 0 | 2-3h | | |
| Phase 1 | 4-5h | | |
| Phase 2 | 6-8h | | |
| Phase 3 | 10-12h | | |
| Phase 4 | 6-8h | | |
| Phase 5 | 8-10h | | |
| Phase 6 | 4-6h | | |
| Phase 7 | 4-6h | | |
| Phase 8 | 6-8h | | |
| **TOTAL** | **50-66h** | | |

---

**Última actualización**: 2024-07-15  
**Versión**: 1.0
