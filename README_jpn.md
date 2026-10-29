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
  🇯🇵 <b>日本語</b> |
  <a href="README_por.md">🇵🇹 Português</a>
</p>

### ARMOR-SERVER の iPhone オペレータークライアント：状態、警戒、警報、警報盤、カメラ、アシスタント。8 言語対応

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

**正直さのチェック - 今日動いているもの:** アプリのルール（サーバー接続、応答の解析、アドレスの選択、端末ロック、セッションの保管庫、証明書の信頼、警報ポリシー、ユースケース、MJPEG の切り出し）は Swift パッケージ `ArmorCore` にあり、macOS または Linux で `swift test` により実行される 103 件の単体テストでカバーされています。`tools/ios_lint.py` は Mac なしで構造、8 言語の表、契約を検査します。**まだ**証明されていないもの：SwiftUI の画面と iPhone が必要な部分（Face ID、キーチェーン、証明書ルール、ライブカメラ、Firebase 経由のプッシュ）は、Xcode でのビルドも実機での実行もしていません。

---

## 📋 ひと目で

| | |
|---|---|
| バージョン | `0.0.1` |
| 成熟度 | 足場段階 |
| 役割 | ARMOR-SERVER 用の iPhone オペレーター向けクライアント（ファミリー：Clients、親：ARMOR-SERVER） |
| 技術 | Swift 5.9+ / SwiftUI, iOS 16+ |
| テスト | 103 (`swift test`) |
| 言語 | 8（言語ごとに 241 フレーズ、`ios_lint.py` が検査） |
| 動作環境 | iOS 16+ の iPhone。テストは macOS または Linux で実行 |
| 実機での確認 | iPhone ではまだ実行していません。ルールは Linux でテスト済みです |
| ライセンス | GPL-3.0-or-later |

**移動先：** [概要](#-概要) · [アーキテクチャ](#-アーキテクチャ) · [セキュリティ](#-セキュリティと安全) · [インターフェース](#-インターフェース) · [設定](#-設定) · [クイックスタート](#-クイックスタート) · [テスト](#-テスト) · [トラブルシューティング](#-トラブルシューティング) · [構成](#-リポジトリの構成) · [関連](#-関連プロジェクト)

## 🚦 プロジェクトの状況

各行はこのリポジトリの一部分で、信号は今日どこまで進んでいるかを示します。計画ではなく、リポジトリが示せるもの（テスト、ビルド、実行）に基づいて書かれています。

🟢 完了・検証済み · 🟡 動作する（既知の制限あり） · 🟠 一部のみ、または未検証 · 🔴 未実装または動作しない

| 領域 | 状態 | ここでの意味 |
|---|---|---|
| ソフトウェア | 🟠 | アプリの規則は Swift パッケージ（`ArmorCore`）です。SwiftUI の画面は Xcode ではまだビルドしていません。 |
| テスト | 🟡 | 103 件のユニットテストが macOS または Linux の `swift test` で通り、`tools/ios_lint.py` が Mac なしで構造、8 言語の表、契約を確認します。実機で動くテストはありません。 |
| インターフェース | 🟠 | SwiftUI の画面は書いてありますが、Xcode でのビルドも iPhone での実行もしていません。 |
| ハードウェア | 🔴 | iPhone 上ではまだ動かしていません。規則は Linux でのみテストしています。 |
| セキュリティ | 🟠 | 端末のロック、セッションの保管庫、証明書の信頼は Linux でテストした規則です。Face ID、キーチェーン、証明書の規則は実機では動かしていません。 |
| 連携 | 🟠 | ライブカメラと Firebase 経由のプッシュは試していません。サーバーとの接続と解析は共有の契約に対してテストしています。 |
| ドキュメント | 🟢 | 8 言語と変更履歴は最新です。 |

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

| 名前 | 方法 | 用途 |
|---|---|---|
| ARMOR-SERVER | HTTP `/api/v1`, MJPEG | アプリが読み取り・命令するすべて。他とは通信しません |
| ARMOR-ANDROID-CONTROL | 同じコントラクト | `ios_lint.py` が、アプリが Android クライアントも呼ぶパスだけを呼ぶことを検査 |
| ARMOR-STUDIO | QR | 設置環境の証明書の鍵をペアリング |

## 🏛️ アーキテクチャ

<p align="center">
  <img src="images/architecture.svg" alt="ARMOR-IOS-CONTROL のアーキテクチャ：呼び出し元、内部、依存先" width="100%">
</p>

## 🔒 セキュリティと安全

| 脅威 | 対策 |
|---|---|
| 電話上のパスワード | *ログイン状態を保持* のときだけこの電話のキーチェーンに保存し、バックアップされません。セッションはサーバーの HttpOnly Cookie です |
| 電話が他人の手にあるときの重要な命令 | アーム、ディスアーム、サイレン停止、解錠などの重要な命令の前に Face ID、Touch ID またはパスコードを要求します。管理者は必須にできますが、選んだ水準を下げることはできません。パスコードのない電話が締め出されることはありません |
| 変更または偽造された証明書 | 設置環境の証明書の鍵は初回に記憶するか Studio の QR でペアリングします。変わると接続を拒否して知らせます |
| 平文で送られるパスワード | 平文 HTTP はプライベートネットワークまたはループバックのアドレスのみ（`NSAllowsLocalNetworking`）。それ以外は https が必要で、そうでなければアプリはパスワードを送りません |
| 電話上のカメラのパスワード | カメラはサーバー経由で、アプリにはカメラのパスワードも RTSP アドレスもありません |
| 閲覧者が何かを変更する | *閲覧者* ロールは見るだけで、何かを変えるボタンはすべて無効です。サーバーも再確認します |
| アシスタントが誤ってアーム・ディスアームする | 入力したコマンドのみ（音声入力はキーボードのマイク）。アームとディスアームには、あなたに結び付いた確認が必要で、電話のロックの内側で行います |

権限のテキスト（Face ID、ローカルネットワーク）は 8 言語すべてにあります。ここにあるものは iPhone では一度も動いていません。Face ID、キーチェーン、証明書ルールは実機で未検証です。[docs/CLIENT_BOUNDARY.md](docs/CLIENT_BOUNDARY.md) と [SECURITY.md](SECURITY.md) を参照してください。

## 🔌 インターフェース

これはクライアントです。ARMOR-SERVER の 26 のパスを呼び出し（`tools/ios_lint.py` が数え、Android クライアントも呼ぶことを検査）、カメラの MJPEG ストリームを独自のパーサー（`MjpegParser.swift`）で切り出します。

| 部分 | 設定内容 |
|---|---|
| 2 つのアドレス | 自宅 Wi-Fi ではプライベートアドレス、外出先のモバイル通信では動的 DNS 名または VPN のアドレスを使います。片方が応答しなければもう片方を試し、何が失敗したかをメッセージで伝えます（`Reach.swift`、`Connector.swift`） |
| カメラ | 画面に出ている映像だけが動くグリッド、カメラを動かすパッドとスナップショット付きの全画面表示、切れたら待ち時間を延ばしながら再要求するストリーム |
| プッシュ | 閉じたアプリにアラームが届くのはプッシュ（`Push.swift`、Firebase）経由のみで、サーバーでプッシュが有効かつ設置環境が自前の `GoogleService-Info.plist` を用意した場合に限ります。未検証です |

## ⚙️ 設定

| 名前 | 値 | 設定内容 |
|---|---|---|
| iOS | 16.0+ | 最低バージョン（`project.yml` で設定） |
| Xcode / Swift | 15+ / 5.9+ | アプリのビルド／テスト実行用 |
| `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION` | 0.0.1, 1 | アプリのバージョン（`project.yml` より） |
| `GoogleService-Info.plist` | プッシュ用 | 設置環境ごとのファイル。リポジトリには置きません |

アプリ内：2 つのアドレス、*ログイン状態を保持*、電話のロック、言語（8 言語または電話に従う）は *その他 > 言語* にあります。

## 🚀 クイックスタート

**必要なもの:** アプリのビルドには Xcode 15+ と iOS 16+ の Mac、テストには Swift 5.9+（macOS または Linux）、検査には Python 3.11。

```sh
swift test                  # 103 tests of ArmorCore (macOS or Linux)
python tools/ios_lint.py    # structure, eight languages, contract (any system)
xcodegen generate           # then open ARMOR-IOS-CONTROL.xcodeproj in Xcode (on a Mac)
```

Xcode プロジェクトは `project.yml` から XcodeGen で生成します。署名チームを選び、アプリアイコンを追加し、プッシュにはインストール専用の `GoogleService-Info.plist` を追加してください（リポジトリには保存しません）。[クライアントの境界](docs/CLIENT_BOUNDARY.md)を参照してください。

## 🧪 テスト

```sh
swift test                  # macOS or Linux
python tools/ios_lint.py    # any system, no Mac needed
python -I tools/armor_ci_validate.py
```

| テストファイル | テスト数 | 対象 |
|---|---|---|
| `ControllerTests.swift` | 15 | コントローラーのユースケース |
| `ClientTests.swift` | 14 | サーバーとの接続とその解析 |
| `LockTests.swift` | 12 | 電話のロック |
| `ModelsTests.swift` | 12 | サーバーから読むモデル |
| `ReachTests.swift` | 11 | 2 つのアドレスの選択 |
| `SecurityTests.swift` | 8 | セッション保管庫と証明書への信頼 |
| `EndpointTests.swift`, `MjpegTests.swift`, `TranslatorTests.swift` | 7 + 7 + 7 | アドレス解析、MJPEG の切り出し、翻訳 |
| `PolicyTests.swift`, `AlarmCodesTests.swift` | 6 + 4 | アラームポリシーとアラームコード |

103 件のテストは実サーバーのデータで動きます。`tools/ios_lint.py` は Mac なしで通ります：Swift ファイル 31、8 言語の 241 フレーズ、サーバーパス 26。実機で動くテストはありません。

## 🏗️ ビルドとリリース

Xcode プロジェクトは XcodeGen で `project.yml` から生成します。署名チームを選び、アプリのアイコンを `App/Resources/Assets.xcassets/AppIcon.appiconset` に、プッシュ用に設置環境の `GoogleService-Info.plist` を追加してください。Xcode でビルドしたことはありません。

## 🩺 トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| 接続が拒否され通知される | 設置環境の証明書の鍵が変わった | 意図して変えたなら Studio の QR で再ペアリング |
| どちらのアドレスも応答しない | アドレスの誤り、ネットワークなし、または自宅外への http（拒否：パスワードは平文で送りません） | 両方のアドレスを確認し、外出先では https を使う |
| `wrong_pin`、`pin_locked`、`pin_not_set` | サーバーが解除 PIN を拒否。アプリはコードをあなたの言語で表示します | PIN を入れ直すかロック解除を待つ。PIN は Studio で設定 |

## 📂 リポジトリの構成

<p align="center">
  <img src="images/repository-structure.svg" alt="ARMOR-IOS-CONTROL のリポジトリ構造" width="100%">
</p>

<details>
<summary>ツリーのテキスト版</summary>

```text
ARMOR-IOS-CONTROL/
├── Sources/ArmorCore/                   アプリのルール：Swift パッケージ
├── App/                                 SwiftUI 画面と iPhone が必要な部分
├── Tests/                               103 件のテストと実サーバーのデータ
├── docs/                                このリポジトリのガイド
├── tools/                               共通の CI チェックとプロジェクトツール
├── .github/                             CI ワークフローと Issue・Pull Request のテンプレート
├── images/                              バナー、アイコン、この README の 2 つの図
├── armor.project.json                   マニフェスト：バージョン、役割、成熟度、ビルドコマンド
├── CHANGELOG.md                         各バージョンの変更点
├── SECURITY.md SUPPORT.md LICENSE       セキュリティポリシー、サポート、ライセンス
├── CONTRIBUTING.md CODE_OF_CONDUCT.md   貢献方法と行動規範
├── Package.swift                        Swift パッケージ：ArmorCore とそのテスト
├── project.yml                          XcodeGen：ここから Xcode プロジェクトを生成
└── .gitattributes .gitignore            Git の設定
```

</details>

## 🗺️ ロードマップと既知の制限

**現時点の既知の制限**

* iPhone では何も動いていません。SwiftUI 画面は Xcode でビルドしておらず、Face ID、キーチェーン、証明書ルール、ライブカメラ、Firebase のプッシュは未検証です。
* テスト済みなのはルール（`ArmorCore`）だけで、Linux 上のみです。
* アプリはバックグラウンドで監視しません。iOS では閉じたアプリがサーバーに問い合わせることはできません。

**今後**

* Xcode で画面をビルドし、iPhone で CM5 テストベンチに対してアプリを動かす。
* Face ID、キーチェーン、証明書ルール、ライブカメラ、プッシュを試す。

## 🌍 言語

README とテキストは、英語、スペイン語、フランス語、イタリア語、ドイツ語、中国語、日本語、ヨーロッパポルトガル語で提供されています。

## 🔗 関連プロジェクト

**A.R.M.O.R.**（Autonomous Radar & Multimodal Observation Range）は、独立したリポジトリで構成される境界セキュリティシステムです。各リポジトリは独自のバージョン、テスト、README を持ちます。ファミリーは次のとおりです：

* **[ARMOR-COMMON](https://github.com/JuanenRac/ARMOR-COMMON)** - メッセージのコントラクト、バリデーター、適合ベクトル、生成された型
* **[ARMOR-NODE-RADAR](https://github.com/JuanenRac/ARMOR-NODE-RADAR)** - 3 つのレーダーと独自の Web パネルを備えた ESP32-S3 向けフィールドノードのファームウェア
* **[ARMOR-NODE-SOLAR](https://github.com/JuanenRac/ARMOR-NODE-SOLAR)** - ソーラーインバーターとバッテリーのプロトコル、ゲートウェイノードのメッセージ
* **[ARMOR-NODE-ELECTRICAL](https://github.com/JuanenRac/ARMOR-NODE-ELECTRICAL)** - 電気ノード：メーター、系統の読み取り値のメッセージ、切り替えのルール
* **[ARMOR-NODE-ALARM](https://github.com/JuanenRac/ARMOR-NODE-ALARM)** - 警報ノードとパネル：ゾーン、警戒、遅延、サイレン、PIN。サーバーありでもなしでも動作
* **[ARMOR-NODE-HMI](https://github.com/JuanenRac/ARMOR-NODE-HMI)** - タッチパネル：壁面画面でのシステムの状態、警戒と確認応答、そして音声アシスタントの置き場
* **[ARMOR-NETWORK](https://github.com/JuanenRac/ARMOR-NETWORK)** - ローカルネットワーク：そのデバイス、インターネット、そして変化
* **[ARMOR-SERVER](https://github.com/JuanenRac/ARMOR-SERVER)** - 中央コーディネーター：テレメトリ、警報、デバイス、ソーラーの読み取り値、カメラ
* **[ARMOR-STUDIO](https://github.com/JuanenRac/ARMOR-STUDIO)** - Web コンソール：カメラ、レーダー、警報、太陽光エネルギー、2D/3D のサイトデザイナー
* **[ARMOR-ANDROID-CONTROL](https://github.com/JuanenRac/ARMOR-ANDROID-CONTROL)** - ライブの 2D/3D レーダーを備えた Android オペレータークライアント
* **ARMOR-IOS-CONTROL**（このリポジトリ） - iPhone オペレータークライアント
* **[ARMOR-SERVER-AI](https://github.com/JuanenRac/ARMOR-SERVER-AI)** - 判断を説明し、決して作動させない視覚推論ポリシー
* **[ARMOR-VISION](https://github.com/JuanenRac/ARMOR-VISION)** - Jetson Orin NX 向けのカメラゾーン、マスク、検出ルール
* **[ARMOR-VOICE-AI](https://github.com/JuanenRac/ARMOR-VOICE-AI)** - 偽造できない確認つきのオフライン音声インテント
* **[ARMOR-HARDWARE](https://github.com/JuanenRac/ARMOR-HARDWARE)** - 筐体、電子回路、ベンチ受け入れマトリクス
* **[ARMOR-DEVOPS](https://github.com/JuanenRac/ARMOR-DEVOPS)** - デプロイ、CM5 テストベンチ、バックアップ、TLS
* **[ARMOR-SIMULATOR](https://github.com/JuanenRac/ARMOR-SIMULATOR)** - 再現可能な障害を持つオフラインのテレメトリシミュレーター
* **[ARMOR-UPDATER](https://github.com/JuanenRac/ARMOR-UPDATER)** - エコシステム自身のリポジトリを検出、インストール、更新
* **[ARMOR-DOCS](https://github.com/JuanenRac/ARMOR-DOCS)** - アーキテクチャ、セキュリティのベースライン、機能マトリクス

## 📚 ドキュメント

* [クライアントの境界](docs/CLIENT_BOUNDARY.md)：クライアントがすることとしないこと、ビルド方法
* [機能マトリクス：何が証明され、何が証明されていないか](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/CAPABILITY_MATRIX.md)
* [プロジェクトカタログ：バージョンと、リポジトリ同士の依存関係](https://github.com/JuanenRac/ARMOR-DOCS/blob/main/docs/PROJECT_CATALOG.md)
* [このリポジトリの変更履歴](CHANGELOG.md)

## 🤝 コントリビュートとコミュニティ

* Pull Request の前に `swift test` and `python tools/ios_lint.py` and `python -I tools/armor_ci_validate.py` を実行してください。通る必要があります。[CONTRIBUTING.md](CONTRIBUTING.md) と[行動規範](CODE_OF_CONDUCT.md)を参照してください。
* README は 8 言語で提供され、ARMOR-DOCS のソースから生成されます。文面の変更はそちらで行います。
* コンポーネント間のメッセージの変更は ARMOR-COMMON から始めます。
* ビルドしただけのものを、ボード上で動いているかのように書かないでください。
* 脆弱性は非公開で報告してください：[SECURITY.md](SECURITY.md)。質問、アイデア、報告：electrohobby3d@gmail.com（[SUPPORT.md](SUPPORT.md)）。

## 👤 作者

**JuanenRac (Electro Hobby 3D)** · electrohobby3d@gmail.com

## 📜 ライセンス

GPL-3.0-or-later - [LICENSE](LICENSE) を参照してください。
