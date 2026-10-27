import 'package:flutter/material.dart';

import 'api_client.dart';
import 'resource_schema.dart';

const panelColor = Color(0xFF242144);
const accentColor = Color(0xFF36C9D8);
const _readOnlyNotice =
    'Os cadastros e as alterações são feitos no aplicativo web da equipe responsável. Aqui, você pode consultar os dados.';

class ResourceScreen extends StatefulWidget {
  const ResourceScreen({
    super.key,
    required this.api,
    required this.spec,
    this.header,
  });
  final ApiClient api;
  final ResourceSpec spec;
  final Widget? header;
  @override
  State<ResourceScreen> createState() => _ResourceScreenState();
}

class _ResourceScreenState extends State<ResourceScreen> {
  List<Map<String, dynamic>> _rows = [];
  String? _error;
  bool _busy = true;
  String _query = '';
  String? _status;
  String? _historyPath;
  int _page = 0;
  int _generation = 0;
  static const pageSize = 12;

  bool get _weatherOnly =>
      widget.spec.path == 'leituraClimatica' && widget.header != null;

  @override
  void initState() {
    super.initState();
    if (!_weatherOnly) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await widget.api.list(_historyPath ?? widget.spec.path);
      if (mounted && generation == _generation) {
        setState(() {
          _rows = rows.reversed.toList();
          _page = 0;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  void _details(Map<String, dynamic> row) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.spec.label(row)),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final field in widget.spec.fields.where(
                  (f) => f.key != 'apiKey',
                ))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.label,
                          style: const TextStyle(
                            color: accentColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(displayValue(row[field.key])),
                      ],
                    ),
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

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (_weatherOnly) {
      return Scaffold(
        appBar: AppBar(title: Text(spec.title)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [widget.header!],
            ),
          ),
        ),
      );
    }
    final visible = _rows
        .where(
          (row) =>
              row.entries
                  .where((entry) => entry.key != 'apiKey')
                  .map((entry) => entry.value)
                  .map(displayValue)
                  .join(' ')
                  .toLowerCase()
                  .contains(_query.toLowerCase()) &&
              (_status == null ||
                  (row['status'] ?? row['statusPlantio']) == _status),
        )
        .toList();
    final statuses = _rows
        .map((r) => r['status'] ?? r['statusPlantio'])
        .whereType<String>()
        .toSet()
        .toList();
    final pageCount = (visible.length / pageSize).ceil();
    return Scaffold(
      appBar: AppBar(
        title: Text(spec.title),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              Text(
                spec.description,
                style: const TextStyle(color: Color(0xFFBDB6D3)),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(_readOnlyNotice),
              ),
              const SizedBox(height: 20),
              if (widget.header != null) ...[
                widget.header!,
                const SizedBox(height: 20),
              ],
              if (_historyPath != null)
                TextButton.icon(
                  onPressed: () {
                    _historyPath = null;
                    _load();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Histórico do equipamento • mostrar todos'),
                ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar registros',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() {
                  _query = value;
                  _page = 0;
                }),
              ),
              if (statuses.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _status == null,
                        onSelected: (_) => setState(() {
                          _status = null;
                          _page = 0;
                        }),
                      ),
                      for (final status in statuses)
                        ChoiceChip(
                          label: Text(displayValue(status)),
                          selected: _status == status,
                          onSelected: (_) => setState(() {
                            _status = status;
                            _page = 0;
                          }),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (_error != null) ErrorPanel(message: _error!, retry: _load),
              if (!_busy && _error == null && visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(spec.icon, size: 48, color: accentColor),
                      const SizedBox(height: 14),
                      Text(
                        _rows.isEmpty
                            ? 'Nenhum registro por aqui ainda'
                            : 'Nenhum resultado para esta busca',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              if (!_busy && _error == null) ...[
                for (final row in visible.skip(_page * pageSize).take(pageSize))
                  Card(
                    color: panelColor,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      leading: Icon(spec.icon, color: accentColor),
                      title: Text(spec.label(row)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          spec.fields
                              .where(
                                (f) => f.key != 'apiKey' && row[f.key] != null,
                              )
                              .take(3)
                              .map(
                                (f) =>
                                    '${f.label}: ${displayValue(row[f.key])}',
                              )
                              .join('\n'),
                        ),
                      ),
                      onTap: () => _details(row),
                      trailing:
                          spec.path == 'manutencao' &&
                              row['tipoEquipamento'] != null &&
                              row['equipamentoId'] != null
                          ? IconButton(
                              tooltip: 'Histórico do equipamento',
                              icon: const Icon(Icons.history),
                              onPressed: () {
                                _historyPath =
                                    '${spec.path}/equipamento/${Uri.encodeComponent(row['tipoEquipamento'].toString())}/${Uri.encodeComponent(row['equipamentoId'].toString())}';
                                _load();
                              },
                            )
                          : const Icon(Icons.chevron_right),
                    ),
                  ),
                if (pageCount > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Página anterior',
                        onPressed: _page > 0
                            ? () => setState(() => _page--)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('${_page + 1} de $pageCount'),
                      IconButton(
                        tooltip: 'Próxima página',
                        onPressed: _page + 1 < pageCount
                            ? () => setState(() => _page++)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: accentColor),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: retry, child: const Text('Tentar novamente')),
        ],
      ),
    ),
  );
}
