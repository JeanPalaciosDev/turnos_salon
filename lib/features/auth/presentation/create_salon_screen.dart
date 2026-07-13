import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tokens.dart';
import '../../tenant/application/tenant_providers.dart';
import '../data/auth_repository.dart';

/// Pantalla de creación de nuevo salón (tenant).
///
/// Formulario para el primer admin de un nuevo salón:
/// - Nombre del salón
/// - Email del admin
/// - Contraseña (con confirmación)
/// - Color principal (selector de color)
/// - Preferencia de tema (auto, claro, oscuro)
///
/// Flow on submit:
/// 1. Valida campos
/// 2. Llama TenantCreationService.crearTenant()
/// 3. Si éxito: auto-login con AuthRepository.signIn()
/// 4. Router redirige a /agenda (Custom Claims ya están listos)
/// 5. Si error: muestra SnackBar y permite reintentar
class CreateSalonScreen extends ConsumerStatefulWidget {
  const CreateSalonScreen({super.key});

  @override
  ConsumerState<CreateSalonScreen> createState() => _CreateSalonScreenState();
}

class _CreateSalonScreenState extends ConsumerState<CreateSalonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salonNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _colorCtrl = TextEditingController(text: '#534AB7');

  String _themePreference = 'auto'; // 'auto', 'light', 'dark'
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _salonNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _crearSalon() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      // 1. Crear tenant vía Cloud Function
      final tenantCreationService = ref.read(tenantCreationServiceProvider);
      final tenantId = await tenantCreationService.crearTenant(
        salonName: _salonNameCtrl.text.trim(),
        adminEmail: _emailCtrl.text.trim(),
        adminPassword: _passwordCtrl.text,
        primaryColor: _colorCtrl.text.trim(),
        forceTheme: _themePreference == 'auto' ? null : _themePreference,
      );

      if (!mounted) return;

      // 2. Mostrar spinner de login automático
      setState(() => _error = null);
      _showSnackBar('Salón creado. Iniciando sesión...', isError: false);

      // 3. Auto-login
      await ref.read(authRepositoryProvider).signIn(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );

      // El redirect del router lleva a /agenda automáticamente
      // Los Custom Claims ya están listos (tenant_id, role='super_admin')
    } catch (e) {
      if (!mounted) return;
      final mensaje = _parseError(e);
      setState(() => _error = mensaje);
      _showSnackBar(mensaje, isError: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 5 : 2),
      ),
    );
  }

  String _parseError(Object e) {
    final texto = e.toString();
    if (texto.startsWith('Exception: ')) {
      return texto.substring('Exception: '.length);
    }
    return texto;
  }

  // Abre un diálogo simple para elegir color (hex input o selector).
  // Por ahora, usamos un TextField con validación hex.
  void _pickColor() {
    final ctrl = TextEditingController(text: _colorCtrl.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Vista previa del color
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _parseColor(ctrl.text),
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: Insets.lg),
            // Input de código hexadecimal
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Código hexadecimal',
                hintText: '#FFFFFF',
                prefixIcon: Icon(Icons.palette_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (_isValidHexColor(ctrl.text)) {
                setState(() => _colorCtrl.text = ctrl.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final cleanHex = hex.replaceFirst('#', '');
      if (cleanHex.length == 6) {
        return Color(int.parse('FF$cleanHex', radix: 16));
      }
    } catch (_) {}
    return Colors.purple;
  }

  bool _isValidHexColor(String hex) {
    final regex = RegExp(r'^#[0-9A-Fa-f]{6}$');
    return regex.hasMatch(hex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
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
                      // Encabezado
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(Insets.xl),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(Radii.lg),
                          ),
                          child: Icon(
                            Icons.store_outlined,
                            size: 48,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      Text(
                        'Crear nuevo salón',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        'Configura tu salón y cuenta admin',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Insets.xl + Insets.sm),

                      // Nombre del salón
                      TextFormField(
                        controller: _salonNameCtrl,
                        enabled: !_cargando,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del salón',
                          prefixIcon: Icon(Icons.store_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa el nombre del salón';
                          }
                          if (v.trim().length < 2) {
                            return 'El nombre debe tener al menos 2 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: Insets.lg),

                      // Email admin
                      TextFormField(
                        controller: _emailCtrl,
                        enabled: !_cargando,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Correo del admin',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa tu correo';
                          }
                          if (!_isValidEmail(v)) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: Insets.lg),

                      // Contraseña
                      TextFormField(
                        controller: _passwordCtrl,
                        enabled: !_cargando,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Ingresa una contraseña';
                          }
                          if (v.length < 6) {
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: Insets.lg),

                      // Confirmar contraseña
                      TextFormField(
                        controller: _confirmPasswordCtrl,
                        enabled: !_cargando,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Confirma tu contraseña';
                          }
                          if (v != _passwordCtrl.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: Insets.lg),

                      // Color principal
                      TextFormField(
                        controller: _colorCtrl,
                        enabled: !_cargando,
                        decoration: InputDecoration(
                          labelText: 'Color principal',
                          prefixIcon: Icon(Icons.palette_outlined),
                          suffixIcon: GestureDetector(
                            onTap: _cargando ? null : _pickColor,
                            child: Container(
                              margin: const EdgeInsets.all(Insets.sm),
                              decoration: BoxDecoration(
                                color: _parseColor(_colorCtrl.text),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        readOnly: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Selecciona un color';
                          }
                          if (!_isValidHexColor(v)) {
                            return 'Código hexadecimal inválido (ej: #FFFFFF)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: Insets.lg),

                      // Preferencia de tema
                      DropdownButtonFormField<String>(
                        value: _themePreference,
                        enabled: !_cargando,
                        decoration: const InputDecoration(
                          labelText: 'Preferencia de tema',
                          prefixIcon: Icon(Icons.brightness_4_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'auto',
                            child: Text('Automático'),
                          ),
                          DropdownMenuItem(
                            value: 'light',
                            child: Text('Claro'),
                          ),
                          DropdownMenuItem(
                            value: 'dark',
                            child: Text('Oscuro'),
                          ),
                        ],
                        onChanged: _cargando
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _themePreference = val);
                                }
                              },
                      ),
                      const SizedBox(height: Insets.xl),

                      // Botón crear
                      FilledButton(
                        onPressed: _cargando ? null : _crearSalon,
                        child: _cargando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Crear salón'),
                      ),
                      const SizedBox(height: Insets.lg),

                      // Link a login
                      Center(
                        child: TextButton(
                          onPressed: _cargando ? null : () => context.go('/login'),
                          child: const Text('¿Ya tienes salón? Inicia sesión'),
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

  bool _isValidEmail(String email) {
    final regex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }
}
