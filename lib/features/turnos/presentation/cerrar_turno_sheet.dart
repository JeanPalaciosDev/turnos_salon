import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/moneda.dart';
import '../../servicios/data/servicios_repository.dart';
import '../data/turnos_repository.dart';
import '../domain/turno.dart';

/// Métodos de pago ofrecidos al cerrar el turno.
const _metodosPago = ['Efectivo', 'Tarjeta', 'Transferencia', 'Otro'];

/// Abre la hoja "Cerrar turno". Devuelve `true` si se registró el cobro.
Future<bool?> showCerrarTurno(BuildContext context, Turno turno) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      // Deja sitio al teclado cuando se editan los montos.
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: CerrarTurnoSheet(turno: turno),
    ),
  );
}

/// Captura el cobro real del turno: un monto editable por servicio (prellenado
/// con el precio de referencia), descuento opcional, método de pago y total en
/// vivo. Al finalizar registra el [Cobro] vía transacción y marca completado.
class CerrarTurnoSheet extends ConsumerStatefulWidget {
  const CerrarTurnoSheet({super.key, required this.turno});

  final Turno turno;

  @override
  ConsumerState<CerrarTurnoSheet> createState() => _CerrarTurnoSheetState();
}

class _CerrarTurnoSheetState extends ConsumerState<CerrarTurnoSheet> {
  late final List<TextEditingController> _montos;
  final _descuentoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String? _metodo;
  bool _guardando = false;
  bool _prellenado = false;

  @override
  void initState() {
    super.initState();
    _montos = [
      for (final _ in widget.turno.servicios) TextEditingController(),
    ];
    for (final c in _montos) {
      c.addListener(_recalcular);
    }
    _descuentoCtrl.addListener(_recalcular);
  }

  @override
  void dispose() {
    for (final c in _montos) {
      c.dispose();
    }
    _descuentoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  void _recalcular() => setState(() {});

  num get _subtotal =>
      _montos.fold<num>(0, (acc, c) => acc + parseMonto(c.text));

  num get _descuento => parseMonto(_descuentoCtrl.text);

  num get _total {
    final t = _subtotal - _descuento;
    return t < 0 ? 0 : t;
  }

  /// Prellena cada monto con el precio de referencia del servicio (una sola vez,
  /// cuando llega el catálogo de servicios desde Firestore).
  void _prellenarSiHaceFalta(Map<String, num> precios) {
    if (_prellenado) return;
    _prellenado = true;
    for (var i = 0; i < widget.turno.servicios.length; i++) {
      final precio = precios[widget.turno.servicios[i].servicioId] ?? 0;
      if (precio > 0) _montos[i].text = fmtMontoEditable(precio);
    }
  }

  Future<void> _finalizar() async {
    final t = widget.turno;
    final lineas = [
      for (var i = 0; i < t.servicios.length; i++)
        LineaCobro(
          servicioId: t.servicios[i].servicioId,
          nombre: t.servicios[i].nombre,
          monto: parseMonto(_montos[i].text),
        ),
    ];
    final cobro = Cobro(
      lineas: lineas,
      total: _total,
      descuento: _descuento,
      metodoPago: _metodo,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );

    setState(() => _guardando = true);
    try {
      await ref.read(turnosRepositoryProvider).registrarCobro(t.id, cobro);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cobrado ${fmtMoneda(_total)}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar el turno: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.turno;
    final theme = Theme.of(context);

    // Precios de referencia para prellenar (si el catálogo ya cargó).
    final servicios = ref.watch(serviciosStreamProvider).value;
    if (servicios != null) {
      _prellenarSiHaceFalta({for (final s in servicios) s.id: s.precioReferencia});
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cerrar turno', style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text('${t.clienteNombre}  ·  ${t.horaInicio}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Text('Cobro por servicio', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < t.servicios.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Text(t.servicios[i].nombre)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _montos[i],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(
                        prefixText: '\$ ',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(child: Text('Descuento')),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _descuentoCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Método de pago', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in _metodosPago)
                ChoiceChip(
                  label: Text(m),
                  selected: _metodo == m,
                  onSelected: (sel) =>
                      setState(() => _metodo = sel ? m : null),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notasCtrl,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: theme.textTheme.titleMedium),
              Text(fmtMoneda(_total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _guardando ? null : _finalizar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.point_of_sale),
              label: Text(_guardando ? 'Guardando…' : 'Finalizar y cobrar'),
            ),
          ),
        ],
      ),
    );
  }
}
