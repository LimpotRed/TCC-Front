import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/resource_schema.dart';
import 'package:ghydro/resource_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const ref = {'id': 1, 'nome': 'Registro vinculado', 'nomePopular': 'Milho'};
// Exemplos dos corpos recebidos dos controllers Java, sem banco de dados de teste.
const examples = <String, Map<String, dynamic>>{
  'proprietario': {'nome': 'Maria', 'cpf': '12345678901'},
  'propriedade': {
    'nome': 'Fazenda',
    'localizacao': 'Interior',
    'proprietario': ref,
    'estacoes': [ref],
  },
  'tipoSolo': {
    'descricao': 'Argiloso',
    'capacidadeCampo': 30.0,
    'pontoMurcha': 10.0,
  },
  'setor': {
    'nome': 'Leste',
    'poligonoGeografico': '[[0,0],[1,0],[1,1],[0,0]]',
    'propriedade': ref,
    'tipoSolo': ref,
  },
  'cultura': {'nomePopular': 'Milho', 'variedade': 'Doce'},
  'estadoFenologico': {
    'cultura': ref,
    'nomeFase': 'Inicial',
    'ordemSequencia': 1,
    'duracaoDias': 20,
    'kCFase': 1.2,
  },
  'plantio': {
    'cultura': ref,
    'setor': ref,
    'dataPlantio': '2026-01-01',
    'statusPlantio': 'PLANEJADO',
  },
  'dispositivoIrrigacao': {
    'nome': 'Pivô Leste',
    'tipoDispositivo': 'PIVO',
    'setor': ref,
    'eficienciaIrrigacao': 90.0,
  },
  'sensor': {
    'setor': ref,
    'tipos': ['UMIDADE', 'TEMPERATURA'],
    'status': 'ATIVO',
    'dataInstalacao': '2026-01-01T10:00:00',
    'nivelBateria': 75.0,
  },
  'leituraSensor': {
    'sensor': ref,
    'timestamp': '2026-01-02T10:00:00',
    'valorBruto': 30.0,
    'valorTratado': 32.0,
    'unidadeMedida': 'PORCENTAGEM',
  },
  'estacaoMetereologica': {
    'nome': 'Estação central',
    'tipo': 'FISICA',
    'latitude': '-23.5',
    'longitude': '-46.6',
  },
  'leituraClimatica': {
    'estacaoMetereologica': ref,
    'dataHora': '2026-01-02T10:00:00',
    'temperaturaMaxima': 32.0,
    'temperaturaMinima': 20.0,
  },
  'recomendacao': {
    'plantio': ref,
    'dataGeracao': '2026-01-02T10:00:00',
    'tipoAcao': 'IRRIGACAO',
    'status': 'PENDENTE',
  },
  'execucaoManejo': {
    'plantio': ref,
    'inicio': '2026-01-02T11:00:00',
    'origem': 'MANUAL',
    'volumeAguaAplicado': 35.0,
  },
  'configuracaoCusto': {
    'propriedade': ref,
    'custoM3Agua': 2.5,
    'custoKWh': 0.8,
    'moeda': 'BRL',
  },
  'admin/manutencao': {
    'tipoEquipamento': 'PIVO',
    'equipamentoId': 1,
    'tipoManutencao': 'PREVENTIVA',
    'dataManutencao': '2026-01-02',
  },
};
http.Response response(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  for (final entry in examples.entries) {
    testWidgets('Edita ${entry.key} sem perder vínculos ou tipos de dados', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      http.Request? saved;
      final api = ApiClient(
        client: MockClient((request) async {
          if (request.method == 'GET') return response([ref]);
          saved = request;
          return response({'id': 9});
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ResourceEditor(
            api: api,
            spec: resource(entry.key),
            row: {'id': 9, ...entry.value},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Salvar registro'));
      await tester.tap(find.text('Salvar registro'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.method, 'PUT');
      expect(
        saved!.url.path,
        entry.key == 'estacaoMetereologica'
            ? '/estacaoMetereologica'
            : '/${entry.key}/9',
      );
      final payload = jsonDecode(saved!.body) as Map;
      expect(payload['id'], 9);
      for (final field in entry.value.entries) {
        final expected = field.value is Map
            ? {'id': 1}
            : field.key == 'estacoes'
            ? [
                {'id': 1},
              ]
            : field.value;
        expect(
          payload[field.key],
          expected,
          reason: '${entry.key}.${field.key}',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Erro do servidor mantém formulário e valores editados', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient(
        (_) async => response({'message': 'Cultura já cadastrada.'}, 400),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ResourceEditor(api: api, spec: resource('cultura')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Milho');
    await tester.enterText(find.byType(TextFormField).at(1), 'Doce');
    await tester.ensureVisible(find.text('Salvar registro'));
    await tester.tap(find.text('Salvar registro'));
    await tester.pumpAndSettle();
    expect(find.text('Cultura já cadastrada.'), findsOneWidget);
    expect(find.text('Milho'), findsOneWidget);
  });
  testWidgets('Consulta de produtor não mostra ações de escrita', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient(
        (_) async => response([
          {'id': 9, ...examples['sensor']!},
        ]),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ResourceScreen(
          api: api,
          spec: resource('sensor'),
          canManage: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Ações do registro'), findsNothing);
    await tester.tap(find.text('Sensor #9'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
  for (final endpoint in ['cultura', 'admin/manutencao']) {
    testWidgets('Exclusão de $endpoint exige confirmação e usa rota correta', (
      tester,
    ) async {
      var deleted = false;
      String? deletePath;
      final api = ApiClient(
        client: MockClient((r) async {
          if (r.method == 'DELETE') {
            deleted = true;
            deletePath = r.url.path;
            return http.Response('', 204);
          }
          return response(
            deleted
                ? []
                : [
                    {'id': 9, ...examples[endpoint]!},
                  ],
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ResourceScreen(
            api: api,
            spec: resource(endpoint),
            canManage: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ações do registro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(deleted, isFalse);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(deleted, isFalse);
      await tester.tap(find.byTooltip('Ações do registro'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(
        deletePath,
        endpoint == 'cultura' ? '/cultura/9/' : '/admin/manutencao/9',
      );
      expect(find.text('Nenhum registro por aqui ainda'), findsOneWidget);
    });
  }
}
