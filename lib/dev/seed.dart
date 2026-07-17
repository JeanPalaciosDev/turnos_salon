import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../features/auth/domain/usuario.dart';
import '../features/clientes/domain/cliente.dart';
import '../features/config/domain/salon_config.dart';
import '../features/servicios/domain/servicio.dart';
import '../features/tenant/domain/tenant.dart';
import '../features/trabajadores/domain/trabajador.dart';
import '../features/turnos/domain/turno.dart';

/// Siembra datos de demo en el **emulador** de Firestore.
///
/// Sólo se ejecuta cuando la app corre contra el emulador (ver `main.dart`).
/// Es **idempotente**: si ya hay servicios cargados, no hace nada — así, con
/// `firebase emulators:start --import=... --export-on-exit`, los datos persisten
/// entre ejecuciones y no se duplican.
///
/// Usa los modelos del dominio (`toMap()`), de modo que los nombres de campo
/// quedan garantizados iguales a los que lee la app.
Future<void> seedEmulatorIfEmpty(FirebaseFirestore db) async {
  // Las cuentas Auth se siembran SIEMPRE (idempotencia propia vía
  // email-already-in-use), independientes del guard de datos demo de abajo.
  // Antes quedaban detrás del early-return y NO se creaban si los datos ya
  // estaban sembrados (corrida parcial / reload) → "el seed no creó cuentas
  // Auth" (bug 2026-06-22).
  await _seedUsuariosAuth(db);

  final yaSembrado = await db.collection('servicios').limit(1).get();
  if (yaSembrado.docs.isNotEmpty) return;

  final hoy = _hoy();
  final ayer = _fmtFecha(DateTime.now().subtract(const Duration(days: 1)));
  final batch = db.batch();

  // ── config/salon ─────────────────────────────────────────────────────────
  batch.set(
    db.collection('config').doc('salon'),
    const SalonConfig(
      nombre: 'Salón Demo',
      diasLaborables: [1, 2, 3, 4, 5, 6],
      horaApertura: '09:00',
      horaCierre: '20:00',
      zonaHoraria: 'America/Argentina/Buenos_Aires',
    ).toMap(),
  );

  // ── trabajadores ───────────────────────────────────────────────────────────
  const horarioBase = [
    HorarioLaboral(diaSemana: 1, horaInicio: '09:00', horaFin: '20:00'),
    HorarioLaboral(diaSemana: 2, horaInicio: '09:00', horaFin: '20:00'),
    HorarioLaboral(diaSemana: 3, horaInicio: '09:00', horaFin: '20:00'),
    HorarioLaboral(diaSemana: 4, horaInicio: '09:00', horaFin: '20:00'),
    HorarioLaboral(diaSemana: 5, horaInicio: '09:00', horaFin: '20:00'),
    HorarioLaboral(diaSemana: 6, horaInicio: '09:00', horaFin: '14:00'),
  ];
  const trabajadores = <String, Trabajador>{
    'ana': Trabajador(
        id: 'ana', nombre: 'Ana',
        color: '#534AB7', activo: true, horario: horarioBase),
    'marta': Trabajador(
        id: 'marta', nombre: 'Marta',
        color: '#B7434A', activo: true, horario: horarioBase),
    'luis': Trabajador(
        id: 'luis', nombre: 'Luis',
        color: '#2F8F6B', activo: true, horario: horarioBase),
  };
  trabajadores.forEach((id, t) =>
      batch.set(db.collection('trabajadores').doc(id), t.toMap()));

  // ── servicios ──────────────────────────────────────────────────────────────
  const servicios = <String, Servicio>{
    'corte': Servicio(
        id: 'corte', nombre: 'Corte de cabello', precioReferencia: 8000,
        duracionMin: 30, activo: true, categoria: 'Cabello'),
    'tinte': Servicio(
        id: 'tinte', nombre: 'Tinte / Color', precioReferencia: 25000,
        duracionMin: 90, activo: true, categoria: 'Color'),
    'peinado': Servicio(
        id: 'peinado', nombre: 'Peinado', precioReferencia: 12000,
        duracionMin: 45, activo: true, categoria: 'Cabello'),
    'manicura': Servicio(
        id: 'manicura', nombre: 'Manicura', precioReferencia: 9000,
        duracionMin: 40, activo: true, categoria: 'Uñas'),
    'barba': Servicio(
        id: 'barba', nombre: 'Arreglo de barba', precioReferencia: 5000,
        duracionMin: 20, activo: true, categoria: 'Barbería'),
  };
  servicios.forEach((id, s) =>
      batch.set(db.collection('servicios').doc(id), s.toMap()));

  // ── clientes ────────────────────────────────────────────────────────────────
  const clientes = <String, Cliente>{
    'lucia': Cliente(id: 'lucia', nombre: 'Lucía Gómez', telefono: '+54 9 11 5555-0001'),
    'sofia': Cliente(id: 'sofia', nombre: 'Sofía Ramírez', telefono: '+54 9 11 5555-0002'),
    'diego': Cliente(id: 'diego', nombre: 'Diego Fernández', telefono: '+54 9 11 5555-0003'),
    'valen': Cliente(id: 'valen', nombre: 'Valentina Cruz'),
  };
  clientes.forEach((id, c) =>
      batch.set(db.collection('clientes').doc(id), c.toMap()));

  // ── turnos de HOY ────────────────────────────────────────────────────────────
  // t1 y t2 son de Ana y se SOLAPAN (09:00–09:30 vs 09:15–10:45) → la agenda
  // los agrupa con la marca "⟂ 2 en simultáneo". Caso clave del producto.
  final turnos = <Turno>[
    _turno('t1', hoy, '09:00', 'ana', 'Ana', 'lucia', 'Lucía Gómez',
        [_svc('corte', 'Corte de cabello', 30)], EstadoTurno.pendiente),
    _turno('t2', hoy, '09:15', 'ana', 'Ana', 'sofia', 'Sofía Ramírez',
        [_svc('tinte', 'Tinte / Color', 90)], EstadoTurno.noShow),
    _turno('t3', hoy, '10:00', 'marta', 'Marta', 'diego', 'Diego Fernández',
        [_svc('barba', 'Arreglo de barba', 20), _svc('corte', 'Corte de cabello', 30)],
        EstadoTurno.pendiente),
    // Turno de AYER ya cobrado → alimenta el historial de la ficha de Lucía.
    _turno('t0', ayer, '11:00', 'ana', 'Ana', 'lucia', 'Lucía Gómez',
        [_svc('corte', 'Corte de cabello', 30), _svc('peinado', 'Peinado', 45)],
        EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [
            LineaCobro(servicioId: 'corte', nombre: 'Corte de cabello', monto: 8000),
            LineaCobro(servicioId: 'peinado', nombre: 'Peinado', monto: 14000),
          ],
          total: 20000,
          descuento: 2000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 1))),

    // ── turnos históricos (días -1 a -9) ──────────────────────────────────
    // Nota de alcance: se usan solo `ana`/`marta` como trabajadoras de estos
    // turnos (no `luis`, cuyo rol de catálogo es `recepcion`, no `estilista`)
    // para mantener el seed realista; el requisito de variedad ("cada
    // trabajador usado" con ≥2 turnos completado) queda cubierto por ambas.
    _turno('t4', _fmtFecha(DateTime.now().subtract(const Duration(days: 1))),
        '09:00', 'ana', 'Ana', 'lucia', 'Lucía Gómez',
        [_svc('corte', 'Corte de cabello', 30)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'corte', nombre: 'Corte de cabello', monto: 8000)],
          total: 8000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 1))),
    _turno('t5', _fmtFecha(DateTime.now().subtract(const Duration(days: 1))),
        '10:30', 'marta', 'Marta', 'sofia', 'Sofía Ramírez',
        [_svc('tinte', 'Tinte / Color', 90)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'tinte', nombre: 'Tinte / Color', monto: 26000)],
          total: 26000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 1))),
    _turno('t6', _fmtFecha(DateTime.now().subtract(const Duration(days: 2))),
        '13:00', 'ana', 'Ana', 'diego', 'Diego Fernández',
        [_svc('peinado', 'Peinado', 45)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'peinado', nombre: 'Peinado', monto: 12000)],
          total: 12000,
          metodoPago: 'tarjeta',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 2))),
    _turno('t7', _fmtFecha(DateTime.now().subtract(const Duration(days: 2))),
        '15:00', 'marta', 'Marta', 'valen', 'Valentina Cruz',
        [_svc('manicura', 'Manicura', 40)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'manicura', nombre: 'Manicura', monto: 9000)],
          total: 9000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 2))),
    _turno('t8', _fmtFecha(DateTime.now().subtract(const Duration(days: 2))),
        '17:30', 'ana', 'Ana', 'lucia', 'Lucía Gómez',
        [_svc('barba', 'Arreglo de barba', 20)], EstadoTurno.cancelado),
    _turno('t9', _fmtFecha(DateTime.now().subtract(const Duration(days: 3))),
        '19:00', 'marta', 'Marta', 'sofia', 'Sofía Ramírez',
        [_svc('corte', 'Corte de cabello', 30)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'corte', nombre: 'Corte de cabello', monto: 8500)],
          total: 8500,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 3))),
    _turno('t10', _fmtFecha(DateTime.now().subtract(const Duration(days: 3))),
        '09:00', 'ana', 'Ana', 'diego', 'Diego Fernández',
        [_svc('corte', 'Corte de cabello', 30), _svc('peinado', 'Peinado', 45)],
        EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [
            LineaCobro(servicioId: 'corte', nombre: 'Corte de cabello', monto: 8000),
            LineaCobro(servicioId: 'peinado', nombre: 'Peinado', monto: 12500),
          ],
          total: 19000,
          descuento: 1500,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 3))),
    _turno('t11', _fmtFecha(DateTime.now().subtract(const Duration(days: 4))),
        '10:30', 'marta', 'Marta', 'valen', 'Valentina Cruz',
        [_svc('tinte', 'Tinte / Color', 90)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'tinte', nombre: 'Tinte / Color', monto: 25000)],
          total: 25000,
          metodoPago: 'tarjeta',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 4))),
    _turno('t12', _fmtFecha(DateTime.now().subtract(const Duration(days: 4))),
        '13:00', 'ana', 'Ana', 'lucia', 'Lucía Gómez',
        [_svc('barba', 'Arreglo de barba', 20)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'barba', nombre: 'Arreglo de barba', monto: 5000)],
          total: 5000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 4))),
    _turno('t13', _fmtFecha(DateTime.now().subtract(const Duration(days: 4))),
        '15:00', 'marta', 'Marta', 'sofia', 'Sofía Ramírez',
        [_svc('peinado', 'Peinado', 45)], EstadoTurno.noShow),
    _turno('t14', _fmtFecha(DateTime.now().subtract(const Duration(days: 5))),
        '17:30', 'ana', 'Ana', 'diego', 'Diego Fernández',
        [_svc('corte', 'Corte de cabello', 30)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'corte', nombre: 'Corte de cabello', monto: 7500)],
          total: 7500,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 5))),
    _turno('t15', _fmtFecha(DateTime.now().subtract(const Duration(days: 5))),
        '19:00', 'marta', 'Marta', 'valen', 'Valentina Cruz',
        [_svc('manicura', 'Manicura', 40)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'manicura', nombre: 'Manicura', monto: 9500)],
          total: 9500,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 5))),
    _turno('t16', _fmtFecha(DateTime.now().subtract(const Duration(days: 6))),
        '09:00', 'ana', 'Ana', 'lucia', 'Lucía Gómez',
        [_svc('tinte', 'Tinte / Color', 90)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'tinte', nombre: 'Tinte / Color', monto: 24000)],
          total: 24000,
          metodoPago: 'tarjeta',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 6))),
    _turno('t17', _fmtFecha(DateTime.now().subtract(const Duration(days: 6))),
        '10:30', 'marta', 'Marta', 'sofia', 'Sofía Ramírez',
        [_svc('barba', 'Arreglo de barba', 20)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'barba', nombre: 'Arreglo de barba', monto: 5000)],
          total: 5000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 6))),
    _turno('t18', _fmtFecha(DateTime.now().subtract(const Duration(days: 6))),
        '13:00', 'ana', 'Ana', 'diego', 'Diego Fernández',
        [_svc('corte', 'Corte de cabello', 30)], EstadoTurno.cancelado),
    _turno('t19', _fmtFecha(DateTime.now().subtract(const Duration(days: 7))),
        '15:00', 'marta', 'Marta', 'valen', 'Valentina Cruz',
        [_svc('peinado', 'Peinado', 45)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'peinado', nombre: 'Peinado', monto: 12000)],
          total: 12000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 7))),
    _turno('t20', _fmtFecha(DateTime.now().subtract(const Duration(days: 7))),
        '17:30', 'ana', 'Ana', 'lucia', 'Lucía Gómez',
        [_svc('corte', 'Corte de cabello', 30)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'corte', nombre: 'Corte de cabello', monto: 8000)],
          total: 7000,
          descuento: 1000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 7))),
    _turno('t21', _fmtFecha(DateTime.now().subtract(const Duration(days: 8))),
        '19:00', 'marta', 'Marta', 'sofia', 'Sofía Ramírez',
        [_svc('manicura', 'Manicura', 40)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'manicura', nombre: 'Manicura', monto: 9000)],
          total: 9000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 8))),
    _turno('t22', _fmtFecha(DateTime.now().subtract(const Duration(days: 8))),
        '09:00', 'ana', 'Ana', 'diego', 'Diego Fernández',
        [_svc('peinado', 'Peinado', 45)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'peinado', nombre: 'Peinado', monto: 12500)],
          total: 12500,
          metodoPago: 'tarjeta',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 8))),
    _turno('t23', _fmtFecha(DateTime.now().subtract(const Duration(days: 8))),
        '10:30', 'marta', 'Marta', 'valen', 'Valentina Cruz',
        [_svc('corte', 'Corte de cabello', 30), _svc('barba', 'Arreglo de barba', 20)],
        EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [
            LineaCobro(servicioId: 'corte', nombre: 'Corte de cabello', monto: 8000),
            LineaCobro(servicioId: 'barba', nombre: 'Arreglo de barba', monto: 5000),
          ],
          total: 12000,
          descuento: 1000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 8))),
    _turno('t24', _fmtFecha(DateTime.now().subtract(const Duration(days: 9))),
        '13:00', 'ana', 'Ana', 'lucia', 'Lucía Gómez',
        [_svc('corte', 'Corte de cabello', 30)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'corte', nombre: 'Corte de cabello', monto: 8000)],
          total: 8000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 9))),
    _turno('t25', _fmtFecha(DateTime.now().subtract(const Duration(days: 9))),
        '15:00', 'marta', 'Marta', 'sofia', 'Sofía Ramírez',
        [_svc('tinte', 'Tinte / Color', 90)], EstadoTurno.completado,
        cobro: const Cobro(
          lineas: [LineaCobro(servicioId: 'tinte', nombre: 'Tinte / Color', monto: 25000)],
          total: 25000,
          metodoPago: 'efectivo',
        ),
        fechaCobro: DateTime.now().subtract(const Duration(days: 9))),
  ];
  for (final t in turnos) {
    batch.set(db.collection('turnos').doc(t.id), t.toMap());
  }

  await batch.commit();

  // ── Phase 1: Multi-tenant migration ───────────────────────────────────────
  // Migrate root collections to tenant-scoped structure.
  await _migrateToMultiTenant(db);
}

/// Per multi-tenant plan Phase 1: Migrate existing root collections to
/// tenant-scoped structure (`tenants/tenant_0/{collection}`).
///
/// Idempotent: if `tenants/tenant_0` already exists, skips migration.
/// This allows safe re-runs after partial migrations or app reloads.
///
/// Steps:
/// 1. Check if `tenants/tenant_0` exists; if so, skip.
/// 2. Create `tenants/tenant_0` with branding defaults and owner email.
/// 3. Move root collections (config, servicios, trabajadores, clientes, turnos)
///    to `tenants/tenant_0/{collection}`.
/// 4. Add `tenant_id: "tenant_0"` to all `usuarios/{uid}` docs.
/// 5. Promote the 'dueno' user to `role: "super_admin"`.
Future<void> _migrateToMultiTenant(FirebaseFirestore db) async {
  const tenantId = 'tenant_0';
  final tenantRef = db.collection('tenants').doc(tenantId);

  // Check if tenant already exists (idempotence guard).
  final tenantSnap = await tenantRef.get();
  if (tenantSnap.exists) {
    debugPrint('[Tenant Migration] tenant_0 already exists, skipping migration.');
    return;
  }

  debugPrint('[Tenant Migration] Starting migration to multi-tenant structure...');

  // Find the owner email: look for 'dueno' in usuarios collection.
  String ownerEmail = 'demo@salon.test';
  try {
    final usuariosSnap = await db.collection('usuarios').get();
    for (final doc in usuariosSnap.docs) {
      final data = doc.data();
      if (data['trabajador_id'] == 'dueno') {
        ownerEmail = data['email'] as String? ?? 'demo@salon.test';
        break;
      }
    }
  } catch (e) {
    debugPrint('[Tenant Migration] Warning: Could not fetch usuarios: $e');
  }

  // Create tenants/tenant_0 with branding defaults.
  final tenant = Tenant(
    id: tenantId,
    name: 'Salón Demo',
    estado: 'activo',
    branding: const Branding(
      colorPrimary: '#534AB7',
      colorSecondary: '#B7434A',
      colorAccent: '#2F8F6B',
    ),
    ownerEmail: ownerEmail,
    createdAt: DateTime.now(),
  );
  await tenantRef.set(tenant.toMap());
  debugPrint('[Tenant Migration] Created tenants/$tenantId with branding.');

  // Batch 1: Migrate root collections to tenant subcollections.
  final batch1 = db.batch();
  try {
    // Migrate config/salon to tenants/tenant_0/config/salon
    final configSnap = await db.collection('config').doc('salon').get();
    if (configSnap.exists) {
      batch1.set(
        tenantRef.collection('config').doc('salon'),
        configSnap.data()!,
      );
    }

    // Migrate servicios
    final serviciosSnap = await db.collection('servicios').get();
    for (final doc in serviciosSnap.docs) {
      batch1.set(
        tenantRef.collection('servicios').doc(doc.id),
        doc.data(),
      );
    }

    // Migrate trabajadores
    final trabajadoresSnap = await db.collection('trabajadores').get();
    for (final doc in trabajadoresSnap.docs) {
      batch1.set(
        tenantRef.collection('trabajadores').doc(doc.id),
        doc.data(),
      );
    }

    // Migrate clientes
    final clientesSnap = await db.collection('clientes').get();
    for (final doc in clientesSnap.docs) {
      batch1.set(
        tenantRef.collection('clientes').doc(doc.id),
        doc.data(),
      );
    }

    // Migrate turnos
    final turnosSnap = await db.collection('turnos').get();
    for (final doc in turnosSnap.docs) {
      batch1.set(
        tenantRef.collection('turnos').doc(doc.id),
        doc.data(),
      );
    }

    await batch1.commit();
    debugPrint(
        '[Tenant Migration] Migrated config, servicios, trabajadores, clientes, turnos.');
  } catch (e) {
    debugPrint('[Tenant Migration] Error during collections migration: $e');
  }

  // Batch 2: Update usuarios with tenant_id and promote dueno to super_admin.
  final batch2 = db.batch();
  try {
    final usuariosSnap = await db.collection('usuarios').get();
    for (final doc in usuariosSnap.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['tenant_id'] = tenantId;

      // Promote dueno to super_admin (keep working_role as dueno for backward compat).
      if (data['trabajador_id'] == 'dueno') {
        data['role'] = 'super_admin';
      }

      batch2.update(doc.reference, data);
    }

    await batch2.commit();
    debugPrint('[Tenant Migration] Updated usuarios with tenant_id and promoted dueno.');
  } catch (e) {
    debugPrint('[Tenant Migration] Error updating usuarios: $e');
  }

  debugPrint('[Tenant Migration] Multi-tenant migration complete.');
}

/// Siembra cuentas de Auth (emulador) + docs `usuarios/{uid}` para los roles
/// demo, de modo que en Fase 2F se pueda probar el login y los permisos.
///
/// **Credenciales demo (solo emulador), password común `salon123`:**
///   - dueno@salon.test  → rol dueno      (trabajador_id 'dueno')
///   - ana@salon.test    → rol estilista  (trabajador_id 'ana')
///   - marta@salon.test  → rol estilista  (trabajador_id 'marta')
///   - luis@salon.test   → rol recepcion  (trabajador_id 'luis')
///
/// Idempotente: si la cuenta Auth ya existe (`email-already-in-use`) se omite,
/// así puede correr aunque los servicios ya estén sembrados sin duplicar nada.
/// Usa `FirebaseAuth.instance` (ya cableada al emulador en `main.dart`).
Future<void> _seedUsuariosAuth(FirebaseFirestore db) async {
  const password = 'salon123';
  // El dueño no está en la lista de trabajadores demo: creamos también su doc
  // trabajador para que el vínculo quede coherente.
  await db.collection('trabajadores').doc('dueno').set(const Trabajador(
        id: 'dueno',
        nombre: 'Dueño',
        color: '#444444',
        activo: true,
      ).toMap());

  const demo = <_UsuarioSeed>[
    _UsuarioSeed('dueno@salon.test', 'dueno', 'Dueño'),
    _UsuarioSeed('ana@salon.test', 'ana', 'Ana'),
    _UsuarioSeed('marta@salon.test', 'marta', 'Marta'),
    _UsuarioSeed('luis@salon.test', 'luis', 'Luis'),
  ];

  final auth = FirebaseAuth.instance;
  for (final u in demo) {
    try {
      final cred = await auth.createUserWithEmailAndPassword(
        email: u.email,
        password: password,
      );
      final uid = cred.user!.uid;
      await db.collection('usuarios').doc(uid).set({
        ...Usuario(
          uid: uid,
          trabajadorId: u.trabajadorId,
          nombre: u.nombre,
          email: u.email,
          activo: true,
        ).toMap(),
        'created_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      // Ya existe (corridas previas): se respeta la idempotencia y se omite.
      if (e.code == 'email-already-in-use') continue;
      // Cualquier otro fallo se loguea (antes fallaba en silencio en web) pero
      // no aborta las demás cuentas.
      debugPrint('seed: no se pudo crear ${u.email}: ${e.code}');
    } catch (e) {
      debugPrint('seed: error inesperado creando ${u.email}: $e');
    }
  }
  // Dejar la sesión limpia: createUser deja al último usuario logueado.
  await auth.signOut();
}

class _UsuarioSeed {
  const _UsuarioSeed(this.email, this.trabajadorId, this.nombre);
  final String email;
  final String trabajadorId;
  final String nombre;
}

// ── helpers ──────────────────────────────────────────────────────────────────

ServicioEnTurno _svc(String id, String nombre, int dur) =>
    ServicioEnTurno(servicioId: id, nombre: nombre, duracionMin: dur);

Turno _turno(
  String id,
  String fecha,
  String horaInicio,
  String trabId,
  String trabNombre,
  String cliId,
  String cliNombre,
  List<ServicioEnTurno> servicios,
  EstadoTurno estado, {
  Cobro? cobro,
  DateTime? fechaCobro,
}) {
  final durTotal = servicios.fold<int>(0, (s, e) => s + e.duracionMin);
  return Turno(
    id: id,
    fecha: fecha,
    horaInicio: horaInicio,
    finEstimado: _addMin(horaInicio, durTotal),
    trabajadorId: trabId,
    trabajadorNombre: trabNombre,
    clienteId: cliId,
    clienteNombre: cliNombre,
    servicios: servicios,
    estado: estado,
    creadoPor: 'seed',
    cobro: cobro,
    fechaCobro: fechaCobro,
  );
}

String _hoy() => _fmtFecha(DateTime.now());

String _fmtFecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _addMin(String hhmm, int min) {
  final partes = hhmm.split(':');
  final total = int.parse(partes[0]) * 60 + int.parse(partes[1]) + min;
  final h = (total ~/ 60) % 24;
  final m = total % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
