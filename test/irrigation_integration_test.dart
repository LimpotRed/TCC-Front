import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/auth_service.dart';
import 'package:ghydro/dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Registro de irrigação alimenta os relatórios da fazenda', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final records = <Map<String, dynamic>>[];
    final requests = <String>[];
    final auth = AuthService(
      api: ApiClient(
        client: MockClient((request) async {
          final path = request.url.path;
          requests.add('${request.method} $path');
          Object? response;
          if (path == '/registroIrrigacao' && request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['setorId'], 10);
            expect(body['duracaoMinutos'], 90);
            expect(body.keys.toSet(), {
              'setorId',
              'dataIrrigacao',
              'duracaoMinutos',
            });
            records.add({
              ...body,
              'id': 1,
              'volumeAgua': 30.0,
              'consumoEnergia': 7.5,
            });
            response = records.last;
          } else {
            response = switch (path) {
              '/propriedade' => [
                {'id': 1, 'nome': 'Fazenda Central'},
              ],
              '/setor/propriedade/1' => [
                {'id': 10, 'nome': 'Setor Central', 'plantios': []},
              ],
              '/dispositivoIrrigacao/setor/10' => [
                {
                  'id': 5,
                  'nome': 'Pivô Central',
                  'ativo': true,
                  'vazaoNominal': 20,
                  'potenciaMotor': 5,
                  'setor': {'id': 10},
                },
              ],
              '/configuracaoCusto/propriedade/1' => {
                'moeda': 'BRL',
                'custoM3Agua': 5,
                'custoKWh': 3,
              },
              '/registroIrrigacao/propriedade/1' => records,
              _ => [],
            };
          }
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..token = 'teste',
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
    expect(requests, isNot(contains('GET /dispositivoIrrigacao')));
    await tester.tap(find.text('Gestão'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Controle de irrigação');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Controle de irrigação'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar irrigação'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setor Central').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.ensureVisible(find.text('Salvar registro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar registro'));
    await tester.pumpAndSettle();
    expect(records, hasLength(1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relatórios').last);
    await tester.pumpAndSettle();
    expect(find.text('Irrigações: 1'), findsOneWidget);
    expect(find.text('Duração: 1,50 horas'), findsOneWidget);
    expect(find.text('Volume de água estimado: 30'), findsOneWidget);
    expect(find.text('Energia estimada: 7,50'), findsOneWidget);
    expect(requests, contains('POST /registroIrrigacao'));
    expect(requests, isNot(contains('POST /execucaoManejo')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Resposta tardia de outra fazenda não troca os relatórios', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final oldResponse = Completer<http.Response>();
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/registroIrrigacao/propriedade/1') {
          return oldResponse.future;
        }
        final result = switch (request.url.path) {
          '/propriedade' => [
            {'id': 1, 'nome': 'Fazenda Norte'},
            {'id': 2, 'nome': 'Fazenda Sul'},
          ],
          '/registroIrrigacao/propriedade/2' => [
            {
              'dataIrrigacao': DateTime.now().toIso8601String(),
              'duracaoMinutos': 60,
              'volumeAgua': 22,
              'consumoEnergia': 2,
            },
          ],
          _ => [],
        };
        return http.Response(jsonEncode(result), 200);
      }),
    )..token = 'teste';
    final auth = AuthService(api: api)
      ..profile = {'nome': 'Lucas', 'role': 'PRODUTOR'};
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
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fazenda Sul').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relatórios').last);
    await tester.pumpAndSettle();
    expect(find.text('Volume de água estimado: 22'), findsOneWidget);

    oldResponse.complete(
      http.Response(
        jsonEncode([
          {
            'dataIrrigacao': DateTime.now().toIso8601String(),
            'duracaoMinutos': 120,
            'volumeAgua': 999,
          },
        ]),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Volume de água estimado: 22'), findsOneWidget);
    expect(find.text('Volume de água estimado: 999'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Falha nos relatórios não impede acesso à Home e permite tentar novamente',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var attempts = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/registroIrrigacao/propriedade/1') {
            attempts++;
            return attempts == 1
                ? http.Response('{}', 503)
                : http.Response('[]', 200);
          }
          return http.Response(
            jsonEncode(
              request.url.path == '/propriedade'
                  ? [
                      {'id': 1, 'nome': 'Fazenda Norte'},
                    ]
                  : [],
            ),
            200,
          );
        }),
      )..token = 'teste';
      final auth = AuthService(api: api)
        ..profile = {'nome': 'Lucas', 'role': 'PRODUTOR'};
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
      await tester.tap(find.text('Relatórios').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Não foi possível carregar os registros'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ainda não há irrigações registradas para esta fazenda.'),
        findsOneWidget,
      );
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
