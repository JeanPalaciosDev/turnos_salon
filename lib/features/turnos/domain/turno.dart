import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado del turno. `pendiente` es el único estado vivo; `completado` (vía
/// cobro), `cancelado` y `noShow` son ramas terminales.
enum EstadoTurno { pendiente, completado, cancelado, noShow }

EstadoTurno estadoFromDb(String? v) => switch (v) {
      'pendiente' => EstadoTurno.pendiente,
      'completado' => EstadoTurno.completado,
      'cancelado' => EstadoTurno.cancelado,
      'no_show' => EstadoTurno.noShow,
      // Valores legacy ('confirmado', 'en_curso') o desconocidos → pendiente.
      _ => EstadoTurno.pendiente,
    };

String estadoToDb(EstadoTurno e) => switch (e) {
      EstadoTurno.pendiente => 'pendiente',
      EstadoTurno.completado => 'completado',
      EstadoTurno.cancelado => 'cancelado',
      EstadoTurno.noShow => 'no_show',
    };

/// Foto (snapshot) de un servicio dentro de un turno. Se denormaliza para
/// preservar nombre/duración aunque el servicio cambie después.
class ServicioEnTurno {
  const ServicioEnTurno({
    required this.servicioId,
    required this.nombre,
    required this.duracionMin,
  });

  final String servicioId;
  final String nombre;
  final int duracionMin;

  factory ServicioEnTurno.fromMap(Map<String, dynamic> m) => ServicioEnTurno(
        servicioId: m['servicio_id'] as String,
        nombre: m['nombre'] as String,
        duracionMin: ((m['duracion_min'] as num?) ?? 0).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'servicio_id': servicioId,
        'nombre': nombre,
        'duracion_min': duracionMin,
      };
}

/// Una línea del cobro: monto real cobrado por un servicio del turno.
class LineaCobro {
  const LineaCobro({
    required this.servicioId,
    required this.nombre,
    required this.monto,
  });

  final String servicioId;
  final String nombre;
  final num monto;

  factory LineaCobro.fromMap(Map<String, dynamic> m) => LineaCobro(
        servicioId: m['servicio_id'] as String,
        nombre: m['nombre'] as String,
        monto: (m['monto'] as num?) ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'servicio_id': servicioId,
        'nombre': nombre,
        'monto': monto,
      };
}

/// Cobro capturado al cerrar el turno. `total` = suma de líneas − descuento.
class Cobro {
  const Cobro({
    required this.lineas,
    required this.total,
    this.descuento = 0,
    this.metodoPago,
    this.notas,
  });

  final List<LineaCobro> lineas;
  final num total;
  final num descuento;
  final String? metodoPago;
  final String? notas;

  factory Cobro.fromMap(Map<String, dynamic> m) => Cobro(
        lineas: ((m['lineas'] as List?) ?? const [])
            .map((e) => LineaCobro.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total: (m['total'] as num?) ?? 0,
        descuento: (m['descuento'] as num?) ?? 0,
        metodoPago: m['metodo_pago'] as String?,
        notas: m['notas'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'lineas': lineas.map((e) => e.toMap()).toList(),
        'total': total,
        'descuento': descuento,
        'metodo_pago': metodoPago,
        'notas': notas,
      };
}

/// Turno de un cliente. Anclado en [horaInicio]; [finEstimado] (derivado de la
/// duración de los servicios) sirve solo para detectar solapamientos visuales,
/// nunca bloquea. Fechas 'yyyy-MM-dd' y horas 'HH:mm' en hora local del salón.
class Turno {
  const Turno({
    required this.id,
    required this.fecha,
    required this.horaInicio,
    required this.finEstimado,
    required this.trabajadorId,
    required this.trabajadorNombre,
    required this.clienteId,
    required this.clienteNombre,
    required this.servicios,
    required this.estado,
    required this.creadoPor,
    this.finReal,
    this.clienteTelefono,
    this.cobro,
    this.fechaCobro,
    this.notas,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fecha;
  final String horaInicio;
  final String finEstimado;
  final String? finReal;
  final String trabajadorId;
  final String trabajadorNombre;
  final String clienteId;
  final String clienteNombre;
  final String? clienteTelefono;
  final List<ServicioEnTurno> servicios;
  final EstadoTurno estado;
  final Cobro? cobro;
  final DateTime? fechaCobro;
  final String? notas;
  final String creadoPor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Turno.fromMap(String id, Map<String, dynamic> m) => Turno(
        id: id,
        fecha: m['fecha'] as String,
        horaInicio: m['hora_inicio'] as String,
        finEstimado: m['fin_estimado'] as String? ?? m['hora_inicio'] as String,
        finReal: m['fin_real'] as String?,
        trabajadorId: m['trabajador_id'] as String,
        trabajadorNombre: m['trabajador_nombre'] as String? ?? '',
        clienteId: m['cliente_id'] as String,
        clienteNombre: m['cliente_nombre'] as String? ?? '',
        clienteTelefono: m['cliente_telefono'] as String?,
        servicios: ((m['servicios'] as List?) ?? const [])
            .map((e) =>
                ServicioEnTurno.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        estado: estadoFromDb(m['estado'] as String?),
        cobro: m['cobro'] == null
            ? null
            : Cobro.fromMap(Map<String, dynamic>.from(m['cobro'] as Map)),
        fechaCobro: (m['fecha_cobro'] as Timestamp?)?.toDate(),
        notas: m['notas'] as String?,
        creadoPor: m['creado_por'] as String? ?? '',
        createdAt: (m['created_at'] as Timestamp?)?.toDate(),
        updatedAt: (m['updated_at'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'fecha': fecha,
        'hora_inicio': horaInicio,
        'fin_estimado': finEstimado,
        'fin_real': finReal,
        'trabajador_id': trabajadorId,
        'trabajador_nombre': trabajadorNombre,
        'cliente_id': clienteId,
        'cliente_nombre': clienteNombre,
        'cliente_telefono': clienteTelefono,
        'servicios': servicios.map((e) => e.toMap()).toList(),
        'estado': estadoToDb(estado),
        'cobro': cobro?.toMap(),
        'fecha_cobro':
            fechaCobro == null ? null : Timestamp.fromDate(fechaCobro!),
        'notas': notas,
        'creado_por': creadoPor,
        'created_at': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'updated_at': FieldValue.serverTimestamp(),
      };

  Turno copyWith({
    String? fecha,
    String? horaInicio,
    String? finEstimado,
    String? finReal,
    String? trabajadorId,
    String? trabajadorNombre,
    String? clienteId,
    String? clienteNombre,
    String? clienteTelefono,
    List<ServicioEnTurno>? servicios,
    EstadoTurno? estado,
    Cobro? cobro,
    DateTime? fechaCobro,
    String? notas,
  }) =>
      Turno(
        id: id,
        fecha: fecha ?? this.fecha,
        horaInicio: horaInicio ?? this.horaInicio,
        finEstimado: finEstimado ?? this.finEstimado,
        finReal: finReal ?? this.finReal,
        trabajadorId: trabajadorId ?? this.trabajadorId,
        trabajadorNombre: trabajadorNombre ?? this.trabajadorNombre,
        clienteId: clienteId ?? this.clienteId,
        clienteNombre: clienteNombre ?? this.clienteNombre,
        clienteTelefono: clienteTelefono ?? this.clienteTelefono,
        servicios: servicios ?? this.servicios,
        estado: estado ?? this.estado,
        cobro: cobro ?? this.cobro,
        fechaCobro: fechaCobro ?? this.fechaCobro,
        notas: notas ?? this.notas,
        creadoPor: creadoPor,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
