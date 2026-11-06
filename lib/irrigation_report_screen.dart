import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'api_client.dart';
import 'app_theme.dart';
import 'irrigation_report_pdf.dart';

typedef PdfDelivery = Future<bool> Function(Uint8List bytes, String filename);

class IrrigationReportScreen extends StatefulWidget {
  const IrrigationReportScreen({
    super.key,
    required this.api,
    required this.farmId,
    required this.farmName,
    this.deliverPdf,
  });

  final ApiClient api;
  final String farmId;
  final String farmName;
  final PdfDelivery? deliverPdf;

  @override
  State<IrrigationReportScreen> createState() => _IrrigationReportScreenState();
}

class _IrrigationReportScreenState extends State<IrrigationReportScreen> {
  late DateTime _start;
  late DateTime _end;
  IrrigationReportType _type = IrrigationReportType.complete;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month - 5);
    _end = DateTime(now.year, now.month, now.day);
  }

  String _date(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  Future<void> _pickDate({required bool start}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
      helpText: start ? 'Selecione a data inicial' : 'Selecione a data final',
    );
    if (date == null || !mounted) return;
    setState(() {
      if (start) {
        _start = date;
      } else {
        _end = date;
      }
      _error = null;
      _notice = null;
    });
  }

  Future<void> _generate() async {
    if (_busy) return;
    if (_start.isAfter(_end)) {
      setState(
        () => _error = 'A data inicial não pode ser posterior à data final.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final records = await widget.api.list(
        'registroIrrigacao/propriedade/${Uri.encodeComponent(widget.farmId)}',
      );
      final report = IrrigationReport(
        farmName: widget.farmName,
        start: _start,
        end: _end,
        type: _type,
        records: records,
      );
      final bytes = await buildIrrigationReportPdf(report);
      String compact(DateTime date) =>
          '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      final filename =
          'relatorio-irrigacao-${compact(_start)}-${compact(_end)}.pdf';
      final delivered = await (widget.deliverPdf ?? _deliverPdf)(
        bytes,
        filename,
      );
      if (!mounted) return;
      setState(() {
        _notice = delivered
            ? (kIsWeb
                  ? 'Download do PDF iniciado.'
                  : 'Escolha onde salvar ou compartilhar o PDF.')
            : 'A operação foi cancelada ou não está disponível.';
      });
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível gerar o PDF. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _deliverPdf(Uint8List bytes, String filename) =>
      Printing.sharePdf(bytes: bytes, filename: filename);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(title: const Text('Gerar relatório em PDF')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
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
                  'Escolha o período e o tipo de relatório.',
                  style: TextStyle(color: colors.muted),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<IrrigationReportType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de relatório',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final type in IrrigationReportType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) setState(() => _type = value);
                        },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Período do início da irrigação',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickDate(start: true),
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('Data inicial: ${_date(_start)}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pickDate(start: false),
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Data final: ${_date(_end)}'),
                ),
                const SizedBox(height: 16),
                Text(
                  'O PDF inclui resumo, evolução mensal, gráficos e histórico do período. Os custos e consumos são estimativas do servidor.',
                  style: TextStyle(color: colors.muted),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 16),
                  Semantics(liveRegion: true, child: Text(_notice!)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : _generate,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_busy ? 'Gerando PDF...' : 'Gerar PDF'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
