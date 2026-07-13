# GUÍA: PRUEBA DE CAMPO EN DISPOSITIVO MÓVIL
## Turnos Salon - Multi-Tenant

**Última actualización**: 2026-07-13  
**Objetivo**: Ejecutar pruebas completas en dispositivo físico (Android/iOS)

---

## PARTE 1: PREPARACIÓN DEL DISPOSITIVO

### Paso 1: Preparar tu Dispositivo Android

#### 1.1 Habilitar Modo Desarrollador
```
Dispositivo Android:
1. Ajustes → Sobre el teléfono
2. Toca "Número de compilación" 7 veces
3. Verás: "Eres desarrollador"
4. Vuelve: Ajustes → Opciones de desarrollador
5. Habilita: "Depuración USB"
6. Conecta el dispositivo a tu PC con cable USB
```

#### 1.2 Verificar Conexión
```bash
# En PowerShell en D:\Work\turnos_salon
adb devices
# Deberías ver tu dispositivo listado
```

### Paso 2: Preparar Proyecto Flutter

```bash
# En PowerShell
cd D:\Work\turnos_admin

# Limpiar build anterior
flutter clean

# Obtener dependencias
flutter pub get

# Verificar que el dispositivo está conectado
flutter devices

# Debería mostrar tu dispositivo Android
```

---

## PARTE 2: DESPLEGAR APP ADMIN EN DISPOSITIVO

### Paso 1: Construir y Ejecutar APP ADMIN

```bash
cd D:\Work\turnos_admin

# Ejecutar en dispositivo conectado
flutter run

# Esperará 2-3 minutos en primera ejecución
# Verás: "Starting app..."
```

**¿Qué deberías ver?**
- App se abre en tu dispositivo
- Pantalla de login de Super-Admin
- Botones: "Email" y "Contraseña"

### Paso 2: Crear Credenciales Super-Admin (Primero en Firebase)

Antes de probar login, necesitas un super-admin en Firebase:

**Opción A: Via Firebase Console (Recomendado para pruebas)**
```
1. Abre: https://console.firebase.google.com
2. Proyecto: turnos-salon-163b5
3. Ve a: Authentication → Crear usuario
4. Email: admin@test.com
5. Contraseña: Admin123!@#
6. Clic: "Crear usuario"
```

**Opción B: Via Firebase CLI (Si tienes habilitado)**
```bash
# En PowerShell
firebase auth:create --email admin@test.com --password Admin123!@#
```

### Paso 3: Establecer Custom Claims (Super-admin)

Necesitas Custom Claims en Firebase. Sin Blaze Plan, hazlo manual:

**Via Firebase Console:**
```
1. Ve a: Authentication → Usuarios
2. Busca: admin@test.com
3. Clic en el usuario
4. Custom Claims (parte inferior)
5. Copia este JSON:
{
  "role": "super_admin"
}
6. Clic: "Guardar"
```

**Ahora puedes probar login en APP ADMIN**

### Paso 4: Login en APP ADMIN (Dispositivo)

En la app en tu dispositivo:
```
1. Email: admin@test.com
2. Contraseña: Admin123!@#
3. Clic: "Iniciar Sesión"

Esperado:
- ✅ Login exitoso
- ✅ Ves Dashboard con "Crear Tenant" button
- ✅ No hay errores
```

**Si falla:**
- ❌ "Credenciales inválidas" → Verifica email/password en Firebase
- ❌ "Usuario sin asignar a salón" → Falta custom claims
- ❌ "Conexión rechazada" → Verifica WiFi del dispositivo

---

## PARTE 3: CREAR TENANT DE PRUEBA (EN DISPOSITIVO)

### Paso 1: Crear Tenant via APP ADMIN

En la app en tu dispositivo:
```
1. Clic: "Crear Tenant" o "+" 
2. Llenar formulario:
   
   Nombre Salón: "Salon Test Móvil"
   Email Dueño: "dueno_test@test.com"
   Contraseña: "Test123!@#"
   Color: "#FF6B9D" (rosa)
   
3. Clic: "Guardar"
```

**Esperado:**
- ✅ Mensaje: "✅ Tenant creado"
- ✅ Tenant aparece en lista
- ✅ Estado: "Activo"

**Toma nota del:**
- Email: `dueno_test@test.com`
- Contraseña: `Test123!@#`
- Tenant ID: (visible en detalles)

---

## PARTE 4: PROBAR APP CLIENTE EN SEGUNDO DISPOSITIVO

### Opción A: Dos Dispositivos (Ideal)

```bash
# En segundo dispositivo Android
1. Conecta segundo dispositivo via USB
2. En PowerShell:
   cd D:\Work\turnos_salon
   flutter run -d <device_id_2>
   
3. Espera a que la app se abra
4. Verás LoginScreen
```

### Opción B: Emulador + Dispositivo Físico

```bash
# Terminal 1: Dispositivo físico (APP ADMIN)
cd D:\Work\turnos_admin
flutter run -d <device_id>

# Terminal 2: Emulador (APP CLIENTE)
cd D:\Work\turnos_salon
flutter run -d emulator
```

### Opción C: Mismo Dispositivo (Alternativo)

```bash
# En el mismo dispositivo Android
# Primero: Prueba APP ADMIN
flutter run

# Luego:
1. Presiona: Q para salir
2. Cambia a app cliente:
   cd D:\Work\turnos_salon
   flutter run
```

---

## PARTE 5: PROBAR LOGIN EN APP CLIENTE

### Paso 1: Login con Tenant Usuario

En APP CLIENTE en el dispositivo:
```
1. Verás: LoginScreen
2. Email: dueno_test@test.com
3. Contraseña: Test123!@#
4. Clic: "Iniciar Sesión"
```

**Esperado:**
- ✅ "Cargando configuración de tu salón..."
- ✅ Login exitoso
- ✅ Redirige a /agenda
- ✅ Ves: "Salon Test Móvil" en header
- ✅ Color rosa (#FF6B9D) en UI

### Paso 2: Verificar Branding

En APP CLIENTE:
```
1. Observa el header (AppBar)
   ✅ Nombre: "Salon Test Móvil"
   ✅ Color: Rosa (#FF6B9D)
   
2. Observa botones
   ✅ Color primario rosa
   
3. Observa rol mostrado
   ✅ Deberías ver: "Dueno" o similar
```

**Si no ves branding:**
- ❌ Verifica que custom claims tienen tenant_id
- ❌ Verifica que currentTenantProvider carga
- ❌ Mira logs: `flutter run -v` para debug

### Paso 3: Crear Turno de Prueba

En APP CLIENTE:
```
1. Clic: "+" o "Crear Turno"
2. Rellena:
   - Cliente: "Test Cliente"
   - Servicio: "Corte"
   - Fecha: Hoy
   - Hora: 14:00
   
3. Clic: "Guardar"
```

**Esperado:**
- ✅ Turno aparece en agenda
- ✅ Data guardada en Firestore

**Verifica en Firebase Console:**
```
Firestore:
- Colecciones → tenants → [tenant_id] → turnos
- Deberías ver el turno que creaste
- Ruta: tenants/{tenant_id}/turnos/{turno_id}
```

---

## PARTE 6: PRUEBA DE SUSPENSIÓN DE TENANT

### Paso 1: Suspender Tenant desde APP ADMIN

En APP ADMIN (dispositivo 1):
```
1. Ve a Dashboard
2. Busca: "Salon Test Móvil"
3. Clic: "Suspender" o botón de estado
4. Confirma: "¿Suspender?"
5. Clic: "Sí"

Esperado:
- ✅ Estado cambia a "Suspendido"
- ✅ Color cambia a naranja/rojo
```

### Paso 2: Verificar Bloqueo en APP CLIENTE

En APP CLIENTE (dispositivo 2):
```
1. La app intentará cargar data
2. Firestore Rules bloquean (isTenantActive check)
3. Deberías ver error:
   "Tu salón ha sido suspendido"
   
4. Botón: "Cerrar Sesión"
5. Login intenta fallar con mismo mensaje
```

**Si no ves el error:**
- ❌ Verifica que Firestore Rules se desplegaron
- ❌ Verifica que estado='suspendido' en Firebase
- ❌ Recarga app con: `flutter run`

### Paso 3: Reactivar Tenant

En APP ADMIN:
```
1. Busca: "Salon Test Móvil" 
2. Clic: "Reactivar"
3. Confirma

Esperado:
- ✅ Estado vuelve a "Activo"
```

En APP CLIENTE:
```
1. Logout y login nuevamente
2. Debería funcionar
3. ✅ Datos visibles nuevamente
```

---

## PARTE 7: LIMPIAR DATOS DE PRUEBA

### En Firebase Console

```
Para limpiar después de las pruebas:

1. Auth → Eliminar usuarios de prueba:
   - admin@test.com
   - dueno_test@test.com
   
2. Firestore → Eliminar documentos:
   - _platform/tenants/{test_tenant_id}
   - _platform/usuarios/{test_tenant_id}
   - tenants/{test_tenant_id}
```

### En Dispositivos

```bash
# Borrar app
flutter clean

# Reinstalar
flutter run
```

---

## CHECKLIST: PRUEBA COMPLETA

### Antes de Empezar ✅
- [ ] Dispositivo Android con modo desarrollador habilitado
- [ ] USB depuración activa
- [ ] `flutter devices` muestra el dispositivo
- [ ] Super-admin creado en Firebase con custom claims
- [ ] Conexión WiFi estable en el dispositivo

### APP ADMIN ✅
- [ ] flutter run en dispositivo
- [ ] Login de super-admin exitoso
- [ ] Ves Dashboard
- [ ] Clic "Crear Tenant" funciona
- [ ] Formulario carga
- [ ] Tenant se crea exitosamente
- [ ] Tenant aparece en lista con estado "Activo"

### APP CLIENTE ✅
- [ ] flutter run en segundo dispositivo/emulador
- [ ] LoginScreen visible
- [ ] Login con dueno_test@test.com funciona
- [ ] Redirige a /agenda
- [ ] Ves nombre del tenant en header
- [ ] Ves color rosa en UI
- [ ] Crear turno exitoso
- [ ] Turno aparece en agenda

### Prueba de Suspensión ✅
- [ ] Suspender tenant desde APP ADMIN
- [ ] APP CLIENTE muestra error "Tu salón ha sido suspendido"
- [ ] Logout/Login falla con mensaje correcto
- [ ] Reactivar tenant funciona
- [ ] APP CLIENTE funciona nuevamente

### Datos en Firebase ✅
- [ ] Tenant doc en `_platform/tenants/{id}`
- [ ] Usuario doc en `_platform/usuarios/{tenant_id}/{uid}`
- [ ] Custom claims con tenant_id y role
- [ ] Turno en `tenants/{tenant_id}/turnos/{id}`
- [ ] Ruta correcta (no global)

---

## TROUBLESHOOTING: PROBLEMAS COMUNES

### "Device not found"
```
Solución:
1. Desconecta/reconecta el cable USB
2. En dispositivo: Toca "Permitir" en diálogo USB
3. Ejecuta: adb devices
4. Intenta nuevamente: flutter run
```

### "Could not connect to Firebase"
```
Solución:
1. Verifica WiFi en dispositivo está activa
2. Verifica que la red no es "Aislada" (guest network)
3. Intenta:
   flutter run -v
   # Ve los logs de conexión Firebase
```

### "Custom claims missing"
```
Solución:
1. Ve a Firebase Console
2. Authentication → Usuario
3. Custom Claims (parte baja)
4. Copia el JSON correcto:
   {
     "role": "super_admin"  // para admin
     "tenant_id": "xyz",    // para usuario de tenant
     "role": "dueno"
   }
5. Clic: Guardar
6. Reinicia app
```

### "Tenant suspended error no aparece"
```
Solución:
1. Verifica que firestore.rules se desplegó:
   firebase firestore:describe-schema
   
2. Verifica que estado='suspendido' en Firebase:
   Firestore → _platform → tenants → [id]
   
3. Recarga app:
   flutter run
```

### "Data no aparece después de crear"
```
Solución:
1. Verifica path en Firestore:
   Debería estar en: tenants/{tenant_id}/turnos/
   NO en: turnos/ (global)
   
2. Verifica filtro tenant_id:
   En TurnosRepository - mira que filtro por tenant
   
3. Recarga app: Clic back/forward o restart
```

---

## TIPS ÚTILES PARA TESTING

### Ver Logs en Vivo
```bash
flutter run -v
# Muestra todos los logs Firebase, Firestore, etc.
```

### Debug de Firestore
```
En Firebase Console:
1. Firestore → Collections
2. Selecciona el doc que quieres ver
3. Clic para expandir subcollections
4. Verifica datos están correctos
5. Verifica path es tenant-scoped
```

### Probar Firestore Rules Sin App
```
Firebase Console:
1. Firestore → Rules
2. Clic: "Probar"
3. Simula: user con tenant_id
4. Intenta queries
5. Verifica que Rules bloquean acceso cruzado
```

### Limpiar Datos Rápidamente
```bash
# Eliminar todos los docs de prueba en Firestore Console
Firestore → _platform → tenants → [test_ids] → Eliminar todo
```

---

## PRÓXIMAS PRUEBAS (Después de Este Test)

Una vez que funcione básicamente:

1. **Crear Múltiples Tenants**
   - Repite el test con 3-5 tenants diferentes
   - Verifica aislamiento de datos

2. **Crear Múltiples Usuarios**
   - Crea usuarios con diferentes roles
   - Verifica permisos (estilista no puede eliminar)

3. **Probar Offline**
   - Desactiva WiFi en app
   - Verifica que datos cached funcionan

4. **Prueba de Carga**
   - Crea 50+ turnos
   - Verifica performance
   - Nota tiempos de carga

5. **Prueba de Roles**
   - Login como estilista
   - Intenta crear turno (debería fallar)
   - Verifica Firestore Rules bloquean

---

## SIGUIENTE PASO: COSTOS

Una vez que confirmes que funciona en tu dispositivo, 
procede a: `ANALISIS_COSTOS_FIREBASE.md`

