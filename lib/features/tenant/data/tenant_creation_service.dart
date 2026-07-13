import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/config.dart';

/// Excepción personalizada para errores durante la creación de tenants.
class TenantCreationException implements Exception {
  TenantCreationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Servicio para crear nuevos tenants vía Cloud Function.
///
/// Llamadas POST a [kCloudFunctionCreateTenant] para:
/// 1. Crear documento tenant en Firestore
/// 2. Crear usuario admin en Firebase Auth
/// 3. Asignar Custom Claims (tenant_id, role='super_admin')
///
/// Lanza [TenantCreationException] con mensajes en español on error.
class TenantCreationService {
  TenantCreationService({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  /// Crea un nuevo tenant (salón).
  ///
  /// Valida inputs localmente y luego llama al Cloud Function.
  /// El Cloud Function crea:
  /// - Documento tenant en Firestore (tenants/{tenant_id})
  /// - Usuario admin en Firebase Auth
  /// - Custom Claims (tenant_id, role='super_admin')
  ///
  /// Returns: tenant_id si tiene éxito.
  /// Throws: [TenantCreationException] con mensaje en español en caso de error.
  Future<String> crearTenant({
    required String salonName,
    required String adminEmail,
    required String adminPassword,
    required String primaryColor,
    String? forceTheme,
  }) async {
    // Validación local básica
    if (salonName.trim().isEmpty || salonName.trim().length < 2) {
      throw TenantCreationException(
        'El nombre del salón debe tener al menos 2 caracteres.',
      );
    }

    if (!_isValidEmail(adminEmail)) {
      throw TenantCreationException('El correo no es válido.');
    }

    if (adminPassword.isEmpty || adminPassword.length < 6) {
      throw TenantCreationException(
        'La contraseña debe tener al menos 6 caracteres.',
      );
    }

    if (!_isValidHexColor(primaryColor)) {
      throw TenantCreationException(
        'El color debe ser un código hexadecimal válido (ej: #FFFFFF).',
      );
    }

    // Payload para el Cloud Function
    final payload = {
      'salon_name': salonName.trim(),
      'admin_email': adminEmail.trim(),
      'admin_password': adminPassword,
      'branding': {
        'color_primary': primaryColor,
        if (forceTheme != null) 'force_theme': forceTheme,
      },
    };

    try {
      final response = await _client
          .post(
            Uri.parse(kCloudFunctionCreateTenant),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(kCloudFunctionTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final tenantId = data['tenant_id'] as String?;
          if (tenantId == null || tenantId.isEmpty) {
            throw TenantCreationException(
              'La respuesta del servidor no contiene tenant_id.',
            );
          }
          return tenantId;
        } catch (e) {
          if (e is TenantCreationException) rethrow;
          throw TenantCreationException(
            'Error al procesar la respuesta del servidor.',
          );
        }
      }

      // Manejo de errores HTTP
      final errorMessage = _parseErrorResponse(response);
      throw TenantCreationException(errorMessage);
    } on TenantCreationException {
      rethrow;
    } catch (e) {
      throw TenantCreationException(
        'Error de conexión. Verifica tu red e intenta de nuevo.',
      );
    }
  }

  /// Parsea la respuesta de error del Cloud Function.
  /// Maneja códigos de error comunes y convierte a mensajes en español.
  String _parseErrorResponse(http.Response response) {
    try {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final message = data['message'] as String?;
      final code = data['code'] as String?;

      // Casos específicos según código de error
      if (code == 'email-already-in-use' || response.statusCode == 409) {
        return 'Ya existe una cuenta con ese correo. Intenta con otro.';
      }
      if (code == 'invalid-email' || response.statusCode == 400) {
        return 'Los datos ingresados no son válidos. Revisa y intenta de nuevo.';
      }
      if (code == 'weak-password') {
        return 'La contraseña es demasiado débil. Usa mayúsculas y números.';
      }

      // Mensaje genérico del servidor si existe
      if (message != null && message.isNotEmpty) {
        return message;
      }
    } catch (_) {
      // Si no se puede parsear el JSON, usa mensaje genérico
    }

    // Mensaje genérico según status code
    return switch (response.statusCode) {
      400 => 'Datos inválidos. Revisa los campos e intenta de nuevo.',
      409 => 'Ese correo ya está registrado. Usa otro correo.',
      500 || 502 || 503 => 'Error del servidor. Intenta de nuevo más tarde.',
      _ => 'No se pudo crear el salón. Intenta de nuevo.',
    };
  }

  /// Valida que el email tenga un formato básico correcto.
  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }

  /// Valida que el color sea un código hexadecimal válido (ej: #FFFFFF).
  bool _isValidHexColor(String hex) {
    final regex = RegExp(r'^#[0-9A-Fa-f]{6}$');
    return regex.hasMatch(hex);
  }
}
