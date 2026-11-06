import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/irrigation_control_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets(
      'Histórico acompanha a fazenda e ordena registros em $width px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final paths = <String>[];
        final api = ApiClient(
          client: MockClient((request) async {
            paths.add(request.url.path);
            final body = switch (request.url.path) {
              '/propriedade' => [
                {'id': 1, 'nome': 'Fazenda Norte'},
                {'id': 2, 'nome': 'Fazenda Sul'},
              ],
              '/registroIrrigacao/propriedade/1' => [
                {
                  'id': 1,
                  'nomeSetor': 'Antigo',
                  'dataIrrigacao': '2026-01-01T10:00:00',
                  'duracaoMinutos': 60,
                },
                {
                  'id': 2,
                  'nomeSetor': 'Central',
                  'nomeDispositivo': 'Pivô',
                  'dataIrrigacao': '2026-02-02T12:30:00',
                  'duracaoMinutos': 90,
                  'volumeAgua': 30,
                  'consumoEnergia': 7.5,
                  'custoAgua': 150,
                  'custoEnergia': 22.5,
                  'custoTotal': 172.5,
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
        )..token = 'teste';
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: IrrigationControlScreen(api: api),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Nenhum setor disponível nesta fazenda.'),
          findsOneWidget,
        );
        expect(
          paths.where((path) => path.startsWith('/registroIrrigacao')),
          isEmpty,
        );
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Histórico de irrigação'),
        );
        await tester.pumpAndSettle();
        expect(paths, contains('/registroIrrigacao/propriedade/1'));
        expect(find.text('Início: 02/02/2026 às 12:30'), findsOneWidget);
        expect(find.text('Duração: 1 h 30 min'), findsOneWidget);
        expect(find.text('Dispositivo: Pivô'), findsOneWidget);
        expect(find.text('Custo total estimado: 172,50'), findsOneWidget);
        expect(find.text('Água estimada: Não informado'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Setor: Central')).dy,
          lessThan(tester.getTopLeft(find.text('Setor: Antigo')).dy),
        );
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fazenda Sul').last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Histórico de irrigação'),
        );
        await tester.pumpAndSettle();
        expect(paths, contains('/registroIrrigacao/propriedade/2'));
        expect(
          find.text('Nenhuma irrigação registrada para esta fazenda.'),
          findsOneWidget,
        );
        expect(find.text('Setor: Central'), findsNothing);
      },
    );
  }

  testWidgets('Histórico informa erro e permite nova tentativa', (
    tester,
  ) async {
    var requests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/registroIrrigacao/propriedade/1') {
          requests++;
          return requests == 1
              ? http.Response('{}', 500)
              : http.Response('[]', 200);
        }
        final body = request.url.path == '/propriedade'
            ? [
                {'id': 1, 'nome': 'Fazenda'},
              ]
            : [];
        return http.Response(jsonEncode(body), 200);
      }),
    )..token = 'teste';
    await tester.pumpWidget(
      MaterialApp(home: IrrigationControlScreen(api: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Histórico de irrigação'),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível carregar o histórico.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nenhuma irrigação registrada para esta fazenda.'),
      findsOneWidget,
    );
    expect(requests, 2);
  });
}
