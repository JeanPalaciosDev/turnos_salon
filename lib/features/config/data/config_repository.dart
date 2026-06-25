import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore.dart';
import '../domain/salon_config.dart';

/// Acceso al documento único `config/salon`.
class ConfigRepository {
  ConfigRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('config').doc('salon');

  Stream<SalonConfig?> watch() => _doc.snapshots().map(
        (d) => d.exists ? SalonConfig.fromMap(d.data()!) : null,
      );

  /// Crea la config con valores por defecto si todavía no existe.
  Future<void> ensureSeed() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      await _doc.set(SalonConfig.fromMap(const {}).toMap());
    }
  }

  Future<void> save(SalonConfig config) =>
      _doc.set(config.toMap(), SetOptions(merge: true));
}

final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => ConfigRepository(ref.watch(firestoreProvider)),
);

final configStreamProvider = StreamProvider<SalonConfig?>(
  (ref) => ref.watch(configRepositoryProvider).watch(),
);
