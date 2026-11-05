import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/irrigation_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object? data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _farm = {'id': 1, 'nome': 'Fazenda Boa Vista'};
const _sectors = <Map<String, dynamic>>[
  {
    'id': 10,
    'nome': 'Setor Central',
    'propriedade': {'id': 1},
    'plantios': [
      {'id': 30, 'statusPlantio': 'EM_ANDAMENTO'},
    ],
  },
  {
    'id': 11,
    'nome': 'Setor Norte',
    'propriedade': {'id': 1},
    'plantios': [
      {'id': 31, 'statusPlantio': 'EM_ANDAMENTO'},
    ],
  },
];

Future<void> _open(
  WidgetTester tester,
  ApiClient api, {
  List<Map<String, dynamic>> sectors = _sectors,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<bool>(
                builder: (_) =>
                    IrrigationScreen(api: api, farm: _farm, sectors: sectors),
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String name) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text(name).last);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  testWidgets('Registra duração pelo setor no contrato de irrigação', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? payload;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/configuracaoCusto/propriedade/1') {
          return _json({'moeda': 'BRL', 'custoM3Agua': 5.0, 'custoKWh': 3.0});
        }
        if (request.url.path == '/dispositivoIrrigacao/setor/10') {
          return _json([
            {
              'id': 8,
              'nome': 'Pivô Central',
              'ativo': true,
              'vazaoNominal': 20.0,
              'potenciaMotor': 5.0,
              'setor': {'id': 10},
            },
          ]);
        }
        if (request.url.path == '/registroIrrigacao') {
          expect(request.method, 'POST');
          payload = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({'id': 90});
        }
        fail('Rota inesperada: ${request.url.path}');
      }),
    )..token = 'teste';

    await _open(
      tester,
      api,
      sectors: [
        {..._sectors.first, 'plantios': []},
      ],
    );
    await _choose(tester, 'Setor Central');
    expect(
      find.textContaining('Dispositivo ativo: Pivô Central'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.scrollUntilVisible(
      find.text('Salvar registro'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Água estimada: Não informado'), findsOneWidget);
    await tester.ensureVisible(find.text('Salvar registro'));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar registro'));
    await tester.pumpAndSettle();

    expect(payload, isNotNull);
    expect(payload!.keys.toSet(), {
      'setorId',
      'dataIrrigacao',
      'duracaoMinutos',
    });
    expect(payload!['setorId'], 10);
    expect(payload!['duracaoMinutos'], 90);
    final start = DateTime.parse(payload!['dataIrrigacao'] as String);
    expect(DateTime.now().difference(start).inSeconds, closeTo(90 * 60, 10));
    expect(payload!['dataIrrigacao'], isNot(contains('Z')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Estima consumo somente após confirmação explícita das unidades',
    (tester) async {
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/configuracaoCusto/propriedade/1') {
            return _json({
              'moeda': 'BRL',
              'custoM3Agua': 5.0,
              'custoKWh': 3.0,
              'propriedade': {'id': 1},
            });
          }
          if (request.url.path == '/dispositivoIrrigacao/setor/10') {
            return _json([
              {
                'id': 8,
                'nome': 'Pivô',
                'ativo': true,
                'vazaoNominal': 20.0,
                'potenciaMotor': 5.0,
              },
            ]);
          }
          fail('Rota inesperada: ${request.url.path}');
        }),
      );
      await _open(tester, api);
      await _choose(tester, 'Setor Central');
      await tester.enterText(find.byType(TextField).at(0), '3');
      await tester.enterText(find.byType(TextField).at(1), '30');
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('Água estimada:'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.textContaining('Água estimada: 70,00 m³'), findsOneWidget);
      expect(
        find.textContaining('Energia estimada: 17,50 kWh'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Custo total estimado: R\$ 402,50'),
        findsOneWidget,
      );
      expect(
        find.textContaining('servidor recalcula e registra os valores'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Impede registro sem dispositivo e não exige plantio', (
    tester,
  ) async {
    var posts = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/configuracaoCusto/propriedade/1') {
          return _json(null);
        }
        if (request.url.path == '/dispositivoIrrigacao/setor/10') {
          return _json([]);
        }
        if (request.url.path == '/dispositivoIrrigacao/setor/11') {
          return _json([
            {
              'id': 9,
              'nome': 'Pivô Norte',
              'ativo': true,
              'setor': {'id': 11},
            },
          ]);
        }
        if (request.method == 'POST') posts++;
        return _json({});
      }),
    );
    await _open(
      tester,
      api,
      sectors: [
        _sectors.first,
        {
          ..._sectors.last,
          'plantios': [
            {'id': 31, 'statusPlantio': 'EM_ANDAMENTO'},
            {'id': 32, 'statusPlantio': 'EM_ANDAMENTO'},
          ],
        },
      ],
    );
    await _choose(tester, 'Setor Central');
    expect(find.textContaining('Nenhum dispositivo ativo'), findsOneWidget);
    await _choose(tester, 'Setor Norte');
    expect(find.textContaining('plantio em andamento'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Salvar registro'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Salvar registro'));
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Salvar registro'),
    );
    expect(button.onPressed, isNotNull);
    expect(posts, 0);
  });

  testWidgets('Prévia não apresenta vazão zero como consumo válido', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/configuracaoCusto/propriedade/1') {
          return _json({'moeda': 'BRL', 'custoM3Agua': 5, 'custoKWh': 3});
        }
        if (request.url.path == '/dispositivoIrrigacao/setor/10') {
          return _json([
            {
              'id': 8,
              'nome': 'Pivô',
              'ativo': true,
              'vazaoNominal': 0,
              'potenciaMotor': 5,
            },
          ]);
        }
        fail('Rota inesperada: ${request.url.path}');
      }),
    );
    await _open(tester, api);
    await _choose(tester, 'Setor Central');
    await tester.enterText(find.byType(TextField).first, '1');
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Água estimada:'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Água estimada: Não informado'), findsOneWidget);
    expect(find.textContaining('Energia estimada: 5,00 kWh'), findsOneWidget);
    expect(
      find.textContaining('Custo total estimado: Não informado'),
      findsOneWidget,
    );
  });

  testWidgets('Ignora resposta tardia de dispositivo do setor anterior', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/configuracaoCusto/propriedade/1') {
          return _json(null);
        }
        if (request.url.path == '/dispositivoIrrigacao/setor/10') {
          return old.future;
        }
        if (request.url.path == '/dispositivoIrrigacao/setor/11') {
          return _json([
            {
              'id': 9,
              'nome': 'Pivô Norte',
              'ativo': true,
              'setor': {'id': 11},
            },
          ]);
        }
        fail('Rota inesperada: ${request.url.path}');
      }),
    );
    await _open(tester, api);
    await _choose(tester, 'Setor Central');
    await _choose(tester, 'Setor Norte');
    expect(
      find.textContaining('Dispositivo ativo: Pivô Norte'),
      findsOneWidget,
    );
    old.complete(
      _json([
        {
          'id': 8,
          'nome': 'Pivô Antigo',
          'ativo': true,
          'setor': {'id': 10},
        },
      ]),
    );
    await tester.pump();
    expect(find.textContaining('Pivô Antigo'), findsNothing);
    expect(find.textContaining('Pivô Norte'), findsOneWidget);
  });

  testWidgets('Bloqueia duração inválida e período sem datas', (tester) async {
    var posts = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/configuracaoCusto/propriedade/1') {
          return _json(null);
        }
        if (request.url.path == '/dispositivoIrrigacao/setor/10') {
          return _json([
            {
              'id': 8,
              'nome': 'Pivô',
              'ativo': true,
              'setor': {'id': 10},
            },
          ]);
        }
        if (request.method == 'POST') posts++;
        return _json({});
      }),
    );
    await _open(tester, api);
    await _choose(tester, 'Setor Central');
    await tester.enterText(find.byType(TextField).at(1), '60');
    await tester.scrollUntilVisible(
      find.text('Salvar registro'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Salvar registro'));
    await tester.tap(find.text('Salvar registro'));
    await tester.pump();
    expect(find.textContaining('minutos de 0 a 59'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Informar início e fim'),
      -250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Informar início e fim'));
    await tester.tap(find.text('Informar início e fim'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Salvar registro'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Salvar registro'));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar registro'));
    await tester.pump();
    expect(find.textContaining('Informe início e fim válidos'), findsOneWidget);
    expect(posts, 0);
  });

  testWidgets('Impede registro quando há mais de um dispositivo ativo', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/configuracaoCusto/propriedade/1') {
          return _json(null);
        }
        if (request.url.path == '/dispositivoIrrigacao/setor/10') {
          return _json([
            {'id': 8, 'nome': 'Pivô 1', 'ativo': true},
            {'id': 9, 'nome': 'Pivô 2', 'ativo': true},
          ]);
        }
        fail('Rota inesperada: ${request.url.path}');
      }),
    );
    await _open(tester, api);
    await _choose(tester, 'Setor Central');
    expect(find.textContaining('mais de um dispositivo ativo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Salvar registro'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Salvar registro'),
          )
          .onPressed,
      isNull,
    );
  });
}
