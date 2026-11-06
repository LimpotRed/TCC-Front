import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/app_theme.dart';
import 'package:ghydro/auth_service.dart';
import 'package:ghydro/dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('Troca o tema no início e mantém a navegação em $width px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = ValueNotifier(ThemeMode.dark);
      addTearDown(controller.dispose);
      final api = ApiClient(
        client: MockClient((request) async {
          final body = switch (request.url.path) {
            '/propriedade' => [
              {'id': 1, 'nome': 'Fazenda'},
            ],
            '/setor/propriedade/1' => [
              {'id': 10, 'nome': 'Setor', 'plantios': []},
            ],
            _ => [],
          };
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..token = 'sessão-teste';
      final auth = AuthService(api: api)
        ..profile = {'nome': 'Lucas', 'role': 'PRODUTOR'};
      await tester.pumpWidget(
        AppThemeScope(
          controller: controller,
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: controller,
            builder: (context, mode, _) => MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: mode,
              home: DashboardScreen(
                auth: auth,
                name: 'Lucas',
                email: 'lucas@example.com',
                onLogout: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Início').first)).brightness,
        Brightness.dark,
      );
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_rounded), findsNothing);
      await tester.tap(find.byTooltip('Ativar modo claro'));
      await tester.pumpAndSettle();
      expect(controller.value, ThemeMode.light);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);
      expect(
        Theme.of(tester.element(find.byTooltip('Ativar modo escuro')))
            .brightness,
        Brightness.light,
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFFF3F7F8));
      expect(find.text('MONITORAMENTO DE SENSORES'), findsOneWidget);
      await tester.tap(find.text('Gestão').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Proprietários');
      await tester.tap(find.widgetWithText(ListTile, 'Proprietários'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Proprietários').first)).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Início').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ativar modo escuro'));
      await tester.pumpAndSettle();
      expect(controller.value, ThemeMode.dark);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    });
  }
}
