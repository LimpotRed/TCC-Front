import 'package:flutter/material.dart';

enum FieldKind {
  text,
  number,
  integer,
  date,
  dateTime,
  choice,
  multi,
  relation,
  relations,
}

class DataField {
  const DataField(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.required = true,
    this.options = const [],
    this.resource,
    this.min,
    this.max,
    this.hint,
  });
  final String key, label;
  final FieldKind kind;
  final bool required;
  final List<String> options;
  final String? resource, hint;
  final double? min, max;
}

class ResourceSpec {
  const ResourceSpec(
    this.path,
    this.title,
    this.singular,
    this.group,
    this.icon,
    this.description,
    this.fields, {
    this.staffOnly = false,
    this.putAtRoot = false,
    this.deleteSlash = true,
  });
  final String path, title, singular, group, description;
  final IconData icon;
  final List<DataField> fields;
  final bool staffOnly, putAtRoot, deleteSlash;
  String label(Map<String, dynamic> row) {
    for (final key in ['nome', 'nomePopular', 'nomeFase', 'descricao']) {
      if (row[key] is String && (row[key] as String).isNotEmpty) {
        return row[key] as String;
      }
    }
    if (path == 'plantio') {
      return '${row['cultura']?['nomePopular'] ?? 'Plantio'} • #${row['id']}';
    }
    if (path == 'recomendacao') {
      return '${displayValue(row['tipoAcao'])} • #${row['id']}';
    }
    return '$singular #${row['id']}';
  }
}

String displayValue(dynamic value) {
  if (value == null || value == '') return 'Não informado';
  if (value is Map) {
    return (value['nome'] ??
            value['nomePopular'] ??
            value['nomeFase'] ??
            value['descricao'] ??
            '#${value['id']}')
        .toString();
  }
  if (value is List) return value.map(displayValue).join(', ');
  const names = {
    'PRODUTOR': 'Produtor',
    'TECNICO': 'Técnico',
    'ADMIN': 'Administrador',
    'ATIVO': 'Ativo',
    'INATIVO': 'Inativo',
    'MANUTENCAO': 'Em manutenção',
    'PIVO': 'Pivô',
    'ASPERSOR': 'Aspersor',
    'GOTEJAMENTO': 'Gotejamento',
    'TUBO_PERFURADO': 'Tubo perfurado',
    'MICROASPERSOR': 'Microaspersor',
    'PLANEJADO': 'Planejado',
    'EM_ANDAMENTO': 'Em andamento',
    'CONCLUIDO': 'Concluído',
    'PENDENTE': 'Pendente',
    'ACEITA': 'Aceita',
    'REJEITADA': 'Rejeitada',
    'EXECUTADA_AUTOMATICA': 'Executada automaticamente',
    'IRRIGACAO': 'Irrigação',
    'FERTIRRIGACAO': 'Fertirrigação',
    'ADUBACAO': 'Adubação',
    'PULVERIZACAO': 'Pulverização',
    'COLHEITA': 'Colheita',
    'AUTOMATICO': 'Automático',
    'MANUAL': 'Manual',
    'TEMPERATURA': 'Temperatura',
    'UMIDADE': 'Umidade',
    'VAZAO': 'Vazão',
    'PRESSAO': 'Pressão',
    'TENSAO': 'Tensão',
    'FISICA': 'Física',
    'VIRTUAL': 'Virtual',
    'PORCENTAGEM': 'Porcentagem',
    'GRAUS_CELSIUS': 'Graus Celsius',
    'PPM': 'PPM',
    'KPA': 'kPa',
    'PREVENTIVA': 'Preventiva',
    'CORRETIVA': 'Corretiva',
    'TROCA_BATERIA': 'Troca de bateria',
    'CALIBRACAO': 'Calibração',
    'SUBSTITUICAO_EQUIPAMENTO': 'Substituição de equipamento',
  };
  return names[value.toString()] ?? value.toString();
}

ResourceSpec resource(String path) =>
    resources.firstWhere((r) => r.path == path);

const resources = [
  ResourceSpec(
    'proprietario',
    'Proprietários',
    'Proprietário',
    'Fazenda',
    Icons.people_outline,
    'Pessoas responsáveis pelas propriedades.',
    [DataField('nome', 'Nome completo'), DataField('cpf', 'CPF')],
  ),
  ResourceSpec(
    'propriedade',
    'Propriedades',
    'Propriedade',
    'Fazenda',
    Icons.landscape_outlined,
    'Organize suas fazendas e estações de referência.',
    [
      DataField('nome', 'Nome'),
      DataField('localizacao', 'Localização'),
      DataField(
        'proprietario',
        'Proprietário',
        kind: FieldKind.relation,
        resource: 'proprietario',
      ),
      DataField(
        'estacoes',
        'Estações meteorológicas',
        kind: FieldKind.relations,
        resource: 'estacaoMetereologica',
        required: false,
      ),
    ],
  ),
  ResourceSpec(
    'tipoSolo',
    'Tipos de solo',
    'Tipo de solo',
    'Fazenda',
    Icons.layers_outlined,
    'Características físicas usadas no planejamento da irrigação.',
    [
      DataField('descricao', 'Descrição'),
      DataField(
        'capacidadeCampo',
        'Capacidade de campo',
        kind: FieldKind.number,
        min: 0.000001,
      ),
      DataField(
        'pontoMurcha',
        'Ponto de murcha',
        kind: FieldKind.number,
        min: 0.000001,
      ),
      DataField(
        'densidadeAparente',
        'Densidade aparente',
        kind: FieldKind.number,
        min: 0.000001,
        required: false,
      ),
      DataField(
        'taxaInfiltracaoBasica',
        'Taxa de infiltração básica',
        kind: FieldKind.number,
        min: 0.000001,
        required: false,
      ),
    ],
  ),
  ResourceSpec(
    'setor',
    'Setores',
    'Setor',
    'Fazenda',
    Icons.grid_view_rounded,
    'Divida a propriedade em áreas de cultivo e monitoramento.',
    [
      DataField('nome', 'Nome'),
      DataField(
        'poligonoGeografico',
        'Polígono geográfico',
        hint: 'Coordenadas ou GeoJSON da área',
      ),
      DataField(
        'propriedade',
        'Propriedade',
        kind: FieldKind.relation,
        resource: 'propriedade',
      ),
      DataField(
        'tipoSolo',
        'Tipo de solo',
        kind: FieldKind.relation,
        resource: 'tipoSolo',
      ),
    ],
  ),
  ResourceSpec(
    'cultura',
    'Culturas',
    'Cultura',
    'Cultivo',
    Icons.eco_outlined,
    'Catálogo de espécies e variedades cultivadas.',
    [
      DataField('nomePopular', 'Nome popular'),
      DataField('variedade', 'Variedade'),
      DataField('nomeCientifico', 'Nome científico', required: false),
    ],
  ),
  ResourceSpec(
    'estadoFenologico',
    'Fases fenológicas',
    'Fase fenológica',
    'Cultivo',
    Icons.spa_outlined,
    'Acompanhe cada etapa de desenvolvimento da cultura.',
    [
      DataField(
        'cultura',
        'Cultura',
        kind: FieldKind.relation,
        resource: 'cultura',
      ),
      DataField('nomeFase', 'Nome da fase'),
      DataField('descricaoFase', 'Descrição', required: false),
      DataField(
        'ordemSequencia',
        'Ordem na sequência',
        kind: FieldKind.integer,
        min: 1,
      ),
      DataField(
        'duracaoDias',
        'Duração (dias)',
        kind: FieldKind.integer,
        min: 1,
      ),
      DataField(
        'kCFase',
        'Coeficiente Kc',
        kind: FieldKind.number,
        min: 0.000001,
        required: false,
      ),
      DataField(
        'profundidadeRaiz_cm',
        'Profundidade da raiz (cm)',
        kind: FieldKind.number,
        min: 0.000001,
        required: false,
      ),
      DataField(
        'sensibilidadeKY',
        'Sensibilidade Ky',
        kind: FieldKind.number,
        required: false,
      ),
    ],
  ),
  ResourceSpec(
    'plantio',
    'Plantios',
    'Plantio',
    'Cultivo',
    Icons.grass,
    'Planeje o ciclo, acompanhe o cultivo e registre a conclusão.',
    [
      DataField(
        'cultura',
        'Cultura',
        kind: FieldKind.relation,
        resource: 'cultura',
      ),
      DataField('setor', 'Setor', kind: FieldKind.relation, resource: 'setor'),
      DataField('dataPlantio', 'Data de plantio', kind: FieldKind.date),
      DataField(
        'dataColheitaEstimada',
        'Colheita estimada',
        kind: FieldKind.date,
        required: false,
      ),
      DataField(
        'statusPlantio',
        'Situação',
        kind: FieldKind.choice,
        options: ['PLANEJADO', 'EM_ANDAMENTO', 'CONCLUIDO'],
      ),
    ],
  ),
  ResourceSpec(
    'dispositivoIrrigacao',
    'Pivôs e irrigação',
    'Dispositivo',
    'Monitoramento',
    Icons.water_drop_outlined,
    'Equipamentos e parâmetros de irrigação por setor.',
    [
      DataField('nome', 'Nome'),
      DataField(
        'tipoDispositivo',
        'Tipo',
        kind: FieldKind.choice,
        options: [
          'PIVO',
          'ASPERSOR',
          'GOTEJAMENTO',
          'TUBO_PERFURADO',
          'MICROASPERSOR',
        ],
      ),
      DataField('setor', 'Setor', kind: FieldKind.relation, resource: 'setor'),
      DataField(
        'eficienciaIrrigacao',
        'Eficiência (%)',
        kind: FieldKind.number,
        min: 0.000001,
        max: 100,
        required: false,
      ),
      DataField(
        'vazaoNominal',
        'Vazão nominal',
        kind: FieldKind.number,
        min: 0.000001,
        required: false,
      ),
      DataField(
        'potenciaMotor',
        'Potência do motor',
        kind: FieldKind.number,
        min: 0.000001,
        required: false,
      ),
    ],
  ),
  ResourceSpec(
    'sensor',
    'Sensores',
    'Sensor',
    'Monitoramento',
    Icons.sensors,
    'Situação, bateria e grandezas monitoradas no campo.',
    [
      DataField('setor', 'Setor', kind: FieldKind.relation, resource: 'setor'),
      DataField(
        'tipos',
        'Grandezas medidas',
        kind: FieldKind.multi,
        options: ['TEMPERATURA', 'UMIDADE', 'VAZAO', 'PRESSAO', 'TENSAO'],
      ),
      DataField(
        'status',
        'Situação',
        kind: FieldKind.choice,
        options: ['ATIVO', 'INATIVO', 'MANUTENCAO'],
      ),
      DataField('dataInstalacao', 'Instalação', kind: FieldKind.dateTime),
      DataField(
        'nivelBateria',
        'Bateria (%)',
        kind: FieldKind.number,
        min: 0,
        max: 100,
        required: false,
      ),
    ],
  ),
  ResourceSpec(
    'leituraSensor',
    'Leituras dos sensores',
    'Leitura',
    'Monitoramento',
    Icons.monitor_heart_outlined,
    'Histórico de medições brutas e tratadas.',
    [
      DataField(
        'sensor',
        'Sensor',
        kind: FieldKind.relation,
        resource: 'sensor',
      ),
      DataField('timestamp', 'Data e hora', kind: FieldKind.dateTime),
      DataField('valorBruto', 'Valor bruto', kind: FieldKind.number),
      DataField('valorTratado', 'Valor tratado', kind: FieldKind.number),
      DataField(
        'unidadeMedida',
        'Unidade',
        kind: FieldKind.choice,
        options: ['PORCENTAGEM', 'GRAUS_CELSIUS', 'PPM', 'KPA'],
      ),
    ],
  ),
  ResourceSpec(
    'estacaoMetereologica',
    'Estações meteorológicas',
    'Estação',
    'Clima',
    Icons.cloud_outlined,
    'Estações físicas e fontes de dados climáticos.',
    [
      DataField('nome', 'Nome'),
      DataField(
        'tipo',
        'Tipo',
        kind: FieldKind.choice,
        options: ['FISICA', 'VIRTUAL'],
      ),
      DataField('latitude', 'Latitude', required: false),
      DataField('longitude', 'Longitude', required: false),
      DataField('apiSource', 'Fonte de dados', required: false),
      DataField('apiKey', 'Chave de acesso', required: false),
    ],
    putAtRoot: true,
  ),
  ResourceSpec(
    'leituraClimatica',
    'Leituras climáticas',
    'Leitura climática',
    'Clima',
    Icons.thermostat_outlined,
    'Temperatura, chuva, vento e evapotranspiração registrados.',
    [
      DataField(
        'estacaoMetereologica',
        'Estação',
        kind: FieldKind.relation,
        resource: 'estacaoMetereologica',
      ),
      DataField('dataHora', 'Data e hora', kind: FieldKind.dateTime),
      DataField(
        'temperaturaMaxima',
        'Temperatura máxima (°C)',
        kind: FieldKind.number,
        required: false,
      ),
      DataField(
        'temperaturaMinima',
        'Temperatura mínima (°C)',
        kind: FieldKind.number,
        required: false,
      ),
      DataField(
        'umidadeRelativaAr',
        'Umidade relativa (%)',
        kind: FieldKind.number,
        min: 0,
        max: 100,
        required: false,
      ),
      DataField(
        'velocidadeVento',
        'Velocidade do vento',
        kind: FieldKind.number,
        min: 0,
        required: false,
      ),
      DataField(
        'radiacaoSolar',
        'Radiação solar',
        kind: FieldKind.number,
        min: 0,
        required: false,
      ),
      DataField(
        'precipitacao',
        'Precipitação',
        kind: FieldKind.number,
        min: 0,
        required: false,
      ),
      DataField(
        'etoCalculado',
        'ETo calculada',
        kind: FieldKind.number,
        required: false,
      ),
    ],
  ),
  ResourceSpec(
    'recomendacao',
    'Recomendações',
    'Recomendação',
    'Manejo',
    Icons.tips_and_updates_outlined,
    'Ações recomendadas para cada plantio e seu andamento.',
    [
      DataField(
        'plantio',
        'Plantio',
        kind: FieldKind.relation,
        resource: 'plantio',
      ),
      DataField('dataGeracao', 'Geração', kind: FieldKind.dateTime),
      DataField(
        'tipoAcao',
        'Ação',
        kind: FieldKind.choice,
        options: [
          'IRRIGACAO',
          'FERTIRRIGACAO',
          'ADUBACAO',
          'PULVERIZACAO',
          'COLHEITA',
        ],
      ),
      DataField(
        'quantidade',
        'Quantidade',
        kind: FieldKind.integer,
        min: 1,
        required: false,
      ),
      DataField('duracao', 'Duração', required: false, hint: 'Ex.: 30 minutos'),
      DataField('observacoes', 'Observações', required: false),
      DataField('agenteResponsavel', 'Responsável', required: false),
      DataField(
        'status',
        'Situação',
        kind: FieldKind.choice,
        options: ['PENDENTE', 'ACEITA', 'REJEITADA', 'EXECUTADA_AUTOMATICA'],
      ),
      DataField(
        'dataConclusao',
        'Conclusão',
        kind: FieldKind.dateTime,
        required: false,
      ),
    ],
  ),
  ResourceSpec(
    'execucaoManejo',
    'Execuções de manejo',
    'Execução',
    'Manejo',
    Icons.playlist_add_check,
    'Registre as operações realizadas e os recursos consumidos.',
    [
      DataField(
        'plantio',
        'Plantio',
        kind: FieldKind.relation,
        resource: 'plantio',
      ),
      DataField(
        'recomendacao',
        'Recomendação',
        kind: FieldKind.relation,
        resource: 'recomendacao',
        required: false,
      ),
      DataField('inicio', 'Início', kind: FieldKind.dateTime),
      DataField('fim', 'Fim', kind: FieldKind.dateTime, required: false),
      DataField(
        'volumeAguaAplicado',
        'Volume de água aplicado',
        kind: FieldKind.number,
        min: 0,
        required: false,
      ),
      DataField(
        'energiaGasta',
        'Energia gasta',
        kind: FieldKind.number,
        min: 0,
        required: false,
      ),
      DataField(
        'origem',
        'Origem',
        kind: FieldKind.choice,
        options: ['AUTOMATICO', 'MANUAL'],
      ),
    ],
  ),
  ResourceSpec(
    'configuracaoCusto',
    'Custos',
    'Configuração de custo',
    'Gestão',
    Icons.payments_outlined,
    'Defina as tarifas de água e energia de cada propriedade.',
    [
      DataField(
        'propriedade',
        'Propriedade',
        kind: FieldKind.relation,
        resource: 'propriedade',
      ),
      DataField(
        'custoM3Agua',
        'Custo por m³ de água',
        kind: FieldKind.number,
        min: 0,
      ),
      DataField('custoKWh', 'Custo por kWh', kind: FieldKind.number, min: 0),
      DataField(
        'moeda',
        'Moeda',
        kind: FieldKind.choice,
        options: ['BRL', 'USD', 'EUR'],
      ),
    ],
  ),
  ResourceSpec(
    'admin/manutencao',
    'Manutenções',
    'Manutenção',
    'Gestão',
    Icons.build_outlined,
    'Histórico de intervenções e responsáveis pelos equipamentos.',
    [
      DataField(
        'tipoEquipamento',
        'Tipo do equipamento',
        hint: 'Ex.: SENSOR ou PIVO',
      ),
      DataField(
        'equipamentoId',
        'Identificação do equipamento',
        kind: FieldKind.integer,
        min: 1,
      ),
      DataField(
        'tipoManutencao',
        'Tipo de manutenção',
        kind: FieldKind.choice,
        options: [
          'PREVENTIVA',
          'CORRETIVA',
          'TROCA_BATERIA',
          'CALIBRACAO',
          'SUBSTITUICAO_EQUIPAMENTO',
        ],
      ),
      DataField('dataManutencao', 'Data', kind: FieldKind.date),
      DataField('descricaoProblema', 'Problema encontrado', required: false),
      DataField('solucaoAplicada', 'Solução aplicada', required: false),
      DataField('tecnicoResponsavel', 'Técnico responsável', required: false),
    ],
    staffOnly: true,
    deleteSlash: false,
  ),
];
