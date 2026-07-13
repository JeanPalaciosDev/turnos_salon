import 'package:flutter/material.dart';

import '../domain/turno.dart';

/// Color del punto de estado del turno (consistente con el mockup).
Color estadoColor(EstadoTurno e) => switch (e) {
      EstadoTurno.pendiente => const Color(0xFFBA7517),
      EstadoTurno.completado => const Color(0xFF888780),
      EstadoTurno.cancelado => const Color(0xFFA32D2D),
      EstadoTurno.noShow => const Color(0xFFA32D2D),
    };

/// Etiqueta legible del estado.
String estadoLabel(EstadoTurno e) => switch (e) {
      EstadoTurno.pendiente => 'Pendiente',
      EstadoTurno.completado => 'Completado',
      EstadoTurno.cancelado => 'Cancelado',
      EstadoTurno.noShow => 'No vino',
    };
