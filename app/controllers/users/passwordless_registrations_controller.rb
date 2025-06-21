class Users::PasswordlessRegistrationsController < ApplicationController
  # GET /users/passwordless_sign_up
  def new
    @user = User.new
  end

  # POST /users/passwordless_sign_up
  def create
    @user = User.new(sign_up_params)
    @user.passwordless = true

    # ランダムなパスワード（セキュアで十分長い）を設定
    secure_password = SecureRandom.base64(32)
    @user.password = secure_password
    @user.password_confirmation = secure_password

    if @user.save
      # ログをセキュリティ監査のために残す
      Rails.logger.info("Passwordless user created: #{@user.email} (ID: #{@user.id})")

      # セッションに保存したユーザーIDをパスキー登録時に使用
      session[:passwordless_user_id] = @user.id
      session[:passwordless_registration_started] = Time.current.to_i

      redirect_to new_passwordless_passkey_path
    else
      # エラーがある場合は入力フォームに戻る
      render :new, status: :unprocessable_entity
    end
  end

  private

  def sign_up_params
    params.require(:user).permit(:email)
  end
end
