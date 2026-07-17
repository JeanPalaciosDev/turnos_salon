import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/colores.dart';
import '../../../shared/providers/tenant_providers.dart';
import '../application/trabajadores_providers.dart';
import '../domain/trabajador.dart';

/// Abre el formulario de datos básicos del trabajador (alta o edición).
/// Horarios y ausencias se gestionan en la pantalla de detalle.
Future<void> showTrabajadorForm(BuildContext context, {Trabajador? trabajador}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TrabajadorForm(trabajador: trabajador),
  );
}

class TrabajadorForm extends ConsumerStatefulWidget {
  const TrabajadorForm({super.key, this.trabajador});

  final Trabajador? trabajador;

  @override
  ConsumerState<TrabajadorForm> createState() => _TrabajadorFormState();
}

class _TrabajadorFormState extends ConsumerState<TrabajadorForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late String _color;
  late bool _activo;

  @override
  void initState() {
    super.initState();
    final t = widget.trabajador;
    _nombre = TextEditingController(text: t?.nombre ?? '');
    _color = t?.color ?? trabajadorColores.first;
    _activo = t?.activo ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final t = widget.trabajador;
    final trabajador = Trabajador(
      id: t?.id ?? '',
      nombre: _nombre.text.trim(),
      color: _color,
      activo: _activo,
      // Preservamos el horario existente; se edita en la pantalla de detalle.
      horario: t?.horario ?? const [],
    );

    // Obtener el tenant_id actual
    final tenantId = ref.read(currentTenantIdProvider).value;
    if (tenantId == null || tenantId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Tenant no disponible')),
        );
      }
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    ref
        .read(trabajadoresRepositoryProvider(tenantId))
        .upsert(trabajador)
        .catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      return trabajador.id;
    });
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.trabajador != null;
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
              isEdit ? 'Editar trabajador' : 'Nuevo trabajador',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Color', style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final hex in trabajadorColores)
                  _ColorDot(
                    hex: hex,
                    selected: hex == _color,
                    onTap: () => setState(() => _color = hex),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Guardar cambios' : 'Crear trabajador'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colorFromHex(hex),
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
