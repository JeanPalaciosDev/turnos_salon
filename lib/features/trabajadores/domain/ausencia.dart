/// Ausencia / bloqueo de un trabajador (vacaciones, descanso, etc.).
/// Fechas en formato 'yyyy-MM-dd' (local). Subcolección de `trabajadores`.
class Ausencia {
  const Ausencia({
    required this.id,
    required this.fechaInicio,
    required this.fechaFin,
    required this.motivo,
  });

  final String id;
  final String fechaInicio;
  final String fechaFin;
  final String motivo;

  factory Ausencia.fromMap(String id, Map<String, dynamic> m) => Ausencia(
        id: id,
        fechaInicio: m['fecha_inicio'] as String,
        fechaFin: m['fecha_fin'] as String,
        motivo: m['motivo'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
        'motivo': motivo,
      };
}
