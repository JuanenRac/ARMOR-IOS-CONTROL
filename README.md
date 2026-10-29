<p align="center">
  <img src="images/ARMOR_BANNER.svg" alt="ARMOR-IOS-CONTROL banner" width="100%">
</p>

# 📱 ARMOR-IOS-CONTROL

<p align="center">
  🇺🇸 <b>English</b> |
  <a href="README_spa.md">🇪🇸 Español</a> |
  <a href="README_fra.md">🇫🇷 Français</a> |
  <a href="README_ita.md">🇮🇹 Italiano</a> |
  <a href="README_deu.md">🇩🇪 Deutsch</a> |
  <a href="README_zho.md">🇨🇳 简体中文</a> |
  <a href="README_jpn.md">🇯🇵 日本語</a> |
  <a href="README_por.md">🇵🇹 Português</a>
</p>

### iPhone operator client for ARMOR-SERVER: status, arming, alarms, alarm panels, cameras and the assistant, in eight languages

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL%203.0--or--later-blue.svg" alt="GPL 3.0 or later">
  <img src="https://img.shields.io/badge/Language-Swift-f05138.svg" alt="Language">
  <img src="https://img.shields.io/badge/UI-SwiftUI-0a84ff.svg" alt="UI">
  <img src="https://img.shields.io/badge/Languages-8-00E5FF.svg" alt="Languages">
  <img src="https://img.shields.io/badge/Tests-103%20passing-2ea44f.svg" alt="Tests">
  <img src="https://img.shields.io/badge/Version-0.0.1-0f6cbd.svg" alt="Version">
  <img src="https://img.shields.io/badge/Maturity-scaffolding-FFB020.svg" alt="Maturity">
</p>

---

**Honesty check - what runs today:** the rules of the app (server link, parsing, choice of address, lock of the phone, vault of the session, trust in the certificate, alarm policy, use cases, MJPEG cutting) are the Swift package `ArmorCore`, covered by 103 unit tests that run with `swift test` on macOS or Linux, and `tools/ios_lint.py` checks the structure, the eight language tables and the contract without a Mac. What is **not** proven yet: the SwiftUI screens and the parts that need an iPhone (Face ID, Keychain, certificate rules, live camera, push through Firebase) have not been built in Xcode or run on a device.

---

## 📋 At a glance

| | |
|---|---|
| Version | `0.0.1` |
| Maturity | Scaffolding |
| Role | iPhone operator client for ARMOR-SERVER (family: Clients, parent: ARMOR-SERVER) |
| Stack | Swift 5.9+ / SwiftUI, iOS 16+ |
| Tests | 103 (`swift test`) |
| Languages | 8 (241 phrases per language, checked by `ios_lint.py`) |
| Runs on | An iPhone with iOS 16+; the tests run on macOS or Linux |
| On real hardware | Not run on an iPhone yet; the rules are tested on Linux |
| License | GPL-3.0-or-later |

**Jump to:** [Overview](#-overview) · [Architecture](#-architecture) · [Security](#-security--safety) · [Interfaces](#-interfaces) · [Configuration](#-configuration) · [Quick start](#-quick-start) · [Testing](#-testing) · [Troubleshooting](#-troubleshooting) · [Structure](#-repository-structure) · [Related](#-related-projects)

## 🚦 Project status

Each line is one part of this repository and the light says how far it is today. It is written from what the repository can show (tests, builds, runs), not from what is planned.

🟢 Done and verified · 🟡 Works, with known limits · 🟠 Partly done or not verified yet · 🔴 Not done or not working

| Area | State | What it means here |
|---|---|---|
| Software | 🟠 | The rules of the app are a Swift package (`ArmorCore`); the SwiftUI screens have not been built in Xcode. |
| Tests | 🟡 | 103 unit tests pass with `swift test` on macOS or Linux, and `tools/ios_lint.py` checks the structure, the eight language tables and the contract without a Mac; no test runs on a device. |
| Interface | 🟠 | The SwiftUI screens are written but have not been built in Xcode or run on an iPhone. |
| Hardware | 🔴 | It has not run on an iPhone: the rules are tested on Linux only. |
| Security | 🟠 | The lock of the phone, the session vault and the trust in the certificate are rules tested on Linux; Face ID, the Keychain and the certificate rules have not run on a device. |
| Integration | 🟠 | Live camera and push through Firebase have not been tried; the server link and the parsing are tested against the shared contract. |
| Documentation | 🟢 | Eight languages and the changelog are up to date. |

## 🎯 Overview

* **Sign in with the server's own login:** the addresses of the house (at home and away), user and password; the password creates an HttpOnly session; it is kept only if you tick **Remember me** (in the Keychain of this phone, never backed up). A **viewer** role only looks: every button that changes something is off.
* **Two addresses:** the private one on the home Wi-Fi, the one for away (a dynamic DNS name or the VPN) on mobile data; if one does not answer the other is tried, and the message says what failed.
* **Lock with the phone:** Face ID, Touch ID or the passcode before arming, disarming, silencing a siren, unlocking and the other critical orders (on by default only with Face ID or Touch ID), and, if you turn it on, to open the app. Your administrator can require it, never lower what you chose; a phone with no passcode is never shut out and the locked screen always offers signing in with the password. Optionally (off by default, with a warning) the saved session is readable only while the phone is unlocked.
* **Arm and disarm** after a check of what would be left blind or noisy, with the PIN to disarm; **alarms** to confirm, with a badge; the **alarm panels** (arm away or at home, disarm, silence the siren) and the **history**; **devices** with On / Off and a confirmation for circuits and critical ones.
* **Cameras** through the server (the app never has a camera password): a grid where only the pictures on screen run, a full view with a pad to move the camera and a snapshot, and a stream asked for again with growing waits when it drops.
* **The assistant:** written commands (the keyboard's microphone dictates), with a confirmation bound to you for arming and disarming, behind the lock.
* **Trust in the certificate:** the key of the installation's certificate is remembered the first time or paired with the QR of Studio; if it changes the connection is refused and you are told.
* **Eight languages** (English, Spanish, German, French, Italian, Japanese, Chinese and Portuguese of Portugal), chosen in *More > Language* or following the phone, with a help for every screen.

## 🧩 Role in A.R.M.O.R.

ARMOR-IOS-CONTROL is the iPhone's window on the same [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER) that [ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) and [ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL) use: it reads and orders through it and nothing else, and it speaks the same contract as the Android app.

| Name | How | What for |
|---|---|---|
| ARMOR-SERVER | HTTP `/api/v1`, MJPEG | Everything the app reads and orders; the app talks to nothing else |
| ARMOR-ANDROID-CONTROL | same contract | `ios_lint.py` checks that the app calls only paths the Android client calls |
| ARMOR-STUDIO | QR | Pairs the key of the certificate of the installation |

## 🏛️ Architecture

<p align="center">
  <img src="images/architecture.svg" alt="ARMOR-IOS-CONTROL architecture: who calls it, what it holds and what it depends on" width="100%">
</p>

## 🔒 Security & Safety

| Threat | Defence |
|---|---|
| The password on the phone | Kept only with *Remember me*, in the Keychain of this phone and never backed up; the session is an HttpOnly cookie of the server |
| A critical order with the phone in other hands | Face ID, Touch ID or the passcode before arming, disarming, silencing a siren, unlocking and the other critical orders; the administrator can require it, never lower what you chose; a phone with no passcode is never shut out |
| A changed or forged certificate | The key of the installation's certificate is remembered the first time or paired with the QR of Studio; if it changes the connection is refused and you are told |
| The password sent in clear | Plain HTTP only for a private-network or loopback address (`NSAllowsLocalNetworking`); anything else needs https and the app refuses to send the password otherwise |
| A camera password on the phone | The cameras pass through the server: the app has no camera password and no RTSP address |
| A viewer changes something | The *viewer* role only looks: every button that changes something is off; the server checks it again |
| The assistant arms or disarms by mistake | Written commands only (the keyboard's microphone dictates); arming and disarming need a confirmation bound to you, behind the lock of the phone |

Permission texts (Face ID, local network) exist in all eight languages. Nothing here has run on an iPhone: Face ID, the Keychain and the certificate rules are untested on a device. Read [docs/CLIENT_BOUNDARY.md](docs/CLIENT_BOUNDARY.md) and [SECURITY.md](SECURITY.md).

## 🔌 Interfaces

It is a client: it calls 26 paths of ARMOR-SERVER (`tools/ios_lint.py` counts them and checks that the Android client calls them too), and cuts the MJPEG stream of the cameras with its own parser (`MjpegParser.swift`).

| Part | What it sets |
|---|---|
| Two addresses | The private one on the home Wi-Fi and the one for away (a dynamic DNS name or the VPN) on mobile data; if one does not answer the other is tried, and the message says what failed (`Reach.swift`, `Connector.swift`) |
| Cameras | A grid where only the pictures on screen run, a full view with a pad to move the camera and a snapshot, and a stream asked for again with growing waits when it drops |
| Push | Alarms reach a closed app only through push (`Push.swift`, Firebase), and only when the server has push on and the installation brings its own `GoogleService-Info.plist`; not tried |

## ⚙️ Configuration

| Name | Value | What it sets |
|---|---|---|
| iOS | 16.0+ | Minimum version, set in `project.yml` |
| Xcode / Swift | 15+ / 5.9+ | To build the app / to run the tests |
| `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` | 0.0.1, 1 | The version of the app, from `project.yml` |
| `GoogleService-Info.plist` | for push | The installation's own file, never kept in the repository |

In the app: the two addresses, *Remember me*, the lock of the phone and the language (the eight languages or following the phone) in *More > Language*.

## 🚀 Quick start

**Requirements:** a Mac with Xcode 15+ and iOS 16+ to build the app; Swift 5.9+ (macOS or Linux) for the tests; Python 3.11 for the checks.

```sh
swift test                  # 103 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

The Xcode project is made from `project.yml` with XcodeGen. Choose a signing team, add the app icon and, for push, the installation's `GoogleService-Info.plist` (never kept in the repository). See the [client boundary](docs/CLIENT_BOUNDARY.md).

## 🧪 Testing

```sh
swift test                  # macOS or Linux
python tools/ios_lint.py    # any system, no Mac needed
python -I tools/armor_ci_validate.py
```

| Test file | Tests | What it covers |
|---|---|---|
| `ControllerTests.swift` | 15 | The use cases of the controller |
| `ClientTests.swift` | 14 | The link to the server and its parsing |
| `LockTests.swift` | 12 | The lock of the phone |
| `ModelsTests.swift` | 12 | The models read from the server |
| `ReachTests.swift` | 11 | The choice between the two addresses |
| `SecurityTests.swift` | 8 | The session vault and the trust in the certificate |
| `EndpointTests.swift`, `MjpegTests.swift`, `TranslatorTests.swift` | 7 + 7 + 7 | The address parsing, the MJPEG cutting and the translator |
| `PolicyTests.swift`, `AlarmCodesTests.swift` | 6 + 4 | The alarm policy and the alarm codes |

The 103 tests run with fixtures of a real server. `tools/ios_lint.py` passes without a Mac: 31 Swift files, 241 phrases in 8 languages, 26 server paths. No test runs on a device.

## 🏗️ Build & Release

The Xcode project is generated from `project.yml` with XcodeGen: choose a signing team, add the app icon to `App/Resources/Assets.xcassets/AppIcon.appiconset` and, for push, the installation's `GoogleService-Info.plist`. It has never been built in Xcode.

## 🩺 Troubleshooting

| You see | Because | Do |
|---|---|---|
| The connection is refused and you are told | The key of the installation's certificate changed | Pair again with the QR of Studio if you changed it on purpose |
| Neither address answers | Wrong address, no network, or http to a place outside the home (refused: the password is not sent in clear) | Check both addresses; use https away from home |
| `wrong_pin`, `pin_locked`, `pin_not_set` | The server refuses the disarm PIN; the app shows the code in your language | Type the PIN again or wait for the lock to end; set it in Studio |

## 📂 Repository Structure

<p align="center">
  <img src="images/repository-structure.svg" alt="Repository structure of ARMOR-IOS-CONTROL" width="100%">
</p>

<details>
<summary>Text version of the tree</summary>

```text
ARMOR-IOS-CONTROL/
├── Sources/ArmorCore/                   the rules of the app: a Swift package
├── App/                                 the SwiftUI screens and the parts that need an iPhone
├── Tests/                               103 tests and fixtures of a real server
├── docs/                                the guides of this repository
├── tools/                               the shared CI checks and project tooling
├── .github/                             CI workflow, issue and pull-request templates
├── images/                              banner, icon and the two pictures of this README
├── armor.project.json                   manifest: version, role, maturity, build command
├── CHANGELOG.md                         what changed in each version
├── SECURITY.md SUPPORT.md LICENSE       security policy, support and license
├── CONTRIBUTING.md CODE_OF_CONDUCT.md   how to contribute and the code of conduct
├── Package.swift                        the Swift package: ArmorCore and its tests
├── project.yml                          XcodeGen: the Xcode project is generated from it
└── .gitattributes .gitignore            Git settings
```

</details>

## 🗺️ Roadmap & Known limits

**Known limits today**

* Nothing has run on an iPhone: the SwiftUI screens have not been built in Xcode; Face ID, the Keychain, the certificate rules, the live camera and push through Firebase are untested.
* Only the rules (`ArmorCore`) are tested, and only on Linux.
* The app does not watch in the background: iOS does not let a closed app query the server.

**Next**

* Build the screens in Xcode and run the app on an iPhone against the CM5 test bench.
* Try Face ID, the Keychain, the certificate rules, the live camera and push.

## 🌍 Languages

README and texts exist in English, Spanish, French, Italian, German, Chinese, Japanese and European Portuguese.

## 🔗 Related Projects

**A.R.M.O.R.** (Autonomous Radar & Multimodal Observation Range) is a perimeter-security system made of independent repositories. Each one has its own version, its own tests and its own README; this is the family:

* **[ARMOR-COMMON](https://github.com/JuanenRac/ARMOR-COMMON)** - Message contracts, validators, conformance vectors and generated types
* **[ARMOR-NODE-RADAR](https://github.com/JuanenRac/ARMOR-NODE-RADAR)** - Field-node firmware for ESP32-S3 with three radars and its own web panel
* **[ARMOR-NODE-SOLAR](https://github.com/JuanenRac/ARMOR-NODE-SOLAR)** - Solar inverter and battery protocols and the messages of a gateway node
* **[ARMOR-NODE-ELECTRICAL](https://github.com/JuanenRac/ARMOR-NODE-ELECTRICAL)** - Electrical node: meters, the message of the network's readings and the rules for switching
* **[ARMOR-NODE-ALARM](https://github.com/JuanenRac/ARMOR-NODE-ALARM)** - Alarm node and panel: zones, arming, delays, siren and PIN, with the server or without it
* **[ARMOR-NODE-HMI](https://github.com/JuanenRac/ARMOR-NODE-HMI)** - Touch panel: the state of the system on a wall screen, arming and acknowledging, and the home of the voice assistant
* **[ARMOR-NETWORK](https://github.com/JuanenRac/ARMOR-NETWORK)** - The local network: its devices, the internet and what changes
* **[ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER)** - Central coordinator: telemetry, alarms, devices, solar readings and cameras
* **[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO)** - Web console: cameras, radar, alarms, solar energy and the 2D/3D site designer
* **[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL)** - Android operator client with a live 2D/3D radar
* **ARMOR-IOS-CONTROL** (this repository) - iPhone operator client
* **[ARMOR-SERVER-AI](https://github.com/JuanenRac/ARMOR-SERVER-AI)** - Visual inference policy that explains its decisions and never actuates
* **[ARMOR-VISION](https://github.com/JuanenRac/ARMOR-VISION)** - Camera zones, masks and detection rules for the Jetson Orin NX
* **[ARMOR-VOICE-AI](https://github.com/JuanenRac/ARMOR-VOICE-AI)** - Offline voice intents with a confirmation that cannot be forged
* **[ARMOR-HARDWARE](https://github.com/JuanenRac/ARMOR-HARDWARE)** - Enclosures, electronics and the bench acceptance matrix
* **[ARMOR-DEVOPS](https://github.com/JuanenRac/ARMOR-DEVOPS)** - Deployment, the CM5 test bench, backup and TLS
* **[ARMOR-SIMULATOR](https://github.com/JuanenRac/ARMOR-SIMULATOR)** - Offline telemetry simulator with repeatable faults
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - Detects, installs and updates the ecosystem's own repositories
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - Architecture, security baseline and the capability matrix

## 📚 Documentation

* [Client boundary](docs/CLIENT_BOUNDARY.md): what the client does and never does, and how to build it
* [Capability matrix: what is proven and what is not](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [Project catalogue: versions and how the repositories depend on each other](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [Changelog of this repository](CHANGELOG.md)

## 🤝 Contributing & Community

* Before a pull request run `swift test` and `python tools/ios_lint.py` and `python -I tools/armor_ci_validate.py`: it must pass. See [CONTRIBUTING.md](CONTRIBUTING.md) and the [code of conduct](CODE_OF_CONDUCT.md).
* The README exists in eight languages and is generated from the sources in ARMOR-DOCS: a change to the text is made there.
* A change to a message between components starts in ARMOR-COMMON.
* Do not describe as working on a board what has only been built.
* Report a vulnerability privately: [SECURITY.md](SECURITY.md). Questions, ideas and reports: electrohobby3d@gmail.com ([SUPPORT.md](SUPPORT.md)).

## 👤 AUTHOR

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 LICENSE

GPL-3.0-or-later - see [LICENSE](LICENSE).
