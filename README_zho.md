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
  🇨🇳 <b>简体中文</b> |
  <a href="README_jpn.md">🇯🇵 日本語</a> |
  <a href="README_por.md">🇵🇹 Português</a>
</p>

### ARMOR-SERVER 的 iPhone 操作员客户端：状态、布防、警报、报警主机、摄像头和助手，支持八种语言

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

**诚实性检查 - 今天真正能运行的部分：** 应用的规则（服务器连接、响应解析、地址选择、手机锁、会话保险库、证书信任、警报策略、用例、MJPEG 切分）是 Swift 包 `ArmorCore`，由 146 个单元测试覆盖，可在 macOS 或 Linux 上用 `swift test` 运行；`tools/ios_lint.py` 无需 Mac 即可检查结构、八张语言表和接口契约。**尚未**证明的部分：SwiftUI 界面以及需要 iPhone 的部分（Face ID、钥匙串、证书规则、实时摄像头、通过 Firebase 的推送）尚未在 Xcode 中构建，也未在设备上运行。

---

## 📋 速览

| | |
|---|---|
| 版本 | `0.0.1` |
| 成熟度 | 雏形 |
| 角色 | ARMOR-SERVER 的 iPhone 操作客户端（家族：Clients，上级：ARMOR-SERVER） |
| 技术栈 | Swift 5.9+ / SwiftUI, iOS 16+ |
| 测试 | 146 (`swift test`) |
| 语言 | 8（每种语言 241 条短语，由 `ios_lint.py` 检查） |
| 运行位置 | iOS 16+ 的 iPhone；测试在 macOS 或 Linux 上运行 |
| 真实硬件 | 尚未在 iPhone 上运行；规则在 Linux 上测试 |
| 许可证 | GPL-3.0-or-later |

**跳转到：** [概述](#-概述) · [架构](#-架构) · [安全](#-安全与防护) · [接口](#-接口) · [配置](#-配置) · [快速开始](#-快速开始) · [测试](#-测试) · [故障排除](#-故障排除) · [结构](#-仓库结构) · [相关项目](#-相关项目)

## 🚦 项目状态

每一行是本仓库的一个部分，灯号表示它今天做到了哪一步。内容依据仓库能够展示的证据（测试、构建、运行），而不是计划。

🟢 已完成并验证 · 🟡 可用，有已知限制 · 🟠 部分完成或尚未验证 · 🔴 未完成或不可用

| 领域 | 状态 | 在这里的含义 |
|---|---|---|
| 软件 | 🟠 | 应用的规则是一个 Swift 包（`ArmorCore`）；SwiftUI 界面尚未在 Xcode 中构建。 |
| 测试 | 🟡 | 146 项单元测试在 macOS 或 Linux 上通过 `swift test` 运行，`tools/ios_lint.py` 无需 Mac 即可检查结构、八种语言表和契约；没有任何测试在设备上运行。 |
| 界面 | 🟠 | SwiftUI 界面已编写，但尚未在 Xcode 中构建，也没有在 iPhone 上运行。 |
| 硬件 | 🔴 | 尚未在 iPhone 上运行过：规则只在 Linux 上测试。 |
| 安全 | 🟠 | 手机锁定、会话保险库和对证书的信任是在 Linux 上测试的规则；Face ID、钥匙串和证书规则尚未在设备上运行过。 |
| 集成 | 🟠 | 实时摄像头和通过 Firebase 的推送尚未试过；与服务器的连接和解析已对照共享契约测试。 |
| 文档 | 🟡 | 八种语言和更新日志均为最新。 |

## 🎯 概述

* **使用服务器自身的登录：** 家里的地址（在家与外出）、用户名和密码；密码创建 HttpOnly 会话；只有勾选**记住我**才会保存（存放在这部手机的钥匙串中，不会备份）。**viewer** 角色只能查看：所有会修改内容的按钮都会关闭。
* **两个地址：** 家中 Wi-Fi 使用内网地址，移动数据使用外出地址（动态 DNS 名称或 VPN）；其中一个没有响应时会尝试另一个，并提示哪里出了问题。
* **手机锁：** 在布防、撤防、静音警笛、解锁及其他关键操作之前要求 Face ID、Touch ID 或密码（默认仅在手机有 Face ID 或 Touch ID 时开启），如果您开启，打开应用时也会要求。管理员可以强制要求，但不能降低您的选择；没有密码的手机永远不会被拒之门外，锁定界面始终提供用密码登录。可选（默认关闭，带警告）：仅在手机解锁时才能读取已保存的会话。
* **布防与撤防**：先检查哪些部分会成为盲区或产生误报，撤防需要 PIN；待确认的**警报**及其角标；**报警主机**（外出布防或在家布防、撤防、警笛静音）和**历史记录**；带开/关的**设备**，对回路和关键设备需要确认。
* **摄像头**通过服务器查看（应用永远没有摄像头密码）：只有屏幕上可见的画面才会播放的网格、带方向键用于移动摄像头的全屏视图以及拍照，画面中断时以逐渐增长的等待时间重新请求。
* **按你的意愿设置通知：** 可全部静音，或无声显示；可按严重级别和类型关闭（严重警报绝不会被隐藏，除非使用“全部静音”开关）；可为每个严重级别和每种类型选择自己的声音文件，并带有播放按钮；还可设置朗读警报的声音（女声、男声、年龄、风格、语速、低严重级别通知），并带有试听按钮。一个画面中含两个镜头的摄像头会显示为两个窗口。 应用打开时也会显示通知（横幅和通知声音）；你对隐藏或静音某类通知所做的选择仍然优先。
* **助手：** 文字指令（键盘麦克风可听写），布防和撤防需要与您绑定的确认，并位于手机锁之后。
* **证书信任：** 首次连接时记住安装证书的密钥，或通过 Studio 的二维码配对；如果发生变化，连接会被拒绝并通知您。
* **八种语言**（英语、西班牙语、德语、法语、意大利语、日语、中文和葡萄牙（葡萄牙）语），可在*更多 > 语言*中选择或跟随手机，每个界面都有帮助。

## 🧩 在 A.R.M.O.R. 中的角色

ARMOR-IOS-CONTROL 是 iPhone 通往同一个 [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER) 的窗口，[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) 和 [ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL) 也使用它：只通过它读取和下达命令，并使用与 Android 应用相同的接口契约。

| 名称 | 方式 | 用途 |
|---|---|---|
| ARMOR-SERVER | HTTP `/api/v1`, MJPEG | 应用读取和下达的一切；不与其他对象通信 |
| ARMOR-ANDROID-CONTROL | 相同合约 | `ios_lint.py` 检查应用只调用 Android 客户端也调用的路径 |
| ARMOR-STUDIO | QR | 配对安装环境证书的密钥 |

## 🏛️ 架构

<p align="center">
  <img src="images/architecture.svg" alt="ARMOR-IOS-CONTROL 的架构：谁调用它、它包含什么、它依赖什么" width="100%">
</p>

## 🔒 安全与防护

| 威胁 | 防御 |
|---|---|
| 手机上的密码 | 仅在勾选*记住我*时保存，存于本机钥匙串且绝不备份；会话是服务器的 HttpOnly Cookie |
| 手机落入他人之手时的关键操作 | 在布防、撤防、静音警笛、解锁等关键操作前要求 Face ID、Touch ID 或密码；管理员可以强制要求，但不能降低你的选择；没有密码的手机永远不会被拒之门外 |
| 被更改或伪造的证书 | 首次记住安装环境证书的密钥，或用 Studio 的二维码配对；若发生变化，则拒绝连接并通知你 |
| 以明文发送的密码 | 仅对私有网络或回环地址使用明文 HTTP（`NSAllowsLocalNetworking`）；其他情况需要 https，否则应用拒绝发送密码 |
| 手机上的摄像头密码 | 摄像头经服务器转发：应用没有摄像头密码，也没有 RTSP 地址 |
| 查看者修改了内容 | *查看者*角色只能查看：所有会修改内容的按钮都被禁用；服务器会再次检查 |
| 助手误操作布防或撤防 | 仅限文字命令（键盘麦克风负责听写）；布防和撤防需要与你绑定的确认，并位于手机锁之后 |

权限文字（Face ID、本地网络）有全部八种语言。这里的一切都没有在 iPhone 上运行过：Face ID、钥匙串和证书规则都没有在真机上测试。请阅读 [docs/CLIENT_BOUNDARY.md](docs/CLIENT_BOUNDARY.md) 和 [SECURITY.md](SECURITY.md)。

## 🔌 接口

它是客户端：调用 ARMOR-SERVER 的 26 条路径（`tools/ios_lint.py` 会统计并检查 Android 客户端也调用它们），并用自己的解析器切分摄像头的 MJPEG 流（`MjpegParser.swift`）。

| 部分 | 作用 |
|---|---|
| 两个地址 | 在家庭 Wi-Fi 下使用私有地址，在移动数据下使用外出地址（动态 DNS 名称或 VPN）；一个无响应就尝试另一个，并说明失败原因（`Reach.swift`、`Connector.swift`） |
| 摄像头 | 只有屏幕上可见的画面才会运行的网格、带方向盘和快照的全屏视图，以及中断后以递增等待时间重新请求的视频流 |
| 推送 | 报警只能通过推送（`Push.swift`、Firebase）到达已关闭的应用，且仅当服务器开启推送且安装环境提供自己的 `GoogleService-Info.plist` 时才可行；未经试验 |

## ⚙️ 配置

| 名称 | 值 | 作用 |
|---|---|---|
| iOS | 16.0+ | 最低版本，在 `project.yml` 中设置 |
| Xcode / Swift | 15+ / 5.9+ | 用于构建应用／运行测试 |
| `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` | 0.0.1, 1 | 应用版本，来自 `project.yml` |
| `GoogleService-Info.plist` | 用于推送 | 安装环境自己的文件，绝不保存在仓库中 |

应用内：两个地址、*记住我*、手机锁和语言（八种语言或跟随手机）位于*更多 > 语言*。

## 🚀 快速开始

**要求:** 构建应用需要装有 Xcode 15+ 和 iOS 16+ 的 Mac；测试需要 Swift 5.9+（macOS 或 Linux）；检查需要 Python 3.11。

```sh
swift test                  # 146 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

Xcode 工程由 `project.yml` 通过 XcodeGen 生成。请选择签名团队、添加应用图标，并为推送添加安装专用的 `GoogleService-Info.plist`（绝不保存在仓库中）。参见[客户端边界](docs/CLIENT_BOUNDARY.md)。

## 🧪 测试

```sh
swift test                  # macOS or Linux
python tools/ios_lint.py    # any system, no Mac needed
python -I tools/armor_ci_validate.py
```

| 测试文件 | 测试数 | 覆盖内容 |
|---|---|---|
| `ControllerTests.swift` | 15 | 控制器的用例 |
| `ClientTests.swift` | 14 | 与服务器的连接及解析 |
| `LockTests.swift` | 12 | 手机锁 |
| `ModelsTests.swift` | 12 | 从服务器读取的模型 |
| `ReachTests.swift` | 11 | 两个地址之间的选择 |
| `SecurityTests.swift` | 8 | 会话保险库和对证书的信任 |
| `EndpointTests.swift`, `MjpegTests.swift`, `TranslatorTests.swift` | 7 + 7 + 7 | 地址解析、MJPEG 切分和翻译器 |
| `PolicyTests.swift`, `AlarmCodesTests.swift` | 6 + 4 | 报警策略和报警代码 |

这 146 个测试使用真实服务器的数据。`tools/ios_lint.py` 无需 Mac 即可通过：31 个 Swift 文件、8 种语言的 241 条短语、26 条服务器路径。没有任何测试在真机上运行。

## 🏗️ 构建与发布

Xcode 项目由 XcodeGen 根据 `project.yml` 生成：选择签名团队，把应用图标加入 `App/Resources/Assets.xcassets/AppIcon.appiconset`，推送还需加入安装环境的 `GoogleService-Info.plist`。从未在 Xcode 中构建过。

## 🩺 故障排除

| 现象 | 原因 | 处理 |
|---|---|---|
| 连接被拒绝并通知你 | 安装环境证书的密钥发生了变化 | 若是有意更改，请用 Studio 的二维码重新配对 |
| 两个地址都无响应 | 地址错误、没有网络，或对家庭之外使用 http（会被拒绝：密码不会以明文发送） | 检查两个地址；在外时使用 https |
| `wrong_pin`、`pin_locked`、`pin_not_set` | 服务器拒绝撤防 PIN；应用会用你的语言显示该代码 | 重新输入 PIN 或等待锁定结束；在 Studio 中设置 |

## 📂 仓库结构

<p align="center">
  <img src="images/repository-structure.svg" alt="ARMOR-IOS-CONTROL 的仓库结构" width="100%">
</p>

<details>
<summary>目录树的文本版</summary>

```text
ARMOR-IOS-CONTROL/
├── Sources/ArmorCore/                   应用的规则：一个 Swift 包
├── App/                                 SwiftUI 界面和需要 iPhone 的部分
├── Tests/                               146 个测试和真实服务器的数据
├── docs/                                本仓库的指南
├── tools/                               共享的 CI 检查和项目工具
├── .github/                             CI 工作流以及 Issue 和 Pull Request 模板
├── images/                              横幅、图标和本 README 的两幅图
├── armor.project.json                   清单：版本、角色、成熟度、构建命令
├── CHANGELOG.md                         每个版本的变化
├── SECURITY.md SUPPORT.md LICENSE       安全策略、支持和许可证
├── CONTRIBUTING.md CODE_OF_CONDUCT.md   如何贡献与行为准则
├── Package.swift                        Swift 包：ArmorCore 及其测试
├── project.yml                          XcodeGen：由此生成 Xcode 项目
└── .gitattributes .gitignore            Git 设置
```

</details>

## 🗺️ 路线图与已知限制

**目前已知的限制**

* 尚未在 iPhone 上运行过：SwiftUI 界面没有在 Xcode 中构建；Face ID、钥匙串、证书规则、实时摄像头、通知声音、朗读声音和 Firebase 推送均未测试。
* 只有规则（`ArmorCore`）经过测试，而且仅在 Linux 上。
* 应用不会在后台监视：iOS 不允许已关闭的应用查询服务器。

**下一步**

* 在 Xcode 中构建界面，并在 iPhone 上对 CM5 测试台运行应用。
* 试验 Face ID、钥匙串、证书规则、实时摄像头和推送。

## 🌍 语言

README 和文本提供英语、西班牙语、法语、意大利语、德语、汉语、日语和欧洲葡萄牙语版本。

## 🔗 相关项目

**A.R.M.O.R.**（Autonomous Radar & Multimodal Observation Range）是一个由相互独立的仓库组成的周界安全系统。每个仓库都有自己的版本、自己的测试和自己的 README；这是整个系列：

* **[ARMOR-COMMON](https://github.com/JuanenRac/ARMOR-COMMON)** - 消息契约、验证器、一致性向量和生成的类型
* **[ARMOR-NODE-RADAR](https://github.com/JuanenRac/ARMOR-NODE-RADAR)** - 面向 ESP32-S3 的现场节点固件，配三个雷达和自带的网页面板
* **[ARMOR-NODE-SOLAR](https://github.com/JuanenRac/ARMOR-NODE-SOLAR)** - 太阳能逆变器和电池的协议，以及网关节点的消息
* **[ARMOR-NODE-ELECTRICAL](https://github.com/JuanenRac/ARMOR-NODE-ELECTRICAL)** - 电气节点：电表、电网读数的消息和切换规则
* **[ARMOR-NODE-ALARM](https://github.com/JuanenRac/ARMOR-NODE-ALARM)** - 报警节点与面板：防区、布防、延时、警笛和 PIN，可配合服务器也可独立使用
* **[ARMOR-NODE-HMI](https://github.com/JuanenRac/ARMOR-NODE-HMI)** - 触摸面板：壁挂屏幕上的系统状态、布防与确认，以及语音助手的所在
* **[ARMOR-NETWORK](https://github.com/JuanenRac/ARMOR-NETWORK)** - 本地网络：其设备、互联网以及变化
* **[ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER)** - 中央协调器：遥测、报警、设备、太阳能读数和摄像头
* **[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO)** - 网页控制台：摄像头、雷达、报警、太阳能以及 2D/3D 场地设计器
* **[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL)** - 带实时 2D/3D 雷达的 Android 操作员客户端
* **ARMOR-IOS-CONTROL**（本仓库） - iPhone 操作员客户端
* **[ARMOR-SERVER-AI](https://github.com/JuanenRac/ARMOR-SERVER-AI)** - 视觉推理策略，会解释其决策且从不驱动设备
* **[ARMOR-VISION](https://github.com/JuanenRac/ARMOR-VISION)** - 面向 Jetson Orin NX 的摄像头区域、遮罩和检测规则
* **[ARMOR-VOICE-AI](https://github.com/JuanenRac/ARMOR-VOICE-AI)** - 离线语音意图，附带无法伪造的确认
* **[ARMOR-HARDWARE](https://github.com/JuanenRac/ARMOR-HARDWARE)** - 外壳、电子器件和台架验收矩阵
* **[ARMOR-DEVOPS](https://github.com/JuanenRac/ARMOR-DEVOPS)** - 部署、CM5 测试台、备份和 TLS
* **[ARMOR-SIMULATOR](https://github.com/JuanenRac/ARMOR-SIMULATOR)** - 带可重复故障的离线遥测模拟器
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - 检测、安装和更新生态系统自身的仓库
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - 架构、安全基线和能力矩阵

## 📚 文档

* [客户端边界](docs/CLIENT_BOUNDARY.md)：客户端做什么、绝不做什么，以及如何构建
* [能力矩阵：哪些已被证明，哪些没有](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [项目目录：版本以及各仓库之间如何相互依赖](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [本仓库的更新日志](CHANGELOG.md)

## 🤝 参与贡献与社区

* 提交 Pull Request 之前请运行 `swift test` and `python tools/ios_lint.py` and `python -I tools/armor_ci_validate.py`：必须通过。参见 [CONTRIBUTING.md](CONTRIBUTING.md) 和[行为准则](CODE_OF_CONDUCT.md)。
* README 提供八种语言，由 ARMOR-DOCS 中的源文件生成：文本的修改在那里进行。
* 组件之间消息的变更从 ARMOR-COMMON 开始。
* 不要把仅仅构建过的东西描述为已在板子上运行。
* 请私下报告漏洞：[SECURITY.md](SECURITY.md)。问题、想法和报告：electrohobby3d@gmail.com（[SUPPORT.md](SUPPORT.md)）。

## 👤 作者

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 许可证

GPL-3.0-or-later - 见 [LICENSE](LICENSE)。
