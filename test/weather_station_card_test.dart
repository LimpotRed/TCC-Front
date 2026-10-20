import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/farm_weather_card.dart';
import 'package:ghydro/open_meteo_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _farm = <String, dynamic>{
  'id': 1,
  'nome': 'Fazenda central',
  'localizacao': 'Rio Verde, GO',
};

const _station = <String, dynamic>{
  'id': 1,
  'nome': 'Estação central',
  'tipo': 'VIRTUAL',
  'latitude': '-16,892863',
  'longitude': '-50,041060',
};

http.Response _jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object> _weatherResponse({double temperature = 28.9}) => {
  'timezone': 'America/Sao_Paulo',
  'current': {
    'time': '2026-10-01T19:45',
    'temperature_2m': temperature,
    'relative_humidity_2m': 47,
    'wind_speed_10m': 15.1,
    'weather_code': 0,
    'is_day': 0,
  },
  'hourly': {
    'time': ['2026-10-01T18:00', '2026-10-01T19:00', '2026-10-01T20:00'],
    'precipitation_probability': [50, 69, 80],
  },
};

Future<void> _showCard(
  WidgetTester tester, {
  required ApiClient api,
  required OpenMeteoService weatherService,
  List<Map<String, dynamic>> farms = const [_farm],
  DateTime Function() clock = DateTime.now,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: FarmWeatherCard(
              api: api,
              farms: farms,
              weatherService: weatherService,
              clock: clock,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Relógio avança sem consultar novamente os dados climáticos', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 2, 0, 43, 59);
    var backendRequests = 0;
    var weatherRequests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        backendRequests++;
        return _jsonResponse([_station]);
      }),
    );
    final service = OpenMeteoService(
      client: MockClient((request) async {
        weatherRequests++;
        return _jsonResponse({
          ..._weatherResponse(),
          'utc_offset_seconds': -10800,
        });
      }),
    );
    addTearDown(service.close);

    await _showCard(
      tester,
      api: api,
      weatherService: service,
      clock: () => now,
    );
    await tester.pumpAndSettle();
    expect(find.text('Quinta-feira, 21:43'), findsOneWidget);
    expect(find.text('Dados meteorológicos de 19:45'), findsOneWidget);

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Quinta-feira, 21:44'), findsOneWidget);
    expect(find.text('Dados meteorológicos de 19:45'), findsOneWidget);
    expect(backendRequests, 1);
    expect(weatherRequests, 1);

    await tester.pumpWidget(const SizedBox());
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 1200.0]) {
    testWidgets('Clima real da fazenda sem overflow em $width px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var requests = 0;
      var backendRequests = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer sessão-teste');
          backendRequests++;
          expect(request.url.path, '/propriedade/1/estacoes');
          return _jsonResponse([_station]);
        }),
      )..token = 'sessão-teste';
      final service = OpenMeteoService(
        client: MockClient((request) async {
          requests++;
          expect(request.url.host, 'api.open-meteo.com');
          expect(
            double.parse(request.url.queryParameters['latitude']!),
            -16.892863,
          );
          expect(
            double.parse(request.url.queryParameters['longitude']!),
            -50.04106,
          );
          expect(request.headers.containsKey('Authorization'), isFalse);
          return _jsonResponse(_weatherResponse());
        }),
      );
      addTearDown(service.close);

      await _showCard(tester, api: api, weatherService: service);
      await tester.pumpAndSettle();

      expect(requests, 1);
      expect(backendRequests, 1);
      expect(find.text('Clima da fazenda'), findsOneWidget);
      expect(find.text('Rio Verde, GO'), findsOneWidget);
      expect(find.text('Bateria média'), findsNothing);
      expect(find.text('Umidade do sensor'), findsNothing);
      expect(find.byKey(const Key('battery-indicator-bateria')), findsNothing);
      expect(find.byKey(const Key('battery-indicator-umidade')), findsNothing);
      expect(find.text('VIRTUAL'), findsOneWidget);
      expect(find.text('28,9'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);
      expect(find.text('Chance de chuva na próxima hora'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('Umidade'), findsOneWidget);
      expect(find.text('47%'), findsOneWidget);
      expect(find.text('Vento'), findsOneWidget);
      expect(find.text('15,1 km/h'), findsOneWidget);
      expect(find.textContaining('Quinta-feira, 19:45'), findsOneWidget);
      expect(find.textContaining('Open-Meteo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final stations in <List<Map<String, dynamic>>>[
    [],
    [
      {'id': 1, 'nome': 'Sem coordenadas', 'tipo': 'VIRTUAL'},
    ],
    [
      {..._station, 'latitude': 91, 'longitude': 0},
      {..._station, 'id': 2, 'latitude': 0, 'longitude': -181},
      {..._station, 'id': 3, 'latitude': 'NaN'},
      {..._station, 'id': 4, 'latitude': 'Infinity'},
      {..._station, 'id': 5, 'longitude': 'inválida'},
    ],
  ]) {
    testWidgets(
      'Não consulta clima sem coordenadas válidas: ${stations.length} estações',
      (tester) async {
        var weatherRequests = 0;
        final api = ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/propriedade/1/estacoes');
            return _jsonResponse(stations);
          }),
        );
        final service = OpenMeteoService(
          client: MockClient((_) async {
            weatherRequests++;
            return _jsonResponse(_weatherResponse());
          }),
        );
        addTearDown(service.close);

        await _showCard(tester, api: api, weatherService: service);
        await tester.pumpAndSettle();

        expect(weatherRequests, 0);
        expect(find.text('28,9'), findsNothing);
        expect(
          find.text(
            'A fazenda selecionada não possui estação vinculada com coordenadas válidas.',
          ),
          findsOneWidget,
        );
        expect(find.text('Configurar estações'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Usa a primeira estação válida e aceita coordenadas numéricas', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/propriedade/1/estacoes');
        return _jsonResponse([
          {'id': 1, 'nome': 'Sem posição'},
          {..._station, 'id': 2, 'latitude': -23.5, 'longitude': -46.6},
        ]);
      }),
    );
    final service = OpenMeteoService(
      client: MockClient((request) async {
        expect(request.url.queryParameters['latitude'], '-23.5');
        expect(request.url.queryParameters['longitude'], '-46.6');
        return _jsonResponse(_weatherResponse());
      }),
    );
    addTearDown(service.close);

    await _showCard(tester, api: api, weatherService: service);
    await tester.pumpAndSettle();

    expect(find.text('28,9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nova tentativa recupera falha de listagem do backend', (
    tester,
  ) async {
    var backendRequests = 0;
    var weatherRequests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/propriedade/1/estacoes');
        backendRequests++;
        return backendRequests == 1
            ? _jsonResponse({'message': 'Servidor indisponível.'}, 503)
            : _jsonResponse([_station]);
      }),
    );
    final service = OpenMeteoService(
      client: MockClient((_) async {
        weatherRequests++;
        return _jsonResponse(_weatherResponse());
      }),
    );
    addTearDown(service.close);

    await _showCard(tester, api: api, weatherService: service);
    await tester.pumpAndSettle();
    expect(weatherRequests, 0);
    expect(find.textContaining('Servidor indisponível.'), findsOneWidget);

    await tester.tap(find.byTooltip('Atualizar clima'));
    await tester.pumpAndSettle();

    expect(backendRequests, 2);
    expect(weatherRequests, 1);
    expect(find.text('28,9'), findsOneWidget);
    expect(find.textContaining('Servidor indisponível.'), findsNothing);
  });

  testWidgets('Atualização recupera falha do provedor de clima', (
    tester,
  ) async {
    var weatherRequests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/propriedade/1/estacoes');
        return _jsonResponse([_station]);
      }),
    );
    final service = OpenMeteoService(
      client: MockClient((_) async {
        weatherRequests++;
        return weatherRequests == 1
            ? _jsonResponse({'reason': 'Unavailable'}, 503)
            : _jsonResponse(_weatherResponse());
      }),
    );
    addTearDown(service.close);

    await _showCard(tester, api: api, weatherService: service);
    await tester.pumpAndSettle();
    expect(find.text('28,9'), findsNothing);

    await tester.tap(find.byTooltip('Atualizar clima'));
    await tester.pumpAndSettle();

    expect(weatherRequests, 2);
    expect(find.text('28,9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Campos ausentes mostram Não informado sem inventar valores', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/propriedade/1/estacoes');
        return _jsonResponse([_station]);
      }),
    );
    final service = OpenMeteoService(
      client: MockClient(
        (_) async => _jsonResponse({
          'timezone': 'America/Sao_Paulo',
          'current': {'time': '2026-10-01T19:45'},
        }),
      ),
    );
    addTearDown(service.close);

    await _showCard(tester, api: api, weatherService: service);
    await tester.pumpAndSettle();

    expect(find.text('Não informado'), findsAtLeastNWidgets(3));
    expect(find.text('0%'), findsNothing);
    expect(find.text('0,0 km/h'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Trocar fazenda ignora resposta tardia da seleção anterior', (
    tester,
  ) async {
    final oldResponse = Completer<http.Response>();
    var weatherRequests = 0;
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          anyOf('/propriedade/1/estacoes', '/propriedade/2/estacoes'),
        );
        return _jsonResponse(
          request.url.path == '/propriedade/2/estacoes'
              ? [
                  {
                    ..._station,
                    'id': 2,
                    'nome': 'Estação sul',
                    'latitude': -23.5,
                    'longitude': -46.6,
                  },
                ]
              : [_station],
        );
      }),
    );
    final service = OpenMeteoService(
      client: MockClient((request) {
        weatherRequests++;
        if (request.url.queryParameters['latitude'] == '-23.5') {
          return Future.value(
            _jsonResponse(_weatherResponse(temperature: 21.4)),
          );
        }
        return oldResponse.future;
      }),
    );
    addTearDown(service.close);

    await _showCard(
      tester,
      api: api,
      weatherService: service,
      farms: const [
        _farm,
        {'id': 2, 'nome': 'Fazenda sul'},
      ],
    );
    await tester.pump();
    await tester.pump();
    expect(weatherRequests, 1);

    await tester.tap(
      find.byWidgetPredicate((widget) => widget is DropdownButtonFormField),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Fazenda sul').last);
    await tester.pumpAndSettle();
    expect(weatherRequests, 2);
    expect(find.text('21,4'), findsOneWidget);

    oldResponse.complete(_jsonResponse(_weatherResponse(temperature: 28.9)));
    await tester.pumpAndSettle();

    expect(find.text('21,4'), findsOneWidget);
    expect(find.text('28,9'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final farms in <List<Map<String, dynamic>>>[
    [],
    [_farm],
  ]) {
    testWidgets('Consulta sem configuração local: ${farms.length} fazendas', (
      tester,
    ) async {
      var backendRequests = 0;
      var weatherRequests = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          backendRequests++;
          expect(request.url.path, '/propriedade/1/estacoes');
          return _jsonResponse([]);
        }),
      );
      final service = OpenMeteoService(
        client: MockClient((_) async {
          weatherRequests++;
          return _jsonResponse(_weatherResponse());
        }),
      );
      addTearDown(service.close);

      await _showCard(tester, api: api, weatherService: service, farms: farms);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Gerenciar estações meteorológicas'), findsNothing);
      expect(find.text('Configurar estações'), findsNothing);
      expect(
        find.text(
          farms.isEmpty ? 'Nenhuma fazenda disponível.' : 'A fazenda selecionada não possui estação vinculada com coordenadas válidas.',
        ),
        findsOneWidget,
      );
      expect(backendRequests, farms.isEmpty ? 0 : 1);
      expect(weatherRequests, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
