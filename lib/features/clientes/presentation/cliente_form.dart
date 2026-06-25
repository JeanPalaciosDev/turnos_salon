import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clientes_repository.dart';
import '../domain/cliente.dart';

/// Abre el formulario de cliente como hoja inferior (alta o edición).
Future<void> showClienteForm(BuildContext context, {Cliente? cliente}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ClienteForm(cliente: cliente),
  );
}

class ClienteForm extends ConsumerStatefulWidget {
  const ClienteForm({super.key, this.cliente});

  final Cliente? cliente;

  @override
  ConsumerState<ClienteForm> createState() => _ClienteFormState();
}

class _ClienteFormState extends ConsumerState<ClienteForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _telefono;
  late final TextEditingController _email;
  late final TextEditingController _notas;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _nombre = TextEditingController(text: c?.nombre ?? '');
    _telefono = TextEditingController(text: c?.telefono ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _notas = TextEditingController(text: c?.notas ?? '');
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _email.dispose();
    _notas.dispose();
    super.dispose();
  }

  String? _trimOrNull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final c = widget.cliente;
    final cliente = Cliente(
      id: c?.id ?? '',
      nombre: _nombre.text.trim(),
      telefono: _trimOrNull(_telefono.text),
      email: _trimOrNull(_email.text),
      notas: _trimOrNull(_notas.text),
      createdAt: c?.createdAt,
    );

    // Patrón Firestore offline: no esperar el write para la UI.
    final messenger = ScaffoldMessenger.of(context);
    ref.read(clientesRepositoryProvider).upsert(cliente).catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      return cliente.id;
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.cliente != null;
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
              isEdit ? 'Editar cliente' : 'Nuevo cliente',
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefono,
              decoration: const InputDecoration(
                labelText: 'Teléfono (recomendado)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'Email (opcional)',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notas,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Guardar cambios' : 'Crear cliente'),
            ),
          ],
        ),
      ),
    );
  }
}
