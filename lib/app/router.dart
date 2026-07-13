import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/audit_log_screen.dart';
import '../features/admin/presentation/manage_tenant_users_screen.dart';
import '../features/agenda/presentation/agenda_dia_screen.dart';
import '../features/agenda/presentation/agenda_semana_screen.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/tenant/application/tenant_providers.dart';
import '../features/auth/presentation/create_salon_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/usuarios_screen.dart';
import '../features/clientes/domain/cliente.dart';
import '../features/clientes/presentation/cliente_detalle_screen.dart';
import '../features/clientes/presentation/clientes_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/servicios/presentation/servicios_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/shell/presentation/mas_screen.dart';
import '../features/tenant/presentation/tenants_admin_screen.dart';
import '../features/trabajadores/presentation/trabajadores_screen.dart';
import 'go_router_refresh_stream.dart';

/// Configuración de navegación (go_router).
///
/// Navegación primaria vía `NavigationBar` inferior (M3): las ramas Agenda /
/// Clientes / Más viven dentro de un `StatefulShellRoute.indexedStack` que
/// conserva el estado de cada pestaña. El resto de pantallas (login, detalle
/// diario, detalle de cliente, y los CRUD del dueño) se apilan full-screen
/// SOBRE la barra usando el `rootNavigatorKey`.
/// Rutas accesibles solo por el dueño (matriz de permisos §7).
const rutasSoloDueno = {'/servicios', '/trabajadores', '/usuarios', '/dashboard'};

/// Rutas solo para super-admin (Phase 4: multi-tenant).
const rutasSoloSuperAdmin = {'/sistema/tenants', '/audit-logs'};

/// Navigator raíz: las rutas que lo usan como `parentNavigatorKey` se dibujan
/// por encima de la `NavigationBar` (full-screen).
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/agenda',
    // El router se reevalúa cuando cambia el estado de auth (login/logout).
    // refreshListenable requiere un Listenable: el ChangeNotifier que adapta
    // el Stream<User?>, NUNCA un AsyncValue.
    refreshListenable:
        GoRouterRefreshStream(ref.watch(authRepositoryProvider).authState()),
    redirect: (context, state) {
      // OJO: leer el `currentUser` vivo de FirebaseAuth, NO
      // `authStateProvider.value`. El `refreshListenable` y `authStateProvider`
      // se suscriben a streams `authStateChanges()` distintos; Firebase notifica
      // en orden de suscripción y el refreshListenable (suscrito primero) dispara
      // el redirect ANTES de que el provider actualice su `.value` → el redirect
      // leería `null` y se quedaría en /login pese a un login exitoso (sin error
      // visible). `currentUser` ya está actualizado cuando dispara cualquier
      // listener de authStateChanges, así que no depende del orden de emisión.
      final loggedIn = ref.read(authRepositoryProvider).currentUser != null;
      final yendoALogin = state.matchedLocation == '/login';
      final yendoACrearSalon = state.matchedLocation == '/crear-salon';

      // Guard 1: Redirigir a login si no hay sesión
      if (!loggedIn && !yendoALogin && !yendoACrearSalon) return '/login';
      if (loggedIn && yendoALogin) return '/agenda';
      if (loggedIn && yendoACrearSalon) return '/agenda';

      // Guard 2 (Phase 6): Verificar que tenant_id existe en Custom Claims
      final tenantId = ref.read(tenantIdProvider).value;
      if (loggedIn &&
          !yendoALogin &&
          !yendoACrearSalon &&
          tenantId == null) {
        // Usuario logueado pero sin tenant asignado (edge case: super_admin).
        // Redirigir a login con error.
        debugPrint('Usuario sin tenant_id asignado; redirigiendo a login');
        return '/login';
      }

      // Guard 3 (Phase 6): Verificar que el tenant está cargado y activo
      // para rutas protegidas (excepto login/crear-salon).
      if (loggedIn && !yendoALogin && !yendoACrearSalon && tenantId != null) {
        final tenantAsync = ref.read(currentTenantProvider);

        // Si el tenant tiene error, redirigir a login
        if (tenantAsync.hasError) {
          debugPrint(
              'Error cargando tenant: ${tenantAsync.error}; redirigiendo a login');
          return '/login';
        }

        // Si el tenant cargó y está suspendido, hacer logout
        if (tenantAsync.value != null &&
            tenantAsync.value!.estado != 'activo') {
          debugPrint(
              'Tenant suspendido (${tenantAsync.value!.estado}); cerrando sesión');
          ref.read(authRepositoryProvider).signOut();
          return '/login';
        }
      }

      // Guard 4: Guard por rol: rutas admin-only solo para el dueño.
      if (loggedIn &&
          rutasSoloDueno.contains(state.matchedLocation) &&
          ref.read(esDuenoProvider) == false) {
        return '/agenda';
      }

      // Guard 5: Guard por rol: rutas super-admin-only solo para super_admin (Phase 4).
      if (loggedIn &&
          rutasSoloSuperAdmin.contains(state.matchedLocation) &&
          (ref.read(isSuperAdminProvider).value ?? false) == false) {
        return '/agenda';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/crear-salon',
        name: 'crear-salon',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateSalonScreen(),
      ),
      // Navegación primaria: barra inferior con 3 ramas (cada una mantiene su
      // propio Navigator → estado por pestaña preservado).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agenda',
                name: 'agenda',
                builder: (context, state) => const AgendaSemanaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clientes',
                name: 'clientes',
                builder: (context, state) => const ClientesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mas',
                name: 'mas',
                builder: (context, state) => const MasScreen(),
              ),
            ],
          ),
        ],
      ),
      // Rutas full-screen (sobre la barra), en el navigator raíz.
      GoRoute(
        path: '/agenda/dia',
        name: 'agenda-dia',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AgendaDiaScreen(),
      ),
      GoRoute(
        path: '/servicios',
        name: 'servicios',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ServiciosScreen(),
      ),
      GoRoute(
        path: '/trabajadores',
        name: 'trabajadores',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TrabajadoresScreen(),
      ),
      GoRoute(
        path: '/usuarios',
        name: 'usuarios',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UsuariosScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/clientes/detalle',
        name: 'cliente-detalle',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ClienteDetalleScreen(cliente: state.extra as Cliente),
      ),
      GoRoute(
        path: '/sistema/tenants',
        name: 'tenants-admin',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TenantsAdminScreen(),
      ),
      GoRoute(
        path: '/audit-logs',
        name: 'audit-logs',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AuditLogScreen(),
      ),
      GoRoute(
        path: '/audit-logs/:tenantId',
        name: 'audit-logs-tenant',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final tenantId = state.pathParameters['tenantId'];
          return AuditLogScreen(tenantId: tenantId);
        },
      ),
      GoRoute(
        path: '/tenant/:tenantId/usuarios',
        name: 'manage-tenant-users',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final tenantId = state.pathParameters['tenantId']!;
          final tenantName = state.extra as String? ?? tenantId;
          return ManageTenantUsersScreen(
            tenantId: tenantId,
            tenantName: tenantName,
          );
        },
      ),
    ],
  );
});
