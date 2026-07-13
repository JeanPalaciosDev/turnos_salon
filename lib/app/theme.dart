import 'package:flutter/material.dart';

import '../features/tenant/domain/tenant.dart';
import 'tokens.dart';

/// Branding por defecto cuando no hay tenant (login) o Firestore no disponible.
///
/// Usa el color seed original (violeta #534AB7) sin forzar tema.
const kDefaultBranding = Branding(
  colorPrimary: '#534AB7', // Material 3 violet
  colorSecondary: null,
  colorAccent: null,
  logoUrl: null,
  forceTheme: null, // Auto (system preference)
);

/// Seed de identidad (violeta de marca) - legacy.
const Color _seed = Color(0xFF534AB7);

/// Tema claro de la app - legacy (usado en fallback).
ThemeData buildLightTheme() => _buildTheme(Brightness.light);

/// Tema oscuro de la app - legacy (usado en fallback).
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

/// Construye un [ThemeData] Material 3 a partir del [Brightness].
///
/// Estilo "Soft UI Evolution": sombras suaves, radios cómodos, todo el
/// color deriva del [ColorScheme] sembrado (cero hex hardcodeados aquí).
ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  );

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
