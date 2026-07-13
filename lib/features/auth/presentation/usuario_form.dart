import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trabajadores/data/trabajadores_repository.dart';
import '../../trabajadores/domain/trabajador.dart';
import '../data/admin_user_service.dart';
import '../data/custom_claims_service.dart';
import '../data/usuarios_repository.dart';
import '../domain/usuario.dart';

/// Abre el formulario de alta de usuario (staff). Fase 2D.
///
/// Parámetro [tenantId]: si se proporciona, se asignan Custom Claims al usuario.
Future<void> showUsuarioForm(
  BuildContext context, {
  String? tenantId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => UsuarioForm(tenantId: tenantId),
  );
}

/// Alta de staff: crea la cuenta Auth (instancia secundaria, sin desloguear al
/// admin), asigna Custom Claims (tenant_id y role) y luego crea el doc `usuarios/{uid}`.
///
/// Parámetro opcional [tenantId]: si se proporciona, se usan Custom Claims.
/// Si es null, se omite la asignación de Custom Claims (legacy, sin multi-tenant).
class UsuarioForm extends ConsumerStatefulWidget {
  const UsuarioForm({
    super.key,
    this.tenantId,
  });

  /// ID del tenant. Si es null, no se asignan Custom Claims.
  final String? tenantId;

  @override
  ConsumerState<UsuarioForm> createState() => _UsuarioFormState();
}

class _UsuarioFormState extends ConsumerState<UsuarioForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nombre = TextEditingController();
  RolTrabajador _rol = RolTrabajador.estilista;
  String? _trabajadorId;
  bool _guardando = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // 1) Crear cuenta Auth en instancia secundaria (espera red: con spinner).
      final uid = await ref.read(adminUserServiceProvider).crearCuenta(
            email: _email.text,
            password: _password.text,
          );

      // 2) Asignar Custom Claims (tenant_id y role) si está disponible el tenantId.
      // Fase 2 (multi-tenant): si no hay tenantId, se omite este paso.
      if (widget.tenantId != null) {
        try {
          await ref.read(customClaimsServiceProvider).setClaims(
                uid: uid,
                tenantId: widget.tenantId!,
                role: rolToDb(_rol),
              );
        } catch (e) {
          // Si Custom Claims fallan, abortamos para evitar usuario sin claims.
          rethrow;
        }
      }

      // 3) Escribir el doc usuarios/{uid} (patrón offline: sin await en UI).
      final usuario = Usuario(
        uid: uid,
        trabajadorId: _trabajadorId ?? '',
        rol: _rol,
        nombre: _nombre.text.trim(),
        email: _email.text.trim(),
        activo: true,
      );
      ref
          .read(usuariosRepositoryProvider)
          .crearUsuario(usuario, tenantId: widget.tenantId);

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Usuario "${usuario.nombre}" creado.')),
      );
    } on AdminUserException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      messenger.showSnackBar(SnackBar(content: Text('Error al crear: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trabajadoresAsync = ref.watch(trabajadoresStreamProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nuevo usuario',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombre,
              enabled: !_guardando,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              enabled: !_guardando,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              enabled: !_guardando,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
              validator: (v) => (v == null || v.length < 6)
                  ? 'Mínimo 6 caracteres'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RolTrabajador>(
              initialValue: _rol,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: [
                for (final r in RolTrabajador.values)
                  DropdownMenuItem(value: r, child: Text(rolLabel(r))),
              ],
              onChanged:
                  _guardando ? null : (v) => setState(() => _rol = v ?? _rol),
            ),
            const SizedBox(height: 12),
            trabajadoresAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('No se pudieron cargar trabajadores: $e'),
              data: (trabajadores) =>
                  DropdownButtonFormField<String?>(
                initialValue: _trabajadorId,
                decoration: const InputDecoration(
                  labelText: 'Trabajador vinculado (opcional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— Sin vincular —'),
                  ),
                  for (final t in trabajadores)
                    DropdownMenuItem<String?>(
                      value: t.id,
                      child: Text(t.nombre),
                    ),
                ],
                onChanged: _guardando
                    ? null
                    : (v) => setState(() => _trabajadorId = v),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardando ? null : _save,
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Crear usuario'),
            ),
          ],
        ),
      ),
    );
  }
}
