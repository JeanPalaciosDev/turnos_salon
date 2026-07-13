import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/tenant/application/tenant_providers.dart';
import 'router.dart';
import 'theme.dart';
import 'theme_service.dart';

/// Raíz de la app de gestión de turnos.
///
/// Observa el tenant actual y aplica su branding dinámicamente:
/// - ColorScheme seeded con el color primario del tenant
/// - Modo de tema forzado (light/dark) si está configurado
/// - Fallback a branding por defecto si Firestore no disponible
class TurnosApp extends ConsumerWidget {
  const TurnosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Observar el tenant actual y su branding
    final tenantAsync = ref.watch(currentTenantProvider);

    // Extraer branding del tenant, fallback a default si no disponible
    final branding = tenantAsync.value?.branding ?? kDefaultBranding;
    final forceTheme = tenantAsync.value?.branding.forceTheme;

    // Determinar ThemeMode basado en forceTheme
    final themeMode = switch (forceTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system, // Auto (system preference)
    };

    // Construir temas claro y oscuro con los colores del tenant
    final lightTheme = ThemeService.buildTenantTheme(branding, false);
    final darkTheme = ThemeService.buildTenantTheme(branding, true);

    return MaterialApp.router(
      title: 'Turnos Salón',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
