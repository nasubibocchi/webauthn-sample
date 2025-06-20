# WebAuthn Sample - パスキー認証サンプルアプリケーション

このプロジェクトは、WebAuthn（Web Authentication）を使用したパスキーベースの認証システムを実装したサンプルRailsアプリケーションです。パスワードレス認証の最新技術であるパスキー（Passkey）を使って、より安全で便利なユーザー認証を実現します。

## 概要

このアプリケーションは以下の機能を提供します：

- 通常のメールアドレス・パスワードによるログイン
- パスキーの登録・管理
- パスキーを使用した認証（メールアドレス不要）
- 条件付きUI（Conditional UI）によるシームレスなパスキー認証

## 特徴

### パスキー認証（WebAuthn）

- **フィッシング耐性**: パスキーはドメイン固有で、フィッシングサイトでは使用できません
- **パスワードレス**: 覚えにくいパスワードが不要
- **強力な認証**: 生体認証や端末のセキュリティ機能を活用
- **クロスデバイス対応**: 複数のデバイス間で同期可能

### 実装ポイント

1. **Discoverable Credentials（自己検証型認証情報）**
   - ユーザー名やメールアドレスを入力せずに認証可能
   - ブラウザとOS、認証器が協力してユーザーを識別

2. **Conditional UI**
   - ページロード時に自動的にパスキー認証プロンプトを表示
   - シームレスな認証体験を実現

## 技術スタック

- **フレームワーク**: Ruby on Rails
- **認証基盤**: Devise
- **WebAuthn**: [WebAuthn Ruby](https://github.com/cedarcode/webauthn-ruby)
- **フロントエンド**: Stimulus.js
- **WebAuthnクライアント**: [@github/webauthn-json](https://github.com/github/webauthn-json)

## セットアップと実行方法

### 必要条件

- Ruby 3.0以上
- Rails 7.0以上
- PostgreSQL (または対応するデータベース)
- WebAuthn対応ブラウザ (Chrome, Safari, Firefox, Edge 最新版)

### インストール

```bash
# リポジトリをクローン
git clone https://github.com/your-username/webauthn-sample.git
cd webauthn-sample

# 依存パッケージのインストール
bundle install

# データベースのセットアップ
rails db:create
rails db:migrate

# サーバーの起動
rails s
```

## 使い方

1. アカウント登録: メールアドレスとパスワードでアカウントを作成
2. パスキーの登録: ログイン後、パスキー管理画面からパスキーを登録
3. パスキーでのログイン: 
   - ログイン画面にアクセスすると自動的にパスキー認証が開始されます
   - もしくは「Log in with a passkey」ボタンをクリックして認証

## パスキーの仕組み

パスキー認証は以下のフローで動作します：

1. **登録フェーズ**:
   - サーバーが登録オプションと暗号チャレンジを生成
   - ブラウザが認証器（指紋センサー、Face IDなど）と通信
   - 認証器が公開鍵と秘密鍵のペアを生成
   - 公開鍵とユーザー情報がサーバーに保存

2. **認証フェーズ**:
   - サーバーが認証オプションと新しいチャレンジを生成
   - ブラウザが認証器と通信
   - 認証器が秘密鍵を使用してチャレンジに署名
   - サーバーが公開鍵を使って署名を検証

## パスキーの利点

- **セキュリティ強化**: 生体認証の活用で認証強度が向上
- **利便性向上**: パスワードを記憶・入力する必要がない
- **管理の簡素化**: パスワードリセット対応が不要に
- **標準化技術**: FIDO AllianceとW3Cの標準に準拠

## 技術的詳細と実装のポイント

### クライアント側の実装（JavaScript）

パスキー認証のクライアント側は主に以下のコンポーネントで構成されています：

1. **Stimulusコントローラー** - 認証フローを制御
2. **WebAuthn API** - ブラウザネイティブのWebAuthn機能を使用
3. **@github/webauthn-json** - WebAuthn APIのラッパーライブラリ

```javascript
// Conditional MediaationによるパスキーUI自動表示の実装例
if (PublicKeyCredential.isConditionalMediationAvailable) {
  const isCMA = await PublicKeyCredential.isConditionalMediationAvailable();
  if (isCMA) {
    // パスキー認証の開始
    const credentialRequestOptions = parseRequestOptionsFromJSON({ publicKey: requestOption });
    credentialRequestOptions['mediation'] = 'conditional';
    const credential = await get(credentialRequestOptions);
  }
}
```

### サーバー側の実装（Ruby）

サーバー側では以下の処理を行います：

1. **チャレンジの生成** - ランダムなチャレンジを生成して認証要求
2. **パスキーの検証** - クライアントからの応答を検証
3. **ユーザーの特定** - 正しいパスキーに関連付けられたユーザーを認証

```ruby
# Discoverable Credentialsのためのチャレンジ生成
request_options = WebAuthn::Credential.options_for_get(
  user_verification: "required"
  # allowパラメータを指定しない = 全てのパスキーを許可
)
```

### モデル構造

アプリケーションは以下のモデルを使用しています：

- **User** - 基本的なユーザー情報
- **WebauthnUser** - WebAuthn関連のユーザー情報
- **Passkey** - ユーザーに関連付けられたパスキー情報

## パスキーフローの詳細

### 1. 認証リクエストの開始

ユーザーが認証を開始するときのフロー：

```
+----------+                             +--------+                               +-----------+
|          |                             |        |                               |           |
|  Browser | --- GET /login -----------> | Server | --- Generate Challenge -----> |  Database |
|          |                             |        |                               |           |
|          | <-- Challenge + Options --- |        | <-- Store Challenge --------- |           |
+----------+                             +--------+                               +-----------+
     |
     | WebAuthn API
     v
+----------+
|          |
|   Auth   | (FaceID, TouchID, etc.)
| Platform |
|          |
+----------+
```

### 2. パスキー認証の完了

認証器からの応答を検証するフロー：

```
+----------+                             +--------+                               +-----------+
|          |                             |        |                               |           |
|  Browser | --- POST /authenticate ---> | Server | --- Verify Credential ------> |  Database |
|          |     (signed challenge)      |        |     (public key)              |           |
|          | <-- Auth Success/Error ---- |        | <-- Find User by Credential - |           |
+----------+                             +--------+                               +-----------+
```

## セキュリティ考慮事項

- **リプレイ攻撃対策**: 各認証リクエストには一意のチャレンジを使用
- **なりすまし対策**: ドメイン名を検証し、フィッシングサイトでの使用を防止
- **耐タンパー性**: パスキーの秘密鍵はハードウェアで保護され、エクスポート不可
- **多要素認証**: パスキーは「所有しているもの」と「知っているもの/特性」を組み合わせた多要素認証

## 今後の拡張案

1. **モバイルアプリ対応**: WebAuthn APIをモバイルアプリでも活用
2. **クロスデバイス同期**: パスキー情報のデバイス間同期機能の強化
3. **認証ジャーニー分析**: ユーザーの認証行動パターンの分析と最適化
4. **FIDO2認定**: FIDO2認定を取得し、相互運用性を確保

## 参考資料

- [WebAuthn Guide](https://webauthn.guide/)
- [FIDO Allianceのドキュメント](https://fidoalliance.org/specifications/)
- [W3C Web Authentication API](https://www.w3.org/TR/webauthn/)
- [WebAuthn.io (デモサイト)](https://webauthn.io/)

## 貢献方法

このプロジェクトへの貢献を歓迎します。以下の手順で貢献できます：

1. このリポジトリをフォーク
2. 機能追加やバグ修正のブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add some amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## 課題と今後の発展

- **ブラウザサポート**: 古いブラウザではWebAuthnがサポートされていない場合の対応
- **エラーハンドリング**: より詳細なエラー情報とユーザーフレンドリーなメッセージ
- **インターナショナライゼーション**: 多言語対応

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細は[LICENSE](LICENSE)ファイルを参照してください。

## 謝辞

- [WebAuthn Ruby](https://github.com/cedarcode/webauthn-ruby) - WebAuthnのRuby実装を提供
- [GitHub's webauthn-json](https://github.com/github/webauthn-json) - WebAuthn APIのJSONシリアライズ/デシリアライズを簡素化
- [FIDO Alliance](https://fidoalliance.org/) - FIDO2/WebAuthn標準の策定
