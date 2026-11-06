# 🌱 GHydro — Aplicativo Mobile Flutter

O GHydro é um sistema de gestão e monitoramento agrícola desenvolvido como Trabalho de Conclusão de Curso em Engenharia de Software. O aplicativo Flutter ajuda o produtor a acompanhar propriedades, setores, sensores, clima, plantios e irrigações.

A solução reúne um backend Java com Spring Boot e PostgreSQL, um sistema web administrativo e este aplicativo mobile. Este repositório contém o frontend Flutter. O script de execução procura o backend na pasta irmã `TCC-BACKAND` ou em `Tcc-Back\GHydro-BackEnd` na Área de Trabalho do usuário.

O backend atualmente selecionado está em `../../Tcc-Back/GHydro-BackEnd`. Essa cópia não oferece `GET` ou `PUT /auth/me`. O login valida o token em `/dominios/moedas`; a foto de perfil é apenas de sessão. O cartão climático consulta a estação vinculada em `GET /estacaoMetereologica/propriedade/{id}`. A tela de safras usa as rotas de setor e plantio disponíveis nessa cópia. Veja o aviso no início de [INTEGRACAO.md](INTEGRACAO.md).

**Banco:** a cópia atual do backend usa `ddl-auto=update` e pode criar ou alterar tabelas no PostgreSQL remoto. Não inicie essa cópia nem seus testes de contexto até que o responsável resolva a configuração. O arquivo versionado também contém credenciais e segredo JWT; trate-os como potencialmente expostos.

As contas e os dados do sistema são persistidos pelo backend no PostgreSQL remoto. O aplicativo não usa banco local, `localStorage` ou dados demonstrativos como alternativa. O token de acesso fica somente na memória; ao recarregar a página, é necessário entrar novamente.

## Executar no Windows

Com uma API que já esteja rodando em ambiente seguro, inicie o frontend na pasta deste projeto:

```powershell
.\start-front.cmd
```

O Flutter abre em [http://localhost:4200](http://localhost:4200) e usa a API `http://localhost:8081` por padrão. O CORS global do backend atual permite a origem `localhost:4200`. Para outra porta, use `-WebPort` e confirme que a API a permite.

O script conjunto inicia backend e frontend; use-o somente depois de confirmar que o backend selecionado está configurado de maneira segura:

```powershell
.\start-all.cmd -BackendPath 'C:\caminho\de\uma-api-segura'
```

O backend precisa ter `mvnw.cmd`. O helper `start-backend.ps1` compila uma cópia temporária e usa `spring.jpa.hibernate.ddl-auto=none`, preservando a pasta original. Ele usa JDK 21 ou mais recente, localizado por `JAVA_HOME`, `PATH`, instalações Java ou extensão Red Hat Java do VS Code. A seleção altera o ambiente somente do processo do backend.

O frontend procura Flutter no `PATH`, em `C:\flutter\bin\flutter.bat` e, como alternativa, em `C:\Users\Aluno\develop\flutter\bin\flutter.bat`.

O frontend usa `http://localhost:8081` como API por padrão. Para apontar para uma API hospedada:

```powershell
.\start-front.cmd -ApiBaseUrl 'https://api.exemplo.com'
```

`start-all.cmd` também aceita `-ApiBaseUrl` e `-WebPort`. A URL da API pode ser passada ao Flutter com `--dart-define=API_BASE_URL=...`. No emulador Android, use `http://10.0.2.2:8081` para acessar o backend do computador. Em produção, publique frontend e API com HTTPS.

## Funcionalidades da interface

- Login sem cadastro de contas no aplicativo; a edição do perfil depende de `PUT /auth/me`, ausente no backend atual.
- Visão geral com seleção de fazenda, atualização a cada 60 segundos, setores, plantios e sensores. O controle de irrigação fica na Gestão.
- Cartão de clima em **Gestão > Clima > Leituras climáticas** usa a estação vinculada; a tela de safras consulta setores e plantios da fazenda.
- Consulta de fazendas, setores e estações cadastrados no aplicativo web da outra equipe, sem comandos de escrita para esses recursos.
- Consulta, edição e exclusão dos demais módulos conforme as permissões; a criação após o login existe nos fluxos específicos de irrigação e de safras.
- Pesquisa, filtros de situação, paginação visual, detalhes e confirmação antes de excluir.
- Seletores de relacionamentos, datas, horários e enumerações nos formulários disponíveis.
- Histórico administrativo de manutenções.
- Relatórios por fazenda com duração e estimativas de água e energia dos registros de irrigação.

O formulário público envia o perfil `PRODUTOR`; o backend atual aceita o perfil enviado diretamente e precisa de correção de autorização pelo responsável. O token informa nome, e-mail e perfil para exibição, mas a API decide as permissões. Algumas listagens não estão isoladas por produtor no backend; os filtros do Flutter não substituem essa proteção. Fazendas, setores e estações são somente leitura no mobile.

## Registrar irrigação

Em **Gestão > Monitoramento > Controle de irrigação**, selecione a fazenda e toque em **Registrar irrigação**. Escolha um setor: a tela identifica o único dispositivo ativo. Informe a duração, considerada encerrada agora, ou as datas e horários de início e fim. Sem dispositivo ativo único, o registro fica bloqueado. O serviço exige vazão e potência positivas no dispositivo e tarifas válidas na fazenda.

O formulário pode mostrar uma prévia de água, energia e custo após confirmação das unidades pelo responsável. Ao salvar, envia setor, início e duração em minutos a `/registroIrrigacao`; o servidor identifica o dispositivo, calcula e salva as estimativas e tarifas, mesmo sem marcar a caixa da prévia. Os valores são estimados, não medições.

Na aba **Relatórios**, os gráficos usam `/registroIrrigacao/propriedade/{id}` para somar duração e estimativas de água e energia da fazenda. O histórico anterior de execuções de manejo continua disponível no módulo de manejo e não é misturado automaticamente aos novos registros.

## Clima em Leituras climáticas

Entre em **Gest?o > Clima > Leituras clim?ticas** para abrir o cart?o **Clima da fazenda**. Ele solicita a esta??o vinculada em `GET /estacaoMetereologica/propriedade/{id}` e consulta o Open-Meteo diretamente. O cart?o usa nome e coordenadas e n?o apresenta a chave da esta??o.

Fazendas, estações e seus vínculos são cadastrados no aplicativo web da outra equipe. Neste aplicativo, **Gestão → Propriedades** e **Gestão → Estações meteorológicas** permitem apenas consultar os registros. Não há seleção nem edição de estação no cartão.

Se houver várias estações vinculadas, a primeira com coordenadas válidas em ordem crescente de ID fornece a referência automaticamente. Seu nome e suas coordenadas aparecem no cartão. A latitude precisa estar entre -90 e 90 e a longitude entre -180 e 180; o texto de localização da fazenda não é convertido em coordenadas.

A consulta é feita diretamente à [API Open-Meteo](https://open-meteo.com/en/docs), sem chave de API e sem enviar o token do Ghydro. O cartão mostra a hora local atual da fazenda e separadamente o horário da amostra meteorológica; condições atuais podem estar em passos de 15 minutos. **Chance de chuva na próxima hora** usa a probabilidade associada ao próximo horário cheio, que representa a hora anterior segundo a definição do Open-Meteo. Os dados são estimativas meteorológicas, com atribuição ao Open-Meteo (CC BY 4.0).

Use o botão **Atualizar clima** no cartão ou abra o módulo novamente para uma nova consulta. Sem fazenda, estação vinculada ou coordenadas válidas, o cartão orienta solicitar a configuração no aplicativo web responsável. Não usa uma estação de outra fazenda nem localização padrão como alternativa. Em falhas, oferece nova tentativa. As estimativas são exibidas em memória e não são salvas como leituras climáticas nem geram recomendações automáticas.

O cartão de clima mostra apenas informações meteorológicas. Baterias dos sensores continuam disponíveis nas áreas de monitoramento, sem indicador no cartão climático.

## Safras por fazenda

Toque em **Plantios em andamento** no Início ou em **Plantios** na Gestão. A tela consulta os setores e seus plantios, mostra o histórico e oferece registro de plantio e colheita para os perfis permitidos.

A colheita solicita somente a data ao usuário e envia ao backend os dados necessários para concluir o plantio. Não existem campos de quantidade produzida ou unidade de medida. A criação de um novo plantio exige setor sem plantio não concluído.

## Verificação

```powershell
flutter analyze
flutter test
flutter build web
```

Os testes usam respostas HTTP simuladas apenas para conferir os contratos e a interface. Não existe alternativa simulada durante a execução normal. A validação integrada depende de ambiente seguro e das rotas necessárias.

O mapa completo da integração e o roteiro de validação estão em [INTEGRACAO.md](INTEGRACAO.md).

## Tecnologias e contexto

O aplicativo usa Flutter e Dart, uma API REST com autenticação JWT e a API Open-Meteo para consultas climáticas. A solução completa integra Spring Boot, PostgreSQL, sensores e um sistema web administrativo.

O GHydro é um projeto acadêmico que integra desenvolvimento mobile, sistemas web, APIs e Internet das Coisas.

**Desenvolvedor:** Lucas Lopes Bastos

**GitHub:** [LimpotRed](https://github.com/LimpotRed)
