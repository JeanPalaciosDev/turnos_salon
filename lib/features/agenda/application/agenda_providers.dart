import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Día actualmente mostrado en la agenda.
class FechaSeleccionada extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void hoy() => state = DateTime.now();
  void mover(int dias) => state = state.add(Duration(days: dias));
  void moverSemana(int s) => state = state.add(Duration(days: 7 * s));
  void set(DateTime fecha) => state = fecha;
}

final fechaSeleccionadaProvider =
    NotifierProvider<FechaSeleccionada, DateTime>(FechaSeleccionada.new);

/// Filtro de trabajador en la agenda (`null` = todos).
class TrabajadorFiltro extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final trabajadorFiltroProvider =
    NotifierProvider<TrabajadorFiltro, String?>(TrabajadorFiltro.new);

/// Modo de visualización de la agenda diaria cuando no hay filtro de trabajador.
enum VistaDia { porHorario, porTrabajador }

/// Modo de vista de la agenda diaria (`porHorario` = default cronológico).
class VistaDiaModo extends Notifier<VistaDia> {
  @override
  VistaDia build() => VistaDia.porHorario;

  void set(VistaDia v) => state = v;
  void toggle() => state = state == VistaDia.porHorario
      ? VistaDia.porTrabajador
      : VistaDia.porHorario;
}

final vistaDiaProvider =
    NotifierProvider<VistaDiaModo, VistaDia>(VistaDiaModo.new);
