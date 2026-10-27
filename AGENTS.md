# Ghydro — instruções para agentes

## Objetivo e fonte de verdade

O Ghydro é um aplicativo Flutter em português para consulta e monitoramento de irrigação agrícola. O backend selecionado é `C:\Users\Aluno\Desktop\TCC BACK\GHydro-BackEnd`; não altere seus arquivos. Confira os controllers e modelos dessa pasta antes de alterar contratos. Preserve mudanças locais existentes no frontend e atualize esta especificação quando mudar comportamento.

Após o login, as telas de dados são somente para consulta, exceto o cadastro de plantio e o registro de colheita para perfis autorizados. A criação da conta continua disponível no fluxo público de autenticação. A foto de perfil é uma preferência local e não altera dados do backend.

## Arquivos principais

- `lib/main.dart`, `lib/brand.dart`: entrada, tema e marca.
- `lib/login_screen.dart`, `lib/auth_service.dart`, `lib/auth_validation.dart`: login, cadastro e sessão.
- `lib/api_client.dart`: HTTP, JSON, Bearer token, timeout e tratamento de erros.
- `lib/dashboard_screen.dart`: início, gestão, perfil, relatórios e navegação.
- `lib/resource_schema.dart`, `lib/resource_screen.dart`: metadados e consulta das telas de recursos.
- `lib/farm_planting_screen.dart`: consulta de setores e histórico, cadastro de plantio e registro de colheita.
- `lib/farm_weather_card.dart`, `lib/open_meteo_service.dart`: clima por fazenda e cliente Open-Meteo.
- `lib/profile_photo_service.dart`: seleção e armazenamento da foto local por conta.
- `test/`: testes de comportamento e contratos com HTTP simulado.
- `README.md`, `INTEGRACAO.md`: execução e integração.

## Execução e proteção do backend

- Flutter web usa `http://localhost:4200` e API usa `http://localhost:8081` por padrão; `API_BASE_URL` é configurável por `--dart-define`.
- `start-all.cmd` inicia uma cópia temporária do backend e o frontend. O launcher aplica `spring.jpa.hibernate.ddl-auto=none` ao processo para não atualizar o esquema. O backend tem rotina agendada que pode atualizar status de sensores no banco real.
- A API lê a conexão PostgreSQL e o segredo JWT da configuração própria. Não expor segredos ou alterar a pasta do backend.
- O CORS da versão selecionada permite `http://localhost:4200`.

## Autenticação e sessão

- Login: `POST /auth/login` com `email` e `senha`; o JWT contém `sub`, `nome` e `role`. A autorização é responsabilidade do backend.
- Cadastro público: `POST /auth/register` com `email`, `senha` e `role: PRODUTOR`. O backend atual define o nome inicial do proprietário.
- O JWT fica apenas em memória; recarregar exige novo login. Não armazenar token ou senha localmente.
- Logout limpa sessão. Tratar erros HTTP e falhas de conexão sem inventar dados.

## Navegação e consulta

- As abas são Início, Gestão, Perfil e Relatórios. O painel carrega propriedades, dispositivos, sensores, recomendações, execuções e custos. A fazenda selecionada também alimenta clima e contagens por setor.
- Os módulos são declarados em `resources`: proprietários, propriedades, tipos de solo, setores, culturas, fases fenológicas, plantios, dispositivos de irrigação, sensores, leituras de sensores, estações, leituras climáticas, recomendações, execuções, custos e manutenções. Manutenção é reservada a ADMIN e TECNICO conforme o backend.
- Listagens permitem busca, detalhes, filtros e paginação visual. Histórico de manutenção usa `GET /manutencao/equipamento/{tipo}/{id}`. Nenhuma delas envia alteração ou exclusão.
- O perfil mostra os dados fornecidos no token. Foto opcional é salva apenas no navegador/dispositivo, por e-mail, até 512 KB após seleção. Pode ser adicionada, trocada ou removida; não é enviada ao backend nem sincronizada. Não salvar credenciais junto da foto.
- Em celular, manter dois cartões de resumo e dois cartões de dispositivos por linha; garantir rolagem e ausência de overflow em 320 px.

## Setores, plantio e colheita

- `GET /setor/propriedade/{id}` retorna setores e `plantios` aninhados; a interface mostra safra atual e histórico, inclusive duplicações já existentes, sem excluir dados.
- Cada setor pode ter apenas uma safra não concluída no aplicativo. Plantios antigos `PLANEJADO` também ocupam o setor; o backend não permite concluí-los diretamente. O formulário só fica disponível sem safra aberta e consulta o setor novamente antes do envio; em erro ou dados incompletos, não envia. Após conclusão é possível cadastrar uma nova safra, mantendo o histórico.
- Essa verificação não é atômica: o backend não garante unicidade, portanto requisições simultâneas ou clientes externos ainda podem criar duplicatas. Não afirmar que o frontend garante a regra no banco.
- `ADMIN`, `TECNICO` e `PRODUTOR` podem cadastrar plantio com `POST /plantio`: selecionar cultura de `GET /cultura`, data de plantio e previsão opcional posterior à data de plantio. O formulário não oferece seleção de situação e envia sempre `EM_ANDAMENTO`. Enviar setor e cultura como objetos com `id`; atualizar setores após fechar o formulário. O acesso do produtor é limitado às suas propriedades pelo serviço do backend.
- Para plantio `EM_ANDAMENTO`, `ADMIN`, `TECNICO` e `PRODUTOR` podem registrar colheita. A permissão de plantio é independente da permissão de equipe usada em outros módulos.
- A rota de atualização `PUT /plantio/{id}` do backend também aceita alterações gerais de plantio pelo produtor; o aplicativo oferece somente o registro de colheita e não expõe edição geral.
- O aplicativo escolhe a data entre a data de plantio e hoje e envia `PUT /plantio/{id}` preservando `setor: {id}`, `cultura: {id}`, `dataPlantio` e `dataColheitaEstimada`, com `dataColheitaReal` e `statusPlantio: CONCLUIDO`. As datas enviadas usam `aaaa-MM-dd`.
- Atualize os setores após sucesso; preserve mensagens de erro e acessibilidade em 320 px.

## Clima

- Em Gestão > Clima > Leituras climáticas, o cartão usa `GET /estacaoMetereologica/propriedade/{id}`, que retorna uma estação ou vazio.
- Coordenadas válidas da estação são usadas na API Open-Meteo, em cliente separado e sem token. Mostre os estados de carga, falha e ausência de estação; não invente localização nem grave estimativas climáticas no backend.
- Não exibir ou pesquisar o campo `apiKey`.

## Verificação

Execute `flutter analyze` e os testes relevantes em `test/`; mudanças amplas devem incluir `flutter test` e `flutter build web`. Os testes não devem alterar o banco real. Para mudanças HTTP, confira métodos, payloads e permissões no backend. Na resposta ao usuário, informe limitações e testes não realizados.
