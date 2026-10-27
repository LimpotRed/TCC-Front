# Ghydro — frontend Flutter

Aplicativo Flutter conectado à versão do backend em `C:\Users\Aluno\Desktop\TCC BACK\GHydro-BackEnd`. O backend e sua configuração devem permanecer intactos. A conexão PostgreSQL e o segredo JWT estão no `application.properties` do backend; não copie esses valores para o frontend nem os compartilhe.

## Executar no Windows

No PowerShell, a partir da pasta do frontend:

```powershell
.\start-all.cmd
```

O comando inicia a API na porta 8081 e o Flutter web em [http://localhost:4200](http://localhost:4200), origem permitida pelo CORS desta versão. O helper compila uma cópia temporária do backend e usa `spring.jpa.hibernate.ddl-auto=none` durante a execução para não atualizar o esquema do banco. O backend possui uma rotina automática que pode atualizar o status de sensores no banco real. A conexão depende de acesso à rede e disponibilidade do PostgreSQL.

Para iniciar apenas o frontend, com a API já disponível: `.\start-front.cmd`. Para usar outro endereço, informe `-ApiBaseUrl` ao script. No emulador Android, use `http://10.0.2.2:8081`.

## Contrato atual

- Login: `POST /auth/login`. O token contém e-mail, nome de exibição e perfil. A API não possui `GET /auth/me`.
- Cadastro: `POST /auth/register` com e-mail, senha e perfil `PRODUTOR`. Esta versão do backend cria o proprietário com nome provisório; o nome não é solicitado no formulário.
- Fazendas: `GET /propriedade`. Setores e plantios: `GET /setor/propriedade/{id}`, que retorna os plantios dentro de cada setor. Administradores, técnicos e produtores podem cadastrar plantios com `POST /plantio` e registrar colheitas, atualizando o plantio com `dataColheitaReal` e `statusPlantio: CONCLUIDO`. O produtor acessa suas propriedades conforme as permissões do backend. As demais telas de dados são somente de consulta no aplicativo.
- No aplicativo, cada setor admite uma safra não concluída de cada vez. O cadastro é sempre `EM_ANDAMENTO`; a colheita passa a `CONCLUIDO` e libera novo cadastro. Plantios antigos planejados também ocupam o setor. O frontend confere os dados antes de cadastrar, mas somente o backend poderia garantir unicidade contra requisições simultâneas ou de outros clientes.
- Clima: **Gestão > Clima > Leituras climáticas** consulta `GET /estacaoMetereologica/propriedade/{id}`. O backend retorna uma estação ou vazio. Quando ela tem coordenadas válidas, o aplicativo consulta o Open-Meteo diretamente, sem enviar o token do Ghydro.
- Manutenções: `/manutencao`. As listagens e o histórico permanecem disponíveis para consulta, sem edição ou exclusão pelo aplicativo.
- Foto de perfil: em **Perfil**, escolha, altere ou remova uma foto. Ela é salva localmente para a conta neste navegador/dispositivo, não no backend; outro dispositivo não a recebe. Após a seleção, o arquivo deve ter até 512 KB.

`flutter analyze`, `flutter test` e `flutter build web` verificam o frontend. Testes simulados não substituem uma validação com uma conta real e o banco disponível.
