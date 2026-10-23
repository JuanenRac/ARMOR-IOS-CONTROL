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
  <b>🇨🇳 简体中文</b> |
  <a href="README_jpn.md">🇯🇵 日本語</a> |
  <a href="README_por.md">🇵🇹 Português</a>
</p>

### ARMOR-SERVER 的 iPhone 操作员客户端：状态、布防、警报、报警主机、摄像头和助手，支持八种语言

<p align="center">
  <img src="https://img.shields.io/badge/License-GPL%203.0-blue.svg" alt="GPL 3.0">
  <img src="https://img.shields.io/badge/Language-Swift-f05138.svg" alt="Language">
  <img src="https://img.shields.io/badge/UI-SwiftUI-0a84ff.svg" alt="UI">
  <img src="https://img.shields.io/badge/Languages-8-00E5FF.svg" alt="Languages">
  <img src="https://img.shields.io/badge/Tests-98%20passing-2ea44f.svg" alt="Tests">
  <img src="https://img.shields.io/badge/Version-0.0.1-0f6cbd.svg" alt="Version">
  <img src="https://img.shields.io/badge/Maturity-scaffolding-orange.svg" alt="Maturity">
</p>

---

**诚实检查 - 目前能运行的部分：** 应用的规则（服务器连接、响应解析、地址选择、手机锁、会话保险库、证书信任、警报策略、用例、MJPEG 切分）是 Swift 包 `ArmorCore`，由 98 个单元测试覆盖，可在 macOS 或 Linux 上用 `swift test` 运行；`tools/ios_lint.py` 无需 Mac 即可检查结构、八张语言表和接口契约。**尚未**证明的部分：SwiftUI 界面以及需要 iPhone 的部分（Face ID、钥匙串、证书规则、实时摄像头、通过 Firebase 的推送）尚未在 Xcode 中构建，也未在设备上运行。

---

## 📋 概览

| | |
|---|---|
| 版本 | `0.0.1` |
| 成熟度 | 脚手架 |
| 测试 | 98 (`swift test`) |
| 技术栈 | Swift / SwiftUI |
| 真实硬件 | 尚未在 iPhone 上运行；规则在 Linux 上测试 |

## 🎯 简介

* **使用服务器自身的登录：** 家里的地址（在家与外出）、用户名和密码；密码创建 HttpOnly 会话；只有勾选**记住我**才会保存（存放在这部手机的钥匙串中，不会备份）。**viewer** 角色只能查看：所有会修改内容的按钮都会关闭。
* **两个地址：** 家中 Wi-Fi 使用内网地址，移动数据使用外出地址（动态 DNS 名称或 VPN）；其中一个没有响应时会尝试另一个，并提示哪里出了问题。
* **手机锁：** 在布防、撤防、静音警笛、解锁及其他关键操作之前要求 Face ID、Touch ID 或密码（默认仅在手机有 Face ID 或 Touch ID 时开启），如果您开启，打开应用时也会要求。管理员可以强制要求，但不能降低您的选择；没有密码的手机永远不会被拒之门外，锁定界面始终提供用密码登录。可选（默认关闭，带警告）：仅在手机解锁时才能读取已保存的会话。
* **布防与撤防**：先检查哪些部分会成为盲区或产生误报，撤防需要 PIN；待确认的**警报**及其角标；**报警主机**（外出布防或在家布防、撤防、警笛静音）和**历史记录**；带开/关的**设备**，对回路和关键设备需要确认。
* **摄像头**通过服务器查看（应用永远没有摄像头密码）：只有屏幕上可见的画面才会播放的网格、带方向键用于移动摄像头的全屏视图以及拍照，画面中断时以逐渐增长的等待时间重新请求。
* **助手：** 文字指令（键盘麦克风可听写），布防和撤防需要与您绑定的确认，并位于手机锁之后。
* **证书信任：** 首次连接时记住安装证书的密钥，或通过 Studio 的二维码配对；如果发生变化，连接会被拒绝并通知您。
* **八种语言**（英语、西班牙语、德语、法语、意大利语、日语、中文和葡萄牙（葡萄牙）语），可在*更多 > 语言*中选择或跟随手机，每个界面都有帮助。

## 🧩 A.R.M.O.R. 中的角色

ARMOR-IOS-CONTROL 是 iPhone 通往同一个 [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER) 的窗口，[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) 和 [ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL) 也使用它：只通过它读取和下达命令，并使用与 Android 应用相同的接口契约。

## 📂 仓库结构

```text
ARMOR-IOS-CONTROL/
├── Sources/ArmorCore/   Tr, ServerEndpoint, Models, ArmorApi(+Client), ArmorController, DeviceLock, SessionVault, Trust, Reach, Connector, AlarmPolicy, MjpegParser
│   └── Resources/i18n/   en, de, fr, it, ja, zh, pt (es is the source text)
├── Tests/ArmorCoreTests/   98 tests + fixtures of a real server
├── App/   SwiftUI: ArmorApp, AppModel, Root, Login, Home, Alarms, Cameras, Assistant, More, Locked, Help
│   ├── Platform/   Keychain, Face ID / Touch ID, certificate rules, push
│   └── Resources/   assets and the permission texts in eight languages
├── project.yml (XcodeGen)   Package.swift
├── tools/ios_lint.py   structure, languages, contract, secrets (no Mac needed)
└── docs/CLIENT_BOUNDARY.md
```

## 🛠️ 开发环境

**要求：** 构建应用需要装有 Xcode 15+ 和 iOS 16+ 的 Mac；测试需要 Swift 5.9+（macOS 或 Linux）；检查需要 Python 3.11

```sh
swift test                  # 98 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

Xcode 工程由 `project.yml` 通过 XcodeGen 生成。请选择签名团队、添加应用图标，并为推送添加安装专用的 `GoogleService-Info.plist`（绝不保存在仓库中）。参见[客户端边界](docs/CLIENT_BOUNDARY.md)。

## 🔗 相关项目

**A.R.M.O.R.**（Autonomous Radar & Multimodal Observation Range）是由独立仓库组成的周界安防系统。每个仓库都有自己的版本、测试和 README；家族如下：

* **[ARMOR-COMMON](https://github.com/JuanenRac/ARMOR-COMMON)** - 消息契约、校验器、一致性向量和生成的类型
* **[ARMOR-RADAR](https://github.com/JuanenRac/ARMOR-RADAR)** - 带三个雷达和自带网页面板的 ESP32-S3 现场节点固件
* **[ARMOR-SOLAR](https://github.com/JuanenRac/ARMOR-SOLAR)** - 太阳能逆变器和电池协议以及网关节点的消息
* **[ARMOR-ELECTRICAL](https://github.com/JuanenRac/ARMOR-ELECTRICAL)** - 电气节点：电表、电网读数消息和切换规则
* **[ARMOR-ALARM](https://github.com/JuanenRac/ARMOR-ALARM)** - 报警节点与主机：防区、布防、延时、警笛和 PIN，有无服务器均可
* **[ARMOR-HMI](https://github.com/JuanenRac/ARMOR-HMI)** - 触摸面板：墙面屏幕上的系统状态、布防与确认，以及语音助手的家
* **[ARMOR-NETWORK](https://github.com/JuanenRac/ARMOR-NETWORK)** - 本地网络：其设备、互联网以及变化
* **[ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER)** - 中央协调器：遥测、警报、设备、太阳能读数和摄像头
* **[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO)** - 网页控制台：摄像头、雷达、警报、太阳能和 2D/3D 现场设计器
* **[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL)** - 带实时 2D/3D 雷达的 Android 操作员客户端
* **ARMOR-IOS-CONTROL** （本仓库）- iPhone 操作员客户端
* **[ARMOR-SERVER-AI](https://github.com/JuanenRac/ARMOR-SERVER-AI)** - 解释其决策且从不执行动作的视觉推理策略
* **[ARMOR-VISION](https://github.com/JuanenRac/ARMOR-VISION)** - Jetson Orin NX 的摄像头区域、遮罩和检测规则
* **[ARMOR-VOICE-AI](https://github.com/JuanenRac/ARMOR-VOICE-AI)** - 带有无法伪造的确认的离线语音意图
* **[ARMOR-HARDWARE](https://github.com/JuanenRac/ARMOR-HARDWARE)** - 外壳、电子元件和台架验收矩阵
* **[ARMOR-DEVOPS](https://github.com/JuanenRac/ARMOR-DEVOPS)** - 部署、CM5 测试台、备份和 TLS
* **[ARMOR-SIMULATOR](https://github.com/JuanenRac/ARMOR-SIMULATOR)** - 带可重复故障的离线遥测模拟器
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - 检测、安装并更新生态系统自身的仓库
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - 架构、安全基线和能力矩阵

## 📚 文档与社区

更多阅读：

* [能力矩阵：哪些已证明，哪些没有](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [项目目录：版本以及仓库之间的依赖](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [本仓库的更新日志](CHANGELOG.md)
* [许可证（GPL-3.0-or-later）](LICENSE)
* 问题、想法与报告: electrohobby3d@gmail.com

## 👤 作者

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 许可证

GPL-3.0-or-later - see [LICENSE](LICENSE).
