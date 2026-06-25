/// Servicio ofrecido por el salón.
///
/// [precioReferencia] es solo una sugerencia editable: NO es el ingreso real.
/// El monto real se captura al cerrar el turno (depende de insumos, largo de
/// cabello, mano de obra, ofertas de combo).
class Servicio {
  const Servicio({
    required this.id,
    required this.nombre,
    required this.precioReferencia,
    required this.duracionMin,
    required this.activo,
    this.categoria,
    this.color,
  });

  final String id;
  final String nombre;
  final num precioReferencia;
  final int duracionMin;
  final bool activo;
  final String? categoria;
  final String? color;

  factory Servicio.fromMap(String id, Map<String, dynamic> m) => Servicio(
        id: id,
        nombre: m['nombre'] as String,
        precioReferencia: (m['precio_referencia'] as num?) ?? 0,
        duracionMin: ((m['duracion_min'] as num?) ?? 30).toInt(),
        activo: m['activo'] as bool? ?? true,
        categoria: m['categoria'] as String?,
        color: m['color'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'precio_referencia': precioReferencia,
        'duracion_min': duracionMin,
        'activo': activo,
        'categoria': categoria,
        'color': color,
      };

  Servicio copyWith({
    String? nombre,
    num? precioReferencia,
    int? duracionMin,
    bool? activo,
    String? categoria,
    String? color,
  }) =>
      Servicio(
        id: id,
        nombre: nombre ?? this.nombre,
        precioReferencia: precioReferencia ?? this.precioReferencia,
        duracionMin: duracionMin ?? this.duracionMin,
        activo: activo ?? this.activo,
        categoria: categoria ?? this.categoria,
        color: color ?? this.color,
      );
}
