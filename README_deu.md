<p align="center">
  <img src="images/ARMOR_BANNER.svg" alt="ARMOR-IOS-CONTROL-Banner" width="100%">
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
  <img src="https://img.shields.io/badge/License-GPL%203.0--or--later-blue.svg" alt="GPL 3.0 oder neuer">
  <img src="https://img.shields.io/badge/Language-Swift-f05138.svg" alt="Sprache">
  <img src="https://img.shields.io/badge/UI-SwiftUI-0a84ff.svg" alt="UI">
  <img src="https://img.shields.io/badge/Languages-8-00E5FF.svg" alt="Sprachen">
  <img src="https://img.shields.io/badge/Tests-483%20passing-2ea44f.svg" alt="Tests">
  <img src="https://img.shields.io/badge/Version-0.0.5-0f6cbd.svg" alt="Version">
  <img src="https://img.shields.io/badge/Maturity-scaffolding-FFB020.svg" alt="Reifegrad">
</p>

---

**Ehrlichkeitsprüfung - was heute läuft:** Die Regeln der App (Serververbindung, Auswertung der Antworten, Adressauswahl, Telefonsperre, Tresor der Sitzung, Vertrauen in das Zertifikat, Alarmrichtlinie, Anwendungsfälle, MJPEG-Zerlegung) sind das Swift-Paket `ArmorCore`, abgedeckt durch 483 Unit-Tests, die mit `swift test` unter macOS oder Linux laufen; `tools/ios_lint.py` prüft Struktur, die acht Sprachtabellen und den Vertrag ohne Mac. **Noch nicht** belegt: Die SwiftUI-Bildschirme und die Teile, die ein iPhone brauchen (Face ID, Schlüsselbund, Zertifikatsregeln, Live-Kamera, Push über Firebase), wurden weder in Xcode gebaut noch auf einem Gerät ausgeführt.

---

## 📋 Auf einen Blick

| | |
|---|---|
| Version | `0.0.5` |
| Reifegrad | Gerüst |
| Rolle | iPhone-Bedienclient für ARMOR-SERVER (Familie: Clients, übergeordnet: ARMOR-SERVER) |
| Technik | Swift 5.9+ / SwiftUI, iOS 16+ |
| Tests | 483 (`swift test`) |
| Sprachen | 8 (1229 Sätze je Sprache, von `ios_lint.py` geprüft) |
| Läuft auf | Ein iPhone mit iOS 16+; die Tests laufen auf macOS oder Linux |
| Auf echter Hardware | Noch nicht auf einem iPhone ausgeführt; die Regeln werden unter Linux getestet |
| Lizenz | GPL-3.0-or-later |

**Springe zu:** [Überblick](#-überblick) · [Architektur](#-architektur) · [Sicherheit](#-sicherheit-und-schutz) · [Schnittstellen](#-schnittstellen) · [Konfiguration](#-konfiguration) · [Schnellstart](#-schnellstart) · [Tests](#-tests) · [Probleme](#-fehlerbehebung) · [Struktur](#-struktur-des-repositorys) · [Verwandte](#-verwandte-projekte)

## 🚦 Projektstatus

Jede Zeile ist ein Teil dieses Repositorys, und die Ampel sagt, wie weit er heute ist. Sie beruht auf dem, was das Repository zeigen kann (Tests, Builds, Läufe), nicht auf dem, was geplant ist.

🟢 Fertig und überprüft · 🟡 Funktioniert, mit bekannten Grenzen · 🟠 Teilweise fertig oder noch nicht überprüft · 🔴 Nicht gemacht oder funktioniert nicht

| Bereich | Stand | Was das hier bedeutet |
|---|---|---|
| Software | 🟡 | Die Regeln der App sind ein Swift-Paket (`ArmorCore`), und die SwiftUI-App wird von der CI unter macOS für den Simulator gebaut; sie lief nicht auf einem iPhone. |
| Tests | 🟡 | 483 Unit-Tests bestehen mit `swift test` unter macOS oder Linux, und `tools/ios_lint.py` prüft Struktur, die Tabellen der acht Sprachen und den Vertrag ohne Mac; auf einem Gerät läuft kein Test. |
| Oberfläche | 🟠 | Die SwiftUI-Bildschirme werden von der CI unter macOS für den Simulator gebaut, wurden aber nicht auf einem iPhone ausgeführt. |
| Hardware | 🔴 | Sie lief nicht auf einem iPhone: Die Regeln sind nur unter Linux getestet. |
| Sicherheit | 🟠 | Die Sperre des Telefons, der Tresor der Sitzung und das Vertrauen ins Zertifikat sind unter Linux getestete Regeln; Face ID, der Schlüsselbund und die Zertifikatsregeln liefen nicht auf einem Gerät. |
| Integration | 🟠 | Live-Kamera und Push über Firebase wurden nicht erprobt; die Serververbindung und das Parsen sind gegen den gemeinsamen Vertrag getestet. |
| Dokumentation | 🟡 | Acht Sprachen und das Änderungsprotokoll sind aktuell. |

## 🎯 Überblick

* **Anmeldung mit dem Login des Servers:** die Adressen des Hauses (zu Hause und unterwegs), Benutzer und Passwort; das Passwort erzeugt eine HttpOnly-Sitzung; es wird nur gespeichert, wenn Sie **Angemeldet bleiben** ankreuzen (im Schlüsselbund dieses Telefons, nie im Backup). Die Rolle **viewer** schaut nur: jede Schaltfläche, die etwas ändert, ist aus.
* **Zwei Adressen:** die private im Heim-WLAN, die für unterwegs (ein dynamischer DNS-Name oder das VPN) mit Mobilfunkdaten; antwortet eine nicht, wird die andere versucht, und die Meldung sagt, was fehlschlägt.
* **Sperre mit dem Telefon:** Face ID, Touch ID oder der Code vor Scharf- und Unscharfschalten, Sirene stummschalten, Entriegeln und den anderen kritischen Befehlen (standardmäßig nur mit Face ID oder Touch ID an) und, wenn Sie es einschalten, zum Öffnen der App. Ihr Administrator kann es verlangen, aber nie unter Ihre Wahl senken; ein Telefon ohne Code wird nie ausgesperrt, und der Sperrbildschirm bietet immer die Anmeldung mit dem Passwort an. Optional (aus, mit Warnung) ist die gespeicherte Sitzung nur bei entsperrtem Telefon lesbar.
* **Scharf- und Unscharfschalten** nach einer Prüfung dessen, was blind oder laut bliebe, mit der PIN zum Unscharfschalten; **Alarme** zum Bestätigen, mit Zähler; die **Alarmzentralen** (scharf abwesend oder zu Hause, unscharf, Sirene stumm) und der **Verlauf**; **Geräte** mit Ein / Aus und Bestätigung für Stromkreise und kritische Geräte.
* **Das Detail eines Alarms:** wie in der Android-App: die Schaltfläche Details eines Alarms öffnet ein Blatt mit Schweregrad, Quelle, Uhrzeit und Zustand sowie allen Fakten mit ihrer Bezeichnung in der Sprache der App (die Tabelle ist die des Vertrags, gelesen in der Kernbibliothek); ein Fakt, den die Tabelle nicht kennt, wird so angezeigt, wie er kommt.
* **Kameras** über den Server (die App hat nie das Kamerapasswort): ein Raster, in dem nur die sichtbaren Bilder laufen, eine Vollansicht mit Steuerkreuz zum Bewegen der Kamera und Foto, und ein Stream, der bei Abbruch mit wachsenden Wartezeiten neu angefordert wird.
* **Meldungen nach Wahl:** alles stummschalten oder ohne Ton anzeigen; Dringlichkeiten und Arten abschalten (ein kritischer Alarm wird nie ausgeblendet, außer mit dem Schalter, der alles stumm schaltet); eine eigene Tondatei für jede Dringlichkeit und jede Art mit Wiedergabetaste; und die Stimme, die die Alarme spricht (Frau, Mann, Alter, Stil, Tempo, Meldungen niedriger Dringlichkeit) mit Testtaste. Eine Kamera mit zwei Objektiven in einem Bild erscheint als zwei Fenster. Die Meldungen erscheinen auch bei geöffneter App (ein Banner und der Ton der Meldung); was du zum Ausblenden oder Stummschalten einer Meldung gewählt hast, gilt weiterhin zuerst.
* **Der Assistent:** geschriebene Befehle (das Mikrofon der Tastatur diktiert), mit einer an Sie gebundenen Bestätigung für Scharf- und Unscharfschalten, hinter der Sperre.
* **Vertrauen in das Zertifikat:** Der Schlüssel des Zertifikats der Installation wird beim ersten Mal gemerkt oder mit dem QR-Code von Studio gekoppelt; ändert er sich, wird die Verbindung abgelehnt und Sie werden informiert.
* **Acht Sprachen** (Englisch, Spanisch, Deutsch, Französisch, Italienisch, Japanisch, Chinesisch und Portugiesisch aus Portugal), wählbar unter *Mehr > Sprache* oder dem Telefon folgend, mit einer Hilfe zu jedem Bildschirm.
* **Einen Feldknoten über Bluetooth einrichten, und sein Kopplungscode:** Mehr > Einen Knoten einrichten findet die Knoten, die sich melden, meldet sich mit einem Benutzer des Knotens an oder legt seinen Administrator mit dem Einrichtungscode an und stellt Name, WLAN, Adresse, Broker und Bluetooth-Modus ein; danach sucht die App den Knoten erneut und sagt, ob er dem Netz beigetreten ist oder warum nicht. Sie zeigt den QR-Code eines Knotens (sein Name und die Serveradresse, kein Geheimnis) und liest einen mit der Kamera. Sie folgt der Android-App; die Regeln sind getestet, Funk und Kamera wurden nicht auf einem iPhone ausprobiert.
* **Der Zustand der Knoten:** Mehr > Zustand der Knoten (Bediener und Administratoren) zeigt, was jeder Knoten meldet (Laufzeit, Grund des Neustarts, Speicher, Verbindung, letzter Fehler), und die Warnungen des Servers, die Knoten mit Handlungsbedarf zuerst.
* **Steuerung der Knoten (Administratoren):** Mehr > Knotensteuerung startet neu, pausiert, setzt fort, schaltet in Bereitschaft, identifiziert, fordert eine Diagnose an oder schaltet die Wartung ein und aus, für einen Knoten oder alle; heikle Befehle verlangen, den Namen des Knotens erneut einzutippen, und die Zeile jedes Knotens zeigt, wie weit er gekommen ist. Nichts löscht Einstellungen oder Zugangsdaten oder schaltet einen Knoten aus.
* **Der Konfigurator eines Knotens in der App:** Mehr > Knoten einrichten öffnet die eigene Webseite des Knotens (über seine Adresse im Heimnetz oder über den Server von überall), beschränkt auf diesen Knoten. Das Speichern einer Datei von der Seite (der Export der Einstellungen) ist noch nicht übernommen.
* **Die verbundenen Geräte und der Radarplan:** *Alarme > Verbindungen* listet die Geräte und Apps, die der Server gesehen hat; *Mehr > Radar* zeichnet den Standort, wie Studio ihn entworfen hat, in 2D mit den Personen, denen die Radare folgen (die 3D-Ansicht der Android-App ist noch nicht übernommen).
* **Anwesenheit und ein Bild in der Meldung (beides aus, bis Sie es einschalten):** Ein Schalter lässt das Telefon dem Server nur das Wort *zu Hause* oder *unterwegs* mitteilen, wenn es den Kreis der Erinnerung beim Verlassen überquert (der Ort verlässt das Telefon nie; der Server braucht seine Option „Anwesenheit pro Person“); ein weiterer fügt der Meldung einer Kamera, die nicht mehr antwortet, ihr Standbild hinzu, bei Ihrem eigenen Server angefragt und nie über einen Push-Dienst.
* **Das Gerät vom Handy aus aktualisieren (Administratoren):** Mehr > Gerät aktualisieren zeigt, ob Server und Helfer es erlauben (standardmäßig aus: solange der Schalter aus ist, wird nichts angeboten), listet die aktualisierbaren Programme, zeigt eine Vorschau mit installierter und veröffentlichter Version samt einmaligem Plan mit Countdown und wendet ihn an, nachdem Sie den Projektnamen getippt haben, mit Ihrem Identitätsnachweis und dem Einmalcode des Administrators; die Schritte und das Protokoll des Auftrags werden live verfolgt, und jede Ablehnung des Servers wird in einfachen Worten gesagt.
* **Scharfschaltmodi des Servers (Abwesend, Zuhause, Nacht):** Hat der Server die Scharfschaltmodi eingeschaltet (Studio, Konfiguration > Sicherheit), öffnet die Schaltfläche zum Scharfschalten auf dem Statusbildschirm eine Auswahl, um in einem Modus scharf zu schalten, zu wechseln oder unscharf zu schalten; ein Modus ohne Zuweisung verlangt eine Bestätigung, ein Wechsel zu einem Modus mit weniger Schutz verlangt die PIN wie das Unscharfschalten, und der Status zeigt den aktiven Modus. Das Scharfschalten aus dem unscharfen Zustand führt zuerst die Prüfung vor dem Scharfschalten aus, wie ein einfaches Scharfschalten. Bei ausgeschalteten Modi schaltet die App wie bisher scharf und unscharf. Sie folgt der Android-App; der Code und seine Tests sind geschrieben und wurden weder kompiliert noch auf einem iPhone ausprobiert.
* **Solar, Batterien und Stromnetz, für Administratoren und Bediener:** Mehr > Solar zeigt die Summen (Sonne, Verbrauch, Ladezustand, Netz) und jeden Wechselrichter und jede Batterie mit Werten, Zellen, Zählern und Ereignisprotokoll; Mehr > Elektrisch zeigt den Netzeingang, die Stromkreise und die Gleichstromschienen mit den Umschaltern; Mehr > Batteriewartung (nur Administratoren) bietet die einfachen Vorgänge an einer Pylontech-Batterie in zwei Schritten (der Knoten prüft, der Bildschirm zeigt genau, was geschehen wird, und geschrieben wird erst, nachdem die Seriennummer erneut eingegeben wurde). Die Bildschirme fragen alle paar Sekunden erneut, in einem Takt aus einer Konfigurationsdatei. Sie folgt der Android-App; der Code und seine Tests sind geschrieben und wurden weder kompiliert noch auf einem iPhone ausprobiert.
* **Wetter, Netzwerk, Knotensuche, Dienste und Sicherheit:** Mehr > Wetter zeigt das Wetter eines gewählten Ortes (jetzt, der Regen der nächsten Stunde, 48 Stunden, zehn Tage, Luft, Pollen, Sonne und Mond) mit einem Live-Regen- und Wolkenradar; nur die Koordinaten des Ortes verlassen das Telefon, der Server ist nicht beteiligt. Mehr > Netzwerk zeigt das Internet, die Geräte, die Ausfälle und was sich geändert hat; die Bildschirme Solar und Elektrisch enthalten ein Feld, das Knoten im Netzwerk sucht. Mehr > Dienste listet die Programme und Feldknoten auf, laufend oder nicht. Mehr > Sicherheit verwaltet den zweiten Faktor des Kontos, die offenen Sitzungen und wie der Server das Telefon sieht (für Administratoren auch das VPN ins Haus und die dynamische Adresse; der private Schlüssel eines Geräts wird einmal angezeigt, nie gespeichert, und das Kopieren ist aus, solange die Einstellungen es nicht erlauben). Ein Solar-, Batterie- oder Stromalarm öffnet aus seinem Detail den passenden Bildschirm. Sie folgt der Android-App; der Code und seine Tests sind geschrieben und wurden weder kompiliert noch auf einem iPhone ausprobiert.
* **Das ganze System auf dem Statusbildschirm und ein Fenster für Alarme:** Der Statusbildschirm zählt die Knoten aller Arten (Radar, Solar, Elektrisch, Alarmzentrale, Wandpanel), nicht nur die Radarknoten des Live-Stroms, und ein Tippen öffnet ihre Gesundheit; solange ein Alarm auf eine Person wartet, pulsiert ein Banner über allen Bildschirmen außer den Alarmen (rot und schnell bei einem kritischen, gelb bei den übrigen, ruhig, wenn das Telefon auf weniger Bewegung eingestellt ist), nennt den schlimmsten Alarm und wie viele warten und lässt die Alarme öffnen, vom Banner aus bestätigen oder es schließen, bis ein weiterer Alarm eintrifft. Das Telefon teilt dem Server beim Anmelden für Push auch die Sprache der App mit, damit die Meldung darin geschrieben ist. Sie folgt der Android-App; der Code und seine Tests sind geschrieben und wurden nicht auf einem iPhone ausprobiert.
* **Die Kamera aus einer Meldung öffnen, und ein Widget in Vorbereitung:** Eine Meldung zu einer Kamera (eine, die nicht mehr antwortet, oder ein von einer Kamera ausgelöster Alarm) trägt die Aktion "Kamera öffnen"; ein Tippen bringt die App auf den Ort Kameras mit dieser Kamera im Vollbild. Was ein Widget des Home-Bildschirms sagt (scharf, unscharf oder keine Daten), ist im Kern in den acht Sprachen fertig, und sein Quelltext wartet in `docs/widget`, bis ein Mac ihn als Ziel baut; wie die Kachel der Android-App zeigt es nur an und öffnet die App, es schaltet nie scharf oder unscharf. Sie folgt der Android-App; der Code und seine Tests sind geschrieben und wurden nicht auf einem iPhone ausprobiert.
* **Ein vertrauenswürdiges Telefon, aus, bis Sie es einschalten:** Erlaubt der Administrator es in Studio, lässt ein Schalter unter Mehr > Sperre mit dem Telefon das Telefon ein Schlüsselpaar im Secure Enclave erzeugen (es lässt sich nicht exportieren und funktioniert nur bei entsperrtem Telefon), die öffentliche Hälfte beim Server registrieren und die Sitzung durch Signieren einer einmaligen Herausforderung erneuern, statt erneut nach Passwort und Code zu fragen. Ein Telefon, das der Server nicht mehr kennt, vergisst seine Kennung, ein gesperrtes Telefon versucht es später erneut, und das Ausschalten des Schalters oder das Abmelden lässt den Server das Telefon vergessen. Sie folgt der Android-App; die Regeln sind mit einem falschen Server und einem falschen Schlüssel getestet, und das Secure Enclave selbst wurde nicht auf einem iPhone ausprobiert.

## 🧩 Rolle in A.R.M.O.R.

ARMOR-IOS-CONTROL ist das Fenster des iPhones zum selben [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER), den auch [ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) und [ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL) nutzen: Es liest und befiehlt nur über ihn und spricht denselben Vertrag wie die Android-App.

| Name | Wie | Wozu |
|---|---|---|
| ARMOR-SERVER | HTTP `/api/v1`, MJPEG | Alles, was die App liest und anordnet; sie spricht mit nichts anderem |
| ARMOR-ANDROID-CONTROL | gleicher Vertrag | `ios_lint.py` prüft, dass die App nur Pfade aufruft, die auch der Android-Client aufruft |
| ARMOR-STUDIO | QR | Koppelt den Schlüssel des Zertifikats der Installation |

## 🏛️ Architektur

<p align="center">
  <img src="images/architecture.svg" alt="Architektur von ARMOR-IOS-CONTROL: wer es aufruft, was es enthält und wovon es abhängt" width="100%">
</p>

## 🔒 Sicherheit und Schutz

| Bedrohung | Abwehr |
|---|---|
| Das Passwort auf dem Telefon | Nur mit *Angemeldet bleiben* gespeichert, im Keychain dieses Telefons und nie in Backups; die Sitzung ist ein HttpOnly-Cookie des Servers |
| Ein kritischer Befehl mit dem Telefon in fremden Händen | Face ID, Touch ID oder der Code vor Scharfschalten, Unscharfschalten, Sirene stummschalten, Entriegeln und den anderen kritischen Befehlen; der Administrator kann es verlangen, nie senken, was du gewählt hast; ein Telefon ohne Code wird nie ausgesperrt |
| Ein geändertes oder gefälschtes Zertifikat | Der Schlüssel des Installationszertifikats wird beim ersten Mal gemerkt oder mit dem QR von Studio gekoppelt; ändert er sich, wird die Verbindung verweigert und du wirst benachrichtigt |
| Das Passwort im Klartext gesendet | Klartext-HTTP nur für eine Adresse im privaten Netz oder Loopback (`NSAllowsLocalNetworking`); alles andere braucht https, sonst weigert sich die App, das Passwort zu senden |
| Ein Kamerapasswort auf dem Telefon | Die Kameras laufen über den Server: Die App hat kein Kamerapasswort und keine RTSP-Adresse |
| Ein Betrachter ändert etwas | Die Rolle *Betrachter* schaut nur: Jede Schaltfläche, die etwas ändert, ist aus; der Server prüft es erneut |
| Der Assistent schaltet versehentlich scharf oder unscharf | Nur geschriebene Befehle (das Mikrofon der Tastatur diktiert); Scharf- und Unscharfschalten brauchen eine an dich gebundene Bestätigung, hinter der Telefonsperre |

Die Berechtigungstexte (Face ID, lokales Netzwerk) gibt es in allen acht Sprachen. Nichts davon lief auf einem iPhone: Face ID, der Keychain und die Zertifikatsregeln sind nicht auf einem Gerät getestet. Lies [docs/CLIENT_BOUNDARY.md](docs/CLIENT_BOUNDARY.md) und [SECURITY.md](SECURITY.md).

## 🔌 Schnittstellen

Er ist ein Client: Er ruft 70 Pfade von ARMOR-SERVER auf (`tools/ios_lint.py` zählt sie und prüft, dass auch der Android-Client sie aufruft) und zerlegt den MJPEG-Strom der Kameras mit eigenem Parser (`MjpegParser.swift`).

| Teil | Was sie festlegt |
|---|---|
| Zwei Adressen | Die private im Heim-WLAN und die für unterwegs (ein dynamischer DNS-Name oder das VPN) im Mobilfunk; antwortet eine nicht, wird die andere versucht, und die Meldung sagt, was fehlschlug (`Reach.swift`, `Connector.swift`) |
| Kameras | Ein Raster, in dem nur die sichtbaren Bilder laufen, eine Vollansicht mit Steuerkreuz und Schnappschuss, und ein Strom, der bei Abbruch mit wachsenden Wartezeiten neu angefordert wird |
| Push | Alarme erreichen eine geschlossene App nur per Push (`Push.swift`, Firebase), und nur wenn der Server Push aktiviert hat und die Installation ihre eigene `GoogleService-Info.plist` mitbringt; nicht erprobt |

## ⚙️ Konfiguration

| Name | Wert | Was sie festlegt |
|---|---|---|
| iOS | 16.0+ | Mindestversion, in `project.yml` festgelegt |
| Xcode / Swift | 15+ / 5.9+ | Zum Bauen der App / zum Ausführen der Tests |
| `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` | 0.0.1, 1 | Die Version der App, aus `project.yml` |
| `GoogleService-Info.plist` | für Push | Die eigene Datei der Installation, nie im Repository |

In der App: die zwei Adressen, *Angemeldet bleiben*, die Telefonsperre und die Sprache (die acht Sprachen oder dem Telefon folgen) unter *Mehr > Sprache*.

## 🚀 Schnellstart

**Voraussetzungen:** ein Mac mit Xcode 15+ und iOS 16+ zum Bauen der App; Swift 5.9+ (macOS oder Linux) für die Tests; Python 3.11 für die Prüfungen.

```sh
swift test                  # 483 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

Das Xcode-Projekt wird aus `project.yml` mit XcodeGen erzeugt. Wählen Sie ein Signierteam, fügen Sie das App-Symbol und für Push die `GoogleService-Info.plist` der Installation hinzu (nie im Repository). Siehe die [Client-Grenze](docs/CLIENT_BOUNDARY.md).

## 🧪 Tests

```sh
swift test                  # macOS or Linux
python tools/ios_lint.py    # any system, no Mac needed
python -I tools/armor_ci_validate.py
```

| Testdatei | Tests | Was sie abdeckt |
|---|---|---|
| `ControllerTests.swift` | 15 | Die Anwendungsfälle des Controllers |
| `ClientTests.swift` | 15 | Die Verbindung zum Server und ihre Auswertung |
| `LockTests.swift` | 12 | Die Telefonsperre |
| `ModelsTests.swift` | 12 | Die vom Server gelesenen Modelle |
| `ReachTests.swift` | 11 | Die Wahl zwischen den zwei Adressen |
| `SecurityTests.swift` | 8 | Der Sitzungstresor und das Zertifikatsvertrauen |
| `EndpointTests.swift`, `MjpegTests.swift`, `TranslatorTests.swift` | 7 + 10 + 7 | Die Adressauswertung, das MJPEG-Zerlegen und der Übersetzer |
| `ResponseLimitTests.swift` | 2 | Die längste Antwort, die die App von einem Server annimmt |
| `OpenCameraTests.swift`, `TrustedPhoneTests.swift`, `AlarmBannerTests.swift` | 8 + 18 + 10 | Die Kameraaktion einer Meldung, das vertrauenswürdige Telefon (seine Regeln, mit falschem Server und falschem Schlüssel) und das Alarmfenster |
| `ElevationFormTests.swift`, `QrImageTests.swift` | 3 + 5 | Das Blatt für den erneuten Identitätsnachweis und der Kopplungs-QR-Code, als Bild gezeichnet und gelesen (die 5 des QR brauchen einen Mac) |
| `NodeBleTests.swift`, `NodeHealthTests.swift` | 17 + 5 | Der Bluetooth-Kanal eines Knotens (Rahmen, Anfragen, Einrichtungscode, Einstellungen, SHA-256) und der Zustand der Knoten |
| `NodeControlTests.swift`, `ConnectionsTests.swift`, `NodePanelTests.swift`, `SiteDesignTests.swift` | 8 + 2 + 6 + 11 | Die Steuerung der Knoten, die Verbindungen, die Adresse der Seite eines Knotens und der Radarplan |
| `PolicyTests.swift`, `AlarmCodesTests.swift`, `AlarmFactsTests.swift` | 6 + 4 + 7 | Die Alarmrichtlinie und die Alarmcodes |
| `SolarTests.swift`, `BatteryTests.swift`, `ElectricalTests.swift`, `ScreenPollingTests.swift`, `EquipmentClientTests.swift`, `AlarmRouteTests.swift`, `NetworkTests.swift`, `WeatherTests.swift`, `ServicesSecurityTests.swift` | 14 + 10 + 5 + 3 + 10 + 2 + 9 + 11 + 8 | Solar, Batterien, Stromnetz und die Aufrufe des Clients |

Die 483 Tests laufen mit Daten eines echten Servers. `tools/ios_lint.py` besteht ohne Mac: 108 Swift-Dateien, 1229 Sätze in 8 Sprachen, 70 Serverpfade. Kein Test läuft auf einem Gerät.

## 🏗️ Build und Veröffentlichung

Das Xcode-Projekt wird aus `project.yml` mit XcodeGen erzeugt: Wähle ein Signing-Team, füge das App-Symbol zu `App/Resources/Assets.xcassets/AppIcon.appiconset` hinzu und für Push die `GoogleService-Info.plist` der Installation. Es wurde nie in Xcode gebaut.

## 🩺 Fehlerbehebung

| Sie sehen | Weil | Tun Sie |
|---|---|---|
| Die Verbindung wird verweigert und du wirst benachrichtigt | Der Schlüssel des Installationszertifikats hat sich geändert | Koppele erneut mit dem QR von Studio, wenn du es absichtlich geändert hast |
| Keine der beiden Adressen antwortet | Falsche Adresse, kein Netz oder http zu einem Ziel außerhalb des Hauses (abgelehnt: das Passwort wird nicht im Klartext gesendet) | Prüfe beide Adressen; nutze unterwegs https |
| `wrong_pin`, `pin_locked`, `pin_not_set` | Der Server lehnt die Entschärfungs-PIN ab; die App zeigt den Code in deiner Sprache | Gib die PIN erneut ein oder warte das Ende der Sperre ab; lege sie in Studio fest |

## 📂 Struktur des Repositorys

<p align="center">
  <img src="images/repository-structure.svg" alt="Repository-Struktur von ARMOR-IOS-CONTROL" width="100%">
</p>

<details>
<summary>Textversion des Baums</summary>

```text
ARMOR-IOS-CONTROL/
├── Sources/ArmorCore/                   die Regeln der App: ein Swift-Paket
├── App/                                 die SwiftUI-Bildschirme und die Teile, die ein iPhone brauchen
├── Tests/                               483 Tests und Daten eines echten Servers
├── docs/                                die Anleitungen dieses Repositorys
├── tools/                               die gemeinsamen CI-Prüfungen und Projektwerkzeuge
├── .github/                             CI-Workflow sowie Vorlagen für Issues und Pull Requests
├── images/                              Banner, Symbol und die zwei Bilder dieses READMEs
├── Radar/                               die Radarseite des Wetterbildschirms
├── armor.project.json                   Manifest: Version, Rolle, Reifegrad, Build-Befehl
├── CHANGELOG.md                         was sich in jeder Version geändert hat
├── SECURITY.md SUPPORT.md LICENSE       Sicherheitsrichtlinie, Support und Lizenz
├── CONTRIBUTING.md CODE_OF_CONDUCT.md   Mitwirkung und Verhaltenskodex
├── Package.swift                        das Swift-Paket: ArmorCore und seine Tests
├── project.yml                          XcodeGen: daraus wird das Xcode-Projekt erzeugt
└── .gitattributes .gitignore            Git-Einstellungen
```

</details>

## 🗺️ Roadmap und bekannte Grenzen

**Bekannte Grenzen heute**

* Nichts lief auf einem iPhone: Die SwiftUI-Bildschirme wurden nie in Xcode gebaut; Face ID, der Keychain, die Zertifikatsregeln, die Live-Kamera, die Töne der Meldungen, die Stimme und Push über Firebase sind ungetestet.
* Nur die Regeln (`ArmorCore`) sind getestet, und nur unter Linux.
* Die App überwacht nicht im Hintergrund: iOS lässt eine geschlossene App den Server nicht abfragen.

**Als Nächstes**

* Die Bildschirme in Xcode bauen und die App auf einem iPhone gegen den CM5-Prüfstand ausführen.
* Face ID, den Keychain, die Zertifikatsregeln, die Live-Kamera und Push ausprobieren.

## 🌍 Sprachen

README und Texte gibt es auf Englisch, Spanisch, Französisch, Italienisch, Deutsch, Chinesisch, Japanisch und europäischem Portugiesisch.

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
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - Erkennt, installiert und aktualisiert die eigenen Repositorys des Ökosystems
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - Architektur, Sicherheitsgrundlage und die Fähigkeitsmatrix

## 📚 Dokumentation

* [Client-Grenze](docs/CLIENT_BOUNDARY.md): was der Client tut und nie tut, und wie man ihn baut
* [Fähigkeitsmatrix: was belegt ist und was nicht](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [Projektkatalog: Versionen und wie die Repositorys voneinander abhängen](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [Änderungsverlauf dieses Repositorys](CHANGELOG.md)

## 🤝 Mitwirken und Community

* Führe vor einem Pull Request `swift test` and `python tools/ios_lint.py` and `python -I tools/armor_ci_validate.py` aus: Es muss bestehen. Siehe [CONTRIBUTING.md](CONTRIBUTING.md) und den [Verhaltenskodex](CODE_OF_CONDUCT.md).
* Das README gibt es in acht Sprachen, und es wird aus den Quellen in ARMOR-DOCS erzeugt: Eine Textänderung erfolgt dort.
* Eine Änderung an einer Nachricht zwischen Komponenten beginnt in ARMOR-COMMON.
* Beschreibe nichts als auf einer Platine funktionierend, was nur gebaut wurde.
* Melde eine Schwachstelle privat: [SECURITY.md](SECURITY.md). Fragen, Ideen und Meldungen: electrohobby3d@gmail.com ([SUPPORT.md](SUPPORT.md)).

## 👤 AUTOR

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 LIZENZ

GPL-3.0-or-later - siehe [LICENSE](LICENSE).
