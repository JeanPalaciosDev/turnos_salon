# Distribución Manual de APKs - turnos_salon & turnos_admin

**Fecha:** 2026-07-17  
**Método:** Descarga directa (Google Drive)  
**Usuarios:** Máximo 5 dispositivos

---

## 📦 APKs Generados

### turnos_salon (App Principal)
- **Archivo:** `D:\Work\turnos_salon\build\app\outputs\flutter-apk\app-release.apk`
- **Tamaño:** 55 MB
- **Versión:** 1.0.0
- **Descripción:** App para usuarios del salón (clientes, agenda, turnos)
- **Requisitos:** Android 10+ (API 29+)

### turnos_admin (App de Admin)
- **Archivo:** `D:\Work\turnos_admin\build\app\outputs\flutter-apk\app-release.apk`
- **Tamaño:** 49 MB
- **Versión:** 1.0.0
- **Descripción:** App para super-admin (gestión de tenants)
- **Requisitos:** Android 10+ (API 29+)

---

## 🔗 Distribuir vía Google Drive

### Paso 1: Subir APKs a Google Drive

```
1. Ir a Google Drive (drive.google.com)
2. Crear carpeta: "turnos_salon_apks"
3. Subir ambos archivos:
   - turnos_salon-v1.0.0.apk (55 MB)
   - turnos_admin-v1.0.0.apk (49 MB)
4. Hacer público:
   - Click derecho en carpeta → Share
   - Cambiar a "Anyone with the link"
   - Copiar link de compartir
```

### Paso 2: Crear links de descarga directa

Google Drive Link (carpeta):
```
https://drive.google.com/drive/folders/[FOLDER_ID]?usp=sharing
```

Link descarga directa (APK individual):
```
https://drive.google.com/u/0/uc?id=[FILE_ID]&export=download
```

---

## 📱 Instrucciones para Usuarios

### Para Instalar turnos_salon (Cliente/Operador):

**1. Descargar APK**
```
1. Abrir link de descarga en dispositivo Android
2. Permitir descargas de fuentes desconocidas:
   Settings → Apps & notifications → Advanced → Install unknown apps → Allow
3. Descargar APK (55 MB)
```

**2. Instalar**
```
1. Abrir archivos / File Manager
2. Ir a Descargas (Downloads)
3. Encontrar "turnos_salon-v1.0.0.apk"
4. Tap en archivo → Install
5. Esperar a que instale (~30 segundos)
6. Tap en "Open" cuando termine
```

**3. Primera vez abierta**
```
1. App pide permisos (calendario, contactos) → Allow
2. Pide login con email/password (Firebase Auth)
3. Crear cuenta o usar existente
4. ¡Listo! La app está lista
```

### Para Instalar turnos_admin (Super-Admin):

Mismo proceso, pero con `turnos_admin-v1.0.0.apk`

---

## 🔄 Actualizaciones Futuras

### Cuando hay nuevas versiones (semanales):

**1. Incrementar versión:**
```bash
cd D:\Work\turnos_salon
# Cambiar en pubspec.yaml:
# version: 1.0.0+1  →  1.0.1+2

git add pubspec.yaml
git commit -m "Bump version to 1.0.1"
git push origin master
```

**2. Build nuevo APK:**
```bash
flutter build apk --release
```

**3. Subir a Google Drive:**
```
- Reemplazar archivo anterior en Google Drive
- O crear nueva versión: turnos_salon-v1.0.1.apk
```

**4. Notificar a usuarios:**
```
Enviar email/WhatsApp:
"Nueva versión disponible v1.0.1
Descargar: [LINK]
Cambios: [CHANGELOG]"
```

### Usuarios instalan actualización:
```
1. Descargar nuevo APK
2. Instalar (reemplaza versión anterior)
3. Datos se mantienen (Firestore es el source of truth)
```

---

## 📊 Versioning Strategy

```
Formato: MAJOR.MINOR.PATCH+BUILD

Ejemplo: 1.0.1+2
- 1 = MAJOR (cambios grandes)
- 0 = MINOR (features nuevas)
- 1 = PATCH (bug fixes)
- 2 = BUILD (número de compilación)

Cambiar PATCH o MINOR semanalmente
MAJOR es raro
```

---

## 🛡️ Seguridad en Distribución

✅ **APKs están firmados** (keystore)
✅ **SHA-256 verificable:**
```bash
# Verificar integridad del APK
keytool -list -v -keystore D:\turnos_salon_keystore.jks \
  -alias turnos_salon_key
```

✅ **Google Play Protect:** Escanea APK automáticamente en Android 6+

⚠️ **NO compartir:** Keystore ni passwords en los links

---

## 📋 Checklist Distribución

### Antes de enviar link:
- [ ] APK generado y testeado
- [ ] Tamaño < 100 MB
- [ ] Versión incrementada en pubspec.yaml
- [ ] Archivo renombrado con versión (v1.0.1)
- [ ] Subido a Google Drive
- [ ] Link compartido público
- [ ] Instrucciones preparadas

### Después de enviar:
- [ ] Usuarios confirman descarga
- [ ] Usuarios confirman instalación exitosa
- [ ] Chequear Firebase Crashlytics por errores
- [ ] Registrar feedback

---

## 🆘 Troubleshooting para Usuarios

| Problema | Solución |
|----------|----------|
| "App no instalada" | Chequear Android version (min 10), eliminar versión anterior |
| "Descarga interrumpida" | Reintentar descarga, chequear WiFi |
| "Firebase auth no funciona" | Chequear internet, regenerar token en app |
| "Crash al abrir" | Desinstalar, limpiar cache, reinstalar |
| "Datos no sincronizan" | Chequear Firestore connection, WiFi |

---

## 📌 Resumen

**Distribución manual es perfecta para:**
- MVP / testing phase
- Pequeños equipos (< 10 usuarios)
- Updates frecuentes sin wait de app stores

**Cuando escales (100+ usuarios):**
- Migrar a Google Play Store
- Usar Firebase App Distribution
- Automatizar con CI/CD

---

**Próximos pasos:**
1. Subir ambos APKs a Google Drive
2. Crear links de descarga
3. Enviar links a usuarios con instrucciones
4. Monitorear en Crashlytics
5. Siguiente update: repetir proceso
