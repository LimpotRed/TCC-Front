# Integração Ghydro

O frontend Flutter usa o backend em `C:\Users\Aluno\Desktop\TCC BACK\GHydro-BackEnd` e não altera seus arquivos. O backend configura a conexão PostgreSQL no próprio `application.properties`. O launcher do frontend usa uma cópia temporária e aplica `spring.jpa.hibernate.ddl-auto=none` ao processo para não atualizar o esquema. A rotina agendada do backend pode atualizar estados de sensores no banco real.

## Endereços locais

| Serviço | Endereço |
| --- | --- |
| Frontend web | `http://localhost:4200` |
| API | `http://localhost:8081` |
| Clima | Open-Meteo, consultado diretamente pelo frontend |

Execute `start-all.cmd` na pasta do frontend. `start-front.cmd` inicia somente o frontend com uma API já ativa. Para alterar o endereço da API, use `-ApiBaseUrl`.

## Contratos usados

- Autenticação: `POST /auth/login` com e-mail e senha; o JWT contém os dados básicos do perfil. `POST /auth/register` cria conta pública com perfil PRODUTOR.
- Os recursos de Gestão são consultados pelas rotas listadas em `lib/resource_schema.dart`. As telas permitem busca e detalhes; o cadastro de plantio e registro de colheita são as exceções de escrita para perfis autorizados.
- `GET /setor/propriedade/{id}` fornece os setores e plantios aninhados para o painel e o histórico.
- Para cadastrar plantio, `ADMIN`, `TECNICO` e `PRODUTOR` enviam `POST /plantio` com setor, cultura, data de plantio, situação fixa `EM_ANDAMENTO` e previsão opcional de colheita posterior ao plantio. As culturas disponíveis vêm de `GET /cultura`. O frontend bloqueia setor com plantio não concluído e consulta os setores novamente antes de enviar; `PLANEJADO` também bloqueia. A API atual não garante essa unicidade contra acessos simultâneos ou outros clientes.
- Para registrar colheita, `ADMIN`, `TECNICO` e `PRODUTOR` enviam `PUT /plantio/{id}` com setor, cultura, data de plantio e previsão existentes, mais data real e status `CONCLUIDO`. O backend verifica o acesso do produtor à propriedade. Essa rota permite também alterações gerais via API, embora o aplicativo não ofereça essa edição.
- `GET /estacaoMetereologica/propriedade/{id}` fornece a estação da fazenda. Com coordenadas válidas, o frontend consulta o Open-Meteo sem enviar JWT ou gravar as estimativas.
- O histórico de manutenção usa `GET /manutencao/equipamento/{tipo}/{id}` para perfis autorizados.
- A foto de perfil é armazenada apenas no dispositivo para a conta selecionada e não é enviada ao backend.

Os testes automatizados usam respostas simuladas; valide o fluxo com uma conta apropriada e dados reais quando o banco estiver acessível. Evite criar dados reais apenas para testes sem autorização específica.
