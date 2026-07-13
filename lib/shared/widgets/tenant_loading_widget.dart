import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../features/tenant/application/tenant_providers.dart';

/// Widget que maneja estados de carga del tenant: loading, error, suspendido, o dato.
///
/// Usado en LoginScreen y potencialmente en otras pantallas que requieren
/// que el tenant esté cargado antes de continuar.
///
/// Parámetros:
/// - [onSuccess]: Builder cuando el tenant cargó exitosamente.
/// - [showSuspendedMessage]: Si true, muestra "Tu salón está suspendido"
///   cuando el tenant estado != 'activo'.
/// - [onRetry]: Callback opcional cuando el usuario toca botón de reintentar.
class TenantLoadingWidget extends ConsumerWidget {
  const TenantLoadingWidget({
    super.key,
    required this.onSuccess,
    this.showSuspendedMessage = true,
    this.onRetry,
  });

  /// Builder que retorna widget cuando el tenant está disponible y activo.
  final Widget Function(BuildContext, WidgetRef, String tenantId, String tenantName)
      onSuccess;

  /// Si true, muestra "Tu salón está suspendido" cuando tenant.estado != 'activo'.
  final bool showSuspendedMessage;

  /// Callback cuando el usuario toca "Reintentar".
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(currentTenantProvider);

    return tenantAsync.when(
      data: (tenant) {
        // Tenant cargó exitosamente
        if (tenant == null) {
          // Edge case: usuario sin tenant asignado (ej: super_admin)
          return _buildError(
            context,
            'Usuario sin salón asignado',
            'Contacta al administrador.',
            onRetry,
          );
        }

        // Verificar que el tenant está activo
        if (showSuspendedMessage && tenant.estado != 'activo') {
          return _buildError(
            context,
            'Tu salón está suspendido',
            'El salón "${tenant.name}" fue suspendido. Contacta al administrador.',
            onRetry,
          );
        }

        // Tenant cargó y está activo: mostrar contenido
        return onSuccess(context, ref, tenant.id, tenant.name);
      },
      loading: () => _buildLoading(context, 'Cargando configuración de tu salón...'),
      error: (error, stackTrace) {
        debugPrintStack(stackTrace: stackTrace, label: 'TenantLoadingWidget error');
        return _buildError(
          context,
          'Error al cargar el salón',
          error.toString(),
          onRetry,
        );
      },
    );
  }

  /// Widget de loading con spinner y texto.
  static Widget _buildLoading(BuildContext context, String message) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Widget de error con mensaje y botón de reintentar.
  static Widget _buildError(
    BuildContext context,
    String title,
    String subtitle,
    VoidCallback? onRetry,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: cs.error,
            ),
            const SizedBox(height: Insets.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.xl),
            if (onRetry != null)
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
          ],
        ),
      ),
    );
  }
}
