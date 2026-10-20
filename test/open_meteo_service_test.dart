import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/open_meteo_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> forecast({
  Map<String, dynamic>? current,
  Map<String, dynamic>? hourly,
}) => {
  'timezone': 'America/Sao_Paulo',
  'current':
      current ??
      {
        'time': '2026-10-01T19:45',
        'temperature_2m': 28.9,
        'relative_humidity_2m': 47,
        'wind_speed_10m': 15.1,
        'weather_code': 2,
        'is_day': 0,
      },
  'hourly':
      hourly ??
      {
        'time': ['2026-10-01T18:00', '2026-10-01T19:00', '2026-10-01T20:00'],
        'precipitation_probability': [15, 69, 80],
      },
};

http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<WeatherSnapshot> fetch(OpenMeteoService service) =>
    service.fetch(latitude: -16.892863, longitude: -50.041060);

Matcher failureContaining(String text) => throwsA(
  isA<WeatherFailure>().having(
    (failure) => failure.message,
    'message',
    contains(text),
  ),
);

void main() {
  test(
    'Consulta Open-Meteo sem credenciais do backend e usa unidades locais',
    () async {
      late http.Request request;
      final service = OpenMeteoService(
        client: MockClient((r) async {
          request = r;
          return jsonResponse(forecast());
        }),
      );

      await fetch(service);

      expect(request.method, 'GET');
      expect(request.url.scheme, 'https');
      expect(request.url.host, 'api.open-meteo.com');
      expect(request.url.path, '/v1/forecast');
      expect(request.url.queryParameters, {
        'latitude': '-16.892863',
        'longitude': '-50.04106',
        'timezone': 'auto',
        'forecast_days': '2',
        'temperature_unit': 'celsius',
        'wind_speed_unit': 'kmh',
        'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,is_day',
        'hourly': 'precipitation_probability',
      });
      expect(request.headers['Authorization'], isNull);
      expect(request.url.queryParameters.containsKey('apikey'), isFalse);
      expect(request.headers['Accept'], 'application/json');
      expect(request.body, isEmpty);
    },
  );

  test('Lê condições atuais e probabilidade da próxima hora', () async {
    final service = OpenMeteoService(
      client: MockClient((_) async => jsonResponse(forecast())),
    );

    final weather = await fetch(service);

    expect(weather.time, DateTime(2026, 10, 1, 19, 45));
    expect(weather.time.isUtc, isFalse);
    expect(weather.timezone, 'America/Sao_Paulo');
    expect(weather.temperature, 28.9);
    expect(weather.humidity, 47);
    expect(weather.windSpeed, 15.1);
    expect(weather.precipitationProbability, 80);
    expect(weather.weatherCode, 2);
    expect(weather.isDay, isFalse);
  });

  test(
    'Não usa outra hora ou outro dia quando a próxima hora está ausente',
    () async {
      final service = OpenMeteoService(
        client: MockClient(
          (_) async => jsonResponse(
            forecast(
              hourly: {
                'time': [
                  '2026-09-30T20:00',
                  '2026-10-01T18:00',
                  '2026-10-01T21:00',
                ],
                'precipitation_probability': [10, 20, 30],
              },
            ),
          ),
        ),
      );

      expect((await fetch(service)).precipitationProbability, isNull);
    },
  );

  test(
    'Valores ausentes permanecem nulos e zero continua sendo zero',
    () async {
      final responses = [
        forecast(
          current: {
            'time': '2026-10-01T19:45',
            'temperature_2m': null,
            'relative_humidity_2m': null,
            'wind_speed_10m': null,
            'weather_code': null,
            'is_day': null,
          },
          hourly: {
            'time': ['2026-10-01T20:00'],
            'precipitation_probability': [null],
          },
        ),
        forecast(
          current: {
            'time': '2026-10-01T19:45',
            'temperature_2m': 0,
            'relative_humidity_2m': 0,
            'wind_speed_10m': 0,
            'weather_code': 0,
            'is_day': 1,
          },
          hourly: {
            'time': ['2026-10-01T20:00'],
            'precipitation_probability': [0],
          },
        ),
      ];
      final service = OpenMeteoService(
        client: MockClient((_) async => jsonResponse(responses.removeAt(0))),
      );

      final missing = await fetch(service);
      expect(missing.temperature, isNull);
      expect(missing.humidity, isNull);
      expect(missing.windSpeed, isNull);
      expect(missing.weatherCode, isNull);
      expect(missing.isDay, isNull);
      expect(missing.precipitationProbability, isNull);

      final zero = await fetch(service);
      expect(zero.temperature, 0);
      expect(zero.humidity, 0);
      expect(zero.windSpeed, 0);
      expect(zero.weatherCode, 0);
      expect(zero.isDay, isTrue);
      expect(zero.precipitationProbability, 0);
    },
  );

  test('Bloqueia coordenadas inválidas antes de enviar uma consulta', () async {
    var requests = 0;
    final service = OpenMeteoService(
      client: MockClient((_) async {
        requests++;
        return jsonResponse(forecast());
      }),
    );

    for (final coordinate in [
      (91.0, 0.0),
      (-91.0, 0.0),
      (0.0, 181.0),
      (0.0, -181.0),
      (double.nan, 0.0),
      (0.0, double.infinity),
    ]) {
      await expectLater(
        service.fetch(latitude: coordinate.$1, longitude: coordinate.$2),
        failureContaining('latitude'),
      );
    }
    expect(requests, 0);
  });

  test('Traduz erros HTTP sem expor a mensagem técnica do provedor', () async {
    for (final status in [400, 401, 429, 500]) {
      final service = OpenMeteoService(
        client: MockClient(
          (_) async => jsonResponse({
            'error': true,
            'reason': 'Technical provider message',
          }, status),
        ),
      );
      await expectLater(
        fetch(service),
        throwsA(
          isA<WeatherFailure>()
              .having((failure) => failure.status, 'status', status)
              .having(
                (failure) => failure.message,
                'message',
                isNot(contains('Technical')),
              ),
        ),
      );
    }
  });

  test('Trata erro informado no JSON e respostas inválidas', () async {
    final invalidData = <Object>[
      [],
      {},
      {
        'current': {'time': '2026-10-35T19:45'},
      },
      forecast(
        current: {'time': '2026-10-01T19:45', 'temperature_2m': 'quente'},
      ),
      forecast(
        current: {'time': '2026-10-01T19:45', 'relative_humidity_2m': 101},
      ),
      forecast(current: {'time': '2026-10-01T19:45', 'is_day': 2}),
      forecast(
        hourly: {
          'time': ['2026-10-01T19:00'],
          'precipitation_probability': [],
        },
      ),
    ];
    for (final data in invalidData) {
      final service = OpenMeteoService(
        client: MockClient((_) async => jsonResponse(data)),
      );
      await expectLater(fetch(service), failureContaining('dados inválidos'));
    }

    final providerError = OpenMeteoService(
      client: MockClient(
        (_) async => jsonResponse({
          'error': true,
          'reason': 'Cannot initialize WeatherVariable',
        }),
      ),
    );
    await expectLater(fetch(providerError), failureContaining('processar'));

    final invalidJson = OpenMeteoService(
      client: MockClient((_) async => http.Response('{', 200)),
    );
    await expectLater(fetch(invalidJson), failureContaining('dados inválidos'));
  });

  test('Traduz falhas de conexão e timeout', () async {
    final offline = OpenMeteoService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(fetch(offline), failureContaining('conectar'));

    final completion = Completer<http.Response>();
    final slow = OpenMeteoService(
      client: MockClient((_) => completion.future),
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(fetch(slow), failureContaining('demorou'));
    completion.complete(jsonResponse(forecast()));
  });

  test('Não fecha um cliente injetado por quem usa o serviço', () async {
    final client = TrackingClient();
    final service = OpenMeteoService(client: client);

    service.close();

    expect(client.closed, isFalse);
    expect((await fetch(service)).temperature, 28.9);
    client.close();
  });
}

class TrackingClient extends http.BaseClient {
  bool closed = false;
  final _client = MockClient((_) async => jsonResponse(forecast()));

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request);

  @override
  void close() {
    closed = true;
    _client.close();
  }
}
