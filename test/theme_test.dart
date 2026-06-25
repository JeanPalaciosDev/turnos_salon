import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_salon/app/theme.dart';

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
}
