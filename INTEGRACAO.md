# Integração Ghydro

## Estado atual

O frontend em `tcc-front` usa exclusivamente a API Spring Boot de `TCC-BACKAND`. Nenhum código foi enviado ao GitHub; todas as alterações permanecem neste computador.

| Componente | Endereço local | Persistência |
| --- | --- | --- |
| Flutter Web | `http://localhost:8080` | Não persiste dados de negócio localmente |
| API Spring Boot | `http://localhost:8081` | PostgreSQL remoto |
| Banco | Configurado em `.env.ps1` no backend | PostgreSQL remoto conectado |

O arquivo `.env.ps1` é local e ignorado pelo Git. Ele contém a conexão e o segredo JWT já existentes no projeto, sem expor esses valores nos arquivos versionados.

## Cobertura das telas

| Área | Rota da API | Operações na interface |
| --- | --- | --- |
| Proprietários | `/proprietario` | listar, pesquisar, detalhar, criar, editar e excluir |
| Propriedades | `/propriedade` | listar, pesquisar, detalhar, criar, editar e excluir |
| Tipos de solo | `/tipoSolo` | listar, pesquisar, detalhar, criar, editar e excluir |
| Setores | `/setor` | listar, pesquisar, detalhar, criar, editar e excluir |
| Culturas | `/cultura` | listar, pesquisar, detalhar, criar, editar e excluir |
| Estados fenológicos | `/estadoFenologico` | listar, pesquisar, detalhar, criar, editar e excluir |
| Plantios | `/plantio` | listar, pesquisar, detalhar, criar, editar e excluir |
| Dispositivos de irrigação | `/dispositivoIrrigacao` | listar, filtrar, detalhar, criar, editar e excluir |
| Sensores | `/sensor` | listar, filtrar, detalhar, criar, editar e excluir |
| Leituras de sensor | `/leituraSensor` | listar, pesquisar, detalhar, criar, editar e excluir |
| Estações meteorológicas | `/estacaoMetereologica` | listar, pesquisar, detalhar, criar, editar e excluir |
| Leituras climáticas | `/leituraClimatica` | listar, pesquisar, detalhar, criar, editar e excluir |
| Recomendações | `/recomendacao` | listar, filtrar, detalhar, criar, editar e excluir |
| Execuções de manejo | `/execucaoManejo` | listar, filtrar, detalhar, criar, editar e excluir |
| Configurações de custo | `/configuracaoCusto` | listar, pesquisar, detalhar, criar, editar e excluir |
| Manutenções | `/admin/manutencao` | listar, filtrar e consultar histórico; escrita administrativa |

O perfil usa `GET /auth/me` e `PUT /auth/me`. Cadastro e login usam `/auth/register` e `/auth/login`.

## Ajustes feitos no backend

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

O repositório não contém integração com o equipamento físico do pivô, rotina de coleta automática dos sensores, consulta automática a uma API climática nem um algoritmo que gere recomendações. Também não existe recuperação de senha por e-mail ou uma referência histórica para calcular economia financeira.

Por isso, o painel mostra a proporção real de sensores ativos e os relatórios somam as execuções registradas. A interface informa quando a unidade ou a referência financeira não foi definida, sem inventar valores.

## Validação com o banco ativo

Após o retorno do PostgreSQL, foram confirmados:

- conexão TCP com o servidor;
- pool Hikari conectado ao PostgreSQL 17.11;
- inicialização do Hibernate e dos 17 repositórios JPA;
- teste completo de contexto usando o banco real;
- consulta real de autenticação, com credenciais inexistentes recusadas em 401;
- API protegida em 401 sem token e CORS liberado para o frontend local.

Para validar os fluxos com os dados definitivos da equipe:

1. Cadastrar um produtor, entrar, consultar e editar o perfil.
2. Entrar com um técnico ou administrador e criar uma cadeia completa: proprietário, propriedade, setor, plantio, dispositivo, sensor, leituras, recomendação e execução.
3. Confirmar os relacionamentos de estações meteorológicas com propriedades.
4. Entrar como dois produtores diferentes e verificar que cada um enxerga somente os próprios recursos.
5. Conferir as restrições de exclusão do banco e as mensagens exibidas pela interface.
6. Reiniciar backend e navegador para confirmar a persistência remota.

Os testes automatizados cobrem contratos, autorização e comportamento visual com HTTP simulado. Eles não substituem essa validação final no PostgreSQL real.
