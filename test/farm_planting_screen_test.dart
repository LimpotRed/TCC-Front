import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/farm_planting_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets('Resposta tardia de outra fazenda não troca os setores', (
    tester,
  ) async {
    final oldResponse = Completer<http.Response>();
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/propriedade/1/safras/setores') {
          return oldResponse.future;
        }
        return _json([
          {
            'id': 20,
            'nome': 'Setor autorizado',
            'status': 'EM_DESCANSO',
            'plantioAtivo': null,
          },
        ]);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: FarmPlantingScreen(
          api: api,
          farms: const [
            {'id': 1, 'nome': 'Fazenda antiga'},
            {'id': 2, 'nome': 'Fazenda atual'},
          ],
          selectedFarmId: '1',
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fazenda atual').last);
    await tester.pumpAndSettle();
    expect(find.text('Setor autorizado'), findsOneWidget);
    oldResponse.complete(
      _json([
        {
          'id': 10,
          'nome': 'Setor antigo',
          'status': 'EM_DESCANSO',
          'plantioAtivo': null,
        },
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Setor antigo'), findsNothing);
    expect(find.text('Setor autorizado'), findsOneWidget);
  });

  testWidgets('Mostra somente setores da fazenda selecionada em 320 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final paths = <String>[];
    String? selection;
    final api = ApiClient(
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.headers['Authorization'], 'Bearer token-teste');
        if (request.url.path == '/propriedade/1/safras/setores') {
          return _json([
            {
              'id': 10,
              'nome': 'Setor Norte',
              'status': 'EM_DESCANSO',
              'plantioAtivo': null,
            },
          ]);
        }
        if (request.url.path == '/propriedade/2/safras/setores') {
          return _json([
            {
              'id': 20,
              'nome': 'Setor Sul',
              'status': 'EM_DESCANSO',
              'plantioAtivo': null,
            },
          ]);
        }
        fail('Rota inesperada: ${request.url.path}');
      }),
    )..token = 'token-teste';

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: FarmPlantingScreen(
          api: api,
          farms: const [
            {'id': 1, 'nome': 'Fazenda Norte'},
            {'id': 2, 'nome': 'Fazenda Sul'},
          ],
          selectedFarmId: '1',
          onFarmChanged: (id) => selection = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Setor Norte'), findsOneWidget);
    expect(find.text('Setor Sul'), findsNothing);
    expect(find.text('Cadastrar plantação'), findsOneWidget);
    expect(find.text('Ver histórico produtivo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fazenda Sul').last);
    await tester.pumpAndSettle();
    expect(selection, '2');
    expect(find.text('Setor Norte'), findsNothing);
    expect(find.text('Setor Sul'), findsOneWidget);
    expect(paths, [
      '/propriedade/1/safras/setores',
      '/propriedade/2/safras/setores',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cadastra plantio, registra colheita e preserva histórico', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? active;
    Map<String, dynamic>? completed;
    Map<String, dynamic>? plantingPayload;
    Map<String, dynamic>? harvestPayload;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/propriedade/1/safras/setores' &&
            request.method == 'GET') {
          return _json([
            {
              'id': 10,
              'nome': 'Setor Central',
              'status': active == null ? 'EM_DESCANSO' : 'SAFRA_ATIVA',
              'plantioAtivo': active,
            },
          ]);
        }
        if (request.url.path == '/cultura' && request.method == 'GET') {
          return _json([
            {'id': 7, 'nomePopular': 'Milho'},
          ]);
        }
        if (request.url.path == '/propriedade/1/safras/setores/10/plantios' &&
            request.method == 'POST') {
          plantingPayload = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          active = {
            'id': 30,
            'setorId': 10,
            'setorNome': 'Setor Central',
            'culturaId': 7,
            'culturaNome': 'Milho',
            'dataPlantio': plantingPayload!['dataPlantio'],
            'dataColheitaEstimada': null,
            'statusPlantio': 'EM_ANDAMENTO',
          };
          return _json(active!, 201);
        }
        if (request.url.path ==
                '/propriedade/1/safras/setores/10/plantios/30/colheita' &&
            request.method == 'POST') {
          harvestPayload = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          completed = {
            ...active!,
            'statusPlantio': 'CONCLUIDO',
            ...harvestPayload!,
          };
          active = null;
          return _json(completed!, 201);
        }
        if (request.url.path == '/propriedade/1/safras/setores/10/historico' &&
            request.method == 'GET') {
          return _json([if (completed != null) completed!]);
        }
        fail('Rota inesperada: ${request.method} ${request.url.path}');
      }),
    )..token = 'token-teste';

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: FarmPlantingScreen(
          api: api,
          farms: const [
            {'id': 1, 'nome': 'Fazenda Central'},
          ],
          selectedFarmId: '1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cadastrar plantação'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milho').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar plantio'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(plantingPayload!['culturaId'], 7);
    expect(plantingPayload!['dataPlantio'], matches(r'^\d{4}-\d{2}-\d{2}$'));
    expect(find.text('Registrar colheita'), findsOneWidget);

    await tester.tap(find.text('Registrar colheita'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Quantidade produzida'), findsNothing);
    expect(find.text('Unidade de medida'), findsNothing);
    expect(find.textContaining('Data da colheita:'), findsOneWidget);
    await tester.tap(find.text('Confirmar colheita'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(harvestPayload!.keys, ['dataColheita']);
    expect(harvestPayload!['dataColheita'], matches(r'^\d{4}-\d{2}-\d{2}$'));
    expect(find.text('Cadastrar plantação'), findsOneWidget);

    await tester.tap(find.text('Ver histórico produtivo'));
    await tester.pumpAndSettle();
    expect(find.text('Total de plantios: 1'), findsOneWidget);
    expect(find.textContaining('Colheita real:'), findsOneWidget);
    expect(find.textContaining('Produção:'), findsNothing);
    expect(find.text('Concluído'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Permite tentar novamente carregar culturas sem fechar o formulário',
    (tester) async {
      var cultureRequests = 0;
      Map<String, dynamic>? plantingPayload;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/propriedade/1/safras/setores') {
            return _json([
              {
                'id': 10,
                'nome': 'Setor Central',
                'status': 'EM_DESCANSO',
                'plantioAtivo': null,
              },
            ]);
          }
          if (request.url.path == '/cultura') {
            cultureRequests++;
            return cultureRequests == 1
                ? _json({'message': 'Falha ao carregar culturas.'}, 503)
                : _json([
                    {'id': 7, 'nomePopular': 'Milho'},
                  ]);
          }
          if (request.url.path == '/propriedade/1/safras/setores/10/plantios' &&
              request.method == 'POST') {
            plantingPayload = Map<String, dynamic>.from(
              jsonDecode(request.body) as Map,
            );
            return _json({'id': 30}, 201);
          }
          fail('Rota inesperada: ${request.method} ${request.url.path}');
        }),
      )..token = 'token-teste';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: FarmPlantingScreen(
            api: api,
            farms: const [
              {'id': 1, 'nome': 'Fazenda Central'},
            ],
            selectedFarmId: '1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cadastrar plantação'));
      await tester.pumpAndSettle();
      expect(find.text('Falha ao carregar culturas.'), findsOneWidget);
      expect(find.textContaining('Data do plantio:'), findsOneWidget);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(cultureRequests, 2);
      expect(find.textContaining('Data do plantio:'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Milho').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar plantio'));
      await tester.pumpAndSettle();
      expect(plantingPayload?['culturaId'], 7);
      expect(tester.takeException(), isNull);
    },
  );
}
