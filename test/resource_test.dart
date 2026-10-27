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
  'proprietario': {
    'nome': 'Maria',
    'cpf': '12345678901',
    'email': 'maria@example.com',
  },
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
  'manutencao': {
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
  for (final spec in resources) {
    testWidgets('${spec.title} permite consultar sem ações de escrita', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final requests = <http.Request>[];
      final row = {'id': 1, ...?examples[spec.path]};
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          expect(request.method, 'GET');
          expect(request.url.path, '/${spec.path}');
          return response([row]);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ResourceScreen(api: api, spec: spec),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Excluir'), findsNothing);
      expect(find.text('Novo cadastro'), findsNothing);
      expect(find.byTooltip('Ações do registro'), findsNothing);
      expect(find.text(spec.label(row)), findsOneWidget);
      await tester.tap(find.text(spec.label(row)));
      await tester.pumpAndSettle();
      expect(find.text('Fechar'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Excluir'), findsNothing);
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Manutenção mantém consulta de histórico sem edição', (
    tester,
  ) async {
    final paths = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.method, 'GET');
        return response([
          {'id': 1, ...examples['manutencao']!},
        ]);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ResourceScreen(api: api, spec: resource('manutencao')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Histórico do equipamento'));
    await tester.pumpAndSettle();
    expect(paths, ['/manutencao', '/manutencao/equipamento/PIVO/1']);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Excluir'), findsNothing);
  });
}
