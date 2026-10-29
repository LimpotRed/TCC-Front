# 🌱 GHydro — Aplicativo Mobile Flutter

O **GHydro** é um sistema de gestão e monitoramento agrícola desenvolvido como Trabalho de Conclusão de Curso (TCC) em Engenharia de Software. Seu objetivo é facilitar o acompanhamento de propriedades rurais por meio da tecnologia, permitindo o monitoramento da umidade do solo, das condições climáticas e dos ciclos de produção agrícola.

O projeto utiliza uma arquitetura integrada, composta por:

- **Backend:** desenvolvido em Java com Spring Boot, responsável pelas regras de negócio, autenticação e comunicação com o banco de dados.
- **Banco de dados:** PostgreSQL, utilizado para armazenar informações de usuários, propriedades, setores, sensores, plantios e colheitas.
- **Sistema Web:** responsável pelo gerenciamento e cadastro das informações, como propriedades rurais, setores, usuários e demais registros administrativos.
- **Aplicativo Mobile:** desenvolvido em Flutter e Dart, voltado principalmente à visualização e análise dos dados agrícolas, além do cadastro de plantios e registro de colheitas.

> **Importante:** este repositório contém somente o código-fonte do frontend Flutter. O backend Java, o banco de dados PostgreSQL e o sistema web fazem parte da solução completa, mas são componentes separados.

---

## 📱 Como funciona o aplicativo

O aplicativo mobile foi desenvolvido para oferecer aos produtores rurais uma maneira prática de acompanhar suas propriedades sem depender diretamente do sistema web.

Enquanto o sistema web concentra os cadastros e as operações administrativas, o aplicativo Flutter funciona como uma interface de consulta e acompanhamento das informações coletadas e armazenadas pelo sistema.

No mobile, as principais operações de cadastro são o **registro de novos plantios e a conclusão de colheitas**.

### 🔐 Autenticação

O aplicativo realiza a autenticação dos usuários através da API REST do GHydro, utilizando tokens JWT para identificar o usuário e controlar o acesso às informações.

Cada produtor tem acesso às propriedades e aos dados disponibilizados conforme suas permissões no backend.

### 🚜 Propriedades e setores

O aplicativo apresenta as propriedades vinculadas ao usuário e seus respectivos setores.

Os cadastros e a organização dos setores são realizados pelo sistema web. O aplicativo consulta essas informações diretamente na API e permite visualizar os plantios associados a cada setor.

### 🌾 Plantios e colheitas

Essa é a principal funcionalidade operacional do aplicativo mobile.

O produtor pode:

- Consultar os plantios em andamento.
- Visualizar os setores disponíveis para cultivo.
- Cadastrar um novo plantio em um setor disponível.
- Registrar a conclusão de uma colheita.
- Consultar o histórico produtivo dos setores.

Cada setor permite apenas um plantio não concluído por vez, conforme a validação implementada no aplicativo.

Ao cadastrar um plantio, seu status é definido como `EM_ANDAMENTO`. Quando a colheita é registrada, o status passa para `CONCLUIDO`, liberando o setor para um novo ciclo produtivo.

### 💧 Monitoramento da umidade do solo

O GHydro utiliza sensores IoT para coletar informações sobre a umidade do solo.

Esses dados são enviados ao backend e armazenados no PostgreSQL, ficando disponíveis para consulta no aplicativo.

O mobile atua como uma interface de visualização, permitindo ao produtor acompanhar as informações registradas pelos sensores.

### 🌤️ Monitoramento climático

O aplicativo disponibiliza informações meteorológicas das propriedades por meio da integração com a API Open-Meteo.

As consultas utilizam as coordenadas das estações meteorológicas cadastradas no sistema, permitindo visualizar dados climáticos relacionados à propriedade.

### 🛠️ Consulta de manutenções

O produtor também pode consultar registros e históricos de manutenção dos equipamentos.

Essa funcionalidade é destinada exclusivamente à visualização das informações. Os cadastros e as alterações administrativas são realizados fora do aplicativo mobile.

---

## 🛠️ Tecnologias utilizadas

| Tecnologia | Aplicação |
|---|---|
| Flutter | Desenvolvimento do aplicativo mobile |
| Dart | Linguagem de programação do frontend |
| REST API | Comunicação entre aplicativo e backend |
| JWT | Autenticação e autorização |
| Open-Meteo | Consulta de informações meteorológicas |

### Tecnologias da solução completa

Além do Flutter, o ecossistema GHydro utiliza **Java, Spring Boot, PostgreSQL e um sistema web administrativo**.

Esses componentes são responsáveis pelo processamento, armazenamento e gerenciamento dos dados consumidos pelo aplicativo.

## 🏗️ Arquitetura geral

```text
                SENSORES IoT
                     |
                     v
             BACKEND JAVA
              SPRING BOOT
                     |
                     v
               POSTGRESQL
                     ^
                     |
                 API REST
                     |
           +---------+---------+
           |                   |
           v                   v
      SISTEMA WEB       APLICATIVO FLUTTER
       Cadastros         Consulta de dados
     e gerenciamento     Cadastro de plantios
                        Registro de colheitas
```

O sistema web e o aplicativo mobile são interfaces distintas que se comunicam com o mesmo backend, respeitando as regras de acesso e as responsabilidades de cada plataforma.

---

## ▶️ Como executar

### Pré-requisitos

- Flutter SDK instalado.
- Backend GHydro configurado.
- PostgreSQL disponível e conectado ao backend.

Para iniciar o ambiente configurado no Windows:

```powershell
.\start-all.cmd
```

O comando inicia o backend na porta `8081` e o Flutter Web em:

`http://localhost:4200`

Para executar somente o frontend, com a API já disponível:

```powershell
.\start-front.cmd
```

Para utilizar o backend local no emulador Android:

```text
http://10.0.2.2:8081
```

### Verificações do frontend

```bash
flutter analyze
flutter test
flutter build web
```

---

## 🎓 Contexto do projeto

O GHydro é um projeto acadêmico desenvolvido durante a graduação em Engenharia de Software, integrando desenvolvimento mobile, sistemas web, APIs REST, banco de dados e Internet das Coisas.

Este repositório representa especificamente a **camada frontend mobile**, desenvolvida para facilitar a consulta e a análise das informações agrícolas, além de permitir o registro de plantios e colheitas diretamente pelo produtor.

**Desenvolvedor:** Lucas Lopes Bastos

**GitHub:** https://github.com/LimpotRed

---

*GHydro — Tecnologia aplicada ao monitoramento e à gestão agrícola.*
