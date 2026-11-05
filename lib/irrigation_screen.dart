import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';

const _surface = Color(0xFF242144);
const _muted = Color(0xFFA39DBF);
const _cyan = Color(0xFF36C9D8);

String _display(dynamic value, [String fallback = 'Não informado']) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

String _dateTime(DateTime? value) {
  if (value == null) return 'Selecionar data e horário';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} às ${two(value.hour)}:${two(value.minute)}';
}

String _localIso(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}T${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

/// Registra a duração de uma irrigação no setor da fazenda.
class IrrigationScreen extends StatefulWidget {
  const IrrigationScreen({
    super.key,
    required this.api,
    required this.farm,
    required this.sectors,
  });

  final ApiClient api;
  final Map<String, dynamic> farm;
  final List<Map<String, dynamic>> sectors;

  @override
  State<IrrigationScreen> createState() => _IrrigationScreenState();
}

class _IrrigationScreenState extends State<IrrigationScreen> {
  final _hours = TextEditingController();
  final _minutes = TextEditingController();
  String? _sectorId;
  Map<String, dynamic>? _device;
  String? _deviceError;
  bool _deviceLoading = false;
  bool _saving = false;
  bool _durationMode = true;
  DateTime? _start;
  DateTime? _end;
  String? _error;
  int _deviceGeneration = 0;
  String _costMessage = 'Consultando tarifas da fazenda...';
  Map<String, dynamic>? _cost;
  bool _unitsConfirmed = false;

  @override
  void initState() {
    super.initState();
    _hours.addListener(_refreshEstimates);
    _minutes.addListener(_refreshEstimates);
    _loadCosts();
  }

  void _refreshEstimates() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCosts() async {
    final farmId = widget.farm['id'];
    if (farmId == null) {
      _costMessage = 'Tarifas da fazenda não informadas.';
      return;
    }
    try {
      final result = await widget.api.request(
        'GET',
        'configuracaoCusto/propriedade/${Uri.encodeComponent(farmId.toString())}',
      );
      if (!mounted) return;
      if (result is! Map) {
        setState(() => _costMessage = 'Tarifas da fazenda não informadas.');
        return;
      }
      final property = result['propriedade'];
      if (property is Map &&
          property['id'] != null &&
          property['id'].toString() != farmId.toString()) {
        setState(
          () => _costMessage =
              'Não foi possível identificar as tarifas desta fazenda.',
        );
        return;
      }
      String rate(dynamic value, String unit) {
        if (value is! num || !value.isFinite || value < 0) {
          return 'Não informado';
        }
        final currency = _display(result['moeda']);
        return '${value.toStringAsFixed(2).replaceAll('.', ',')} $currency/$unit';
      }

      setState(() {
        _cost = Map<String, dynamic>.from(result);
        _costMessage =
            'Tarifas da fazenda: água ${rate(result['custoM3Agua'], 'm³')}; energia ${rate(result['custoKWh'], 'kWh')}.';
      });
    } on ApiFailure catch (error) {
      if (!mounted) return;
      setState(
        () => _costMessage = error.status == 404
            ? 'Tarifas da fazenda não informadas.'
            : 'Não foi possível carregar as tarifas da fazenda.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _costMessage = 'Não foi possível carregar as tarifas da fazenda.',
        );
      }
    }
  }

  List<Map<String, dynamic>> get _sectors => widget.sectors
      .where((sector) {
        if (sector['id'] == null) return false;
        final property = sector['propriedade'];
        if (property is Map && property['id'] != null) {
          return property['id'].toString() == widget.farm['id']?.toString();
        }
        return true;
      })
      .toList(growable: false);

  Map<String, dynamic>? get _sector {
    for (final sector in _sectors) {
      if (sector['id'].toString() == _sectorId) return sector;
    }
    return null;
  }

  @override
  void dispose() {
    _deviceGeneration++;
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _selectSector(String? id) async {
    final generation = ++_deviceGeneration;
    setState(() {
      _sectorId = id;
      _device = null;
      _unitsConfirmed = false;
      _deviceError = null;
      _error = null;
      _deviceLoading = id != null;
    });
    if (id == null) return;
    try {
      final devices = await widget.api.list(
        'dispositivoIrrigacao/setor/${Uri.encodeComponent(id)}',
      );
      if (!mounted || generation != _deviceGeneration) return;
      final active = devices.where((row) => row['ativo'] == true).toList();
      if (active.isEmpty) {
        setState(
          () => _deviceError = 'Nenhum dispositivo ativo foi encontrado neste setor. Solicite a configuração no sistema web.',
        );
        return;
      }
      if (active.length > 1) {
        setState(
          () => _deviceError = 'Há mais de um dispositivo ativo neste setor. Regularize a configuração no sistema web.',
        );
        return;
      }
      final result = active.single;
      if (result['id'] == null) {
        setState(
          () => _deviceError =
              'Não foi possível identificar o dispositivo ativo deste setor.',
        );
        return;
      }
      final sector = result['setor'];
      if (sector is Map &&
          sector['id'] != null &&
          sector['id'].toString() != id) {
        setState(
          () => _deviceError =
              'O dispositivo retornado não pertence ao setor selecionado.',
        );
        return;
      }
      setState(() => _device = Map<String, dynamic>.from(result));
    } on ApiFailure catch (error) {
      if (mounted && generation == _deviceGeneration) {
        setState(
          () => _deviceError = error.status == 404
              ? 'Nenhum dispositivo ativo foi encontrado neste setor.'
              : 'Não foi possível consultar o dispositivo ativo. ${error.message}',
        );
      }
    } catch (_) {
      if (mounted && generation == _deviceGeneration) {
        setState(
          () =>
              _deviceError = 'Não foi possível consultar o dispositivo ativo.',
        );
      }
    } finally {
      if (mounted && generation == _deviceGeneration) {
        setState(() => _deviceLoading = false);
      }
    }
  }

  double? _nonNegative(dynamic value) {
    if (value is! num || !value.isFinite || value < 0) return null;
    return value.toDouble();
  }

  double? get _durationHours {
    if (_durationMode) {
      final hours = _hours.text.isEmpty ? 0 : int.tryParse(_hours.text);
      final minutes = _minutes.text.isEmpty ? 0 : int.tryParse(_minutes.text);
      if (hours == null ||
          minutes == null ||
          minutes > 59 ||
          (hours == 0 && minutes == 0)) {
        return null;
      }
      return hours + minutes / 60;
    }
    final start = _start;
    final end = _end;
    if (start == null ||
        end == null ||
        !end.isAfter(start) ||
        end.isAfter(DateTime.now())) {
      return null;
    }
    return end.difference(start).inSeconds / Duration.secondsPerHour;
  }

  String _estimateValue(double? value, String unit) {
    if (value == null || !value.isFinite) return 'Não informado';
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} $unit';
  }

  String get _estimateText {
    final duration = _unitsConfirmed ? _durationHours : null;
    final flow = _nonNegative(_device?['vazaoNominal']);
    final power = _nonNegative(_device?['potenciaMotor']);
    final water = duration != null && flow != null && flow > 0
        ? duration * flow
        : null;
    final energy = duration != null && power != null && power > 0
        ? duration * power
        : null;
    final waterRate = _nonNegative(_cost?['custoM3Agua']);
    final energyRate = _nonNegative(_cost?['custoKWh']);
    final currency = switch (_cost?['moeda']) {
      'BRL' => 'R\$',
      'USD' => 'US\$',
      'EUR' => '€',
      _ => null,
    };
    double? componentCost(double? amount, double? rate) {
      if (amount == null || rate == null) return null;
      final cents = amount * rate * 100;
      return cents.isFinite ? cents.roundToDouble() / 100 : null;
    }

    final waterCost = componentCost(water, waterRate);
    final energyCost = componentCost(energy, energyRate);
    final cost = waterCost != null && energyCost != null && currency != null
        ? waterCost + energyCost
        : null;
    final formattedCost = cost == null || !cost.isFinite
        ? 'Não informado'
        : '$currency ${cost.toStringAsFixed(2).replaceAll('.', ',')}';
    return 'Água estimada: ${_estimateValue(water, 'm³')}\n'
        'Energia estimada: ${_estimateValue(energy, 'kWh')}\n'
        'Custo total estimado: $formattedCost\n\n'
        'Prévia estimada. Ao salvar, o servidor recalcula e registra os valores usando a configuração disponível.';
  }

  Future<void> _pickDateTime({required bool start}) async {
    final now = DateTime.now();
    final previous = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: previous ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(previous ?? now),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving || _deviceLoading) return;
    final sector = _sector;
    final sectorId = int.tryParse(sector?['id']?.toString() ?? '');
    if (sector == null || sectorId == null || _device == null) {
      setState(() => _error = 'Selecione um setor com dispositivo ativo.');
      return;
    }
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;
    if (_durationMode) {
      final hours = _hours.text.isEmpty ? 0 : int.tryParse(_hours.text);
      final minutes = _minutes.text.isEmpty ? 0 : int.tryParse(_minutes.text);
      if (hours == null ||
          minutes == null ||
          minutes > 59 ||
          (hours == 0 && minutes == 0)) {
        setState(
          () => _error =
              'Informe uma duração maior que zero, com minutos de 0 a 59.',
        );
        return;
      }
      end = now;
      start = end.subtract(Duration(hours: hours, minutes: minutes));
    } else {
      start = _start;
      end = _end;
      if (start == null ||
          end == null ||
          !end.isAfter(start) ||
          end.isAfter(now)) {
        setState(
          () => _error = 'Informe início e fim válidos. O fim deve ser posterior ao início e não pode ser futuro.',
        );
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.request(
        'POST',
        'registroIrrigacao',
        body: {
          'setorId': sectorId,
          'dataIrrigacao': _localIso(start),
          'duracaoMinutos': end.difference(start).inMinutes,
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível registrar a operação. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectors = _sectors;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: const Color(0xFF15142F),
        appBar: AppBar(title: const Text('Registrar irrigação')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
                children: [
                  Text(
                    _display(widget.farm['nome'], 'Fazenda selecionada'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (sectors.isEmpty)
                    const _Notice(
                      'Esta fazenda não possui setores disponíveis.',
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _sectorId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Selecionar setor',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final row in sectors)
                          DropdownMenuItem(
                            value: row['id'].toString(),
                            child: Text(
                              _display(row['nome'], 'Setor #${row['id']}'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _saving ? null : _selectSector,
                    ),
                  const SizedBox(height: 18),
                  if (_deviceLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: 'Consultando dispositivo ativo',
                      ),
                    )
                  else if (_deviceError != null)
                    _Notice(
                      _deviceError!,
                      action: TextButton(
                        onPressed: _saving
                            ? null
                            : () => _selectSector(_sectorId),
                        child: const Text('Tentar novamente'),
                      ),
                    )
                  else if (_device != null)
                    _Notice(
                      'Dispositivo ativo: ${_display(_device!['nome'])}',
                      icon: Icons.check_circle_outline,
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Para salvar, o equipamento precisa ter vazão e potência válidas, e a fazenda precisa ter tarifas de água e energia cadastradas.',
                    style: TextStyle(color: _muted),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Como deseja informar o funcionamento?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Informar duração'),
                        selected: _durationMode,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() {
                                _durationMode = true;
                                _error = null;
                              }),
                      ),
                      ChoiceChip(
                        label: const Text('Informar início e fim'),
                        selected: !_durationMode,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() {
                                _durationMode = false;
                                _error = null;
                              }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_durationMode) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hours,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Horas',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _minutes,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Minutos',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'O término será o momento em que o registro for salvo; a data registrada será a do início.',
                      style: TextStyle(color: _muted),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _pickDateTime(start: true),
                      icon: const Icon(Icons.schedule),
                      label: Text('Início: ${_dateTime(_start)}'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _pickDateTime(start: false),
                      icon: const Icon(Icons.schedule),
                      label: Text('Fim: ${_dateTime(_end)}'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Estimativa de consumo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _unitsConfirmed,
                    onChanged: _saving || _device == null
                        ? null
                        : (value) =>
                              setState(() => _unitsConfirmed = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Confirmo que a vazão está em m³/h e a potência em kW.',
                    ),
                    subtitle: const Text(
                      'Confirme as unidades com a equipe responsável. O servidor calcula as estimativas ao salvar, mesmo sem marcar esta opção.',
                    ),
                  ),
                  _Notice(_estimateText),
                  const SizedBox(height: 8),
                  Text(_costMessage, style: const TextStyle(color: _muted)),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Semantics(liveRegion: true, child: _Notice(_error!)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving || _deviceLoading || _device == null
                        ? null
                        : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Salvar registro'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.icon, this.action});
  final String text;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: _cyan),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(text)),
          ],
        ),
        ?action,
      ],
    ),
  );
}
