# 🌱 GHydro — Sistema Inteligente de Gestão Agrícola

### Monitoramento de umidade do solo, gerenciamento de propriedades rurais e acompanhamento de plantios.

O **GHydro** é uma solução tecnológica desenvolvida como Trabalho de Conclusão de Curso (TCC) em Engenharia de Software, com o objetivo de modernizar a gestão agrícola por meio da integração entre **Internet das Coisas (IoT), desenvolvimento mobile, APIs REST e banco de dados relacional**.

O sistema foi idealizado para auxiliar produtores rurais no acompanhamento de suas propriedades, oferecendo acesso a informações sobre umidade do solo, condições climáticas, setores de cultivo, plantios e histórico produtivo.

A proposta é transformar dados coletados no campo em informações acessíveis, contribuindo para uma gestão mais organizada e para decisões agrícolas baseadas em dados.

---

## 🎯 Objetivo do projeto

A agricultura depende de fatores como umidade do solo, condições climáticas e acompanhamento adequado dos ciclos de cultivo.

O GHydro busca facilitar esse processo por meio de uma plataforma que centraliza as informações da propriedade rural e permite ao produtor acompanhar seus dados de maneira prática.

Entre os principais objetivos estão:

- Facilitar o monitoramento das condições do solo por meio de sensores IoT.
- Centralizar informações sobre propriedades, setores e plantios.
- Permitir o acompanhamento do ciclo produtivo, desde o cadastro do plantio até a colheita.
- Disponibilizar informações meteorológicas para auxiliar o planejamento agrícola.
- Organizar o histórico produtivo das propriedades.
- Garantir que cada usuário acesse os dados de acordo com suas permissões.

## 📱 Funcionalidades do aplicativo

### 🔐 Autenticação e controle de acesso

O aplicativo possui integração com uma API de autenticação baseada em JWT (JSON Web Token).

O sistema permite o login de usuários, cadastro de produtores e acesso às funcionalidades conforme os perfis e permissões estabelecidos pelo backend.

### 🚜 Gerenciamento de propriedades rurais

Os usuários podem consultar as propriedades vinculadas à sua conta, visualizar os setores cadastrados e acompanhar os plantios associados a cada área.

O aplicativo consome as informações fornecidas pela API, mantendo a integração entre os dados disponíveis no ambiente web e no dispositivo mobile.

### 🌾 Controle de plantios e colheitas

O GHydro permite acompanhar o ciclo de produção agrícola, incluindo:

- Visualização dos setores de cultivo.
- Consulta aos plantios ativos.
- Cadastro de novos plantios em setores disponíveis.
- Registro de colheitas.
- Atualização do status dos plantios.
- Consulta ao histórico produtivo.

O aplicativo também implementa validações para evitar o cadastro de múltiplos plantios ativos no mesmo setor.

### 💧 Monitoramento da umidade do solo

Uma das principais propostas do GHydro é integrar sensores IoT ao sistema para acompanhar a umidade do solo.

Os sensores realizam leituras periódicas e enviam os registros para armazenamento no banco de dados, permitindo que as informações sejam utilizadas no acompanhamento das condições das áreas monitoradas.

Essa integração representa a conexão entre hardware, comunicação de dados, backend e interfaces de visualização.

### 🌤️ Informações climáticas

O sistema disponibiliza a consulta de dados meteorológicos vinculados às propriedades rurais.

A integração com a API Open-Meteo permite obter informações climáticas a partir das coordenadas da estação meteorológica cadastrada, complementando os dados agrícolas disponíveis no aplicativo.

### 🛠️ Consulta de manutenções

O aplicativo também disponibiliza acesso a registros e históricos de manutenção, contribuindo para o acompanhamento dos equipamentos e das atividades relacionadas à infraestrutura monitorada.

### 👤 Personalização de perfil

Os usuários podem selecionar, atualizar ou remover uma foto de perfil, armazenada localmente no dispositivo ou navegador utilizado.

---

## 🧰 Tecnologias utilizadas

| Tecnologia | Aplicação |
|---|---|
| Flutter | Desenvolvimento da interface multiplataforma |
| Dart | Linguagem de programação do aplicativo |
| Java | Desenvolvimento do backend |
| Spring Boot | Construção e disponibilização da API REST |
| PostgreSQL | Persistência e gerenciamento dos dados |
| JWT | Autenticação e controle de acesso |
| REST API | Comunicação entre frontend e backend |
| Open-Meteo | Integração com informações meteorológicas |
| IoT | Coleta de dados por sensores de umidade |
| Git e GitHub | Versionamento e gerenciamento do código-fonte |

## 🏗️ Arquitetura da solução

O GHydro utiliza uma arquitetura baseada na separação entre frontend, backend e persistência de dados.

**Fluxo simplificado da aplicação:**

```text
       Sensores IoT
            |
            v
     Coleta de dados
            |
            v
    Backend Spring Boot
            |
            v
     Banco PostgreSQL
            ^
            |
       API REST
            |
            v
   Aplicativo Flutter
            |
            v
      Usuário final

 Integração complementar:
 Flutter <--> Open-Meteo
```

O aplicativo Flutter é responsável pela interação com o usuário, apresentação das informações e execução das operações permitidas pela API.

O backend, desenvolvido com Java e Spring Boot, centraliza as regras de negócio, os mecanismos de autenticação e a comunicação com o banco PostgreSQL.

A separação dessas responsabilidades facilita a manutenção do sistema e sua evolução.

## 🔄 Regras de negócio implementadas

O projeto contempla regras importantes para manter a consistência das operações agrícolas:

**Isolamento de dados:** produtores acessam suas propriedades conforme as permissões definidas pelo backend.

**Controle de plantios:** cada setor admite um plantio não concluído por vez, de acordo com as validações implementadas no aplicativo.

**Ciclo produtivo:** novos plantios são cadastrados com status `EM_ANDAMENTO`. Ao registrar a colheita, o plantio passa para `CONCLUIDO`, permitindo iniciar outro ciclo no setor.

**Integração de dados:** setores cadastrados no sistema web são recuperados pelo aplicativo por meio da API.

**Segurança:** as operações autenticadas utilizam JWT, respeitando as permissões fornecidas pelo backend.

> A validação de ocupação dos setores é realizada pelo frontend. A garantia de unicidade em cenários de concorrência depende de validações adicionais no backend.

---

## 💻 Execução do projeto

### Pré-requisitos

- Flutter SDK instalado e configurado.
- Java e ambiente compatível com o backend Spring Boot.
- PostgreSQL acessível e configurado.
- Navegador compatível ou ambiente de emulação Android.
- Acesso à API do projeto.

### Inicialização no Windows

Na pasta do frontend, execute:

```powershell
.\start-all.cmd
```

O script inicia o backend e a aplicação Flutter Web nos endereços utilizados pelo ambiente de desenvolvimento:

**Backend:**
`http://localhost:8081`

**Frontend:**
`http://localhost:4200`

Para iniciar somente o frontend, com a API já disponível:

```powershell
.\start-front.cmd
```

No emulador Android, o endereço de acesso ao backend local é:

```text
http://10.0.2.2:8081
```

A execução completa depende da disponibilidade do backend e de um banco de dados previamente configurado.

### Validação do frontend

Para analisar o código:

```bash
flutter analyze
```

Para executar os testes automatizados:

```bash
flutter test
```

Para gerar a versão web:

```bash
flutter build web
```

---

## 🚀 Desafios técnicos e aprendizados

O desenvolvimento do GHydro envolve diferentes áreas da Engenharia de Software, proporcionando experiências práticas com:

- Integração entre aplicativos Flutter e serviços REST.
- Desenvolvimento e consumo de APIs com autenticação JWT.
- Modelagem de dados e relacionamento entre propriedades, setores e plantios.
- Implementação de regras de negócio relacionadas ao ciclo agrícola.
- Controle de acesso e isolamento de informações por usuário.
- Integração com serviços meteorológicos externos.
- Comunicação entre dispositivos IoT, sistemas de backend e banco de dados.
- Tratamento de dados e estados da interface.
- Organização, manutenção e versionamento de um projeto de software.

Além da implementação técnica, o projeto envolve a análise de problemas reais do setor agrícola e a construção de uma solução que conecta diferentes tecnologias.

## 🔮 Possibilidades de evolução

A arquitetura do GHydro permite explorar novas funcionalidades, como:

- Dashboards analíticos para acompanhamento da produção.
- Alertas automáticos baseados nas leituras dos sensores.
- Análises históricas de umidade e condições ambientais.
- Recomendações de irrigação baseadas em dados.
- Ampliação dos testes automatizados e das validações no backend.
- Melhorias na visualização de informações produtivas.

Esses recursos representam possibilidades de desenvolvimento futuro e não necessariamente funcionalidades disponíveis na versão atual.

---

## 🎓 Contexto acadêmico

O GHydro foi desenvolvido como **Trabalho de Conclusão de Curso (TCC) da graduação em Engenharia de Software**, com foco na aplicação prática de conhecimentos adquiridos durante a formação.

O projeto reúne conceitos de desenvolvimento mobile, arquitetura de software, banco de dados, segurança, integração de sistemas e Internet das Coisas.

Mais do que uma aplicação acadêmica, o GHydro representa uma experiência de construção de software voltada à resolução de problemas reais.

## 👨‍💻 Desenvolvedor

**Lucas Lopes Bastos**

Graduando em Engenharia de Software — SENAI FATESG

[GitHub — LimpotRed](https://github.com/LimpotRed)

---

*GHydro — Tecnologia e informação aplicadas à gestão agrícola.*
