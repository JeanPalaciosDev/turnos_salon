/// Usuario del sistema: doc `usuarios/{uid}` (cuenta Auth).
///
/// NO confundir con [Trabajador] (`trabajadores/{id}`, perfil de agenda).
/// El [uid] es el UID de Firebase Auth (no autogenerado por Firestore).
class Usuario {
  const Usuario({
    required this.uid,
    required this.trabajadorId,
    required this.nombre,
    required this.email,
    required this.activo,
  });

  final String uid;

  /// Vínculo a `trabajadores/{id}`.
  final String trabajadorId;

  /// Denormalizado para UI.
  final String nombre;

  /// Denormalizado (referencia).
  final String email;
  final bool activo;

  factory Usuario.fromMap(String uid, Map<String, dynamic> m) => Usuario(
        uid: uid,
        trabajadorId: m['trabajador_id'] as String? ?? '',
        nombre: m['nombre'] as String? ?? '',
        email: m['email'] as String? ?? '',
        activo: m['activo'] as bool? ?? true,
      );

  /// Nota: `created_at` se escribe con `FieldValue.serverTimestamp()` en el
  /// repositorio (no aquí), por lo que no se incluye en este map.
  Map<String, dynamic> toMap() => {
        'trabajador_id': trabajadorId,
        'nombre': nombre,
        'email': email,
        'activo': activo,
      };

  Usuario copyWith({
    String? trabajadorId,
    String? nombre,
    String? email,
    bool? activo,
  }) =>
      Usuario(
        uid: uid,
        trabajadorId: trabajadorId ?? this.trabajadorId,
        nombre: nombre ?? this.nombre,
        email: email ?? this.email,
        activo: activo ?? this.activo,
      );
}
