<p align="center">
  <img src="images/ARMOR_BANNER.svg" alt="ARMOR-IOS-CONTROL banner" width="100%">
</p>

# 📱 ARMOR-IOS-CONTROL

<p align="center">
  <a href="README.md">🇺🇸 English</a> |
  <a href="README_spa.md">🇪🇸 Español</a> |
  <a href="README_fra.md">🇫🇷 Français</a> |
  <a href="README_ita.md">🇮🇹 Italiano</a> |
  <a href="README_deu.md">🇩🇪 Deutsch</a> |
  <a href="README_zho.md">🇨🇳 简体中文</a> |
  <a href="README_jpn.md">🇯🇵 日本語</a> |
  🇵🇹 <b>Português</b>
</p>

### Cliente de operador para iPhone do ARMOR-SERVER: estado, armar, alarmes, centrais de alarme, câmaras e o assistente, em oito idiomas

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL%203.0--or--later-blue.svg" alt="GPL 3.0 or later">
  <img src="https://img.shields.io/badge/Language-Swift-f05138.svg" alt="Language">
  <img src="https://img.shields.io/badge/UI-SwiftUI-0a84ff.svg" alt="UI">
  <img src="https://img.shields.io/badge/Languages-8-00E5FF.svg" alt="Languages">
  <img src="https://img.shields.io/badge/Tests-146%20passing-2ea44f.svg" alt="Tests">
  <img src="https://img.shields.io/badge/Version-0.0.1-0f6cbd.svg" alt="Version">
  <img src="https://img.shields.io/badge/Maturity-scaffolding-FFB020.svg" alt="Maturity">
</p>

---

**Verificação de honestidade - o que funciona hoje:** as regras da app (ligação ao servidor, leitura das respostas, escolha do endereço, bloqueio do telemóvel, cofre da sessão, confiança no certificado, política de alarmes, casos de uso, corte do MJPEG) são o pacote Swift `ArmorCore`, coberto por 146 testes unitários que correm com `swift test` em macOS ou Linux, e `tools/ios_lint.py` verifica a estrutura, as oito tabelas de idiomas e o contrato sem Mac. O que **ainda não** está provado: os ecrãs SwiftUI e as partes que precisam de um iPhone (Face ID, porta-chaves, regras de certificado, câmara em direto, push com Firebase) não foram compilados no Xcode nem executados num dispositivo.

---

## 📋 Num relance

| | |
|---|---|
| Versão | `0.0.1` |
| Maturidade | Estrutura inicial |
| Função | Cliente de operador para iPhone do ARMOR-SERVER (família: Clients, pai: ARMOR-SERVER) |
| Tecnologia | Swift 5.9+ / SwiftUI, iOS 16+ |
| Testes | 146 (`swift test`) |
| Línguas | 8 (241 frases por língua, verificadas pelo `ios_lint.py`) |
| Funciona em | Um iPhone com iOS 16+; os testes correm em macOS ou Linux |
| Em hardware real | Ainda não foi executado num iPhone; as regras são testadas em Linux |
| Licença | GPL-3.0-or-later |

**Ir para:** [Visão geral](#-visão-geral) · [Arquitetura](#-arquitetura) · [Segurança](#-segurança-e-proteção) · [Interfaces](#-interfaces) · [Configuração](#-configuração) · [Início rápido](#-início-rápido) · [Testes](#-testes) · [Problemas](#-resolução-de-problemas) · [Estrutura](#-estrutura-do-repositório) · [Relacionados](#-projetos-relacionados)

## 🚦 Estado do projeto

Cada linha é uma parte deste repositório e a luz diz até onde chega hoje. É escrita com o que o repositório consegue demonstrar (testes, compilações, execuções), não com o que está previsto.

🟢 Feito e verificado · 🟡 Funciona, com limites conhecidos · 🟠 Feito a meio ou ainda por verificar · 🔴 Por fazer ou a não funcionar

| Área | Estado | O que significa aqui |
|---|---|---|
| Software | 🟠 | As regras da app são um pacote Swift (`ArmorCore`); os ecrãs SwiftUI não foram compilados no Xcode. |
| Testes | 🟡 | Passam 146 testes unitários com `swift test` em macOS ou Linux, e o `tools/ios_lint.py` verifica a estrutura, as tabelas dos oito idiomas e o contrato sem um Mac; nenhum teste corre num dispositivo. |
| Interface | 🟠 | Os ecrãs SwiftUI estão escritos, mas não foram compilados no Xcode nem executados num iPhone. |
| Hardware | 🔴 | Não correu num iPhone: as regras só são testadas em Linux. |
| Segurança | 🟠 | O bloqueio do telefone, o cofre da sessão e a confiança no certificado são regras testadas em Linux; o Face ID, o porta-chaves e as regras do certificado não correram num dispositivo. |
| Integração | 🟠 | A câmara em direto e o push através do Firebase não foram experimentados; a ligação ao servidor e a análise são testadas contra o contrato partilhado. |
| Documentação | 🟡 | Oito idiomas e o registo de alterações estão atualizados. |

## 🎯 Visão geral

* **Inicie sessão com o acesso do próprio servidor:** os endereços da casa (em casa e fora), utilizador e palavra-passe; a palavra-passe cria uma sessão HttpOnly; só é guardada se marcar **Lembrar-me** (na porta-chaves deste telemóvel, sem cópia de segurança). O papel **viewer** só olha: todo o botão que altera algo fica desligado.
* **Dois endereços:** o privado na Wi-Fi de casa e o de fora (um nome DNS dinâmico ou a VPN) com dados móveis; se um não responder tenta-se o outro e a mensagem diz o que falha.
* **Bloqueio com o telemóvel:** Face ID, Touch ID ou o código antes de armar, desarmar, silenciar uma sirene, desbloquear e as outras ordens críticas (ativo por defeito só com Face ID ou Touch ID) e, se o ativar, para abrir a app. O administrador pode exigi-lo, nunca baixar o que escolheu; um telemóvel sem código nunca fica de fora e o ecrã de bloqueio oferece sempre entrar com a palavra-passe. Opcionalmente (desligado, com aviso) a sessão guardada só se lê com o telemóvel desbloqueado.
* **Armar e desarmar** depois de verificar o que ficaria cego ou ruidoso, com o PIN para desarmar; **alarmes** a confirmar, com contador; as **centrais de alarme** (armar ausente ou em casa, desarmar, silenciar a sirene) e o **histórico**; **dispositivos** com Ligar / Desligar e confirmação para circuitos e críticos.
* **Câmaras** através do servidor (a app nunca tem a palavra-passe da câmara): uma grelha onde só correm as imagens visíveis, uma vista completa com cruzeta para mover a câmara e foto, e um fluxo pedido de novo com esperas crescentes se se cortar.
* **Avisos à tua medida:** silenciar tudo ou mostrá-lo sem som; desligar gravidades e tipos (um alarme crítico nunca é escondido, a não ser com o interruptor que silencia tudo); um ficheiro de som teu para cada gravidade e cada tipo, com botão de reprodução; e a voz que diz os alarmes (mulher, homem, idade, estilo, velocidade, avisos de baixa gravidade), com botão de teste. Uma câmara com duas lentes numa só imagem aparece como duas janelas. Os avisos também aparecem com a app aberta (um banner e o som do aviso); o que escolheu sobre ocultar ou silenciar um aviso continua a ter prioridade.
* **O assistente:** ordens escritas (o microfone do teclado dita), com uma confirmação ligada a si para armar e desarmar, atrás do bloqueio.
* **Confiança no certificado:** a chave do certificado da instalação é memorizada na primeira vez ou emparelhada com o QR do Studio; se mudar, a ligação é recusada e é avisado.
* **Oito idiomas** (inglês, espanhol, alemão, francês, italiano, japonês, chinês e português de Portugal), a escolher em *Mais > Idioma* ou a seguir o telemóvel, com ajuda para cada ecrã.

## 🧩 Papel no A.R.M.O.R.

O ARMOR-IOS-CONTROL é a janela do iPhone para o mesmo [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER) que o [ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) e o [ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL) usam: lê e ordena através dele e nada mais, e fala o mesmo contrato que a app Android.

| Nome | Como | Para quê |
|---|---|---|
| ARMOR-SERVER | HTTP `/api/v1`, MJPEG | Tudo o que a app lê e ordena; não fala com mais nada |
| ARMOR-ANDROID-CONTROL | mesmo contrato | O `ios_lint.py` verifica que a app só chama caminhos que o cliente Android também chama |
| ARMOR-STUDIO | QR | Emparelha a chave do certificado da instalação |

## 🏛️ Arquitetura

<p align="center">
  <img src="images/architecture.svg" alt="Arquitetura de ARMOR-IOS-CONTROL: quem o chama, o que contém e de que depende" width="100%">
</p>

## 🔒 Segurança e proteção

| Ameaça | Defesa |
|---|---|
| A palavra-passe no telemóvel | Guardada só com *Lembrar-me*, no Keychain deste telemóvel e nunca em cópias de segurança; a sessão é um cookie HttpOnly do servidor |
| Uma ordem crítica com o telemóvel noutras mãos | Face ID, Touch ID ou o código antes de armar, desarmar, silenciar uma sirene, desbloquear e as outras ordens críticas; o administrador pode exigi-lo, nunca baixar o que escolheu; um telemóvel sem código nunca fica de fora |
| Um certificado alterado ou forjado | A chave do certificado da instalação é memorizada à primeira vez ou emparelhada com o QR do Studio; se mudar, a ligação é recusada e é avisado |
| A palavra-passe enviada em claro | HTTP simples só para um endereço de rede privada ou loopback (`NSAllowsLocalNetworking`); tudo o resto exige https, senão a app recusa enviar a palavra-passe |
| Uma palavra-passe de câmara no telemóvel | As câmaras passam pelo servidor: a app não tem palavra-passe de câmara nem endereço RTSP |
| Um visualizador altera algo | O papel *visualizador* só vê: todos os botões que alteram algo estão desligados; o servidor volta a verificar |
| O assistente arma ou desarma por engano | Só ordens escritas (o microfone do teclado dita); armar e desarmar exigem uma confirmação ligada a si, atrás do bloqueio do telemóvel |

Os textos de permissões (Face ID, rede local) existem nas oito línguas. Nada disto correu num iPhone: o Face ID, o Keychain e as regras de certificado não foram testados num dispositivo. Leia [docs/CLIENT_BOUNDARY.md](docs/CLIENT_BOUNDARY.md) e [SECURITY.md](SECURITY.md).

## 🔌 Interfaces

É um cliente: chama 26 caminhos do ARMOR-SERVER (o `tools/ios_lint.py` conta-os e verifica que o cliente Android também os chama) e corta o fluxo MJPEG das câmaras com um analisador próprio (`MjpegParser.swift`).

| Parte | O que define |
|---|---|
| Dois endereços | O privado no Wi-Fi de casa e o de fora (um nome DNS dinâmico ou a VPN) com dados móveis; se um não responder tenta-se o outro e a mensagem diz o que falhou (`Reach.swift`, `Connector.swift`) |
| Câmaras | Uma grelha onde só correm as imagens visíveis, uma vista completa com comando para mover a câmara e um instantâneo, e um fluxo pedido de novo com esperas crescentes se cair |
| Push | Os alarmes só chegam a uma app fechada por push (`Push.swift`, Firebase), e só se o servidor tiver o push ativo e a instalação trouxer o seu próprio `GoogleService-Info.plist`; não experimentado |

## ⚙️ Configuração

| Nome | Valor | O que define |
|---|---|---|
| iOS | 16.0+ | Versão mínima, definida em `project.yml` |
| Xcode / Swift | 15+ / 5.9+ | Para compilar a app / para executar os testes |
| `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` | 0.0.1, 1 | A versão da app, de `project.yml` |
| `GoogleService-Info.plist` | para push | O ficheiro próprio da instalação, nunca guardado no repositório |

Na app: os dois endereços, *Lembrar-me*, o bloqueio do telemóvel e a língua (as oito ou seguir o telemóvel) em *Mais > Língua*.

## 🚀 Início rápido

**Requisitos:** um Mac com Xcode 15+ e iOS 16+ para compilar a app; Swift 5.9+ (macOS ou Linux) para os testes; Python 3.11 para as verificações.

```sh
swift test                  # 146 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

O projeto Xcode gera-se a partir de `project.yml` com o XcodeGen. Escolha uma equipa de assinatura, adicione o ícone da app e, para o push, o `GoogleService-Info.plist` da instalação (nunca guardado no repositório). Veja o [limite do cliente](docs/CLIENT_BOUNDARY.md).

## 🧪 Testes

```sh
swift test                  # macOS or Linux
python tools/ios_lint.py    # any system, no Mac needed
python -I tools/armor_ci_validate.py
```

| Ficheiro de testes | Testes | O que cobre |
|---|---|---|
| `ControllerTests.swift` | 15 | Os casos de uso do controlador |
| `ClientTests.swift` | 14 | A ligação ao servidor e a sua interpretação |
| `LockTests.swift` | 12 | O bloqueio do telemóvel |
| `ModelsTests.swift` | 12 | Os modelos lidos do servidor |
| `ReachTests.swift` | 11 | A escolha entre os dois endereços |
| `SecurityTests.swift` | 8 | O cofre da sessão e a confiança no certificado |
| `EndpointTests.swift`, `MjpegTests.swift`, `TranslatorTests.swift` | 7 + 7 + 7 | A leitura de endereços, o corte MJPEG e o tradutor |
| `PolicyTests.swift`, `AlarmCodesTests.swift` | 6 + 4 | A política de alarmes e os códigos de alarme |

Os 146 testes usam dados de um servidor real. O `tools/ios_lint.py` passa sem Mac: 31 ficheiros Swift, 241 frases em 8 línguas, 26 caminhos do servidor. Nenhum teste corre num dispositivo.

## 🏗️ Compilação e publicação

O projeto Xcode gera-se a partir de `project.yml` com o XcodeGen: escolha uma equipa de assinatura, junte o ícone da app a `App/Resources/Assets.xcassets/AppIcon.appiconset` e, para push, o `GoogleService-Info.plist` da instalação. Nunca foi compilado no Xcode.

## 🩺 Resolução de problemas

| Vê | Porque | Faça |
|---|---|---|
| A ligação é recusada e é avisado | A chave do certificado da instalação mudou | Emparelhe de novo com o QR do Studio se o mudou de propósito |
| Nenhum dos dois endereços responde | Endereço errado, sem rede, ou http para um sítio fora de casa (recusado: a palavra-passe não é enviada em claro) | Verifique os dois endereços; use https fora de casa |
| `wrong_pin`, `pin_locked`, `pin_not_set` | O servidor recusa o PIN de desarmar; a app mostra o código na sua língua | Escreva o PIN de novo ou espere o fim do bloqueio; defina-o no Studio |

## 📂 Estrutura do repositório

<p align="center">
  <img src="images/repository-structure.svg" alt="Estrutura do repositório de ARMOR-IOS-CONTROL" width="100%">
</p>

<details>
<summary>Versão em texto da árvore</summary>

```text
ARMOR-IOS-CONTROL/
├── Sources/ArmorCore/                   as regras da app: um pacote Swift
├── App/                                 os ecrãs SwiftUI e as partes que precisam de um iPhone
├── Tests/                               146 testes e dados de um servidor real
├── docs/                                os guias deste repositório
├── tools/                               as verificações de CI partilhadas e as ferramentas do projeto
├── .github/                             fluxo de CI e modelos de issues e pull requests
├── images/                              faixa, ícone e as duas imagens deste README
├── armor.project.json                   manifesto: versão, função, maturidade, comando de build
├── CHANGELOG.md                         o que mudou em cada versão
├── SECURITY.md SUPPORT.md LICENSE       política de segurança, apoio e licença
├── CONTRIBUTING.md CODE_OF_CONDUCT.md   como contribuir e o código de conduta
├── Package.swift                        o pacote Swift: ArmorCore e os seus testes
├── project.yml                          XcodeGen: daqui gera-se o projeto Xcode
└── .gitattributes .gitignore            definições do Git
```

</details>

## 🗺️ Roteiro e limites conhecidos

**Limites conhecidos hoje**

* Nada correu num iPhone: os ecrãs SwiftUI não foram compilados no Xcode; o Face ID, o Keychain, as regras de certificado, a câmara em direto, os sons dos avisos, a voz e o push via Firebase não foram testados.
* Só as regras (`ArmorCore`) estão testadas, e só em Linux.
* A app não vigia em segundo plano: o iOS não deixa uma app fechada consultar o servidor.

**A seguir**

* Compilar os ecrãs no Xcode e correr a app num iPhone contra a bancada de testes CM5.
* Experimentar o Face ID, o Keychain, as regras de certificado, a câmara em direto e o push.

## 🌍 Idiomas

O README e os textos existem em inglês, espanhol, francês, italiano, alemão, chinês, japonês e português europeu.

## 🔗 Projetos relacionados

O **A.R.M.O.R.** (Autonomous Radar & Multimodal Observation Range) é um sistema de segurança perimetral feito de repositórios independentes. Cada um tem a sua própria versão, os seus próprios testes e o seu próprio README; esta é a família:

* **[ARMOR-COMMON](https://github.com/JuanenRac/ARMOR-COMMON)** - Contratos de mensagens, validadores, vetores de conformidade e tipos gerados
* **[ARMOR-NODE-RADAR](https://github.com/JuanenRac/ARMOR-NODE-RADAR)** - Firmware de nó de campo para ESP32-S3 com três radares e o seu próprio painel web
* **[ARMOR-NODE-SOLAR](https://github.com/JuanenRac/ARMOR-NODE-SOLAR)** - Protocolos de inversores e baterias solares e as mensagens de um nó porta de ligação
* **[ARMOR-NODE-ELECTRICAL](https://github.com/JuanenRac/ARMOR-NODE-ELECTRICAL)** - Nó elétrico: contadores, a mensagem das leituras da rede e as regras de comutação
* **[ARMOR-NODE-ALARM](https://github.com/JuanenRac/ARMOR-NODE-ALARM)** - Nó e painel de alarme: zonas, armar, atrasos, sirene e PIN, com o servidor ou sem ele
* **[ARMOR-NODE-HMI](https://github.com/JuanenRac/ARMOR-NODE-HMI)** - Painel tátil: o estado do sistema num ecrã de parede, armar e reconhecer, e a casa do assistente de voz
* **[ARMOR-NETWORK](https://github.com/JuanenRac/ARMOR-NETWORK)** - A rede local: os seus dispositivos, a internet e o que muda
* **[ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER)** - Coordenador central: telemetria, alarmes, dispositivos, leituras solares e câmaras
* **[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO)** - Consola web: câmaras, radar, alarmes, energia solar e o desenhador 2D/3D do local
* **[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL)** - Cliente de operador Android com radar 2D/3D em direto
* **ARMOR-IOS-CONTROL** (este repositório) - Cliente de operador para iPhone
* **[ARMOR-SERVER-AI](https://github.com/JuanenRac/ARMOR-SERVER-AI)** - Política de inferência visual que explica as suas decisões e nunca atua
* **[ARMOR-VISION](https://github.com/JuanenRac/ARMOR-VISION)** - Zonas de câmara, máscaras e regras de deteção para o Jetson Orin NX
* **[ARMOR-VOICE-AI](https://github.com/JuanenRac/ARMOR-VOICE-AI)** - Intenções de voz offline com uma confirmação que não pode ser falsificada
* **[ARMOR-HARDWARE](https://github.com/JuanenRac/ARMOR-HARDWARE)** - Caixas, eletrónica e a matriz de aceitação em bancada
* **[ARMOR-DEVOPS](https://github.com/JuanenRac/ARMOR-DEVOPS)** - Implantação, a bancada de testes do CM5, cópias de segurança e TLS
* **[ARMOR-SIMULATOR](https://github.com/JuanenRac/ARMOR-SIMULATOR)** - Simulador de telemetria offline com falhas repetíveis
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - Deteta, instala e atualiza os repositórios do próprio ecossistema
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - Arquitetura, base de segurança e a matriz de capacidades

## 📚 Documentação

* [Limites do cliente](docs/CLIENT_BOUNDARY.md): o que o cliente faz e nunca faz, e como o compilar
* [Matriz de capacidades: o que está demonstrado e o que não está](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [Catálogo de projetos: versões e como os repositórios dependem uns dos outros](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [Registo de alterações deste repositório](CHANGELOG.md)

## 🤝 Contribuir e comunidade

* Antes de um pull request, execute `swift test` and `python tools/ios_lint.py` and `python -I tools/armor_ci_validate.py`: tem de passar. Consulte [CONTRIBUTING.md](CONTRIBUTING.md) e o [código de conduta](CODE_OF_CONDUCT.md).
* O README existe em oito idiomas e é gerado a partir das fontes do ARMOR-DOCS: uma alteração ao texto faz-se lá.
* Uma alteração a uma mensagem entre componentes começa no ARMOR-COMMON.
* Não descreva como a funcionar numa placa aquilo que só foi compilado.
* Comunique uma vulnerabilidade em privado: [SECURITY.md](SECURITY.md). Perguntas, ideias e relatórios: electrohobby3d@gmail.com ([SUPPORT.md](SUPPORT.md)).

## 👤 AUTOR

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 LICENÇA

GPL-3.0-or-later - consulte [LICENSE](LICENSE).
