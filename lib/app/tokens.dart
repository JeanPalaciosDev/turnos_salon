/// Tokens de diseño: espaciados y radios consistentes.
///
/// Se introducen para ir reemplazando números mágicos de forma gradual
/// (Fase 4). En Fase 1 solo se crean.
library;

/// Espaciados estándar (en lógica de 4px).
class Insets {
  const Insets._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Radios de borde estándar.
class Radii {
  const Radii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}
