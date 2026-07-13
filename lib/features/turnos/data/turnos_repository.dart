import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/turno.dart';

/// Acceso a la colección `turnos` en un tenant específico.
///
/// Todas las queries usan la ruta: `tenants/{tenantId}/turnos/{turno_id}`
/// para mantener aislamiento de datos multi-tenant.
class TurnosRepository {
  TurnosRepository(this._db, this.tenantId);
  final FirebaseFirestore _db;
  final String tenantId;

  CollectionReference<Map<String, dynamic>> get _col => _db
      .collection('tenants')
      .doc(tenantId)
      .collection('turnos');

  /// Turnos de un día concreto ('yyyy-MM-dd'), ordenados por hora de inicio.
  ///
  /// Se filtra por igualdad de `fecha` y se ordena en el cliente para no
  /// requerir un índice compuesto (los turnos de un día son pocos).
  Stream<List<Turno>> watchByFecha(String fecha) =>
      _col.where('fecha', isEqualTo: fecha).snapshots().map((snap) {
        final turnos =
            snap.docs.map((d) => Turno.fromMap(d.id, d.data())).toList();
        turnos.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
        return turnos;
      });

  /// Turnos entre dos fechas inclusive ('yyyy-MM-dd'). Rango sobre el único
  /// campo de desigualdad `fecha` → sin índice compuesto. Ordena en cliente.
  Stream<List<Turno>> watchByRango(String desde, String hasta) =>
      _col
          .where('fecha', isGreaterThanOrEqualTo: desde)
          .where('fecha', isLessThanOrEqualTo: hasta)
          .snapshots()
          .map((snap) {
            final turnos =
                snap.docs.map((d) => Turno.fromMap(d.id, d.data())).toList();
            turnos.sort((a, b) {
              final f = a.fecha.compareTo(b.fecha);
              return f != 0 ? f : a.horaInicio.compareTo(b.horaInicio);
            });
            return turnos;
          });

  Future<String> upsert(Turno turno) async {
    if (turno.id.isEmpty) {
      final ref = await _col.add(turno.toMap());
      return ref.id;
    }
    await _col.doc(turno.id).set(turno.toMap(), SetOptions(merge: true));
    return turno.id;
  }

  Future<void> updateEstado(String turnoId, EstadoTurno estado) =>
      _col.doc(turnoId).set({
        'estado': estadoToDb(estado),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Turnos de un cliente, del más reciente al más antiguo. Para el historial
  /// de su ficha. Se filtra por igualdad de `cliente_id` y se ordena en el
  /// cliente (un cliente individual tiene pocos turnos → sin índice compuesto).
  Stream<List<Turno>> watchByCliente(String clienteId) => _col
          .where('cliente_id', isEqualTo: clienteId)
          .snapshots()
          .map((snap) {
        final turnos =
            snap.docs.map((d) => Turno.fromMap(d.id, d.data())).toList();
        turnos.sort((a, b) {
          final porFecha = b.fecha.compareTo(a.fecha);
          return porFecha != 0
              ? porFecha
              : b.horaInicio.compareTo(a.horaInicio);
        });
        return turnos;
      });

  /// Cierra el turno: registra el cobro y lo marca como completado.
  ///
  /// A diferencia del resto de escrituras (que NO se esperan, para no colgar la
  /// UI con la caché offline), el cobro corre dentro de una **transacción** y
  /// SÍ se espera: garantiza que un turno no se cobre dos veces aunque dos
  /// dispositivos lo cierren a la vez (riesgo §9 de la spec). La transacción
  /// requiere conexión; el llamador debe manejar el error si no hay red.
  Future<void> registrarCobro(String turnoId, Cobro cobro) {
    final ref = _col.doc(turnoId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('El turno ya no existe.');
      }
      if (snap.data()?['estado'] == estadoToDb(EstadoTurno.completado)) {
        throw StateError('Este turno ya fue cobrado.');
      }
      tx.set(
        ref,
        {
          'estado': estadoToDb(EstadoTurno.completado),
          'cobro': cobro.toMap(),
          'fecha_cobro': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}

// NOTE: Providers moved to lib/features/turnos/application/turno_providers.dart
// to allow dependency on currentTenantIdProvider for multi-tenant queries.
