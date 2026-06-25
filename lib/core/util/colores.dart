import 'package:flutter/material.dart';

/// Paleta de colores para identificar trabajadores en la agenda.
const trabajadorColores = <String>[
  '#534AB7',
  '#1D9E75',
  '#D85A30',
  '#D4537E',
  '#378ADD',
  '#BA7517',
  '#639922',
  '#888780',
];

/// Convierte un hex '#RRGGBB' (o 'RRGGBB') a [Color]. Cae a gris si es inválido.
Color colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFF888780);
  final h = hex.replaceAll('#', '').trim();
  final value = int.tryParse('FF$h', radix: 16);
  return value == null ? const Color(0xFF888780) : Color(value);
}
