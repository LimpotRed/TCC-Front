# Ghydro — frontend

Aplicativo Flutter conectado ao backend Spring Boot. O script de execução procura o backend na pasta irmã `TCC-BACKAND` ou em `Tcc-Back\GHydro-BackEnd` na Área de Trabalho do usuário.

O backend usado atualmente está em `../../Tcc-Back/GHydro-BackEnd`. Essa cópia atende `GET /auth/me`, `GET /propriedade/{id}/estacoes`, as rotas de safras por fazenda e a origem local `http://localhost:8080`. `PUT /auth/me` continua ausente, portanto a edição do perfil ainda não conclui. Veja as [limitações atuais da integração](INTEGRACAO.md#diferenças-da-cópia-atual-do-backend).

As contas e os dados do sistema são persistidos pelo backend no PostgreSQL remoto. O aplicativo não usa banco local, `localStorage` ou dados demonstrativos como alternativa. O token de acesso fica somente na memória; ao recarregar a página, é necessário entrar novamente.

## Executar no Windows

Para iniciar o backend e o frontend juntos, execute na pasta deste projeto:

```powershell
.\start-all.cmd
```

Esse comando inicia o backend em segundo plano, aguarda a porta 8081 por até dois minutos e inicia o Flutter em [http://localhost:8080](http://localhost:8080), usando a API em `http://localhost:8081`. O terminal informa os arquivos de log temporários do backend. Se a porta 8081 já estiver ocupada, o script informa isso e evita iniciar outra API.

Para indicar outra pasta do backend:

```powershell
.\start-all.cmd -BackendPath 'C:\Users\lucas\OneDrive\Área de Trabalho\Tcc-Back\GHydro-BackEnd'
```

O backend pode ter `start-backend.cmd` ou `mvnw.cmd`. Neste último caso, `start-backend.ps1` recompila o backend com `clean compile` e executa `spring-boot:run` na porta 8081, usando JDK 21 ou mais recente. Ele procura o JDK em `JAVA_HOME`, no `javac` do `PATH` e no Java instalado pela extensão Red Hat Java do VS Code. A seleção altera o ambiente somente do processo do backend, sem configuração permanente do Windows.

O frontend procura Flutter no `PATH`, em `C:\flutter\bin\flutter.bat` e, como alternativa, em `C:\Users\Aluno\develop\flutter\bin\flutter.bat`. O backend lê a conexão e o segredo JWT de variáveis `GHYDRO_DB_URL`, `GHYDRO_DB_USER`, `GHYDRO_DB_PASSWORD` e `GHYDRO_JWT_SECRET` ou do arquivo local `Tcc-Back/GHydro-BackEnd/.env.properties`. A configuração local deste computador foi preservada nesse arquivo, que é ignorado pelo Git; em outra máquina, copie `.env.properties.example` e preencha os valores. A API valida o esquema existente e não cria nem altera tabelas na inicialização normal.

Também é possível iniciar os serviços em terminais separados, a partir da pasta deste frontend:

1. Inicie o backend no primeiro terminal:

```powershell
.\start-backend.ps1 -BackendPath 'C:\Users\lucas\OneDrive\Área de Trabalho\Tcc-Back\GHydro-BackEnd'
```

2. Em outro terminal, inicie o frontend:

```powershell
.\start-front.cmd
```

3. Abra [http://localhost:8080](http://localhost:8080).

O frontend usa `http://localhost:8081` como API por padrão. Para apontar para uma API hospedada:

```powershell
.\start-front.cmd -ApiBaseUrl 'https://api.exemplo.com'
```

`start-all.cmd` também aceita `-ApiBaseUrl` para definir a API usada pelo frontend. O mesmo valor pode ser passado diretamente ao Flutter com `--dart-define=API_BASE_URL=...`. No emulador Android, use `http://10.0.2.2:8081` para acessar o backend do computador. O backend permite `http://localhost:8080` e `http://localhost:4200` por padrão; `CORS_ORIGINS` substitui essas origens quando necessário. Em produção, publique frontend e API com HTTPS.

## Funcionalidades da interface

- Cadastro público de conta, login e consulta do perfil pela API; a edição do perfil depende de `PUT /auth/me`, ausente no backend atual.
- Painel com propriedades, dispositivos, sensores e execuções reais.
- Cartão de clima em **Gestão > Clima > Leituras climáticas**, com temperatura, chance de chuva, umidade e vento do Open-Meteo nas coordenadas de uma estação vinculada.
- Safras por fazenda: consulta dos setores, início de plantio em setor disponível, registro de colheita e histórico produtivo.
- Consulta de fazendas, setores e estações cadastrados no aplicativo web da outra equipe, sem comandos de escrita para esses recursos.
- Consulta, edição e exclusão dos demais módulos disponíveis no backend, conforme as permissões de acesso. A criação após o login existe somente para plantio e colheita na tela de safras.
- Pesquisa, filtros de situação, paginação visual, detalhes e confirmação antes de excluir.
- Seletores de relacionamentos, datas, horários e enumerações nos formulários disponíveis.
- Histórico administrativo de manutenções.
- Relatórios calculados a partir das execuções de manejo retornadas pela API.

O perfil `PRODUTOR` pode iniciar plantios e registrar colheitas nas fazendas ligadas ao seu proprietário; `ADMIN` e `TECNICO` mantêm edição e exclusão nos recursos editáveis. O backend não possui role separada `PROPRIETARIO` nem vínculo produtor–fazenda independente; reconhece o vínculo direto `Usuario.proprietario` e o vínculo legado `Proprietario.usuarioId`. O cadastro público de conta permanece na tela de login e cria somente `PRODUTOR`. Fazendas, setores e estações meteorológicas são somente leitura no mobile. O backend verifica o acesso às fazendas nas rotas de safras; outras listagens têm restrições próprias descritas em [INTEGRACAO.md](INTEGRACAO.md).

## Clima em Leituras climáticas

Entre em **Gestão > Clima > Leituras climáticas** para ver o cartão **Clima da fazenda**. Esse módulo exibe somente o cartão e não aparece em **Início**. O cartão mostra a primeira fazenda disponível para a conta. Quando houver várias, escolha no campo **Fazenda**. A seleção permanece em memória entre abas e atualizações e também define os setores do cartão **Plantios em andamento**. O clima solicita as estações vinculadas em `GET /propriedade/{id}/estacoes`.

Fazendas, estações e seus vínculos são cadastrados no aplicativo web da outra equipe. Neste aplicativo, **Gestão → Propriedades** e **Gestão → Estações meteorológicas** permitem apenas consultar os registros. Não há seleção nem edição de estação no cartão.

Se houver várias estações vinculadas, a primeira com coordenadas válidas em ordem crescente de ID fornece a referência automaticamente. Seu nome e suas coordenadas aparecem no cartão. A latitude precisa estar entre -90 e 90 e a longitude entre -180 e 180; o texto de localização da fazenda não é convertido em coordenadas.

A consulta é feita diretamente à [API Open-Meteo](https://open-meteo.com/en/docs), sem chave de API e sem enviar o token do Ghydro. O cartão mostra a hora local atual da fazenda e separadamente o horário da amostra meteorológica; condições atuais podem estar em passos de 15 minutos. **Chance de chuva na próxima hora** usa a probabilidade associada ao próximo horário cheio, que representa a hora anterior segundo a definição do Open-Meteo. Os dados são estimativas meteorológicas, com atribuição ao Open-Meteo (CC BY 4.0).

Use o botão **Atualizar clima** no cartão ou abra o módulo novamente para uma nova consulta. Sem fazenda, estação vinculada ou coordenadas válidas, o cartão orienta solicitar a configuração no aplicativo web responsável. Não usa uma estação de outra fazenda nem localização padrão como alternativa. Em falhas, oferece nova tentativa. As estimativas são exibidas em memória e não são salvas como leituras climáticas nem geram recomendações automáticas.

O cartão de clima mostra apenas informações meteorológicas. Baterias dos sensores continuam disponíveis nas áreas de monitoramento, sem indicador no cartão climático.

## Safras por fazenda

Toque em **Plantios em andamento** no Início ou em **Plantios** na Gestão. A tela consulta todos os setores da fazenda selecionada. Setores sem plantio ativo oferecem **Cadastrar plantação**, com cultura cadastrada no backend, data de plantio e previsão opcional. Setores com plantio ativo mostram a cultura e oferecem **Registrar colheita**, somente com a data. Cada setor tem **Ver histórico produtivo**.

As operações usam `/propriedade/{id}/safras/setores/...` e exigem token; o backend verifica a fazenda, o setor e o plantio. A colheita grava a data em `plantio.data_colheita_real` e conclui o plantio, sem tabela adicional. Não há comando de cadastro ou edição de setor no mobile. Após cada operação, a lista é atualizada. O backend valida o esquema do banco na inicialização e não cria tabelas automaticamente.

## Verificação

```powershell
flutter analyze
flutter test
flutter build web
```

Os testes usam respostas HTTP simuladas apenas para conferir os contratos e a interface. Não existe alternativa simulada durante a execução normal. A validação de banco remoto e dos fluxos completos precisa ser feita com os dois serviços em execução, conforme o roteiro de integração.

O mapa completo da integração e o roteiro de validação estão em [INTEGRACAO.md](INTEGRACAO.md).
