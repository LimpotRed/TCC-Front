import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/auth_service.dart';
import 'package:ghydro/dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('Painel conectado e navegação na largura $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var loggedOut = false;
      final auth = AuthService(
        api: ApiClient(
          client: MockClient(
            (r) async => http.Response(
              jsonEncode(
                r.url.path == '/dispositivoIrrigacao'
                    ? [
                        {
                          'id': 7,
                          'nome': 'Pivô Leste',
                          'tipoDispositivo': 'PIVO',
                          'eficienciaIrrigacao': 85,
                          'setor': {'nome': 'Leste'},
                        },
                        {
                          'id': 8,
                          'nome': 'Pivô Sul',
                          'tipoDispositivo': 'PIVO',
                          'eficienciaIrrigacao': 92,
                          'setor': {'nome': 'Sul'},
                        },
                      ]
                    : [],
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
      )..profile = {'nome': 'Lucas', 'role': 'PRODUTOR'};
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: DashboardScreen(
            auth: auth,
            name: 'Lucas',
            email: 'lucas@example.com',
            onLogout: (_) => loggedOut = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Pivô Leste'));
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      final leftDevice = tester.getRect(find.text('Pivô Leste'));
      final rightDevice = tester.getRect(find.text('Pivô Sul'));
      expect((leftDevice.top - rightDevice.top).abs(), lessThan(1));
      expect(rightDevice.left, greaterThan(leftDevice.left));
      if (width == 320) {
        await tester.ensureVisible(find.text('Setores'));
        await tester.pumpAndSettle();
        final properties = tester.getRect(find.text('Propriedades'));
        final sectors = tester.getRect(find.text('Setores'));
        final crops = tester.getRect(find.text('Plantios em andamento'));
        expect((properties.top - sectors.top).abs(), lessThan(1));
        expect(sectors.left, greaterThan(properties.left));
        expect(crops.top, greaterThan(properties.bottom));
      }
      expect(find.text('R\$ 5.643,50'), findsNothing);
      await tester.tap(find.text('Gestão'));
      await tester.pumpAndSettle();
      expect(find.text('Gestão da fazenda'), findsOneWidget);
      expect(find.text('Manutenções'), findsNothing);
      await tester.tap(find.text('Relatórios').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Volume de água registrado nos últimos 6 meses'),
        findsOneWidget,
      );
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
