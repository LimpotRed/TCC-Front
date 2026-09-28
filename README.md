# Ghydro — frontend

Aplicativo Flutter conectado ao backend Spring Boot que fica na pasta irmã `TCC-BACKAND`.

As contas e os dados do sistema são persistidos pelo backend no PostgreSQL remoto. O aplicativo não usa banco local, `localStorage` ou dados demonstrativos como alternativa. O token de acesso fica somente na memória; ao recarregar a página, é necessário entrar novamente.

## Executar no Windows

Para iniciar o backend e o frontend juntos, execute na pasta deste projeto:

```powershell
.\start-all.cmd
```

Esse comando abre o backend em uma janela separada e inicia o Flutter em `http://localhost:8080`, usando a API em `http://localhost:8081`.

Para apontar para outra API:

```powershell
.\start-all.cmd -ApiBaseUrl 'https://api.exemplo.com'
```

Também é possível iniciar os serviços separadamente:

1. Inicie o backend:

```powershell
cd C:\Users\Aluno\Desktop\TCC-BACKAND
.\start-backend.cmd
```

2. Em outro terminal, inicie o frontend:

```powershell
cd C:\Users\Aluno\Desktop\tcc-front
.\start-front.cmd
```

3. Abra [http://localhost:8080](http://localhost:8080).

O frontend usa `http://localhost:8081` como API por padrão. Para apontar para uma API hospedada:

```powershell
.\start-front.cmd -ApiBaseUrl 'https://api.exemplo.com'
```

O mesmo valor pode ser passado diretamente ao Flutter com `--dart-define=API_BASE_URL=...`. No emulador Android, use `http://10.0.2.2:8081` para acessar o backend do computador. Em produção, publique frontend e API com HTTPS e configure a origem do frontend em `CORS_ORIGINS` no backend.

## Funcionalidades conectadas

- Cadastro, login, consulta e edição do perfil pela API.
- Painel com propriedades, dispositivos, sensores e execuções reais.
- Cadastro, consulta, edição e exclusão dos módulos disponíveis no backend.
- Pesquisa, filtros de situação, paginação visual, detalhes e confirmação antes de excluir.
- Seletores de relacionamentos, datas, horários, enumerações e múltiplas estações.
- Histórico administrativo de manutenções.
- Relatórios calculados a partir das execuções de manejo retornadas pela API.

Usuários `PRODUTOR` visualizam seus próprios dados e não recebem comandos de alteração. Operações de escrita exigem `ADMIN` ou `TECNICO`. O cadastro público sempre cria um usuário `PRODUTOR`.

## Verificação

```powershell
flutter analyze
flutter test
flutter build web
```

Os testes usam respostas HTTP simuladas apenas para conferir os contratos e a interface. Não existe alternativa simulada durante a execução normal. A conexão, o contexto JPA e a consulta de autenticação também foram validados no PostgreSQL remoto.

O mapa completo da integração e o roteiro de validação estão em [INTEGRACAO.md](INTEGRACAO.md).
