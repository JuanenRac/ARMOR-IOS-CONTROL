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
  <img src="https://img.shields.io/badge/License-GPL%203.0-blue.svg" alt="GPL 3.0">
  <img src="https://img.shields.io/badge/Language-Swift-f05138.svg" alt="Language">
  <img src="https://img.shields.io/badge/UI-SwiftUI-0a84ff.svg" alt="UI">
  <img src="https://img.shields.io/badge/Languages-8-00E5FF.svg" alt="Languages">
  <img src="https://img.shields.io/badge/Tests-103%20passing-2ea44f.svg" alt="Tests">
  <img src="https://img.shields.io/badge/Version-0.0.1-0f6cbd.svg" alt="Version">
  <img src="https://img.shields.io/badge/Maturity-scaffolding-FFB020.svg" alt="Maturity">
</p>

---

**Verificação de honestidade - o que funciona hoje:** as regras da app (ligação ao servidor, leitura das respostas, escolha do endereço, bloqueio do telemóvel, cofre da sessão, confiança no certificado, política de alarmes, casos de uso, corte do MJPEG) são o pacote Swift `ArmorCore`, coberto por 103 testes unitários que correm com `swift test` em macOS ou Linux, e `tools/ios_lint.py` verifica a estrutura, as oito tabelas de idiomas e o contrato sem Mac. O que **ainda não** está provado: os ecrãs SwiftUI e as partes que precisam de um iPhone (Face ID, porta-chaves, regras de certificado, câmara em direto, push com Firebase) não foram compilados no Xcode nem executados num dispositivo.

---

## 📋 Num relance

| | |
|---|---|
| Versão | `0.0.1` |
| Maturidade | Estrutura inicial |
| Testes | 103 (`swift test`) |
| Tecnologia | Swift / SwiftUI |
| Em hardware real | Ainda não foi executado num iPhone; as regras são testadas em Linux |

## 🎯 Visão geral

* **Inicie sessão com o acesso do próprio servidor:** os endereços da casa (em casa e fora), utilizador e palavra-passe; a palavra-passe cria uma sessão HttpOnly; só é guardada se marcar **Lembrar-me** (na porta-chaves deste telemóvel, sem cópia de segurança). O papel **viewer** só olha: todo o botão que altera algo fica desligado.
* **Dois endereços:** o privado na Wi-Fi de casa e o de fora (um nome DNS dinâmico ou a VPN) com dados móveis; se um não responder tenta-se o outro e a mensagem diz o que falha.
* **Bloqueio com o telemóvel:** Face ID, Touch ID ou o código antes de armar, desarmar, silenciar uma sirene, desbloquear e as outras ordens críticas (ativo por defeito só com Face ID ou Touch ID) e, se o ativar, para abrir a app. O administrador pode exigi-lo, nunca baixar o que escolheu; um telemóvel sem código nunca fica de fora e o ecrã de bloqueio oferece sempre entrar com a palavra-passe. Opcionalmente (desligado, com aviso) a sessão guardada só se lê com o telemóvel desbloqueado.
* **Armar e desarmar** depois de verificar o que ficaria cego ou ruidoso, com o PIN para desarmar; **alarmes** a confirmar, com contador; as **centrais de alarme** (armar ausente ou em casa, desarmar, silenciar a sirene) e o **histórico**; **dispositivos** com Ligar / Desligar e confirmação para circuitos e críticos.
* **Câmaras** através do servidor (a app nunca tem a palavra-passe da câmara): uma grelha onde só correm as imagens visíveis, uma vista completa com cruzeta para mover a câmara e foto, e um fluxo pedido de novo com esperas crescentes se se cortar.
* **O assistente:** ordens escritas (o microfone do teclado dita), com uma confirmação ligada a si para armar e desarmar, atrás do bloqueio.
* **Confiança no certificado:** a chave do certificado da instalação é memorizada na primeira vez ou emparelhada com o QR do Studio; se mudar, a ligação é recusada e é avisado.
* **Oito idiomas** (inglês, espanhol, alemão, francês, italiano, japonês, chinês e português de Portugal), a escolher em *Mais > Idioma* ou a seguir o telemóvel, com ajuda para cada ecrã.

## 🧩 Papel no A.R.M.O.R.

O ARMOR-IOS-CONTROL é a janela do iPhone para o mesmo [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER) que o [ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) e o [ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL) usam: lê e ordena através dele e nada mais, e fala o mesmo contrato que a app Android.

## 📂 Estrutura do repositório

```text
ARMOR-IOS-CONTROL/
├── Sources/ArmorCore/   Tr, ServerEndpoint, Models, ArmorApi(+Client), ArmorController, DeviceLock, SessionVault, Trust, Reach, Connector, AlarmPolicy, AlarmText, AlarmCodes (+ alarm_codes.json), MjpegParser
│   └── Resources/i18n/   en, de, fr, it, ja, zh, pt (es is the source text)
├── Tests/ArmorCoreTests/   103 tests + fixtures of a real server
├── App/   SwiftUI: ArmorApp, AppModel, Root, Login, Home, Alarms, Cameras, Assistant, More, Locked, Help
│   ├── Platform/   Keychain, Face ID / Touch ID, certificate rules, push
│   └── Resources/   assets and the permission texts in eight languages
├── project.yml (XcodeGen)   Package.swift
├── tools/ios_lint.py   structure, languages, contract, secrets (no Mac needed)
└── docs/CLIENT_BOUNDARY.md
```

## 🛠️ Ambiente de desenvolvimento

**Requisitos:** um Mac com Xcode 15+ e iOS 16+ para compilar a app; Swift 5.9+ (macOS ou Linux) para os testes; Python 3.11 para as verificações

```sh
swift test                  # 103 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

O projeto Xcode gera-se a partir de `project.yml` com o XcodeGen. Escolha uma equipa de assinatura, adicione o ícone da app e, para o push, o `GoogleService-Info.plist` da instalação (nunca guardado no repositório). Veja o [limite do cliente](docs/CLIENT_BOUNDARY.md).

## 🔗 Projetos relacionados

O **A.R.M.O.R.** (Autonomous Radar & Multimodal Observation Range) é um sistema de segurança perimetral feito de repositórios independentes. Cada um tem a sua própria versão, os seus próprios testes e o seu próprio README; esta é a família:

* **[ARMOR-COMMON](https://github.com/JuanenRac/ARMOR-COMMON)** - Contratos de mensagens, validadores, vetores de conformidade e tipos gerados
* **[ARMOR-NODE-RADAR](https://github.com/JuanenRac/ARMOR-NODE-RADAR)** - Firmware de nó de campo para ESP32-S3 com três radares e o seu próprio painel web
* **[ARMOR-NODE-SOLAR](https://github.com/JuanenRac/ARMOR-NODE-SOLAR)** - Protocolos de inversores e baterias solares e as mensagens de um nó de ligação
* **[ARMOR-NODE-ELECTRICAL](https://github.com/JuanenRac/ARMOR-NODE-ELECTRICAL)** - Nó elétrico: contadores, a mensagem das leituras da rede e as regras de comutação
* **[ARMOR-NODE-ALARM](https://github.com/JuanenRac/ARMOR-NODE-ALARM)** - Nó e central de alarme: zonas, armar, atrasos, sirene e PIN, com o servidor ou sem ele
* **[ARMOR-NODE-HMI](https://github.com/JuanenRac/ARMOR-NODE-HMI)** - Painel tátil: o estado do sistema num ecrã de parede, armar e reconhecer, e a casa do assistente de voz
* **[ARMOR-NETWORK](https://github.com/JuanenRac/ARMOR-NETWORK)** - A rede local: os seus dispositivos, a internet e o que muda
* **[ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER)** - Coordenador central: telemetria, alarmes, dispositivos, leituras solares e câmaras
* **[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO)** - Consola web: câmaras, radar, alarmes, energia solar e o desenhador de local 2D/3D
* **[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL)** - Cliente Android de operador com um radar 2D/3D em direto
* **ARMOR-IOS-CONTROL** (este repositório) - Cliente de operador para iPhone
* **[ARMOR-SERVER-AI](https://github.com/JuanenRac/ARMOR-SERVER-AI)** - Política de inferência visual que explica as suas decisões e nunca atua
* **[ARMOR-VISION](https://github.com/JuanenRac/ARMOR-VISION)** - Zonas de câmara, máscaras e regras de deteção para o Jetson Orin NX
* **[ARMOR-VOICE-AI](https://github.com/JuanenRac/ARMOR-VOICE-AI)** - Intenções de voz offline com uma confirmação que não se pode falsificar
* **[ARMOR-HARDWARE](https://github.com/JuanenRac/ARMOR-HARDWARE)** - Caixas, eletrónica e a matriz de aceitação de bancada
* **[ARMOR-DEVOPS](https://github.com/JuanenRac/ARMOR-DEVOPS)** - Implementação, a bancada de testes CM5, cópias de segurança e TLS
* **[ARMOR-SIMULATOR](https://github.com/JuanenRac/ARMOR-SIMULATOR)** - Simulador de telemetria offline com falhas repetíveis
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - Deteta, instala e atualiza os próprios repositórios do ecossistema
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - Arquitetura, linha de base de segurança e a matriz de capacidades

## 📚 Documentação e comunidade

Onde ler mais:

* [Matriz de capacidades: o que está provado e o que não](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [Catálogo de projetos: versões e como os repositórios dependem uns dos outros](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [Registo de alterações deste repositório](CHANGELOG.md)
* [Licença (GPL-3.0-or-later)](LICENSE)
* Perguntas, ideias e relatórios: electrohobby3d@gmail.com

## 👤 AUTOR

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 LICENÇA

GPL-3.0-or-later - veja [LICENSE](LICENSE).
