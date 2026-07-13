import 'package:flutter/material.dart';

import '../features/tenant/domain/tenant.dart';
import 'tokens.dart';

/// Servicio para generar [ThemeData] dinámico a partir de [Branding] del tenant.
///
/// Convierte colores hex a [Color], crea [ColorScheme] seeded, y retorna
/// un [ThemeData] Material 3 completo respetando light/dark mode.
class ThemeService {
  ThemeService._();

  /// Construye un [ThemeData] Material 3 seeded a partir de la branding del tenant.
  ///
  /// Parámetros:
  /// - [branding]: Configuración de branding (colores hex, logo, tema forzado)
  /// - [isDarkMode]: true para tema oscuro, false para claro
  ///
  /// Lógica:
  /// 1. Parsea [colorPrimary] desde hex '#RRGGBB' a [Color]
  /// 2. Crea [ColorScheme.fromSeed] usando el color primario
  /// 3. Respeta el parámetro [isDarkMode] para brightness
  /// 4. Opcionalmente aplica [colorSecondary] y [colorAccent] via copyWith
  /// 5. Retorna [ThemeData] completo con Material 3
  ///
  /// Maneja nulos gracefully: si no hay hex válido, usa color por defecto.
  static ThemeData buildTenantTheme(Branding branding, bool isDarkMode) {
    final seedColor = _parseHexColor(branding.colorPrimary) ?? _defaultSeedColor;
    final brightness = isDarkMode ? Brightness.dark : Brightness.light;

    var colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    // Aplicar colores secundario y accent si están disponibles
    Color? secondaryColor = _parseHexColor(branding.colorSecondary);
    Color? accentColor = _parseHexColor(branding.colorAccent);

    if (secondaryColor != null || accentColor != null) {
      colorScheme = colorScheme.copyWith(
        secondary: secondaryColor ?? colorScheme.secondary,
        tertiary: accentColor ?? colorScheme.tertiary,
      );
    }

    return _buildThemeWithColorScheme(colorScheme);
  }

  /// Parsea un string hex (#RRGGBB) a [Color].
  ///
  /// Retorna null si el string es inválido.
  static Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;

    try {
      // Remover '#' si está presente
      final cleanHex = hex.startsWith('#') ? hex.substring(1) : hex;

      // Validar que sea hexadecimal válido (6 caracteres)
      if (cleanHex.length != 6) return null;

      // Parsear como int hexadecimal y convertir a Color (0xFF + RRGGBB)
      return Color(int.parse('0xFF$cleanHex'));
    } catch (e) {
      debugPrint('Error parsing hex color "$hex": $e');
      return null;
    }
  }

  /// Construye el [ThemeData] completo a partir de un [ColorScheme].
  ///
  /// Reutiliza la lógica de tema existente para mantener consistencia
  /// con el diseño "Soft UI Evolution".
  static ThemeData _buildThemeWithColorScheme(ColorScheme colorScheme) {
    final brightness = colorScheme.brightness;
    final baseTextTheme = ThemeData(brightness: brightness).textTheme;
    final textTheme = baseTextTheme.copyWith(
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        height: 1.4,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        shadowColor: colorScheme.shadow,
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(color: colorScheme.onSurface);
        }),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: Insets.md,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: Insets.lg,
      ),
    );
  }

  /// Color seed por defecto (violeta de marca original).
  static const Color _defaultSeedColor = Color(0xFF534AB7);
}
