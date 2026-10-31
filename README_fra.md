<p align="center">
  <img src="images/ARMOR_BANNER.svg" alt="Bannière d'ARMOR-IOS-CONTROL" width="100%">
</p>

# 📱 ARMOR-IOS-CONTROL

<p align="center">
  <a href="README.md">🇺🇸 English</a> |
  <a href="README_spa.md">🇪🇸 Español</a> |
  🇫🇷 <b>Français</b> |
  <a href="README_ita.md">🇮🇹 Italiano</a> |
  <a href="README_deu.md">🇩🇪 Deutsch</a> |
  <a href="README_zho.md">🇨🇳 简体中文</a> |
  <a href="README_jpn.md">🇯🇵 日本語</a> |
  <a href="README_por.md">🇵🇹 Português</a>
</p>

### Client opérateur iPhone d'ARMOR-SERVER : état, armement, alarmes, centrales d'alarme, caméras et assistant, en huit langues

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL%203.0--or--later-blue.svg" alt="GPL 3.0 ou ultérieure">
  <img src="https://img.shields.io/badge/Language-Swift-f05138.svg" alt="Langage">
  <img src="https://img.shields.io/badge/UI-SwiftUI-0a84ff.svg" alt="UI">
  <img src="https://img.shields.io/badge/Languages-8-00E5FF.svg" alt="Langues">
  <img src="https://img.shields.io/badge/Tests-159%20passing-2ea44f.svg" alt="Tests">
  <img src="https://img.shields.io/badge/Version-0.0.1-0f6cbd.svg" alt="Version">
  <img src="https://img.shields.io/badge/Maturity-scaffolding-FFB020.svg" alt="Maturité">
</p>

---

**Vérification d'honnêteté - ce qui fonctionne aujourd'hui :** les règles de l'app (liaison au serveur, lecture des réponses, choix de l'adresse, verrou du téléphone, coffre de la session, confiance dans le certificat, politique d'alarmes, cas d'usage, découpage du MJPEG) forment le paquet Swift `ArmorCore`, couvert par 159 tests unitaires qui s'exécutent avec `swift test` sous macOS ou Linux, et `tools/ios_lint.py` vérifie la structure, les huit tables de langues et le contrat sans Mac. Ce qui n'est **pas** encore prouvé : les écrans SwiftUI et les parties qui exigent un iPhone (Face ID, trousseau, règles de certificat, caméra en direct, push via Firebase) n'ont pas été compilés dans Xcode ni exécutés sur un appareil.

---

## 📋 En un coup d'œil

| | |
|---|---|
| Version | `0.0.1` |
| Maturité | Ébauche |
| Rôle | Client opérateur iPhone pour ARMOR-SERVER (famille : Clients, parent : ARMOR-SERVER) |
| Technologie | Swift 5.9+ / SwiftUI, iOS 16+ |
| Tests | 159 (`swift test`) |
| Langues | 8 (241 phrases par langue, vérifiées par `ios_lint.py`) |
| Fonctionne sur | Un iPhone avec iOS 16+ ; les tests tournent sous macOS ou Linux |
| Sur matériel réel | Pas encore exécuté sur un iPhone ; les règles sont testées sous Linux |
| Licence | GPL-3.0-or-later |

**Aller à :** [Présentation](#-présentation) · [Architecture](#-architecture) · [Sécurité](#-sécurité-et-protection) · [Interfaces](#-interfaces) · [Configuration](#-configuration) · [Démarrage rapide](#-démarrage-rapide) · [Tests](#-tests) · [Dépannage](#-dépannage) · [Structure](#-structure-du-dépôt) · [Liés](#-projets-liés)

## 🚦 État du projet

Chaque ligne est une partie de ce dépôt et le feu dit où elle en est aujourd'hui. Elle est écrite d'après ce que le dépôt peut montrer (tests, compilations, exécutions), pas d'après ce qui est prévu.

🟢 Fait et vérifié · 🟡 Fonctionne, avec des limites connues · 🟠 À moitié fait ou pas encore vérifié · 🔴 Pas fait ou ne fonctionne pas

| Domaine | État | Ce que cela veut dire ici |
|---|---|---|
| Logiciel | 🟠 | Les règles de l'application forment un paquet Swift (`ArmorCore`) ; les écrans SwiftUI n'ont pas été compilés dans Xcode. |
| Tests | 🟡 | 159 tests unitaires réussissent avec `swift test` sous macOS ou Linux, et `tools/ios_lint.py` vérifie la structure, les tables des huit langues et le contrat sans Mac ; aucun test ne tourne sur un appareil. |
| Interface | 🟠 | Les écrans SwiftUI sont écrits mais n'ont été ni compilés dans Xcode ni exécutés sur un iPhone. |
| Matériel | 🔴 | Elle n'a pas tourné sur un iPhone : les règles ne sont testées que sous Linux. |
| Sécurité | 🟠 | Le verrouillage du téléphone, le coffre de la session et la confiance dans le certificat sont des règles testées sous Linux ; Face ID, le trousseau et les règles du certificat n'ont pas tourné sur un appareil. |
| Intégration | 🟠 | La caméra en direct et le push via Firebase n'ont pas été essayés ; la liaison au serveur et l'analyse sont testées contre le contrat partagé. |
| Documentation | 🟡 | Huit langues et le journal des modifications sont à jour. |

## 🎯 Présentation

* **Connexion avec l'identifiant du serveur lui-même :** les adresses de la maison (à la maison et à l'extérieur), utilisateur et mot de passe ; le mot de passe crée une session HttpOnly ; il n'est conservé que si vous cochez **Se souvenir de moi** (dans le trousseau de ce téléphone, jamais sauvegardé). Le rôle **viewer** regarde seulement : tout bouton qui modifie quelque chose est désactivé.
* **Deux adresses :** la privée sur le Wi-Fi de la maison, celle de l'extérieur (un nom DNS dynamique ou le VPN) avec les données mobiles ; si l'une ne répond pas, l'autre est essayée et le message dit ce qui échoue.
* **Verrou du téléphone :** Face ID, Touch ID ou le code avant d'armer, de désarmer, de couper une sirène, de déverrouiller et les autres ordres critiques (activé par défaut seulement avec Face ID ou Touch ID) et, si vous l'activez, pour ouvrir l'app. Votre administrateur peut l'exiger, jamais baisser ce que vous avez choisi ; un téléphone sans code n'est jamais bloqué et l'écran verrouillé propose toujours de se connecter avec le mot de passe. En option (désactivé, avec avertissement), la session enregistrée n'est lisible que téléphone déverrouillé.
* **Armer et désarmer** après vérification de ce qui resterait aveugle ou bruyant, avec le PIN pour désarmer ; **alarmes** à acquitter, avec compteur ; les **centrales d'alarme** (armer absent ou présent, désarmer, couper la sirène) et l'**historique** ; **appareils** avec Marche / Arrêt et confirmation pour les circuits et les appareils critiques.
* **Caméras** via le serveur (l'app n'a jamais le mot de passe de la caméra) : une grille où seules les images à l'écran tournent, une vue complète avec une croix pour déplacer la caméra et une photo, et un flux redemandé avec des attentes croissantes s'il se coupe.
* **Des avis à votre mesure :** tout mettre en sourdine ou l'afficher sans son ; désactiver des gravités et des types (une alarme critique n'est jamais masquée, sauf par l'interrupteur qui coupe tout) ; un fichier de son à vous pour chaque gravité et chaque type, avec un bouton de lecture ; et la voix qui dit les alarmes (femme, homme, âge, style, vitesse, avis de faible gravité), avec un bouton d'essai. Une caméra à deux objectifs dans une même image apparaît comme deux fenêtres. Les notices s'affichent aussi quand l'app est ouverte (une bannière et le son de la notice) ; ce que vous avez choisi pour masquer ou couper une notice passe toujours en premier.
* **L'assistant :** commandes écrites (le micro du clavier dicte), avec une confirmation liée à vous pour armer et désarmer, derrière le verrou.
* **Confiance dans le certificat :** la clé du certificat de l'installation est retenue la première fois ou appairée avec le QR de Studio ; si elle change, la connexion est refusée et vous êtes prévenu.
* **Huit langues** (anglais, espagnol, allemand, français, italien, japonais, chinois et portugais du Portugal), choisies dans *Plus > Langue* ou suivant le téléphone, avec une aide pour chaque écran.
* **Modes d'armement du serveur (Absent, À la maison, Nuit) :** quand le serveur a les modes d'armement activés (Studio, Configuration > Sécurité), le bouton d'armement de l'écran d'état ouvre un sélecteur pour armer dans un mode, passer de l'un à l'autre ou désarmer ; un mode sans rien d'attribué demande une confirmation, un passage à un mode qui protège moins demande le PIN comme un désarmement, et l'état montre le mode en vigueur. Armer depuis l'état désarmé exécute d'abord la vérification avant armement, comme un armement simple. Modes éteints, l'application arme et désarme comme avant. Elle suit l'application Android ; le code et ses tests sont écrits et n'ont été ni compilés ni essayés sur un iPhone.

## 🧩 Rôle dans A.R.M.O.R.

ARMOR-IOS-CONTROL est la fenêtre de l'iPhone sur le même [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER) que celui d'[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) et d'[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL) : il lit et ordonne par lui et rien d'autre, et parle le même contrat que l'app Android.

| Nom | Comment | À quoi ça sert |
|---|---|---|
| ARMOR-SERVER | HTTP `/api/v1`, MJPEG | Tout ce que l'app lit et commande ; elle ne parle à rien d'autre |
| ARMOR-ANDROID-CONTROL | même contrat | `ios_lint.py` vérifie que l'app n'appelle que des chemins appelés par le client Android |
| ARMOR-STUDIO | QR | Apparie la clé du certificat de l'installation |

## 🏛️ Architecture

<p align="center">
  <img src="images/architecture.svg" alt="Architecture de ARMOR-IOS-CONTROL : qui l'appelle, ce qu'il contient et de quoi il dépend" width="100%">
</p>

## 🔒 Sécurité et protection

| Menace | Défense |
|---|---|
| Le mot de passe sur le téléphone | Conservé seulement avec *Se souvenir de moi*, dans le Keychain de ce téléphone et jamais sauvegardé ; la session est un cookie HttpOnly du serveur |
| Un ordre critique avec le téléphone en d'autres mains | Face ID, Touch ID ou le code avant d'armer, désarmer, couper une sirène, déverrouiller et les autres ordres critiques ; l'administrateur peut l'exiger, jamais abaisser votre choix ; un téléphone sans code n'est jamais exclu |
| Un certificat changé ou falsifié | La clé du certificat de l'installation est mémorisée la première fois ou appariée avec le QR de Studio ; si elle change, la connexion est refusée et vous êtes prévenu |
| Le mot de passe envoyé en clair | HTTP en clair seulement pour une adresse de réseau privé ou loopback (`NSAllowsLocalNetworking`) ; tout le reste exige https, sinon l'app refuse d'envoyer le mot de passe |
| Un mot de passe de caméra sur le téléphone | Les caméras passent par le serveur : l'app n'a ni mot de passe de caméra ni adresse RTSP |
| Un lecteur change quelque chose | Le rôle *lecteur* ne fait que regarder : tout bouton qui change quelque chose est désactivé ; le serveur revérifie |
| L'assistant arme ou désarme par erreur | Seulement des ordres écrits (le micro du clavier dicte) ; armer et désarmer exigent une confirmation liée à vous, derrière le verrouillage du téléphone |

Les textes d'autorisation (Face ID, réseau local) existent dans les huit langues. Rien de tout cela n'a tourné sur un iPhone : Face ID, le Keychain et les règles de certificat ne sont pas testés sur un appareil. Lisez [docs/CLIENT_BOUNDARY.md](docs/CLIENT_BOUNDARY.md) et [SECURITY.md](SECURITY.md).

## 🔌 Interfaces

C'est un client : il appelle 26 chemins d'ARMOR-SERVER (`tools/ios_lint.py` les compte et vérifie que le client Android les appelle aussi) et découpe le flux MJPEG des caméras avec son propre analyseur (`MjpegParser.swift`).

| Partie | Ce qu'elle règle |
|---|---|
| Deux adresses | La privée sur le Wi-Fi de la maison et celle pour l'extérieur (un nom DNS dynamique ou le VPN) en données mobiles ; si l'une ne répond pas, l'autre est essayée et le message dit ce qui a échoué (`Reach.swift`, `Connector.swift`) |
| Caméras | Une grille où seules les images à l'écran tournent, une vue complète avec une croix pour bouger la caméra et un instantané, et un flux redemandé avec des attentes croissantes en cas de coupure |
| Push | Les alarmes n'atteignent une app fermée que par push (`Push.swift`, Firebase), et seulement si le serveur a le push activé et que l'installation apporte son propre `GoogleService-Info.plist` ; non essayé |

## ⚙️ Configuration

| Nom | Valeur | Ce qu'elle règle |
|---|---|---|
| iOS | 16.0+ | Version minimale, définie dans `project.yml` |
| Xcode / Swift | 15+ / 5.9+ | Pour compiler l'app / pour lancer les tests |
| `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` | 0.0.1, 1 | La version de l'app, de `project.yml` |
| `GoogleService-Info.plist` | pour le push | Le fichier propre à l'installation, jamais gardé dans le dépôt |

Dans l'app : les deux adresses, *Se souvenir de moi*, le verrouillage du téléphone et la langue (les huit langues ou suivre le téléphone) dans *Plus > Langue*.

## 🚀 Démarrage rapide

**Prérequis:** un Mac avec Xcode 15+ et iOS 16+ pour compiler l'app ; Swift 5.9+ (macOS ou Linux) pour les tests ; Python 3.11 pour les contrôles.

```sh
swift test                  # 159 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

Le projet Xcode est généré depuis `project.yml` avec XcodeGen. Choisissez une équipe de signature, ajoutez l'icône de l'app et, pour le push, le `GoogleService-Info.plist` de l'installation (jamais conservé dans le dépôt). Voir la [frontière du client](docs/CLIENT_BOUNDARY.md).

## 🧪 Tests

```sh
swift test                  # macOS or Linux
python tools/ios_lint.py    # any system, no Mac needed
python -I tools/armor_ci_validate.py
```

| Fichier de tests | Tests | Ce qu'il couvre |
|---|---|---|
| `ControllerTests.swift` | 15 | Les cas d'usage du contrôleur |
| `ClientTests.swift` | 14 | Le lien avec le serveur et son analyse |
| `LockTests.swift` | 12 | Le verrouillage du téléphone |
| `ModelsTests.swift` | 12 | Les modèles lus depuis le serveur |
| `ReachTests.swift` | 11 | Le choix entre les deux adresses |
| `SecurityTests.swift` | 8 | Le coffre de session et la confiance dans le certificat |
| `EndpointTests.swift`, `MjpegTests.swift`, `TranslatorTests.swift` | 7 + 7 + 7 | L'analyse d'adresses, le découpage MJPEG et le traducteur |
| `PolicyTests.swift`, `AlarmCodesTests.swift` | 6 + 4 | La politique d'alarme et les codes d'alarme |

Les 159 tests utilisent des données d'un vrai serveur. `tools/ios_lint.py` réussit sans Mac : 31 fichiers Swift, 241 phrases en 8 langues, 26 chemins du serveur. Aucun test ne tourne sur un appareil.

## 🏗️ Compilation et publication

Le projet Xcode est généré depuis `project.yml` avec XcodeGen : choisissez une équipe de signature, ajoutez l'icône de l'app à `App/Resources/Assets.xcassets/AppIcon.appiconset` et, pour le push, le `GoogleService-Info.plist` de l'installation. Il n'a jamais été compilé dans Xcode.

## 🩺 Dépannage

| Vous voyez | Parce que | Faites |
|---|---|---|
| La connexion est refusée et vous êtes prévenu | La clé du certificat de l'installation a changé | Appariez de nouveau avec le QR de Studio si vous l'avez changé exprès |
| Aucune des deux adresses ne répond | Mauvaise adresse, pas de réseau, ou http vers un lieu hors de la maison (refusé : le mot de passe n'est pas envoyé en clair) | Vérifiez les deux adresses ; utilisez https hors de la maison |
| `wrong_pin`, `pin_locked`, `pin_not_set` | Le serveur refuse le PIN de désarmement ; l'app affiche le code dans votre langue | Saisissez de nouveau le PIN ou attendez la fin du blocage ; définissez-le dans Studio |

## 📂 Structure du dépôt

<p align="center">
  <img src="images/repository-structure.svg" alt="Structure du dépôt de ARMOR-IOS-CONTROL" width="100%">
</p>

<details>
<summary>Version texte de l'arborescence</summary>

```text
ARMOR-IOS-CONTROL/
├── Sources/ArmorCore/                   les règles de l'app : un paquet Swift
├── App/                                 les écrans SwiftUI et les parties qui exigent un iPhone
├── Tests/                               159 tests et données d'un vrai serveur
├── docs/                                les guides de ce dépôt
├── tools/                               les contrôles CI partagés et les outils du projet
├── .github/                             workflow CI et modèles d'issues et de pull requests
├── images/                              bannière, icône et les deux images de ce README
├── armor.project.json                   manifeste : version, rôle, maturité, commande de build
├── CHANGELOG.md                         ce qui a changé à chaque version
├── SECURITY.md SUPPORT.md LICENSE       politique de sécurité, support et licence
├── CONTRIBUTING.md CODE_OF_CONDUCT.md   comment contribuer et le code de conduite
├── Package.swift                        le paquet Swift : ArmorCore et ses tests
├── project.yml                          XcodeGen : le projet Xcode en est généré
└── .gitattributes .gitignore            réglages Git
```

</details>

## 🗺️ Feuille de route et limites connues

**Limites connues aujourd'hui**

* Rien n'a tourné sur un iPhone : les écrans SwiftUI n'ont pas été compilés dans Xcode ; Face ID, le Keychain, les règles de certificat, la caméra en direct, les sons des avis, la voix et le push via Firebase ne sont pas testés.
* Seules les règles (`ArmorCore`) sont testées, et seulement sous Linux.
* L'app ne surveille pas en arrière-plan : iOS ne laisse pas une app fermée interroger le serveur.

**Ensuite**

* Compiler les écrans dans Xcode et lancer l'app sur un iPhone contre le banc d'essai CM5.
* Essayer Face ID, le Keychain, les règles de certificat, la caméra en direct et le push.

## 🌍 Langues

Le README et les textes existent en anglais, espagnol, français, italien, allemand, chinois, japonais et portugais européen.

## 🔗 Projets liés

**A.R.M.O.R.** (Autonomous Radar & Multimodal Observation Range) est un système de sécurité périmétrique composé de dépôts indépendants. Chacun a sa propre version, ses propres tests et son propre README ; voici la famille :

* **[ARMOR-COMMON](https://github.com/JuanenRac/ARMOR-COMMON)** - Contrats de messages, validateurs, vecteurs de conformité et types générés
* **[ARMOR-NODE-RADAR](https://github.com/JuanenRac/ARMOR-NODE-RADAR)** - Firmware du nœud de terrain pour ESP32-S3 avec trois radars et son propre panneau web
* **[ARMOR-NODE-SOLAR](https://github.com/JuanenRac/ARMOR-NODE-SOLAR)** - Protocoles des onduleurs et batteries solaires et messages d'un nœud passerelle
* **[ARMOR-NODE-ELECTRICAL](https://github.com/JuanenRac/ARMOR-NODE-ELECTRICAL)** - Nœud électrique : compteurs, le message des mesures du réseau et les règles de commutation
* **[ARMOR-NODE-ALARM](https://github.com/JuanenRac/ARMOR-NODE-ALARM)** - Nœud et centrale d'alarme : zones, armement, temporisations, sirène et PIN, avec ou sans le serveur
* **[ARMOR-NODE-HMI](https://github.com/JuanenRac/ARMOR-NODE-HMI)** - Panneau tactile : l'état du système sur un écran mural, armer et acquitter, et la maison de l'assistant vocal
* **[ARMOR-NETWORK](https://github.com/JuanenRac/ARMOR-NETWORK)** - Le réseau local : ses appareils, internet et ce qui change
* **[ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER)** - Coordinateur central : télémétrie, alarmes, appareils, relevés solaires et caméras
* **[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO)** - Console web : caméras, radar, alarmes, énergie solaire et concepteur de site 2D/3D
* **[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL)** - Client Android de l'opérateur avec radar 2D/3D en direct
* **ARMOR-IOS-CONTROL** (ce dépôt) - Client opérateur iPhone
* **[ARMOR-SERVER-AI](https://github.com/JuanenRac/ARMOR-SERVER-AI)** - Politique d'inférence visuelle qui explique ses décisions et n'agit jamais
* **[ARMOR-VISION](https://github.com/JuanenRac/ARMOR-VISION)** - Zones de caméra, masques et règles de détection pour la Jetson Orin NX
* **[ARMOR-VOICE-AI](https://github.com/JuanenRac/ARMOR-VOICE-AI)** - Intentions vocales hors ligne avec une confirmation impossible à falsifier
* **[ARMOR-HARDWARE](https://github.com/JuanenRac/ARMOR-HARDWARE)** - Boîtiers, électronique et matrice d'acceptation sur banc
* **[ARMOR-DEVOPS](https://github.com/JuanenRac/ARMOR-DEVOPS)** - Déploiement, banc d'essai CM5, sauvegarde et TLS
* **[ARMOR-SIMULATOR](https://github.com/JuanenRac/ARMOR-SIMULATOR)** - Simulateur de télémétrie hors ligne avec des pannes reproductibles
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - Détecte, installe et met à jour les propres dépôts de l'écosystème
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - Architecture, base de sécurité et matrice des capacités

## 📚 Documentation

* [Limites du client](docs/CLIENT_BOUNDARY.md) : ce que le client fait et ne fait jamais, et comment le compiler
* [Matrice des capacités : ce qui est prouvé et ce qui ne l'est pas](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [Catalogue des projets : versions et dépendances entre les dépôts](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [Historique des modifications de ce dépôt](CHANGELOG.md)

## 🤝 Contribuer et communauté

* Avant une pull request, lancez `swift test` and `python tools/ios_lint.py` and `python -I tools/armor_ci_validate.py` : il doit réussir. Voir [CONTRIBUTING.md](CONTRIBUTING.md) et le [code de conduite](CODE_OF_CONDUCT.md).
* Le README existe en huit langues et est généré à partir des sources d'ARMOR-DOCS : une modification du texte se fait là-bas.
* Une modification d'un message entre composants commence dans ARMOR-COMMON.
* Ne décrivez pas comme fonctionnant sur une carte ce qui a seulement été compilé.
* Signalez une vulnérabilité en privé : [SECURITY.md](SECURITY.md). Questions, idées et rapports : electrohobby3d@gmail.com ([SUPPORT.md](SUPPORT.md)).

## 👤 AUTEUR

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 LICENCE

GPL-3.0-or-later - voir [LICENSE](LICENSE).
