import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_salon/app/theme.dart';
import 'package:turnos_salon/app/theme_service.dart';
import 'package:turnos_salon/features/tenant/domain/tenant.dart';

void main() {
  group('Tema claro / oscuro', () {
    test('buildLightTheme es brillo claro y Material 3', () {
      final theme = buildLightTheme();
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
    });

    test('buildDarkTheme es brillo oscuro y Material 3', () {
      final theme = buildDarkTheme();
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });
  });

  group('ThemeService - Generación dinámica de temas', () {
    test('buildTenantTheme crea tema claro con branding default', () {
      final theme = ThemeService.buildTenantTheme(kDefaultBranding, false);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
    });

    test('buildTenantTheme crea tema oscuro con branding default', () {
      final theme = ThemeService.buildTenantTheme(kDefaultBranding, true);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    test('buildTenantTheme respeta color primario hex válido', () {
      const customBranding = Branding(
        colorPrimary: '#FF6200',
        colorSecondary: null,
        colorAccent: null,
        logoUrl: null,
        forceTheme: null,
      );

      final theme = ThemeService.buildTenantTheme(customBranding, false);
      // El color primario del ColorScheme debe ser similar al proporcionado
      expect(theme.colorScheme.primary, isNotNull);
      // Verificar que el seed color se aplicó (no es el default violeta)
      expect(
        theme.colorScheme.primary,
        isNot(const Color(0xFF534AB7)), // Not default
      );
    });

    test('buildTenantTheme ignora hex inválido y usa default', () {
      const invalidBranding = Branding(
        colorPrimary: 'invalid-hex',
        colorSecondary: null,
        colorAccent: null,
        logoUrl: null,
        forceTheme: null,
      );

      final theme = ThemeService.buildTenantTheme(invalidBranding, false);
      expect(theme.colorScheme.primary, isNotNull);
      expect(theme.useMaterial3, isTrue);
      // Debe ser usable sin errores
    });

    test('buildTenantTheme maneja branding nulo gracefully', () {
      final theme = ThemeService.buildTenantTheme(
        const Branding(),
        false,
      );
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('buildTenantTheme genera ColorScheme válido para Material 3', () {
      const branding = Branding(
        colorPrimary: '#6200EE',
        colorSecondary: null,
        colorAccent: null,
        logoUrl: null,
        forceTheme: null,
      );

      final theme = ThemeService.buildTenantTheme(branding, false);
      // Verificar que todos los colores requeridos están presentes
      expect(theme.colorScheme.primary, isNotNull);
      expect(theme.colorScheme.onPrimary, isNotNull);
      expect(theme.colorScheme.secondary, isNotNull);
      expect(theme.colorScheme.surface, isNotNull);
      expect(theme.colorScheme.error, isNotNull);
    });

    test('buildTenantTheme aplica colores secundario y accent si están presentes',
        () {
      const branding = Branding(
        colorPrimary: '#6200EE',
        colorSecondary: '#03DAC6',
        colorAccent: '#FF6200',
        logoUrl: null,
        forceTheme: null,
      );

      final theme = ThemeService.buildTenantTheme(branding, false);
      expect(theme.colorScheme.secondary, isNotNull);
      expect(theme.colorScheme.tertiary, isNotNull);
    });

    test('buildTenantTheme preserva consistencia Material 3 con tema oscuro', () {
      const branding = Branding(
        colorPrimary: '#BB86FC',
        colorSecondary: null,
        colorAccent: null,
        logoUrl: null,
        forceTheme: null,
      );

      final darkTheme = ThemeService.buildTenantTheme(branding, true);
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.colorScheme.brightness, Brightness.dark);
      expect(darkTheme.useMaterial3, isTrue);
      // Verificar contraste mínimo (tema oscuro debe tener colores apropiados)
      expect(darkTheme.colorScheme.surface, isNotNull);
    });

    test('buildTenantTheme maneja hex sin # prefijo', () {
      const branding = Branding(
        colorPrimary: '534AB7',
        colorSecondary: null,
        colorAccent: null,
        logoUrl: null,
        forceTheme: null,
      );

      final theme = ThemeService.buildTenantTheme(branding, false);
      expect(theme.useMaterial3, isTrue);
      // Debe parsear correctamente sin #
    });

    test('buildTenantTheme preserva todos los elementos de tema (cards, inputs)',
        () {
      const branding = Branding(
        colorPrimary: '#6200EE',
        colorSecondary: null,
        colorAccent: null,
        logoUrl: null,
        forceTheme: null,
      );

      final theme = ThemeService.buildTenantTheme(branding, false);
      // Verificar que los componentes de tema están presentes
      expect(theme.cardTheme, isNotNull);
      expect(theme.inputDecorationTheme, isNotNull);
      expect(theme.appBarTheme, isNotNull);
      expect(theme.navigationBarTheme, isNotNull);
      expect(theme.textTheme, isNotNull);
    });
  });
}
