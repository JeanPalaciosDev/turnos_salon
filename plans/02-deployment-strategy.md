# Plan 02: Deployment Strategy - turnos_salon & turnos_admin

**Status:** Planning phase  
**Date:** 2026-07-17  
**Scope:** Build APKs, configure Firebase, distribute to devices, production setup

---

## 📋 Phase 0: Prerequisites & Requirements

**Before building APKs, verify:**

1. **Android SDK Setup**
   ```bash
   flutter doctor -v
   # DEBE retornar:
   # ✓ Flutter SDK
   # ✓ Android toolchain
   # ✓ Android Studio (o equivalente)
   ```

2. **Signing Certificate**
   - ✅ Generar keystore para firmar APKs
   - ✅ Guardar credenciales en lugar seguro
   - ✅ NO commitear keystore a git

3. **Firebase Projects**
   - ✅ turnos_salon: Firebase project configurado
   - ✅ turnos_admin: Firebase project separado (super-admin only)
   - ✅ API keys y credenciales en `firebase_options.dart`

4. **Device Preparation**
   - ✅ Dispositivos con Android 10+ (API 29+)
   - ✅ Almacenamiento suficiente (>100MB por app)
   - ✅ Conexión a internet (setup Firebase)

---

## 🔨 Phase 1: Build APK - turnos_salon

**Objetivo:** Generar APK optimizado para distribución

### 1.1 Preparar build

```bash
cd D:\Work\turnos_salon

# Limpiar builds anteriores
flutter clean

# Descargar dependencies
flutter pub get

# Generar código Dart/Firebase
dart run build_runner build --delete-conflicting-outputs

# Análisis final
flutter analyze
```

**Verificación:** DEBE compilar sin errores críticos

### 1.2 Generar signing certificate (primera vez)

```bash
# En Windows, generar keystore:
keytool -genkey -v -keystore D:\turnos_salon_keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias turnos_salon_key

# IMPORTANTE: Guardar password en lugar seguro (1Password, LastPass, etc.)
# NO subir keystore a git
```

**Archivo a crear:**
- `D:\turnos_salon_keystore.jks` (keystore file)
- `key.properties` en `D:\Work\turnos_salon\android\` (credenciales)

Contenido de `key.properties`:
```properties
storePassword=<password_del_keystore>
keyPassword=<password_de_la_key>
keyAlias=turnos_salon_key
storeFile=D:\\turnos_salon_keystore.jks
```

### 1.3 Build APK

```bash
cd D:\Work\turnos_salon

# Build release APK (optimizado, firmado)
flutter build apk --release

# Output: D:\Work\turnos_salon\build\app\outputs\flutter-apk\app-release.apk
```

**Verificación:**
```bash
# Verificar que APK existe
ls -la build/app/outputs/flutter-apk/app-release.apk

# Verificar tamaño (debe ser ~50-80MB)
du -h build/app/outputs/flutter-apk/app-release.apk
```

**Anti-patterns:**
- ❌ NO usar `flutter build apk --debug` para producción
- ❌ NO subir APKs sin firmar
- ❌ NO usar keystore compartido entre apps

---

## 🔨 Phase 2: Build APK - turnos_admin

**Objetivo:** Generar APK de admin separado

### 2.1 Preparar build

```bash
cd D:\Work\turnos_admin

flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

### 2.2 Generar signing certificate (SEPARADO)

```bash
# Generar keystore DIFERENTE para admin app
keytool -genkey -v -keystore D:\turnos_admin_keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias turnos_admin_key

# Crear key.properties para admin
# D:\Work\turnos_admin\android\key.properties
```

### 2.3 Build APK

```bash
cd D:\Work\turnos_admin

flutter build apk --release

# Output: D:\Work\turnos_admin\build\app\outputs\flutter-apk\app-release.apk
```

---

## 📱 Phase 3: Firebase Configuration on Devices

**Objetivo:** Configurar Firebase auth en dispositivos físicos

### 3.1 Enable SHA-1 fingerprint in Firebase Console

Para cada app (turnos_salon y turnos_admin):

```bash
# Generar SHA-1 fingerprint del keystore
keytool -list -v -keystore D:\turnos_salon_keystore.jks \
  -alias turnos_salon_key -storepass <password>

# Copiar el SHA-1 fingerprint (ej: AA:BB:CC:DD:...)
```

En Firebase Console:
1. Ir a Project Settings
2. Ir a "Your apps" → Android app
3. Agregar SHA-1 fingerprint en "App signing certificate"
4. Descargar actualizado `google-services.json`
5. Reemplazar en `android/app/google-services.json`

### 3.2 Rebuild con Firebase config actualizado

```bash
cd D:\Work\turnos_salon

flutter clean
flutter pub get
flutter build apk --release

# Repetir para turnos_admin
```

---

## 📲 Phase 4: Distribute to Devices

### 4.1 Install on device via USB

```bash
# Conectar dispositivo con USB (developer mode enabled)
flutter devices  # Verificar que aparece el device

cd D:\Work\turnos_salon
flutter install  # Instala app en device

# Repetir para turnos_admin
cd D:\Work\turnos_admin
flutter install
```

### 4.2 Install APK manually (si no tienes USB/adb)

1. Copiar APK a dispositivo (email, Google Drive, etc.)
2. Abrir file manager en dispositivo
3. Tap en APK → Install → Allow unknown sources

### 4.3 Distribution Options (para múltiples usuarios)

| Método | Use Case | Setup |
|--------|----------|-------|
| **Google Play Store** | Producción, múltiples usuarios | ⏳ Esperar aprobación Google (3-5 días) |
| **Firebase App Distribution** | Beta testing, internal distribution | ✅ Rápido (< 1 min) |
| **APK directo (email/drive)** | Pruebas, amigos/familia | ✅ Inmediato, pero sin actualizaciones automáticas |
| **Android Enterprise** | Dispositivos corporativos | ⏳ Requiere MDM setup |

**Recomendación para MVP:** Firebase App Distribution (testing) → Google Play Store (producción)

---

## ✅ Phase 5: Production Testing

### 5.1 Smoke Tests (en dispositivo)

**turnos_salon:**
- [ ] App abre sin crashes
- [ ] Firebase login funciona
- [ ] Puede crear cliente
- [ ] Puede crear turno
- [ ] Puede guardar cambios
- [ ] Firestore Rules funcionan (lectura/escritura)

**turnos_admin:**
- [ ] App abre sin crashes
- [ ] Firebase super-admin login funciona
- [ ] Puede crear tenant
- [ ] Puede crear usuario para tenant
- [ ] Puede suspender/reactivar tenant
- [ ] Cloud Functions funcionan (setUserClaims)

### 5.2 Integration Test

```bash
# En el dispositivo con turnos_salon:
1. Login como usuario del tenant
2. Crear cliente X
3. Crear turno para cliente X
4. Cambiar estado de turno

# En el dispositivo con turnos_admin:
1. Login como super-admin
2. Ver tenant con turno del step 4 arriba
3. Verificar datos sincronizados (Firestore)
```

### 5.3 Performance Check

- ✅ App no tarda más de 3 segundos en abrir
- ✅ Crear turno no tarda más de 2 segundos
- ✅ Battery usage < 5% en uso normal
- ✅ Data usage < 10MB por sesión de 1 hora

---

## 🚀 Phase 6: Production Deployment

### 6.1 Google Play Store Submission

**Para turnos_salon (user-facing):**

1. Crear Google Play Developer Account ($25 USD)
2. Setup app signing en Google Play Console
3. Upload APK release
4. Fill store listing:
   - App name
   - Short description
   - Full description
   - Screenshots (4-5)
   - Category: "Business"
   - Content rating questionnaire
5. Submit for review (3-5 days)
6. Once approved: toggle "Production" release

**Para turnos_admin (internal only):**

- ✅ NO subir a Play Store (solo para admins)
- ✅ Usar Firebase App Distribution o manual distribution
- ✅ O crear Google Play app con acceso "Internal testing" only

### 6.2 Continuous Deployment (CI/CD)

**Setup GitHub Actions para auto-build:**

```yaml
name: Build APKs
on:
  push:
    branches: [master]
  
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v3
        with:
          name: apk-artifacts
          path: build/app/outputs/flutter-apk/
```

---

## 📊 Phase 7: Monitoring & Updates

### 7.1 Track Install Metrics

- Google Play Console: Installs, uninstalls, crashes, ratings
- Firebase Crashlytics: Real-time crash reports
- Firebase Analytics: User behavior, session duration

### 7.2 Deploy Updates

```bash
# Incrementar version en pubspec.yaml
# turnos_salon/pubspec.yaml:
# version: 1.0.0+1  →  1.0.1+2

# Rebuild
flutter build apk --release

# Upload new APK a Google Play Console
```

### 7.3 Rollback Procedure

Si hay crítico bug en producción:
1. Revert commit en git
2. Rebuild APK
3. Upload a Google Play Console as "Staged rollout" 0%
4. Increment users gradually (5% → 10% → 50% → 100%)
5. Monitor Crashlytics para issues

---

## 🔑 Credentials Management

**IMPORTANTE: Nunca commitear keystore o credenciales**

### Setup (una sola vez):

```bash
# 1. Generar keystores
keytool -genkey -v -keystore ~\turnos_salon_keystore.jks ...
keytool -genkey -v -keystore ~\turnos_admin_keystore.jks ...

# 2. Guardar passwords en:
# - 1Password / LastPass / Bitwarden
# - Notas locales encriptadas (NO en cloud)
# - NO en git, NO en email

# 3. key.properties solo en máquina local
# Agregar a .gitignore:
echo "android/key.properties" >> .gitignore
echo "*_keystore.jks" >> .gitignore
```

---

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] `flutter analyze` retorna 0 errores
- [ ] `flutter test` pasa todos los tests
- [ ] Git branch está limpio
- [ ] CHANGELOG.md actualizado con cambios

### Build Phase
- [ ] APK generado y firmado
- [ ] APK testeado en dispositivo
- [ ] Tamaño APK < 100MB
- [ ] SHA-1 fingerprint en Firebase Console

### Release Phase
- [ ] Screenshots y descripción listos
- [ ] Version number incrementado
- [ ] Release notes preparadas
- [ ] App signing certificate verificado

### Post-Release
- [ ] App disponible en Google Play
- [ ] Usuarios pueden descargar
- [ ] Crashlytics monitoreando
- [ ] Analytics registrando eventos

---

## 🆘 Troubleshooting

| Problema | Solución |
|----------|----------|
| "Plugin not found" | Correr `flutter pub get` y limpiar |
| APK no instala | Verificar versión Android target (minSdkVersion) |
| Firebase auth falla | Verificar SHA-1 en Firebase Console |
| Muy lento/crashes | Profiler: `flutter run --profile` |
| Google Play rechaza app | Revisar privacy policy, permisos en AndroidManifest |

---

**Próximos pasos:**
1. Responde las preguntas de deployment (plataformas, # usuarios)
2. Ejecutaremos Phase 1-4 (builds + install)
3. Haremos testing en dispositivo
4. Luego Phase 6-7 (Google Play Store + monitoring)
