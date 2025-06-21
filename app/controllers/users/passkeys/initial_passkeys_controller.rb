# このコントローラーは、通常のパスワード認証方式でサインアップした直後のユーザーに対し、
# 初回のパスキー設定を促すための専用フローを提供します。
#
# 通常の PasskeysController とは以下の点で異なります：
# 1. サインアップ直後の特殊な認証状態を処理
# 2. 登録後のリダイレクト先が異なる（パスキー管理ページではなくメインページへ）
# 3. エラーハンドリングとユーザー体験の最適化
#
# 関連コントローラー:
# - Users::RegistrationsController - 登録後にこのコントローラーにリダイレクト
# - PasskeysController - 日常的なパスキー管理用（追加登録や削除）
# - Users::PasswordlessPasskeysController - パスワードレス登録フロー用
class Users::Passkeys::InitialPasskeysController < ApplicationController
  def show
    # パスキー設定ページを表示
  end

  def create
    passkey_params = params.require(:passkey).permit(:label, :credential)
    stored_registration_challenge = session[:current_webauthn_registration_challenge]
    parsed_credential = JSON.parse(passkey_params[:credential]) rescue nil
    webauthn_credential = WebAuthn::Credential.from_create(parsed_credential)
    webauthn_credential.verify(stored_registration_challenge, user_verification: true)

    current_user.passkeys.create!(
      label: passkey_params[:label],
      external_id: webauthn_credential.id,
      public_key: webauthn_credential.public_key,
      sign_count: webauthn_credential.sign_count,
      last_used_at: Time.current
    )

    # パスキー設定後、メインページへリダイレクト
    redirect_to after_sign_in_path_for(current_user), notice: "パスキーが正常に登録されました！"
  rescue WebAuthn::Error => e
    redirect_to initial_passkey_path, alert: "パスキーの登録に失敗しました: #{e.message}"
  end
end
