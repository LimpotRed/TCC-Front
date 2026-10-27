import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/farm_planting_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Cartão anterior mostra safra atual e histórico em celular', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'id': 1,
              'nome': 'Setor Norte',
              'plantios': [
                {
                  'id': 1,
                  'cultura': {'id': 1, 'nomePopular': 'Milho'},
                  'statusPlantio': 'EM_ANDAMENTO',
                  'dataPlantio': '2026-01-01',
                },
                {
                  'id': 2,
                  'cultura': {'id': 2, 'nomePopular': 'Soja'},
                  'statusPlantio': 'CONCLUIDO',
                  'dataPlantio': '2025-01-01',
                  'dataColheitaReal': '2025-05-01',
                },
              ],
            },
          ]),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FarmPlantingScreen(
          api: api,
          farms: const [
            {'id': 9, 'nome': 'Fazenda'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gestão de safras e plantios'), findsOneWidget);
    expect(find.text('SAFRA ATUAL'), findsOneWidget);
    expect(find.text('Safra ativa'), findsOneWidget);
    expect(find.text('Milho'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver histórico produtivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver histórico produtivo'));
    await tester.pumpAndSettle();
    expect(find.text('Soja'), findsOneWidget);
    expect(find.textContaining('01/05/2025'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Consulta setores e seus plantios na rota atual em 320 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paths = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'nome': 'Setor Norte',
              'plantios': [
                {
                  'id': 3,
                  'cultura': {'nomePopular': 'Milho'},
                  'statusPlantio': 'EM_ANDAMENTO',
                  'dataPlantio': '2026-01-01',
                },
              ],
            },
          ]),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FarmPlantingScreen(
          api: api,
          farms: const [
            {'id': 9, 'nome': 'Fazenda'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(paths, ['/setor/propriedade/9']);
    expect(find.text('Setor Norte'), findsOneWidget);
    expect(find.text('Milho'), findsOneWidget);
    expect(find.text('Cadastrar plantação'), findsNothing);
    expect(find.text('Registrar colheita'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Equipe registra colheita com PUT e preserva os vínculos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? payload;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'PUT' && request.url.path == '/plantio/3') {
          payload = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          return http.Response('{}', 200);
        }
        if (request.url.path == '/setor/propriedade/9') {
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'nome': 'Setor Norte',
                'plantios': [
                  {
                    'id': 3,
                    'cultura': {'id': 7, 'nomePopular': 'Milho'},
                    'statusPlantio': 'EM_ANDAMENTO',
                    'dataPlantio': '2020-01-01',
                    'dataColheitaEstimada': '2020-06-01',
                  },
                ],
              },
            ]),
            200,
          );
        }
        fail('Requisição inesperada: ${request.method} ${request.url.path}');
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FarmPlantingScreen(
          api: api,
          canManagePlantings: true,
          farms: const [
            {'id': 9, 'nome': 'Fazenda'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar plantação'), findsNothing);
    expect(
      find.text('Este setor já possui uma safra não concluída.'),
      findsOneWidget,
    );
    expect(find.text('Editar plantio'), findsNothing);
    expect(find.text('Excluir plantio'), findsNothing);
    final harvestButton = find.widgetWithText(
      FilledButton,
      'Registrar colheita',
    );
    final button = tester.widget<FilledButton>(harvestButton);
    expect(
      tester.getSize(harvestButton).width,
      tester.getSize(find.text('Plantio: 01/01/2020')).width,
    );
    expect(tester.getSize(harvestButton).height, greaterThanOrEqualTo(48));
    expect(
      button.style!.backgroundColor!.resolve({}),
      Theme.of(tester.element(harvestButton)).colorScheme.primary,
    );
    expect(button.style!.foregroundColor!.resolve({}), const Color(0xFF1B1938));
    await tester.tap(find.text('Registrar colheita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(payload?['setor'], {'id': 1});
    expect(payload?['cultura'], {'id': 7});
    expect(payload?['dataColheitaEstimada'], '2020-06-01');
    expect(payload?['dataColheitaReal'], isNotNull);
    expect(payload?['statusPlantio'], 'CONCLUIDO');
  });

  testWidgets('Equipe cadastra plantio e pode limpar previsão no celular', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? payload;
    var sectorRequests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/setor/propriedade/9') {
          sectorRequests++;
          return http.Response(
            jsonEncode([
              {'id': 1, 'nome': 'Setor Norte', 'plantios': []},
            ]),
            200,
          );
        }
        if (request.method == 'GET' && request.url.path == '/cultura') {
          return http.Response(
            jsonEncode([
              {'id': 7, 'nomePopular': 'Milho'},
            ]),
            200,
          );
        }
        if (request.method == 'POST' && request.url.path == '/plantio') {
          payload = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          return http.Response('{}', 201);
        }
        fail('Requisição inesperada: ${request.method} ${request.url.path}');
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FarmPlantingScreen(
          api: api,
          canManagePlantings: true,
          farms: const [
            {'id': 9, 'nome': 'Fazenda'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cadastrar plantação'));
    await tester.pumpAndSettle();
    expect(find.text('Situação'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milho').last);
    await tester.pumpAndSettle();
    expect(find.text('Data de plantio'), findsOneWidget);
    final estimated = find.text('Previsão de colheita (opcional)');
    await tester.ensureVisible(estimated);
    await tester.pumpAndSettle();
    await tester.tap(estimated);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Limpar previsão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar previsão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(payload?['setor'], {'id': 1});
    expect(payload?['cultura'], {'id': 7});
    expect(payload?['statusPlantio'], 'EM_ANDAMENTO');
    expect(payload?['dataPlantio'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(payload?['dataColheitaEstimada'], isNull);
    expect(payload?['dataColheitaReal'], isNull);
    expect(sectorRequests, 3);
    expect(tester.takeException(), isNull);
  });

  for (final status in ['EM_ANDAMENTO', 'PLANEJADO']) {
    testWidgets('Setor com safra $status não permite novo cadastro', (
      tester,
    ) async {
      final api = ApiClient(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode([
              {
                'id': 1,
                'nome': 'Setor Norte',
                'plantios': [
                  {
                    'id': 3,
                    'statusPlantio': status,
                    'cultura': {'nomePopular': 'Milho'},
                  },
                ],
              },
            ]),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FarmPlantingScreen(
            api: api,
            canManagePlantings: true,
            farms: const [
              {'id': 9, 'nome': 'Fazenda'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cadastrar plantação'), findsNothing);
      expect(
        find.text('Este setor já possui uma safra não concluída.'),
        findsOneWidget,
      );
    });
  }

  testWidgets('Colheita concluída libera novo cadastro e mantém histórico', (
    tester,
  ) async {
    var harvested = false;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          expect(jsonDecode(request.body)['statusPlantio'], 'CONCLUIDO');
          harvested = true;
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'nome': 'Setor Norte',
              'plantios': [
                {
                  'id': 3,
                  'cultura': {'id': 7, 'nomePopular': 'Milho'},
                  'statusPlantio': harvested ? 'CONCLUIDO' : 'EM_ANDAMENTO',
                  'dataPlantio': '2020-01-01',
                },
              ],
            },
          ]),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FarmPlantingScreen(
          api: api,
          canManagePlantings: true,
          farms: const [
            {'id': 9, 'nome': 'Fazenda'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar plantação'), findsNothing);
    await tester.tap(find.text('Registrar colheita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar plantação'), findsOneWidget);
    await tester.tap(find.text('Ver histórico produtivo'));
    await tester.pumpAndSettle();
    expect(find.text('Milho'), findsOneWidget);
  });

  testWidgets('Não cadastra se o setor foi ocupado com formulário aberto', (
    tester,
  ) async {
    var checks = 0;
    var posted = false;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/cultura') {
          return http.Response(
            jsonEncode([
              {'id': 7, 'nomePopular': 'Milho'},
            ]),
            200,
          );
        }
        if (request.method == 'POST') {
          posted = true;
          return http.Response('{}', 201);
        }
        checks++;
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'nome': 'Setor Norte',
              'plantios': checks == 1
                  ? []
                  : [
                      {'id': 3, 'statusPlantio': 'EM_ANDAMENTO'},
                    ],
            },
          ]),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FarmPlantingScreen(
          api: api,
          canManagePlantings: true,
          farms: const [
            {'id': 9, 'nome': 'Fazenda'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cadastrar plantação'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milho').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(posted, isFalse);
    expect(
      find.textContaining('Este setor já possui uma safra não concluída.'),
      findsOneWidget,
    );
  });
}
