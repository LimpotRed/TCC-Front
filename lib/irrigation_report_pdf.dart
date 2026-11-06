import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum IrrigationReportType {
  complete('Completo'),
  duration('Duração'),
  water('Água'),
  energy('Energia'),
  expenses('Gastos');

  const IrrigationReportType(this.label);
  final String label;
}

class IrrigationReport {
  IrrigationReport({
    required this.farmName,
    required this.start,
    required this.end,
    required this.type,
    required List<Map<String, dynamic>> records,
  }) : records = _filter(records, start, end);

  final String farmName;
  final DateTime start;
  final DateTime end;
  final IrrigationReportType type;
  final List<Map<String, dynamic>> records;

  static List<Map<String, dynamic>> _filter(
    List<Map<String, dynamic>> rows,
    DateTime start,
    DateTime end,
  ) {
    final first = DateTime(start.year, start.month, start.day);
    final afterLast = DateTime(end.year, end.month, end.day + 1);
    if (!first.isBefore(afterLast)) {
      throw ArgumentError(
        'A data inicial deve ser anterior ou igual à data final.',
      );
    }
    final selected = rows.where((row) {
      final date = DateTime.tryParse(row['dataIrrigacao']?.toString() ?? '');
      if (date == null) return false;
      // O backend devolve LocalDateTime, sem converter para outro fuso.
      final local = DateTime(
        date.year,
        date.month,
        date.day,
        date.hour,
        date.minute,
        date.second,
      );
      return !local.isBefore(first) && local.isBefore(afterLast);
    }).toList();
    selected.sort(
      (a, b) => b['dataIrrigacao'].toString().compareTo(
        a['dataIrrigacao'].toString(),
      ),
    );
    return selected;
  }

  bool includes(IrrigationReportType category) =>
      type == IrrigationReportType.complete || type == category;
}

double? _numberValue(Map<String, dynamic> row, String key) {
  final value = row[key];
  return value is num && value.isFinite && value >= 0 ? value.toDouble() : null;
}

String _number(double? value) {
  if (value == null) return 'Não informado';
  return value
      .toStringAsFixed(value == value.roundToDouble() ? 0 : 2)
      .replaceAll('.', ',');
}

double? _total(Iterable<double?> values) {
  final present = values.whereType<double>();
  return present.isEmpty
      ? null
      : present.fold<double>(0, (sum, value) => sum + value);
}

double? _mean(Iterable<double?> values) {
  final present = values.whereType<double>().toList();
  return present.isEmpty
      ? null
      : present.reduce((a, b) => a + b) / present.length;
}

String _date(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

String _dateTime(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'Não informado';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${_date(date)} ${two(date.hour)}:${two(date.minute)}';
}

String _name(dynamic value) {
  final result = value?.toString().trim();
  return result == null || result.isEmpty ? 'Não informado' : result;
}

class _Metric {
  const _Metric(
    this.label,
    this.key, {
    this.average = false,
    this.minutesToHours = false,
  });
  final String label;
  final String key;
  final bool average;
  final bool minutesToHours;
  double? read(Map<String, dynamic> row) {
    final value = _numberValue(row, key);
    return value != null && minutesToHours ? value / 60 : value;
  }

  double? aggregate(Iterable<Map<String, dynamic>> records) =>
      average ? _mean(records.map(read)) : _total(records.map(read));
}

List<_Metric> _metrics(IrrigationReport report) => [
  if (report.includes(IrrigationReportType.duration))
    const _Metric('Duração (horas)', 'duracaoMinutos', minutesToHours: true),
  if (report.includes(IrrigationReportType.water))
    const _Metric('Água estimada', 'volumeAgua'),
  if (report.includes(IrrigationReportType.energy))
    const _Metric('Energia estimada', 'consumoEnergia'),
  if (report.includes(IrrigationReportType.expenses)) ...[
    const _Metric('Gasto médio água', 'custoAgua', average: true),
    const _Metric('Gasto médio energia', 'custoEnergia', average: true),
  ],
];

/// Gera o arquivo localmente, com dados já devolvidos pelo servidor.
Future<Uint8List> buildIrrigationReportPdf(IrrigationReport report) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  );
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final metrics = _metrics(report);
  final byMonth = <String, List<Map<String, dynamic>>>{};
  for (final row in report.records) {
    final date = DateTime.parse(row['dataIrrigacao'].toString());
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    (byMonth[key] ??= []).add(row);
  }
  final months = byMonth.keys.toList()..sort();
  final monthlyValues = {
    for (final metric in metrics)
      metric: {
        for (final month in months) month: metric.aggregate(byMonth[month]!),
      },
  };
  final monthlyMaxima = {
    for (final metric in metrics)
      metric: monthlyValues[metric]!.values.whereType<double>().fold<double>(
        0,
        (max, value) => value > max ? value : max,
      ),
  };
  final accent = PdfColor.fromHex('#006E78');
  pw.Widget section(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: accent,
      ),
    ),
  );
  final monthHeaders = ['Mês', ...metrics.map((metric) => metric.label)];
  final monthRows = [
    for (final month in months)
      [
        '${month.substring(5, 7)}/${month.substring(0, 4)}',
        for (final metric in metrics) _number(monthlyValues[metric]![month]),
      ],
  ];
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      maxPages: 1000,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      build: (context) => [
        pw.Text(
          'Relatório de irrigação',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: accent,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Fazenda: ${report.farmName}'),
        pw.Text('Período: ${_date(report.start)} a ${_date(report.end)}'),
        pw.Text('Tipo: ${report.type.label}'),
        pw.Text('Registros no período: ${report.records.length}'),
        section('Resumo do período'),
        if (report.records.isEmpty)
          pw.Text('Nenhuma irrigação encontrada no período selecionado.')
        else
          for (final metric in metrics)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                '${metric.label}: ${_number(metric.aggregate(report.records))}',
              ),
            ),
        if (report.records.isNotEmpty) ...[
          if (report.includes(IrrigationReportType.expenses))
            pw.Text(
              'Custo total estimado: ${_number(_total(report.records.map((row) => _numberValue(row, 'custoTotal'))))}',
            ),
          section('Evolução mensal'),
          pw.TableHelper.fromTextArray(
            headers: monthHeaders,
            data: monthRows,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#DFEFEF'),
            ),
            cellPadding: const pw.EdgeInsets.all(5),
          ),
          section('Gráficos mensais'),
          for (final metric in metrics) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
              child: pw.Text(
                metric.label,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ),
            for (final month in months)
              _chartRow(
                month,
                monthlyValues[metric]![month],
                monthlyMaxima[metric]!,
                accent,
              ),
          ],
          pw.NewPage(freeSpace: 140),
          section('Histórico de irrigações'),
          for (final row in report.records)
            pw.Inseparable(
              canSpan: false,
              child: pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 7),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#D3DEDF')),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${_dateTime(row['dataIrrigacao'])} • Setor: ${_name(row['nomeSetor'])}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                    pw.Text(
                      'Dispositivo: ${_name(row['nomeDispositivo'])}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    for (final metric in metrics)
                      pw.Text(
                        '${metric.average ? metric.label.replaceFirst('Gasto médio', 'Custo') : metric.label}: ${_number(metric.read(row))}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    if (report.includes(IrrigationReportType.expenses))
                      pw.Text(
                        'Custo total estimado: ${_number(_numberValue(row, 'custoTotal'))}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                  ],
                ),
              ),
            ),
        ],
        section('Sobre os valores'),
        pw.Text(
          'Água, energia e custos são estimativas calculadas pelo servidor. Valores ausentes não entram nas somas ou médias. As médias são por irrigação com custo informado. A moeda e as unidades não acompanham os registros; não foram presumidas. Irrigações antigas registradas como execução de manejo não estão incluídas.',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
  );
  return pdf.save();
}

pw.Widget _chartRow(
  String month,
  double? value,
  double maximum,
  PdfColor color,
) {
  final width = value == null || maximum == 0 ? 0.0 : 200 * value / maximum;
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      children: [
        pw.SizedBox(
          width: 52,
          child: pw.Text(
            '${month.substring(5, 7)}/${month.substring(0, 4)}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.SizedBox(
          width: 210,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Container(width: width, height: 7, color: color),
          ),
        ),
        pw.Text(_number(value), style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
  );
}
