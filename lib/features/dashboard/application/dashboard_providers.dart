import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/util/horas.dart';
import '../../turnos/data/turnos_repository.dart';
import '../../turnos/domain/turno.dart';
import '../domain/dashboard_metrics.dart';

DateTimeRange _mesActual() {
  final ahora = DateTime.now();
  return DateTimeRange(
    start: DateTime(ahora.year, ahora.month, 1),
    end: DateTime(ahora.year, ahora.month + 1, 0),
  );
}

/// Rango de fechas actualmente filtrado en el dashboard (default: mes actual).
class RangoDashboard extends Notifier<DateTimeRange> {
  @override
  DateTimeRange build() => _mesActual();

  void set(DateTimeRange rango) => state = rango;

  void esteMes() => state = _mesActual();

  void mesAnterior() {
    final ahora = DateTime.now();
    final mesAnteriorInicio = DateTime(ahora.year, ahora.month - 1, 1);
    state = DateTimeRange(
      start: mesAnteriorInicio,
      end: DateTime(mesAnteriorInicio.year, mesAnteriorInicio.month + 1, 0),
    );
  }

  void estaSemana() {
    final lunes = lunesDeSemana(DateTime.now());
    state = DateTimeRange(start: lunes, end: lunes.add(const Duration(days: 6)));
  }
}

final rangoDashboardProvider =
    NotifierProvider<RangoDashboard, DateTimeRange>(RangoDashboard.new);

/// Filtro de trabajador del dashboard (`null` = todos). Independiente del
/// filtro de la agenda (`trabajadorFiltroProvider`) para no pisar el que el
/// usuario dejó puesto ahí.
class DashboardTrabajadorFiltro extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final dashboardTrabajadorFiltroProvider =
    NotifierProvider<DashboardTrabajadorFiltro, String?>(
        DashboardTrabajadorFiltro.new);

/// Turnos del rango filtrado, ya filtrados por trabajador en cliente.
final dashboardTurnosProvider = StreamProvider<List<Turno>>((ref) {
  final rango = ref.watch(rangoDashboardProvider);
  final desde = fmtFecha(rango.start);
  final hasta = fmtFecha(rango.end);
  final stream =
      ref.watch(turnosRepositoryProvider).watchByRango(desde, hasta);
  final trabajadorId = ref.watch(dashboardTrabajadorFiltroProvider);
  if (trabajadorId == null) return stream;
  return stream.map(
      (turnos) => turnos.where((t) => t.trabajadorId == trabajadorId).toList());
});

/// Métricas agregadas del rango/filtro actuales.
final dashboardMetricsProvider = Provider<DashboardMetrics>((ref) {
  final turnos = ref.watch(dashboardTurnosProvider).value ?? [];
  return DashboardMetrics.desde(turnos);
});
