import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/colores.dart';
import '../data/trabajadores_repository.dart';
import '../domain/ausencia.dart';
import '../domain/trabajador.dart';
import 'trabajador_form.dart';

const _diasCortos = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

String _fmtTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Detalle del trabajador: datos, horario laboral y ausencias.
class TrabajadorDetalleScreen extends ConsumerWidget {
  const TrabajadorDetalleScreen({super.key, required this.trabajadorId});

  final String trabajadorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trabajadoresAsync = ref.watch(trabajadoresStreamProvider);
    return trabajadoresAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (list) {
        final matches = list.where((t) => t.id == trabajadorId);
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Trabajador no encontrado')),
          );
        }
        return _Body(matches.first);
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.trabajador);

  final Trabajador trabajador;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = trabajador;
    final ausenciasAsync = ref.watch(ausenciasProvider(t.id));
    final horario = [...t.horario]..sort((a, b) {
        final d = a.diaSemana.compareTo(b.diaSemana);
        return d != 0 ? d : a.horaInicio.compareTo(b.horaInicio);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(t.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar datos',
            onPressed: () => showTrabajadorForm(context, trabajador: t),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            leading: CircleAvatar(backgroundColor: colorFromHex(t.color)),
            title: Text(rolLabel(t.rol)),
            subtitle: Text(t.activo ? 'Activo' : 'Inactivo'),
          ),
          const Divider(),
          _SectionHeader(
            title: 'Horario laboral',
            onAdd: () => _addFranja(context, ref),
          ),
          if (horario.isEmpty)
            const _EmptyHint('Sin franjas horarias. Agregá una con +.')
          else
            for (var i = 0; i < horario.length; i++)
              ListTile(
                dense: true,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(
                  '${_diasCortos[horario[i].diaSemana]}  '
                  '${horario[i].horaInicio} – ${horario[i].horaFin}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Quitar',
                  onPressed: () => _removeFranja(ref, horario, i),
                ),
              ),
          const Divider(),
          _SectionHeader(
            title: 'Ausencias',
            onAdd: () => _addAusencia(context, ref),
          ),
          ausenciasAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _EmptyHint('Error: $e'),
            data: (ausencias) {
              if (ausencias.isEmpty) {
                return const _EmptyHint('Sin ausencias registradas.');
              }
              return Column(
                children: [
                  for (final a in ausencias)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.event_busy_outlined),
                      title: Text('${a.fechaInicio} → ${a.fechaFin}'),
                      subtitle: a.motivo.isEmpty ? null : Text(a.motivo),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Quitar',
                        onPressed: () => ref
                            .read(trabajadoresRepositoryProvider)
                            .deleteAusencia(t.id, a.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar trabajador'),
        content: Text('¿Eliminar a "${trabajador.nombre}"?'),
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
      await ref.read(trabajadoresRepositoryProvider).delete(trabajador.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _addFranja(BuildContext context, WidgetRef ref) async {
    final franja = await showDialog<HorarioLaboral>(
      context: context,
      builder: (_) => const _FranjaDialog(),
    );
    if (franja == null) return;
    final nuevo = [...trabajador.horario, franja];
    ref
        .read(trabajadoresRepositoryProvider)
        .upsert(trabajador.copyWith(horario: nuevo))
        .catchError((Object _) => trabajador.id);
  }

  void _removeFranja(WidgetRef ref, List<HorarioLaboral> sorted, int index) {
    final franja = sorted[index];
    final nuevo = [...trabajador.horario];
    final pos = nuevo.indexWhere((f) =>
        f.diaSemana == franja.diaSemana &&
        f.horaInicio == franja.horaInicio &&
        f.horaFin == franja.horaFin);
    if (pos == -1) return;
    nuevo.removeAt(pos);
    ref
        .read(trabajadoresRepositoryProvider)
        .upsert(trabajador.copyWith(horario: nuevo))
        .catchError((Object _) => trabajador.id);
  }

  Future<void> _addAusencia(BuildContext context, WidgetRef ref) async {
    final ausencia = await showDialog<Ausencia>(
      context: context,
      builder: (_) => const _AusenciaDialog(),
    );
    if (ausencia == null) return;
    ref.read(trabajadoresRepositoryProvider).addAusencia(trabajador.id, ausencia);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar',
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Diálogo para agregar una franja de horario.
class _FranjaDialog extends StatefulWidget {
  const _FranjaDialog();

  @override
  State<_FranjaDialog> createState() => _FranjaDialogState();
}

class _FranjaDialogState extends State<_FranjaDialog> {
  int _dia = 1;
  TimeOfDay _inicio = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 18, minute: 0);

  Future<void> _pickInicio() async {
    final t = await showTimePicker(context: context, initialTime: _inicio);
    if (t != null) setState(() => _inicio = t);
  }

  Future<void> _pickFin() async {
    final t = await showTimePicker(context: context, initialTime: _fin);
    if (t != null) setState(() => _fin = t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar franja'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _dia,
            decoration: const InputDecoration(labelText: 'Día'),
            items: [
              for (var d = 1; d <= 7; d++)
                DropdownMenuItem(value: d, child: Text(_diasCortos[d])),
            ],
            onChanged: (v) => setState(() => _dia = v ?? _dia),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickInicio,
                  child: Text('Inicio  ${_fmtTime(_inicio)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickFin,
                  child: Text('Fin  ${_fmtTime(_fin)}'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            HorarioLaboral(
              diaSemana: _dia,
              horaInicio: _fmtTime(_inicio),
              horaFin: _fmtTime(_fin),
            ),
          ),
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

/// Diálogo para agregar una ausencia.
class _AusenciaDialog extends StatefulWidget {
  const _AusenciaDialog();

  @override
  State<_AusenciaDialog> createState() => _AusenciaDialogState();
}

class _AusenciaDialogState extends State<_AusenciaDialog> {
  DateTime _inicio = DateTime.now();
  DateTime _fin = DateTime.now();
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _pick(bool inicio) async {
    final base = inicio ? _inicio : _fin;
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (inicio) {
        _inicio = d;
        if (_fin.isBefore(_inicio)) _fin = d;
      } else {
        _fin = d;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar ausencia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(true),
                  child: Text('Desde  ${_fmtDate(_inicio)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(false),
                  child: Text('Hasta  ${_fmtDate(_fin)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _motivo,
            decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            Ausencia(
              id: '',
              fechaInicio: _fmtDate(_inicio),
              fechaFin: _fmtDate(_fin),
              motivo: _motivo.text.trim(),
            ),
          ),
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
