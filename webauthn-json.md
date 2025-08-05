### passkey関連のAPIを使用している箇所

  1. 新規パスキー作成: app/javascript/controllers/new_passkey_controller.js

  - `parseCreationOptionsFromJSON()` - パスキー作成オプションの解析
  - `create()` - パスキーの作成

  2. パスワードレスパスキー: app/javascript/controllers/passwordless_passkey_controller.js

  - `parseCreationOptionsFromJSON()` - パスキー作成オプションの解析
  - `create()` - パスキーの作成

  3. パスキー認証: app/javascript/controllers/authorize_passkey_controller.js

  - `window.PublicKeyCredential` - WebAuthnサポート確認
  - `PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()` - プラットフォーム認証器の可用性確認
  - `PublicKeyCredential.isConditionalMediationAvailable()` - 条件付きメディエーション確認
  - `parseRequestOptionsFromJSON()` - パスキー認証オプションの解析
  - `get()` - パスキー認証の実行

  全てのコントローラーで @github/webauthn-json ライブラリが使用されています。