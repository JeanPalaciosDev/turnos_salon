/// Configuración del salón (documento único `config/salon`).
/// [diasLaborables] usa 1 = lunes … 7 = domingo. Horas en 'HH:mm' local.
class SalonConfig {
  const SalonConfig({
    required this.nombre,
    required this.diasLaborables,
    required this.horaApertura,
    required this.horaCierre,
    required this.zonaHoraria,
  });

  final String nombre;
  final List<int> diasLaborables;
  final String horaApertura;
  final String horaCierre;
  final String zonaHoraria;

  factory SalonConfig.fromMap(Map<String, dynamic> m) => SalonConfig(
        nombre: m['nombre'] as String? ?? 'Mi salón',
        diasLaborables: ((m['dias_laborables'] as List?) ?? const [1, 2, 3, 4, 5, 6])
            .map((e) => (e as num).toInt())
            .toList(),
        horaApertura: m['hora_apertura'] as String? ?? '09:00',
        horaCierre: m['hora_cierre'] as String? ?? '20:00',
        zonaHoraria: m['zona_horaria'] as String? ?? 'America/Argentina/Buenos_Aires',
      );

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'dias_laborables': diasLaborables,
        'hora_apertura': horaApertura,
        'hora_cierre': horaCierre,
        'zona_horaria': zonaHoraria,
      };
}
