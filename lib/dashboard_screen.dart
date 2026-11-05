import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';
import 'farm_planting_screen.dart';
import 'open_meteo_service.dart';
import 'resource_schema.dart';
import 'resource_screen.dart';
import 'farm_weather_card.dart';
import 'irrigation_control_screen.dart';
import 'profile_photo_service.dart';

const _background = Color(0xFF15142F);
const _surface = Color(0xFF242144);
const _muted = Color(0xFFA39DBF);
const _cyan = Color(0xFF36C9D8);
const _green = Color(0xFF65D99A);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.auth,
    required this.name,
    required this.email,
    required this.onLogout,
    this.weatherService,
    this.photoService,
  });
  final AuthService auth;
  final String name, email;
  final void Function(BuildContext) onLogout;
  final OpenMeteoService? weatherService;
  final ProfilePhotoService? photoService;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  bool _busy = true;
  String? _error;
  final _data = <String, List<Map<String, dynamic>>>{};
  String _moduleSearch = '';
  String? _selectedFarmId;
  List<Map<String, dynamic>> _farmSectors = [];
  bool _farmSectorsBusy = false;
  String? _farmSectorsError;
  int _farmSectorsGeneration = 0;
  List<Map<String, dynamic>> _irrigations = [];
  bool _irrigationsBusy = false;
  String? _irrigationsError;
  int _irrigationsGeneration = 0;
  int _dataGeneration = 0;
  Timer? _refreshTimer;
  bool _automaticRefreshInFlight = false;
  Uint8List? _profilePhoto;
  @override
  void initState() {
    super.initState();
    widget.auth.api.onUnauthorized = () {
      if (mounted) widget.onLogout(context);
    };
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_busy || _automaticRefreshInFlight || _farmSectorsBusy) return;
      _automaticRefreshInFlight = true;
      try {
        await _load(silent: true);
      } finally {
        _automaticRefreshInFlight = false;
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    widget.auth.api.onUnauthorized = null;
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_dataGeneration;
    if (!silent) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final entries = await Future.wait([
        for (final path in ['propriedade', 'sensor', 'recomendacao'])
          widget.auth.api.list(path).then((rows) => MapEntry(path, rows)),
      ]);
      if (mounted && generation == _dataGeneration) {
        final previousFarmId = _selectedFarmId;
        setState(() {
          _data.clear();
          _data.addEntries(entries);
          _error = null;
          final ids = rows('propriedade')
              .map((farm) => farm['id']?.toString())
              .whereType<String>()
              .toSet();
          if (!ids.contains(_selectedFarmId)) {
            _selectedFarmId = ids.isEmpty ? null : ids.first;
          }
        });
        _loadFarmIrrigations();
        await _loadFarmSectors(
          silent: silent && previousFarmId == _selectedFarmId,
        );
      }
    } catch (e) {
      if (mounted && generation == _dataGeneration) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (!silent && mounted && generation == _dataGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _loadFarmSectors({bool silent = false}) async {
    final id = _selectedFarmId;
    final generation = ++_farmSectorsGeneration;
    if (id == null) {
      if (mounted) {
        setState(() {
          _farmSectors = [];
          _farmSectorsBusy = false;
          _farmSectorsError = null;
        });
      }
      return;
    }
    setState(() {
      _farmSectorsBusy = true;
      _farmSectorsError = null;
      if (!silent) {
        _farmSectors = [];
      }
    });
    try {
      final sectors = await widget.auth.api.list(
        'setor/propriedade/${Uri.encodeComponent(id)}',
      );
      if (mounted && generation == _farmSectorsGeneration) {
        setState(() {
          _farmSectors = sectors;
          _farmSectorsError = null;
        });
      }
    } catch (error) {
      if (mounted && generation == _farmSectorsGeneration) {
        setState(() => _farmSectorsError = error.toString());
      }
    } finally {
      if (mounted && generation == _farmSectorsGeneration && _farmSectorsBusy) {
        setState(() => _farmSectorsBusy = false);
      }
    }
  }

  void _selectFarm(String? id) {
    if (id == _selectedFarmId) return;
    setState(() => _selectedFarmId = id);
    _loadFarmSectors();
    _loadFarmIrrigations();
  }

  Future<void> _loadFarmIrrigations() async {
    final id = _selectedFarmId;
    final generation = ++_irrigationsGeneration;
    if (id == null) {
      setState(() {
        _irrigations = [];
        _irrigationsBusy = false;
        _irrigationsError = null;
      });
      return;
    }
    setState(() {
      _irrigations = [];
      _irrigationsBusy = true;
      _irrigationsError = null;
    });
    try {
      final records = await widget.auth.api.list(
        'registroIrrigacao/propriedade/${Uri.encodeComponent(id)}',
      );
      if (!mounted ||
          generation != _irrigationsGeneration ||
          _selectedFarmId != id) {
        return;
      }
      setState(() => _irrigations = records);
    } catch (error) {
      if (mounted &&
          generation == _irrigationsGeneration &&
          _selectedFarmId == id) {
        setState(() => _irrigationsError = error.toString());
      }
    } finally {
      if (mounted &&
          generation == _irrigationsGeneration &&
          _selectedFarmId == id) {
        setState(() => _irrigationsBusy = false);
      }
    }
  }

  Future<void> _chooseProfilePhoto() async {
    try {
      final Uint8List? bytes;
      if (widget.photoService != null) {
        bytes = await widget.photoService!.chooseAndSave(widget.email);
      } else {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          imageQuality: 85,
        );
        bytes = await image?.readAsBytes();
      }
      if (bytes == null) return;
      if (mounted) setState(() => _profilePhoto = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir a foto.')),
      );
    }
  }

  Future<void> _removeProfilePhoto() async {
    try {
      await widget.photoService?.remove(widget.email);
      if (mounted) setState(() => _profilePhoto = null);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível remover a foto.')),
      );
    }
  }

  Iterable<Map<String, dynamic>> get _farmPlantings =>
      _farmSectors.expand((sector) {
        final plantings = sector['plantios'];
        if (plantings is! List) return <Map<String, dynamic>>[];
        return plantings.whereType<Map>().map(
          (row) => Map<String, dynamic>.from(row),
        );
      });

  List<Map<String, dynamic>> rows(String key) => _data[key] ?? [];
  Future<void> _open(ResourceSpec spec) async {
    if (spec.path == 'dispositivoIrrigacao') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => IrrigationControlScreen(
            api: widget.auth.api,
            selectedFarmId: _selectedFarmId,
            onFarmChanged: _selectFarm,
          ),
        ),
      );
      if (mounted && widget.auth.api.token != null) await _load();
      return;
    }
    if (spec.path == 'plantio') {
      await _openPlantings();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResourceScreen(
          api: widget.auth.api,
          spec: spec,
          canManage: widget.auth.canManage,
          header: spec.path == 'leituraClimatica'
              ? FarmWeatherCard(
                  api: widget.auth.api,
                  farms: rows('propriedade'),
                  weatherService: widget.weatherService,
                  selectedFarmId: _selectedFarmId,
                  onFarmChanged: _selectFarm,
                )
              : null,
        ),
      ),
    );
    if (mounted && widget.auth.api.token != null) await _load();
  }

  Future<void> _openPlantings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FarmPlantingScreen(
          api: widget.auth.api,
          farms: rows('propriedade'),
          canManagePlantings: widget.auth.canManagePlantings,
          selectedFarmId: _selectedFarmId,
          onFarmChanged: _selectFarm,
        ),
      ),
    );
    if (mounted && widget.auth.api.token != null) await _load();
  }

  void _notifications() {
    final pending = rows('recomendacao')
        .where((r) => r['status'] == 'PENDENTE')
        .length;
    final low = rows('sensor')
        .where(
          (r) => r['nivelBateria'] is num && (r['nivelBateria'] as num) < 20,
        )
        .length;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atenção no campo'),
        content: Text(
          _error != null
              ? 'Não foi possível atualizar os avisos. Tente atualizar o painel.'
              : '$pending recomendações pendentes.\n$low sensores com bateria abaixo de 20%.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  String _number(num n) =>
      n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2).replaceAll('.', ',');
  @override
  Widget build(BuildContext context) {
    final profile = widget.auth.profile;
    final name = profile?['nome'] as String? ?? widget.name;
    return Scaffold(
      backgroundColor: _background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_background, Color(0xFF282347)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: _chooseProfilePhoto,
                          customBorder: const CircleBorder(),
                          child: CircleAvatar(
                            backgroundColor: _surface,
                            backgroundImage: _profilePhoto == null
                                ? null
                                : MemoryImage(_profilePhoto!),
                            radius: 26,
                            child: _profilePhoto == null
                                ? Text(
                                    name.isEmpty
                                        ? 'G'
                                        : name.characters.first.toUpperCase(),
                                    style: const TextStyle(color: _cyan),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bem-vindo!',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: _muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Atualizar painel',
                          onPressed: _busy ? null : _load,
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          tooltip: 'Notificações',
                          onPressed: _notifications,
                          icon: const Icon(Icons.notifications_none_rounded),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Mais opções',
                          onSelected: (_) => widget.onLogout(context),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'logout',
                              child: Text('Sair da conta'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (_tab == 0) ...[
                      if (_busy) const LinearProgressIndicator(),
                      if (_error != null)
                        ErrorPanel(message: _error!, retry: _load),
                      if (!_busy && _error == null) _home(),
                    ],
                    if (_tab == 1) _modules(),
                    if (_tab == 2)
                      _profile(name, _profilePhoto, _chooseProfilePhoto),
                    if (_tab == 3) ...[
                      if (_busy) const LinearProgressIndicator(),
                      if (_error != null)
                        ErrorPanel(message: _error!, retry: _load),
                      if (!_busy && _error == null) _reports(),
                    ],
                    const SizedBox(height: 32),
                    const Text(
                      'GHYDRO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: _surface,
        indicatorColor: _cyan.withValues(alpha: 0.18),
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() => _tab = tab),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Gestão',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Relatórios',
          ),
        ],
      ),
    );
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF393254)),
    ),
    child: child,
  );
  Widget _home() {
    final sectorIds = _farmSectors
        .map((sector) => sector['id']?.toString())
        .whereType<String>()
        .toSet();
    final sensors = rows('sensor').where((sensor) {
      final sector = sensor['setor'];
      return sector is Map && sectorIds.contains(sector['id']?.toString());
    }).toList();
    final active = sensors.where((s) => s['status'] == 'ATIVO').length;
    final sensorCountsAvailable =
        _selectedFarmId != null &&
        !_farmSectorsBusy &&
        _farmSectorsError == null;
    final ring = _card(
      Column(
        children: [
          const Text(
            'MONITORAMENTO DE SENSORES',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 11, letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 240,
            height: 240,
            child: CustomPaint(
              painter: _ActivityRing(
                !sensorCountsAvailable || sensors.isEmpty
                    ? 0
                    : active / sensors.length,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sensorCountsAvailable ? '$active' : '--',
                      style: const TextStyle(
                        color: _green,
                        fontSize: 46,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Sensores ativos',
                      style: TextStyle(color: _muted),
                    ),
                    Text(
                      sensorCountsAvailable
                          ? 'de ${sensors.length} cadastrados'
                          : 'Dados dos setores indisponíveis',
                      style: const TextStyle(color: _cyan),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Text(
            'Dados registrados no servidor',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Início',
          style: TextStyle(fontSize: 26, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'Atualização automática a cada 60 segundos',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 16),
        if (rows('propriedade').isNotEmpty) ...[
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedFarmId),
            initialValue: _selectedFarmId,
            decoration: const InputDecoration(
              labelText: 'Fazenda',
              border: OutlineInputBorder(),
            ),
            isExpanded: true,
            items: [
              for (final farm in rows('propriedade'))
                if (farm['id'] != null)
                  DropdownMenuItem(
                    value: farm['id'].toString(),
                    child: Text(
                      farm['nome']?.toString() ?? 'Fazenda',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            ],
            onChanged: _selectFarm,
          ),
          const SizedBox(height: 16),
        ],
        ring,
        const SizedBox(height: 24),
        const Text(
          'Visão Geral',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Monitoramento Geral — resumo de fazendas, setores, plantios e sensores',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final columns = isMobile
                ? 2
                : (constraints.maxWidth / 257).floor().clamp(2, 4);
            final cardWidth =
                (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _stat(
                  'Propriedades',
                  '${rows('propriedade').length}',
                  Icons.landscape_outlined,
                  'propriedade',
                  width: cardWidth,
                  square: isMobile,
                ),
                _stat(
                  'Setores',
                  _farmSectorsBusy || _farmSectorsError != null
                      ? '--'
                      : '${_farmSectors.length}',
                  Icons.grid_view,
                  'setor',
                  width: cardWidth,
                  square: isMobile,
                ),
                _stat(
                  'Plantios em andamento',
                  _farmSectorsBusy || _farmSectorsError != null
                      ? '--'
                      : '${_farmPlantings.where((planting) => planting['statusPlantio'] == 'EM_ANDAMENTO').length}',
                  Icons.grass,
                  'plantio',
                  width: cardWidth,
                  square: isMobile,
                ),
                _stat(
                  'Sensores ativos',
                  _farmSectorsBusy || _farmSectorsError != null
                      ? '--'
                      : '$active',
                  Icons.sensors,
                  'sensor',
                  width: cardWidth,
                  square: isMobile,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        if (_farmSectorsError != null) ...[
          _card(
            Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Não foi possível carregar as safras desta fazenda.',
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadFarmSectors,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (rows('propriedade').isEmpty)
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comece pela sua fazenda',
                  style: TextStyle(fontSize: 21, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text(
                  'As fazendas e estações são cadastradas no aplicativo web. Peça à equipe responsável para vincular sua fazenda à conta e atualize o painel.',
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Atualizar painel'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stat(
    String label,
    String value,
    IconData icon,
    String path, {
    required double width,
    required bool square,
  }) {
    return SizedBox(
      width: width,
      height: square ? width : null,
      child: Card(
        color: _surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(resource(path)),
          child: Padding(
            padding: EdgeInsets.all(square ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: _cyan, size: square ? 20 : 24),
                SizedBox(height: square ? 6 : 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: square ? 24 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  maxLines: square ? 2 : null,
                  overflow: square ? TextOverflow.ellipsis : null,
                  style: TextStyle(color: _muted, fontSize: square ? 12 : 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modules() {
    final available = resources
        .where(
          (r) =>
              (!r.staffOnly || widget.auth.canManage) &&
              r.title.toLowerCase().contains(_moduleSearch.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Gestão da fazenda',
          style: TextStyle(fontSize: 26, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tudo que você precisa acompanhar, em um só lugar.',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 20),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Encontrar uma seção',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _moduleSearch = value),
        ),
        const SizedBox(height: 24),
        for (final group in available.map((r) => r.group).toSet()) ...[
          Text(
            group.toUpperCase(),
            style: const TextStyle(
              color: _cyan,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          for (final spec in available.where((r) => r.group == group))
            Card(
              color: _surface,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(spec.icon, color: _cyan),
                title: Text(spec.title),
                subtitle: Text(spec.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(spec),
              ),
            ),
          const SizedBox(height: 20),
        ],
        if (available.isEmpty) const Text('Nenhuma seção encontrada.'),
      ],
    );
  }

  Widget _profile(String name, Uint8List? photo, VoidCallback choosePhoto) =>
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Minha conta',
              style: TextStyle(fontSize: 26, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: _surface,
                    backgroundImage: photo == null ? null : MemoryImage(photo),
                    child: photo == null
                        ? Text(
                            name.isEmpty
                                ? 'G'
                                : name.characters.first.toUpperCase(),
                            style: const TextStyle(color: _cyan, fontSize: 30),
                          )
                        : null,
                  ),
                  TextButton.icon(
                    onPressed: choosePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      photo == null ? 'Adicionar foto' : 'Alterar foto',
                    ),
                  ),
                  if (photo != null)
                    TextButton(
                      onPressed: _removeProfilePhoto,
                      child: const Text('Remover foto'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Nome', style: TextStyle(color: _muted)),
            Text(name, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            const Text('E-mail', style: TextStyle(color: _muted)),
            Text(widget.email),
            const SizedBox(height: 20),
            const Text('Perfil de acesso', style: TextStyle(color: _muted)),
            Text(displayValue(widget.auth.profile?['role'])),
            const SizedBox(height: 20),
            const Text('CPF', style: TextStyle(color: _muted)),
            Text(displayValue(widget.auth.profile?['cpf'])),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => _ProfileEditor(auth: widget.auth),
                  ),
                );
                if (changed == true && mounted) setState(() {});
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar perfil'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => widget.onLogout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
            ),
          ],
        ),
      );
  double? _durationHours(Map<String, dynamic> row) {
    final minutes = _recordedValue(row, 'duracaoMinutos');
    return minutes == null ? null : minutes / 60;
  }

  double? _recordedValue(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! num || !value.isFinite || value < 0) return null;
    return value.toDouble();
  }

  double? _totalValues(Iterable<double?> values) {
    final present = values.whereType<double>();
    if (present.isEmpty) return null;
    return present.fold<double>(0, (sum, value) => sum + value);
  }

  String _shownValue(double? value) =>
      value == null ? 'Não informado' : _number(value);

  Widget _reports() {
    final executions = _irrigations;
    if (_selectedFarmId == null) {
      return const Text('Selecione uma fazenda para consultar os relatórios.');
    }
    if (_irrigationsBusy) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_irrigationsError != null) {
      return ErrorPanel(
        message:
            'Não foi possível carregar os registros de irrigação da fazenda.',
        retry: _loadFarmIrrigations,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Relatórios',
          style: TextStyle(fontSize: 26, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'Irrigações da fazenda selecionada nos últimos 6 meses',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 20),
        if (executions.isEmpty) ...[
          _card(
            const Text(
              'Ainda não há irrigações registradas para esta fazenda.',
            ),
          ),
          const SizedBox(height: 20),
        ],
        _monthlyChart(
          'Duração das irrigações (horas)',
          executions,
          _durationHours,
        ),
        const SizedBox(height: 20),
        _monthlyChart(
          'Volume de água estimado',
          executions,
          (row) => _recordedValue(row, 'volumeAgua'),
        ),
        const SizedBox(height: 20),
        _monthlyChart(
          'Energia estimada',
          executions,
          (row) => _recordedValue(row, 'consumoEnergia'),
        ),
        const SizedBox(height: 20),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Irrigações registradas • todo o período',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 14),
              Text('Irrigações: ${executions.length}'),
              Text(
                'Duração: ${_shownValue(_totalValues(executions.map(_durationHours)))} horas',
              ),
              Text(
                'Volume de água estimado: ${_shownValue(_totalValues(executions.map((row) => _recordedValue(row, 'volumeAgua'))))}',
              ),
              Text(
                'Energia estimada: ${_shownValue(_totalValues(executions.map((row) => _recordedValue(row, 'consumoEnergia'))))}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Água e energia são estimativas calculadas pelo servidor a partir da configuração do equipamento.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 8),
              const Text(
                'Os registros antigos de manejo podem ser consultados separadamente.',
                style: TextStyle(color: _muted),
              ),
              TextButton(
                onPressed: () => _open(resource('execucaoManejo')),
                child: const Text('Ver registros de manejo anteriores'),
              ),
              TextButton(
                onPressed: () => _open(resource('configuracaoCusto')),
                child: const Text('Ver tarifas por propriedade'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monthlyChart(
    String title,
    List<Map<String, dynamic>> executions,
    double? Function(Map<String, dynamic>) valueOf,
  ) {
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    final now = DateTime.now();
    final monthly = List.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index);
      final selected = executions.where((row) {
        final date = DateTime.tryParse(row['dataIrrigacao']?.toString() ?? '');
        return date?.year == month.year && date?.month == month.month;
      });
      return (month, _totalValues(selected.map(valueOf)));
    });
    final maximum = monthly.fold<double>(
      0,
      (value, entry) => math.max(value, entry.$2 ?? 0),
    );
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final entry in monthly)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Semantics(
                        label:
                            '${months[entry.$1.month - 1]}: ${_shownValue(entry.$2)}',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FittedBox(
                              child: Text(
                                entry.$2 == null ? '—' : _number(entry.$2!),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: maximum == 0 || entry.$2 == null
                                  ? 2
                                  : math.max(2, 140 * entry.$2! / maximum),
                              width: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: _cyan,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              months[entry.$1.month - 1],
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '— indica ausência de dados.',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ActivityRing extends CustomPainter {
  _ActivityRing(this.fraction);
  final double fraction;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width * .38,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      paint..color = const Color(0xFF393254),
    );
    if (fraction > 0) {
      paint.shader = const SweepGradient(
        colors: [_green, _cyan, Color(0xFF6634CE), _green],
      ).createShader(rect);
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, paint);
    }
  }

  @override
  bool shouldRepaint(_ActivityRing oldDelegate) =>
      fraction != oldDelegate.fraction;
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.auth});
  final AuthService auth;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final _name = TextEditingController(
    text: widget.auth.profile?['nome'] as String?,
  );
  late final _cpf = TextEditingController(
    text: widget.auth.profile?['cpf'] as String?,
  );
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _cpf.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.auth.updateProfile(_name.text, _cpf.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Informe seu nome.'
                      : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _cpf,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'CPF (opcional)',
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFFFB4AB)),
                  ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Salvando…' : 'Salvar perfil'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
