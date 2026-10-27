import 'package:flutter/material.dart';

class DataField {
  const DataField(this.key, this.label);
  final String key, label;
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
  });
  final String path, title, singular, group, description;
  final IconData icon;
  final List<DataField> fields;
  final bool staffOnly;
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
    'SEM_RESPOSTA': 'Sem resposta',
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
    [
      DataField('nome', 'Nome completo'),
      DataField('cpf', 'CPF'),
      DataField('email', 'E-mail'),
    ],
  ),
  ResourceSpec(
    'propriedade',
    'Propriedades',
    'Propriedade',
    'Fazenda',
    Icons.landscape_outlined,
    'Consulte as fazendas e suas estações cadastradas no aplicativo web.',
    [
      DataField('nome', 'Nome'),
      DataField('localizacao', 'Localização'),
      DataField('proprietario', 'Proprietário'),
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
      DataField('capacidadeCampo', 'Capacidade de campo'),
      DataField('pontoMurcha', 'Ponto de murcha'),
      DataField('densidadeAparente', 'Densidade aparente'),
      DataField('taxaInfiltracaoBasica', 'Taxa de infiltração básica'),
    ],
  ),
  ResourceSpec(
    'setor',
    'Setores',
    'Setor',
    'Fazenda',
    Icons.grid_view_rounded,
    'Consulte os setores cadastrados no sistema web da fazenda.',
    [
      DataField('nome', 'Nome'),
      DataField('poligonoGeografico', 'Polígono geográfico'),
      DataField('propriedade', 'Propriedade'),
      DataField('tipoSolo', 'Tipo de solo'),
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
      DataField('nomeCientifico', 'Nome científico'),
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
      DataField('cultura', 'Cultura'),
      DataField('nomeFase', 'Nome da fase'),
      DataField('descricaoFase', 'Descrição'),
      DataField('ordemSequencia', 'Ordem na sequência'),
      DataField('duracaoDias', 'Duração (dias)'),
      DataField('kCFase', 'Coeficiente Kc'),
      DataField('profundidadeRaiz_cm', 'Profundidade da raiz (cm)'),
      DataField('sensibilidadeKY', 'Sensibilidade Ky'),
    ],
  ),
  ResourceSpec(
    'plantio',
    'Plantios',
    'Plantio',
    'Cultivo',
    Icons.grass,
    'Acompanhe o cultivo e registre a colheita.',
    [
      DataField('cultura', 'Cultura'),
      DataField('setor', 'Setor'),
      DataField('dataPlantio', 'Data de plantio'),
      DataField('dataColheitaEstimada', 'Colheita estimada'),
      DataField('statusPlantio', 'Situação'),
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
      DataField('tipoDispositivo', 'Tipo'),
      DataField('setor', 'Setor'),
      DataField('eficienciaIrrigacao', 'Eficiência (%)'),
      DataField('vazaoNominal', 'Vazão nominal'),
      DataField('potenciaMotor', 'Potência do motor'),
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
      DataField('setor', 'Setor'),
      DataField('tipos', 'Grandezas medidas'),
      DataField('status', 'Situação'),
      DataField('dataInstalacao', 'Instalação'),
      DataField('nivelBateria', 'Bateria (%)'),
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
      DataField('sensor', 'Sensor'),
      DataField('timestamp', 'Data e hora'),
      DataField('valorBruto', 'Valor bruto'),
      DataField('valorTratado', 'Valor tratado'),
      DataField('unidadeMedida', 'Unidade'),
    ],
  ),
  ResourceSpec(
    'estacaoMetereologica',
    'Estações meteorológicas',
    'Estação',
    'Clima',
    Icons.cloud_outlined,
    'Consulte as estações meteorológicas cadastradas no aplicativo web.',
    [
      DataField('nome', 'Nome'),
      DataField('tipo', 'Tipo'),
      DataField('latitude', 'Latitude'),
      DataField('longitude', 'Longitude'),
      DataField('apiSource', 'Fonte de dados'),
    ],
  ),
  ResourceSpec(
    'leituraClimatica',
    'Leituras climáticas',
    'Leitura climática',
    'Clima',
    Icons.thermostat_outlined,
    'Temperatura, chuva, vento e evapotranspiração registrados.',
    [
      DataField('estacaoMetereologica', 'Estação'),
      DataField('dataHora', 'Data e hora'),
      DataField('temperaturaMaxima', 'Temperatura máxima (°C)'),
      DataField('temperaturaMinima', 'Temperatura mínima (°C)'),
      DataField('umidadeRelativaAr', 'Umidade relativa (%)'),
      DataField('velocidadeVento', 'Velocidade do vento'),
      DataField('radiacaoSolar', 'Radiação solar'),
      DataField('precipitacao', 'Precipitação'),
      DataField('etoCalculado', 'ETo calculada'),
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
      DataField('plantio', 'Plantio'),
      DataField('dataGeracao', 'Geração'),
      DataField('tipoAcao', 'Ação'),
      DataField('quantidade', 'Quantidade'),
      DataField('duracao', 'Duração'),
      DataField('observacoes', 'Observações'),
      DataField('agenteResponsavel', 'Responsável'),
      DataField('status', 'Situação'),
      DataField('dataConclusao', 'Conclusão'),
    ],
  ),
  ResourceSpec(
    'execucaoManejo',
    'Execuções de manejo',
    'Execução',
    'Manejo',
    Icons.playlist_add_check,
    'Consulte as operações realizadas e os recursos consumidos.',
    [
      DataField('plantio', 'Plantio'),
      DataField('recomendacao', 'Recomendação'),
      DataField('inicio', 'Início'),
      DataField('fim', 'Fim'),
      DataField('volumeAguaAplicado', 'Volume de água aplicado'),
      DataField('energiaGasta', 'Energia gasta'),
      DataField('origem', 'Origem'),
    ],
  ),
  ResourceSpec(
    'configuracaoCusto',
    'Custos',
    'Configuração de custo',
    'Gestão',
    Icons.payments_outlined,
    'Consulte as tarifas de água e energia de cada propriedade.',
    [
      DataField('propriedade', 'Propriedade'),
      DataField('custoM3Agua', 'Custo por m³ de água'),
      DataField('custoKWh', 'Custo por kWh'),
      DataField('moeda', 'Moeda'),
    ],
  ),
  ResourceSpec(
    'manutencao',
    'Manutenções',
    'Manutenção',
    'Gestão',
    Icons.build_outlined,
    'Histórico de intervenções e responsáveis pelos equipamentos.',
    [
      DataField('tipoEquipamento', 'Tipo do equipamento'),
      DataField('equipamentoId', 'Identificação do equipamento'),
      DataField('tipoManutencao', 'Tipo de manutenção'),
      DataField('dataManutencao', 'Data'),
      DataField('descricaoProblema', 'Problema encontrado'),
      DataField('solucaoAplicada', 'Solução aplicada'),
      DataField('tecnicoResponsavel', 'Técnico responsável'),
    ],
    staffOnly: true,
  ),
];
