<p align="center">
  <img src="images/ARMOR_BANNER.svg" alt="Banner di ARMOR-IOS-CONTROL" width="100%">
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
  <img src="https://img.shields.io/badge/License-GPL%203.0--or--later-blue.svg" alt="GPL 3.0 o successiva">
  <img src="https://img.shields.io/badge/Language-Swift-f05138.svg" alt="Linguaggio">
  <img src="https://img.shields.io/badge/UI-SwiftUI-0a84ff.svg" alt="UI">
  <img src="https://img.shields.io/badge/Languages-8-00E5FF.svg" alt="Lingue">
  <img src="https://img.shields.io/badge/Tests-103%20passing-2ea44f.svg" alt="Test">
  <img src="https://img.shields.io/badge/Version-0.0.1-0f6cbd.svg" alt="Versione">
  <img src="https://img.shields.io/badge/Maturity-scaffolding-FFB020.svg" alt="Maturità">
</p>

---

**Controllo di onestà - cosa funziona oggi:** le regole dell'app (collegamento al server, lettura delle risposte, scelta dell'indirizzo, blocco del telefono, cassaforte della sessione, fiducia nel certificato, politica degli allarmi, casi d'uso, taglio dell'MJPEG) sono il pacchetto Swift `ArmorCore`, coperto da 103 test unitari che girano con `swift test` su macOS o Linux, e `tools/ios_lint.py` controlla la struttura, le otto tabelle delle lingue e il contratto senza Mac. Ciò che **non** è ancora provato: le schermate SwiftUI e le parti che richiedono un iPhone (Face ID, portachiavi, regole del certificato, telecamera dal vivo, push con Firebase) non sono state compilate in Xcode né eseguite su un dispositivo.

---

## 📋 In breve

| | |
|---|---|
| Versione | `0.0.1` |
| Maturità | Impalcatura |
| Ruolo | Client operatore per iPhone di ARMOR-SERVER (famiglia: Clients, padre: ARMOR-SERVER) |
| Tecnologia | Swift 5.9+ / SwiftUI, iOS 16+ |
| Test | 103 (`swift test`) |
| Lingue | 8 (241 frasi per lingua, verificate da `ios_lint.py`) |
| Gira su | Un iPhone con iOS 16+; i test girano su macOS o Linux |
| Su hardware reale | Non ancora eseguito su un iPhone; le regole sono testate su Linux |
| Licenza | GPL-3.0-or-later |

**Vai a:** [Panoramica](#-panoramica) · [Architettura](#-architettura) · [Sicurezza](#-sicurezza-e-protezione) · [Interfacce](#-interfacce) · [Configurazione](#-configurazione) · [Avvio rapido](#-avvio-rapido) · [Test](#-test) · [Problemi](#-risoluzione-dei-problemi) · [Struttura](#-struttura-del-repository) · [Correlati](#-progetti-correlati)

## 🚦 Stato del progetto

Ogni riga è una parte di questo repository e il semaforo dice a che punto è oggi. È scritta in base a ciò che il repository può mostrare (test, compilazioni, esecuzioni), non a ciò che è previsto.

🟢 Fatto e verificato · 🟡 Funziona, con limiti noti · 🟠 Fatto a metà o non ancora verificato · 🔴 Non fatto o non funzionante

| Area | Stato | Cosa significa qui |
|---|---|---|
| Software | 🟠 | Le regole dell'app sono un pacchetto Swift (`ArmorCore`); le schermate SwiftUI non sono state compilate in Xcode. |
| Test | 🟡 | Superano 103 test unitari con `swift test` su macOS o Linux, e `tools/ios_lint.py` controlla la struttura, le tabelle delle otto lingue e il contratto senza un Mac; nessun test gira su un dispositivo. |
| Interfaccia | 🟠 | Le schermate SwiftUI sono scritte ma non sono state compilate in Xcode né eseguite su un iPhone. |
| Hardware | 🔴 | Non ha girato su un iPhone: le regole sono provate solo su Linux. |
| Sicurezza | 🟠 | Il blocco del telefono, il deposito della sessione e la fiducia nel certificato sono regole provate su Linux; Face ID, il portachiavi e le regole del certificato non sono stati eseguiti su un dispositivo. |
| Integrazione | 🟠 | La telecamera dal vivo e il push tramite Firebase non sono stati provati; il collegamento al server e il parsing sono provati contro il contratto condiviso. |
| Documentazione | 🟢 | Otto lingue e il registro delle modifiche sono aggiornati. |

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

| Nome | Come | A cosa serve |
|---|---|---|
| ARMOR-SERVER | HTTP `/api/v1`, MJPEG | Tutto ciò che l'app legge e ordina; non parla con nient'altro |
| ARMOR-ANDROID-CONTROL | stesso contratto | `ios_lint.py` verifica che l'app chiami solo percorsi chiamati dal client Android |
| ARMOR-STUDIO | QR | Associa la chiave del certificato dell'installazione |

## 🏛️ Architettura

<p align="center">
  <img src="images/architecture.svg" alt="Architettura di ARMOR-IOS-CONTROL: chi lo chiama, cosa contiene e da cosa dipende" width="100%">
</p>

## 🔒 Sicurezza e protezione

| Minaccia | Difesa |
|---|---|
| La password sul telefono | Salvata solo con *Ricordami*, nel Keychain di questo telefono e mai nei backup; la sessione è un cookie HttpOnly del server |
| Un ordine critico con il telefono in altre mani | Face ID, Touch ID o il codice prima di inserire, disinserire, silenziare una sirena, sbloccare e gli altri ordini critici; l'amministratore può imporlo, mai abbassare la tua scelta; un telefono senza codice non resta mai escluso |
| Un certificato cambiato o falsificato | La chiave del certificato dell'installazione viene ricordata la prima volta o associata con il QR di Studio; se cambia, la connessione è rifiutata e ne sei avvisato |
| La password inviata in chiaro | HTTP in chiaro solo per un indirizzo di rete privata o loopback (`NSAllowsLocalNetworking`); tutto il resto richiede https, altrimenti l'app rifiuta di inviare la password |
| Una password di telecamera sul telefono | Le telecamere passano dal server: l'app non ha password di telecamera né indirizzo RTSP |
| Un visualizzatore cambia qualcosa | Il ruolo *visualizzatore* guarda soltanto: ogni pulsante che cambia qualcosa è spento; il server lo ricontrolla |
| L'assistente inserisce o disinserisce per errore | Solo comandi scritti (il microfono della tastiera detta); inserire e disinserire richiedono una conferma legata a te, dietro il blocco del telefono |

I testi dei permessi (Face ID, rete locale) esistono in tutte e otto le lingue. Nulla di tutto ciò è girato su un iPhone: Face ID, il Keychain e le regole del certificato non sono testati su un dispositivo. Leggi [docs/CLIENT_BOUNDARY.md](docs/CLIENT_BOUNDARY.md) e [SECURITY.md](SECURITY.md).

## 🔌 Interfacce

È un client: chiama 26 percorsi di ARMOR-SERVER (`tools/ios_lint.py` li conta e verifica che li chiami anche il client Android) e taglia il flusso MJPEG delle telecamere con un parser proprio (`MjpegParser.swift`).

| Parte | Cosa imposta |
|---|---|
| Due indirizzi | Quella privata sul Wi-Fi di casa e quella per fuori (un nome DNS dinamico o la VPN) con i dati mobili; se una non risponde si prova l'altra e il messaggio dice cosa è fallito (`Reach.swift`, `Connector.swift`) |
| Telecamere | Una griglia dove girano solo le immagini a schermo, una vista completa con un pad per muovere la telecamera e un'istantanea, e un flusso richiesto di nuovo con attese crescenti se cade |
| Push | Gli allarmi raggiungono un'app chiusa solo via push (`Push.swift`, Firebase), e solo se il server ha il push attivo e l'installazione porta il proprio `GoogleService-Info.plist`; non provato |

## ⚙️ Configurazione

| Nome | Valore | Cosa imposta |
|---|---|---|
| iOS | 16.0+ | Versione minima, definita in `project.yml` |
| Xcode / Swift | 15+ / 5.9+ | Per compilare l'app / per eseguire i test |
| `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` | 0.0.1, 1 | La versione dell'app, da `project.yml` |
| `GoogleService-Info.plist` | per il push | Il file proprio dell'installazione, mai conservato nel repository |

Nell'app: i due indirizzi, *Ricordami*, il blocco del telefono e la lingua (le otto lingue o seguire il telefono) in *Altro > Lingua*.

## 🚀 Avvio rapido

**Requisiti:** un Mac con Xcode 15+ e iOS 16+ per compilare l'app; Swift 5.9+ (macOS o Linux) per i test; Python 3.11 per le verifiche.

```sh
swift test                  # 103 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

Il progetto Xcode si genera da `project.yml` con XcodeGen. Scegli un team di firma, aggiungi l'icona dell'app e, per il push, il `GoogleService-Info.plist` dell'installazione (mai conservato nel repository). Vedi il [confine del client](docs/CLIENT_BOUNDARY.md).

## 🧪 Test

```sh
swift test                  # macOS or Linux
python tools/ios_lint.py    # any system, no Mac needed
python -I tools/armor_ci_validate.py
```

| File di test | Test | Cosa copre |
|---|---|---|
| `ControllerTests.swift` | 15 | I casi d'uso del controller |
| `ClientTests.swift` | 14 | Il collegamento al server e la sua interpretazione |
| `LockTests.swift` | 12 | Il blocco del telefono |
| `ModelsTests.swift` | 12 | I modelli letti dal server |
| `ReachTests.swift` | 11 | La scelta tra i due indirizzi |
| `SecurityTests.swift` | 8 | Il deposito della sessione e la fiducia nel certificato |
| `EndpointTests.swift`, `MjpegTests.swift`, `TranslatorTests.swift` | 7 + 7 + 7 | La lettura degli indirizzi, il taglio MJPEG e il traduttore |
| `PolicyTests.swift`, `AlarmCodesTests.swift` | 6 + 4 | La politica degli allarmi e i codici di allarme |

I 103 test usano dati di un server reale. `tools/ios_lint.py` passa senza Mac: 31 file Swift, 241 frasi in 8 lingue, 26 percorsi del server. Nessun test gira su un dispositivo.

## 🏗️ Compilazione e rilascio

Il progetto Xcode si genera da `project.yml` con XcodeGen: scegli un team di firma, aggiungi l'icona dell'app a `App/Resources/Assets.xcassets/AppIcon.appiconset` e, per il push, il `GoogleService-Info.plist` dell'installazione. Non è mai stato compilato in Xcode.

## 🩺 Risoluzione dei problemi

| Vedi | Perché | Fai |
|---|---|---|
| La connessione è rifiutata e ne sei avvisato | La chiave del certificato dell'installazione è cambiata | Associa di nuovo con il QR di Studio se l'hai cambiato di proposito |
| Nessuno dei due indirizzi risponde | Indirizzo errato, nessuna rete, o http verso un luogo fuori casa (rifiutato: la password non si invia in chiaro) | Controlla i due indirizzi; usa https fuori casa |
| `wrong_pin`, `pin_locked`, `pin_not_set` | Il server rifiuta il PIN di disinserimento; l'app mostra il codice nella tua lingua | Digita di nuovo il PIN o attendi la fine del blocco; impostalo in Studio |

## 📂 Struttura del repository

<p align="center">
  <img src="images/repository-structure.svg" alt="Struttura del repository di ARMOR-IOS-CONTROL" width="100%">
</p>

<details>
<summary>Versione testuale dell'albero</summary>

```text
ARMOR-IOS-CONTROL/
├── Sources/ArmorCore/                   le regole dell'app: un pacchetto Swift
├── App/                                 le schermate SwiftUI e le parti che richiedono un iPhone
├── Tests/                               103 test e dati di un server reale
├── docs/                                le guide di questo repository
├── tools/                               i controlli CI condivisi e gli strumenti del progetto
├── .github/                             workflow CI e modelli per issue e pull request
├── images/                              banner, icona e le due immagini di questo README
├── armor.project.json                   manifesto: versione, ruolo, maturità, comando di build
├── CHANGELOG.md                         cosa è cambiato in ogni versione
├── SECURITY.md SUPPORT.md LICENSE       politica di sicurezza, supporto e licenza
├── CONTRIBUTING.md CODE_OF_CONDUCT.md   come contribuire e il codice di condotta
├── Package.swift                        il pacchetto Swift: ArmorCore e i suoi test
├── project.yml                          XcodeGen: da qui si genera il progetto Xcode
└── .gitattributes .gitignore            impostazioni di Git
```

</details>

## 🗺️ Roadmap e limiti noti

**Limiti noti oggi**

* Nulla è girato su un iPhone: le schermate SwiftUI non sono state compilate in Xcode; Face ID, il Keychain, le regole del certificato, la telecamera dal vivo e il push via Firebase non sono testati.
* Solo le regole (`ArmorCore`) sono testate, e solo su Linux.
* L'app non sorveglia in background: iOS non lascia che un'app chiusa interroghi il server.

**Prossimi passi**

* Compilare le schermate in Xcode e far girare l'app su un iPhone contro il banco di prova CM5.
* Provare Face ID, il Keychain, le regole del certificato, la telecamera dal vivo e il push.

## 🌍 Lingue

Il README e i testi esistono in inglese, spagnolo, francese, italiano, tedesco, cinese, giapponese e portoghese europeo.

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

## 📚 Documentazione

* [Confini del client](docs/CLIENT_BOUNDARY.md): cosa fa e non fa mai il client, e come compilarlo
* [Matrice delle capacità: cosa è provato e cosa no](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [Catalogo dei progetti: versioni e dipendenze tra i repository](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [Cronologia delle modifiche di questo repository](CHANGELOG.md)

## 🤝 Contribuire e comunità

* Prima di una pull request esegui `swift test` and `python tools/ios_lint.py` and `python -I tools/armor_ci_validate.py`: deve passare. Vedi [CONTRIBUTING.md](CONTRIBUTING.md) e il [codice di condotta](CODE_OF_CONDUCT.md).
* Il README esiste in otto lingue ed è generato dalle sorgenti in ARMOR-DOCS: una modifica al testo si fa lì.
* Una modifica a un messaggio tra componenti parte da ARMOR-COMMON.
* Non descrivere come funzionante su una scheda ciò che è stato solo compilato.
* Segnala una vulnerabilità in privato: [SECURITY.md](SECURITY.md). Domande, idee e segnalazioni: electrohobby3d@gmail.com ([SUPPORT.md](SUPPORT.md)).

## 👤 AUTORE

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 LICENZA

GPL-3.0-or-later - vedi [LICENSE](LICENSE).
