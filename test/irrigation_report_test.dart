import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/irrigation_report_pdf.dart';
import 'package:ghydro/irrigation_report_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Filtra pelo início incluindo todo o primeiro e último dia', () {
    final original = [
      {'id': 1, 'dataIrrigacao': '2026-01-31T23:59:59'},
      {'id': 2, 'dataIrrigacao': '2026-02-01T00:00:00'},
      {'id': 3, 'dataIrrigacao': '2026-02-28T23:59:59'},
      {'id': 4, 'dataIrrigacao': '2026-03-01T00:00:00'},
      {'id': 5, 'dataIrrigacao': null},
      {'id': 6, 'dataIrrigacao': 'inválida'},
    ];
    final report = IrrigationReport(
      farmName: 'Fazenda',
      start: DateTime(2026, 2, 1),
      end: DateTime(2026, 2, 28),
      type: IrrigationReportType.complete,
      records: original,
    );
    expect(report.records.map((row) => row['id']), [3, 2]);
    expect(original.map((row) => row['id']), [1, 2, 3, 4, 5, 6]);
    expect(
      () => IrrigationReport(
        farmName: 'Fazenda',
        start: DateTime(2026, 3),
        end: DateTime(2026, 2),
        type: IrrigationReportType.water,
        records: original,
      ),
      throwsArgumentError,
    );
  });

  test(
    'Gera PDF em todos os tipos, vazio e com histórico multipágina',
    () async {
      final records = List.generate(
        120,
        (index) => {
          'dataIrrigacao':
              '2026-01-${(index % 28 + 1).toString().padLeft(2, '0')}T12:30:00',
          'nomeSetor': 'Setor São João',
          'nomeDispositivo': 'Pivô Central',
          'duracaoMinutos': 90,
          'volumeAgua': 12.5,
          'consumoEnergia': null,
          'custoAgua': 4.5,
          'custoEnergia': 0,
          'custoTotal': 4.5,
        },
      );
      for (final type in IrrigationReportType.values) {
        final report = IrrigationReport(
          farmName: 'Fazenda São João',
          start: DateTime(2026),
          end: DateTime(2026, 1, 31),
          type: type,
          records: records,
        );
        final bytes = await buildIrrigationReportPdf(report);
        expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
        expect(bytes.length, greaterThan(1000));
      }
      final empty = IrrigationReport(
        farmName: 'Fazenda',
        start: DateTime(2026),
        end: DateTime(2026, 1, 31),
        type: IrrigationReportType.complete,
        records: const [],
      );
      final bytes = await buildIrrigationReportPdf(empty);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    },
  );

  for (final width in [320.0, 1200.0]) {
    testWidgets('Gera PDF da fazenda e seleciona tipo em $width px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              {
                'dataIrrigacao': DateTime.now().toIso8601String(),
                'nomeSetor': 'Central',
                'custoAgua': 20,
              },
            ]),
            200,
          );
        }),
      )..token = 'teste';
      Uint8List? result;
      String? filename;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: IrrigationReportScreen(
            api: api,
            farmId: '42',
            farmName: 'Fazenda São João',
            deliverPdf: (bytes, name) async {
              result = bytes;
              filename = name;
              return true;
            },
          ),
        ),
      );
      await tester.tap(
        find.byType(DropdownButtonFormField<IrrigationReportType>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gastos').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .state<FormFieldState<IrrigationReportType>>(
              find.byType(DropdownButtonFormField<IrrigationReportType>),
            )
            .value,
        IrrigationReportType.expenses,
      );
      await tester.ensureVisible(find.text('Gerar PDF'));
      await tester.tap(find.text('Gerar PDF'));
      await tester.pumpAndSettle();
      expect(requests.single.url.path, '/registroIrrigacao/propriedade/42');
      expect(requests.single.headers['Authorization'], 'Bearer teste');
      expect(ascii.decode(result!.sublist(0, 5)), '%PDF-');
      expect(filename, startsWith('relatorio-irrigacao-'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Datas escolhidas em ordem inválida impedem consulta', (
    tester,
  ) async {
    var requests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        requests++;
        return http.Response('[]', 200);
      }),
    )..token = 'teste';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: IrrigationReportScreen(
          api: api,
          farmId: '1',
          farmName: 'Fazenda',
          deliverPdf: (bytes, filename) async => true,
        ),
      ),
    );
    Future<void> setDate(Finder button, String value) async {
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, value);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    await setDate(find.textContaining('Data inicial:'), '31/01/2026');
    await setDate(find.textContaining('Data final:'), '01/01/2026');
    await tester.ensureVisible(find.text('Gerar PDF'));
    await tester.tap(find.text('Gerar PDF'));
    await tester.pumpAndSettle();
    expect(
      find.text('A data inicial não pode ser posterior à data final.'),
      findsOneWidget,
    );
    expect(requests, 0);
  });

  testWidgets('Erro na consulta não produz PDF e permite tentar novamente', (
    tester,
  ) async {
    var calls = 0;
    var deliveries = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        calls++;
        return calls == 1 ? http.Response('{}', 500) : http.Response('[]', 200);
      }),
    )..token = 'teste';
    await tester.pumpWidget(
      MaterialApp(
        home: IrrigationReportScreen(
          api: api,
          farmId: '1',
          farmName: 'Fazenda',
          deliverPdf: (bytes, filename) async {
            deliveries++;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.text('Gerar PDF'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível concluir a operação. Tente novamente.'),
      findsOneWidget,
    );
    expect(deliveries, 0);
    await tester.tap(find.text('Gerar PDF'));
    await tester.pumpAndSettle();
    expect(deliveries, 1);
  });
}
