import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tokens.dart';
import '../../../shared/models/tenant_user.dart';
import '../../auth/data/admin_user_service.dart';
import '../data/tenant_user_repository.dart';

/// Diálogo para cambiar el rol de un usuario dentro de un tenant.
///
/// Presenta:
/// - Dropdown con roles disponibles (dueno, recepcionista, estilista)
/// - Rol actual resaltado
/// - Botones de confirmar/cancelar
/// - Feedback de éxito/error
class RoleChangeDialog extends ConsumerStatefulWidget {
  const RoleChangeDialog({
    required this.tenantId,
    required this.user,
    super.key,
  });

  final String tenantId;
  final TenantUser user;

  @override
  ConsumerState<RoleChangeDialog> createState() => _RoleChangeDialogState();
}

class _RoleChangeDialogState extends ConsumerState<RoleChangeDialog> {
  late String _selectedRole;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.user.rol;
  }

  Future<void> _handleConfirm() async {
    if (_selectedRole == widget.user.rol) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final adminService = ref.read(adminUserServiceProvider);

      // Actualizar el rol en Firestore
      await adminService.updateUserRole(
        tenantId: widget.tenantId,
        uid: widget.user.uid,
        newRole: _selectedRole,
      );

      // Actualizar en el repositorio local
      await ref.read(tenantUserRepositoryProvider).updateTenantUser(
            widget.tenantId,
            widget.user.uid,
            {'rol': _selectedRole},
          );

      if (!mounted) return;

      // Mostrar feedback y cerrar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Rol de ${widget.user.nombre} actualizado a $_selectedRole',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getRoleLabel(String role) => switch (role) {
        'dueno' => 'Dueño',
        'recepcionista' => 'Recepcionista',
        'estilista' => 'Estilista',
        _ => role,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      title: const Text('Cambiar rol'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del usuario
            Text(
              widget.user.nombre,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              widget.user.email,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.lg),

            // Dropdown de roles
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Nuevo rol',
                prefixIcon: const Icon(Icons.security_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: 'dueno',
                  child: Text(_getRoleLabel('dueno')),
                ),
                DropdownMenuItem(
                  value: 'recepcionista',
                  child: Text(_getRoleLabel('recepcionista')),
                ),
                DropdownMenuItem(
                  value: 'estilista',
                  child: Text(_getRoleLabel('estilista')),
                ),
              ],
              onChanged: _isLoading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedRole = value);
                      }
                    },
            ),
            const SizedBox(height: Insets.sm),

            // Info: rol actual
            Text(
              'Rol actual: ${_getRoleLabel(widget.user.rol)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Insets.lg),

            // Mensaje de error si existe
            if (_errorMessage != null)
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(Insets.sm),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleConfirm,
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(cs.onPrimary),
                  ),
                )
              : const Text('Cambiar rol'),
        ),
      ],
    );
  }
}
