# Plan 00: Security Remediation - Exposed Firebase Keys

**URGENTE:** Google API Keys están expuestas en GitHub  
**Status:** Requires immediate action  
**Date:** 2026-07-17

---

## 🚨 Problem Summary

GitHub Actions detectó API keys expuestas en:
- `JeanPalaciosDev/turnos_admin` (commit 37a32ba)
- `firebase_options.dart` líneas 53, 63

**Risk:** Cualquier persona puede:
- Usar tus API keys
- Generar cargos en Google Cloud Console
- Acceder a tu Firestore
- Interceptar autenticación

**Action Required:** Revocar keys + regenerar

---

## 🔐 Phase 1: Revocar Keys Comprometidas

### 1.1 En Google Cloud Console

Para **turnos_salon**:
1. Ir a https://console.cloud.google.com/
2. Seleccionar tu proyecto (turnos_salon)
3. APIs & Services → Credentials
4. Encontrar las API Keys usadas en `firebase_options.dart`
5. Hacer click en cada key → "Delete"
6. Confirmar eliminación

Para **turnos_admin**:
1. Repetir mismo proceso en su Google Cloud Project

### 1.2 Verificar que keys fueron eliminadas

```bash
# En Google Cloud Console, debería no haber keys listadas
# (o solo keys internas de Google)
```

---

## 🔄 Phase 2: Regenerar Firebase Options (Sin Secrets)

### 2.1 Re-descargar Firebase Config desde Firebase Console

```bash
# Para turnos_salon:
# 1. Firebase Console → Project Settings
# 2. Descargar google-services.json (Android)
# 3. Reemplazar D:\Work\turnos_salon\android\app\google-services.json

# Para turnos_admin:
# Repetir mismo proceso
```

### 2.2 Regenerar firebase_options.dart

```bash
# Usar FlutterFire CLI para regenerar de forma segura:
dart pub global activate flutterfire_cli

cd D:\Work\turnos_salon
flutterfire configure --project=turnos_salon --out=lib/firebase_options.dart --overwrite-firebase-options

# Repetir para turnos_admin
cd D:\Work\turnos_admin
flutterfire configure --project=turnos_admin --out=lib/firebase_options.dart --overwrite-firebase-options
```

**Nota:** FlutterFire CLI NO incluye API keys hardcodeadas - genera código seguro

### 2.3 Verificar que firebase_options.dart NO tiene secrets

```bash
# Buscar patrones sospechosos:
grep -E "api.*key|secret|AIza|x-goog" lib/firebase_options.dart
# DEBE retornar vacío (sin keys sensibles)
```

---

## 🛡️ Phase 3: Agregar a .gitignore

### 3.1 Excluir archivos con secrets

Agregar a `.gitignore` en AMBOS repositorios:

```bash
# Secrets & Credentials
.env
.env.local
google-services.json
lib/firebase_options_secrets.dart
firebase-debug.log

# Private keys
*.jks
*.p8
*.p12
*.key
key.properties
```

### 3.2 Commit the updated .gitignore

```bash
cd D:\Work\turnos_salon
git add .gitignore
git commit -m "Security: Add secrets to .gitignore"
git push origin master

cd D:\Work\turnos_admin
git add .gitignore
git commit -m "Security: Add secrets to .gitignore"
git push origin master
```

---

## 🔄 Phase 4: Rewrite Git History (Remove Secrets)

### 4.1 Usar BFG Repo-Cleaner para remover commits con secrets

```bash
# Descargar BFG:
# https://rtyley.github.io/bfg-repo-cleaner/

# Para turnos_admin (contiene secrets):
cd D:\Work\turnos_admin

# Mirror clone (necesario para BFG)
git clone --mirror https://github.com/JeanPalaciosDev/turnos_admin.git turnos_admin.git
cd turnos_admin.git

# Eliminar firebase_options.dart del history
java -jar bfg.jar --delete-files firebase_options.dart

# Push limpieza
git reflog expire --expire=now --all && git gc --prune=now --aggressive
git push --mirror

# Volver a clonar clean
cd ..
git clone https://github.com/JeanPalaciosDev/turnos_admin.git turnos_admin_clean
cd turnos_admin_clean
git log --oneline # Verificar que secrets fueron removidos
```

**Alternative (si BFG no funciona):**
```bash
# Opción nuclear: borrar repo y crear nuevo
# 1. Hacer backup local
# 2. Borrar repo en GitHub
# 3. Crear nuevo repo
# 4. Push sin secrets

# NO es ideal pero es seguro
```

### 4.2 Para turnos_salon (verificar si tiene secrets)

```bash
cd D:\Work\turnos_salon
grep -r "AIza\|x-goog\|api.*key" lib/ --include="*.dart"

# Si retorna matches: repetir proceso de BFG
# Si retorna vacío: está limpio
```

---

## ✅ Phase 5: Verificar Remediación

### 5.1 Chequear GitHub

1. Ir a repositorio en GitHub
2. Settings → Security & analysis
3. "Secret scanning" debe mostrar "No secrets detected"

### 5.2 Chequear en local

```bash
# Verificar que firebase_options.dart está seguro:
cd D:\Work\turnos_admin
cat lib/firebase_options.dart | grep -E "AIza|secret|password"
# DEBE retornar vacío

# Verificar git history
git log --all -S "AIza" --oneline
# DEBE retornar vacío
```

### 5.3 Validar que app sigue funcionando

```bash
flutter analyze
flutter test

# Build APK
flutter build apk --release
# DEBE compilar sin errores (Firebase options siguen funcionando)
```

---

## 🔑 Phase 6: Setup Secure Credential Management (Futuro)

Para evitar que esto vuelva a pasar:

### 6.1 Usar Environment Variables en lugar de hardcode

**firebase_options.dart puede leer de environment:**

```dart
// En lugar de hardcodear keys, leer de variables de entorno:
const firebaseApiKey = String.fromEnvironment(
  'FIREBASE_API_KEY',
  defaultValue: '', // En development: vacío
);
```

### 6.2 En producción (Google Play / Firebase Hosting)

Usar:
- **Firebase App Distribution:** Variables de entorno automáticas
- **Google Play Console:** Secrets en "App signing"
- **GitHub Actions:** GitHub Secrets (no en .env)

### 6.3 Setup GitHub Secrets para CI/CD

```bash
# En GitHub Repo Settings → Secrets and variables → Actions
# Agregar:
FIREBASE_API_KEY=<new_safe_key>
FIREBASE_PROJECT_ID=<project_id>
```

---

## 📋 Immediate Action Checklist

**Hoy (URGENTE):**
- [ ] Revocar API keys en Google Cloud Console
- [ ] Regenerar firebase_options.dart con FlutterFire CLI
- [ ] Verificar que NO hay secrets en nuevo archivo
- [ ] Commit cambios
- [ ] Hacer rewrite history con BFG (remover commits viejos con secrets)

**Esta semana:**
- [ ] Setup GitHub Secrets para CI/CD
- [ ] Documentar credential management process
- [ ] Entrenar al equipo en secure practices

**Futuro:**
- [ ] Implementar secret scanning en pre-commit hooks
- [ ] Usar environment variables en lugar de hardcode
- [ ] Auditar otros repositorios por secrets

---

## 🆘 If Keys Were Compromised

If anyone accessed your exposed keys:

1. **Immediately:**
   - [ ] Disable API key in Google Cloud Console
   - [ ] Monitor Google Cloud billing for suspicious charges
   - [ ] Check Firebase Authentication logs for unauthorized access

2. **Within 24 hours:**
   - [ ] Rotate all database credentials
   - [ ] Change admin email password
   - [ ] Enable 2FA on Google account

3. **Ongoing:**
   - [ ] Monitor Firestore access patterns (Firestore → Logs)
   - [ ] Check for unauthorized data modifications
   - [ ] Enable Cloud Audit Logs

---

**Priority:** CRITICAL - Execute Phase 1-4 immediately before proceeding with deployment

**Contact:** GitHub will disable the API keys automatically, but it's safer to do it yourself first.
