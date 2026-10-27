import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'open_meteo_service.dart';

const _surface = Color(0xFF242144);
const _muted = Color(0xFFA39DBF);
const _cyan = Color(0xFF36C9D8);

/// Consulta o clima pela referência meteorológica vinculada à fazenda.
class FarmWeatherCard extends StatefulWidget {
  const FarmWeatherCard({
    super.key,
    required this.api,
    required this.farms,
    this.weatherService,
    this.selectedFarmId,
    this.onFarmChanged,
    this.refreshVersion = 0,
    this.clock = DateTime.now,
  });

  final ApiClient api;
  final List<Map<String, dynamic>> farms;
  final OpenMeteoService? weatherService;
  final String? selectedFarmId;
  final ValueChanged<String?>? onFarmChanged;
  final int refreshVersion;
  final DateTime Function() clock;

  @override
  State<FarmWeatherCard> createState() => _FarmWeatherCardState();
}

class _FarmWeatherCardState extends State<FarmWeatherCard> {
  late final _weatherService = widget.weatherService ?? OpenMeteoService();
  late final _ownsWeatherService = widget.weatherService == null;
  List<_Farm> _farms = [];
  _Farm? _selected;
  _StationLocation? _reference;
  WeatherSnapshot? _weather;
  bool _loading = true;
  String? _error;
  bool _referenceLoaded = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  @override
  void didUpdateWidget(covariant FarmWeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion ||
        oldWidget.api != widget.api ||
        oldWidget.farms != widget.farms ||
        (oldWidget.selectedFarmId != widget.selectedFarmId &&
            widget.selectedFarmId != _selected?.id)) {
      _loadFarms(
        preferredFarmId: oldWidget.selectedFarmId != widget.selectedFarmId
            ? widget.selectedFarmId
            : null,
      );
    }
  }

  @override
  void dispose() {
    if (_ownsWeatherService) _weatherService.close();
    super.dispose();
  }

  Future<void> _loadFarms({String? preferredFarmId}) async {
    final generation = ++_generation;
    final previousId =
        preferredFarmId ?? _selected?.id ?? widget.selectedFarmId;
    setState(() {
      _loading = true;
      _reference = null;
      _weather = null;
      _error = null;
      _referenceLoaded = false;
    });
    // O painel pode estar construindo o cartão no primeiro carregamento.
    await Future<void>.value();
    if (!mounted || generation != _generation) return;
    final farms = <String, _Farm>{};
    for (final row in widget.farms) {
      final farm = _Farm.fromRow(row);
      if (farm != null) farms[farm.id] = farm;
    }
    setState(() {
      _farms = farms.values.toList();
      _selected = farms[previousId] ?? _farms.firstOrNull;
      _loading = false;
    });
    final selected = _selected;
    if (selected == null) {
      widget.onFarmChanged?.call(null);
    } else {
      await _loadFarmWeather(selected);
    }
  }

  Future<void> _loadFarmWeather(_Farm farm) async {
    final generation = ++_generation;
    setState(() {
      _selected = farm;
      _loading = true;
      _reference = null;
      _referenceLoaded = false;
      _weather = null;
      _error = null;
    });
    widget.onFarmChanged?.call(farm.id);
    try {
      final station = await widget.api.request(
        'GET',
        'estacaoMetereologica/propriedade/${Uri.encodeComponent(farm.id)}',
      );
      if (!mounted || generation != _generation) return;
      if (station != null && station is! Map) {
        throw const ApiFailure('O servidor retornou uma estação inválida.');
      }
      final reference = station == null
          ? null
          : _StationLocation.fromRow(Map<String, dynamic>.from(station as Map));
      setState(() {
        _reference = reference;
        _referenceLoaded = true;
      });
      if (reference == null) return;
      final weather = await _weatherService.fetch(
        latitude: reference.latitude,
        longitude: reference.longitude,
      );
      if (mounted && generation == _generation) {
        setState(() => _weather = weather);
      }
    } on ApiFailure catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.message);
      }
    } on WeatherFailure catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = 'Não foi possível consultar o clima da fazenda.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final reference = _reference;
    final weather = _weather;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF393254)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_outlined, color: _cyan, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Clima da fazenda',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFF393254)),
          ),
          const Text(
            'Acompanhe as condições climáticas estimadas para a fazenda selecionada.',
            style: TextStyle(color: _muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _cyan.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'VIRTUAL',
                  style: TextStyle(color: _cyan, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Atualizar clima',
                onPressed: _loading ? null : _loadFarms,
                icon: const Icon(Icons.refresh, color: _cyan),
              ),
            ],
          ),
          if (selected != null) ...[
            if (_farms.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(selected.id),
                  initialValue: selected.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Fazenda',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final farm in _farms)
                      DropdownMenuItem(
                        value: farm.id,
                        child: Text(farm.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) {
                    if (id == null || id == selected.id) return;
                    _loadFarmWeather(
                      _farms.firstWhere((farm) => farm.id == id),
                    );
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  selected.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            if (selected.location != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  selected.location!,
                  style: const TextStyle(color: _muted),
                ),
              ),
            if (reference != null) ...[
              Text(
                'Referência climática: ${reference.name}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: _muted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${reference.latitude.toStringAsFixed(6)}, ${reference.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(color: _muted),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Carregando clima da fazenda',
                ),
              ),
            )
          else if (_error != null)
            Semantics(
              liveRegion: true,
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, color: _muted),
                  const SizedBox(height: 10),
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: selected == null
                        ? _loadFarms
                        : () => _loadFarmWeather(selected),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          else if (selected == null)
            Semantics(
              liveRegion: true,
              child: const Column(
                children: [
                  Text(
                    'Nenhuma fazenda disponível.',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'As fazendas são cadastradas no aplicativo web. Peça à equipe responsável para vincular sua fazenda à conta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                ],
              ),
            )
          else if (_referenceLoaded && reference == null)
            Semantics(
              liveRegion: true,
              child: const Column(
                children: [
                  Text(
                    'A fazenda selecionada não possui estação vinculada com coordenadas válidas.',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'A equipe responsável deve configurar o vínculo e as coordenadas no aplicativo web. Depois, atualize o painel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                ],
              ),
            )
          else if (weather != null)
            _CurrentWeather(weather: weather, clock: widget.clock),
          const SizedBox(height: 16),
          const SelectableText(
            'Fonte: Open-Meteo • open-meteo.com • CC BY 4.0',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Farm {
  const _Farm(this.id, this.name, this.location);
  final String id, name;
  final String? location;

  static _Farm? fromRow(Map<String, dynamic> row) {
    final id = row['id']?.toString().trim();
    if (id == null || id.isEmpty) return null;
    final name = row['nome']?.toString().trim();
    final location = row['localizacao']?.toString().trim();
    return _Farm(
      id,
      name == null || name.isEmpty ? 'Fazenda #$id' : name,
      location == null || location.isEmpty ? null : location,
    );
  }
}

class _StationLocation {
  const _StationLocation(this.id, this.name, this.latitude, this.longitude);
  final String id, name;
  final double latitude, longitude;

  static _StationLocation? fromRow(Map<String, dynamic> row) {
    double? coordinate(dynamic value) {
      final number = value is num
          ? value.toDouble()
          : double.tryParse(
              value?.toString().trim().replaceAll(',', '.') ?? '',
            );
      return number != null && number.isFinite ? number : null;
    }

    final latitude = coordinate(row['latitude']);
    final longitude = coordinate(row['longitude']);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    final name = row['nome']?.toString().trim();
    return _StationLocation(
      row['id']?.toString() ?? '$latitude,$longitude',
      name == null || name.isEmpty ? 'Estação cadastrada' : name,
      latitude,
      longitude,
    );
  }
}

class _CurrentWeather extends StatefulWidget {
  const _CurrentWeather({required this.weather, required this.clock});
  final WeatherSnapshot weather;
  final DateTime Function() clock;

  @override
  State<_CurrentWeather> createState() => _CurrentWeatherState();
}

class _CurrentWeatherState extends State<_CurrentWeather> {
  Timer? _clockTimer;
  late DateTime _localTime;

  DateTime _readLocalTime() {
    final offset = widget.weather.utcOffsetSeconds;
    if (offset == null) return widget.weather.stationLocalTime;
    return DateTime.fromMillisecondsSinceEpoch(
      widget.clock().toUtc().millisecondsSinceEpoch + offset * 1000,
      isUtc: true,
    );
  }

  void _startClock() {
    _clockTimer?.cancel();
    _localTime = _readLocalTime();
    if (widget.weather.utcOffsetSeconds == null) return;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _readLocalTime();
      if (next.year != _localTime.year ||
          next.month != _localTime.month ||
          next.day != _localTime.day ||
          next.hour != _localTime.hour ||
          next.minute != _localTime.minute) {
        setState(() => _localTime = next);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  @override
  void didUpdateWidget(covariant _CurrentWeather oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weather != widget.weather ||
        oldWidget.clock != widget.clock) {
      _startClock();
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String _value(double? value, String unit, {int decimals = 0}) => value == null
      ? 'Não informado'
      : '${value.toStringAsFixed(decimals).replaceAll('.', ',')}$unit';

  @override
  Widget build(BuildContext context) {
    final weather = widget.weather;
    const weekdays = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];
    final time = _localTime;
    final localTime =
        '${weekdays[time.weekday - 1]}, '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final dataTime =
        '${weather.time.hour.toString().padLeft(2, '0')}:${weather.time.minute.toString().padLeft(2, '0')}';
    final condition = _condition(weather.weatherCode, weather.isDay);
    final temperature = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cyan.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  condition.$1,
                  color: const Color(0xFFFFCE72),
                  size: 44,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _value(weather.temperature, '', decimals: 1),
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (weather.temperature != null)
                      const Text(
                        '°C',
                        style: TextStyle(color: _muted, fontSize: 24),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(condition.$2, style: const TextStyle(color: _muted)),
      ],
    );
    final metrics = Column(
      children: [
        _WeatherMetric(
          Icons.grain,
          'Chance de chuva na próxima hora',
          _value(weather.precipitationProbability, '%'),
        ),
        const SizedBox(height: 14),
        _WeatherMetric(
          Icons.water_drop_outlined,
          'Umidade',
          _value(weather.humidity, '%'),
        ),
        const SizedBox(height: 14),
        _WeatherMetric(
          Icons.air,
          'Vento',
          _value(weather.windSpeed, ' km/h', decimals: 1),
        ),
      ],
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1938),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF393254)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 8,
              children: [
                const Text(
                  'HORA LOCAL DA FAZENDA',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                Text(
                  localTime,
                  key: const Key('farm-local-time'),
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Dados meteorológicos de $dataTime',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Color(0xFF393254)),
            ),
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 480
                  ? Row(
                      children: [
                        Expanded(child: temperature),
                        const SizedBox(width: 28),
                        Expanded(child: metrics),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        temperature,
                        const SizedBox(height: 24),
                        metrics,
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Estimativas meteorológicas. A chance de chuva se refere ao intervalo horário indicado.',
              style: TextStyle(color: _muted, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

(IconData, String) _condition(int? code, bool? isDay) => switch (code) {
  0 => (
    isDay == false ? Icons.nightlight_round : Icons.wb_sunny_outlined,
    'Céu limpo',
  ),
  1 => (
    isDay == false ? Icons.nightlight_round : Icons.wb_sunny_outlined,
    'Predominantemente limpo',
  ),
  2 => (Icons.cloud_outlined, 'Parcialmente nublado'),
  3 => (Icons.cloud, 'Nublado'),
  45 || 48 => (Icons.blur_on, 'Neblina'),
  51 || 53 || 55 || 56 || 57 => (Icons.grain, 'Garoa'),
  61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => (Icons.grain, 'Chuva'),
  71 || 73 || 75 || 77 || 85 || 86 => (Icons.ac_unit_outlined, 'Neve'),
  95 || 96 || 97 || 99 => (Icons.thunderstorm_outlined, 'Trovoadas'),
  _ => (Icons.cloud_outlined, 'Condição não informada'),
};

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(child: Icon(icon, color: _cyan, size: 22)),
      const SizedBox(width: 10),
      Expanded(
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(label, style: const TextStyle(color: _muted)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ],
  );
}
