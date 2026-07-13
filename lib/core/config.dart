/// Configuración global de endpoints y URLs.
///
/// Los valores se pueden sobrescribir con --dart-define en línea de comandos.
/// Ejemplo: flutter run --dart-define=CLOUD_FUNCTION_ENDPOINT=https://...

/// Endpoint del Cloud Function que asigna Custom Claims en Firebase Auth.
/// URL base: https://REGION-PROJECT_ID.cloudfunctions.net/setUserClaims
///
/// Sobrescribir en desarrollo:
///   flutter run --dart-define=CLOUD_FUNCTION_ENDPOINT=http://127.0.0.1:5001/project/region/setUserClaims
const String kCloudFunctionSetUserClaims = String.fromEnvironment(
  'CLOUD_FUNCTION_ENDPOINT',
  defaultValue: 'https://us-central1-turnos-salon-dev.cloudfunctions.net/setUserClaims',
);

/// Endpoint del Cloud Function que crea nuevos tenants (fases 5+).
/// URL: https://REGION-PROJECT_ID.cloudfunctions.net/createTenant
///
/// Sobrescribir en desarrollo:
///   flutter run --dart-define=CLOUD_FUNCTION_CREATE_TENANT=http://127.0.0.1:5001/project/region/createTenant
const String kCloudFunctionCreateTenant = String.fromEnvironment(
  'CLOUD_FUNCTION_CREATE_TENANT',
  defaultValue: 'https://us-central1-turnos-salon-dev.cloudfunctions.net/createTenant',
);

/// Timeout para requests a Cloud Functions (en segundos).
const Duration kCloudFunctionTimeout = Duration(seconds: 30);
