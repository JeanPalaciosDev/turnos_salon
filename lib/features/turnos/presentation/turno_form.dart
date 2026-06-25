import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/colores.dart';
import '../../../core/util/horas.dart';
import '../../auth/application/auth_providers.dart';
import '../../clientes/data/clientes_repository.dart';
import '../../clientes/presentation/cliente_form.dart';
import '../../servicios/data/servicios_repository.dart';
import '../../servicios/domain/servicio.dart';
import '../../trabajadores/data/trabajadores_repository.dart';
import '../data/turnos_repository.dart';
import '../domain/turno.dart';

/// Abre el formulario de alta/edición de turno.
Future<void> showTurnoForm(
  BuildContext context, {
  Turno? turno,
  DateTime? fechaInicial,
  String? trabajadorInicial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TurnoForm(
      turno: turno,
      fechaInicial: fechaInicial,
      trabajadorInicial: trabajadorInicial,
    ),
  );
}

class TurnoForm extends ConsumerStatefulWidget {
  const TurnoForm({
    super.key,
    this.turno,
    this.fechaInicial,
    this.trabajadorInicial,
  });

  final Turno? turno;
  final DateTime? fechaInicial;
  final String? trabajadorInicial;

  @override
  ConsumerState<TurnoForm> createState() => _TurnoFormState();
}

class _TurnoFormState extends ConsumerState<TurnoForm> {
  String? _clienteId;
  String? _trabajadorId;
  final Set<String> _servicioIds = {};
  late DateTime _fecha;
  TimeOfDay? _horaInicio;
  late final TextEditingController _notas;

  /// Filtro de búsqueda de servicios (por nombre o categoría).
  String _busquedaServicio = '';

  /// Cuando es `true` el catálogo muestra todos los servicios disponibles;
  /// si no, solo un preview corto (la búsqueda siempre muestra todo lo que matchea).
  bool _catalogoExpandido = false;

  /// Máximo de chips de catálogo visibles sin búsqueda antes de "Ver todos".
  static const _maxCatalogo = 10;

  @override
  void initState() {
    super.initState();
    final t = widget.turno;
    _clienteId = t?.clienteId;
    _trabajadorId = t?.trabajadorId ?? widget.trabajadorInicial;
    if (t != null) _servicioIds.addAll(t.servicios.map((s) => s.servicioId));
    _fecha = t != null
        ? parseFecha(t.fecha)
        : (widget.fechaInicial ?? DateTime.now());
    if (t != null) {
      final m = minutosDeHora(t.horaInicio);
      _horaInicio = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    }
    _notas = TextEditingController(text: t?.notas ?? '');
  }

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pickHora() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _horaInicio ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (t != null) setState(() => _horaInicio = t);
  }

  Future<void> _pickFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _fecha = d);
  }

  void _save() {
    final clientes = ref.read(clientesStreamProvider).value ?? const [];
    final trabajadores =
        ref.read(trabajadoresStreamProvider).value ?? const [];
    final servicios = ref.read(serviciosStreamProvider).value ?? const [];

    if (_clienteId == null) return _toast('Elegí un cliente');
    if (_trabajadorId == null) return _toast('Elegí un trabajador');
    if (_servicioIds.isEmpty) return _toast('Elegí al menos un servicio');
    if (_horaInicio == null) return _toast('Elegí la hora de inicio');

    final cliente = clientes.firstWhere((c) => c.id == _clienteId);
    final trabajador = trabajadores.firstWhere((t) => t.id == _trabajadorId);
    final servs =
        servicios.where((s) => _servicioIds.contains(s.id)).toList();
    final durTotal = servs.fold<int>(0, (a, s) => a + s.duracionMin);
    final iniMin = _horaInicio!.hour * 60 + _horaInicio!.minute;

    final t = widget.turno;
    final turno = Turno(
      id: t?.id ?? '',
      fecha: fmtFecha(_fecha),
      horaInicio: horaDeMinutos(iniMin),
      finEstimado: horaDeMinutos(iniMin + durTotal),
      finReal: t?.finReal,
      trabajadorId: trabajador.id,
      trabajadorNombre: trabajador.nombre,
      clienteId: cliente.id,
      clienteNombre: cliente.nombre,
      clienteTelefono: cliente.telefono,
      servicios: servs
          .map((s) => ServicioEnTurno(
                servicioId: s.id,
                nombre: s.nombre,
                duracionMin: s.duracionMin,
              ))
          .toList(),
      estado: t?.estado ?? EstadoTurno.pendiente,
      cobro: t?.cobro,
      fechaCobro: t?.fechaCobro,
      notas: _notas.text.trim().isEmpty ? null : _notas.text.trim(),
      creadoPor: t?.creadoPor ??
          (ref.read(usuarioActualProvider).value?.uid ?? 'desconocido'),
      createdAt: t?.createdAt,
    );

    final messenger = ScaffoldMessenger.of(context);
    ref.read(turnosRepositoryProvider).upsert(turno).catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      return turno.id;
    });
    Navigator.of(context).pop();
  }

  /// Selector de servicios centrado en la búsqueda: los seleccionados se ven
  /// como chips removibles arriba, y debajo un buscador por nombre + un catálogo
  /// plano de chips "tocar para agregar". Sin encabezados de categoría, para que
  /// la vista quede liviana incluso con muchos servicios.
  Widget _selectorServicios(List<Servicio> servicios) {
    final scheme = Theme.of(context).colorScheme;
    final q = _busquedaServicio.trim().toLowerCase();
    final buscando = q.isNotEmpty;

    // Disponibles: activos + los ya seleccionados (caso edición de inactivos).
    final disponibles = servicios
        .where((s) => s.activo || _servicioIds.contains(s.id))
        .toList();

    final seleccionados = disponibles
        .where((s) => _servicioIds.contains(s.id))
        .toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));

    // Catálogo = no seleccionados que matchean la búsqueda (los seleccionados
    // ya se ven arriba; no se repiten abajo).
    final coincidencias = disponibles
        .where((s) => !_servicioIds.contains(s.id))
        .where((s) =>
            !buscando ||
            s.nombre.toLowerCase().contains(q) ||
            (s.categoria ?? '').toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));

    // Sin búsqueda: preview corto. Con búsqueda: todo lo que matchea.
    final mostrarTodo = buscando || _catalogoExpandido;
    final catalogo =
        mostrarTodo ? coincidencias : coincidencias.take(_maxCatalogo).toList();
    final ocultos = coincidencias.length - catalogo.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Seleccionados (removibles con ✕).
        if (seleccionados.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in seleccionados) _chipSeleccionado(s)],
          ),
          const SizedBox(height: 12),
        ],

        // Buscador por nombre (siempre visible).
        TextField(
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar servicio por nombre',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: buscando
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _busquedaServicio = ''),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _busquedaServicio = v),
        ),
        const SizedBox(height: 12),

        // Catálogo "tocar para agregar".
        if (coincidencias.isEmpty)
          Text(
            buscando
                ? 'Sin resultados para "${_busquedaServicio.trim()}"'
                : 'Todos los servicios ya están agregados',
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in catalogo) _chipDisponible(s),
              if (ocultos > 0)
                ActionChip(
                  label: Text('Ver todos (+$ocultos)'),
                  onPressed: () =>
                      setState(() => _catalogoExpandido = true),
                )
              else if (_catalogoExpandido && !buscando)
                ActionChip(
                  label: const Text('Ver menos'),
                  onPressed: () =>
                      setState(() => _catalogoExpandido = false),
                ),
            ],
          ),
      ],
    );
  }

  /// Chip de un servicio ya elegido: tinte con su color y ✕ para quitarlo.
  Widget _chipSeleccionado(Servicio s) {
    final color = colorFromHex(s.color);
    return InputChip(
      avatar: CircleAvatar(radius: 5, backgroundColor: color),
      label: Text('${s.nombre} · ${s.duracionMin}m'),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
      onDeleted: () => setState(() => _servicioIds.remove(s.id)),
    );
  }

  /// Chip de un servicio del catálogo: tocar para agregarlo a la selección.
  Widget _chipDisponible(Servicio s) {
    final color = colorFromHex(s.color);
    return ActionChip(
      avatar: CircleAvatar(radius: 5, backgroundColor: color),
      label: Text('${s.nombre} · ${s.duracionMin}m'),
      onPressed: () => setState(() => _servicioIds.add(s.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientes = ref.watch(clientesStreamProvider).value;
    final trabajadores = ref.watch(trabajadoresStreamProvider).value;
    final servicios = ref.watch(serviciosStreamProvider).value;

    if (clientes == null || trabajadores == null || servicios == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isEdit = widget.turno != null;
    final selServicios =
        servicios.where((s) => _servicioIds.contains(s.id)).toList();
    final durTotal = selServicios.fold<int>(0, (a, s) => a + s.duracionMin);
    final finEstimado = _horaInicio == null
        ? null
        : horaDeMinutos(
            _horaInicio!.hour * 60 + _horaInicio!.minute + durTotal);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Editar turno' : 'Nuevo turno',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Cliente
            if (clientes.isEmpty)
              _SinDatos(
                texto: 'No hay clientes.',
                accion: 'Crear cliente',
                onTap: () => showClienteForm(context),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _clienteId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Cliente'),
                      items: [
                        for (final c in clientes)
                          DropdownMenuItem(value: c.id, child: Text(c.nombre)),
                      ],
                      onChanged: (v) => setState(() => _clienteId = v),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_add_alt),
                    tooltip: 'Nuevo cliente',
                    onPressed: () => showClienteForm(context),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            // Trabajador
            if (trabajadores.isEmpty)
              const _SinDatos(texto: 'No hay trabajadores cargados.')
            else
              DropdownButtonFormField<String>(
                initialValue: _trabajadorId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Trabajador'),
                items: [
                  for (final t in trabajadores)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text(t.activo ? t.nombre : '${t.nombre} (inactivo)'),
                    ),
                ],
                onChanged: (v) => setState(() => _trabajadorId = v),
              ),
            const SizedBox(height: 16),

            // Servicios
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Servicios',
                    style: Theme.of(context).textTheme.titleSmall),
                if (selServicios.isNotEmpty)
                  Text(
                    '${selServicios.length} · $durTotal min',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            if (servicios.isEmpty)
              const _SinDatos(texto: 'No hay servicios cargados.')
            else
              _selectorServicios(servicios),
            const SizedBox(height: 8),

            // Fecha + hora
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFecha,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(fmtFechaLegible(_fecha)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickHora,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_horaInicio == null
                        ? 'Hora'
                        : horaDeMinutos(
                            _horaInicio!.hour * 60 + _horaInicio!.minute)),
                  ),
                ),
              ],
            ),
            if (finEstimado != null) ...[
              const SizedBox(height: 8),
              Text(
                'Duración $durTotal min · fin estimado $finEstimado',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notas,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Guardar cambios' : 'Crear turno'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinDatos extends StatelessWidget {
  const _SinDatos({required this.texto, this.accion, this.onTap});

  final String texto;
  final String? accion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(texto,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          if (accion != null && onTap != null)
            TextButton(onPressed: onTap, child: Text(accion!)),
        ],
      ),
    );
  }
}
