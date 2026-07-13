import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/moneda.dart';
import '../../../shared/providers/tenant_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../application/turno_providers.dart';
import '../domain/turno.dart';
import 'cerrar_turno_sheet.dart';
import 'estado_ui.dart';

/// Muestra el detalle de un turno. Devuelve `'edit'` si el usuario pidió editar
/// (el llamador abre el formulario), o `null` en cualquier otro caso.
Future<String?> showTurnoDetalle(BuildContext context, Turno turno) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TurnoDetalleSheet(turno: turno),
  );
}

class TurnoDetalleSheet extends ConsumerWidget {
  const TurnoDetalleSheet({super.key, required this.turno});

  final Turno turno;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = turno;
    final servicios = t.servicios.map((s) => s.nombre).join(' + ');
    // dueno||recepcion pueden editar/eliminar/cobrar; el estilista solo cambia
    // estado (el límite real lo refuerzan las reglas en 2E).
    final puedeGestionar = ref.watch(puedeGestionarTurnosProvider);

    void setEstado(EstadoTurno estado) {
      final tenantId = ref.read(currentTenantIdProvider).value;
      if (tenantId != null && tenantId.isNotEmpty) {
        ref.read(turnosRepositoryProvider(tenantId)).updateEstado(t.id, estado);
        Navigator.of(context).pop();
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(t.horaInicio,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 12),
              _EstadoChip(t.estado),
            ],
          ),
          const SizedBox(height: 8),
          Text(t.clienteNombre,
              style: Theme.of(context).textTheme.titleMedium),
          Text('${t.trabajadorNombre}  ·  $servicios',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (t.clienteTelefono != null && t.clienteTelefono!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Tel: ${t.clienteTelefono}'),
            ),
          if (t.notas != null && t.notas!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(t.notas!),
            ),
          if (t.cobro != null) ...[
            const Divider(height: 24),
            _ResumenCobro(t.cobro!, fechaCobro: t.fechaCobro),
          ],
          const Divider(height: 24),
          // Turnos ya completados o terminados (cancelado/no vino) no cambian
          // de estado ni se vuelven a cobrar.
          if (!_esTerminal(t.estado)) ...[
            Text('Cambiar estado',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EstadoButton(
                    'Cancelar', () => setEstado(EstadoTurno.cancelado)),
                _EstadoButton('No vino', () => setEstado(EstadoTurno.noShow)),
              ],
            ),
            if (puedeGestionar) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final cobrado = await showCerrarTurno(context, t);
                    if (cobrado == true && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Cerrar y cobrar'),
                ),
              ),
            ],
            const Divider(height: 24),
          ]
          // Cancelado / No vino son reversibles: si el cliente llega tarde,
          // se reactiva el turno volviéndolo a pendiente. Completado NO se
          // revierte aquí (lleva cobro asociado).
          else if (_esReversible(t.estado)) ...[
            Text('Cambiar estado',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setEstado(EstadoTurno.pendiente),
                icon: const Icon(Icons.undo),
                label: const Text('Reactivar turno'),
              ),
            ),
            const Divider(height: 24),
          ],
          if (puedeGestionar)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop('edit'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context, ref),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar turno'),
        content: Text(
            '¿Eliminar el turno de "${turno.clienteNombre}" a las ${turno.horaInicio}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final tenantId = ref.read(currentTenantIdProvider).value;
      if (tenantId != null && tenantId.isNotEmpty) {
        await ref.read(turnosRepositoryProvider(tenantId)).delete(turno.id);
        if (context.mounted) Navigator.of(context).pop();
      }
    }
  }
}

/// Estados que no admiten más cambios: ya completado/cobrado o descartado.
bool _esTerminal(EstadoTurno e) =>
    e == EstadoTurno.completado ||
    e == EstadoTurno.cancelado ||
    e == EstadoTurno.noShow;

/// Estados terminales que SÍ se pueden deshacer volviendo a `pendiente`
/// (el cliente canceló o no vino, pero finalmente aparece). `completado` queda
/// fuera: tiene un cobro asociado que no se revierte desde aquí.
bool _esReversible(EstadoTurno e) =>
    e == EstadoTurno.cancelado || e == EstadoTurno.noShow;

/// Resumen del cobro de un turno ya cerrado (líneas + descuento + total).
class _ResumenCobro extends StatelessWidget {
  const _ResumenCobro(this.cobro, {this.fechaCobro});

  final Cobro cobro;
  final DateTime? fechaCobro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('Cobro', style: theme.textTheme.titleSmall),
            if (cobro.metodoPago != null) ...[
              const Spacer(),
              Text(cobro.metodoPago!,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        for (final l in cobro.lineas)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(l.nombre)),
                Text(fmtMoneda(l.monto)),
              ],
            ),
          ),
        if (cobro.descuento > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Descuento'),
                Text('- ${fmtMoneda(cobro.descuento)}'),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: theme.textTheme.titleMedium),
            Text(fmtMoneda(cobro.total),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                )),
          ],
        ),
        if (cobro.notas != null && cobro.notas!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(cobro.notas!,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip(this.estado);

  final EstadoTurno estado;

  @override
  Widget build(BuildContext context) {
    final color = estadoColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(estadoLabel(estado)),
        ],
      ),
    );
  }
}

class _EstadoButton extends StatelessWidget {
  const _EstadoButton(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}
