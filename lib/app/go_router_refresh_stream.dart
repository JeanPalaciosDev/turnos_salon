import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapta un [Stream] a un [Listenable] para usarlo como `refreshListenable`
/// de go_router (que requiere un [Listenable], no un `AsyncValue`).
///
/// Patrón canónico de Code With Andrea:
/// https://pro.codewithandrea.com/flutter-foundations/05-riverpod-part2/22-go-router-refresh-listenable
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
