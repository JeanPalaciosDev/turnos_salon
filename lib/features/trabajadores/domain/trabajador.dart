/// Rol del trabajador / usuario del sistema.
enum RolTrabajador { dueno, recepcion, estilista }

RolTrabajador rolFromDb(String? v) => switch (v) {
      'dueno' => RolTrabajador.dueno,
      'recepcion' => RolTrabajador.recepcion,
      _ => RolTrabajador.estilista,
    };

String rolToDb(RolTrabajador r) => r.name;

/// Etiqueta legible del rol para la UI.
String rolLabel(RolTrabajador r) => switch (r) {
      RolTrabajador.dueno => 'Dueño',
      RolTrabajador.recepcion => 'Recepción',
      RolTrabajador.estilista => 'Estilista',
    };

/// Una franja de horario laboral semanal del trabajador.
/// [diaSemana] 1 = lunes … 7 = domingo. Horas en formato 'HH:mm' (local).
class HorarioLaboral {
  const HorarioLaboral({
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
  });

  final int diaSemana;
  final String horaInicio;
  final String horaFin;

  factory HorarioLaboral.fromMap(Map<String, dynamic> m) => HorarioLaboral(
        diaSemana: (m['dia_semana'] as num).toInt(),
        horaInicio: m['hora_inicio'] as String,
        horaFin: m['hora_fin'] as String,
      );

  Map<String, dynamic> toMap() => {
        'dia_semana': diaSemana,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
      };
}

/// Trabajador del salón (estilista, recepción, dueño).
class Trabajador {
  const Trabajador({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.color,
    required this.activo,
    this.horario = const [],
  });

  final String id;
  final String nombre;
  final RolTrabajador rol;

  /// Color (hex, ej. '#534AB7') para identificar al trabajador en la agenda.
  final String color;
  final bool activo;
  final List<HorarioLaboral> horario;

  factory Trabajador.fromMap(String id, Map<String, dynamic> m) => Trabajador(
        id: id,
        nombre: m['nombre'] as String,
        rol: rolFromDb(m['rol'] as String?),
        color: m['color'] as String? ?? '#888780',
        activo: m['activo'] as bool? ?? true,
        horario: ((m['horario'] as List?) ?? const [])
            .map((e) => HorarioLaboral.fromMap(
                Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'rol': rolToDb(rol),
        'color': color,
        'activo': activo,
        'horario': horario.map((e) => e.toMap()).toList(),
      };

  Trabajador copyWith({
    String? nombre,
    RolTrabajador? rol,
    String? color,
    bool? activo,
    List<HorarioLaboral>? horario,
  }) =>
      Trabajador(
        id: id,
        nombre: nombre ?? this.nombre,
        rol: rol ?? this.rol,
        color: color ?? this.color,
        activo: activo ?? this.activo,
        horario: horario ?? this.horario,
      );
}
