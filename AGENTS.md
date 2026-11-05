# Ghydro frontend — especificação para agentes

## Escopo e finalidade

Este arquivo vale para todo o repositório `tcc-front`. Ele é a especificação operacional do frontend Ghydro e deve orientar qualquer agente que analise, corrija ou amplie o projeto.

O Ghydro é um aplicativo Flutter, em português do Brasil, para gestão e monitoramento de irrigação agrícola. Contas e dados de negócio usam a API Spring Boot e são persistidos pelo backend em PostgreSQL remoto. O backend local atual está em `../../Tcc-Back/GHydro-BackEnd`, na Área de Trabalho; os scripts também aceitam a localização anterior `../TCC-BACKAND`. Fazendas e estações meteorológicas são cadastradas e vinculadas no aplicativo web da outra equipe; neste frontend, esses dois recursos são apenas consultados. O cartão de clima permite escolher a fazenda e consulta diretamente o Open-Meteo nas coordenadas de uma estação vinculada a ela.

Ao alterar comportamento funcional, contrato HTTP, regra de acesso, navegação ou responsividade, atualize este arquivo na mesma mudança. Não descreva aqui uma funcionalidade que ainda não existe.

## Hierarquia da fonte de verdade

1. A solicitação atual do usuário define a mudança desejada.
2. O contrato implementado no backend selecionado para execução define rotas, autorização e JSON aceito; confira a pasta atual antes de consultar a versão anterior.
3. `lib/resource_schema.dart` define os recursos e formulários genéricos atualmente expostos pelo frontend.
4. Este `AGENTS.md` define o comportamento esperado do produto e as invariantes do repositório.
5. `README.md` contém o guia curto de execução; `INTEGRACAO.md` contém o histórico e o roteiro de validação integrada.

Para a consulta climática externa, a [documentação oficial Open-Meteo](https://open-meteo.com/en/docs) define o contrato e o significado das variáveis.

Se código, backend e especificação divergirem, investigue a divergência antes de ampliar a mudança. Corrija o conjunto necessário para que contrato, interface, testes e documentação voltem a concordar.

## Roteiro de leitura por tarefa

Não é necessário ler todos os arquivos para cada mudança. Use esta rota:

| Tipo de tarefa | Arquivos principais |
| --- | --- |
| Inicialização, splash, tema global | `lib/main.dart`, `lib/brand.dart` |
| Login, cadastro, validação e sessão | `lib/login_screen.dart`, `lib/auth_service.dart`, `lib/auth_validation.dart`, `lib/api_client.dart` |
| Painel, irrigação, perfil, safras e relatórios | `lib/dashboard_screen.dart`, `lib/irrigation_screen.dart`, `lib/farm_planting_screen.dart`, `lib/farm_weather_card.dart` |
| Clima em Gestão > Clima > Leituras climáticas e Open-Meteo | `lib/dashboard_screen.dart`, `lib/resource_screen.dart`, `lib/farm_weather_card.dart`, `lib/open_meteo_service.dart` |
| Campos, enums, relacionamentos ou novo módulo | `lib/resource_schema.dart`, `lib/resource_screen.dart` |
| Contrato HTTP ou autorização | `lib/api_client.dart`, `lib/auth_service.dart`, `lib/resource_schema.dart` e os controllers/DTOs correspondentes no backend selecionado |
| Layout móvel | tela alterada e testes em `test/dashboard_test.dart`, `test/resource_test.dart` ou `test/auth_test.dart` |
| Execução local | `start-all.cmd`, `start-all.ps1`, `start-backend.ps1`, `start-front.cmd`, `start-front.ps1`, `README.md` |

## Tecnologia e execução

- Flutter com Dart SDK `^3.13.2` e Material 3.
- Dependências de produção: Flutter, `http`, `cupertino_icons` e `flutter_localizations`.
- Locale único: `pt_BR`.
- Frontend web local: `http://localhost:4200` por padrão; `-WebPort` permite alterar a porta.
- API local padrão: `http://localhost:8081`.
- A URL da API vem de `--dart-define=API_BASE_URL=...`; o padrão fica em `ApiClient`.
- No emulador Android, use `http://10.0.2.2:8081` para alcançar o computador.
- O CORS global do backend atual permite `http://localhost:4200`; outra porta depende da configuração da API em uso.
- Estimativas climáticas: `GET https://api.open-meteo.com/v1/forecast`, em um cliente separado do backend, sem JWT e sem chave de API.

Comandos no Windows:

```powershell
# Backend e frontend juntos
.\start-all.cmd

# Somente o frontend
.\start-front.cmd

# Outra API
.\start-front.cmd -ApiBaseUrl 'https://api.exemplo.com'
```

O script conjunto procura o backend em `../TCC-BACKAND` ou em `Tcc-Back/GHydro-BackEnd` na Área de Trabalho do usuário. `-BackendPath` permite selecionar outra pasta. Ele inicia o backend em segundo plano, aguarda a porta 8081 por até dois minutos e mantém o Flutter no terminal atual. Uma porta 8081 já ocupada interrompe essa inicialização para evitar outra API concorrente; para usar a API existente, execute somente o frontend.

O helper `start-backend.ps1` usa `start-backend.cmd` quando disponível ou o Maven wrapper para a versão Spring Boot 4 com JDK 21 ou mais recente; o projeto continua compilado para Java 21. Procura o JDK em `JAVA_HOME`, no `javac` do `PATH` e na extensão Red Hat Java do VS Code, alterando apenas o ambiente do processo. Antes de iniciar a API com Maven, executa `clean compile` para eliminar arquivos compilados inválidos após uma atualização do JDK. O Maven inicia com logs INFO e debug/trace desativados. Antes de emitir a saída dos launchers, o helper filtra linhas sensíveis e mascara valores de conexão e segredo carregados em memória, inclusive no arquivo local `.env.properties`. O script do frontend também reconhece Flutter em `C:\flutter\bin\flutter.bat`.

Na cópia atual do backend, `application.properties` contém credenciais e segredo em valores literais e define `spring.jpa.hibernate.ddl-auto=update`; a inicialização pode alterar o esquema do PostgreSQL. Não inicie esse backend nem seus testes de contexto contra o banco remoto até o responsável resolver a configuração. Não reproduza valores sensíveis em logs, telas ou documentação. Os segredos devem ser tratados como potencialmente expostos e sua rotação deve ser discutida com o responsável.

### Compatibilidade do backend copiado

A cópia atual em `Tcc-Back/GHydro-BackEnd` não implementa `GET /auth/me` ou `PUT /auth/me`. O login usa `GET /dominios/moedas` autenticado para confirmar que o token foi aceito e lê nome, e-mail e perfil das claims do JWT apenas para exibição e controles da interface. O servidor decide as permissões; o perfil da claim pode ficar desatualizado. CPF não está disponível nesse fluxo e a edição de perfil não conclui nessa API. O cadastro público do frontend envia `PRODUTOR`, mas o backend atual aceita o perfil enviado e não grava o nome informado como nome de conta.

O backend atual expoe `GET /estacaoMetereologica/propriedade/{id}`, autenticada, que retorna uma estacao como entidade. O cartao usa essa rota e so le nome e coordenadas; nunca mostra `apiKey`. A API nao oferece `GET /propriedade/{id}/estacoes`.

O backend tem `ADMIN`, `TECNICO` e `PRODUTOR`. A cópia atual não implementa as rotas `/propriedade/{id}/safras/...` usadas por `FarmPlantingScreen`; plantio, colheita e histórico nessa tela permanecem limitados. `GET /setor/propriedade/{id}` retorna setores com plantios aninhados e é usado no painel e na irrigação. Várias listagens e operações do backend não fazem isolamento completo por produtor; filtragem visual não substitui autorização no servidor. Consulte `INTEGRACAO.md` para o histórico e suas ressalvas.

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
| `lib/irrigation_control_screen.dart` | módulo de controle de irrigação, escolha da fazenda e acesso ao registro |
| `lib/irrigation_screen.dart` | seleção de setor, identificação de equipamento ativo e registro do intervalo de irrigação |
| `lib/farm_weather_card.dart` | `FarmWeatherCard`, seleção de fazenda, consulta da referência vinculada e estados de carregamento/erro/vazio |
| `lib/farm_planting_screen.dart` | setores da fazenda selecionada, início de plantio, registro de colheita e histórico produtivo |
| `lib/open_meteo_service.dart` | cliente Open-Meteo, validação de coordenadas e leitura das condições atuais e probabilidade horária |
| `lib/resource_schema.dart` | metadados, campos, enums e relações dos 16 recursos |
| `lib/resource_screen.dart` | listagem, detalhes, edição e exclusão genéricos |
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
- Após receber o token, o app consulta `GET /dominios/moedas` autenticado; o servidor valida o JWT. Com a resposta aceita, extrai nome, e-mail e perfil das claims para compor a interface.
- Falha de validação ou token com claims inválidas invalida a sessão recém-criada. O perfil informado na claim não substitui a autorização do servidor.
- Login bem-sucedido abre `DashboardScreen` e remove o login da pilha de navegação.

### Cadastro

- Campos: nome, e-mail, senha e confirmação de senha.
- Nome precisa ter ao menos 2 caracteres após `trim()`.
- E-mail precisa ter formato válido.
- Nova senha precisa ter ao menos 8 caracteres e no máximo 72 bytes em UTF-8.
- Confirmação precisa ser idêntica à senha.
- O cadastro envia `POST /auth/register` com `{nome, email, senha, role: "PRODUTOR"}`.
- Cadastro concluído retorna para o modo login, mantém o e-mail, limpa senhas e exibe aviso de sucesso.
- O formulário envia sempre `PRODUTOR` e não oferece escolha de perfil. O backend atual aceita outros perfis se enviados diretamente e não persiste o nome recebido; isso exige correção pelo responsável pelo backend.

### Sessão e logout

- O token JWT existe somente em memória em `ApiClient.token`.
- Não usar `localStorage`, banco local, cookie persistente ou fallback de sessão.
- Recarregar a página exige novo login.
- Requisições autenticadas enviam `Authorization: Bearer <token>`.
- Um `401` para uma requisição que usou o token atual limpa o token e chama `onUnauthorized` uma vez para voltar ao login.
- O cliente encerra a sessão ao receber 401 em uma requisição autenticada e mantém a sessão em 403. As respostas exatas dependem da configuração da API.
- Logout limpa token e perfil e recria a tela de login sem rota anterior.

## Perfis e autorização

| Perfil | Leitura | Escrita pela interface | Observação |
| --- | --- | --- | --- |
| `PRODUTOR` | recursos acessíveis pelo backend | registrar irrigação para setor acessível | o novo serviço verifica acesso ao setor; outras rotas ainda não isolam todas as relações |
| `TECNICO` | recursos acessíveis pelo backend | registro de irrigação e edição/exclusão nos recursos editáveis | `AuthService.canManage == true` |
| `ADMIN` | recursos acessíveis pelo backend | registro de irrigação e edição/exclusão nos recursos editáveis | `AuthService.canManage == true` |

Regras obrigatórias:

- Após o login, a tela de safras oferece criação de plantio e registro de colheita em um setor existente quando a API correspondente estiver disponível. A Gestão oferece registro de irrigação. Os editores genéricos não oferecem criação. O cadastro público de conta permanece disponível.
- A interface oculta editar e excluir quando `canManage` é falso.
- Recursos com `readOnly: true` não oferecem editar ou excluir para nenhum perfil. `propriedade`, `setor` e `estacaoMetereologica` usam essa regra porque o cadastro pertence ao aplicativo web da outra equipe.
- Recursos com `staffOnly: true` não aparecem para produtor.
- A proteção real também deve existir no backend; ocultar botões não substitui autorização HTTP.
- `403` não encerra a sessão.
- Não promover usuários nem ampliar acesso apenas no frontend.

## Painel principal

Ao entrar, `DashboardScreen` carrega em paralelo:

`propriedade`, `sensor` e `recomendacao`. Após carregar fazendas, consulta `GET /setor/propriedade/{id}` e usa os plantios aninhados para a contagem. Os relatórios carregam independentemente `GET /registroIrrigacao/propriedade/{id}` para a fazenda selecionada; falha nessa consulta não bloqueia a Home. A Home não consulta a listagem global de dispositivos nem de execuções de manejo.

O callback de sessão expirada é instalado em `initState()` e removido em `dispose()`. Ao voltar de uma tela de recurso, o painel recarrega os dados se o token ainda existir. O `RefreshIndicator` também dispara a recarga. Um timer recarrega o painel a cada 60 segundos e é cancelado em `dispose()`.

### Cabeçalho e navegação

- Cabeçalho com avatar pela inicial do nome, saudação, botão de notificações e atualização.
- Notificações contam recomendações `PENDENTE` e sensores com bateria abaixo de 20%.
- Navegação inferior fixa com quatro destinos: `Início`, `Gestão`, `Perfil` e `Relatórios`.

### Início

- Anel de atividade: proporção de sensores com `status == ATIVO` sobre o total.
- A Home não apresenta a lista, os cartões ou a eficiência de dispositivos de irrigação.
- Cartões de resumo mostram propriedades, setores, plantios `EM_ANDAMENTO` e sensores ativos da fazenda selecionada. Contagem de setores e plantios exibe `--` durante carga ou falha da consulta de setores.
- Em tela móvel com largura menor que 600 px, os quatro cartões de resumo são quadrados e aparecem em 2 colunas.
- Se não houver propriedade, orientar que a fazenda seja cadastrada e vinculada à conta no aplicativo web da equipe responsável.
- O cartão **Plantios em andamento** e o módulo **Plantios** abrem a tela de safras da fazenda selecionada.

### Registro de irrigação

- Em **Gestão > Monitoramento > Controle de irrigação**, o módulo oferece seleção de fazenda e o cartão **Registrar irrigação**, sem listagem genérica de dispositivos. A seleção inicial acompanha a fazenda do painel. O módulo consulta as fazendas e os setores da selecionada, apresenta carregamento, erro e nova tentativa, e ignora respostas antigas ao trocar de fazenda. Ao selecionar um setor no formulário, `GET /dispositivoIrrigacao/setor/{id}` fornece seus dispositivos e identifica o único com `ativo == true`. Nenhum dispositivo ativo, ou mais de um ativo, impede o registro e mostra uma mensagem.
- O produtor informa duração em horas/minutos, considerada encerrada no momento do registro, ou escolhe início e fim. O intervalo deve ser válido e não pode estar no futuro; não é exigido plantio ativo pela API nova.
- O formulário envia `POST /registroIrrigacao` com `{setorId, dataIrrigacao, duracaoMinutos}`, usando o início do intervalo como `dataIrrigacao`. O servidor identifica o dispositivo ativo, valida acesso ao setor e exige vazão e potência positivas e tarifas válidas de água e energia. Ele calcula e salva estimativas, tarifas e custos com o registro.
- Vazão e potência não têm unidades confirmadas explicitamente no modelo. A caixa inicia desmarcada; a prévia em m³/h e kW só aparece após confirmação pelo responsável. Essa opção não altera o cálculo do servidor, que ocorre ao salvar mesmo sem confirmação. Água, energia e custo são estimativas, não medições. A prévia pode diferir por arredondamento; os relatórios usam os valores devolvidos pela API. Os setores recarregam após salvar e o painel recarrega ao sair do módulo.

### Safras e setores

- `FarmPlantingScreen` continua implementada para APIs que exponham `/propriedade/{id}/safras/...`, mas essas rotas não existem na cópia atual do backend. Com ela, a tela mostra erro e suas ações de plantio, colheita e histórico não concluem.
- Numa API compatível, cada setor exibe o plantio ativo ou em descanso; o formulário de colheita envia somente `{dataColheita}`. A tela oferece recarga e ignora respostas antigas ao trocar de fazenda.
- O painel usa `GET /setor/propriedade/{id}` para contagens e registro de irrigação; isso não adapta nem garante os fluxos existentes da tela de safras.

### Clima em Leituras climáticas

- O cartão **Clima da fazenda** não aparece em **Início**. Ele fica em **Gestão > Clima > Leituras climáticas**. Esse módulo serve somente para exibir o cartão: não oferece busca, listagem, detalhes ou ações de registros e não consulta `/leituraClimatica`.
- O painel fornece a `FarmWeatherCard` as fazendas já carregadas em `GET /propriedade` ao abrir **Leituras climáticas**. O cartão escolhe inicialmente a primeira fazenda disponível; havendo mais de uma, oferece o seletor **Fazenda**. Não existe seletor de estação.
- O painel mantém `selectedFarmId` em memória entre abas e atualizações, enquanto a fazenda continuar disponível; **Atualizar clima** preserva a fazenda escolhida no cartão. A seleção não persiste após logout ou recarga do app.
- Para a fazenda selecionada, o cartao solicita `GET /estacaoMetereologica/propriedade/{id}` e interpreta o objeto da estacao vinculada retornado pela API atual.
- Uma estação precisa ter latitude finita entre -90 e 90 e longitude finita entre -180 e 180. O cartão aceita coordenadas numéricas ou strings com ponto/vírgula decimal; registros sem coordenadas válidas não são consultados.
- A primeira estação vinculada com coordenadas válidas é usada automaticamente como referência climática. Seu nome aparece como informação, sem comando de seleção ou edição. Não há consulta global de estações como alternativa para uma fazenda sem referência.
- Nome e localização textual identificam a fazenda; nome e coordenadas da referência identificam a origem da consulta. `propriedade.localizacao` é texto livre e não é interpretado como coordenadas. O selo `VIRTUAL` identifica a fonte de estimativas Open-Meteo, independentemente do tipo do equipamento cadastrado.
- O cartão climático não exibe indicadores de bateria ou umidade de sensores e não consulta `/propriedade/{id}/indicadores`. Baterias dos sensores permanecem disponíveis em outras áreas de monitoramento.
- A foto de perfil pode ser escolhida na tela Perfil e aparece tambem no avatar do cabecalho. A imagem fica somente na memoria da sessao e e descartada ao sair ou recarregar o app; o backend atual nao oferece armazenamento de foto.
- Exibe temperatura em °C, umidade relativa do ar em %, vento em km/h, condição meteorológica, hora atual da fazenda calculada pelo relógio do dispositivo e deslocamento UTC retornado pela API, e horário dos dados meteorológicos retornados pelo serviço. Um timer local mantém a hora atual avançando enquanto o cartão está aberto, sem novas consultas à API, e é cancelado ao sair ou recarregar o cartão. As condições atuais do Open-Meteo podem vir em passos de 15 minutos; por isso, o horário da amostra pode anteceder o relógio atual.
- “Chance de chuva na próxima hora” é a probabilidade em % associada ao próximo horário cheio, que representa a hora anterior a esse horário conforme a definição do Open-Meteo. Não representa volume medido; sem valor correspondente, mostrar `Não informado`.
- A consulta solicita `current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,is_day`, `hourly=precipitation_probability`, `forecast_days=2`, `temperature_unit=celsius` e `wind_speed_unit=kmh`.
- Os dados são estimativas de modelos meteorológicos, com atribuição visível ao Open-Meteo e CC BY 4.0. Valores ausentes aparecem como `Não informado`.
- A carga ocorre ao abrir **Leituras climáticas**; o botão **Atualizar clima** e a troca de fazenda fazem nova consulta de vínculos e clima. Atualizar o painel e reabrir o módulo também inicia nova consulta. Não há timer de consulta periódica, geolocalização do navegador nem coordenadas padrão copiadas da referência visual.
- Sem fazenda, vínculo ou coordenadas válidas, o cartão orienta solicitar o cadastro/configuração no aplicativo web da equipe responsável. Não oferece cadastro, edição ou criação de vínculo neste frontend, para nenhum perfil.
- Carregamento, ausência de referência válida e erro têm estados próprios; falha do Open-Meteo não transforma as listas do painel em erro nem encerra a sessão. Respostas antigas são ignoradas ao trocar de fazenda.
- Em larguras internas a partir de 480 px, temperatura e métricas meteorológicas ficam lado a lado; abaixo disso, ficam empilhadas para atender 320 px.
- Os dados consultados ficam em memória para exibição. Não são gravados em `/leituraClimatica` nem usados para gerar recomendações ou comandar irrigação.

### Gestão

- Lista os recursos de `resource_schema.dart`, agrupados em Fazenda, Cultivo, Monitoramento, Clima, Manejo e Gestão.
- Campo de busca filtra pelo título do módulo.
- Recurso `staffOnly` só aparece para `ADMIN` ou `TECNICO`.
- Tocar em um módulo abre `ResourceScreen` com o mesmo `ApiClient` autenticado, exceto **Plantios**, que abre `FarmPlantingScreen`, e **Controle de irrigação**, que abre `IrrigationControlScreen`.
- **Leituras climáticas** abre somente o cartão de clima; não solicita `/leituraClimatica`. Sair do módulo e voltar ao **Início** não exibe o cartão no painel.
- Fazendas, setores e estações meteorológicas oferecem somente listagem, busca e detalhes, com aviso de que os cadastros e alterações são feitos no aplicativo web da equipe responsável.

### Perfil

- Exibe nome, e-mail, perfil de acesso e CPF quando fornecidos; no login da cópia atual, CPF não é fornecido.
- Edição permite nome obrigatório e CPF opcional.
- A interface tenta salvar com `PUT /auth/me` e atualizar `AuthService.profile`; a rota está ausente na cópia atual do backend, então o salvamento não conclui com essa API.
- Não existe validação completa de CPF no frontend atualmente.

### Relatórios

- Usa `GET /registroIrrigacao/propriedade/{id}` para a fazenda selecionada, com estados de carga e erro independentes e descarte de respostas antigas. O servidor valida o acesso à propriedade.
- Os gráficos mostram duração e estimativas de água e energia registradas pelo servidor, agregadas por mês nos últimos 6 meses. Valores ausentes permanecem não informados. O resumo cobre todo o período. Registros antigos em `/execucaoManejo` não são incorporados automaticamente e continuam acessíveis no módulo de manejo.
- Não calcular ou inventar economia financeira sem referência histórica fornecida pelo backend.
- Links abrem execuções de manejo e configurações de custo.

## Comportamento das telas de recursos

`ResourceScreen` e `ResourceEditor` implementam listagem, detalhes, edição e exclusão a partir de `ResourceSpec` e `DataField`. O fluxo de criação não é exposto pela interface.

### Listagem

- Faz `GET /<path>` e mostra a resposta em ordem reversa.
- Ignora respostas antigas usando um contador de geração quando há carregamentos concorrentes.
- Busca local compara o texto digitado com todos os valores exibíveis da linha, sem diferenciar maiúsculas.
- Se houver `status` ou `statusPlantio`, cria filtros com `ChoiceChip`.
- Paginação é local, com 12 registros por página.
- Tocar no registro abre detalhes em diálogo.
- O campo `apiKey` nunca aparece no diálogo de detalhes.
- Produtor recebe interface somente leitura.
- Equipe técnica recebe menu de editar/excluir somente quando `ResourceSpec.readOnly` é falso. Nenhuma listagem mostra botão de novo registro.
- `propriedade`, `setor` e `estacaoMetereologica` são somente leitura para todos os perfis. O editor desses recursos não carrega relações nem apresenta formulário de escrita, mesmo quando aberto diretamente.
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
- A interface não abre o editor em modo de criação nem envia `POST /<path>` para cadastrar registros.
- Edição normalmente usa `PUT /<path>/<id>`.
- O schema conserva `putAtRoot` para estação; o backend atual usa `PUT /estacaoMetereologica/{id}`, mas o editor não envia essa operação porque o recurso é somente leitura neste frontend.
- Campo `apiKey` é obscurecido e, em edição, não é enviado quando deixado vazio.
- Durante o salvamento, bloquear alterações e impedir que a tela seja fechada.
- Em erro, manter todos os valores preenchidos para correção e nova tentativa.

## Catálogo de recursos e contratos

Um campo sem `?` é obrigatório. `?` indica opcional. `-> recurso` indica relação por objeto `{id}`. Listas de relações usam `[{id}]`. Os campos abaixo pertencem ao editor de registros existentes; não há formulário de criação. Os recursos marcados como somente leitura mantêm metadados de campos no schema, mas não expõem formulário de edição neste aplicativo.

| Grupo | Rota | Campos aceitos pelo formulário |
| --- | --- | --- |
| Fazenda | `/proprietario` | `nome`, `cpf` |
| Fazenda | `/propriedade` | somente leitura; `nome`, `localizacao`, `proprietario`; a rota de vínculos climáticos solicitada pelo frontend está ausente no backend atual |
| Fazenda | `/tipoSolo` | `descricao`, `capacidadeCampo`, `pontoMurcha`, `densidadeAparente?`, `taxaInfiltracaoBasica?` |
| Fazenda | `/setor` | somente leitura; `nome`, `poligonoGeografico`, `propriedade -> propriedade`, `tipoSolo -> tipoSolo` |
| Cultivo | `/cultura` | `nomePopular`, `variedade`, `nomeCientifico?` |
| Cultivo | `/estadoFenologico` | `cultura -> cultura`, `nomeFase`, `descricaoFase?`, `ordemSequencia`, `duracaoDias`, `kCFase?`, `profundidadeRaiz_cm?`, `sensibilidadeKY?` |
| Cultivo | `/plantio` | módulo abre a tela de safras por fazenda; os metadados do editor genérico preservam `cultura -> cultura`, `setor -> setor`, `dataPlantio`, `dataColheitaEstimada?`, `statusPlantio` |
| Cultivo | `/propriedade/{id}/safras/...` | contrato esperado pela tela de safras, ausente no backend atual |
| Monitoramento | `/dispositivoIrrigacao` | módulo abre o controle de irrigação; metadados preservam `nome`, `tipoDispositivo`, `setor -> setor`, `eficienciaIrrigacao?`, `vazaoNominal?`, `potenciaMotor?` |
| Monitoramento | `/sensor` | `setor -> setor`, `tipos[]`, `status`, `dataInstalacao`, `nivelBateria?` |
| Monitoramento | `/leituraSensor` | `sensor -> sensor`, `timestamp`, `valorBruto`, `valorTratado`, `unidadeMedida` |
| Clima | `/estacaoMetereologica` | somente leitura; `nome`, `tipo`, `latitude?`, `longitude?`, `apiSource?`; `apiKey` nunca exibida |
| Clima | `/leituraClimatica` | módulo exibe somente o cartão de clima; metadados do editor genérico preservam `estacaoMetereologica -> estacaoMetereologica`, `dataHora`, `temperaturaMaxima?`, `temperaturaMinima?`, `umidadeRelativaAr?`, `velocidadeVento?`, `radiacaoSolar?`, `precipitacao?`, `etoCalculado?` |
| Manejo | `/recomendacao` | `plantio -> plantio`, `dataGeracao`, `tipoAcao`, `quantidade?`, `duracao?`, `observacoes?`, `agenteResponsavel?`, `status`, `dataConclusao?` |
| Manejo | `/execucaoManejo` | `plantio -> plantio`, `recomendacao? -> recomendacao`, `inicio`, `fim?`, `volumeAguaAplicado?`, `energiaGasta?`, `origem`; histórico de manejo anterior |
| Monitoramento | `/registroIrrigacao` | registro por `setorId`, `dataIrrigacao` e `duracaoMinutos`; relatório por propriedade |
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

- Todas as requisições ao backend usam `Content-Type: application/json; charset=utf-8`.
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

O Open-Meteo usa `Accept: application/json`, decodificação UTF-8 e timeout de 25 segundos. Erros HTTP, limite de consultas (429), timeout, falha de conexão e JSON inválido recebem mensagens em português. Esse cliente nunca usa o token ou o callback de sessão do backend.

## Design, responsividade e acessibilidade

- Tema principal escuro: fundo `#15142F`, superfícies `#242144`, texto secundário `#A39DBF`, destaque ciano `#36C9D8` e sucesso `#65D99A`.
- Splash e login usam fundo `Color.fromARGB(255, 37, 69, 77)`; formulário de autenticação usa tema claro e destaque `#30C5C9`.
- Larguras máximas: autenticação 440 px, editor 720 px, recursos 1100 px, painel 1180 px.
- Todas as telas precisam funcionar a partir de 320 px sem overflow horizontal.
- Mantenha os cartões de resumo em 2 colunas no celular.
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
- A consulta Open-Meteo serve para exibir o clima em **Leituras climáticas**; não há persistência automática dessas estimativas como leituras climáticas no backend.
- Não há algoritmo de geração automática de recomendações.
- Não há base histórica suficiente para calcular economia financeira.

Não simule essas capacidades na interface. Quando a fonte de dados não fornecer um dado, mostre estado vazio, `Não informado` ou uma explicação honesta.

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
| `test/dashboard_test.dart` | painel em 320 e 1200 px, dados reais simulados, módulos, relatórios, perfil e logout; clima acessível por Gestão > Clima > Leituras climáticas, sem cartão no Início, com seleção por fazenda |
| `test/resource_test.dart` | ausência de criação na interface, contratos de edição, relações, tipos, erro preservado, leitura de produtor e exclusão; casos existentes adequados à consulta de fazendas/estações para todos os perfis |
| `test/open_meteo_service_test.dart` | contrato Open-Meteo, unidades, hora local, probabilidade correspondente, dados ausentes, coordenadas, erros e isolamento do cliente |
| `test/weather_station_card_test.dart` | `FarmWeatherCard`, seleção de fazenda, consulta de vínculos, ausência de indicadores, carga, erro, ausência de dados e respostas tardias |
| `test/farm_planting_screen_test.dart` | seleção de fazenda, setores em 320 px, contrato de plantio e colheita e histórico real do setor |
| `test/irrigation_screen_test.dart` | seleção de setor e equipamento, validações e envio do intervalo de irrigação com HTTP simulado |

A adequação dos casos de clima por fazenda e consulta de fazendas/estações não substitui a validação com os dados da equipe. Os testes de interface devem garantir que a criação após o login fica restrita aos fluxos específicos de safras e de registro de irrigação.

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

Uma validação integrada exige ambiente seguro e confirmação de que o backend selecionado não altera indevidamente o banco. Não execute `start-all.cmd` nem testes de contexto contra a cópia atual enquanto `ddl-auto=update` permanecer configurado no PostgreSQL remoto. Também são necessárias rotas compatíveis para clima e safras. Em ambiente apropriado, o roteiro histórico inclui:

1. Cadastrar um produtor pela tela pública, entrar, consultar e editar o perfil.
2. Cadastrar fazendas e estações e gravar seus vínculos no aplicativo web da equipe responsável; neste frontend, consultá-las com os perfis afetados. Nos demais módulos, conferir a cadeia proprietário → setor → plantio → dispositivo/sensor → leitura → recomendação → execução.
3. Conferir o clima de cada fazenda, a referência automática entre estações vinculadas e os estados vazios sem vínculo/coordenadas; confirmar ausência de comandos de escrita para fazendas, setores e estações em todos os perfis.
4. Entrar como dois produtores com proprietários distintos, confirmar isolamento de fazendas e safras, cadastrar plantio, registrar colheita e verificar o histórico; confirmar 403 para a fazenda alheia.
5. Confirmar conflitos de plantio ativo/colheita duplicada e restrições de exclusão com registros vinculados.
6. Reiniciar navegador e backend para confirmar persistência remota e novo login após recarga.

Essa validação manual complementa os testes com HTTP simulado; ela não deve ser substituída por dados inventados no frontend.
