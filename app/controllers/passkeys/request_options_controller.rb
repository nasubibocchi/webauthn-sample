class Passkeys::RequestOptionsController < ApplicationController
  def create
    begin
      user_params = params.require(:user).permit(:email)
      user = User.find_by!(email: user_params[:email])
      
      if user.passkeys.blank?
        Rails.logger.info "User found but no passkeys registered: #{user_params[:email]}"
        render json: { error: "No passkeys registered for this email" }, status: :unprocessable_entity
        return
      end

      # https://www.w3.org/TR/webauthn/#dictionary-assertion-options
      request_options = WebAuthn::Credential.options_for_get(
        user_verification: "required",  # ユーザー認証を要求する
        allow: user.passkeys.pluck(:external_id) 
      )

      session[:current_webauthn_authentication_challenge] = request_options.challenge
      
      Rails.logger.info "WebAuthn request options generated for: #{user_params[:email]}"
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
