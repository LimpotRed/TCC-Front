# Ghydro frontend — especificação para agentes

## Escopo e finalidade

Este arquivo vale para todo o repositório `tcc-front`. Ele é a especificação operacional do frontend Ghydro e deve orientar qualquer agente que analise, corrija ou amplie o projeto.

O Ghydro é um aplicativo Flutter, em português do Brasil, para gestão e monitoramento de irrigação agrícola. O frontend consome exclusivamente a API Spring Boot localizada na pasta irmã `../TCC-BACKAND`. Contas e dados de negócio são persistidos pelo backend em PostgreSQL remoto.

Ao alterar comportamento funcional, contrato HTTP, regra de acesso, navegação ou responsividade, atualize este arquivo na mesma mudança. Não descreva aqui uma funcionalidade que ainda não existe.

## Hierarquia da fonte de verdade

1. A solicitação atual do usuário define a mudança desejada.
2. O contrato implementado no backend `../TCC-BACKAND` define rotas, autorização e JSON aceito.
3. `lib/resource_schema.dart` define os recursos e formulários genéricos atualmente expostos pelo frontend.
4. Este `AGENTS.md` define o comportamento esperado do produto e as invariantes do repositório.
5. `README.md` contém o guia curto de execução; `INTEGRACAO.md` contém o histórico e o roteiro de validação integrada.

Se código, backend e especificação divergirem, investigue a divergência antes de ampliar a mudança. Corrija o conjunto necessário para que contrato, interface, testes e documentação voltem a concordar.

## Roteiro de leitura por tarefa

Não é necessário ler todos os arquivos para cada mudança. Use esta rota:

| Tipo de tarefa | Arquivos principais |
| --- | --- |
| Inicialização, splash, tema global | `lib/main.dart`, `lib/brand.dart` |
| Login, cadastro, validação e sessão | `lib/login_screen.dart`, `lib/auth_service.dart`, `lib/auth_validation.dart`, `lib/api_client.dart` |
| Painel, perfil, indicadores e relatórios | `lib/dashboard_screen.dart` |
| Campos, enums, relacionamentos ou novo módulo | `lib/resource_schema.dart`, `lib/resource_screen.dart` |
| Contrato HTTP ou autorização | `lib/api_client.dart`, `lib/auth_service.dart`, `lib/resource_schema.dart` e os controllers/DTOs correspondentes em `../TCC-BACKAND` |
| Layout móvel | tela alterada e testes em `test/dashboard_test.dart`, `test/resource_test.dart` ou `test/auth_test.dart` |
| Execução local | `start-all.cmd`, `start-all.ps1`, `start-front.cmd`, `start-front.ps1`, `README.md` |

## Tecnologia e execução

- Flutter com Dart SDK `^3.13.2` e Material 3.
- Dependências de produção: Flutter, `http`, `cupertino_icons` e `flutter_localizations`.
- Locale único: `pt_BR`.
- Frontend web local: `http://localhost:8080`.
- API local padrão: `http://localhost:8081`.
- A URL da API vem de `--dart-define=API_BASE_URL=...`; o padrão fica em `ApiClient`.
- No emulador Android, use `http://10.0.2.2:8081` para alcançar o computador.
- O backend precisa permitir a origem do frontend em `CORS_ORIGINS`.

Comandos no Windows:

```powershell
# Backend e frontend juntos
.\start-all.cmd

# Somente o frontend
.\start-front.cmd

# Outra API
.\start-front.cmd -ApiBaseUrl 'https://api.exemplo.com'
```

O script conjunto espera o backend em `../TCC-BACKAND/start-backend.cmd`, inicia-o em segundo plano e mantém o Flutter no terminal atual.

## Estrutura do código

| Arquivo | Responsabilidade |
| --- | --- |
| `lib/main.dart` | entrada do app, tema escuro global e splash |
| `lib/brand.dart` | cores da marca e widget compartilhado da logo |
| `lib/login_screen.dart` | interface de login e cadastro |
| `lib/auth_validation.dart` | validação pura de nome, e-mail e nova senha |
| `lib/auth_service.dart` | cadastro, login, perfil, token e logout |
| `lib/api_client.dart` | HTTP, JSON, Bearer token, timeout e tradução de erros |
| `lib/dashboard_screen.dart` | início, gestão, perfil, relatórios e navegação inferior |
| `lib/resource_schema.dart` | metadados, campos, enums e relações dos 16 recursos |
| `lib/resource_screen.dart` | listagem e editor CRUD genéricos |
| `test/` | contratos e comportamento com HTTP simulado |
| `assets/images/image.png` | símbolo da marca usado na splash e no login |

O projeto não usa gerenciador de estado externo. O estado está nos `StatefulWidget`s e serviços injetáveis. Preserve esse padrão até existir uma necessidade clara e aprovada para outra arquitetura.

## Fluxo do aplicativo

### Inicialização e splash

1. `main()` abre `GhydroApp`.
2. `SplashScreen` mostra `GhydroLogo` e indicador de carregamento durante 2 segundos após o primeiro frame.
3. A splash usa `pushReplacement`, portanto não pode ser acessada pelo botão voltar.
4. O timer deve ser cancelado em `dispose()`.

### Login

- Campos: e-mail e senha.
- O formulário valida o e-mail e exige senha não vazia.
- O ícone de olho apenas alterna `obscureText` e mantém tooltip acessível.
- O login envia `POST /auth/login` com `{email, senha}`.
- E-mail é aparado e convertido para minúsculas.
- A resposta precisa conter `token` string.
- Após receber o token, o app consulta `GET /auth/me` antes de abrir o painel.
- Falha ao buscar o perfil invalida a sessão recém-criada.
- Login bem-sucedido abre `DashboardScreen` e remove o login da pilha de navegação.

### Cadastro

- Campos: nome, e-mail, senha e confirmação de senha.
- Nome precisa ter ao menos 2 caracteres após `trim()`.
- E-mail precisa ter formato válido.
- Nova senha precisa ter ao menos 8 caracteres e no máximo 72 bytes em UTF-8.
- Confirmação precisa ser idêntica à senha.
- O cadastro envia `POST /auth/register` com `{nome, email, senha, role: "PRODUTOR"}`.
- Cadastro concluído retorna para o modo login, mantém o e-mail, limpa senhas e exibe aviso de sucesso.
- O cadastro público sempre cria `PRODUTOR`; nunca ofereça escolha de perfil na interface pública.

### Sessão e logout

- O token JWT existe somente em memória em `ApiClient.token`.
- Não usar `localStorage`, banco local, cookie persistente ou fallback de sessão.
- Recarregar a página exige novo login.
- Requisições autenticadas enviam `Authorization: Bearer <token>`.
- Um `401` para uma requisição que usou o token atual limpa o token e chama `onUnauthorized` uma vez para voltar ao login.
- Logout limpa token e perfil e recria a tela de login sem rota anterior.

## Perfis e autorização

| Perfil | Leitura | Escrita pela interface | Observação |
| --- | --- | --- | --- |
| `PRODUTOR` | dados associados à própria conta | não | backend é responsável por filtrar o proprietário |
| `TECNICO` | recursos permitidos pelo backend | sim | `AuthService.canManage == true` |
| `ADMIN` | recursos permitidos pelo backend | sim | `AuthService.canManage == true` |

Regras obrigatórias:

- A interface oculta criar, editar e excluir quando `canManage` é falso.
- Recursos com `staffOnly: true` não aparecem para produtor.
- A proteção real também deve existir no backend; ocultar botões não substitui autorização HTTP.
- `403` não encerra a sessão.
- Não promover usuários nem ampliar acesso apenas no frontend.

## Painel principal

Ao entrar, `DashboardScreen` carrega em paralelo:

`propriedade`, `setor`, `plantio`, `dispositivoIrrigacao`, `sensor`, `recomendacao`, `execucaoManejo` e `configuracaoCusto`.

O callback de sessão expirada é instalado em `initState()` e removido em `dispose()`. Ao voltar de uma tela de recurso, o painel recarrega os dados se o token ainda existir. O `RefreshIndicator` também dispara a recarga.

### Cabeçalho e navegação

- Cabeçalho com avatar pela inicial do nome, saudação, botão de notificações e atualização.
- Notificações contam recomendações `PENDENTE` e sensores com bateria abaixo de 20%.
- Navegação inferior fixa com quatro destinos: `Início`, `Gestão`, `Perfil` e `Relatórios`.

### Início

- Anel de atividade: proporção de sensores com `status == ATIVO` sobre o total.
- Lista de até 4 dispositivos de irrigação, com nome, tipo, setor e eficiência quando disponível.
- Cartões de resumo: propriedades, setores, plantios `EM_ANDAMENTO` e recomendações `PENDENTE`.
- Em tela móvel com largura menor que 600 px, os quatro cartões de resumo são quadrados e aparecem em 2 colunas.
- Os cartões de dispositivos aparecem em 2 colunas quadradas.
- Em largura de conteúdo a partir de 800 px, anel e dispositivos ficam lado a lado; abaixo disso ficam empilhados.
- Se não houver propriedade, mostrar orientação diferente para equipe técnica e produtor.

### Gestão

- Lista os recursos de `resource_schema.dart`, agrupados em Fazenda, Cultivo, Monitoramento, Clima, Manejo e Gestão.
- Campo de busca filtra pelo título do módulo.
- Recurso `staffOnly` só aparece para `ADMIN` ou `TECNICO`.
- Tocar em um módulo abre `ResourceScreen` com o mesmo `ApiClient` autenticado.

### Perfil

- Exibe nome, e-mail, perfil de acesso e CPF.
- Edição permite nome obrigatório e CPF opcional.
- Salva com `PUT /auth/me` e atualiza `AuthService.profile`.
- Não existe validação completa de CPF no frontend atualmente.

### Relatórios

- Usa apenas registros reais de `execucaoManejo` já retornados pela API.
- Gráfico mostra soma de `volumeAguaAplicado` por mês nos últimos 6 meses.
- Resumo de todo o período mostra quantidade de execuções, volume de água e energia gasta.
- Os valores mantêm a unidade fornecida nos registros.
- Não calcular ou inventar economia financeira sem referência histórica fornecida pelo backend.
- Links abrem execuções de manejo e configurações de custo.

## Comportamento das telas de recursos

`ResourceScreen` e `ResourceEditor` implementam o CRUD a partir de `ResourceSpec` e `DataField`.

### Listagem

- Faz `GET /<path>` e mostra a resposta em ordem reversa.
- Ignora respostas antigas usando um contador de geração quando há carregamentos concorrentes.
- Busca local compara o texto digitado com todos os valores exibíveis da linha, sem diferenciar maiúsculas.
- Se houver `status` ou `statusPlantio`, cria filtros com `ChoiceChip`.
- Paginação é local, com 12 registros por página.
- Tocar no registro abre detalhes em diálogo.
- O campo `apiKey` nunca aparece no diálogo de detalhes.
- Produtor recebe interface somente leitura.
- Equipe técnica recebe botão de novo registro e menu de editar/excluir.
- Exclusão sempre exige confirmação explícita e alerta sobre vínculos dependentes.
- Erros preservam a tela e oferecem nova tentativa.
- Em manutenções, o menu inclui histórico do equipamento em `GET /admin/manutencao/equipamento/<tipoEquipamento>/<equipamentoId>`.

### Editor e serialização

| `FieldKind` | Controle | Valor enviado |
| --- | --- | --- |
| `text` | `TextFormField` | string aparada ou `null` |
| `number` | campo numérico | `double`; aceita vírgula na digitação |
| `integer` | campo numérico | `int` |
| `date` | seletor de data | ISO `yyyy-MM-dd` |
| `dateTime` | data e hora | ISO local sem fração de segundo |
| `choice` | dropdown | string do enum |
| `multi` | chips | lista de strings |
| `relation` | dropdown carregado por GET | `{ "id": valor }` |
| `relations` | chips carregados por GET | lista de `{ "id": valor }` |

- Recursos relacionados são carregados em paralelo antes de liberar o formulário.
- Campo obrigatório vazio deve bloquear envio e mostrar erro junto ao campo.
- Limites `min` e `max` definidos no schema precisam ser validados.
- Edição envia o `id` também no corpo.
- Criação usa `POST /<path>`.
- Edição normalmente usa `PUT /<path>/<id>`.
- `estacaoMetereologica` usa `PUT /estacaoMetereologica` por exigir `putAtRoot`.
- Campo `apiKey` é obscurecido e, em edição, não é enviado quando deixado vazio.
- Durante o salvamento, bloquear alterações e impedir que a tela seja fechada.
- Em erro, manter todos os valores preenchidos para correção e nova tentativa.

## Catálogo de recursos e contratos

Um campo sem `?` é obrigatório. `?` indica opcional. `-> recurso` indica relação por objeto `{id}`. Listas de relações usam `[{id}]`.

| Grupo | Rota | Campos aceitos pelo formulário |
| --- | --- | --- |
| Fazenda | `/proprietario` | `nome`, `cpf` |
| Fazenda | `/propriedade` | `nome`, `localizacao`, `proprietario -> proprietario`, `estacoes? -> [estacaoMetereologica]` |
| Fazenda | `/tipoSolo` | `descricao`, `capacidadeCampo`, `pontoMurcha`, `densidadeAparente?`, `taxaInfiltracaoBasica?` |
| Fazenda | `/setor` | `nome`, `poligonoGeografico`, `propriedade -> propriedade`, `tipoSolo -> tipoSolo` |
| Cultivo | `/cultura` | `nomePopular`, `variedade`, `nomeCientifico?` |
| Cultivo | `/estadoFenologico` | `cultura -> cultura`, `nomeFase`, `descricaoFase?`, `ordemSequencia`, `duracaoDias`, `kCFase?`, `profundidadeRaiz_cm?`, `sensibilidadeKY?` |
| Cultivo | `/plantio` | `cultura -> cultura`, `setor -> setor`, `dataPlantio`, `dataColheitaEstimada?`, `statusPlantio` |
| Monitoramento | `/dispositivoIrrigacao` | `nome`, `tipoDispositivo`, `setor -> setor`, `eficienciaIrrigacao?`, `vazaoNominal?`, `potenciaMotor?` |
| Monitoramento | `/sensor` | `setor -> setor`, `tipos[]`, `status`, `dataInstalacao`, `nivelBateria?` |
| Monitoramento | `/leituraSensor` | `sensor -> sensor`, `timestamp`, `valorBruto`, `valorTratado`, `unidadeMedida` |
| Clima | `/estacaoMetereologica` | `nome`, `tipo`, `latitude?`, `longitude?`, `apiSource?`, `apiKey?` |
| Clima | `/leituraClimatica` | `estacaoMetereologica -> estacaoMetereologica`, `dataHora`, `temperaturaMaxima?`, `temperaturaMinima?`, `umidadeRelativaAr?`, `velocidadeVento?`, `radiacaoSolar?`, `precipitacao?`, `etoCalculado?` |
| Manejo | `/recomendacao` | `plantio -> plantio`, `dataGeracao`, `tipoAcao`, `quantidade?`, `duracao?`, `observacoes?`, `agenteResponsavel?`, `status`, `dataConclusao?` |
| Manejo | `/execucaoManejo` | `plantio -> plantio`, `recomendacao? -> recomendacao`, `inicio`, `fim?`, `volumeAguaAplicado?`, `energiaGasta?`, `origem` |
| Gestão | `/configuracaoCusto` | `propriedade -> propriedade`, `custoM3Agua`, `custoKWh`, `moeda` |
| Gestão | `/admin/manutencao` | `tipoEquipamento`, `equipamentoId`, `tipoManutencao`, `dataManutencao`, `descricaoProblema?`, `solucaoAplicada?`, `tecnicoResponsavel?`; somente equipe |

Não corrija a grafia da rota `estacaoMetereologica` apenas no frontend: essa grafia faz parte do contrato atual do backend.

### Enumerações atuais

- Plantio: `PLANEJADO`, `EM_ANDAMENTO`, `CONCLUIDO`.
- Dispositivo: `PIVO`, `ASPERSOR`, `GOTEJAMENTO`, `TUBO_PERFURADO`, `MICROASPERSOR`.
- Sensor/status: `ATIVO`, `INATIVO`, `MANUTENCAO`.
- Sensor/grandezas: `TEMPERATURA`, `UMIDADE`, `VAZAO`, `PRESSAO`, `TENSAO`.
- Unidade: `PORCENTAGEM`, `GRAUS_CELSIUS`, `PPM`, `KPA`.
- Estação: `FISICA`, `VIRTUAL`.
- Ação: `IRRIGACAO`, `FERTIRRIGACAO`, `ADUBACAO`, `PULVERIZACAO`, `COLHEITA`.
- Recomendação/status: `PENDENTE`, `ACEITA`, `REJEITADA`, `EXECUTADA_AUTOMATICA`.
- Execução/origem: `AUTOMATICO`, `MANUAL`.
- Moeda: `BRL`, `USD`, `EUR`.
- Manutenção: `PREVENTIVA`, `CORRETIVA`, `TROCA_BATERIA`, `CALIBRACAO`, `SUBSTITUICAO_EQUIPAMENTO`.

`displayValue()` é o ponto central de tradução desses códigos para textos humanos. Ao criar um novo enum, adicione as opções ao campo e a tradução correspondente.

## Contrato HTTP e erros

- Todas as requisições usam `Content-Type: application/json; charset=utf-8`.
- Respostas são decodificadas explicitamente como UTF-8.
- Timeout: 25 segundos.
- Resposta `2xx` é sucesso, inclusive `204` sem corpo.
- Listagens precisam responder com array JSON; outro tipo gera `ApiFailure`.
- Se o backend responder `{ "message": "..." }`, essa mensagem tem prioridade.
- Fallbacks do frontend:
  - `401` no login: e-mail ou senha incorretos;
  - outro `401`: sessão expirada;
  - `403`: perfil sem permissão;
  - `404`: registro não encontrado;
  - `409`: conflito ou vínculo existente;
  - timeout e falha de conexão: mensagem própria;
  - demais erros: falha genérica da operação.

Não exibir token, senha, `apiKey`, segredo JWT, credenciais de banco ou conteúdo de `.env.ps1` em logs, telas, testes ou documentação versionada.

## Design, responsividade e acessibilidade

- Tema principal escuro: fundo `#15142F`, superfícies `#242144`, texto secundário `#A39DBF`, destaque ciano `#36C9D8` e sucesso `#65D99A`.
- Splash e login usam fundo `Color.fromARGB(255, 37, 69, 77)`; formulário de autenticação usa tema claro e destaque `#30C5C9`.
- Larguras máximas: autenticação 440 px, editor 720 px, recursos 1100 px, painel 1180 px.
- Todas as telas precisam funcionar a partir de 320 px sem overflow horizontal.
- Mantenha os cartões de resumo e de dispositivos em 2 colunas no celular.
- Textos extensos em cartões móveis devem limitar linhas e usar ellipsis quando necessário.
- Preserve `SafeArea`, rolagem vertical e alvos de toque Material.
- Campos devem manter label, mensagem de erro e ação de teclado coerentes.
- Ícones sem texto precisam de `tooltip` ou semântica equivalente.
- Mensagens assíncronas importantes usam `Semantics(liveRegion: true)`.
- Splash e logo mantêm rótulos semânticos; senha usa autofill apropriado e pode ser mostrada/ocultada.
- Todo texto visível ao usuário deve estar em português do Brasil, salvo códigos técnicos inevitáveis.

## Restrições e funcionalidades fora do escopo atual

- Não há banco local, modo offline, dados demonstrativos em produção ou fallback quando a API falha.
- Não há persistência do JWT entre recargas.
- Não há recuperação de senha por e-mail.
- Não há integração direta com o pivô físico.
- Não há coleta automática de sensores implementada neste repositório.
- Não há consulta automática a serviço climático.
- Não há algoritmo de geração automática de recomendações.
- Não há base histórica suficiente para calcular economia financeira.

Não simule essas capacidades na interface. Quando o backend não fornecer um dado, mostre estado vazio, `Não informado` ou uma explicação honesta.

## Convenções de implementação

- Siga o estilo existente e `flutter_lints`.
- Prefira widgets pequenos e helpers privados quando uma tela começar a acumular responsabilidades.
- Use `const` quando possível.
- Libere `TextEditingController`, timer, callback e outros recursos em `dispose()`.
- Após `await`, confira `mounted` antes de usar `context` ou `setState()`.
- Bloqueie envio repetido com estados `_busy` ou `_saving`.
- Preserve injeção de `ApiClient`/`AuthService` para testes.
- Não duplique regras de campos em várias telas; altere `resource_schema.dart` e o editor genérico.
- Não altere chaves JSON, enums, singular/plural de rotas ou formato de relações sem conferir o backend.
- Não introduza dependência nova quando widgets e bibliotecas já presentes resolvem a necessidade de forma clara.
- Não edite arquivos gerados em `build/` ou `.dart_tool/`.
- Preserve mudanças locais do usuário que não pertencem à tarefa.

## Fluxo de desenvolvimento orientado por especificação

Para qualquer funcionalidade nova ou alteração de comportamento:

1. Localize neste arquivo a regra afetada e confira a implementação atual nos arquivos indicados pelo roteiro de leitura.
2. Transforme o pedido em critérios observáveis: gatilho, resultado esperado, perfis afetados, estados de carregamento/erro/vazio e comportamento em 320 px e desktop.
3. Se houver dado ou chamada HTTP, confirme rota, método, payload, resposta e autorização no backend antes de alterar o frontend.
4. Atualize a seção correspondente desta especificação junto com a implementação. Se a decisão ainda não estiver aprovada, não a registre como comportamento existente.
5. Implemente pelo ponto central do projeto: schema para recursos/campos, `ApiClient` para HTTP, `AuthService` para sessão e widgets compartilhados para padrões visuais.
6. Adicione ou ajuste o teste que demonstra o critério de aceite e execute as verificações proporcionais à mudança.
7. Revise o diff final procurando contrato duplicado, dados inventados, quebra de autorização, overflow móvel e documentação desatualizada.

Ao receber uma solicitação ambígua, preserve as invariantes documentadas e faça a menor suposição reversível. Uma escolha que mude contrato de API, regra de acesso ou significado de dados exige confirmação do usuário ou evidência no backend.

## Testes e critérios de aceite

Testes atuais:

| Arquivo | Cobertura |
| --- | --- |
| `test/splash_test.dart` | atraso de 2 segundos, substituição de rota e cancelamento do timer |
| `test/auth_test.dart` | payloads de cadastro/login, JWT, perfil, erros, validação e navegação |
| `test/dashboard_test.dart` | painel em 320 e 1200 px, dados reais simulados, módulos, relatórios, perfil e logout |
| `test/resource_test.dart` | payload e edição dos 16 recursos, relações, tipos, erro preservado, leitura de produtor e rotas de exclusão |

Comandos de verificação:

```powershell
flutter analyze
flutter test
flutter build web
```

Os testes automatizados usam `MockClient` apenas no ambiente de teste. Nunca transportar respostas simuladas para a execução normal.

Para uma mudança ser considerada concluída:

1. O fluxo solicitado funciona nos perfis afetados.
2. Não existe overflow a 320 px nem regressão no desktop.
3. Carregamento, vazio, erro e sucesso continuam compreensíveis.
4. Dados sensíveis não aparecem na interface ou em logs.
5. Contrato HTTP e autorização continuam alinhados ao backend.
6. Testes diretamente relacionados passam; mudanças amplas devem rodar `flutter analyze` e `flutter test` completos.
7. Uma mudança de contrato deve atualizar `resource_schema.dart`, testes, este arquivo e, quando aplicável, `INTEGRACAO.md`.

## Validação integrada manual

Quando a tarefa envolver backend ou banco real, valide com `start-all.cmd` e percorra o fluxo afetado. Para uma validação completa:

1. Cadastrar um produtor, entrar, consultar e editar o perfil.
2. Entrar como técnico ou administrador e criar a cadeia proprietário → propriedade → setor → plantio → dispositivo/sensor → leitura → recomendação → execução.
3. Conferir relações entre propriedades e estações meteorológicas.
4. Entrar como dois produtores e confirmar o isolamento dos dados.
5. Confirmar conflitos e restrições de exclusão com registros vinculados.
6. Reiniciar navegador e backend para confirmar persistência remota e novo login após recarga.

Essa validação manual complementa os testes com HTTP simulado; ela não deve ser substituída por dados inventados no frontend.
