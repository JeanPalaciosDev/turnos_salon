# Levanta el Firebase Emulator Suite + la app Flutter contra el emulador, de una.
#
# Requisitos (una sola vez):
#   - Firebase CLI:  npm install -g firebase-tools
#   - Java (JDK 11+) para los emuladores
#   - Un emulador de Android corriendo (o dispositivo) antes de ejecutar esto
#
# Uso:
#   ./run-dev.ps1                       # Android emulator (host 10.0.2.2)
#   ./run-dev.ps1 -EmulatorHost 127.0.0.1   # web / Windows desktop / iOS
#
# Los datos del emulador se guardan en ./emulator-data y se reimportan en la
# próxima corrida (el seed es idempotente, así que no se duplica nada).

param(
  [string]$EmulatorHost = "10.0.2.2",
  [string]$DataDir = "./emulator-data"
)

$ErrorActionPreference = "Stop"

# 1. Firebase Emulator Suite en una ventana aparte, con persistencia de datos.
#    --config firebase.emulator.json => reglas PERMISIVAS (firestore.rules.emulator),
#    imprescindibles para que el seed pueda sembrar datos y cuentas demo antes del
#    login. Sin esto, las reglas estrictas dan permission-denied y NO se crean las
#    credenciales demo. Ver docs/desarrollo-local.md.
$importArg = ""
if (Test-Path $DataDir) { $importArg = "--import `"$DataDir`" " }
$fbCmd = "firebase emulators:start --config firebase.emulator.json --only auth,firestore ${importArg}--export-on-exit `"$DataDir`""
Write-Host "Levantando emuladores -> $fbCmd" -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", $fbCmd

# 2. Esperar a que Firestore (8080) acepte conexiones antes de arrancar la app,
#    si no el seed inicial falla con ECONNREFUSED.
Write-Host "Esperando a Firestore en 127.0.0.1:8080..." -ForegroundColor Cyan
while (-not (Test-NetConnection 127.0.0.1 -Port 8080 -InformationLevel Quiet)) {
  Start-Sleep -Seconds 1
}
Write-Host "Emulador listo. Panel: http://127.0.0.1:4000" -ForegroundColor Green

# 3. App Flutter apuntando al emulador.
flutter run `
  --dart-define=USE_EMULATOR=true `
  --dart-define=EMULATOR_HOST=$EmulatorHost
