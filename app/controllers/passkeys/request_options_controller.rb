class Passkeys::RequestOptionsController < ApplicationController
  def create
    begin
      # エンドポイントを2つのモードで動作させる
      # 1. メールアドレスが提供された場合: 特定ユーザーの認証情報に制限する (従来のフロー)
      # 2. メールアドレスが提供されていない場合: discoverable credentials を使用 (新しいフロー)
      if params[:user].present? && params[:user][:email].present?
        # 従来のフローの実装
        user_params = params.require(:user).permit(:email)
        user = User.find_by!(email: user_params[:email])

        if user.webauthn_user.nil?
          Rails.logger.info "User found but no webauthn_user exists: #{user_params[:email]}"
          render json: { error: "No WebAuthn identity for this user" }, status: :unprocessable_entity
          return
        end

        if user.passkeys.blank?
          Rails.logger.info "User found but no passkeys registered: #{user_params[:email]}"
          render json: { error: "No passkeys registered for this email" }, status: :unprocessable_entity
          return
        end

        # 特定ユーザーのパスキーのみを許可
        request_options = WebAuthn::Credential.options_for_get(
          user_verification: "preferred",
          allow: user.passkeys.pluck(:external_id)
        )

        Rails.logger.info "WebAuthn request options generated for: #{user_params[:email]} with allowed credentials: #{user.passkeys.pluck(:external_id)}"
      else
        # 新しい discoverable credentials フロー
        # allowパラメータを指定せずに、すべてのパスキーを許可する
        request_options = WebAuthn::Credential.options_for_get(
          user_verification: "preferred"
        )

        Rails.logger.info "WebAuthn request options generated for discoverable credentials"
      end

      session[:current_webauthn_authentication_challenge] = request_options.challenge
      render json: request_options
    rescue ActiveRecord::RecordNotFound => e
      # ユーザーが見つからない場合のエラー処理
      Rails.logger.error "User not found: #{e.message}"
      render json: { error: "User not found" }, status: :not_found
    rescue => e
      # その他のエラー処理
      Rails.logger.error "Error generating WebAuthn options: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: "An error occurred" }, status: :internal_server_error
    end
  end
end
