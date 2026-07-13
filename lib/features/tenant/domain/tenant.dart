import 'package:cloud_firestore/cloud_firestore.dart';

/// Per multi-tenant plan Phase 1:
/// Tenant represents a salon organization. Top-level doc path: `tenants/{tenant_id}`.
/// Each tenant has its own branding config and owns all sub-collections
/// (config, servicios, trabajadores, clientes, turnos).
class Tenant {
  const Tenant({
    required this.id,
    required this.name,
    required this.estado,
    required this.branding,
    required this.ownerEmail,
    required this.createdAt,
  });

  /// Unique tenant identifier (e.g., 'tenant_0').
  final String id;

  /// Salon name.
  final String name;

  /// Tenant status: 'activo', 'suspendido', 'cancelado'.
  final String estado;

  /// Branding config for this tenant's UI.
  final Branding branding;

  /// Email of the tenant owner (super_admin).
  final String ownerEmail;

  /// Timestamp when tenant was created.
  final DateTime? createdAt;

  factory Tenant.fromMap(String id, Map<String, dynamic> m) => Tenant(
        id: id,
        name: m['name'] as String? ?? '',
        estado: m['estado'] as String? ?? 'activo',
        branding: m['branding'] != null
            ? Branding.fromMap(Map<String, dynamic>.from(m['branding'] as Map))
            : const Branding(),
        ownerEmail: m['owner_email'] as String? ?? '',
        createdAt: (m['created_at'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'estado': estado,
        'branding': branding.toMap(),
        'owner_email': ownerEmail,
        'created_at': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  Tenant copyWith({
    String? name,
    String? estado,
    Branding? branding,
    String? ownerEmail,
    DateTime? createdAt,
  }) =>
      Tenant(
        id: id,
        name: name ?? this.name,
        estado: estado ?? this.estado,
        branding: branding ?? this.branding,
        ownerEmail: ownerEmail ?? this.ownerEmail,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// Branding configuration for a tenant's UI.
/// All colors optional; app defaults apply if not set.
class Branding {
  const Branding({
    this.colorPrimary,
    this.colorSecondary,
    this.colorAccent,
    this.logoUrl,
    this.forceTheme,
  });

  /// Primary color (hex, e.g., '#534AB7').
  final String? colorPrimary;

  /// Secondary color (hex, optional).
  final String? colorSecondary;

  /// Accent color (hex, optional).
  final String? colorAccent;

  /// URL to tenant's logo.
  final String? logoUrl;

  /// Force UI theme: 'light', 'dark', or null (auto).
  final String? forceTheme;

  factory Branding.fromMap(Map<String, dynamic> m) => Branding(
        colorPrimary: m['color_primary'] as String?,
        colorSecondary: m['color_secondary'] as String?,
        colorAccent: m['color_accent'] as String?,
        logoUrl: m['logo_url'] as String?,
        forceTheme: m['force_theme'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (colorPrimary != null) 'color_primary': colorPrimary,
        if (colorSecondary != null) 'color_secondary': colorSecondary,
        if (colorAccent != null) 'color_accent': colorAccent,
        if (logoUrl != null) 'logo_url': logoUrl,
        if (forceTheme != null) 'force_theme': forceTheme,
      };

  Branding copyWith({
    String? colorPrimary,
    String? colorSecondary,
    String? colorAccent,
    String? logoUrl,
    String? forceTheme,
  }) =>
      Branding(
        colorPrimary: colorPrimary ?? this.colorPrimary,
        colorSecondary: colorSecondary ?? this.colorSecondary,
        colorAccent: colorAccent ?? this.colorAccent,
        logoUrl: logoUrl ?? this.logoUrl,
        forceTheme: forceTheme ?? this.forceTheme,
      );
}
