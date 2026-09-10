import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/dashboard_screen.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('Painel e navegação funcionam na largura $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var loggedOut = false;
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            name: 'Lucas',
            email: 'lucas@example.com',
            onLogout: (_) => loggedOut = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Pivô Leste'));
      await tester.tap(find.text('Pivô Leste'));
      await tester.pumpAndSettle();
      expect(find.text('42 ha'), findsOneWidget);
      Navigator.of(tester.element(find.text('42 ha'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Relatórios').last);
      await tester.pumpAndSettle();
      expect(find.text('Economia dos últimos 6 meses'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('lucas@example.com'), findsOneWidget);
      await tester.ensureVisible(find.text('Sair da conta'));
      await tester.tap(find.text('Sair da conta'));
      expect(loggedOut, isTrue);
    });
  }
}
