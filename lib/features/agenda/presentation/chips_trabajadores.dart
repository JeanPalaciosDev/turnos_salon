import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trabajadores/domain/trabajador.dart';
import '../application/agenda_providers.dart';

/// Fila de chips para filtrar la agenda por trabajador (`null` = todos).
/// Compartida por las vistas semanal y diaria.
class ChipsTrabajadores extends ConsumerWidget {
  const ChipsTrabajadores({
    super.key,
    required this.trabajadores,
    required this.filtro,
  });

  final List<Trabajador> trabajadores;
  final String? filtro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void set(String? id) =>
        ref.read(trabajadorFiltroProvider.notifier).set(id);

    final activos = trabajadores.where((t) => t.activo).toList();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: filtro == null,
              onSelected: (_) => set(null),
            ),
          ),
          for (final t in activos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(t.nombre),
                selected: filtro == t.id,
                onSelected: (_) => set(t.id),
              ),
            ),
        ],
      ),
    );
  }
}
