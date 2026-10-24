<p align="center">
  <img src="images/ARMOR_BANNER.svg" alt="ARMOR-IOS-CONTROL banner" width="100%">
</p>

# 📱 ARMOR-IOS-CONTROL

<p align="center">
  <a href="README.md">🇺🇸 English</a> |
  <a href="README_spa.md">🇪🇸 Español</a> |
  <a href="README_fra.md">🇫🇷 Français</a> |
  <a href="README_ita.md">🇮🇹 Italiano</a> |
  🇩🇪 <b>Deutsch</b> |
  <a href="README_zho.md">🇨🇳 简体中文</a> |
  <a href="README_jpn.md">🇯🇵 日本語</a> |
  <a href="README_por.md">🇵🇹 Português</a>
</p>

### iPhone-Bedienclient für ARMOR-SERVER: Status, Scharfschaltung, Alarme, Alarmzentralen, Kameras und der Assistent, in acht Sprachen

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

**Ehrlichkeitsprüfung - was heute läuft:** Die Regeln der App (Serververbindung, Auswertung der Antworten, Adressauswahl, Telefonsperre, Tresor der Sitzung, Vertrauen in das Zertifikat, Alarmrichtlinie, Anwendungsfälle, MJPEG-Zerlegung) sind das Swift-Paket `ArmorCore`, abgedeckt durch 103 Unit-Tests, die mit `swift test` unter macOS oder Linux laufen; `tools/ios_lint.py` prüft Struktur, die acht Sprachtabellen und den Vertrag ohne Mac. **Noch nicht** belegt: Die SwiftUI-Bildschirme und die Teile, die ein iPhone brauchen (Face ID, Schlüsselbund, Zertifikatsregeln, Live-Kamera, Push über Firebase), wurden weder in Xcode gebaut noch auf einem Gerät ausgeführt.

---

## 📋 Auf einen Blick

| | |
|---|---|
| Version | `0.0.1` |
| Reifegrad | Gerüst |
| Tests | 103 (`swift test`) |
| Technik | Swift / SwiftUI |
| Auf echter Hardware | Noch nicht auf einem iPhone ausgeführt; die Regeln werden unter Linux getestet |

## 🚦 Projektstatus

Jede Zeile ist ein Teil dieses Repositorys, und die Ampel sagt, wie weit er heute ist. Sie beruht auf dem, was das Repository zeigen kann (Tests, Builds, Läufe), nicht auf dem, was geplant ist.

🟢 Fertig und überprüft · 🟡 Funktioniert, mit bekannten Grenzen · 🟠 Teilweise fertig oder noch nicht überprüft · 🔴 Nicht gemacht oder funktioniert nicht

| Bereich | Stand | Was das hier bedeutet |
|---|---|---|
| Software | 🟠 | Die Regeln der App sind ein Swift-Paket (`ArmorCore`); die SwiftUI-Bildschirme wurden nicht in Xcode gebaut. |
| Tests | 🟡 | 103 Unit-Tests bestehen mit `swift test` unter macOS oder Linux, und `tools/ios_lint.py` prüft Struktur, die Tabellen der acht Sprachen und den Vertrag ohne Mac; auf einem Gerät läuft kein Test. |
| Oberfläche | 🟠 | Die SwiftUI-Bildschirme sind geschrieben, wurden aber weder in Xcode gebaut noch auf einem iPhone ausgeführt. |
| Hardware | 🔴 | Sie lief nicht auf einem iPhone: Die Regeln sind nur unter Linux getestet. |
| Sicherheit | 🟠 | Die Sperre des Telefons, der Tresor der Sitzung und das Vertrauen ins Zertifikat sind unter Linux getestete Regeln; Face ID, der Schlüsselbund und die Zertifikatsregeln liefen nicht auf einem Gerät. |
| Integration | 🟠 | Live-Kamera und Push über Firebase wurden nicht erprobt; die Serververbindung und das Parsen sind gegen den gemeinsamen Vertrag getestet. |
| Dokumentation | 🟢 | Acht Sprachen und das Änderungsprotokoll sind aktuell. |

## 🎯 Überblick

* **Anmeldung mit dem Login des Servers:** die Adressen des Hauses (zu Hause und unterwegs), Benutzer und Passwort; das Passwort erzeugt eine HttpOnly-Sitzung; es wird nur gespeichert, wenn Sie **Angemeldet bleiben** ankreuzen (im Schlüsselbund dieses Telefons, nie im Backup). Die Rolle **viewer** schaut nur: jede Schaltfläche, die etwas ändert, ist aus.
* **Zwei Adressen:** die private im Heim-WLAN, die für unterwegs (ein dynamischer DNS-Name oder das VPN) mit Mobilfunkdaten; antwortet eine nicht, wird die andere versucht, und die Meldung sagt, was fehlschlägt.
* **Sperre mit dem Telefon:** Face ID, Touch ID oder der Code vor Scharf- und Unscharfschalten, Sirene stummschalten, Entriegeln und den anderen kritischen Befehlen (standardmäßig nur mit Face ID oder Touch ID an) und, wenn Sie es einschalten, zum Öffnen der App. Ihr Administrator kann es verlangen, aber nie unter Ihre Wahl senken; ein Telefon ohne Code wird nie ausgesperrt, und der Sperrbildschirm bietet immer die Anmeldung mit dem Passwort an. Optional (aus, mit Warnung) ist die gespeicherte Sitzung nur bei entsperrtem Telefon lesbar.
* **Scharf- und Unscharfschalten** nach einer Prüfung dessen, was blind oder laut bliebe, mit der PIN zum Unscharfschalten; **Alarme** zum Bestätigen, mit Zähler; die **Alarmzentralen** (scharf abwesend oder zu Hause, unscharf, Sirene stumm) und der **Verlauf**; **Geräte** mit Ein / Aus und Bestätigung für Stromkreise und kritische Geräte.
* **Kameras** über den Server (die App hat nie das Kamerapasswort): ein Raster, in dem nur die sichtbaren Bilder laufen, eine Vollansicht mit Steuerkreuz zum Bewegen der Kamera und Foto, und ein Stream, der bei Abbruch mit wachsenden Wartezeiten neu angefordert wird.
* **Der Assistent:** geschriebene Befehle (das Mikrofon der Tastatur diktiert), mit einer an Sie gebundenen Bestätigung für Scharf- und Unscharfschalten, hinter der Sperre.
* **Vertrauen in das Zertifikat:** Der Schlüssel des Zertifikats der Installation wird beim ersten Mal gemerkt oder mit dem QR-Code von Studio gekoppelt; ändert er sich, wird die Verbindung abgelehnt und Sie werden informiert.
* **Acht Sprachen** (Englisch, Spanisch, Deutsch, Französisch, Italienisch, Japanisch, Chinesisch und Portugiesisch aus Portugal), wählbar unter *Mehr > Sprache* oder dem Telefon folgend, mit einer Hilfe zu jedem Bildschirm.

## 🧩 Rolle in A.R.M.O.R.

ARMOR-IOS-CONTROL ist das Fenster des iPhones zum selben [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER), den auch [ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) und [ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL) nutzen: Es liest und befiehlt nur über ihn und spricht denselben Vertrag wie die Android-App.

## 📂 Struktur des Repositorys

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

## 🛠️ Entwicklungsumgebung

**Voraussetzungen:** ein Mac mit Xcode 15+ und iOS 16+ zum Bauen der App; Swift 5.9+ (macOS oder Linux) für die Tests; Python 3.11 für die Prüfungen

```sh
swift test                  # 103 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

Das Xcode-Projekt wird aus `project.yml` mit XcodeGen erzeugt. Wählen Sie ein Signierteam, fügen Sie das App-Symbol und für Push die `GoogleService-Info.plist` der Installation hinzu (nie im Repository). Siehe die [Client-Grenze](docs/CLIENT_BOUNDARY.md).

## 🔗 Verwandte Projekte

**A.R.M.O.R.** (Autonomous Radar & Multimodal Observation Range) ist ein Perimeter-Sicherheitssystem aus unabhängigen Repositorys. Jedes hat eine eigene Version, eigene Tests und ein eigenes README; hier ist die Familie:

* **[ARMOR-COMMON](https://github.com/JuanenRac/ARMOR-COMMON)** - Nachrichtenverträge, Validierer, Konformitätsvektoren und generierte Typen
* **[ARMOR-NODE-RADAR](https://github.com/JuanenRac/ARMOR-NODE-RADAR)** - Feldknoten-Firmware für ESP32-S3 mit drei Radaren und eigenem Web-Panel
* **[ARMOR-NODE-SOLAR](https://github.com/JuanenRac/ARMOR-NODE-SOLAR)** - Protokolle für Solar-Wechselrichter und -Batterien und die Nachrichten eines Gateway-Knotens
* **[ARMOR-NODE-ELECTRICAL](https://github.com/JuanenRac/ARMOR-NODE-ELECTRICAL)** - Elektroknoten: Zähler, die Nachricht der Netzmesswerte und die Regeln fürs Schalten
* **[ARMOR-NODE-ALARM](https://github.com/JuanenRac/ARMOR-NODE-ALARM)** - Alarmknoten und Alarmzentrale: Zonen, Scharfschalten, Verzögerungen, Sirene und PIN, mit dem Server oder ohne ihn
* **[ARMOR-NODE-HMI](https://github.com/JuanenRac/ARMOR-NODE-HMI)** - Touch-Panel: der Systemzustand auf einem Wandbildschirm, Scharf- und Quittieren sowie das Zuhause des Sprachassistenten
* **[ARMOR-NETWORK](https://github.com/JuanenRac/ARMOR-NETWORK)** - Das lokale Netzwerk: seine Geräte, das Internet und was sich ändert
* **[ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER)** - Zentraler Koordinator: Telemetrie, Alarme, Geräte, Solarmesswerte und Kameras
* **[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO)** - Web-Konsole: Kameras, Radar, Alarme, Solarenergie und 2D/3D-Standortdesigner
* **[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL)** - Android-Bedienclient mit Live-Radar in 2D/3D
* **ARMOR-IOS-CONTROL** (dieses Repository) - iPhone-Bedienclient
* **[ARMOR-SERVER-AI](https://github.com/JuanenRac/ARMOR-SERVER-AI)** - Visuelle Inferenzrichtlinie, die ihre Entscheidungen erklärt und nie handelt
* **[ARMOR-VISION](https://github.com/JuanenRac/ARMOR-VISION)** - Kamerazonen, Masken und Erkennungsregeln für den Jetson Orin NX
* **[ARMOR-VOICE-AI](https://github.com/JuanenRac/ARMOR-VOICE-AI)** - Offline-Sprachabsichten mit einer nicht fälschbaren Bestätigung
* **[ARMOR-HARDWARE](https://github.com/JuanenRac/ARMOR-HARDWARE)** - Gehäuse, Elektronik und die Abnahmematrix am Prüfstand
* **[ARMOR-DEVOPS](https://github.com/JuanenRac/ARMOR-DEVOPS)** - Bereitstellung, CM5-Prüfstand, Backup und TLS
* **[ARMOR-SIMULATOR](https://github.com/JuanenRac/ARMOR-SIMULATOR)** - Offline-Telemetriesimulator mit wiederholbaren Fehlern
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - Erkennt, installiert und aktualisiert die eigenen Repositories des Ökosystems
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - Architektur, Sicherheitsgrundlage und die Fähigkeitsmatrix

## 📚 Dokumentation und Community

Hier gibt es mehr zu lesen:

* [Fähigkeitsmatrix: was belegt ist und was nicht](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [Projektkatalog: Versionen und wie die Repositorys voneinander abhängen](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [Änderungsverlauf dieses Repositorys](CHANGELOG.md)
* [Lizenz (GPL-3.0-or-later)](LICENSE)
* Fragen, Ideen und Meldungen: electrohobby3d@gmail.com

## 👤 AUTOR

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 LIZENZ

GPL-3.0-or-later - siehe [LICENSE](LICENSE).
