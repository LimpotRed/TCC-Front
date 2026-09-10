# Ghydro

Aplicativo do nosso TCC para acompanhar pivôs de irrigação e a economia de água. As telas foram feitas em Flutter, usando Dart.

## Como abrir o projeto

1. Instale o Flutter e abra esta pasta no VS Code.
2. No terminal da pasta, rode `flutter pub get` para baixar as dependências.
3. Inicie o app com o comando abaixo:

```powershell
flutter run -d web-server --web-hostname localhost --web-port 8080
```

Abra http://localhost:8080 no navegador e deixe o terminal aberto.

No computador do Lucas, se o comando `flutter` não for encontrado, use:

```powershell
& 'C:\flutter\bin\flutter.bat' run -d web-server --web-hostname localhost --web-port 8080
```

O projeto usa Dart 3.13.2 ou mais recente dentro da versão 3. O Flutter já inclui o Dart.

## Como usar

Ao abrir, a logo aparece por 2 segundos. Depois vem o login. Quem ainda não tem conta pode clicar em “Crie agora”, preencher os dados e voltar para entrar.

Após entrar, o painel mostra o nome cadastrado, a economia mensal e os pivôs. Toque em um pivô para ver seus detalhes. O menu inferior abre início, pivôs, perfil e relatórios. Para sair, use o perfil ou o menu no canto superior.

## Onde mexer

| Arquivo | O que ele faz |
| --- | --- |
| `lib/main.dart` | Inicia o app e mostra a splash por 2 segundos. |
| `lib/brand.dart` | Guarda a logo e as cores da splash e do login. |
| `lib/login_screen.dart` | Monta os campos e botões de login e cadastro. |
| `lib/auth_validation.dart` | Confere nome, e-mail e tamanho da senha. |
| `lib/auth_service.dart` | Salva as contas e confere a senha ao entrar. |
| `lib/dashboard_screen.dart` | Monta o painel, os cartões, o gráfico e a navegação. |
| `assets/images/image.png` | Logo usada no app. |
| `web/ghydro-logo.png` | Ícone da aba do navegador. |
| `pubspec.yaml` | Lista as dependências e as imagens usadas. |

Dentro do painel, `_pivots` guarda os dados dos pivôs. `_economy` mostra o valor da economia. `_reports` monta as barras e `_EconomyRing` desenha o anel colorido.

## Como os dados funcionam hoje

O cadastro e o login funcionam com contas salvas no próprio navegador. Cada integrante precisa criar sua conta no computador que usar. Mantenha o mesmo endereço e perfil do navegador; limpar os dados do site apaga as contas.

A senha original não é gravada. O app salva um hash, que é um valor calculado a partir da senha, e faz a mesma conta para conferir o login. Isso não substitui a proteção de um servidor.

Os números de economia, os status dos pivôs e as barras dos relatórios estão definidos no código. Eles ainda não vêm de sensores ou equipamentos. A próxima etapa é conectar essas informações e colocar as contas em um servidor, caso o grupo queira acessá-las em vários aparelhos. A recuperação de senha ainda não está disponível.

## Como compartilhar com o grupo

Envie as pastas `lib`, `assets`, `web`, `android` e `ios`, junto com `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.metadata`, `.gitignore` e este README. As pastas `build` e `.dart_tool` são geradas pelo Flutter e não precisam ser enviadas.

Depois de mudar o código, salve o arquivo e pressione `r` no terminal. Use `R` para reiniciar o app e `q` para encerrar.
