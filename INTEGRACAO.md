# Integração Ghydro

## Estado atual

O frontend usa atualmente a API Spring Boot em `../../Tcc-Back/GHydro-BackEnd`, na Área de Trabalho, para autenticação e dados de negócio. O cartão de clima em **Gestão > Clima > Leituras climáticas** consulta diretamente o Open-Meteo. O script conjunto também aceita a pasta irmã `TCC-BACKAND` e uma pasta indicada com `-BackendPath`.

| Componente | Endereço local | Persistência |
| --- | --- | --- |
| Flutter Web | `http://localhost:8080` | Não persiste dados de negócio localmente |
| API Spring Boot | `http://localhost:8081` | PostgreSQL remoto |
| Estimativas meteorológicas | `https://api.open-meteo.com/v1/forecast` | Exibição em memória no frontend |
| Banco | Configuração da cópia atual do backend | PostgreSQL remoto configurado no backend |

Em 01/10/2026, uma execução anterior registrou os dois serviços ativos e conexão do backend com o PostgreSQL. Esse registro não valida os dados ou os fluxos atuais; `GET /auth/me`, CORS local, estações vinculadas e safras receberam mudanças depois daquela execução.

## Execução local

- Os scripts localizam a nova pasta e executam o backend com JDK 21 ou mais recente na porta 8081. A extensão Red Hat Java do VS Code atualizou o JDK embutido de 21 para 25 em 15/10/2026; o helper aceita essa versão, recompila com `clean compile` e o projeto permanece compilado para Java 21. O `clean compile` removeu um arquivo `.class` inválido que impedia a inicialização após a troca de JDK.

Em 15/10/2026, `start-all.cmd` iniciou os dois serviços com o JDK 25 da extensão: o backend conectou ao PostgreSQL, o frontend respondeu HTTP 200 em `localhost:8080` e a API aceitou o preflight CORS dessa origem. A execução de teste foi encerrada para deixar as portas livres no VS Code.

## Diferenças da cópia atual do backend

- `GET /auth/me` existe e responde apenas `id`, `nome`, `email`, `role` e `cpf` ao usuário autenticado. `PUT /auth/me` não existe; a edição do perfil depende dessa rota.
- O CORS global libera `http://localhost:8080` e `http://localhost:4200` por padrão. `CORS_ORIGINS` permite substituir a lista de origens.
- `GET /propriedade/{id}/indicadores` entrega apenas os percentuais agregados da fazenda acessível à conta; o endpoint não expõe as entidades de sensores ou leituras.
- `GET /propriedade/{id}/estacoes` verifica o acesso à fazenda e devolve apenas estações vinculadas, ordenadas por ID, com `id`, `nome`, `tipo`, `latitude`, `longitude`; omite `apiKey` e leituras. A previsão depende de vínculos reais na tabela `propriedade_estacao`.
- As rotas `/propriedade/{id}/safras/...` listam setores e ciclos, criam plantio e registram colheita com autorização por fazenda. A colheita grava apenas `plantio.data_colheita_real` e conclui o plantio, sem tabela adicional.
- O banco atual distingue `ADMIN`, `TECNICO` e `PRODUTOR`, sem role `PROPRIETARIO` nem tabela de autorização produtor–fazenda. Para `PRODUTOR`, o serviço de acesso considera `Usuario.proprietario` e o vínculo legado `Proprietario.usuarioId`, sempre pela propriedade do mesmo proprietário; conta sem vínculo não recebe fazendas. As listagens de fazenda, setor, plantio e recursos associados são filtradas por esses vínculos.
- O cadastro público do backend salva `nome` e força `PRODUTOR`, ignorando qualquer tentativa de escolher `ADMIN` ou `TECNICO` no corpo. O formulário público do frontend envia `PRODUTOR`.
- `GET /estacaoMetereologica` é filtrado para `PRODUTOR` pelas fazendas vinculadas e não serializa `apiKey`. O cartão continua usando somente a rota de estações vinculadas da fazenda.
- `Propriedade.estacoes` e `EstacaoMetereologica.propriedades` têm `@JsonIgnore`; as listagens usuais não expõem a associação. O POST/PUT atual de propriedade ignora `estacoes` e não grava esse vínculo. O aplicativo web da outra equipe é responsável por persistir as associações com estações pela integração própria; esta mudança não alterou rotas de cadastro, banco ou regras de escrita.
- As rotas de escrita genéricas exigem `ADMIN` ou `TECNICO`; a exceção para `PRODUTOR` é iniciar plantio e registrar colheita nas rotas de safras com acesso verificado. Os testes de autorização usam H2; a conferência com contas reais ainda depende da validação integrada.
- `application.properties` do backend usa variáveis `GHYDRO_DB_URL`, `GHYDRO_DB_USER`, `GHYDRO_DB_PASSWORD` e `GHYDRO_JWT_SECRET`, com importação opcional de `.env.properties` na raiz do backend. A configuração existente deste computador foi movida para esse arquivo local, ignorado pelo Git; `.env.properties.example` documenta as chaves sem valores reais. Na execução normal, Hibernate valida o esquema e não pode criar ou alterar tabelas. Os segredos antigos ainda existem no histórico do Git e precisam ser rotacionados por quem administra o banco e o JWT. Os testes usam H2 em `src/test/resources/application.properties` para não acessar o PostgreSQL remoto.
- Requisições sem autenticação ou com JWT inválido retornam 401; um produtor autenticado sem acesso à fazenda recebe 403. O cliente usa o 401 para encerrar a sessão e mantém a sessão em 403.

## Cobertura das telas

| Área | Rota da API | Operações na interface |
| --- | --- | --- |
| Proprietários | `/proprietario` | listar, pesquisar, detalhar, editar e excluir |
| Propriedades | `/propriedade` | listar, pesquisar e detalhar; somente leitura para todos os perfis |
| Tipos de solo | `/tipoSolo` | listar, pesquisar, detalhar, editar e excluir |
| Setores | `/setor` | listar, pesquisar e detalhar; somente leitura no mobile |
| Culturas | `/cultura` | listar, pesquisar, detalhar, editar e excluir |
| Estados fenológicos | `/estadoFenologico` | listar, pesquisar, detalhar, editar e excluir |
| Plantios e colheitas | `/propriedade/{id}/safras/...` | selecionar fazenda, listar setores, iniciar plantio, registrar colheita e consultar histórico |
| Dispositivos de irrigação | `/dispositivoIrrigacao` | listar, filtrar, detalhar, editar e excluir |
| Sensores | `/sensor` | listar, filtrar, detalhar, editar e excluir |
| Leituras de sensor | `/leituraSensor` | listar, pesquisar, detalhar, editar e excluir |
| Estações meteorológicas | `/estacaoMetereologica` | listar, pesquisar e detalhar; somente leitura para todos os perfis |
| Leituras climáticas | `/leituraClimatica` | o módulo exibe somente o cartão de clima por fazenda; não consulta essa rota |
| Recomendações | `/recomendacao` | listar, filtrar, detalhar, editar e excluir |
| Execuções de manejo | `/execucaoManejo` | listar, filtrar, detalhar, editar e excluir |
| Configurações de custo | `/configuracaoCusto` | listar, pesquisar, detalhar, editar e excluir |
| Manutenções | `/admin/manutencao` | listar, filtrar, consultar histórico, editar e excluir; somente equipe |

A tabela descreve os controles implementados no frontend, sem comprovar os fluxos contra o banco remoto atual. A consulta do perfil usa `GET /auth/me`; a edição solicita `PUT /auth/me`, ainda ausente nesta cópia. Cadastro público e login usam `/auth/register` e `/auth/login`. Após o login, somente a tela de safras permite criar plantio e colheita.

Os editores genéricos não oferecem criação, inclusive nas listas vazias e quando abertos diretamente. `propriedade`, `setor` e `estacaoMetereologica` usam `ResourceSpec.readOnly: true` e não oferecem editar ou excluir, inclusive para `ADMIN` e `TECNICO`; o cadastro e as alterações desses recursos pertencem ao aplicativo web da equipe responsável. Nos demais recursos, edição e exclusão seguem as permissões anteriores.

## Integração Open-Meteo

O cartão **Clima da fazenda**, implementado por `FarmWeatherCard` em `lib/farm_weather_card.dart`, aparece sozinho em **Gestão > Clima > Leituras climáticas**; foi removido de **Início**. Esse módulo não exibe busca ou lista de leituras e não chama `/leituraClimatica`. O cartão recebe do painel as fazendas carregadas em `GET /propriedade`. Seleciona a primeira inicialmente e oferece o campo **Fazenda** quando há várias. `selectedFarmId` fica em memória no painel entre abas e atualizações, enquanto a fazenda continuar disponível.

O cartão solicita `GET /propriedade/{id}/estacoes` para a fazenda selecionada e usa automaticamente a primeira estação vinculada com coordenadas válidas, em ordem crescente de ID. Não oferece seletor ou edição de estação; exibe seu nome como referência climática. Latitude e longitude vêm exclusivamente dessa estação, dentro dos intervalos -90 a 90 e -180 a 180. `propriedade.localizacao` é texto livre exibido como informação, sem extração de coordenadas ou geolocalização.

Fazendas, estações e vínculos são mantidos no aplicativo web da outra equipe. Sem fazenda disponível, associação ou coordenadas válidas, o cartão orienta solicitar a configuração nesse aplicativo. Não consulta a listagem global de estações nem usa uma localização de outra fazenda como alternativa. Troca de fazenda e atualização recarregam vínculos e clima; respostas antigas são ignoradas.

O cliente separado envia ao Open-Meteo apenas parâmetros de localização e clima, sem Bearer token ou chave. Solicita condições atuais (`temperature_2m`, `relative_humidity_2m`, `wind_speed_10m`, `weather_code`, `is_day`) e probabilidade horária (`precipitation_probability`), em °C/km/h, com `timezone=auto` e `forecast_days=2`. O cartão mostra o relógio local atual da fazenda, calculado com `utc_offset_seconds`, separado do horário da amostra atual do modelo (que pode usar passos de 15 minutos). A chance de chuva seleciona o próximo horário cheio porque a variável horária representa a probabilidade de precipitação na hora anterior a esse horário; valores ausentes não são substituídos por zero.

O cartão usa cores e superfícies do projeto, disposição adaptada a 320 px e atribuição ao [Open-Meteo](https://open-meteo.com/en/docs) sob CC BY 4.0. A identificação `VIRTUAL` se refere à fonte de estimativas. Falhas têm nova tentativa independente do painel; nenhuma consulta cria registros de leitura climática ou decisões de manejo no backend.

O backend ainda disponibiliza `GET /propriedade/{id}/indicadores` para consulta dos sensores da fazenda, mas o cartão **Clima da fazenda** não chama essa rota nem exibe baterias ou percentuais de umidade de sensores. O aviso de bateria baixa e o módulo de sensores permanecem no painel.

## Safras e histórico produtivo

O painel usa `GET /propriedade/{id}/safras/setores` para contar setores e plantios ativos apenas da fazenda selecionada. O cartão **Plantios em andamento** e o módulo **Plantios** abrem a tela de safras, que lista todos os setores dessa fazenda. A seleção é compartilhada com o clima e permanece em memória entre abas e recargas. A tela consulta as culturas em `GET /cultura` apenas quando o usuário abre o cadastro de plantio.

| Operação | Rota | Corpo/resultado |
| --- | --- | --- |
| Listar setores | `GET /propriedade/{id}/safras/setores` | `[{id,nome,status,plantioAtivo}]`; status `SAFRA_ATIVA` ou `EM_DESCANSO` |
| Histórico de setor | `GET /propriedade/{id}/safras/setores/{setorId}/historico` | plantios em ordem decrescente de data e ID, com colheita quando registrada |
| Iniciar plantio | `POST /propriedade/{id}/safras/setores/{setorId}/plantios` | `{culturaId,dataPlantio,dataColheitaEstimada?}`; 201 |
| Registrar colheita | `POST /propriedade/{id}/safras/setores/{setorId}/plantios/{plantioId}/colheita` | `{dataColheita}`; 201 |

O DTO de plantio contém `id`, `setorId`, `setorNome`, `culturaId`, `culturaNome`, `dataPlantio`, `dataColheitaEstimada`, `statusPlantio` e `dataColheita`. Para ciclos antigos, `dataColheita` usa `plantio.data_colheita_real` quando existe. A API valida proprietário, fazenda, setor e plantio em cada rota; outra fazenda gera 403 para `PRODUTOR`, IDs de setor ou plantio que não pertencem ao caminho geram 404. Plantio ativo ou colheita duplicada geram 409. Um novo plantio exige data até hoje e previsão posterior ao plantio; colheita exige data entre plantio e hoje.

O registro de colheita grava `plantio.data_colheita_real` e muda `statusPlantio` para `CONCLUIDO` na mesma transação. O backend usa `ddl-auto=validate` na execução normal, sem criação ou alteração automática do esquema. A tabela `colheita_produtiva` gerada anteriormente pode continuar no PostgreSQL, mas esta versão não a mapeia nem usa; sua eventual remoção deve ser tratada separadamente após conferir os dados. Setores e estações continuam cadastrados no sistema web.

## Validação da mudança atual

Os testes de interface usam HTTP simulado apenas no ambiente de teste e cobrem navegação até **Gestão > Clima > Leituras climáticas** sem cartão no **Início**, seleção de fazenda, setores em 320 px, cadastro, colheita, histórico, ausência de indicadores no clima e consulta Open-Meteo pelas coordenadas da estação vinculada. A suíte do backend com H2 testa autorização JWT, isolamento entre fazendas, IDs manipulados, duplicidade e ciclo completo sem acessar o PostgreSQL remoto. A validação com contas reais da equipe ainda precisa confirmar os vínculos `propriedade_estacao`, usuários vinculados a proprietários, setores, culturas e o fluxo de plantio e colheita.

Uma primeira execução do teste de inicialização, antes de isolar a configuração de teste, abriu conexão com o PostgreSQL usando o antigo `ddl-auto=update`. Ela foi interrompida; não é possível atribuir com certeza a criação da tabela a essa execução. A configuração de teste agora força H2. A consulta posterior, somente de leitura, encontrou 18 plantios, a coluna `data_colheita_real` e `colheita_produtiva` sem linhas; o backend iniciou com `ddl-auto=validate` e foi encerrado após a verificação.

Para conferir manualmente, inicie ambos os serviços, entre com uma conta vinculada, escolha cada fazenda, compare setores e cultura com o sistema web, registre plantio e colheita em ambiente apropriado e consulte o histórico após recarregar. Em outra conta, tente consultar a fazenda alheia e confirme o bloqueio. Em **Gestão > Clima > Leituras climáticas**, confirme que aparece somente o cartão, compare coordenadas e horário da estação e teste fazenda sem estação; confira também que o cartão não aparece em **Início**. A edição de perfil continua pendente da rota `PUT /auth/me`.

## Histórico — ajustes da versão anterior do backend

O registro abaixo se refere à versão anterior em `TCC-BACKAND`. Esses ajustes não foram transportados integralmente para `Tcc-Back/GHydro-BackEnd` e não representam a validação da cópia atual.

- Autenticação JWT com respostas 401 e 403 consistentes.
- Cadastro público limitado ao perfil `PRODUTOR`.
- Perfil autenticado sem expor senha.
- CORS centralizado e configurável.
- Escrita restrita a `ADMIN` e `TECNICO`.
- Listas operacionais filtradas por proprietário para `PRODUTOR`.
- Chaves de estações meteorológicas aceitas na escrita e omitidas na resposta.
- Contratos JSON corrigidos para plantios, estações, sensores e estados fenológicos.
- Validação entre recomendação, plantio e execução.
- Tratamento centralizado de erros de validação, conflito, acesso e recurso inexistente.
- Configuração exclusiva do PostgreSQL remoto por variáveis de ambiente.

## Limites do serviço existente

O repositório não contém integração com o equipamento físico do pivô, rotina de coleta automática dos sensores, gravação automática de estimativas Open-Meteo como leituras climáticas nem um algoritmo que gere recomendações. Também não existe recuperação de senha por e-mail ou uma referência histórica para calcular economia financeira.

Por isso, o painel mostra a proporção real de sensores ativos e os relatórios somam as execuções registradas. A interface informa quando a unidade ou a referência financeira não foi definida, sem inventar valores.

## Histórico — validação da versão anterior com o banco ativo

Na versão anterior, após o retorno do PostgreSQL, foram registrados:

- conexão TCP com o servidor;
- pool Hikari conectado ao PostgreSQL 17.11;
- inicialização do Hibernate e dos 17 repositórios JPA;
- teste completo de contexto usando o banco real;
- consulta real de autenticação, com credenciais inexistentes recusadas em 401;
- API protegida em 401 sem token e CORS liberado para o frontend local.

Esse histórico não comprova os fluxos da cópia atual. Após alinhar as rotas e as restrições pendentes, validar com os dados definitivos da equipe:

1. Cadastrar um produtor pela tela pública, entrar, consultar e editar o perfil.
2. Preparar as fazendas, estações e vínculos no aplicativo web responsável; neste frontend, consultar esses recursos e percorrer os demais módulos com técnico ou administrador.
3. Confirmar o clima por fazenda, as referências vinculadas e os estados vazios sem associação/coordenadas.
4. Entrar como dois produtores diferentes e verificar que cada um enxerga somente os próprios recursos.
5. Conferir as restrições de exclusão do banco e as mensagens exibidas pela interface.
6. Reiniciar backend e navegador para confirmar a persistência remota.

Os testes automatizados cobrem contratos, autorização e comportamento visual com HTTP simulado. Eles não substituem essa validação final no PostgreSQL real.
