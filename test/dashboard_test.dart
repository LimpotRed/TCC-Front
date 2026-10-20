import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/auth_service.dart';
import 'package:ghydro/dashboard_screen.dart';
import 'package:ghydro/open_meteo_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Fazenda escolhida permanece ao trocar aba e atualizar painel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final queriedLatitudes = <String>[];
    final queriedPaths = <String>[];
    final auth = AuthService(
      api: ApiClient(
        client: MockClient((request) async {
          queriedPaths.add(request.url.path);
          return http.Response(
            jsonEncode(switch (request.url.path) {
              '/propriedade' => [
                {'id': 1, 'nome': 'Fazenda central'},
                {'id': 2, 'nome': 'Fazenda sul'},
              ],
              '/propriedade/1/estacoes' => [
                {
                  'id': 1,
                  'nome': 'Estação central',
                  'latitude': -16.8,
                  'longitude': -50.0,
                },
              ],
              '/propriedade/1/safras/setores' => [
                {
                  'id': 10,
                  'nome': 'Setor Norte',
                  'status': 'EM_DESCANSO',
                  'plantioAtivo': null,
                },
              ],
              '/propriedade/2/estacoes' => [
                {
                  'id': 2,
                  'nome': 'Estação sul',
                  'latitude': -23.5,
                  'longitude': -46.6,
                },
              ],
              '/propriedade/2/safras/setores' => [
                {
                  'id': 20,
                  'nome': 'Setor Sul',
                  'status': 'EM_DESCANSO',
                  'plantioAtivo': null,
                },
              ],
              _ => [],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..token = 'sessão-teste',
    )..profile = {'nome': 'Lucas', 'role': 'PRODUTOR'};
    final weatherService = OpenMeteoService(
      client: MockClient((request) async {
        queriedLatitudes.add(request.url.queryParameters['latitude']!);
        return http.Response(
          jsonEncode({
            'current': {'time': '2026-10-01T19:45', 'temperature_2m': 28.9},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: DashboardScreen(
          auth: auth,
          name: 'Lucas',
          email: 'lucas@example.com',
          onLogout: (_) {},
          weatherService: weatherService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clima da fazenda'), findsNothing);
    expect(queriedLatitudes, isEmpty);
    expect(queriedPaths.where((p) => p.endsWith('/estacoes')), isEmpty);
    expect(queriedPaths, contains('/propriedade/1/safras/setores'));
    expect(queriedPaths, isNot(contains('/plantio')));
    expect(queriedPaths.where((p) => p.endsWith('/indicadores')), isEmpty);

    await tester.tap(find.text('Gestão'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Leituras climáticas');
    await tester.pumpAndSettle();
    expect(find.text('CLIMA'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Leituras climáticas'));
    await tester.pumpAndSettle();
    expect(find.text('Clima da fazenda'), findsOneWidget);
    expect(find.text('Buscar registros'), findsNothing);
    expect(find.textContaining('Leitura climática #'), findsNothing);
    expect(queriedPaths, isNot(contains('/leituraClimatica')));
    expect(queriedLatitudes, ['-16.8']);
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is DropdownButtonFormField),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fazenda sul').last);
    await tester.pumpAndSettle();
    expect(queriedLatitudes.last, '-23.5');
    expect(queriedPaths, contains('/propriedade/2/safras/setores'));

    await tester.tap(find.byTooltip('Atualizar clima'));
    await tester.pumpAndSettle();
    expect(queriedLatitudes, ['-16.8', '-23.5', '-23.5']);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Clima da fazenda'), findsNothing);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Início'));
    await tester.pumpAndSettle();
    expect(find.text('Clima da fazenda'), findsNothing);
    expect(queriedLatitudes.last, '-23.5');
    expect(queriedLatitudes.length, 3);
    await tester.tap(find.byTooltip('Atualizar painel'));
    await tester.pumpAndSettle();
    expect(queriedLatitudes.last, '-23.5');
    expect(queriedLatitudes.length, 3);
    await tester.tap(find.text('Gestão'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Leituras climáticas'));
    await tester.pumpAndSettle();
    expect(find.text('Clima da fazenda'), findsOneWidget);
    expect(queriedLatitudes.last, '-23.5');
    expect(queriedLatitudes.length, 4);
    expect(queriedPaths, isNot(contains('/leituraClimatica')));
    expect(tester.takeException(), isNull);
  });

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
      expect(find.text('Clima da fazenda'), findsNothing);
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
      await tester.enterText(find.byType(TextField), 'Leituras climáticas');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Leituras climáticas'));
      await tester.pumpAndSettle();
      expect(find.text('Clima da fazenda'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
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
