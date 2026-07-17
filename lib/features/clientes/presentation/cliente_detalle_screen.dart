import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/horas.dart';
import '../../../core/util/moneda.dart';
import '../../turnos/application/turno_providers.dart';
import '../../turnos/domain/turno.dart';
import '../../turnos/presentation/estado_ui.dart';
import '../domain/cliente.dart';
import 'cliente_form.dart';

/// Ficha de un cliente: datos de contacto + historial de turnos (con el cobro
/// de los que ya se cerraron). El historial sale en vivo de Firestore.
class ClienteDetalleScreen extends ConsumerWidget {
  const ClienteDetalleScreen({super.key, required this.cliente});

  final Cliente cliente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = cliente;
    final theme = Theme.of(context);
    final turnosAsync = ref.watch(turnosPorClienteProvider(c.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(c.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: () => showClienteForm(context, cliente: c),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _Contacto(c),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Historial de turnos',
                style: theme.textTheme.titleMedium),
          ),
          turnosAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error al cargar el historial:\n$e',
                  textAlign: TextAlign.center),
            ),
            data: (turnos) {
              if (turnos.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Sin turnos todavía.',
                      style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant)),
                );
              }
              return Column(
                children: [for (final t in turnos) _TurnoHistorialTile(t)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Contacto extends StatelessWidget {
  const _Contacto(this.cliente);

  final Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final c = cliente;
    final tieneTel = c.telefono != null && c.telefono!.isNotEmpty;
    final tieneMail = c.email != null && c.email!.isNotEmpty;
    final tieneNotas = c.notas != null && c.notas!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tieneTel)
            _Fila(Icons.phone_outlined, c.telefono!)
          else
            _Fila(Icons.phone_outlined, 'Sin teléfono', atenuado: true),
          if (tieneMail) _Fila(Icons.mail_outline, c.email!),
          if (tieneNotas) _Fila(Icons.notes_outlined, c.notas!),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.icon, this.texto, {this.atenuado = false});

  final IconData icon;
  final String texto;
  final bool atenuado;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: atenuado ? TextStyle(color: color) : null),
          ),
        ],
      ),
    );
  }
}

class _TurnoHistorialTile extends StatelessWidget {
  const _TurnoHistorialTile(this.turno);

  final Turno turno;

  @override
  Widget build(BuildContext context) {
    final t = turno;
    final servicios = t.servicios.map((s) => s.nombre).join(' + ');
    final fecha = fmtFechaLegible(parseFecha(t.fecha));
    return ListTile(
      leading: Container(
        width: 10,
        height: 10,
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: estadoColor(t.estado),
          shape: BoxShape.circle,
        ),
      ),
      title: Text('$fecha · ${t.horaInicio}'),
      subtitle: Text('$servicios  ·  ${estadoLabel(t.estado)}'),
      trailing: t.cobro != null
          ? Text(fmtMoneda(t.cobro!.total),
              style: const TextStyle(fontWeight: FontWeight.w600))
          : null,
    );
  }
}
