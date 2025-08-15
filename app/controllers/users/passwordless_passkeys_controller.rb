# このコントローラーは、パスワードレス登録フローの一部として、
# メールアドレスのみで仮登録したユーザーにパスキーを設定するための専用処理を提供します。
#
# PasskeysController および InitialPasskeysController とは以下の点で異なります：
# 1. ユーザーは仮登録状態（パスワードレス）でまだ完全にログインしていない
# 2. パスキー登録が完了するまでアカウントが有効にならない
# 3. セッション管理が特殊（passwordless_user_id等を使用）
# 4. 認証要件が異なる（authenticate_user!をスキップ）
#
# この実装により、パスワード認証とパスワードレス認証の2つの登録フローを
# 適切に分離しつつ、どちらもパスキーによる認証を実現しています。
class Users::PasswordlessPasskeysController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  before_action :ensure_valid_registration_session
  before_action :set_user

  # パスキー登録フォームの表示
  def new
    # @userは before_action で設定済み
  end

  # パスキー登録用のオプション生成
  def creation_options
    # 登録に関する追加のセキュリティ設定
    # https://github.com/cedarcode/webauthn-ruby/blob/b48108d053e4a0b8e6edf474d72b113a81426a01/lib/webauthn/public_key_credential/creation_options.rb#L10
    creation_options = WebAuthn::Credential.options_for_create(
      user: {
        id: find_or_create_webauthn_id(@user),
        name: @user.email,
        display_name: @user.email
      },
      authenticator_selection: {
        # パスワードレスで使用されるパスキーは必ず discoverable credentials を使用
        resident_key: "required",
        require_resident_key: true,
        # ユーザー検証を常に要求 (例: 生体認証、PIN)
        user_verification: "preferred"
        # 一部のブラウザでは、プラットフォーム認証器のみを要求
        # authenticator_attachment: "platform"
      },
      # FIDO登録認証器にセキュリティ要件を明示
      attestation: "direct"
    )

    session[:current_webauthn_registration_challenge] = creation_options.challenge
    # タイムスタンプを更新して、チャレンジの有効期限を追跡
    session[:passwordless_challenge_timestamp] = Time.current.to_i

    render json: creation_options
  end

  # パスキーの実際の登録処理
  def create
    # チャレンジが有効期限内かチェック（5分以内）
    challenge_timestamp = session[:passwordless_challenge_timestamp].to_i
    if Time.current.to_i - challenge_timestamp > 5.minutes
      redirect_to new_passwordless_registration_path, alert: "登録セッションの有効期限が切れました。もう一度お試しください。"
      return
    end

    passkey_params = params.require(:passkey).permit(:label, :credential)
    stored_registration_challenge = session[:current_webauthn_registration_challenge]
    parsed_credential = JSON.parse(passkey_params[:credential]) rescue nil

    begin
      webauthn_credential = WebAuthn::Credential.from_create(parsed_credential)
      webauthn_credential.verify(stored_registration_challenge, user_verification: "preferred")

      # パスキーの登録とユーザーのパスワードレス化を1つのトランザクションで実行
      ActiveRecord::Base.transaction do
        # WebAuthnユーザーが存在しない場合は作成
        webauthn_user = @user.webauthn_user || @user.create_webauthn_user(webauthn_id: WebAuthn.generate_user_id)

        # パスキーを作成
        passkey = webauthn_user.passkeys.create!(
          label: passkey_params[:label],
          external_id: webauthn_credential.id,
          public_key: webauthn_credential.public_key,
          sign_count: webauthn_credential.sign_count,
          last_used_at: Time.current
        )

        # ユーザーがパスワードレスであることを明示的にマーク
        @user.update!(is_passwordless: true)
      end

      # セッション情報をクリア
      clear_passwordless_session

      # パスキー登録後にユーザーをログイン状態にする
      sign_in(@user)
      redirect_to root_path, notice: "アカウントとパスキーが正常に登録されました！"

    rescue WebAuthn::Error => e
      Rails.logger.warn("WebAuthn error during passwordless registration: #{e.message}")
      redirect_to new_passwordless_passkey_path, alert: "パスキーの登録に失敗しました: #{e.message}"
    rescue => e
      Rails.logger.error("Error during passwordless registration: #{e.message}")
      redirect_to new_passwordless_registration_path, alert: "登録処理中にエラーが発生しました。もう一度お試しください。"
    end
  end

  private

  # 登録セッションが有効かチェック
  def ensure_valid_registration_session
    user_id = session[:passwordless_user_id]
    registration_started = session[:passwordless_registration_started].to_i

    # セッション情報がない、または有効期限切れ(30分)
    if user_id.blank? || Time.current.to_i - registration_started > 30.minutes
      redirect_to new_passwordless_registration_path, alert: "登録セッションの有効期限が切れました。もう一度お試しください。"
    end
  end

  def set_user
    @user = User.find_by(id: session[:passwordless_user_id])
    unless @user
      redirect_to new_passwordless_registration_path, alert: "ユーザー情報が見つかりません。もう一度お試しください。"
    end
  end

  def find_or_create_webauthn_id(user)
    return user.webauthn_user.webauthn_id if user.webauthn_user

    user.create_webauthn_user(webauthn_id: WebAuthn.generate_user_id).webauthn_id
  end

  def clear_passwordless_session
    session.delete(:passwordless_user_id)
    session.delete(:passwordless_registration_started)
    session.delete(:current_webauthn_registration_challenge)
    session.delete(:passwordless_challenge_timestamp)
  end
end
