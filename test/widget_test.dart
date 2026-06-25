import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:turnos_salon/app/app.dart';
import 'package:turnos_salon/features/auth/application/auth_providers.dart';
import 'package:turnos_salon/features/auth/data/auth_repository.dart';

/// AuthRepository falso (sin Firebase): emite "sin sesión".
///
/// Usa `implements` para no invocar el constructor real (que necesitaría
/// `FirebaseAuth.instance` y, por tanto, `Firebase.initializeApp`).
class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<User?> authState() => Stream<User?>.value(null);

  @override
  User? get currentUser => null;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('Sin sesión, la app arranca en la pantalla de login',
      (WidgetTester tester) async {
    // Override del auth (sin Firebase): el guard del router redirige a /login.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: const TurnosApp(),
      ),
    );
    await tester.pumpAndSettle();

    // La pantalla de login: título, campo de correo y botón "Entrar".
    expect(find.text('Turnos Salón'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
