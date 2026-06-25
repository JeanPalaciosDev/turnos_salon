import 'package:cloud_firestore/cloud_firestore.dart';

/// Cliente del salón. El teléfono es recomendado pero no obligatorio
/// (queda listo para recordatorios futuros).
class Cliente {
  const Cliente({
    required this.id,
    required this.nombre,
    this.telefono,
    this.email,
    this.notas,
    this.createdAt,
  });

  final String id;
  final String nombre;
  final String? telefono;
  final String? email;
  final String? notas;
  final DateTime? createdAt;

  factory Cliente.fromMap(String id, Map<String, dynamic> m) => Cliente(
        id: id,
        nombre: m['nombre'] as String,
        telefono: m['telefono'] as String?,
        email: m['email'] as String?,
        notas: m['notas'] as String?,
        createdAt: (m['created_at'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'telefono': telefono,
        'email': email,
        'notas': notas,
        'created_at': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  Cliente copyWith({
    String? nombre,
    String? telefono,
    String? email,
    String? notas,
  }) =>
      Cliente(
        id: id,
        nombre: nombre ?? this.nombre,
        telefono: telefono ?? this.telefono,
        email: email ?? this.email,
        notas: notas ?? this.notas,
        createdAt: createdAt,
      );
}
