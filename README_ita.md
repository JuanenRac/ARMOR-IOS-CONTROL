<p align="center">
  <img src="images/ARMOR_BANNER.svg" alt="ARMOR-IOS-CONTROL banner" width="100%">
</p>

# 📱 ARMOR-IOS-CONTROL

<p align="center">
  <a href="README.md">🇺🇸 English</a> |
  <a href="README_spa.md">🇪🇸 Español</a> |
  <a href="README_fra.md">🇫🇷 Français</a> |
  🇮🇹 <b>Italiano</b> |
  <a href="README_deu.md">🇩🇪 Deutsch</a> |
  <a href="README_zho.md">🇨🇳 简体中文</a> |
  <a href="README_jpn.md">🇯🇵 日本語</a> |
  <a href="README_por.md">🇵🇹 Português</a>
</p>

### Client operatore per iPhone di ARMOR-SERVER: stato, armamento, allarmi, centrali di allarme, telecamere e assistente, in otto lingue

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

**Controllo di onestà - cosa funziona oggi:** le regole dell'app (collegamento al server, lettura delle risposte, scelta dell'indirizzo, blocco del telefono, cassaforte della sessione, fiducia nel certificato, politica degli allarmi, casi d'uso, taglio dell'MJPEG) sono il pacchetto Swift `ArmorCore`, coperto da 103 test unitari che girano con `swift test` su macOS o Linux, e `tools/ios_lint.py` controlla la struttura, le otto tabelle delle lingue e il contratto senza Mac. Ciò che **non** è ancora provato: le schermate SwiftUI e le parti che richiedono un iPhone (Face ID, portachiavi, regole del certificato, telecamera dal vivo, push con Firebase) non sono state compilate in Xcode né eseguite su un dispositivo.

---

## 📋 In breve

| | |
|---|---|
| Versione | `0.0.1` |
| Maturità | Impalcatura |
| Test | 103 (`swift test`) |
| Tecnologia | Swift / SwiftUI |
| Su hardware reale | Non ancora eseguito su un iPhone; le regole sono testate su Linux |

## 🎯 Panoramica

* **Accedi con il login del server stesso:** gli indirizzi di casa (in casa e fuori), utente e password; la password crea una sessione HttpOnly; viene conservata solo se spunti **Ricordami** (nel portachiavi di questo telefono, mai nel backup). Il ruolo **viewer** guarda soltanto: ogni pulsante che cambia qualcosa è spento.
* **Due indirizzi:** quello privato sul Wi-Fi di casa, quello per fuori (un nome DNS dinamico o la VPN) con i dati mobili; se uno non risponde si prova l'altro e il messaggio dice cosa non va.
* **Blocco con il telefono:** Face ID, Touch ID o il codice prima di armare, disarmare, silenziare una sirena, sbloccare e gli altri ordini critici (attivo di default solo con Face ID o Touch ID) e, se lo attivi, per aprire l'app. Il tuo amministratore può imporlo, mai abbassare ciò che hai scelto; un telefono senza codice non resta mai fuori e la schermata di blocco offre sempre di accedere con la password. Facoltativamente (disattivato, con avviso) la sessione salvata è leggibile solo con il telefono sbloccato.
* **Armare e disarmare** dopo il controllo di ciò che resterebbe cieco o rumoroso, con il PIN per disarmare; **allarmi** da confermare, con contatore; le **centrali di allarme** (armare fuori o in casa, disarmare, silenziare la sirena) e lo **storico**; **dispositivi** con Acceso / Spento e conferma per circuiti e critici.
* **Telecamere** tramite il server (l'app non ha mai la password della telecamera): una griglia in cui girano solo le immagini visibili, una vista completa con croce direzionale per muovere la telecamera e foto, e un flusso richiesto di nuovo con attese crescenti se si interrompe.
* **L'assistente:** comandi scritti (il microfono della tastiera detta), con una conferma legata a te per armare e disarmare, dietro il blocco.
* **Fiducia nel certificato:** la chiave del certificato dell'installazione viene ricordata la prima volta o associata con il QR di Studio; se cambia, la connessione viene rifiutata e ti viene detto.
* **Otto lingue** (inglese, spagnolo, tedesco, francese, italiano, giapponese, cinese e portoghese del Portogallo), scelte in *Altro > Lingua* o seguendo il telefono, con un aiuto per ogni schermata.

## 🧩 Ruolo in A.R.M.O.R.

ARMOR-IOS-CONTROL è la finestra dell'iPhone sullo stesso [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER) che usano [ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) e [ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL): legge e ordina attraverso di esso e nient'altro, e parla lo stesso contratto dell'app Android.

## 📂 Struttura del repository

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

## 🛠️ Ambiente di sviluppo

**Requisiti:** un Mac con Xcode 15+ e iOS 16+ per compilare l'app; Swift 5.9+ (macOS o Linux) per i test; Python 3.11 per i controlli

```sh
swift test                  # 103 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

Il progetto Xcode si genera da `project.yml` con XcodeGen. Scegli un team di firma, aggiungi l'icona dell'app e, per il push, il `GoogleService-Info.plist` dell'installazione (mai conservato nel repository). Vedi il [confine del client](docs/CLIENT_BOUNDARY.md).

## 🔗 Progetti correlati

**A.R.M.O.R.** (Autonomous Radar & Multimodal Observation Range) è un sistema di sicurezza perimetrale fatto di repository indipendenti. Ognuno ha la propria versione, i propri test e il proprio README; ecco la famiglia:

* **[ARMOR-COMMON](https://github.com/JuanenRac/ARMOR-COMMON)** - Contratti dei messaggi, validatori, vettori di conformità e tipi generati
* **[ARMOR-NODE-RADAR](https://github.com/JuanenRac/ARMOR-NODE-RADAR)** - Firmware del nodo di campo per ESP32-S3 con tre radar e un proprio pannello web
* **[ARMOR-NODE-SOLAR](https://github.com/JuanenRac/ARMOR-NODE-SOLAR)** - Protocolli di inverter e batterie solari e messaggi di un nodo gateway
* **[ARMOR-NODE-ELECTRICAL](https://github.com/JuanenRac/ARMOR-NODE-ELECTRICAL)** - Nodo elettrico: contatori, il messaggio delle letture della rete e le regole di manovra
* **[ARMOR-NODE-ALARM](https://github.com/JuanenRac/ARMOR-NODE-ALARM)** - Nodo e centrale d'allarme: zone, inserimento, ritardi, sirena e PIN, con il server o senza
* **[ARMOR-NODE-HMI](https://github.com/JuanenRac/ARMOR-NODE-HMI)** - Pannello touch: lo stato del sistema su uno schermo a parete, attivare e riconoscere gli allarmi, e la casa dell'assistente vocale
* **[ARMOR-NETWORK](https://github.com/JuanenRac/ARMOR-NETWORK)** - La rete locale: i suoi dispositivi, internet e ciò che cambia
* **[ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER)** - Coordinatore centrale: telemetria, allarmi, dispositivi, letture solari e telecamere
* **[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO)** - Console web: telecamere, radar, allarmi, energia solare e progettista del sito 2D/3D
* **[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL)** - Client Android dell'operatore con radar 2D/3D in tempo reale
* **ARMOR-IOS-CONTROL** (questo repository) - Client operatore per iPhone
* **[ARMOR-SERVER-AI](https://github.com/JuanenRac/ARMOR-SERVER-AI)** - Politica di inferenza visiva che spiega le sue decisioni e non agisce mai
* **[ARMOR-VISION](https://github.com/JuanenRac/ARMOR-VISION)** - Zone delle telecamere, maschere e regole di rilevamento per la Jetson Orin NX
* **[ARMOR-VOICE-AI](https://github.com/JuanenRac/ARMOR-VOICE-AI)** - Intenti vocali offline con una conferma impossibile da falsificare
* **[ARMOR-HARDWARE](https://github.com/JuanenRac/ARMOR-HARDWARE)** - Contenitori, elettronica e matrice di accettazione da banco
* **[ARMOR-DEVOPS](https://github.com/JuanenRac/ARMOR-DEVOPS)** - Distribuzione, banco di prova CM5, backup e TLS
* **[ARMOR-SIMULATOR](https://github.com/JuanenRac/ARMOR-SIMULATOR)** - Simulatore di telemetria offline con guasti ripetibili
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - Rileva, installa e aggiorna i repository stessi dell'ecosistema
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - Architettura, base di sicurezza e matrice delle capacità

## 📚 Documentazione e comunità

Dove leggere di più:

* [Matrice delle capacità: cosa è provato e cosa no](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [Catalogo dei progetti: versioni e dipendenze tra i repository](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [Cronologia delle modifiche di questo repository](CHANGELOG.md)
* [Licenza (GPL-3.0-or-later)](LICENSE)
* Domande, idee e segnalazioni: electrohobby3d@gmail.com

## 👤 AUTORE

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 LICENZA

GPL-3.0-or-later - vedi [LICENSE](LICENSE).
