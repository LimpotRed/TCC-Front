import 'package:flutter/material.dart';

import 'api_client.dart';
import 'app_theme.dart';

class IrrigationHistoryScreen extends StatefulWidget {
  const IrrigationHistoryScreen({
    super.key,
    required this.api,
    required this.farmId,
    required this.farmName,
  });

  final ApiClient api;
  final String farmId;
  final String farmName;

  @override
  State<IrrigationHistoryScreen> createState() =>
      _IrrigationHistoryScreenState();
}

class _IrrigationHistoryScreenState extends State<IrrigationHistoryScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.api.list(
        'registroIrrigacao/propriedade/${Uri.encodeComponent(widget.farmId)}',
      );
      if (!mounted || generation != _generation) return;
      rows.sort((a, b) {
        final first = DateTime.tryParse(a['dataIrrigacao']?.toString() ?? '');
        final second = DateTime.tryParse(b['dataIrrigacao']?.toString() ?? '');
        if (first == null) return second == null ? 0 : 1;
        if (second == null) return -1;
        return second.compareTo(first);
      });
      setState(() => _records = rows);
    } on ApiFailure catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Não foi possível carregar o histórico.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  String _date(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return 'Não informado';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} às ${two(date.hour)}:${two(date.minute)}';
  }

  String _duration(dynamic raw) {
    if (raw is! num || !raw.isFinite || raw < 0 || raw != raw.roundToDouble()) {
      return 'Não informado';
    }
    final minutes = raw.toInt();
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours == 0) return '$remainder min';
    if (remainder == 0) return '$hours h';
    return '$hours h $remainder min';
  }

  String _value(dynamic raw) {
    if (raw is! num || !raw.isFinite || raw < 0) return 'Não informado';
    return raw
        .toStringAsFixed(raw == raw.roundToDouble() ? 0 : 2)
        .replaceAll('.', ',');
  }

  String _name(dynamic raw) {
    final value = raw?.toString().trim();
    return value == null || value.isEmpty ? 'Não informado' : value;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Histórico de irrigação'),
        actions: [
          IconButton(
            tooltip: 'Atualizar histórico',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              itemCount:
                  1 + (!_loading && _error == null ? _records.length : 0),
              itemBuilder: (context, index) {
                if (index > 0) return _recordCard(_records[index - 1]);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.farmName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registros da fazenda selecionada, do mais recente ao mais antigo.',
                      style: TextStyle(color: colors.muted),
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else if (_error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Não foi possível carregar o histórico. $_error',
                        ),
                      ),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    ] else if (_records.isEmpty)
                      const Text(
                        'Nenhuma irrigação registrada para esta fazenda.',
                      )
                    else ...[
                      Text(
                        'Água, energia e custos são estimativas do servidor. A moeda não acompanha os registros.',
                        style: TextStyle(color: colors.muted),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> record) {
    final colors = AppColors.of(context);
    return Card(
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Setor: ${_name(record['nomeSetor'])}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Início: ${_date(record['dataIrrigacao'])}'),
            Text('Duração: ${_duration(record['duracaoMinutos'])}'),
            Text('Dispositivo: ${_name(record['nomeDispositivo'])}'),
            const SizedBox(height: 8),
            Text('Água estimada: ${_value(record['volumeAgua'])}'),
            Text('Energia estimada: ${_value(record['consumoEnergia'])}'),
            Text('Custo estimado da água: ${_value(record['custoAgua'])}'),
            Text(
              'Custo estimado da energia: ${_value(record['custoEnergia'])}',
            ),
            Text('Custo total estimado: ${_value(record['custoTotal'])}'),
          ],
        ),
      ),
    );
  }
}
