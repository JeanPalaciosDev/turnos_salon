import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/tenant_providers.dart';
import '../application/servicios_providers.dart';
import '../domain/servicio.dart';

/// Abre el formulario de servicio como hoja inferior (alta o edición).
Future<void> showServicioForm(BuildContext context, {Servicio? servicio}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ServicioForm(servicio: servicio),
  );
}

class ServicioForm extends ConsumerStatefulWidget {
  const ServicioForm({super.key, this.servicio});

  final Servicio? servicio;

  @override
  ConsumerState<ServicioForm> createState() => _ServicioFormState();
}

class _ServicioFormState extends ConsumerState<ServicioForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _precio;
  late final TextEditingController _duracion;
  late final TextEditingController _categoria;
  late bool _activo;

  @override
  void initState() {
    super.initState();
    final s = widget.servicio;
    _nombre = TextEditingController(text: s?.nombre ?? '');
    _precio = TextEditingController(text: s?.precioReferencia.toString() ?? '');
    _duracion = TextEditingController(text: s?.duracionMin.toString() ?? '30');
    _categoria = TextEditingController(text: s?.categoria ?? '');
    _activo = s?.activo ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _precio.dispose();
    _duracion.dispose();
    _categoria.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final s = widget.servicio;
    final categoria = _categoria.text.trim();
    final servicio = Servicio(
      id: s?.id ?? '',
      nombre: _nombre.text.trim(),
      precioReferencia: num.tryParse(_precio.text.trim()) ?? 0,
      duracionMin: int.tryParse(_duracion.text.trim()) ?? 30,
      activo: _activo,
      categoria: categoria.isEmpty ? null : categoria,
      color: s?.color,
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

    // Firestore con persistencia offline: el cache local + el stream reflejan el
    // cambio al instante. El Future de escritura solo se resuelve con el ACK del
    // servidor, así que NO lo esperamos (dejaría el spinner colgado). Cerramos ya
    // y manejamos un eventual error en segundo plano.
    final messenger = ScaffoldMessenger.of(context);
    ref
        .read(serviciosRepositoryProvider(tenantId))
        .upsert(servicio)
        .catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      return servicio.id;
    });
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.servicio != null;
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
              isEdit ? 'Editar servicio' : 'Nuevo servicio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _precio,
                    decoration: const InputDecoration(
                      labelText: 'Precio ref.',
                      prefixText: '\$ ',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final n = num.tryParse((v ?? '').trim());
                      if (n == null || n < 0) return 'Inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _duracion,
                    decoration: const InputDecoration(
                      labelText: 'Duración',
                      suffixText: 'min',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'Inválido';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoria,
              decoration:
                  const InputDecoration(labelText: 'Categoría (opcional)'),
              textCapitalization: TextCapitalization.sentences,
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
              child: Text(isEdit ? 'Guardar cambios' : 'Crear servicio'),
            ),
          ],
        ),
      ),
    );
  }
}
