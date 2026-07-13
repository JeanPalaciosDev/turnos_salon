import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config.dart';

/// Servicio para asignar Custom Claims (tenant_id y role) a usuarios en Firebase Auth.
///
/// Fase 2 (Multi-tenant): después de crear una cuenta Auth, se invocan Custom Claims
/// para que Firestore Rules puedan leerlos desde `request.auth.token.claims`.
/// Ejemplo: `allow read: if request.auth.token.claims.role == 'super_admin'`
///
/// Estos claims NO se pueden asignar desde Flutter; requieren el Admin SDK de Firebase.
/// Por eso se expone un Cloud Function HTTP que actúa como intermediario.
///
/// Seguridad: el Cloud Function verifica que el caller tenga role='super_admin' antes
/// de permitir la asignación de claims a otros usuarios.
class CustomClaimsService {
  CustomClaimsService(this._auth);
  final FirebaseAuth _auth;

  /// Asigna Custom Claims a un usuario.
  ///
  /// Parámetros:
  ///   - uid: ID de la cuenta Auth del usuario
  ///   - tenantId: ID del tenant (ej: "tenant_0", "salon_abc123")
  ///   - role: Rol del usuario ("super_admin", "dueno", "recepcion", "estilista")
  ///
  /// Lanza [CustomClaimsException] si:
  ///   - No hay usuario autenticado (403)
  ///   - El usuario no tiene permiso (role != 'super_admin')
  ///   - El uid destino no existe (404)
  ///   - Network error o timeout
  ///   - Cloud Function devuelve error (500+)
  Future<void> setClaims({
    required String uid,
    required String tenantId,
    required String role,
  }) async {
    // 1. Validar que hay usuario autenticado (será quien haga la request).
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw CustomClaimsException(
        'No hay sesión activa. Debes iniciar sesión para realizar esta acción.',
      );
    }

    // 2. Obtener el token ID del usuario actual.
    IdTokenResult? idTokenResult;
    try {
      idTokenResult = await currentUser.getIdTokenResult();
    } catch (e) {
      throw CustomClaimsException(
        'No se pudo obtener el token de autenticación. Intenta de nuevo.',
        originalError: e,
      );
    }

    // 3. Invocar el Cloud Function.
    try {
      final response = await http.post(
        Uri.parse(kCloudFunctionSetUserClaims),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${idTokenResult.token}',
        },
        body: jsonEncode({
          'uid': uid,
          'tenant_id': tenantId,
          'role': role,
        }),
      ).timeout(
        kCloudFunctionTimeout,
        onTimeout: () => throw CustomClaimsException(
          'La operación tardó demasiado. Verifica tu conexión e intenta de nuevo.',
        ),
      );

      // 4. Procesar respuesta del Cloud Function.
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          // Éxito.
          return;
        }
        // Error reportado por la función pero con status 200 (edge case).
        throw CustomClaimsException(
          data['message'] as String? ??
              'No se pudieron asignar los permisos. Intenta de nuevo.',
        );
      } else if (response.statusCode == 403) {
        throw CustomClaimsException(
          'No tienes permiso para asignar roles. Solo super_admin puede hacerlo.',
        );
      } else if (response.statusCode == 404) {
        throw CustomClaimsException(
          'El usuario no existe en Firebase Auth.',
        );
      } else if (response.statusCode == 400) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          throw CustomClaimsException(
            data['message'] as String? ?? 'Parámetros inválidos.',
          );
        } catch (_) {
          throw CustomClaimsException(
            'Los parámetros enviados no son válidos.',
          );
        }
      } else if (response.statusCode >= 500) {
        throw CustomClaimsException(
          'Error en el servidor. Intenta de nuevo más tarde.',
          originalError: Exception('HTTP ${response.statusCode}'),
        );
      } else {
        throw CustomClaimsException(
          'Error al asignar permisos (${response.statusCode}). Intenta de nuevo.',
        );
      }
    } on CustomClaimsException {
      rethrow;
    } catch (e) {
      throw CustomClaimsException(
        'Error de red. Verifica tu conexión e intenta de nuevo.',
        originalError: e,
      );
    }
  }
}

/// Excepción para errores de Custom Claims con mensajes en español.
///
/// Patrón copiado de [AdminUserException] (admin_user_service.dart).
class CustomClaimsException implements Exception {
  const CustomClaimsException(
    this.message, {
    this.originalError,
  });

  /// Mensaje listo para mostrar al usuario (en español).
  final String message;

  /// Error original (para logging interno o debug).
  final dynamic originalError;

  @override
  String toString() => message;
}

final customClaimsServiceProvider = Provider<CustomClaimsService>(
  (ref) => CustomClaimsService(FirebaseAuth.instance),
);
