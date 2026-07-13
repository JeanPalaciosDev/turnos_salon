/// Shared domain models for multi-tenant Firestore infrastructure.
///
/// These models are used by both the app and future admin app for managing
/// the _platform collections in Firestore (tenants, users, audit logs).
///
/// Path structure:
/// - `_platform/tenants/{tenant_id}` -> Tenant
/// - `_platform/usuarios/{tenant_id}/{user_id}` -> TenantUser
/// - `_platform/audit_logs/{log_id}` -> AuditLog
/// - Nested in Tenant: Branding
library shared_models;

export 'branding.dart';
export 'tenant.dart';
export 'tenant_user.dart';
export 'audit_log.dart';
