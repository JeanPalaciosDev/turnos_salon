import 'package:cloud_firestore/cloud_firestore.dart';

/// AuditLog records platform-level actions for compliance and debugging.
/// Document path: `_platform/audit_logs/{log_id}`.
/// Each audit entry tracks who (super_admin) did what (acción) to which tenant (tenant_id).
class AuditLog {
  const AuditLog({
    required this.id,
    required this.accion,
    required this.superAdminEmail,
    required this.tenantId,
    required this.timestamp,
    this.detalles,
  });

  /// Unique audit log identifier (Firestore auto-generated).
  final String id;

  /// Action performed (e.g., 'crear_tenant', 'suspender_tenant', 'crear_usuario').
  final String accion;

  /// Email of the super_admin who performed the action.
  final String superAdminEmail;

  /// Tenant affected by this action.
  final String tenantId;

  /// When the action was performed.
  final DateTime timestamp;

  /// Optional structured details about the action.
  /// Example: { 'tenant_name': 'Salón Ana', 'old_estado': 'activo', 'new_estado': 'suspendido' }
  final Map<String, dynamic>? detalles;

  /// Create AuditLog from Firestore document map.
  factory AuditLog.fromJson(String id, Map<String, dynamic> json) {
    return AuditLog(
      id: id,
      accion: json['accion'] as String? ?? '',
      superAdminEmail: json['super_admin_email'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      timestamp:
          (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      detalles: json['detalles'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Firestore document map (snake_case keys).
  Map<String, dynamic> toJson() => {
        'accion': accion,
        'super_admin_email': superAdminEmail,
        'tenant_id': tenantId,
        'timestamp': Timestamp.fromDate(timestamp),
        if (detalles != null) 'detalles': detalles,
      };

  /// Create a copy with optional field overrides.
  AuditLog copyWith({
    String? accion,
    String? superAdminEmail,
    String? tenantId,
    DateTime? timestamp,
    Map<String, dynamic>? detalles,
  }) =>
      AuditLog(
        id: id,
        accion: accion ?? this.accion,
        superAdminEmail: superAdminEmail ?? this.superAdminEmail,
        tenantId: tenantId ?? this.tenantId,
        timestamp: timestamp ?? this.timestamp,
        detalles: detalles ?? this.detalles,
      );
}
