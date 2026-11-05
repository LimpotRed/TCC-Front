import 'package:flutter/material.dart';

import 'api_client.dart';
import 'resource_schema.dart';

bool _sectorHasOpenPlanting(Map<dynamic, dynamic> sector) {
  final plantings = sector['plantios'];
  if (plantings is! List) return true;
  return plantings.any(
    (planting) => planting is! Map || planting['statusPlantio'] != 'CONCLUIDO',
  );
}

/// Mostra os plantios que a API retorna em cada setor da propriedade.
class FarmPlantingScreen extends StatefulWidget {
  const FarmPlantingScreen({
    super.key,
    required this.api,
    required this.farms,
    this.canManagePlantings = false,
    this.selectedFarmId,
    this.onFarmChanged,
  });

  final ApiClient api;
  final List<Map<String, dynamic>> farms;
  final bool canManagePlantings;
  final String? selectedFarmId;
  final ValueChanged<String?>? onFarmChanged;

  @override
  State<FarmPlantingScreen> createState() => _FarmPlantingScreenState();
}

class _FarmPlantingScreenState extends State<FarmPlantingScreen> {
  String? _farmId;
  Future<List<Map<String, dynamic>>>? _sectors;

  @override
  void initState() {
    super.initState();
    final ids = widget.farms
        .where((f) => f['id'] != null)
        .map((f) => f['id'].toString())
        .toList();
    _farmId = ids.contains(widget.selectedFarmId)
        ? widget.selectedFarmId
        : (ids.isEmpty ? null : ids.first);
    _refresh();
  }

  void _refresh() {
    final id = _farmId;
    setState(() {
      _sectors = id == null
          ? null
          : widget.api.list('setor/propriedade/${Uri.encodeComponent(id)}');
    });
  }

  Future<void> _createPlanting(Map<String, dynamic> sector) async {
    final farmId = _farmId;
    if (!widget.canManagePlantings ||
        sector['id'] == null ||
        farmId == null ||
        _sectorHasOpenPlanting(sector)) {
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CreatePlantingDialog(
        api: widget.api,
        sector: sector,
        farmId: farmId,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plantio registrado com sucesso.')),
      );
    }
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final farms = widget.farms.where((farm) => farm['id'] != null).toList();
    final selected = farms.where((farm) => farm['id'].toString() == _farmId);
    return Scaffold(
      backgroundColor: const Color(0xFF15142F),
      appBar: AppBar(
        title: const Text('Plantio em andamento'),
        actions: [
          IconButton(
            onPressed: _farmId == null ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar setores',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
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
                  style: TextStyle(color: Color(0xFFA39DBF)),
                ),
                if (!widget.canManagePlantings) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Seu perfil não permite cadastrar plantios ou registrar colheitas.',
                    style: TextStyle(color: Color(0xFFA39DBF)),
                  ),
                ],
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
                            farm['nome']?.toString() ?? 'Fazenda',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      _farmId = id;
                      widget.onFarmChanged?.call(id);
                      _refresh();
                    },
                  )
                else if (selected.isNotEmpty)
                  Text(
                    selected.first['nome']?.toString() ?? 'Fazenda',
                    style: const TextStyle(
                      color: Color(0xFF36C9D8),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 20),
                if (_farmId == null)
                  const _MessageCard(
                    'Nenhuma fazenda disponível para sua conta.',
                  )
                else
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _sectors,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _MessageCard(
                          snapshot.error.toString(),
                          action: TextButton(
                            onPressed: _refresh,
                            child: const Text('Tentar novamente'),
                          ),
                        );
                      }
                      final sectors = snapshot.data ?? [];
                      if (sectors.isEmpty) {
                        return const _MessageCard(
                          'Esta fazenda ainda não possui setores.',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${sectors.length} ${sectors.length == 1 ? 'setor' : 'setores'} nesta fazenda',
                            style: const TextStyle(color: Color(0xFFA39DBF)),
                          ),
                          const SizedBox(height: 12),
                          for (final sector in sectors) ...[
                            _sectorCard(sector),
                            const SizedBox(height: 14),
                          ],
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectorCard(Map<String, dynamic> sector) {
    final rows = sector['plantios'] is List
        ? (sector['plantios'] as List).whereType<Map>().toList()
        : <Map>[];
    final active = rows
        .where(
          (row) =>
              row['statusPlantio'] == 'EM_ANDAMENTO' ||
              row['statusPlantio'] == 'PLANEJADO',
        )
        .toList();
    final inProgress = active.any(
      (row) => row['statusPlantio'] == 'EM_ANDAMENTO',
    );
    return Card(
      color: const Color(0xFF242144),
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
                const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF36C9D8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sector['nome']?.toString() ?? 'Setor',
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
                    active.isEmpty
                        ? 'Em descanso'
                        : inProgress
                        ? 'Safra ativa'
                        : 'Planejado',
                    active.isEmpty
                        ? const Color(0xFFA39DBF)
                        : inProgress
                        ? const Color(0xFF65D99A)
                        : const Color(0xFF36C9D8),
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
              child: active.isEmpty
                  ? const Column(
                      children: [
                        Icon(
                          Icons.grass_outlined,
                          color: Color(0xFFA39DBF),
                          size: 32,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'O solo deste setor está em descanso.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final planting in active)
                          _plantingDetails(sector, planting),
                      ],
                    ),
            ),
            if (widget.canManagePlantings &&
                !_sectorHasOpenPlanting(sector)) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _createPlanting(sector),
                  icon: const Icon(Icons.add),
                  label: const Text('Cadastrar plantação'),
                ),
              ),
            ] else if (widget.canManagePlantings) ...[
              const SizedBox(height: 12),
              const Text(
                'Este setor já possui uma safra não concluída.',
                style: TextStyle(color: Color(0xFFA39DBF)),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showHistory(sector, rows),
                icon: const Icon(Icons.history),
                label: const Text('Ver histórico produtivo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plantingDetails(
    Map<dynamic, dynamic> sector,
    Map<dynamic, dynamic> planting,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        displayValue(planting['cultura']),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text('Plantio: ${_displayDate(planting['dataPlantio'])}'),
      Text(
        'Colheita estimada: ${_displayDate(planting['dataColheitaEstimada'])}',
      ),
      Text('Situação: ${displayValue(planting['statusPlantio'])}'),
      if (widget.canManagePlantings &&
          planting['statusPlantio'] == 'EM_ANDAMENTO') ...[
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _harvest(sector, planting),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: const Color(0xFF1B1938),
            minimumSize: const Size(0, 48),
          ),
          child: const Text('Registrar colheita'),
        ),
      ],
      const SizedBox(height: 8),
    ],
  );

  void _showHistory(Map<String, dynamic> sector, List<Map> plantings) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Histórico • ${sector['nome'] ?? 'Setor'}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: plantings.isEmpty
                ? const Text('Nenhum plantio registrado neste setor.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final planting in plantings)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(displayValue(planting['cultura'])),
                              subtitle: Text(
                                'Plantio: ${_displayDate(planting['dataPlantio'])}\nColheita: ${_displayDate(planting['dataColheitaReal'])}\nSituação: ${displayValue(planting['statusPlantio'])}',
                              ),
                              isThreeLine: true,
                            ),
                            const Divider(),
                          ],
                        ),
                    ],
                  ),
          ),
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

  Future<void> _harvest(
    Map<dynamic, dynamic> sector,
    Map<dynamic, dynamic> planting,
  ) async {
    final start = DateTime.tryParse(planting['dataPlantio']?.toString() ?? '');
    if (start == null ||
        planting['id'] == null ||
        planting['cultura'] is! Map ||
        (planting['cultura'] as Map)['id'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não é possível registrar a colheita: faltam dados do plantio.',
            ),
          ),
        );
      }
      return;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    if (start.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A data de plantio está no futuro.')),
      );
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateUtils.dateOnly(start),
      lastDate: today,
      helpText: 'Data da colheita',
    );
    if (date == null || !mounted) return;
    try {
      await widget.api.request(
        'PUT',
        'plantio/${Uri.encodeComponent(planting['id'].toString())}',
        body: {
          'setor': {'id': sector['id']},
          'cultura': {'id': (planting['cultura'] as Map)['id']},
          'dataPlantio': planting['dataPlantio'],
          'dataColheitaEstimada': planting['dataColheitaEstimada'],
          'dataColheitaReal': _iso(date),
          'statusPlantio': 'CONCLUIDO',
        },
      );
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

String _iso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _displayDate(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'Não informado';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _MessageCard extends StatelessWidget {
  const _MessageCard(this.message, {this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      color: const Color(0xFF242144),
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

class _DateSelector extends StatelessWidget {
  const _DateSelector({
    required this.label,
    required this.value,
    required this.onPressed,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback? onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          alignment: Alignment.centerLeft,
          side: const BorderSide(color: Color(0xFF57516C)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFA39DBF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value == null ? 'Selecionar data' : _displayDate(value),
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
      if (value != null && onClear != null)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Limpar previsão'),
          ),
        ),
    ],
  );
}

class _CreatePlantingDialog extends StatefulWidget {
  const _CreatePlantingDialog({
    required this.api,
    required this.sector,
    required this.farmId,
  });
  final ApiClient api;
  final Map<String, dynamic> sector;
  final String farmId;

  @override
  State<_CreatePlantingDialog> createState() => _CreatePlantingDialogState();
}

class _CreatePlantingDialogState extends State<_CreatePlantingDialog> {
  late Future<List<Map<String, dynamic>>> _cultures;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  DateTime? _estimated;
  String? _cultureId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cultures = widget.api.list('cultura');
  }

  Future<void> _chooseDate({required bool estimated}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: estimated
          ? (_estimated ?? _date.add(const Duration(days: 1)))
          : _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year + 100),
      helpText: estimated ? 'Previsão de colheita' : 'Data de plantio',
    );
    if (selected != null && mounted) {
      setState(() {
        if (estimated) {
          _estimated = selected;
        } else {
          _date = selected;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final cultureId = int.tryParse(_cultureId ?? '');
    if (cultureId == null) {
      setState(() => _error = 'Selecione uma cultura.');
      return;
    }
    if (_estimated != null && !_estimated!.isAfter(_date)) {
      setState(
        () => _error = 'A previsão de colheita deve ser posterior ao plantio.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final cultures = await _cultures;
      if (!cultures.any((culture) => culture['id']?.toString() == _cultureId)) {
        throw const ApiFailure('Selecione uma cultura disponível.');
      }
      final sectors = await widget.api.list(
        'setor/propriedade/${Uri.encodeComponent(widget.farmId)}',
      );
      final matching = sectors.where(
        (sector) => sector['id']?.toString() == widget.sector['id'].toString(),
      );
      if (matching.length != 1) {
        throw const ApiFailure('Não foi possível verificar este setor.');
      }
      if (_sectorHasOpenPlanting(matching.single)) {
        throw const ApiFailure(
          'Este setor já possui uma safra não concluída. Atualize a tela para consultar.',
        );
      }
      await widget.api.request(
        'POST',
        'plantio',
        body: {
          'setor': {'id': widget.sector['id']},
          'cultura': {'id': cultureId},
          'dataPlantio': _iso(_date),
          'dataColheitaEstimada': _estimated == null ? null : _iso(_estimated!),
          'dataColheitaReal': null,
          'statusPlantio': 'EM_ANDAMENTO',
        },
      );
      if (mounted) Navigator.pop(context, true);
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
      title: const Text('Cadastrar plantação'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _cultures,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snapshot.error.toString()),
                    TextButton(
                      onPressed: () => setState(() {
                        _cultures = widget.api.list('cultura');
                      }),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                );
              }
              final cultures = (snapshot.data ?? [])
                  .where((culture) => culture['id'] != null)
                  .toList();
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Setor: ${displayValue(widget.sector['nome'])}'),
                  if (cultures.isEmpty)
                    const Text('Nenhuma cultura cadastrada no sistema.')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _cultureId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Cultura'),
                      items: [
                        for (final culture in cultures)
                          DropdownMenuItem(
                            value: culture['id'].toString(),
                            child: Text(
                              displayValue(culture),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _cultureId = value),
                    ),
                  const SizedBox(height: 20),
                  _DateSelector(
                    label: 'Data de plantio',
                    value: _date,
                    onPressed: _saving
                        ? null
                        : () => _chooseDate(estimated: false),
                  ),
                  const SizedBox(height: 12),
                  _DateSelector(
                    label: 'Previsão de colheita (opcional)',
                    value: _estimated,
                    onPressed: _saving
                        ? null
                        : () => _chooseDate(estimated: true),
                    onClear: _saving
                        ? null
                        : () => setState(() => _estimated = null),
                  ),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Salvando…' : 'Salvar'),
        ),
      ],
    ),
  );
}
