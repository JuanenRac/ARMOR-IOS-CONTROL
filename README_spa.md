<p align="center">
  <img src="images/ARMOR_BANNER.svg" alt="Banner de ARMOR-IOS-CONTROL" width="100%">
</p>

# 📱 ARMOR-IOS-CONTROL

<p align="center">
  <a href="README.md">🇺🇸 English</a> |
  🇪🇸 <b>Español</b> |
  <a href="README_fra.md">🇫🇷 Français</a> |
  <a href="README_ita.md">🇮🇹 Italiano</a> |
  <a href="README_deu.md">🇩🇪 Deutsch</a> |
  <a href="README_zho.md">🇨🇳 简体中文</a> |
  <a href="README_jpn.md">🇯🇵 日本語</a> |
  <a href="README_por.md">🇵🇹 Português</a>
</p>

### Cliente de operador para iPhone de ARMOR-SERVER: estado, armado, alarmas, centrales de alarma, cámaras y el asistente, en ocho idiomas

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL%203.0--or--later-blue.svg" alt="GPL 3.0 o posterior">
  <img src="https://img.shields.io/badge/Language-Swift-f05138.svg" alt="Lenguaje">
  <img src="https://img.shields.io/badge/UI-SwiftUI-0a84ff.svg" alt="UI">
  <img src="https://img.shields.io/badge/Languages-8-00E5FF.svg" alt="Idiomas">
  <img src="https://img.shields.io/badge/Tests-159%20passing-2ea44f.svg" alt="Pruebas">
  <img src="https://img.shields.io/badge/Version-0.0.1-0f6cbd.svg" alt="Versión">
  <img src="https://img.shields.io/badge/Maturity-scaffolding-FFB020.svg" alt="Madurez">
</p>

---

**Comprobación de honestidad - qué funciona hoy:** las reglas de la app (enlace con el servidor, lectura de las respuestas, elección de dirección, bloqueo del teléfono, caja de la sesión, confianza en el certificado, política de alarmas, casos de uso, corte del MJPEG) son el paquete Swift `ArmorCore`, cubierto por 159 pruebas unitarias que se ejecutan con `swift test` en macOS o Linux, y `tools/ios_lint.py` comprueba la estructura, las ocho tablas de idiomas y el contrato sin Mac. Lo que **no** está demostrado todavía: las pantallas SwiftUI y las partes que necesitan un iPhone (Face ID, llavero, reglas de certificado, cámara en vivo, push con Firebase) no se han compilado en Xcode ni ejecutado en un dispositivo.

---

## 📋 De un vistazo

| | |
|---|---|
| Versión | `0.0.1` |
| Madurez | Andamiaje |
| Función | Cliente de operador para iPhone de ARMOR-SERVER (familia: Clients, padre: ARMOR-SERVER) |
| Tecnología | Swift 5.9+ / SwiftUI, iOS 16+ |
| Pruebas | 159 (`swift test`) |
| Idiomas | 8 (241 frases por idioma, comprobadas por `ios_lint.py`) |
| Funciona en | Un iPhone con iOS 16+; las pruebas corren en macOS o Linux |
| En hardware real | Aún no se ha ejecutado en un iPhone; las reglas se prueban en Linux |
| Licencia | GPL-3.0-or-later |

**Ir a:** [Resumen](#-resumen) · [Arquitectura](#-arquitectura) · [Seguridad](#-seguridad-y-protección) · [Interfaces](#-interfaces) · [Configuración](#-configuración) · [Inicio rápido](#-inicio-rápido) · [Pruebas](#-pruebas) · [Problemas](#-resolución-de-problemas) · [Estructura](#-estructura-del-repositorio) · [Relacionados](#-proyectos-relacionados)

## 🚦 Estado del proyecto

Cada línea es una parte de este repositorio y la luz dice hasta dónde llega hoy. Está escrito con lo que el repositorio puede demostrar (pruebas, compilaciones, ejecuciones), no con lo que está planeado.

🟢 Hecho y verificado · 🟡 Funciona, con límites conocidos · 🟠 Parcial o sin verificar todavía · 🔴 No hecho o no funciona

| Área | Estado | Qué significa aquí |
|---|---|---|
| Software | 🟠 | Las reglas de la app son un paquete Swift (`ArmorCore`); las pantallas SwiftUI no se han compilado en Xcode. |
| Pruebas | 🟡 | Pasan 159 pruebas unitarias con `swift test` en macOS o Linux, y `tools/ios_lint.py` comprueba la estructura, las tablas de los ocho idiomas y el contrato sin un Mac; ninguna prueba se ejecuta en un dispositivo. |
| Interfaz | 🟠 | Las pantallas SwiftUI están escritas pero no se han compilado en Xcode ni ejecutado en un iPhone. |
| Hardware | 🔴 | No ha funcionado en un iPhone: las reglas solo se prueban en Linux. |
| Seguridad | 🟠 | El bloqueo del teléfono, la caja de la sesión y la confianza en el certificado son reglas probadas en Linux; Face ID, el llavero y las reglas del certificado no se han ejecutado en un dispositivo. |
| Integración | 🟠 | La cámara en vivo y el push mediante Firebase no se han probado; el enlace con el servidor y el análisis se prueban contra el contrato compartido. |
| Documentación | 🟡 | Ocho idiomas y el historial de cambios están al día. |

## 🎯 Resumen

* **Inicia sesión con el acceso del propio servidor:** las direcciones de la casa (en casa y fuera), usuario y contraseña; la contraseña crea una sesión HttpOnly; solo se guarda si marcas **Recordarme** (en el llavero de este teléfono, sin copia de seguridad). El rol **viewer** solo mira: todo botón que cambia algo queda apagado.
* **Dos direcciones:** la privada en la wifi de casa y la de fuera (un nombre DNS dinámico o la VPN) con datos móviles; si una no responde se prueba la otra y el mensaje dice qué falla.
* **Bloqueo con el teléfono:** Face ID, Touch ID o el código antes de armar, desarmar, silenciar una sirena, desbloquear y las demás órdenes críticas (activado por defecto solo con Face ID o Touch ID) y, si lo activas, para abrir la app. Tu administrador puede exigirlo, nunca bajar lo que elegiste; un teléfono sin código nunca se queda fuera y la pantalla de bloqueo siempre ofrece entrar con la contraseña. Opcionalmente (desactivado, con aviso) la sesión guardada solo se lee con el teléfono desbloqueado.
* **Armar y desarmar** tras comprobar lo que quedaría ciego o ruidoso, con el PIN para desarmar; **alarmas** que confirmar, con contador; las **centrales de alarma** (armar fuera o en casa, desarmar, silenciar la sirena) y el **historial**; **dispositivos** con Encender / Apagar y confirmación para circuitos y críticos.
* **Cámaras** a través del servidor (la app nunca tiene la contraseña de la cámara): una cuadrícula donde solo corren las imágenes visibles, una vista completa con cruceta para mover la cámara y foto, y un flujo que se pide de nuevo con esperas crecientes si se corta.
* **Avisos a tu medida:** silenciar todo o mostrarlo sin sonido; apagar gravedades y tipos (una alarma crítica nunca se oculta, salvo con el interruptor que silencia todo); un archivo de sonido propio para cada gravedad y cada tipo, con botón de reproducir; y la voz que dice las alarmas (mujer, hombre, edad, estilo, velocidad, avisos de gravedad baja), con botón de prueba. Una cámara con dos objetivos en una imagen se muestra como dos ventanas. Los avisos también se muestran con la app abierta (un banner y el sonido del aviso); lo que elegiste sobre ocultar o silenciar un aviso sigue mandando.
* **El asistente:** órdenes escritas (el micrófono del teclado dicta), con una confirmación ligada a ti para armar y desarmar, detrás del bloqueo.
* **Confianza en el certificado:** la clave del certificado de la instalación se recuerda la primera vez o se empareja con el QR de Studio; si cambia, la conexión se rechaza y se te avisa.
* **Ocho idiomas** (inglés, español, alemán, francés, italiano, japonés, chino y portugués de Portugal), a elegir en *Más > Idioma* o siguiendo al teléfono, con ayuda para cada pantalla.
* **Modos de armado del servidor (Fuera, En casa, Noche):** mientras el servidor tiene los modos de armado activados (Studio, Configuración > Seguridad), el botón de armar de la pantalla de estado abre un selector para armar en un modo, cambiar de uno a otro o desarmar; un modo sin nada asignado pide confirmación, un cambio a un modo que defiende menos pide el PIN como desarmar, y el estado muestra el modo en vigor. Con los modos apagados la app arma y desarma como antes. Sigue a la app de Android; el código y sus pruebas están escritos y no se compilaron ni se probaron en un iPhone.

## 🧩 Papel en A.R.M.O.R.

ARMOR-IOS-CONTROL es la ventana del iPhone al mismo [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER) que usan [ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) y [ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL): lee y ordena a través de él y nada más, y habla el mismo contrato que la app de Android.

| Nombre | Cómo | Para qué |
|---|---|---|
| ARMOR-SERVER | HTTP `/api/v1`, MJPEG | Todo lo que la app lee y ordena; no habla con nada más |
| ARMOR-ANDROID-CONTROL | mismo contrato | `ios_lint.py` comprueba que la app solo llama a rutas que llama el cliente Android |
| ARMOR-STUDIO | QR | Empareja la clave del certificado de la instalación |

## 🏛️ Arquitectura

<p align="center">
  <img src="images/architecture.svg" alt="Arquitectura de ARMOR-IOS-CONTROL: quién lo llama, qué contiene y de qué depende" width="100%">
</p>

## 🔒 Seguridad y protección

| Amenaza | Defensa |
|---|---|
| La contraseña en el teléfono | Solo se guarda con *Recordarme*, en el Keychain de este teléfono y nunca en copias de seguridad; la sesión es una cookie HttpOnly del servidor |
| Una orden crítica con el teléfono en otras manos | Face ID, Touch ID o el código antes de armar, desarmar, silenciar una sirena, desbloquear y otras órdenes críticas; el administrador puede exigirlo, nunca bajar lo que elegiste; un teléfono sin código nunca se queda fuera |
| Un certificado cambiado o falsificado | Se recuerda la clave del certificado de la instalación la primera vez o se empareja con el QR de Studio; si cambia se rechaza la conexión y se te avisa |
| La contraseña enviada en claro | HTTP plano solo para una dirección de red privada o loopback (`NSAllowsLocalNetworking`); lo demás exige https y la app se niega a enviar la contraseña de otro modo |
| Una contraseña de cámara en el teléfono | Las cámaras pasan por el servidor: la app no tiene contraseña de cámara ni dirección RTSP |
| Un visor cambia algo | El rol *visor* solo mira: todos los botones que cambian algo están apagados; el servidor lo vuelve a comprobar |
| El asistente arma o desarma por error | Solo órdenes escritas (el micrófono del teclado dicta); armar y desarmar exigen una confirmación atada a ti, tras el bloqueo del teléfono |

Los textos de permisos (Face ID, red local) existen en los ocho idiomas. Nada de esto ha corrido en un iPhone: Face ID, el Keychain y las reglas de certificado no se han probado en un dispositivo. Lee [docs/CLIENT_BOUNDARY.md](docs/CLIENT_BOUNDARY.md) y [SECURITY.md](SECURITY.md).

## 🔌 Interfaces

Es un cliente: llama a 26 rutas de ARMOR-SERVER (`tools/ios_lint.py` las cuenta y comprueba que el cliente Android también las llama) y corta el flujo MJPEG de las cámaras con su propio intérprete (`MjpegParser.swift`).

| Parte | Qué define |
|---|---|
| Dos direcciones | La privada en el Wi-Fi de casa y la de fuera (un nombre DNS dinámico o la VPN) con datos móviles; si una no responde se prueba la otra y el mensaje dice qué falló (`Reach.swift`, `Connector.swift`) |
| Cámaras | Una rejilla donde solo corren las imágenes visibles, una vista completa con mando para mover la cámara y una instantánea, y un flujo que se pide de nuevo con esperas crecientes si se corta |
| Push | Las alarmas llegan a una app cerrada solo por push (`Push.swift`, Firebase) y solo si el servidor tiene push activado y la instalación aporta su propio `GoogleService-Info.plist`; sin probar |

## ⚙️ Configuración

| Nombre | Valor | Qué define |
|---|---|---|
| iOS | 16.0+ | Versión mínima, definida en `project.yml` |
| Xcode / Swift | 15+ / 5.9+ | Para compilar la app / para ejecutar las pruebas |
| `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` | 0.0.1, 1 | La versión de la app, de `project.yml` |
| `GoogleService-Info.plist` | para push | El fichero propio de la instalación, nunca guardado en el repositorio |

En la app: las dos direcciones, *Recordarme*, el bloqueo del teléfono y el idioma (los ocho o seguir al teléfono) en *Más > Idioma*.

## 🚀 Inicio rápido

**Requisitos:** un Mac con Xcode 15+ e iOS 16+ para compilar la app; Swift 5.9+ (macOS o Linux) para las pruebas; Python 3.11 para las comprobaciones.

```sh
swift test                  # 159 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

El proyecto de Xcode se genera desde `project.yml` con XcodeGen. Elige un equipo de firma, añade el icono de la app y, para el push, el `GoogleService-Info.plist` de la instalación (nunca se guarda en el repositorio). Consulta el [límite del cliente](docs/CLIENT_BOUNDARY.md).

## 🧪 Pruebas

```sh
swift test                  # macOS or Linux
python tools/ios_lint.py    # any system, no Mac needed
python -I tools/armor_ci_validate.py
```

| Fichero de pruebas | Pruebas | Qué cubre |
|---|---|---|
| `ControllerTests.swift` | 15 | Los casos de uso del controlador |
| `ClientTests.swift` | 14 | El enlace con el servidor y su interpretación |
| `LockTests.swift` | 12 | El bloqueo del teléfono |
| `ModelsTests.swift` | 12 | Los modelos leídos del servidor |
| `ReachTests.swift` | 11 | La elección entre las dos direcciones |
| `SecurityTests.swift` | 8 | El almacén de sesión y la confianza en el certificado |
| `EndpointTests.swift`, `MjpegTests.swift`, `TranslatorTests.swift` | 7 + 7 + 7 | La lectura de direcciones, el corte MJPEG y el traductor |
| `PolicyTests.swift`, `AlarmCodesTests.swift` | 6 + 4 | La política de alarmas y los códigos de alarma |

Las 159 pruebas usan datos de un servidor real. `tools/ios_lint.py` pasa sin Mac: 31 ficheros Swift, 241 frases en 8 idiomas, 26 rutas del servidor. Ninguna prueba corre en un dispositivo.

## 🏗️ Compilación y publicación

El proyecto de Xcode se genera desde `project.yml` con XcodeGen: elige un equipo de firma, añade el icono de la app a `App/Resources/Assets.xcassets/AppIcon.appiconset` y, para push, el `GoogleService-Info.plist` de la instalación. Nunca se ha compilado en Xcode.

## 🩺 Resolución de problemas

| Ves | Porque | Haz |
|---|---|---|
| Se rechaza la conexión y se te avisa | Cambió la clave del certificado de la instalación | Vuelve a emparejar con el QR de Studio si lo cambiaste a propósito |
| Ninguna de las dos direcciones responde | Dirección errónea, sin red, o http a un lugar fuera de casa (rechazado: la contraseña no se envía en claro) | Revisa las dos direcciones; usa https fuera de casa |
| `wrong_pin`, `pin_locked`, `pin_not_set` | El servidor rechaza el PIN de desarmado; la app muestra el código en tu idioma | Escribe el PIN de nuevo o espera a que acabe el bloqueo; defínelo en Studio |

## 📂 Estructura del repositorio

<p align="center">
  <img src="images/repository-structure.svg" alt="Estructura del repositorio de ARMOR-IOS-CONTROL" width="100%">
</p>

<details>
<summary>Versión en texto del árbol</summary>

```text
ARMOR-IOS-CONTROL/
├── Sources/ArmorCore/                   las reglas de la app: un paquete Swift
├── App/                                 las pantallas SwiftUI y las partes que necesitan un iPhone
├── Tests/                               159 pruebas y datos de un servidor real
├── docs/                                las guías de este repositorio
├── tools/                               las comprobaciones de CI compartidas y las herramientas del proyecto
├── .github/                             flujo de CI y plantillas de issues y pull requests
├── images/                              banner, icono y las dos imágenes de este README
├── armor.project.json                   manifiesto: versión, rol, madurez, comando de build
├── CHANGELOG.md                         qué cambió en cada versión
├── SECURITY.md SUPPORT.md LICENSE       política de seguridad, soporte y licencia
├── CONTRIBUTING.md CODE_OF_CONDUCT.md   cómo contribuir y el código de conducta
├── Package.swift                        el paquete Swift: ArmorCore y sus pruebas
├── project.yml                          XcodeGen: de aquí se genera el proyecto de Xcode
└── .gitattributes .gitignore            ajustes de Git
```

</details>

## 🗺️ Hoja de ruta y límites conocidos

**Límites conocidos hoy**

* Nada ha corrido en un iPhone: las pantallas SwiftUI no se han compilado en Xcode; Face ID, el Keychain, las reglas de certificado, la cámara en vivo, los sonidos de los avisos, la voz y el push de Firebase están sin probar.
* Solo las reglas (`ArmorCore`) están probadas, y solo en Linux.
* La app no vigila en segundo plano: iOS no deja que una app cerrada consulte al servidor.

**Lo siguiente**

* Compilar las pantallas en Xcode y ejecutar la app en un iPhone contra el banco de pruebas CM5.
* Probar Face ID, el Keychain, las reglas de certificado, la cámara en vivo y el push.

## 🌍 Idiomas

El README y los textos existen en inglés, español, francés, italiano, alemán, chino, japonés y portugués de Portugal.

## 🔗 Proyectos relacionados

**A.R.M.O.R.** (Autonomous Radar & Multimodal Observation Range) es un sistema de seguridad perimetral hecho de repositorios independientes. Cada uno tiene su propia versión, sus propias pruebas y su propio README; esta es la familia:

* **[ARMOR-COMMON](https://github.com/JuanenRac/ARMOR-COMMON)** - Contratos de mensajes, validadores, vectores de conformidad y tipos generados
* **[ARMOR-NODE-RADAR](https://github.com/JuanenRac/ARMOR-NODE-RADAR)** - Firmware de nodo de campo para ESP32-S3 con tres radares y su propio panel web
* **[ARMOR-NODE-SOLAR](https://github.com/JuanenRac/ARMOR-NODE-SOLAR)** - Protocolos de inversores y baterías solares y los mensajes de un nodo pasarela
* **[ARMOR-NODE-ELECTRICAL](https://github.com/JuanenRac/ARMOR-NODE-ELECTRICAL)** - Nodo eléctrico: medidores, el mensaje de las lecturas de la red y las reglas de maniobra
* **[ARMOR-NODE-ALARM](https://github.com/JuanenRac/ARMOR-NODE-ALARM)** - Nodo y panel de alarma: zonas, armado, retardos, sirena y PIN, con el servidor o sin él
* **[ARMOR-NODE-HMI](https://github.com/JuanenRac/ARMOR-NODE-HMI)** - Panel táctil: el estado del sistema en una pantalla de pared, armar y reconocer, y el hogar del asistente de voz
* **[ARMOR-NETWORK](https://github.com/JuanenRac/ARMOR-NETWORK)** - La red local: sus dispositivos, internet y lo que cambia
* **[ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER)** - Coordinador central: telemetría, alarmas, dispositivos, lecturas solares y cámaras
* **[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO)** - Consola web: cámaras, radar, alarmas, energía solar y el diseñador 2D/3D del emplazamiento
* **[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL)** - Cliente de operador Android con radar 2D/3D en vivo
* **ARMOR-IOS-CONTROL** (este repositorio) - Cliente de operador para iPhone
* **[ARMOR-SERVER-AI](https://github.com/JuanenRac/ARMOR-SERVER-AI)** - Política de inferencia visual que explica sus decisiones y nunca actúa
* **[ARMOR-VISION](https://github.com/JuanenRac/ARMOR-VISION)** - Zonas de cámara, máscaras y reglas de detección para la Jetson Orin NX
* **[ARMOR-VOICE-AI](https://github.com/JuanenRac/ARMOR-VOICE-AI)** - Intenciones de voz sin conexión con una confirmación que no se puede falsificar
* **[ARMOR-HARDWARE](https://github.com/JuanenRac/ARMOR-HARDWARE)** - Cajas, electrónica y la matriz de aceptación en banco
* **[ARMOR-DEVOPS](https://github.com/JuanenRac/ARMOR-DEVOPS)** - Despliegue, el banco de pruebas de la CM5, copias de seguridad y TLS
* **[ARMOR-SIMULATOR](https://github.com/JuanenRac/ARMOR-SIMULATOR)** - Simulador de telemetría sin conexión con fallos repetibles
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - Detecta, instala y actualiza los repositorios del propio ecosistema
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - Arquitectura, base de seguridad y la matriz de capacidades

## 📚 Documentación

* [Límites del cliente](docs/CLIENT_BOUNDARY.md): qué hace y qué nunca hace el cliente, y cómo compilarlo
* [Matriz de capacidades: qué está demostrado y qué no](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [Catálogo de proyectos: versiones y cómo dependen unos repositorios de otros](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [Registro de cambios de este repositorio](CHANGELOG.md)

## 🤝 Contribuir y comunidad

* Antes de un pull request ejecuta `swift test` and `python tools/ios_lint.py` and `python -I tools/armor_ci_validate.py`: debe pasar. Consulta [CONTRIBUTING.md](CONTRIBUTING.md) y el [código de conducta](CODE_OF_CONDUCT.md).
* El README existe en ocho idiomas y se genera desde las fuentes de ARMOR-DOCS: un cambio de texto se hace allí.
* Un cambio en un mensaje entre componentes empieza en ARMOR-COMMON.
* No describas como funcionando en una placa lo que solo se ha compilado.
* Informa de una vulnerabilidad en privado: [SECURITY.md](SECURITY.md). Preguntas, ideas e informes: electrohobby3d@gmail.com ([SUPPORT.md](SUPPORT.md)).

## 👤 AUTOR

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 LICENCIA

GPL-3.0-or-later - véase [LICENSE](LICENSE).
