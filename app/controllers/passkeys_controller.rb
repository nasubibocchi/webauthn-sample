# このコントローラーは、ログイン済みユーザーがマイページなどからアクセスして
# パスキーの管理（追加・表示・削除）を行うための標準的なインターフェースを提供します。
#
# 注: 初回登録時のパスキー設定には Users::Passkeys::InitialPasskeysController を使用し、
# パスワードレス登録のパスキー設定には Users::PasswordlessPasskeysController を使用します。
# これにより、異なるユーザーフローに対して適切なエラーハンドリングとリダイレクトを実現しています。
class PasskeysController < ApplicationController
  def index
    @passkeys = current_user.passkeys
  end

  def create
    passkey_params = params.require(:passkey).permit(:label, :credential)
    stored_registration_challenge = session[:current_webauthn_registration_challenge]
    parsed_credential = JSON.parse(passkey_params[:credential]) rescue nil
    webauthn_credential = WebAuthn::Credential.from_create(parsed_credential)
    webauthn_credential.verify(stored_registration_challenge, user_verification: true) # 検証失敗したら `WebAuthn::VerificationError` が発生するので、実際に使うときはエラーハンドリングを考える

    current_user.passkeys.create!(
      label: passkey_params[:label],
      external_id: webauthn_credential.id,
      public_key: webauthn_credential.public_key,
      sign_count: webauthn_credential.sign_count,
      last_used_at: Time.current
    )

    redirect_to passkeys_path
  end

  def destroy
    @passkey = current_user.passkeys.find(params[:id])
    @passkey.destroy
    redirect_to passkeys_path
  end
end
