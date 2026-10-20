import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherFailure implements Exception {
  const WeatherFailure(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.time,
    required this.stationLocalTime,
    this.utcOffsetSeconds,
    this.temperature,
    this.humidity,
    this.windSpeed,
    this.precipitationProbability,
    this.weatherCode,
    this.isDay,
    this.timezone,
  });

  /// Wall-clock time at the station, already returned in its local timezone.
  /// Do not convert this value using the device's timezone.
  final DateTime time;

  /// Current wall-clock time at the station, computed from the API's UTC offset.
  final DateTime stationLocalTime;
  final int? utcOffsetSeconds;
  final double? temperature;
  final double? humidity;
  final double? windSpeed;

  /// Precipitation probability for the upcoming hourly interval after [time].
  final double? precipitationProbability;
  final int? weatherCode;
  final bool? isDay;
  final String? timezone;
}

class OpenMeteoService {
  OpenMeteoService({
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  Future<WeatherSnapshot> fetch({
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const WeatherFailure(
        'Informe latitude entre -90 e 90 e longitude entre -180 e 180.',
      );
    }

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'timezone': 'auto',
      'forecast_days': '2',
      'temperature_unit': 'celsius',
      'wind_speed_unit': 'kmh',
      'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,is_day',
      'hourly': 'precipitation_probability',
    });

    try {
      // This client is separate from the backend API and never receives its JWT.
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WeatherFailure(
          response.statusCode == 429
              ? 'O serviço de clima recebeu muitas consultas. Tente novamente em alguns instantes.'
              : 'Não foi possível consultar o clima. Tente novamente.',
          status: response.statusCode,
        );
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid weather response');
      }
      // Open-Meteo uses {error: true, reason: ...}, including parameter errors.
      // Keep provider messages out of the UI so errors stay in Portuguese.
      if (data['error'] == true) {
        throw const WeatherFailure(
          'O serviço de clima não conseguiu processar a consulta. Tente novamente.',
        );
      }
      return _parse(data);
    } on TimeoutException {
      throw const WeatherFailure(
        'O serviço de clima demorou para responder. Tente novamente.',
      );
    } on http.ClientException {
      throw const WeatherFailure(
        'Não foi possível conectar ao serviço de clima. Verifique sua conexão e tente novamente.',
      );
    } on FormatException {
      throw const WeatherFailure(
        'O serviço de clima retornou dados inválidos. Tente novamente.',
      );
    }
  }

  WeatherSnapshot _parse(Map<String, dynamic> data) {
    final current = data['current'];
    if (current is! Map<String, dynamic>) {
      throw const FormatException('Missing current weather');
    }
    final time = _localTime(current['time']);
    final day = _integer(current['is_day']);
    if (day != null && day != 0 && day != 1) {
      throw const FormatException('Invalid daylight value');
    }
    final timezone = data['timezone'];
    if (timezone != null && timezone is! String) {
      throw const FormatException('Invalid timezone');
    }
    return WeatherSnapshot(
      time: time,
      stationLocalTime: _stationLocalNow(data['utc_offset_seconds'], time),
      utcOffsetSeconds: _validUtcOffset(data['utc_offset_seconds']),
      temperature: _number(current['temperature_2m']),
      humidity: _number(current['relative_humidity_2m'], min: 0, max: 100),
      windSpeed: _number(current['wind_speed_10m'], min: 0),
      precipitationProbability: _nextHourPrecipitationProbability(
        data['hourly'],
        time,
      ),
      weatherCode: _integer(current['weather_code']),
      isDay: day == null ? null : day == 1,
      timezone: timezone as String?,
    );
  }

  DateTime _stationLocalNow(dynamic offset, DateTime fallback) {
    final seconds = _validUtcOffset(offset);
    if (seconds == null) return fallback;
    final nowUtc = DateTime.now().toUtc();
    return DateTime.fromMillisecondsSinceEpoch(
      nowUtc.millisecondsSinceEpoch + seconds * 1000,
      isUtc: true,
    );
  }

  int? _validUtcOffset(dynamic offset) {
    if (offset is! num ||
        !offset.isFinite ||
        offset.toDouble() != offset.toInt().toDouble() ||
        offset < -43200 ||
        offset > 50400) {
      return null;
    }
    return offset.toInt();
  }

  double? _nextHourPrecipitationProbability(dynamic hourly, DateTime time) {
    if (hourly == null) return null;
    if (hourly is! Map<String, dynamic>) {
      throw const FormatException('Invalid hourly weather');
    }
    final times = hourly['time'];
    final probabilities = hourly['precipitation_probability'];
    if (times == null || probabilities == null) return null;
    if (times is! List ||
        probabilities is! List ||
        times.length != probabilities.length) {
      throw const FormatException('Invalid hourly series');
    }
    final nextHour = DateTime.utc(
      time.year,
      time.month,
      time.day,
      time.hour,
    ).add(const Duration(hours: 1));
    for (var index = 0; index < times.length; index++) {
      final hour = _localTime(times[index]);
      if (hour.year == nextHour.year &&
          hour.month == nextHour.month &&
          hour.day == nextHour.day &&
          hour.hour == nextHour.hour &&
          hour.minute == 0 &&
          hour.second == 0) {
        return _number(probabilities[index], min: 0, max: 100);
      }
    }
    return null;
  }

  double? _number(dynamic value, {double? min, double? max}) {
    if (value == null) return null;
    if (value is! num ||
        !value.isFinite ||
        (min != null && value < min) ||
        (max != null && value > max)) {
      throw const FormatException('Invalid weather value');
    }
    return value.toDouble();
  }

  int? _integer(dynamic value) {
    final number = _number(value, min: 0);
    if (number == null) return null;
    if (number != number.truncateToDouble()) {
      throw const FormatException('Invalid weather code');
    }
    return number.toInt();
  }

  DateTime _localTime(dynamic value) {
    if (value is! String) {
      throw const FormatException('Invalid local weather time');
    }
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$',
    ).firstMatch(value);
    if (match == null) {
      throw const FormatException('Invalid local weather time');
    }
    final parts = [
      for (var index = 1; index <= 6; index++)
        int.parse(match.group(index) ?? '0'),
    ];
    final time = DateTime(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
    if (time.year != parts[0] ||
        time.month != parts[1] ||
        time.day != parts[2] ||
        time.hour != parts[3] ||
        time.minute != parts[4] ||
        time.second != parts[5]) {
      throw const FormatException('Invalid local weather time');
    }
    return time;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
