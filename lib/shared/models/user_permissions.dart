/// Modelo de permisos de usuario basado en rol.
///
/// Define qué acciones puede realizar cada rol en la aplicación.
/// Se utiliza para habilitar/deshabilitar botones y validar acciones en la UI.
class UserPermissions {
  /// Acciones permitidas para un usuario con este rol.
  final Set<String> permissions;

  const UserPermissions._(this.permissions);

  /// Crea permisos para un usuario 'dueno' (propietario del tenant).
  /// Tiene acceso completo a todas las funcionalidades.
  factory UserPermissions.dueno() {
    return UserPermissions._(
      {
        // Gestión de usuarios
        'create_user',
        'update_user',
        'delete_user',
        'change_role',
        'view_user_list',

        // Gestión de servicios
        'create_service',
        'update_service',
        'delete_service',
        'view_services',

        // Gestión de trabajadores
        'create_worker',
        'update_worker',
        'delete_worker',
        'view_workers',

        // Gestión de clientes
        'create_client',
        'update_client',
        'delete_client',
        'view_clients',

        // Gestión de turnos
        'create_appointment',
        'update_appointment',
        'delete_appointment',
        'view_schedule',
        'manage_schedule',

        // Dashboard y reportes
        'view_dashboard',
        'view_reports',

        // Auditoría
        'view_audit_logs',
      },
    );
  }

  /// Crea permisos para un usuario 'recepcionista'.
  /// Puede gestionar turnos y clientes, pero no usuarios ni configuración.
  factory UserPermissions.recepcionista() {
    return UserPermissions._(
      {
        // Gestión de clientes
        'create_client',
        'update_client',
        'view_clients',

        // Gestión de turnos
        'create_appointment',
        'update_appointment',
        'delete_appointment',
        'view_schedule',
        'manage_schedule',

        // Dashboard
        'view_dashboard',
      },
    );
  }

  /// Crea permisos para un usuario 'estilista'.
  /// Solo puede ver su propia agenda.
  factory UserPermissions.estilista() {
    return UserPermissions._(
      {
        'view_own_schedule',
      },
    );
  }

  /// Obtiene permisos basado en el rol.
  static UserPermissions forRole(String role) {
    return switch (role) {
      'dueno' => UserPermissions.dueno(),
      'recepcionista' => UserPermissions.recepcionista(),
      'estilista' => UserPermissions.estilista(),
      _ => UserPermissions._({}),
    };
  }

  /// Verifica si el usuario tiene un permiso específico.
  bool hasPermission(String permission) {
    return permissions.contains(permission);
  }

  /// Verifica si el usuario tiene alguno de los permisos especificados.
  bool hasAnyPermission(Iterable<String> perms) {
    return perms.any((p) => permissions.contains(p));
  }

  /// Verifica si el usuario tiene todos los permisos especificados.
  bool hasAllPermissions(Iterable<String> perms) {
    return perms.every((p) => permissions.contains(p));
  }

  /// Lista de todos los permisos disponibles.
  static const List<String> allPermissions = [
    'create_user',
    'update_user',
    'delete_user',
    'change_role',
    'view_user_list',
    'create_service',
    'update_service',
    'delete_service',
    'view_services',
    'create_worker',
    'update_worker',
    'delete_worker',
    'view_workers',
    'create_client',
    'update_client',
    'delete_client',
    'view_clients',
    'create_appointment',
    'update_appointment',
    'delete_appointment',
    'view_schedule',
    'manage_schedule',
    'view_own_schedule',
    'view_dashboard',
    'view_reports',
    'view_audit_logs',
  ];
}
