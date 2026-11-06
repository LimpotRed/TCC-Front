import 'package:flutter/material.dart';

import 'app_theme.dart';

import 'api_client.dart';
import 'irrigation_history_screen.dart';
import 'irrigation_screen.dart';

/// Acesso ao registro de irrigação para a fazenda selecionada.
class IrrigationControlScreen extends StatefulWidget {
  const IrrigationControlScreen({
    super.key,
    required this.api,
    this.selectedFarmId,
    this.onFarmChanged,
  });

  final ApiClient api;
  final String? selectedFarmId;
  final ValueChanged<String?>? onFarmChanged;

  @override
  State<IrrigationControlScreen> createState() =>
      _IrrigationControlScreenState();
}

class _IrrigationControlScreenState extends State<IrrigationControlScreen> {
  List<Map<String, dynamic>> _farms = [];
  List<Map<String, dynamic>> _sectors = [];
  String? _farmId;
  String? _farmError;
  String? _sectorError;
  bool _loadingFarms = true;
  bool _loadingSectors = false;
  int _farmGeneration = 0;
  int _sectorGeneration = 0;

  @override
  void initState() {
    super.initState();
    _farmId = widget.selectedFarmId;
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    final generation = ++_farmGeneration;
    ++_sectorGeneration;
    setState(() {
      _loadingFarms = true;
      _loadingSectors = false;
      _farmError = null;
      _sectorError = null;
      _sectors = [];
    });
    try {
      final rows = await widget.api.list('propriedade');
      if (!mounted || generation != _farmGeneration) return;
      // IDs devem ser únicos para o seletor, mesmo se a API repetir uma linha.
      final farmsById = <String, Map<String, dynamic>>{};
      for (final farm in rows) {
        final id = farm['id'];
        if (id != null) farmsById[id.toString()] = farm;
      }
      final previousId = _farmId;
      final nextId = farmsById.containsKey(previousId)
          ? previousId
          : farmsById.keys.firstOrNull;
      setState(() {
        _farms = farmsById.values.toList();
        _farmId = nextId;
        _loadingFarms = false;
      });
      if (previousId != nextId) widget.onFarmChanged?.call(nextId);
      if (nextId != null) await _loadSectors(nextId);
    } catch (error) {
      if (!mounted || generation != _farmGeneration) return;
      setState(() {
        _farmError = error.toString();
        _loadingFarms = false;
      });
    }
  }

  Future<void> _loadSectors(String farmId) async {
    final generation = ++_sectorGeneration;
    setState(() {
      _loadingSectors = true;
      _sectorError = null;
      _sectors = [];
    });
    try {
      final sectors = await widget.api.list(
        'setor/propriedade/${Uri.encodeComponent(farmId)}',
      );
      if (!mounted || generation != _sectorGeneration || _farmId != farmId) {
        return;
      }
      setState(() => _sectors = sectors);
    } catch (error) {
      if (!mounted || generation != _sectorGeneration || _farmId != farmId) {
        return;
      }
      setState(() => _sectorError = error.toString());
    } finally {
      if (mounted && generation == _sectorGeneration && _farmId == farmId) {
        setState(() => _loadingSectors = false);
      }
    }
  }

  void _selectFarm(String? id) {
    if (id == null || id == _farmId) return;
    setState(() => _farmId = id);
    widget.onFarmChanged?.call(id);
    _loadSectors(id);
  }

  Future<void> _registerIrrigation() async {
    final farmId = _farmId;
    final matchingFarms = _farms.where(
      (farm) => farm['id']?.toString() == farmId,
    );
    if (farmId == null ||
        matchingFarms.isEmpty ||
        _loadingSectors ||
        _sectorError != null ||
        _sectors.isEmpty) {
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => IrrigationScreen(
          api: widget.api,
          farm: matchingFarms.first,
          sectors: List.of(_sectors),
        ),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Irrigação registrada com sucesso.')),
    );
    if (_farmId == farmId) {
      await _loadSectors(farmId);
    }
  }

  void _openHistory() {
    final farmId = _farmId;
    final farms = _farms.where((farm) => farm['id']?.toString() == farmId);
    if (farmId == null || farms.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IrrigationHistoryScreen(
          api: widget.api,
          farmId: farmId,
          farmName: farms.first['nome']?.toString() ?? 'Fazenda',
        ),
      ),
    );
  }

  Widget _message(String message, {VoidCallback? retry}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.of(context).surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        if (retry != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: retry, child: const Text('Tentar novamente')),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.of(context).background,
    appBar: AppBar(title: const Text('Controle de irrigação')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_loadingFarms)
              const Center(child: CircularProgressIndicator())
            else if (_farmError != null)
              _message(
                'Não foi possível carregar as fazendas. $_farmError',
                retry: _loadFarms,
              )
            else if (_farms.isEmpty)
              _message(
                'Nenhuma fazenda disponível. Solicite à equipe responsável que vincule uma fazenda à sua conta.',
              )
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey(_farmId),
                initialValue: _farmId,
                decoration: const InputDecoration(
                  labelText: 'Fazenda',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: [
                  for (final farm in _farms)
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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.of(context).surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.of(context).border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.water_drop_outlined,
                          color: AppColors.of(context).cyan,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Controle de Irrigação',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registre o tempo de funcionamento e acompanhe o consumo de água e energia.',
                      style: TextStyle(color: AppColors.of(context).muted),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingSectors)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      )
                    else if (_sectorError != null) ...[
                      Text(
                        'Não foi possível carregar os setores. $_sectorError',
                      ),
                      TextButton(
                        onPressed: () => _loadSectors(_farmId!),
                        child: const Text('Tentar novamente'),
                      ),
                    ] else if (_sectors.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('Nenhum setor disponível nesta fazenda.'),
                      ),
                    FilledButton.icon(
                      onPressed:
                          _loadingSectors ||
                              _sectorError != null ||
                              _sectors.isEmpty
                          ? null
                          : _registerIrrigation,
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar irrigação'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _openHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('Histórico de irrigação'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
