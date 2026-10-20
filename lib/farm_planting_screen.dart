import 'package:flutter/material.dart';

import 'api_client.dart';
import 'resource_schema.dart';

const _surface = Color(0xFF242144);
const _muted = Color(0xFFA39DBF);
const _cyan = Color(0xFF36C9D8);
const _green = Color(0xFF65D99A);

String _date(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return 'Não informado';
  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}

String _iso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _text(dynamic value, [String fallback = 'Não informado']) {
  final result = value?.toString().trim();
  return result == null || result.isEmpty ? fallback : result;
}

/// Safras da fazenda selecionada. Setores são cadastrados no sistema web.
class FarmPlantingScreen extends StatefulWidget {
  const FarmPlantingScreen({
    super.key,
    required this.api,
    required this.farms,
    this.selectedFarmId,
    this.onFarmChanged,
  });

  final ApiClient api;
  final List<Map<String, dynamic>> farms;
  final String? selectedFarmId;
  final ValueChanged<String?>? onFarmChanged;

  @override
  State<FarmPlantingScreen> createState() => _FarmPlantingScreenState();
}

class _FarmPlantingScreenState extends State<FarmPlantingScreen> {
  String? _farmId;
  List<Map<String, dynamic>> _sectors = [];
  bool _busy = false;
  String? _error;
  int _generation = 0;

  List<Map<String, dynamic>> get _farms =>
      widget.farms.where((farm) => farm['id'] != null).toList(growable: false);

  @override
  void initState() {
    super.initState();
    final farms = _farms;
    final ids = farms.map((farm) => farm['id'].toString()).toSet();
    _farmId = ids.contains(widget.selectedFarmId)
        ? widget.selectedFarmId
        : (farms.isEmpty ? null : farms.first['id'].toString());
    if (_farmId != null) _load();
  }

  String _path(String sectorId) =>
      'propriedade/${Uri.encodeComponent(_farmId!)}/safras/setores/${Uri.encodeComponent(sectorId)}';

  Future<void> _load() async {
    final farmId = _farmId;
    final generation = ++_generation;
    if (farmId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sectors = await widget.api.list(
        'propriedade/${Uri.encodeComponent(farmId)}/safras/setores',
      );
      if (mounted && generation == _generation) {
        setState(() => _sectors = sectors);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
      }
    }
  }

  void _selectFarm(String? id) {
    if (id == null || id == _farmId) return;
    setState(() {
      _farmId = id;
      _sectors = [];
    });
    widget.onFarmChanged?.call(id);
    _load();
  }

  Future<void> _createPlanting(Map<String, dynamic> sector) async {
    final sectorId = sector['id']?.toString();
    if (sectorId == null || _farmId == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CreatePlantingDialog(
        api: widget.api,
        path: '${_path(sectorId)}/plantios',
        sectorName: _text(sector['nome'], 'Setor #$sectorId'),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plantio registrado com sucesso.')),
      );
      await _load();
    }
  }

  Future<void> _registerHarvest(
    Map<String, dynamic> sector,
    Map<String, dynamic> planting,
  ) async {
    final sectorId = sector['id']?.toString();
    final plantingId = planting['id']?.toString();
    if (sectorId == null || plantingId == null || _farmId == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _HarvestDialog(
        api: widget.api,
        path:
            '${_path(sectorId)}/plantios/${Uri.encodeComponent(plantingId)}/colheita',
        cultureName: _text(planting['culturaNome']),
        plantingDate: DateTime.tryParse(
          planting['dataPlantio']?.toString() ?? '',
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Colheita registrada com sucesso.')),
      );
      await _load();
    }
  }

  void _showHistory(Map<String, dynamic> sector) {
    final sectorId = sector['id']?.toString();
    if (sectorId == null || _farmId == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => _HistoryDialog(
        api: widget.api,
        path: '${_path(sectorId)}/historico',
        sectorName: _text(sector['nome'], 'Setor #$sectorId'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final farms = _farms;
    final selectedFarm = farms.where((row) => row['id'].toString() == _farmId);
    return Scaffold(
      backgroundColor: const Color(0xFF15142F),
      appBar: AppBar(
        title: const Text('Plantio em andamento'),
        actions: [
          IconButton(
            tooltip: 'Atualizar setores',
            onPressed: _busy || _farmId == null ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                children: [
                  const Text(
                    'Gestão de safras e plantios',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Acompanhe a safra atual e o histórico produtivo de cada setor.',
                    style: TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 20),
                  if (farms.length > 1)
                    DropdownButtonFormField<String>(
                      key: ValueKey(_farmId),
                      initialValue: _farmId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Fazenda',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final farm in farms)
                          DropdownMenuItem(
                            value: farm['id'].toString(),
                            child: Text(
                              _text(farm['nome'], 'Fazenda #${farm['id']}'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _selectFarm,
                    )
                  else if (selectedFarm.isNotEmpty)
                    Text(
                      _text(selectedFarm.first['nome']),
                      style: const TextStyle(
                        color: _cyan,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_farmId == null)
                    const _MessageCard(
                      'Nenhuma fazenda está vinculada à sua conta. Solicite o vínculo no sistema web.',
                    )
                  else if (_busy)
                    const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Carregando setores da fazenda',
                      ),
                    )
                  else if (_error != null)
                    _MessageCard(
                      _error!,
                      action: TextButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    )
                  else if (_sectors.isEmpty)
                    const _MessageCard(
                      'Esta fazenda ainda não possui setores. O cadastro de setores é feito no sistema web.',
                    )
                  else ...[
                    Text(
                      '${_sectors.length} ${_sectors.length == 1 ? 'setor' : 'setores'} nesta fazenda',
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 12),
                    for (final sector in _sectors) ...[
                      _sectorCard(sector),
                      const SizedBox(height: 14),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectorCard(Map<String, dynamic> sector) {
    final planting = sector['plantioAtivo'] is Map
        ? Map<String, dynamic>.from(sector['plantioAtivo'] as Map)
        : null;
    final active = planting != null;
    return Card(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF393254)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: _cyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _text(sector['nome'], 'Setor #${sector['id']}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _StatusPill(
                    planting?['statusPlantio'] == 'PLANEJADO'
                        ? 'Planejado'
                        : active
                        ? 'Safra ativa'
                        : 'Em descanso',
                    planting?['statusPlantio'] == 'PLANEJADO'
                        ? _cyan
                        : active
                        ? _green
                        : _muted,
                  ),
                ),
              ],
            ),
            const Divider(height: 30, color: Color(0xFF393254)),
            const Text(
              'SAFRA ATUAL',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1938),
                borderRadius: BorderRadius.circular(14),
              ),
              child: active
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _text(planting['culturaNome']),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Plantio: ${_date(planting['dataPlantio'])}'),
                        Text(
                          'Colheita estimada: ${_date(planting['dataColheitaEstimada'])}',
                        ),
                        Text(
                          'Situação: ${displayValue(planting['statusPlantio'])}',
                        ),
                        const SizedBox(height: 14),
                        if (planting['statusPlantio'] == 'EM_ANDAMENTO')
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _registerHarvest(sector, planting),
                              icon: const Icon(Icons.task_alt),
                              label: const Text('Registrar colheita'),
                            ),
                          )
                        else
                          const Text(
                            'A colheita estará disponível quando o plantio estiver em andamento.',
                            style: TextStyle(color: _muted),
                          ),
                      ],
                    )
                  : Column(
                      children: [
                        const Icon(
                          Icons.grass_outlined,
                          color: _muted,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'O solo deste setor está em descanso.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _createPlanting(sector),
                          icon: const Icon(Icons.add),
                          label: const Text('Cadastrar plantação'),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showHistory(sector),
                icon: const Icon(Icons.history),
                label: const Text('Ver histórico produtivo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard(this.message, {this.action});
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: _surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [Text(message), ?action]),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      maxLines: 2,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    child: Row(
      children: [
        const Icon(Icons.calendar_today, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

class _CreatePlantingDialog extends StatefulWidget {
  const _CreatePlantingDialog({
    required this.api,
    required this.path,
    required this.sectorName,
  });
  final ApiClient api;
  final String path;
  final String sectorName;

  @override
  State<_CreatePlantingDialog> createState() => _CreatePlantingDialogState();
}

class _CreatePlantingDialogState extends State<_CreatePlantingDialog> {
  List<Map<String, dynamic>> _cultures = [];
  String? _cultureId;
  DateTime _plantingDate = DateTime.now();
  DateTime? _estimatedDate;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCultures();
  }

  Future<void> _loadCultures() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cultures = await widget.api.list('cultura');
      if (mounted) {
        setState(
          () => _cultures = cultures.where((c) => c['id'] != null).toList(),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool estimated}) async {
    final initial = estimated
        ? (_estimatedDate ?? _plantingDate)
        : _plantingDate;
    final chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: estimated ? DateTime(2100) : DateTime.now(),
    );
    if (!mounted || chosen == null) return;
    setState(() {
      if (estimated) {
        _estimatedDate = chosen;
      } else {
        _plantingDate = chosen;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final cultureId = int.tryParse(_cultureId ?? '');
    if (cultureId == null) {
      setState(() => _error = 'Selecione a cultura.');
      return;
    }
    if (_plantingDate.isAfter(DateTime.now())) {
      setState(() => _error = 'A data do plantio não pode ser futura.');
      return;
    }
    if (_estimatedDate != null && !_estimatedDate!.isAfter(_plantingDate)) {
      setState(() => _error = 'A colheita estimada deve ser após o plantio.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.request(
        'POST',
        widget.path,
        body: {
          'culturaId': cultureId,
          'dataPlantio': _iso(_plantingDate),
          if (_estimatedDate != null)
            'dataColheitaEstimada': _iso(_estimatedDate!),
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text('Cadastrar plantação — ${widget.sectorName}'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (!_loading && _cultures.isEmpty && _error == null)
                const Text(
                  'Nenhuma cultura cadastrada. Solicite o cadastro no sistema web.',
                ),
              if (_cultures.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _cultureId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cultura'),
                  items: [
                    for (final culture in _cultures)
                      DropdownMenuItem(
                        value: culture['id'].toString(),
                        child: Text(
                          _text(
                            culture['nomePopular'],
                            'Cultura #${culture['id']}',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (id) => setState(() => _cultureId = id),
                ),
              const SizedBox(height: 16),
              _DateButton(
                onPressed: _saving ? null : () => _pickDate(estimated: false),
                label: 'Data do plantio: ${_date(_iso(_plantingDate))}',
              ),
              const SizedBox(height: 8),
              _DateButton(
                onPressed: _saving ? null : () => _pickDate(estimated: true),
                label: _estimatedDate == null
                    ? 'Informar colheita estimada (opcional)'
                    : 'Colheita estimada: ${_date(_iso(_estimatedDate!))}',
              ),
              if (_estimatedDate != null)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _estimatedDate = null),
                  child: const Text('Limpar data estimada'),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                if (!_loading && _cultures.isEmpty)
                  TextButton.icon(
                    onPressed: _loadCultures,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading || _saving || _cultures.isEmpty ? null : _save,
          child: Text(_saving ? 'Salvando...' : 'Confirmar plantio'),
        ),
      ],
    ),
  );
}

class _HarvestDialog extends StatefulWidget {
  const _HarvestDialog({
    required this.api,
    required this.path,
    required this.cultureName,
    required this.plantingDate,
  });
  final ApiClient api;
  final String path;
  final String cultureName;
  final DateTime? plantingDate;

  @override
  State<_HarvestDialog> createState() => _HarvestDialogState();
}

class _HarvestDialogState extends State<_HarvestDialog> {
  DateTime _harvestDate = DateTime.now();
  bool _saving = false;
  String? _error;

  Future<void> _pickDate() async {
    final today = DateTime.now();
    if (widget.plantingDate != null && widget.plantingDate!.isAfter(today)) {
      setState(() => _error = 'O plantio ainda não pode ser colhido.');
      return;
    }
    final chosen = await showDatePicker(
      context: context,
      initialDate: _harvestDate,
      firstDate: widget.plantingDate ?? DateTime(1900),
      lastDate: today,
    );
    if (mounted && chosen != null) setState(() => _harvestDate = chosen);
  }

  Future<void> _save() async {
    if (widget.plantingDate != null &&
        _harvestDate.isBefore(widget.plantingDate!)) {
      setState(() => _error = 'A colheita não pode anteceder o plantio.');
      return;
    }
    if (_harvestDate.isAfter(DateTime.now())) {
      setState(() => _error = 'A data da colheita não pode ser futura.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.request(
        'POST',
        widget.path,
        body: {'dataColheita': _iso(_harvestDate)},
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Registrar colheita'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cultura: ${widget.cultureName}'),
              const SizedBox(height: 16),
              _DateButton(
                onPressed: _saving ? null : _pickDate,
                label: 'Data da colheita: ${_date(_iso(_harvestDate))}',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvando...' : 'Confirmar colheita'),
        ),
      ],
    ),
  );
}

class _HistoryDialog extends StatefulWidget {
  const _HistoryDialog({
    required this.api,
    required this.path,
    required this.sectorName,
  });
  final ApiClient api;
  final String path;
  final String sectorName;

  @override
  State<_HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<_HistoryDialog> {
  List<Map<String, dynamic>> _rows = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.api.list(widget.path);
      if (mounted) setState(() => _rows = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820, maxHeight: 620),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.sectorName,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar histórico',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (!_loading && _error == null)
              Text(
                'Total de plantios: ${_rows.length}',
                style: const TextStyle(color: _muted),
              ),
            const SizedBox(height: 14),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              _MessageCard(
                _error!,
                action: TextButton(
                  onPressed: _load,
                  child: const Text('Tentar novamente'),
                ),
              ),
            if (!_loading && _error == null)
              Expanded(
                child: _rows.isEmpty
                    ? const Center(
                        child: Text('Nenhum plantio registrado neste setor.'),
                      )
                    : ListView.separated(
                        itemCount: _rows.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _text(row['culturaNome']),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ),
                                    _StatusPill(
                                      displayValue(row['statusPlantio']),
                                      row['statusPlantio'] == 'CONCLUIDO'
                                          ? _green
                                          : _cyan,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Setor: ${_text(row['setorNome'], widget.sectorName)}',
                                ),
                                Text('Plantio: ${_date(row['dataPlantio'])}'),
                                Text(
                                  'Colheita estimada: ${_date(row['dataColheitaEstimada'])}',
                                ),
                                Text(
                                  'Colheita real: ${_date(row['dataColheita'])}',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    ),
  );
}
