import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/auth_service.dart';
import 'package:ghydro/login_screen.dart';
import 'package:ghydro/dashboard_screen.dart';

class MemoryStore implements AccountStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }
}

void main() {
  test(
    'Contas persistem, rejeitam duplicatas e exigem a senha correta',
    () async {
      final store = MemoryStore();
      final auth = AuthService(store: store, iterations: 10);
      await auth.register(
        name: 'Lucas',
        email: ' Lucas@example.com ',
        password: 'senha12345',
      );
      final reopened = AuthService(store: store, iterations: 10);
      await reopened.signIn(email: 'lucas@example.com', password: 'senha12345');
      await expectLater(
        reopened.signIn(email: 'lucas@example.com', password: 'errada'),
        throwsA(isA<AuthFailure>()),
      );
      await expectLater(
        reopened.signIn(email: 'outro@example.com', password: 'senha12345'),
        throwsA(isA<AuthFailure>()),
      );
      await expectLater(
        auth.register(
          name: 'Lucas',
          email: 'LUCAS@example.com',
          password: 'senha12345',
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(store.data.values.single, isNot(contains('senha12345')));
    },
  );

  testWidgets('Cadastro, confirmação, erro de login e painel de irrigação', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = AuthService(store: MemoryStore(), iterations: 10);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));
    await tester.ensureVisible(find.text('Crie agora'));
    await tester.tap(find.text('Crie agora'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('name')), 'Lucas');
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'lucas@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password')),
      'senha12345',
    );
    await tester.enterText(find.byKey(const ValueKey('confirm')), 'diferente');
    await tester.ensureVisible(find.text('Criar conta'));
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    expect(find.text('As senhas não coincidem.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('confirm')), 'senha12345');
    await tester.ensureVisible(find.text('Criar conta'));
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Conta criada! Entre com seu e-mail e senha.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('email')))
          .controller!
          .text,
      'lucas@example.com',
    );
    await tester.enterText(find.byKey(const ValueKey('password')), 'errada');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('password')),
      'senha12345',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Lucas'), findsOneWidget);
    expect(find.text('Seus pivôs'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(DashboardScreen))).canPop(),
      isFalse,
    );
  });
}
