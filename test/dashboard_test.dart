import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/auth_service.dart';
import 'package:ghydro/dashboard_screen.dart';
import 'package:ghydro/open_meteo_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final active in [0, 1, 2]) {
    testWidgets('Anel mostra proporção de $active de 2 sensores ativos', (
      tester,
    ) async {
      final auth = AuthService(
        api: ApiClient(
          client: MockClient((request) async {
            final body = switch (request.url.path) {
              '/propriedade' => [
                {'id': 1, 'nome': 'Fazenda'},
              ],
              '/setor/propriedade/1' => [
                {'id': 10, 'nome': 'Setor', 'plantios': []},
              ],
              '/sensor' => [
                for (var i = 0; i < 2; i++)
                  {
                    'status': i < active ? 'ATIVO' : 'INATIVO',
                    'setor': {'id': 10},
                  },
                {
                  'status': 'ATIVO',
                  'setor': {'id': 99},
                },
              ],
              _ => [],
            };
            return http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        )..token = 'sessão-teste',
      )..profile = {'nome': 'Lucas', 'role': 'PRODUTOR'};
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: DashboardScreen(
            auth: auth,
            name: 'Lucas',
            email: 'lucas@example.com',
            onLogout: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final painter = tester
          .widget<CustomPaint>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint &&
                  widget.painter?.runtimeType.toString() == '_ActivityRing',
            ),
          )
          .painter!;
      expect(find.text('de 2 cadastrados'), findsOneWidget);
      void paintRing(Canvas canvas) =>
          painter.paint(canvas, const Size(240, 240));
      expect(paintRing, paintsExactlyCountTimes(#drawArc, active == 0 ? 1 : 2));
      if (active > 0) {
        expect(
          paintRing,
          paints
            ..arc(color: const Color(0xFF393254))
            ..arc(
              startAngle: -math.pi / 2,
              sweepAngle: math.pi * active,
              color: Colors.white,
            ),
        );
      }
      final pixel = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(240, 240));
        final picture = recorder.endRecording();
        final image = await picture.toImage(240, 240);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final offset = (29 * 240 + 122) * 4;
        final rgb = [
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        ];
        image.dispose();
        picture.dispose();
        return rgb;
      });
      if (active == 0) {
        expect(pixel, [0x39, 0x32, 0x54]);
      } else {
        expect(pixel, isNot([0x39, 0x32, 0x54]));
        expect(pixel![1], greaterThan(pixel[0]));
      }
    });
  }

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
              '/estacaoMetereologica/propriedade/1' => {
                'id': 1,
                'nome': 'Estação central',
                'latitude': -16.8,
                'longitude': -50.0,
              },
              '/setor/propriedade/1' => [
                {'id': 10, 'nome': 'Setor Norte', 'plantios': []},
              ],
              '/estacaoMetereologica/propriedade/2' => {
                'id': 2,
                'nome': 'Estação sul',
                'latitude': -23.5,
                'longitude': -46.6,
              },
              '/setor/propriedade/2' => [
                {'id': 20, 'nome': 'Setor Sul', 'plantios': []},
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
    expect(queriedPaths, contains('/setor/propriedade/1'));
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
    expect(queriedPaths, contains('/setor/propriedade/2'));

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

  testWidgets('Atualização automática recupera falha anterior do painel', (
    tester,
  ) async {
    var first = true;
    final auth = AuthService(
      api: ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/propriedade' && first) {
            first = false;
            return http.Response('{}', 500);
          }
          return http.Response(
            jsonEncode(
              request.url.path == '/propriedade'
                  ? [
                      {'id': 1, 'nome': 'Fazenda'},
                    ]
                  : [],
            ),
            200,
          );
        }),
      )..token = 'sessão-teste',
    )..profile = {'nome': 'Lucas', 'role': 'PRODUTOR'};
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: DashboardScreen(
          auth: auth,
          name: 'Lucas',
          email: 'lucas@example.com',
          onLogout: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Visão Geral'), findsNothing);
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(find.text('Visão Geral'), findsOneWidget);
  });

  testWidgets('Atualização troca fazenda removida sem usar setores antigos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final secondFarmSectors = Completer<http.Response>();
    var farmLoads = 0;
    final auth = AuthService(
      api: ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/setor/propriedade/2') {
            return secondFarmSectors.future;
          }
          final result = switch (request.url.path) {
            '/propriedade' =>
              ++farmLoads == 1
                  ? [
                      {'id': 1, 'nome': 'Fazenda A'},
                      {'id': 2, 'nome': 'Fazenda B'},
                    ]
                  : [
                      {'id': 2, 'nome': 'Fazenda B'},
                    ],
            '/setor/propriedade/1' => [
              {'id': 10, 'nome': 'Setor A', 'plantios': []},
            ],
            '/dispositivoIrrigacao' => [
              {
                'id': 7,
                'nome': 'Pivô A',
                'ativo': true,
                'setor': {'id': 10},
              },
              {
                'id': 8,
                'nome': 'Pivô B',
                'ativo': true,
                'setor': {'id': 20},
              },
            ],
            _ => [],
          };
          return http.Response(
            jsonEncode(result),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..token = 'sessão-teste',
    )..profile = {'nome': 'Lucas', 'role': 'PRODUTOR'};
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: DashboardScreen(
          auth: auth,
          name: 'Lucas',
          email: 'lucas@example.com',
          onLogout: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pivô A'), findsNothing);
    expect(find.text('Registrar irrigação'), findsNothing);
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    await tester.pump();
    expect(find.text('Fazenda B'), findsOneWidget);
    expect(find.text('Pivô A'), findsNothing);
    expect(find.text('Registrar irrigação'), findsNothing);
    secondFarmSectors.complete(
      http.Response(
        jsonEncode([
          {'id': 20, 'nome': 'Setor B', 'plantios': []},
        ]),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pivô B'), findsNothing);
    expect(find.text('Registrar irrigação'), findsNothing);
  });

  testWidgets(
    'Controle de irrigação fica na Gestão e recupera erro de setores',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var farmRequests = 0;
      var southSectorRequests = 0;
      final auth = AuthService(
        api: ApiClient(
          client: MockClient((request) async {
            final path = request.url.path;
            if (path == '/propriedade') farmRequests++;
            if (path == '/setor/propriedade/2' && ++southSectorRequests == 2) {
              return http.Response(
                '{"message":"Erro ao consultar setores"}',
                503,
              );
            }
            final Object? body = switch (path) {
              '/propriedade' => [
                {'id': 1, 'nome': 'Fazenda Norte'},
                {'id': 2, 'nome': 'Fazenda Sul'},
              ],
              '/setor/propriedade/1' => [
                {'id': 10, 'nome': 'Setor Norte', 'plantios': []},
              ],
              '/setor/propriedade/2' => [
                {'id': 20, 'nome': 'Setor Sul', 'plantios': []},
              ],
              '/configuracaoCusto/propriedade/2' => null,
              _ => [],
            };
            return http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        )..token = 'sessão-teste',
      )..profile = {'nome': 'Lucas', 'role': 'PRODUTOR'};

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: DashboardScreen(
            auth: auth,
            name: 'Lucas',
            email: 'lucas@example.com',
            onLogout: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Registrar irrigação'), findsNothing);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fazenda Sul').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gestão'));
      await tester.pumpAndSettle();
      expect(find.text('Pivôs e irrigação'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Controle de irrigação');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Controle de irrigação'));
      await tester.pumpAndSettle();

      expect(farmRequests, greaterThanOrEqualTo(2));
      expect(southSectorRequests, 2);
      expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
      expect(find.text('Buscar registros'), findsNothing);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(southSectorRequests, 3);
      expect(find.text('Fazenda Sul'), findsOneWidget);
      final register = find.widgetWithText(FilledButton, 'Registrar irrigação');
      expect(tester.widget<FilledButton>(register).onPressed, isNotNull);
      await tester.tap(register);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Setor Sul'), findsOneWidget);
      expect(find.text('Setor Norte'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Relatórios e sensores usam somente a fazenda selecionada', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paths = <String>[];
    final end = DateTime.now().subtract(const Duration(minutes: 10));
    final start = end.subtract(const Duration(hours: 3));
    final auth = AuthService(
      api: ApiClient(
        client: MockClient((request) async {
          paths.add(request.url.path);
          final body = switch (request.url.path) {
            '/propriedade' => [
              {'id': 1, 'nome': 'Fazenda Norte'},
              {'id': 2, 'nome': 'Fazenda Sul'},
            ],
            '/setor/propriedade/1' => [
              {
                'id': 10,
                'nome': 'Setor Norte',
                'plantios': [
                  {'id': 100, 'statusPlantio': 'EM_ANDAMENTO'},
                ],
              },
            ],
            '/setor/propriedade/2' => [
              {
                'id': 20,
                'nome': 'Setor Sul',
                'plantios': [
                  {'id': 200, 'statusPlantio': 'EM_ANDAMENTO'},
                ],
              },
            ],
            '/dispositivoIrrigacao' => [
              {
                'id': 7,
                'nome': 'Pivô Norte',
                'ativo': true,
                'setor': {'id': 10},
              },
              {
                'id': 8,
                'nome': 'Pivô Sul',
                'ativo': true,
                'setor': {'id': 20},
              },
            ],
            '/sensor' => [
              {
                'status': 'ATIVO',
                'setor': {'id': 10},
              },
              {
                'status': 'ATIVO',
                'setor': {'id': 20},
              },
              {
                'status': 'ATIVO',
                'setor': {'id': 20},
              },
            ],
            '/registroIrrigacao/propriedade/1' => [
              {
                'dataIrrigacao': start.toIso8601String(),
                'duracaoMinutos': 180,
                'volumeAgua': 12,
              },
            ],
            '/registroIrrigacao/propriedade/2' => [
              {
                'dataIrrigacao': start.toIso8601String(),
                'duracaoMinutos': 180,
                'volumeAgua': 999,
                'consumoEnergia': 20,
              },
            ],
            _ => [],
          };
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..token = 'sessão-teste',
    )..profile = {'nome': 'Lucas', 'role': 'PRODUTOR'};
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: DashboardScreen(
          auth: auth,
          name: 'Lucas',
          email: 'lucas@example.com',
          onLogout: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Visão Geral'), findsOneWidget);
    expect(find.text('Registrar irrigação'), findsNothing);
    expect(find.text('Pivô Norte'), findsNothing);
    expect(find.text('Pivô Sul'), findsNothing);
    expect(paths, isNot(contains('/dispositivoIrrigacao')));
    expect(paths, isNot(contains('/execucaoManejo')));
    final sensorLabel = find.text('Sensores ativos').last;
    expect(
      find.ancestor(of: sensorLabel, matching: find.byType(Card)).first,
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(of: sensorLabel, matching: find.byType(Card)).first,
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Relatórios').last);
    await tester.pumpAndSettle();
    expect(find.text('Irrigações: 1'), findsOneWidget);
    expect(find.text('Duração: 3 horas'), findsOneWidget);
    expect(find.text('Volume de água estimado: 12'), findsOneWidget);
    expect(find.text('Energia estimada: Não informado'), findsOneWidget);
    expect(find.text('999'), findsNothing);
    final callsBefore = paths
        .where((path) => path == '/registroIrrigacao/propriedade/1')
        .length;
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(
      paths.where((path) => path == '/registroIrrigacao/propriedade/1').length,
      greaterThan(callsBefore),
    );

    await tester.tap(find.text('Início'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fazenda Sul').last);
    await tester.pumpAndSettle();
    expect(find.text('Pivô Sul'), findsNothing);
    expect(find.text('Pivô Norte'), findsNothing);
    expect(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Sensores ativos').last,
              matching: find.byType(Card),
            )
            .first,
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Relatórios').last);
    await tester.pumpAndSettle();
    expect(find.text('Irrigações: 1'), findsOneWidget);
    expect(find.text('Volume de água estimado: 999'), findsOneWidget);
    expect(find.text('Energia estimada: 20'), findsOneWidget);
    expect(find.text('Volume de água estimado: 12'), findsNothing);
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
                r.url.path == '/propriedade'
                    ? [
                        {'id': 1, 'nome': 'Fazenda central'},
                      ]
                    : r.url.path == '/setor/propriedade/1'
                    ? [
                        {'id': 10, 'nome': 'Leste', 'plantios': []},
                        {'id': 20, 'nome': 'Sul', 'plantios': []},
                      ]
                    : r.url.path == '/dispositivoIrrigacao'
                    ? [
                        {
                          'id': 7,
                          'nome': 'Pivô Leste',
                          'ativo': true,
                          'tipoDispositivo': 'PIVO',
                          'eficienciaIrrigacao': 85,
                          'setor': {'id': 10, 'nome': 'Leste'},
                        },
                        {
                          'id': 8,
                          'nome': 'Pivô Sul',
                          'ativo': true,
                          'tipoDispositivo': 'PIVO',
                          'eficienciaIrrigacao': 92,
                          'setor': {'id': 20, 'nome': 'Sul'},
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
      expect(find.text('Seus pivôs e dispositivos'), findsNothing);
      expect(find.text('Pivô Leste'), findsNothing);
      expect(find.text('Pivô Sul'), findsNothing);
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
      expect(find.text('Volume de água estimado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('lucas@example.com'), findsOneWidget);
      await tester.ensureVisible(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair da conta'));
      expect(loggedOut, isTrue);
    });
  }
}
