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
  <a href="README_zho.md">🇨🇳 简体中文</a> |
  <b>🇯🇵 日本語</b> |
  <a href="README_por.md">🇵🇹 Português</a>
</p>

### ARMOR-SERVER の iPhone オペレータークライアント：状態、警戒、警報、警報盤、カメラ、アシスタント。8 言語対応

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

**正直なチェック - 今日動いているもの：** アプリのルール（サーバー接続、応答の解析、アドレスの選択、端末ロック、セッションの保管庫、証明書の信頼、警報ポリシー、ユースケース、MJPEG の切り出し）は Swift パッケージ `ArmorCore` にあり、macOS または Linux で `swift test` により実行される 98 件の単体テストでカバーされています。`tools/ios_lint.py` は Mac なしで構造、8 言語の表、契約を検査します。**まだ**証明されていないもの：SwiftUI の画面と iPhone が必要な部分（Face ID、キーチェーン、証明書ルール、ライブカメラ、Firebase 経由のプッシュ）は、Xcode でのビルドも実機での実行もしていません。

---

## 📋 概要一覧

| | |
|---|---|
| バージョン | `0.0.1` |
| 成熟度 | 足場 |
| テスト | 98 (`swift test`) |
| 技術 | Swift / SwiftUI |
| 実機 | iPhone ではまだ実行していません。ルールは Linux でテスト済みです |

## 🎯 概要

* **サーバー自身のログインでサインイン：** 家のアドレス（自宅と外出先）、ユーザー名、パスワード。パスワードは HttpOnly セッションを作り、**記憶**にチェックした場合のみ保存されます（この iPhone のキーチェーン内、バックアップなし）。**viewer** ロールは閲覧のみで、変更するボタンはすべて無効です。
* **2 つのアドレス：** 自宅の Wi-Fi ではプライベートなアドレス、モバイルデータでは外出先用（ダイナミック DNS 名または VPN）。一方が応答しなければもう一方を試し、何が失敗したかを表示します。
* **端末ロック：** 警戒、解除、サイレンの消音、解錠などの重要な操作の前に Face ID、Touch ID またはパスコードを要求します（既定では Face ID / Touch ID がある場合のみオン）。オンにするとアプリを開くときにも要求します。管理者は必須にできますが、あなたの選択を下げることはできません。パスコードのない iPhone が締め出されることはなく、ロック画面には常にパスワードでのサインインがあります。任意（既定でオフ、警告付き）：保存したセッションは iPhone のロック解除中のみ読めます。
* **警戒と解除**：死角やノイズになる箇所を確認した上で行い、解除には PIN が必要です。確認すべき**警報**（バッジ付き）、**警報盤**（外出警戒・在宅警戒、解除、サイレン消音）と**履歴**、オン / オフできる**デバイス**（回路と重要機器は確認付き）。
* **カメラ**はサーバー経由（アプリがカメラのパスワードを持つことはありません）：画面に見えている映像だけが動くグリッド、カメラを動かす十字キーと写真付きのフルビュー、途切れたときに待ち時間を延ばしながら再取得するストリーム。
* **アシスタント：** 文字コマンド（キーボードのマイクで音声入力可）。警戒と解除にはご本人に結び付いた確認が必要で、ロックの内側にあります。
* **証明書の信頼：** インストールの証明書の鍵を初回に記憶するか、Studio の QR コードでペアリングします。変更されると接続を拒否して通知します。
* **8 言語**（英語、スペイン語、ドイツ語、フランス語、イタリア語、日本語、中国語、ポルトガル（ポルトガル）語）を*その他 > 言語*で選択、または iPhone に従い、各画面にヘルプがあります。

## 🧩 A.R.M.O.R. での役割

ARMOR-IOS-CONTROL は、[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO) と [ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL) が使うのと同じ [ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER) への iPhone の窓口です。読み取りも命令もサーバー経由のみで、Android アプリと同じ契約を使います。

## 📂 リポジトリ構成

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

## 🛠️ 開発環境

**要件：** アプリのビルドには Xcode 15+ と iOS 16+ を備えた Mac、テストには Swift 5.9+（macOS または Linux）、検査には Python 3.11

```sh
swift test                  # 98 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

Xcode プロジェクトは `project.yml` から XcodeGen で生成します。署名チームを選び、アプリアイコンを追加し、プッシュにはインストール専用の `GoogleService-Info.plist` を追加してください（リポジトリには保存しません）。[クライアントの境界](docs/CLIENT_BOUNDARY.md)を参照してください。

## 🔗 関連プロジェクト

**A.R.M.O.R.**（Autonomous Radar & Multimodal Observation Range）は、独立したリポジトリで構成される周界警備システムです。各リポジトリには独自のバージョン、テスト、README があります。ファミリーは次のとおりです：

* **[ARMOR-COMMON](https://github.com/JuanenRac/ARMOR-COMMON)** - メッセージ契約、検証ツール、適合ベクトル、生成された型
* **[ARMOR-RADAR](https://github.com/JuanenRac/ARMOR-RADAR)** - 3 つのレーダーと独自の Web パネルを備えた ESP32-S3 フィールドノードのファームウェア
* **[ARMOR-SOLAR](https://github.com/JuanenRac/ARMOR-SOLAR)** - 太陽光インバーターとバッテリーのプロトコル、およびゲートウェイノードのメッセージ
* **[ARMOR-ELECTRICAL](https://github.com/JuanenRac/ARMOR-ELECTRICAL)** - 電気ノード：メーター、電力網の測定値メッセージ、切り替えルール
* **[ARMOR-ALARM](https://github.com/JuanenRac/ARMOR-ALARM)** - 警報ノードと警報盤：ゾーン、警戒、遅延、サイレン、PIN。サーバーの有無を問いません
* **[ARMOR-HMI](https://github.com/JuanenRac/ARMOR-HMI)** - タッチパネル：壁面スクリーンでのシステム状態、警戒と確認、音声アシスタントの拠点
* **[ARMOR-NETWORK](https://github.com/JuanenRac/ARMOR-NETWORK)** - ローカルネットワーク：デバイス、インターネット、変化
* **[ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER)** - 中央コーディネーター：テレメトリ、警報、デバイス、太陽光の測定値、カメラ
* **[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO)** - Web コンソール：カメラ、レーダー、警報、太陽光発電、2D/3D サイトデザイナー
* **[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL)** - リアルタイム 2D/3D レーダー付きの Android オペレータークライアント
* **ARMOR-IOS-CONTROL** （このリポジトリ）- iPhone オペレータークライアント
* **[ARMOR-SERVER-AI](https://github.com/JuanenRac/ARMOR-SERVER-AI)** - 判断を説明し、決して動作しない視覚推論ポリシー
* **[ARMOR-VISION](https://github.com/JuanenRac/ARMOR-VISION)** - Jetson Orin NX 向けのカメラゾーン、マスク、検出ルール
* **[ARMOR-VOICE-AI](https://github.com/JuanenRac/ARMOR-VOICE-AI)** - 偽造できない確認を備えたオフライン音声インテント
* **[ARMOR-HARDWARE](https://github.com/JuanenRac/ARMOR-HARDWARE)** - 筐体、電子部品、ベンチ受け入れマトリクス
* **[ARMOR-DEVOPS](https://github.com/JuanenRac/ARMOR-DEVOPS)** - デプロイ、CM5 テストベンチ、バックアップ、TLS
* **[ARMOR-SIMULATOR](https://github.com/JuanenRac/ARMOR-SIMULATOR)** - 再現可能な障害を備えたオフラインのテレメトリシミュレーター
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - エコシステム自身のリポジトリを検出、インストール、更新
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - アーキテクチャ、セキュリティベースライン、機能マトリクス

## 📚 ドキュメントとコミュニティ

詳しくは：

* [機能マトリクス：実証済みのことと未実証のこと](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [プロジェクトカタログ：バージョンとリポジトリ間の依存関係](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [このリポジトリの変更履歴](CHANGELOG.md)
* [ライセンス（GPL-3.0-or-later）](LICENSE)
* 質問、アイデア、報告: electrohobby3d@gmail.com

## 👤 作者

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 ライセンス

GPL-3.0-or-later - see [LICENSE](LICENSE).
