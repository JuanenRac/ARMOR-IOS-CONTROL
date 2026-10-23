<p align="center">
  <img src="images/ARMOR_BANNER.svg" alt="ARMOR-IOS-CONTROL banner" width="100%">
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
  <img src="https://img.shields.io/badge/License-GPL%203.0-blue.svg" alt="GPL 3.0">
  <img src="https://img.shields.io/badge/Language-Swift-f05138.svg" alt="Language">
  <img src="https://img.shields.io/badge/UI-SwiftUI-0a84ff.svg" alt="UI">
  <img src="https://img.shields.io/badge/Languages-8-00E5FF.svg" alt="Languages">
  <img src="https://img.shields.io/badge/Tests-103%20passing-2ea44f.svg" alt="Tests">
  <img src="https://img.shields.io/badge/Version-0.0.1-0f6cbd.svg" alt="Version">
  <img src="https://img.shields.io/badge/Maturity-scaffolding-FFB020.svg" alt="Maturity">
</p>

---

**Vérification d'honnêteté - ce qui fonctionne aujourd'hui:** les règles de l'app (liaison au serveur, lecture des réponses, choix de l'adresse, verrou du téléphone, coffre de la session, confiance dans le certificat, politique d'alarmes, cas d'usage, découpage du MJPEG) forment le paquet Swift `ArmorCore`, couvert par 103 tests unitaires qui s'exécutent avec `swift test` sous macOS ou Linux, et `tools/ios_lint.py` vérifie la structure, les huit tables de langues et le contrat sans Mac. Ce qui n'est **pas** encore prouvé : les écrans SwiftUI et les parties qui exigent un iPhone (Face ID, trousseau, règles de certificat, caméra en direct, push via Firebase) n'ont pas été compilés dans Xcode ni exécutés sur un appareil.

---

## 📋 En un coup d'œil

| | |
|---|---|
| Version | `0.0.1` |
| Maturité | Ébauche |
| Tests | 103 (`swift test`) |
| Technologie | Swift / SwiftUI |
| Sur matériel réel | Pas encore exécuté sur un iPhone ; les règles sont testées sous Linux |

## 🎯 Présentation

* **Connexion avec l'identifiant du serveur lui-même :** les adresses de la maison (à la maison et à l'extérieur), utilisateur et mot de passe ; le mot de passe crée une session HttpOnly ; il n'est conservé que si vous cochez **Se souvenir de moi** (dans le trousseau de ce téléphone, jamais sauvegardé). Le rôle **viewer** regarde seulement : tout bouton qui modifie quelque chose est désactivé.
* **Deux adresses :** la privée sur le Wi-Fi de la maison, celle de l'extérieur (un nom DNS dynamique ou le VPN) avec les données mobiles ; si l'une ne répond pas, l'autre est essayée et le message dit ce qui échoue.
* **Verrou du téléphone :** Face ID, Touch ID ou le code avant d'armer, de désarmer, de couper une sirène, de déverrouiller et les autres ordres critiques (activé par défaut seulement avec Face ID ou Touch ID) et, si vous l'activez, pour ouvrir l'app. Votre administrateur peut l'exiger, jamais baisser ce que vous avez choisi ; un téléphone sans code n'est jamais bloqué et l'écran verrouillé propose toujours de se connecter avec le mot de passe. En option (désactivé, avec avertissement), la session enregistrée n'est lisible que téléphone déverrouillé.
* **Armer et désarmer** après vérification de ce qui resterait aveugle ou bruyant, avec le PIN pour désarmer ; **alarmes** à acquitter, avec compteur ; les **centrales d'alarme** (armer absent ou présent, désarmer, couper la sirène) et l'**historique** ; **appareils** avec Marche / Arrêt et confirmation pour les circuits et les appareils critiques.
* **Caméras** via le serveur (l'app n'a jamais le mot de passe de la caméra) : une grille où seules les images à l'écran tournent, une vue complète avec une croix pour déplacer la caméra et une photo, et un flux redemandé avec des attentes croissantes s'il se coupe.
* **L'assistant :** commandes écrites (le micro du clavier dicte), avec une confirmation liée à vous pour armer et désarmer, derrière le verrou.
* **Confiance dans le certificat :** la clé du certificat de l'installation est retenue la première fois ou appairée avec le QR de Studio ; si elle change, la connexion est refusée et vous êtes prévenu.
* **Huit langues** (anglais, espagnol, allemand, français, italien, japonais, chinois et portugais du Portugal), choisies dans *Plus > Langue* ou suivant le téléphone, avec une aide pour chaque écran.

## 🧩 Rôle dans A.R.M.O.R.

ARMOR-IOS-CONTROL est la fenêtre de l'iPhone sur le même [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER) que celui d'[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) et d'[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL) : il lit et ordonne par lui et rien d'autre, et parle le même contrat que l'app Android.

## 📂 Structure du dépôt

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

## 🛠️ Environnement de développement

**Prérequis:** un Mac avec Xcode 15+ et iOS 16+ pour compiler l'app ; Swift 5.9+ (macOS ou Linux) pour les tests ; Python 3.11 pour les vérifications

```sh
swift test                  # 103 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

Le projet Xcode est généré depuis `project.yml` avec XcodeGen. Choisissez une équipe de signature, ajoutez l'icône de l'app et, pour le push, le `GoogleService-Info.plist` de l'installation (jamais conservé dans le dépôt). Voir la [frontière du client](docs/CLIENT_BOUNDARY.md).

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

## 📚 Documentation et communauté

Pour en savoir plus :

* [Matrice des capacités : ce qui est prouvé et ce qui ne l'est pas](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [Catalogue des projets : versions et dépendances entre les dépôts](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [Historique des modifications de ce dépôt](CHANGELOG.md)
* [Licence (GPL-3.0-or-later)](LICENSE)
* Questions, idées et rapports : electrohobby3d@gmail.com

## 👤 AUTEUR

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 LICENCE

GPL-3.0-or-later - voir [LICENSE](LICENSE).
