import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'farm_planting_screen.dart';
import 'open_meteo_service.dart';
import 'resource_schema.dart';
import 'resource_screen.dart';
import 'farm_weather_card.dart';
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
  int _dataGeneration = 0;
  late final ProfilePhotoService _photoService =
      widget.photoService ?? ProfilePhotoService();
  Uint8List? _photo;
  bool _photoBusy = false;
  int _photoGeneration = 0;
  @override
  void initState() {
    super.initState();
    widget.auth.api.onUnauthorized = () {
      if (mounted) widget.onLogout(context);
    };
    _load();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final generation = _photoGeneration;
    try {
      final photo = await _photoService.load(widget.email);
      if (mounted && generation == _photoGeneration) {
        setState(() => _photo = photo);
      }
    } catch (_) {
      // O perfil permanece utilizável quando o armazenamento local falha.
    }
  }

  Future<void> _choosePhoto() async {
    if (_photoBusy) return;
    _photoGeneration++;
    setState(() => _photoBusy = true);
    try {
      final photo = await _photoService.chooseAndSave(widget.email);
      if (mounted && photo != null) setState(() => _photo = photo);
    } catch (error) {
      if (mounted) {
        final message = error is ProfilePhotoFailure
            ? error.message
            : 'Não foi possível salvar a foto neste dispositivo.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    if (_photoBusy) return;
    _photoGeneration++;
    setState(() => _photoBusy = true);
    try {
      await _photoService.remove(widget.email);
      if (mounted) setState(() => _photo = null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível remover a foto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Widget _avatar(String name, {double radius = 26}) => CircleAvatar(
    backgroundColor: _surface,
    radius: radius,
    backgroundImage: _photo == null ? null : MemoryImage(_photo!),
    child: _photo == null
        ? Text(
            name.isEmpty ? 'G' : name.characters.first.toUpperCase(),
            style: const TextStyle(color: _cyan),
          )
        : null,
  );

  @override
  void dispose() {
    widget.auth.api.onUnauthorized = null;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_dataGeneration;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entries = await Future.wait([
        for (final path in [
          'propriedade',
          'dispositivoIrrigacao',
          'sensor',
          'recomendacao',
          'execucaoManejo',
          'configuracaoCusto',
        ])
          widget.auth.api.list(path).then((rows) => MapEntry(path, rows)),
      ]);
      if (mounted && generation == _dataGeneration) {
        setState(() {
          _data.clear();
          _data.addEntries(entries);
          final ids = rows('propriedade')
              .map((farm) => farm['id']?.toString())
              .whereType<String>()
              .toSet();
          if (!ids.contains(_selectedFarmId)) {
            _selectedFarmId = ids.isEmpty ? null : ids.first;
          }
        });
        unawaited(_loadFarmSectors());
      }
    } catch (e) {
      if (mounted && generation == _dataGeneration) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _dataGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _loadFarmSectors() async {
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
      _farmSectors = [];
    });
    try {
      final sectors = await widget.auth.api.list(
        'setor/propriedade/${Uri.encodeComponent(id)}',
      );
      if (mounted && generation == _farmSectorsGeneration) {
        setState(() => _farmSectors = sectors);
      }
    } catch (error) {
      if (mounted && generation == _farmSectorsGeneration) {
        setState(() => _farmSectorsError = error.toString());
      }
    } finally {
      if (mounted && generation == _farmSectorsGeneration) {
        setState(() => _farmSectorsBusy = false);
      }
    }
  }

  void _selectFarm(String? id) {
    if (id == _selectedFarmId) return;
    setState(() => _selectedFarmId = id);
    _loadFarmSectors();
  }

  List<Map<String, dynamic>> rows(String key) => _data[key] ?? [];
  Future<void> _open(ResourceSpec spec) async {
    if (spec.path == 'plantio') {
      await _openPlantings();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResourceScreen(
          api: widget.auth.api,
          spec: spec,
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

  double _sum(Iterable<Map<String, dynamic>> rows, String field) => rows.fold(
    0.0,
    (sum, row) => sum + ((row[field] as num?)?.toDouble() ?? 0),
  );
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
                        _avatar(name),
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
                    if (_tab == 2) _profile(name),
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
    final sensors = rows('sensor');
    final active = sensors.where((s) => s['status'] == 'ATIVO').length;
    final ring = _card(
      Column(
        children: [
          const Text(
            'SUA IRRIGAÇÃO, MAIS EFICIENTE',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 11, letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 240,
            height: 240,
            child: CustomPaint(
              painter: _ActivityRing(
                sensors.isEmpty ? 0 : active / sensors.length,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$active',
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
                      'de ${sensors.length} cadastrados',
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
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 800
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ring),
                    const SizedBox(width: 24),
                    Expanded(child: _pivots()),
                  ],
                )
              : Column(children: [ring, const SizedBox(height: 24), _pivots()]),
        ),
        const SizedBox(height: 24),
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
                      : '${_farmSectors.expand((s) => s['plantios'] is List ? s['plantios'] as List : const []).where((p) => p is Map && p['statusPlantio'] == 'EM_ANDAMENTO').length}',
                  Icons.grass,
                  'plantio',
                  width: cardWidth,
                  square: isMobile,
                ),
                _stat(
                  'Recomendações pendentes',
                  '${rows('recomendacao').where((r) => r['status'] == 'PENDENTE').length}',
                  Icons.tips_and_updates_outlined,
                  'recomendacao',
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
                    'Não foi possível carregar os setores desta fazenda.',
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

  Widget _pivots() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Seus pivôs e dispositivos',
              style: TextStyle(fontSize: 21, color: Colors.white),
            ),
          ),
          IconButton(
            tooltip: 'Ver dispositivos',
            onPressed: () => _open(resource('dispositivoIrrigacao')),
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (rows('dispositivoIrrigacao').isEmpty)
        _card(const Text('Nenhum dispositivo cadastrado para sua conta.')),
      if (rows('dispositivoIrrigacao').isNotEmpty)
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final row in rows('dispositivoIrrigacao').take(4))
                SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: AspectRatio(aspectRatio: 1, child: _deviceCard(row)),
                ),
            ],
          ),
        ),
    ],
  );

  Widget _deviceCard(Map<String, dynamic> row) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF393254)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.water_drop_outlined, color: _cyan, size: 22),
            const Spacer(),
            if (row['eficienciaIrrigacao'] is num)
              Text(
                '${_number(row['eficienciaIrrigacao'] as num)}%',
                style: const TextStyle(color: _green, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          row['nome']?.toString() ?? 'Dispositivo',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(
          displayValue(row['tipoDispositivo']),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
        Text(
          'Setor: ${displayValue(row['setor'])}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 10),
        ),
      ],
    ),
  );

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

  Widget _profile(String name) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Minha conta',
          style: TextStyle(fontSize: 26, color: Colors.white),
        ),
        const SizedBox(height: 24),
        Center(child: _avatar(name, radius: 48)),
        const SizedBox(height: 12),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _photoBusy ? null : _choosePhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(_photo == null ? 'Adicionar foto' : 'Alterar foto'),
              ),
              if (_photo != null)
                TextButton(
                  onPressed: _photoBusy ? null : _removePhoto,
                  child: const Text('Remover foto'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Nome', style: TextStyle(color: _muted)),
        Text(name, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 20),
        const Text('E-mail', style: TextStyle(color: _muted)),
        Text(widget.email),
        const SizedBox(height: 20),
        const Text('Perfil de acesso', style: TextStyle(color: _muted)),
        Text(displayValue(widget.auth.profile?['role'])),
        const SizedBox(height: 24),
        const Text(
          'Os dados do perfil são somente para consulta.',
          style: TextStyle(color: _muted),
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
  Widget _reports() {
    final executions = rows('execucaoManejo');
    final now = DateTime.now();
    final monthly = List.generate(6, (i) {
      final month = DateTime(now.year, now.month - 5 + i);
      final selected = executions.where((e) {
        final date = DateTime.tryParse(e['inicio']?.toString() ?? '');
        return date?.year == month.year && date?.month == month.month;
      });
      return (month, _sum(selected, 'volumeAguaAplicado'));
    });
    final maxValue = monthly.fold<double>(
      0,
      (value, entry) => math.max(value, entry.$2),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Relatórios',
          style: TextStyle(fontSize: 26, color: Colors.white),
        ),
        const SizedBox(height: 8),
        const Text(
          'Volume de água registrado nos últimos 6 meses',
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 24),
        _card(
          Column(
            children: [
              if (executions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Ainda não há execuções de manejo registradas.'),
                ),
              SizedBox(
                height: 220,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final entry in monthly)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FittedBox(
                                child: Text(
                                  _number(entry.$2),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: maxValue == 0
                                    ? 2
                                    : math.max(2, 160 * entry.$2 / maxValue),
                                width: 36,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Color(0xFF6634CE), _cyan],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
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
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recursos registrados • todo o período',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 14),
              Text('Execuções: ${executions.length}'),
              Text(
                'Volume de água: ${_number(_sum(executions, 'volumeAguaAplicado'))}',
              ),
              Text(
                'Energia gasta: ${_number(_sum(executions, 'energiaGasta'))}',
              ),
              const SizedBox(height: 14),
              const Text(
                'Os valores seguem a unidade informada nos registros. A economia financeira depende de uma referência de consumo, ainda não fornecida pelo serviço.',
                style: TextStyle(color: _muted),
              ),
              TextButton(
                onPressed: () => _open(resource('execucaoManejo')),
                child: const Text('Ver execuções'),
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
