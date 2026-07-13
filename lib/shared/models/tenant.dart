import 'package:cloud_firestore/cloud_firestore.dart';
import 'branding.dart';

/// Tenant represents a salon organization in the multi-tenant system.
/// Top-level document path: `_platform/tenants/{tenant_id}`.
/// Each tenant owns all sub-collections (turnos, clientes, trabajadores, servicios).
class Tenant {
  const Tenant({
    required this.id,
    required this.name,
    required this.estado,
    required this.branding,
    required this.ownerEmail,
    required this.createdAt,
    this.updatedAt,
  });

  /// Unique tenant identifier (e.g., 'tenant_001').
  final String id;

  /// Salon name (e.g., 'Salón Ana').
  final String name;

  /// Tenant status: 'activo', 'suspendido', or 'deleted'.
  /// When 'suspendido', all users are blocked from accessing their data.
  final String estado;

  /// Branding config for this tenant's UI (colors, logo, theme).
  final Branding branding;

  /// Email of the tenant owner (super_admin who manages this tenant).
  final String ownerEmail;

  /// Timestamp when tenant was created.
  final DateTime createdAt;

  /// Timestamp when tenant was last modified.
  final DateTime? updatedAt;

  /// Create Tenant from Firestore document map.
  factory Tenant.fromJson(String id, Map<String, dynamic> json) {
    return Tenant(
      id: id,
      name: json['name'] as String? ?? '',
      estado: json['estado'] as String? ?? 'activo',
      branding: json['branding'] != null
          ? Branding.fromJson(
              Map<String, dynamic>.from(json['branding'] as Map))
          : const Branding(),
      ownerEmail: json['owner_email'] as String? ?? '',
      createdAt: (json['created_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      updatedAt: (json['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document map (snake_case keys).
  Map<String, dynamic> toJson() => {
        'name': name,
        'estado': estado,
        'branding': branding.toJson(),
        'owner_email': ownerEmail,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': updatedAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(updatedAt!),
      };

  /// Create a copy with optional field overrides.
  Tenant copyWith({
    String? name,
    String? estado,
    Branding? branding,
    String? ownerEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Tenant(
        id: id,
        name: name ?? this.name,
        estado: estado ?? this.estado,
        branding: branding ?? this.branding,
        ownerEmail: ownerEmail ?? this.ownerEmail,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
