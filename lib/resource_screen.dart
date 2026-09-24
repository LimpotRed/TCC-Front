import 'package:flutter/material.dart';

import 'api_client.dart';
import 'resource_schema.dart';

const panelColor = Color(0xFF242144);
const accentColor = Color(0xFF36C9D8);

class ResourceScreen extends StatefulWidget {
  const ResourceScreen({
    super.key,
    required this.api,
    required this.spec,
    required this.canManage,
  });
  final ApiClient api;
  final ResourceSpec spec;
  final bool canManage;
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
  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ResourceEditor(api: widget.api, spec: widget.spec, row: row),
      ),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro salvo no servidor.')),
      );
      await _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir registro?'),
        content: Text(
          'Excluir “${widget.spec.label(row)}”? Esta ação é permanente e pode remover registros dependentes. Revise os vínculos antes de confirmar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.request(
        'DELETE',
        '${widget.spec.path}/${row['id']}${widget.spec.deleteSlash ? '/' : ''}',
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
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
    final visible = _rows
        .where(
          (row) =>
              row.values
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
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: Text('Novo registro'),
            )
          : null,
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
              if (!widget.canManage)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Consulta dos dados disponíveis para sua conta. Alterações são realizadas pela equipe técnica.',
                  ),
                ),
              const SizedBox(height: 20),
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
                      if (_rows.isEmpty && widget.canManage)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Use “Novo registro” para começar.',
                            textAlign: TextAlign.center,
                          ),
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
                      trailing: widget.canManage
                          ? PopupMenuButton<String>(
                              tooltip: 'Ações do registro',
                              onSelected: (action) {
                                if (action == 'edit') {
                                  _edit(row);
                                } else if (action == 'history') {
                                  _historyPath =
                                      '${spec.path}/equipamento/${Uri.encodeComponent(row['tipoEquipamento'].toString())}/${row['equipamentoId']}';
                                  _load();
                                } else {
                                  _delete(row);
                                }
                              },
                              itemBuilder: (_) => [
                                if (spec.path == 'admin/manutencao')
                                  const PopupMenuItem(
                                    value: 'history',
                                    child: Text('Histórico do equipamento'),
                                  ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Excluir'),
                                ),
                              ],
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

class ResourceEditor extends StatefulWidget {
  const ResourceEditor({
    super.key,
    required this.api,
    required this.spec,
    this.row,
  });
  final ApiClient api;
  final ResourceSpec spec;
  final Map<String, dynamic>? row;
  @override
  State<ResourceEditor> createState() => _ResourceEditorState();
}

class _ResourceEditorState extends State<ResourceEditor> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _values = <String, dynamic>{};
  final _lookups = <String, List<Map<String, dynamic>>>{};
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    for (final field in widget.spec.fields) {
      final value = widget.row?[field.key];
      if (field.kind == FieldKind.relation) {
        _values[field.key] = value is Map ? value['id'] : null;
      } else if (field.kind == FieldKind.relations) {
        _values[field.key] = (value as List? ?? [])
            .map((v) => v['id'])
            .toList();
      } else if (field.kind == FieldKind.multi) {
        _values[field.key] = List<String>.from(value as List? ?? []);
      } else if (field.kind == FieldKind.choice) {
        _values[field.key] = value;
      } else {
        _controllers[field.key] = TextEditingController(
          text: value?.toString() ?? '',
        );
      }
    }
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final paths = widget.spec.fields
          .map((f) => f.resource)
          .whereType<String>()
          .toSet();
      await Future.wait(
        paths.map((path) async {
          _lookups[path] = await widget.api.list(path);
        }),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(DataField field) async {
    final current =
        DateTime.tryParse(_controllers[field.key]!.text) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (date == null || !mounted) return;
    var result = date;
    if (field.kind == FieldKind.dateTime) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (time == null || !mounted) return;
      result = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }
    _controllers[field.key]!.text = field.kind == FieldKind.date
        ? result.toIso8601String().split('T').first
        : result.toIso8601String().split('.').first;
    setState(() {});
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final payload = <String, dynamic>{
      if (widget.row != null) 'id': widget.row!['id'],
    };
    for (final f in widget.spec.fields) {
      final text = _controllers[f.key]?.text.trim() ?? '';
      payload[f.key] = switch (f.kind) {
        FieldKind.number =>
          text.isEmpty ? null : double.parse(text.replaceAll(',', '.')),
        FieldKind.integer => text.isEmpty ? null : int.parse(text),
        FieldKind.relation =>
          _values[f.key] == null ? null : {'id': _values[f.key]},
        FieldKind.relations =>
          (_values[f.key] as List).map((id) => {'id': id}).toList(),
        FieldKind.multi || FieldKind.choice => _values[f.key],
        _ => text.isEmpty ? null : text,
      };
      if (f.key == 'apiKey' && text.isEmpty) payload.remove(f.key);
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final spec = widget.spec;
      final path = widget.row == null || spec.putAtRoot
          ? spec.path
          : '${spec.path}/${widget.row!['id']}';
      await widget.api.request(
        widget.row == null ? 'POST' : 'PUT',
        path,
        body: payload,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(DataField field) {
    final decoration = InputDecoration(
      labelText: '${field.label}${field.required ? ' *' : ''}',
      helperText: field.hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      errorMaxLines: 3,
    );
    if (field.kind == FieldKind.relation || field.kind == FieldKind.choice) {
      final options = field.kind == FieldKind.relation
          ? [
              for (final row
                  in _lookups[field.resource] ?? <Map<String, dynamic>>[])
                DropdownMenuItem<Object>(
                  value: row['id'],
                  child: Text(
                    resource(field.resource!).label(row),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ]
          : [
              for (final option in field.options)
                DropdownMenuItem<Object>(
                  value: option,
                  child: Text(displayValue(option)),
                ),
            ];
      final selected = options.any((o) => o.value == _values[field.key])
          ? _values[field.key]
          : null;
      return DropdownButtonFormField<Object>(
        initialValue: selected,
        isExpanded: true,
        decoration: decoration,
        items: [
          if (!field.required)
            const DropdownMenuItem(value: null, child: Text('Sem vínculo')),
          ...options,
        ],
        validator: (v) => field.required && v == null
            ? 'Selecione ${field.label.toLowerCase()}.'
            : null,
        onChanged: (v) => setState(() => _values[field.key] = v),
      );
    }
    if (field.kind == FieldKind.multi || field.kind == FieldKind.relations) {
      final options = field.kind == FieldKind.multi
          ? {for (final v in field.options) v: displayValue(v)}
          : {
              for (final row
                  in _lookups[field.resource] ?? <Map<String, dynamic>>[])
                row['id']: resource(field.resource!).label(row),
            };
      return FormField<List>(
        initialValue: _values[field.key] as List,
        validator: (_) => field.required && (_values[field.key] as List).isEmpty
            ? 'Selecione ao menos uma opção.'
            : null,
        builder: (state) => InputDecorator(
          decoration: decoration.copyWith(errorText: state.errorText),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (options.isEmpty)
                const Text(
                  'Nenhum registro disponível. Cadastre-o na seção correspondente.',
                ),
              for (final option in options.entries)
                FilterChip(
                  label: Text(option.value),
                  selected: (_values[field.key] as List).contains(option.key),
                  onSelected: (selected) => setState(() {
                    final values = _values[field.key] as List;
                    selected
                        ? values.add(option.key)
                        : values.remove(option.key);
                    state.didChange(values);
                  }),
                ),
            ],
          ),
        ),
      );
    }
    final isDate = [FieldKind.date, FieldKind.dateTime].contains(field.kind);
    final isNumber = [FieldKind.number, FieldKind.integer].contains(field.kind);
    return TextFormField(
      controller: _controllers[field.key],
      readOnly: isDate,
      obscureText: field.key == 'apiKey',
      onTap: isDate ? () => _pickDate(field) : null,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: decoration.copyWith(
        suffixIcon: isDate
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!field.required)
                    IconButton(
                      tooltip: 'Limpar data',
                      onPressed: () =>
                          setState(() => _controllers[field.key]!.clear()),
                      icon: const Icon(Icons.clear),
                    ),
                  const Icon(Icons.calendar_today_outlined),
                  const SizedBox(width: 12),
                ],
              )
            : null,
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return field.required
              ? 'Informe ${field.label.toLowerCase()}.'
              : null;
        }
        if (isNumber) {
          final number = field.kind == FieldKind.integer
              ? int.tryParse(text)
              : double.tryParse(text.replaceAll(',', '.'));
          if (number == null || !number.isFinite) {
            return 'Informe um número válido.';
          }
          if (field.min != null && number < field.min!) {
            return 'Valor abaixo do permitido.';
          }
          if (field.max != null && number > field.max!) {
            return 'O máximo é ${field.max}.';
          }
        }
        if (isDate && DateTime.tryParse(text) == null) {
          return 'Selecione uma data válida.';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.row == null ? 'Cadastrar' : 'Editar'} ${widget.spec.singular.toLowerCase()}',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text('Campos com * são obrigatórios.'),
                      const SizedBox(height: 24),
                      if (_lookups.length <
                          widget.spec.fields
                              .map((f) => f.resource)
                              .whereType<String>()
                              .toSet()
                              .length)
                        ErrorPanel(
                          message:
                              _error ??
                              'Não foi possível carregar os vínculos.',
                          retry: _loadLookups,
                        )
                      else ...[
                        AbsorbPointer(
                          absorbing: _saving,
                          child: Column(
                            children: [
                              for (final field in widget.spec.fields)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: _field(field),
                                ),
                            ],
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFFFB4AB),
                                ),
                              ),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            _saving ? 'Salvando…' : 'Salvar registro',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}
