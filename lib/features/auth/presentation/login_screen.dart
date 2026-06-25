import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tokens.dart';
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
      await ref.read(authRepositoryProvider).signIn(
            _emailCtrl.text,
            _passwordCtrl.text,
          );
      // El redirect del router lleva a /agenda; no navegamos manualmente.
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
                      // Encabezado de marca: icono dentro de un contenedor
                      // redondeado con primaryContainer/onPrimaryContainer.
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(Insets.xl),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius:
                                BorderRadius.circular(Radii.lg),
                          ),
                          child: Icon(
                            Icons.content_cut,
                            size: 48,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      Text(
                        'Turnos Salón',
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
                        child: _cargando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Entrar'),
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
