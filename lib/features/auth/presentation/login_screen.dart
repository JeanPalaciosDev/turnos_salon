import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tokens.dart';
import '../../tenant/application/tenant_providers.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';

/// Pantalla de inicio de sesión (Fase 2B).
///
/// Email + contraseña + botón "Entrar". Sin registro/auto-signup.
/// Llama [AuthRepository.signIn]; muestra spinner mientras autentica y el
/// mensaje de error de la excepción si falla. El guard del router redirige
/// a /agenda al loguear correctamente.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      // Phase 5: AuthRepository.signIn() ya verifica que el tenant es válido y está activo.
      await ref.read(authRepositoryProvider).signIn(
            _emailCtrl.text,
            _passwordCtrl.text,
          );

      // Post-login: mostrar loading mientras se carga la config del tenant desde Firestore.
      // El router redirige a /agenda cuando currentTenantProvider está disponible,
      // pero aquí queremos dar feedback visual (spinner + "Cargando configuración...").
      if (!mounted) return;
      setState(() {
        _cargando = true;
        _error = null;
      });

      // Esperar a que currentTenantProvider tenga data.
      // Esto permite que el LoginScreen muestre un loading específico mientras
      // se carga la branding y config del tenant.
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // El redirect del router lleva a /agenda cuando el tenant está cargado.
      // No navegamos manualmente; confiamos en el Go Router refresh.
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _mensaje(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _mensaje(Object e) {
    final texto = e.toString();
    // Las excepciones de AuthRepository son Exception('mensaje en español').
    return texto.startsWith('Exception: ')
        ? texto.substring('Exception: '.length)
        : texto;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Observar tenant actual: puede estar disponible si usuario viene de deeplink
    // después de autenticación, pero en login inicial será null.
    final tenantAsync = ref.watch(currentTenantProvider);
    final tenant = tenantAsync.value;
    final tenantId = ref.watch(tenantIdProvider).value;
    final salonName = tenant?.name ?? 'Turnos Salón';
    final logoUrl = tenant?.branding.logoUrl;
    final primaryColor = tenant?.branding.colorPrimary;

    // Si el usuario está cargando (después de login exitoso) y el tenant aún está
    // resolviendo, mostrar una pantalla de loading.
    if (_cargando && tenantAsync.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
              const SizedBox(height: Insets.lg),
              Text(
                'Cargando configuración de tu salón...',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Calcular el color del botón a partir de branding si existe
    Color? buttonColor;
    if (primaryColor != null) {
      try {
        final cleanHex = primaryColor.startsWith('#')
            ? primaryColor.substring(1)
            : primaryColor;
        if (cleanHex.length == 6) {
          buttonColor = Color(int.parse('0xFF$cleanHex'));
        }
      } catch (e) {
        // Ignorar errores de parseo
      }
    }

    return Scaffold(
      body: DecoratedBox(
        // Gradiente sutil derivado del colorScheme: respeta claro/oscuro
        // automáticamente y mantiene contraste con los campos sobre surface.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.surface,
              Color.alphaBlend(
                cs.primaryContainer.withValues(alpha: 0.30),
                cs.surface,
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Insets.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Encabezado de marca: logo del tenant si disponible,
                      // sino icono por defecto dentro de un contenedor redondeado.
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(Insets.xl),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius:
                                BorderRadius.circular(Radii.lg),
                          ),
                          child: logoUrl != null
                              ? Image.network(
                                  logoUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.content_cut,
                                    size: 48,
                                    color: cs.onPrimaryContainer,
                                  ),
                                )
                              : Icon(
                                  Icons.content_cut,
                                  size: 48,
                                  color: cs.onPrimaryContainer,
                                ),
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      Text(
                        salonName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        'Gestión de turnos del salón',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      // Debug: mostrar tenant_id en modo desarrollo
                      if (tenantId != null && !const bool.fromEnvironment('dart.vm.product'))
                        Padding(
                          padding: const EdgeInsets.only(top: Insets.sm),
                          child: Text(
                            'Tenant: $tenantId',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      const SizedBox(height: Insets.xl + Insets.sm),
                      TextFormField(
                        controller: _emailCtrl,
                        enabled: !_cargando,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Correo',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa tu correo'
                            : null,
                      ),
                      const SizedBox(height: Insets.lg),
                      TextFormField(
                        controller: _passwordCtrl,
                        enabled: !_cargando,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _cargando ? null : _entrar(),
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Ingresa tu contraseña'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Insets.lg),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.error),
                        ),
                      ],
                      const SizedBox(height: Insets.xl),
                      FilledButton(
                        onPressed: _cargando ? null : _entrar,
                        style: buttonColor != null
                            ? FilledButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: Colors.white,
                              )
                            : null,
                        child: _cargando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Entrar'),
                      ),
                      const SizedBox(height: Insets.lg),
                      Center(
                        child: TextButton(
                          onPressed: _cargando ? null : () => context.go('/crear-salon'),
                          child: const Text('¿Crear nuevo salón?'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
